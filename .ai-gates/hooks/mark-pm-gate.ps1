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
# 会话有没有 PM 判定过"（window_pm_not_this_turn）。比完全没有机械层强，但不是
# this_turn_pm / 本条结构化判定——preToolUse 拿不到尚未完成的助手文本。
#
# 2026-08-03 健壮化（真演修复）：真实 Cursor 环境对超大 AgentResponse payload
# （agent 长回复，可达数十 KB）时，PS5.1 的 Console.In.ReadToEnd() + ConvertFrom-Json
# 解析失败 → [PM] 打点不落盘 → 业务路径门禁误拦（与 mark-changelog-write 同故障）。
# 修复：① 读取改 OpenStandardInput() + StreamReader 显式 UTF-8；
#       ② ConvertFrom-Json 失败时 fallback 正则提取 conversation_id + 文本字段，
#          [PM] 检测仍照常执行——打点链路不因 parse 失败而断。
#   PARSE_FAIL 审计插桩保留，便于后续收敛。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
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
$text = ""

# 正则提取会话 id（parse 失败兜底；与 mark-changelog-write 同思路）
function Get-ConversationIdFromRaw {
    param([string]$Raw)
    $m = [Regex]::Match($Raw, '"conversation_id"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# 正则提取首个非空文本字段（parse 失败兜底；候选顺序同 Get-AgentText）
function Get-AgentTextFromRaw {
    param([string]$Raw)
    foreach ($name in $textFieldCandidates) {
        $pat = '"' + [Regex]::Escape($name) + '"\s*:\s*"((?:\\.|[^"\\])*)"'
        $m = [Regex]::Match($Raw, $pat)
        if ($m.Success) {
            $s = $m.Groups[1].Value -replace '\\n', "`n" -replace '\\r', "`r" -replace '\\"', '"' -replace '\\\\', '\'
            return @{ Text = $s; Field = $name }
        }
    }
    return @{ Text = ""; Field = "none" }
}

try {
    # 读取 stdin：OpenStandardInput + StreamReader 显式 UTF-8（同 mark-changelog-write，
    # 真实 Cursor 超大 AgentResponse payload 时 Console.In.ReadToEnd 解析失败）。
    $stdinStream = [Console]::OpenStandardInput()
    try {
        $reader = New-Object System.IO.StreamReader($stdinStream, (New-Object System.Text.UTF8Encoding($false)))
        $raw = $reader.ReadToEnd()
        $reader.Close()
    } finally {
        $stdinStream.Dispose()
    }
    $raw = $raw.TrimStart([char]0xFEFF)
    $json = $raw | ConvertFrom-Json -ErrorAction Stop

    $extracted = Get-AgentText -Json $json
    $text = $extracted.Text
    $fieldUsed = $extracted.Field
    $conversationId = if ($json.conversation_id) { [string]$json.conversation_id } else { "unknown" }
} catch {
    # parse 失败（真实大 payload 场景）：fallback 正则提取 conversation_id + 文本，
    # [PM] 检测仍照常执行——打点链路不因 parse 失败而断（2026-08-03 真演修复）。
    # PARSE_FAIL 插桩保留用于收敛（err 区分 JSON 语法错 vs 读取/编码异常）。
    $rawStr = [string]$raw
    $fbConv = Get-ConversationIdFromRaw -Raw $rawStr
    if ($fbConv) { $conversationId = $fbConv }
    $fbText = Get-AgentTextFromRaw -Raw $rawStr
    $text = $fbText.Text
    $fieldUsed = $fbText.Field
    $errMsg = ($_.Exception.Message -replace '\r?\n', ' ')
    $rawLen = if ($null -eq $raw) { -1 } elseif ($raw -is [string]) { $raw.Length } else { -2 }
    Write-MarkAudit "PARSE_FAIL rawLen=$rawLen err=$errMsg field=$fieldUsed conv=$conversationId"
}

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

Write-MarkAudit "conversation=$conversationId field=$fieldUsed hasPm=$hasPmMarker wrote=$wrote"

# afterAgentResponse 无 permission 字段语义；正常退出即可
exit 0
