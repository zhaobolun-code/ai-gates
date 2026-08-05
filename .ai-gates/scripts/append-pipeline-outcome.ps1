<#
.SYNOPSIS
  Append one lightweight outcome row to .ai-gates/pipeline-outcome.log (JSONL).
#>
param(
    [ValidateSet('step_pass', 'step_fail', 'close', 'stop_fail')]
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

$logPath = Join-Path $repoRoot ".ai-gates/pipeline-outcome.log"
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

# ---- 2026-08-05：失败事件同步更新回归热度（.ai-gates/regression-heat.yaml） ----
function Get-ModuleFromDoc {
    param([string]$Doc)
    if ($Doc -match '压力系统') { return 'PressureManager' }
    if ($Doc -match '溶解') { return 'DissolveManager' }
    if ($Doc -match '反应') { return 'Reaction' }
    return 'other'
}

function Update-RegressionHeat {
    param([string]$HeatPath, [string]$Module, [string]$FailTs, [string]$StopCount, [int]$RepairRounds)
    $entries = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $HeatPath) {
        $cur = $null
        foreach ($line in (Get-Content -LiteralPath $HeatPath -Encoding UTF8)) {
            $trim = $line.Trim()
            if ($trim -match '^-\s*module:\s*(.+)$') {
                if ($cur) { $entries.Add($cur) }
                $cur = [ordered]@{ module = $Matches[1].Trim(); last_fail_ts = ''; fail_count = 0; max_stop_count = 0; heat = 'low' }
            } elseif ($cur -and $trim -match '^last_fail_ts:\s*(.+)$') { $cur.last_fail_ts = $Matches[1].Trim() }
            elseif ($cur -and $trim -match '^fail_count:\s*(\d+)') { $cur.fail_count = [int]$Matches[1] }
            elseif ($cur -and $trim -match '^max_stop_count:\s*(\d+)') { $cur.max_stop_count = [int]$Matches[1] }
            elseif ($cur -and $trim -match '^heat:\s*(.+)$') { $cur.heat = $Matches[1].Trim() }
        }
        if ($cur) { $entries.Add($cur) }
    }
    $entry = $entries | Where-Object { $_.module -eq $Module } | Select-Object -First 1
    if (-not $entry) {
        $entry = [ordered]@{ module = $Module; last_fail_ts = ''; fail_count = 0; max_stop_count = 0; heat = 'low' }
        $entries.Add($entry)
    }
    $entry.last_fail_ts = $FailTs
    $entry.fail_count = $entry.fail_count + 1
    $stop = 0
    if ($StopCount -match '^(\d+)/') { $stop = [int]$Matches[1] }
    if ($RepairRounds -gt $stop) { $stop = $RepairRounds }
    if ($stop -gt $entry.max_stop_count) { $entry.max_stop_count = $stop }
    if ($entry.fail_count -ge 3 -or $entry.max_stop_count -ge 2) { $entry.heat = 'high' }
    elseif ($entry.fail_count -eq 2 -or $entry.max_stop_count -eq 1) { $entry.heat = 'medium' }
    else { $entry.heat = 'low' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# 回归热度（自动生成：append-pipeline-outcome.ps1 失败事件更新 / compute-failure-heat.ps1 重算）")
    [void]$sb.AppendLine("# 用途：plan-review-tiers §L1.5 触发（heat≥medium 或近 6 个月有记录）。勿手工编辑。")
    [void]$sb.AppendLine('version: 1')
    [void]$sb.AppendLine('entries:')
    foreach ($e in $entries) {
        [void]$sb.AppendLine("  - module: $($e.module)")
        [void]$sb.AppendLine("    last_fail_ts: $($e.last_fail_ts)")
        [void]$sb.AppendLine("    fail_count: $($e.fail_count)")
        [void]$sb.AppendLine("    max_stop_count: $($e.max_stop_count)")
        [void]$sb.AppendLine("    heat: $($e.heat)")
    }
    [System.IO.File]::WriteAllText($HeatPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "regression heat updated: $HeatPath (module=$Module heat=$($entry.heat) fail_count=$($entry.fail_count))"
}

if ($Event -in @('step_fail', 'stop_fail')) {
    $heatPath = Join-Path $repoRoot ".ai-gates\regression-heat.yaml"
    Update-RegressionHeat -HeatPath $heatPath -Module (Get-ModuleFromDoc -Doc $Doc) -FailTs (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK") -StopCount $StopCount -RepairRounds $RepairRounds
}
