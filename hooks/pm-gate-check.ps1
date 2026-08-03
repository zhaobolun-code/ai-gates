# pm-gate-check.ps1
# preToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 支柱 D。
#
# 目的：机械化 CORE.md 硬门禁 #7 的近似版本——"最近 N 分钟内这个会话（conversation_id）
# 有没有出现过 [PM] 标记"，标记由 mark-pm-gate.ps1（afterAgentResponse）写入
# .cursor/hooks-log/pm-gate.json。已知局限见该脚本头部注释：这是"最近判定过"而不是
# "同条判定"的机械近似，不是精确复刻 CORE 文字规则。
#
# 行为（与 MAINTAINER §Cursor Hooks 一致 · observe/ask）：
#   非 .cursor/** 且无新鲜 [PM] 标记 → permission=ask（人工确认；不是 deny）
#   解析异常 → fail-open allow（避免 hook/落盘故障把人逼进死路）
#   hooks.json 对本 hook 须 failClosed=false
#
# allow 旁路：
#   1. .cursor/** 下的改动永远 allow——自救通道。
#   2. Kill switch：存在 .cursor/hooks-log/pm-gate-disabled 时整条检查临时关闭（仍写审计）。
#   3. 该 conversation_id 在新鲜度窗口内有有效 [PM] 标记 → allow。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$hooksDir = Join-Path $PSScriptRoot ".."
$logDir = Join-Path $hooksDir "hooks-log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$gateFile = Join-Path $logDir "pm-gate.json"
$killSwitch = Join-Path $logDir "pm-gate-disabled"
$auditFile = Join-Path $logDir "pm-gate-check.log"

$FreshnessMinutes = 120

function Write-Audit {
    param([string]$Line)
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
    }
}

function Test-CursorInfraPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    return ($FilePath -match '[\\/]\.cursor[\\/]' -or $FilePath -match '^\.cursor[\\/]')
}

function Get-PathFromRaw {
    param([string]$Raw)
    foreach ($pat in @(
        '"file_path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"target_notebook"\s*:\s*"((?:\\.|[^"\\])*)"'
    )) {
        $m = [Regex]::Match($Raw, $pat)
        if ($m.Success) {
            $s = $m.Groups[1].Value -replace '\\/', '/' -replace '\\\\', '\'
            return $s
        }
    }
    return $null
}

function Emit-Allow {
    param([string]$Reason)
    Write-Audit "ALLOW reason=$Reason"
    Write-Output '{"permission":"allow"}'
    exit 0
}

function Emit-Ask {
    param([string]$ConversationId, [string]$Detail)
    Write-Audit "ASK conversation=$ConversationId detail=$Detail"
    $userMsg = "PM gate ask detail=$Detail : no fresh [PM] marker detected. Confirm to continue write, or emit [PM] first / edit .cursor path / place hooks-log/pm-gate-disabled."
    $agentMsg = "preToolUse: conversation=$ConversationId no fresh [PM] within $FreshnessMinutes min ($Detail); ask (not deny)."
    $result = @{
        permission    = "ask"
        user_message  = $userMsg
        agent_message = $agentMsg
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}

# kill switch first (no stdin parse needed)
if (Test-Path -LiteralPath $killSwitch) {
    Emit-Allow "kill_switch_active"
}

$raw = ""
try {
    $raw = [Console]::In.ReadToEnd()
    $raw = $raw.TrimStart([char]0xFEFF)
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    $fallbackPath = Get-PathFromRaw -Raw $raw
    if (Test-CursorInfraPath -FilePath $fallbackPath) {
        Emit-Allow "cursor_infra_path_exempt_parse_fallback"
    }
    # fail-open：解析失败不硬拦（与 MAINTAINER 一致；避免 mark 落盘故障连环死路）
    Emit-Allow "parse_failed_fail_open"
}

$conversationId = if ($json.conversation_id) { [string]$json.conversation_id } else { "unknown" }

$filePath = $null
if ($json.tool_input) {
    if ($json.tool_input.file_path) { $filePath = [string]$json.tool_input.file_path }
    elseif ($json.tool_input.path) { $filePath = [string]$json.tool_input.path }
    elseif ($json.tool_input.target_notebook) { $filePath = [string]$json.tool_input.target_notebook }
}

if (Test-CursorInfraPath -FilePath $filePath) {
    Emit-Allow "cursor_infra_path_exempt"
}

if (-not (Test-Path -LiteralPath $gateFile)) {
    Emit-Ask -ConversationId $conversationId -Detail "gate_file_missing"
}

try {
    $gateRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
    $gate = $gateRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Emit-Ask -ConversationId $conversationId -Detail "gate_file_unreadable"
}

$entry = $gate.$conversationId
if (-not $entry -or -not $entry.lastPmAtUtc) {
    Emit-Ask -ConversationId $conversationId -Detail "no_pm_marker_for_conversation"
}

try {
    $lastPmUtc = [DateTime]::Parse($entry.lastPmAtUtc).ToUniversalTime()
} catch {
    Emit-Ask -ConversationId $conversationId -Detail "timestamp_unparseable"
}

$ageMinutes = ([DateTime]::UtcNow - $lastPmUtc).TotalMinutes
if ($ageMinutes -gt $FreshnessMinutes) {
    Emit-Ask -ConversationId $conversationId -Detail ("stale_pm_marker_age={0}min" -f [Math]::Round($ageMinutes,1))
}

Emit-Allow ("fresh_pm_marker_age={0}min" -f [Math]::Round($ageMinutes,1))
