# mark-pm-gate.ps1 -- Codex 版
# Stop hook -- observation only, never blocks（Codex Stop 事件输出无拦截语义）。
#
# Cursor 原版挂 afterAgentResponse（AgentResponse matcher）；Codex 等价映射为 Stop 事件
# （实测 payload 含 last_assistant_message / session_id）。目的：把"这轮回复里出现过
# [PM] 标记"写进带时间戳、按 session_id 分桶的 pm-gate.json，供 pm-gate-check.ps1
# （PreToolUse）在下一次 apply_patch 时读取判断是否放行。
#
# 已知局限（与 Cursor 版一致，如实记录）：Stop 在"该条助手消息完整生成后"触发，所以
# 标记只能证明"之前某一轮完整回复里出现过 [PM]"，不能证明"当前同一条回复里先 [PM] 后
# 写"——Codex 与 Cursor 一样拿不到尚未完成的助手文本。效果等价于把 CORE 硬门禁 #7 的
# "同条先 PM"退化成机械可查的"最近 N 分钟内该会话有没有 PM 判定过"。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$gateFile = Join-Path $LogDir 'pm-gate.json'

$raw = Read-HookStdin
$sessionId = "unknown"
$fieldUsed = "none"
$text = ""
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $sessionId = Get-SessionId -Json $json -Raw $raw
    $v = Get-Property $json 'last_assistant_message'
    if ($v) { $text = [string]$v; $fieldUsed = 'last_assistant_message' }
} catch {
    # parse 失败兜底：正则提取 session_id + last_assistant_message，[PM] 检测仍执行
    $m = [Regex]::Match($raw, '"session_id"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m.Success) { $sessionId = $m.Groups[1].Value }
    $m2 = [Regex]::Match($raw, '"last_assistant_message"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m2.Success) {
        $text = $m2.Groups[1].Value -replace '\\n', "`n" -replace '\\r', "`r" -replace '\\"', '"' -replace '\\\\', '\'
        $fieldUsed = 'last_assistant_message(regex)'
    }
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("PARSE_FAIL session={0} field={1}" -f $sessionId, $fieldUsed)
}

# [PM] 作为岗位标记出现（CORE.md：首行标记 [PM]）；不要求必须在行首，宁可宽松不漏判。
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
    $gate[$sessionId] = [ordered]@{
        lastPmAtUtc = [DateTime]::UtcNow.ToString('o')
        snippet     = $snippet
        sourceField = $fieldUsed
    }
    $json2 = $gate | ConvertTo-Json -Depth 6
    Write-JsonAtomic -Path $gateFile -Content $json2
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("session={0} field={1} hasPm=True wrote=pm-gate.json" -f $sessionId, $fieldUsed)
} else {
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("session={0} field={1} hasPm=False wrote=none" -f $sessionId, $fieldUsed)
}

Emit-StopEmpty
