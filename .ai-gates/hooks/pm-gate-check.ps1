# pm-gate-check.ps1
# Cursor preToolUse. Reads stdin and emits permission JSON.
# Deny and allow decisions live in gate-decision.ps1.

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
. (Join-Path $PSScriptRoot 'gate-decision.ps1')

$repoRoot = Get-AiGatesProjectRoot
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$killSwitch = Join-Path $logDir "pm-gate-disabled"
$auditFile = Join-Path $logDir "pm-gate-check.log"

function Write-Audit {
    param([string]$Line)
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $(Redact-HookSecrets $Line)" -Encoding UTF8
    } catch { }
}

function Get-CursorSessionId {
    param($Json, [string]$Raw)
    if ($Json) {
        if ($Json.conversation_id) { return [string]$Json.conversation_id }
        if ($Json.session_id) { return [string]$Json.session_id }
    }
    if ([string]::IsNullOrEmpty($Raw)) { return 'unknown' }
    $head = $Raw
    $cut = [regex]::Match($Raw, '"(?:old_string|new_string|contents|content|patch|diff)"\s*:')
    if ($cut.Success -and $cut.Index -gt 0) { $head = $Raw.Substring(0, $cut.Index) }
    foreach ($key in @('conversation_id', 'session_id')) {
        $m = [regex]::Match($head, ('"' + $key + '"\s*:\s*"((?:\\.|[^"\\])*)"'))
        if ($m.Success -and -not [string]::IsNullOrWhiteSpace($m.Groups[1].Value)) { return $m.Groups[1].Value }
    }
    return 'unknown'
}

function Get-CursorInputPaths {
    param($Json, [string]$Raw, [bool]$ParseFailed)
    if ($ParseFailed) {
        $fromRaw = Get-HookTargetPathFromRaw -Raw $Raw
        if ($fromRaw) { return @($fromRaw) }
        return @()
    }
    $filePath = $null
    if ($Json.tool_input) {
        if ($Json.tool_input.file_path) { $filePath = [string]$Json.tool_input.file_path }
        elseif ($Json.tool_input.path) { $filePath = [string]$Json.tool_input.path }
        elseif ($Json.tool_input.target_notebook) { $filePath = [string]$Json.tool_input.target_notebook }
        elseif ($Json.tool_input.patch) { $filePath = Get-HookTargetPathFromRaw -Raw ([string]$Json.tool_input.patch) }
        elseif ($Json.tool_input.diff) { $filePath = Get-HookTargetPathFromRaw -Raw ([string]$Json.tool_input.diff) }
    }
    if ($filePath) { return @($filePath) }
    return @()
}

# parse_failed_fail_open：解析失败仍放行。window_pm_not_this_turn：120 分钟窗口不是本条判定。
function Emit-Deny {
    param([string]$ConversationId, [string]$Detail, [string]$UserMessage)
    Write-Audit "DENY conversation=$ConversationId detail=$Detail"
    $result = @{
        permission    = "deny"
        user_message  = $UserMessage
        agent_message = "preToolUse: conversation=$ConversationId no fresh [PM] within 120 min ($Detail); deny (hard block, Cursor 2.2+ ask bug; follow user_message escape paths)."
    }
    Write-Output ($result | ConvertTo-Json -Compress)
}

function Emit-CursorVerdict {
    param($Verdict, [string]$ConversationId)
    if ($Verdict.Allow) {
        Write-Audit "ALLOW reason=$($Verdict.Detail)"
        Write-Output (@{ permission = "allow"; reason = [string]$Verdict.Detail } | ConvertTo-Json -Compress)
        return
    }
    Emit-Deny -ConversationId $ConversationId -Detail $Verdict.Detail -UserMessage ([string]$Verdict.Message)
}

if (Test-Path -LiteralPath $killSwitch) {
    Emit-CursorVerdict -Verdict (New-GateVerdict -Allow $true -Detail 'kill_switch_active') -ConversationId ''
    return
}

$raw = ''
$json = $null
$parseFailed = $false
try {
    $raw = Read-HookStdin
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    $parseFailed = $true
}

$sessionId = Get-CursorSessionId -Json $json -Raw $raw
$paths = @(Get-CursorInputPaths -Json $json -Raw $raw -ParseFailed $parseFailed)
$verdict = Resolve-WriteGateVerdictFromFiles -HostName cursor -SessionId $sessionId -Paths $paths -ParseFailed $parseFailed -LogDir $logDir
Emit-CursorVerdict -Verdict $verdict -ConversationId $sessionId
