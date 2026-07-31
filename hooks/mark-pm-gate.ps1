# mark-pm-gate.ps1
# afterAgentResponse hook (matcher: AgentResponse) -- observation only, never blocks
# (afterAgentResponse 本身没有拦截能力，见 Cursor Hooks 文档).
#
# 目的：支柱 D 第一半。把"这轮回复里出现过 [PM] 标记"这件事，从"只存在于聊天文本里、
# 事后没法机械复核"变成"写进一个带时间戳、按 conversation_id 分桶的标记文件"，供
# pm-gate-check.ps1（preToolUse）在下一次 Write/StrReplace 时读取判断是否放行。
#
# 文本字段：Cursor afterAgentResponse 载荷字段名可能随版本变化；本脚本按候选列表
# 依次取第一个非空字符串（至少含 text + 备选 response/content/message/output），
# 避免只认 text 时静默漏标。
#
# 审计：每次调用都追加 hooks-log/mark-pm-gate.log（含 field= / hasPm= / wrote=），
# 便于机器断言落盘是否发生；命中 [PM] 时对 pm-gate.json 做同目录 temp + Replace 原子写。
#
# 已知局限（如实记录，不夸大）：afterAgentResponse 只在"这条助手消息完全生成完毕后"
# 触发，所以本 hook 写下的标记，只能证明"之前某一轮完整回复里出现过 [PM]"，不能证明
# "当前这条正在生成、还没说完的回复里同条先 [PM] 了"——这是 Cursor Hooks 当前公开
# 文档确认的限制（preToolUse 拿不到本轮尚未完成的助手文本），不是本脚本的 bug。
# 效果上等价于把 CORE 硬门禁 #7 的"同条先 PM"，退化成机械可查的"最近 N 分钟内这个
# 会话有没有 PM 判定过"——比完全没有机械层强，但不是精确的同条校验。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$logDir = Join-Path $PSScriptRoot "..\hooks-log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$gateFile = Join-Path $logDir "pm-gate.json"
$auditFile = Join-Path $logDir "mark-pm-gate.log"

# 至少 text + 备选；顺序即优先级
$textFieldCandidates = @("text", "response", "content", "message", "output")

function Write-MarkAudit {
    param([string]$Line)
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
        # 审计失败不阻塞 exit 0
    }
}

function Get-AgentText {
    param($Json)
    foreach ($name in $textFieldCandidates) {
        $prop = $Json.PSObject.Properties[$name]
        if (-not $prop) { continue }
        $val = $prop.Value
        if ($null -eq $val) { continue }
        $s = [string]$val
        if (-not [string]::IsNullOrWhiteSpace($s)) {
            return @{ Text = $s; Field = $name }
        }
    }
    return @{ Text = ""; Field = "none" }
}

function Write-GateAtomic {
    param([string]$Content)
    $tempPath = Join-Path $logDir ("pm-gate.json.tmp." + [Guid]::NewGuid().ToString("N"))
    $bakPath = Join-Path $logDir ("pm-gate.json.bak." + [Guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllText($tempPath, $Content, $utf8Bom)
        if (Test-Path -LiteralPath $gateFile) {
            [System.IO.File]::Replace($tempPath, $gateFile, $bakPath)
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::Move($tempPath, $gateFile)
        }
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $bakPath) {
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$conversationId = "unknown"
$fieldUsed = "none"
$hasPmMarker = $false
$wrote = "none"

try {
    $raw = [Console]::In.ReadToEnd()
    $raw = $raw.TrimStart([char]0xFEFF)
    $json = $raw | ConvertFrom-Json -ErrorAction Stop

    $extracted = Get-AgentText -Json $json
    $text = $extracted.Text
    $fieldUsed = $extracted.Field
    $conversationId = if ($json.conversation_id) { [string]$json.conversation_id } else { "unknown" }

    # [PM] 作为岗位标记出现（CORE.md：首行标记 [PM]）；不要求必须在行首，
    # 避免因缩进/引用符号导致漏判——宁可稍微宽松，也不要把真正的 PM 判定漏标成"没判定"。
    $hasPmMarker = $text -match [Regex]::Escape("[PM]")

    if ($hasPmMarker) {
        $gate = [ordered]@{}
        if (Test-Path -LiteralPath $gateFile) {
            try {
                $existingRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
                $existing = $existingRaw | ConvertFrom-Json -ErrorAction Stop
                $existing.PSObject.Properties | ForEach-Object { $gate[$_.Name] = $_.Value }
            } catch {
                # 旧文件损坏就当空表重建，不阻塞
            }
        }

        $snippet = $text.Substring(0, [Math]::Min(160, $text.Length))
        $gate[$conversationId] = [ordered]@{
            lastPmAtUtc  = [DateTime]::UtcNow.ToString("o")
            snippet      = $snippet
            sourceField  = $fieldUsed
        }

        $json2 = $gate | ConvertTo-Json -Depth 6
        Write-GateAtomic -Content $json2
        $wrote = "pm-gate.json"
    }
} catch {
    # 解析/写入失败不影响任何东西——本 hook 本身也没有拦截能力
    $wrote = "error"
}

Write-MarkAudit "conversation=$conversationId field=$fieldUsed hasPm=$hasPmMarker wrote=$wrote"

# afterAgentResponse 无 permission 字段语义；正常退出即可
exit 0
