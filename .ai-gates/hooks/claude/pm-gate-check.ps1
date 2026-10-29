# pm-gate-check.ps1 -- Claude Code
# Reads stdin and emits permissionDecision JSON.
# Deny and allow decisions live in gate-decision.ps1.

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')
. (Join-Path $PSScriptRoot '..\gate-decision.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$killSwitch = Join-Path $LogDir 'pm-gate-disabled'

if (Test-Path -LiteralPath $killSwitch) {
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW kill_switch_active'
    Write-Output (Emit-PreToolUseAllow)
    return
}

$raw = Read-HookStdin
$json = $null
$parseFailed = $false
try { $json = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $parseFailed = $true }

if ($parseFailed) {
    $paths = @()
    try { $paths = @(Get-TargetPaths -ToolInput $null -Raw $raw) } catch { $paths = @() }
    $sessionId = Get-SessionId -Json $null -Raw $raw
} else {
    $sessionId = Get-SessionId -Json $json -Raw $raw
    $paths = @(Get-TargetPaths -ToolInput $json.tool_input -Raw $raw)
}

$verdict = Resolve-WriteGateVerdictFromFiles -HostName claude -SessionId $sessionId -Paths $paths -ParseFailed $parseFailed -LogDir $LogDir -IncludeClaude $true -RootDocsAreLevel1 $true
if ($verdict.Allow) {
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("ALLOW {0} session={1}" -f $verdict.Detail, $sessionId)
    Write-Output (Emit-PreToolUseAllow)
    return
}
Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail={1}" -f $sessionId, $verdict.Detail)
Write-Output (Emit-PreToolUseDeny -Reason $verdict.Message)
