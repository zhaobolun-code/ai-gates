<#
.SYNOPSIS
  Append one lightweight outcome row to .cursor/pipeline-outcome.log (JSONL).
#>
param(
    [ValidateSet('step_pass', 'close', 'stop_fail')]
    [string] $Event = 'step_pass',

    [Parameter(Mandatory = $true)]
    [string] $Doc,

    [ValidateSet('Express', 'Standard', 'Full', '')]
    [string] $Lane = '',

    [int] $Steps = 1,

    [int] $RepairRounds = 0,

    [int] $VerifyFails = 0,

    [int] $RoundsToPass = 1,

    [switch] $MultiAttempt,

    [ValidateSet('none', 'spec_drift', 'dual_track', 'semantic', 'test_method', 'scope', 'other')]
    [string] $WhyMulti = 'none',

    [string] $StopCount = '',

    [string] $Note = ''
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$logPath = Join-Path $repoRoot ".cursor/pipeline-outcome.log"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null

if (-not (Test-Path -LiteralPath $logPath)) {
    @(
        "# pipeline-outcome.log — JSONL, one object per line"
        "# Template: .cursor/skills/templates/pipeline-outcome-log.md"
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8
}

$firstPass = -not $MultiAttempt.IsPresent
if (-not $firstPass -and $WhyMulti -eq 'none') {
    throw "MultiAttempt requires -WhyMulti other than none"
}
if ($firstPass) { $WhyMulti = 'none' }
if ($RoundsToPass -lt 1) { $RoundsToPass = 1 }

$row = [ordered]@{
    ts              = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    event           = $Event
    doc             = $Doc
    steps           = $Steps
    repair_rounds   = $RepairRounds
    verify_fails    = $VerifyFails
    rounds_to_pass  = $RoundsToPass
    first_pass      = $firstPass
    why_multi       = $WhyMulti
}
if ($Lane) { $row.lane = $Lane }
if ($StopCount) { $row.stop_count = $StopCount }
if ($Note) { $row.note = $Note }

$line = ($row | ConvertTo-Json -Compress)
Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
Write-Host "appended to $logPath"
Write-Host $line