# pm-gate-check.ps1
# preToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 支柱 D。
#
# 目的：机械化 CORE.md 硬门禁 #7 的近似版本——"最近 N 分钟内这个会话（conversation_id）
# 有没有出现过 [PM] 标记"，标记由 mark-pm-gate.ps1（afterAgentResponse）写入
# .cursor/hooks-log/pm-gate.json。已知局限见该脚本头部注释：这是"最近判定过"而不是
# "同条判定"的机械近似，不是精确复刻 CORE 文字规则。
#
# 业务默认（互斥）：非 .cursor/** 且无新鲜标记 → permission=deny（不再 ask）。
# 禁止业务路径 fail-open allow。解析异常时：能识别 .cursor/** 则 allow（自救）；
# 否则 deny（fail-closed，勿静默 allow 业务写）。与 hooks.json failClosed=true 互补
# （能跑→deny JSON；跑不起来→Cursor 拦写）。
#
# allow 仅旁路（与 deny 互斥，不得叠 ask）：
#   1. .cursor/** 下的改动永远 allow——自救通道，防止硬门禁锁死自己。
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

function Emit-Deny {
    param([string]$ConversationId, [string]$Detail)
    Write-Audit "DENY conversation=$ConversationId detail=$Detail"
    $userMsg = "PM gate deny detail=$Detail : business write blocked. Emit [PM] first, or edit .cursor path / place hooks-log/pm-gate-disabled."
    $agentMsg = "preToolUse: conversation=$ConversationId no fresh [PM] within $FreshnessMinutes min ($Detail); deny (not ask)."
    $result = @{
        permission    = "deny"
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
    Emit-Deny -ConversationId "unknown" -Detail "parse_failed"
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
    Emit-Deny -ConversationId $conversationId -Detail "gate_file_missing"
}

try {
    $gateRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
    $gate = $gateRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Emit-Deny -ConversationId $conversationId -Detail "gate_file_unreadable"
}

$entry = $gate.$conversationId
if (-not $entry -or -not $entry.lastPmAtUtc) {
    Emit-Deny -ConversationId $conversationId -Detail "no_pm_marker_for_conversation"
}

try {
    $lastPmUtc = [DateTime]::Parse($entry.lastPmAtUtc).ToUniversalTime()
} catch {
    Emit-Deny -ConversationId $conversationId -Detail "timestamp_unparseable"
}

$ageMinutes = ([DateTime]::UtcNow - $lastPmUtc).TotalMinutes
if ($ageMinutes -gt $FreshnessMinutes) {
    Emit-Deny -ConversationId $conversationId -Detail ("stale_pm_marker_age={0}min" -f [Math]::Round($ageMinutes,1))
}

Emit-Allow ("fresh_pm_marker_age={0}min" -f [Math]::Round($ageMinutes,1))
