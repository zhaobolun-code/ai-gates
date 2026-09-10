# test-plugin-hook-skip.ps1 — 插件通道在项目 hooks 落地后必须空跑。
# Usage:
#   powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/test-plugin-hook-skip.ps1

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$hooksDir = Join-Path (Split-Path $scriptDir -Parent) 'hooks'
$common = Join-Path $hooksDir 'cursor-hooks-common.ps1'
$invoke = Join-Path $hooksDir 'plugin\invoke.ps1'
if (-not (Test-Path -LiteralPath $common)) { throw "missing $common" }
if (-not (Test-Path -LiteralPath $invoke)) { throw "missing $invoke" }

$failed = 0
function Assert-True {
    param([bool]$Cond, [string]$Name)
    if ($Cond) { Write-Host "PASS $Name" -ForegroundColor Green }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

$tmp = Join-Path $env:TEMP ("ai-gates-hook-skip-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path (Join-Path $tmp '.cursor\hooks') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $tmp '.cursor\hooks.json') -Value '{"version":1}' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $tmp '.cursor\hooks\pre-write-gate.ps1') -Value '# dummy' -Encoding UTF8

$oldPlugin = $env:CURSOR_PLUGIN_ROOT
$oldProject = $env:CURSOR_PROJECT_DIR
try {
    $env:CURSOR_PROJECT_DIR = $tmp
    $env:CURSOR_PLUGIN_ROOT = Join-Path $tmp 'fake-plugin'
    . $common
    Assert-True -Cond ((Get-AiGatesHookChannel) -eq 'plugin') -Name 'channel=plugin'
    Assert-True -Cond (-not (Test-AiGatesShouldRunHook)) -Name 'plugin skip when project hooks present'

    Remove-Item -LiteralPath (Join-Path $tmp '.cursor\hooks\pre-write-gate.ps1') -Force
    Assert-True -Cond (Test-AiGatesShouldRunHook) -Name 'plugin runs when project gate script missing'

    Set-Content -LiteralPath (Join-Path $tmp '.cursor\hooks\pre-write-gate.ps1') -Value '# dummy' -Encoding UTF8
    $env:CURSOR_PLUGIN_ROOT = $null
    Assert-True -Cond ((Get-AiGatesHookChannel) -eq 'project') -Name 'channel=project'
    Assert-True -Cond (Test-AiGatesShouldRunHook) -Name 'project channel always runs'

    $env:CURSOR_PLUGIN_ROOT = Join-Path $tmp 'fake-plugin'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$invoke`" -Target git-safety-check"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['CURSOR_PLUGIN_ROOT'] = $env:CURSOR_PLUGIN_ROOT
    $psi.EnvironmentVariables['CURSOR_PROJECT_DIR'] = $tmp
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write('{"command":"git status"}')
    $p.StandardInput.Close()
    $stdout = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    Assert-True -Cond ($stdout -match '"permission"\s*:\s*"allow"') -Name 'invoke skip stdout allow'
    Assert-True -Cond ($p.ExitCode -eq 0) -Name 'invoke skip exit 0'
} finally {
    $env:CURSOR_PLUGIN_ROOT = $oldPlugin
    $env:CURSOR_PROJECT_DIR = $oldProject
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) {
    Write-Host "FAILED $failed" -ForegroundColor Red
    exit 1
}
Write-Host 'OK test-plugin-hook-skip'
exit 0
