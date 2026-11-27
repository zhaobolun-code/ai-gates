<#
.SYNOPSIS
  Append one lightweight outcome row to .ai-gates/pipeline-outcome.log (JSONL).
#>
param(
    [ValidateSet('step_pass', 'step_fail', 'close', 'stop_fail', 'ai_pass', 'human_fail', 'human_pass')]
    [string] $Event = 'step_pass',

    [Parameter(Mandatory = $true)]
    [string] $Doc,

    [ValidateSet('Express', 'Direct', 'Standard', 'Full', '')]
    [string] $Lane = '',

    [int] $Steps = 1,

    [int] $RepairRounds = 0,

    [int] $VerifyFails = 0,

    [int] $RoundsToPass = 1,

    [switch] $MultiAttempt,

    [ValidateSet('none', 'spec_drift', 'dual_track', 'semantic', 'test_method', 'scope', 'other')]
    [string] $WhyMulti = 'none',

    [string] $StopCount = '',

    [string] $Note = '',

    [string[]] $Files = @(),

    [string] $Module = '',

    [string] $HeatPath = '',

    [string] $OutcomeLog = '',

    [string] $DirectLogRoot = ''
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

. (Join-Path $scriptDir 'file-heat-lib.ps1')
if ([string]::IsNullOrWhiteSpace($HeatPath)) { $HeatPath = Join-Path $repoRoot ".ai-gates\regression-heat.yaml" }
if ([string]::IsNullOrWhiteSpace($OutcomeLog)) { $logPath = Join-Path $repoRoot ".ai-gates/pipeline-outcome.log" } else { $logPath = $OutcomeLog }
if ([string]::IsNullOrWhiteSpace($DirectLogRoot)) {
    $zhTong = -join (@(0x76F4, 0x901A, 0x6587, 0x6863) | ForEach-Object { [char]$_ })
    $DirectLogRoot = Join-Path $repoRoot (Join-Path ".ai-gates\Doc" $zhTong)
}
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
$fileEvent = $Event -in @('ai_pass', 'human_fail', 'human_pass')
$cleanFiles = @($Files | ForEach-Object { Convert-HeatPath $_ } | Where-Object { $_ })
if ($fileEvent -and $cleanFiles.Count -eq 0) { throw "-Files is required for $Event" }
if ($cleanFiles.Count -gt 0) { $row.files = @($cleanFiles) }

$line = ($row | ConvertTo-Json -Compress)
Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
Write-Host "appended to $logPath"
Write-Host $line

$heatDoc = Read-RegressionHeatDocument -Path $HeatPath
$wroteHeat = $false
if ($Event -in @('step_fail', 'stop_fail', 'human_fail')) {
    $modName = $Module
    if ([string]::IsNullOrWhiteSpace($modName)) { $modName = Get-ModuleFromDoc -Doc $Doc }
    $entry = Add-ModuleHeatFailure -Entries $heatDoc.Entries -Module $modName -FailTs (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK") -StopCount $StopCount -RepairRounds $RepairRounds
    $wroteHeat = $true
    Write-Host "module heat: $modName fail_count=$($entry.fail_count) heat=$($entry.heat)"
}
if ($fileEvent) {
    $day = Get-Date -Format "yyyy-MM-dd"
    Apply-FileHeatEvent -Files $heatDoc.Files -Event $Event -Paths $cleanFiles -Day $day
    Clear-ExpiredFileHeat -Files $heatDoc.Files -Now (Get-Date)
    $modName = $Module
    if ([string]::IsNullOrWhiteSpace($modName)) { $modName = Get-ModuleFromDoc -Doc $Doc }
    $logFile = Write-DirectLogEntry -Root $DirectLogRoot -Module $modName -Event $Event -Paths $cleanFiles -Note $Note -Ts $row.ts
    $wroteHeat = $true
    Write-Host "direct log: $logFile"
}
if ($wroteHeat) {
    Write-RegressionHeatDocument -Path $HeatPath -Entries $heatDoc.Entries -Files $heatDoc.Files
    Write-Host "regression heat updated: $HeatPath"
}
