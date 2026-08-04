<#
.SYNOPSIS
  Summarize .ai-gates/pipeline-outcome.log for last N days (lightweight).

.DESCRIPTION
  Prints: rows, first-pass rate, avg rounds_to_pass, avg repair_rounds, why_multi top.
#>
param(
    [int] $LastDays = 30
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$logPath = Join-Path $repoRoot ".ai-gates/pipeline-outcome.log"
$cutoff = (Get-Date).AddDays(-$LastDays)

Write-Host "=== pipeline outcome (last $LastDays days) ==="

if (-not (Test-Path -LiteralPath $logPath)) {
    Write-Host "missing: $logPath"
    exit 0
}

$rows = @()
Get-Content -LiteralPath $logPath -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    try {
        $o = $line | ConvertFrom-Json
        $ts = [datetime]::Parse($o.ts)
        if ($ts -lt $cutoff) { return }
        $rows += $o
    } catch {
        Write-Host "warn: skip bad line"
    }
}

Write-Host "rows: $($rows.Count)"
if ($rows.Count -eq 0) { exit 0 }

$passRows = @($rows | Where-Object { $_.event -eq 'step_pass' -or $_.event -eq 'close' })
$n = $passRows.Count
if ($n -eq 0) {
    Write-Host "no step_pass/close rows in window"
} else {
    $first = @($passRows | Where-Object { $_.first_pass -eq $true }).Count
    $avgRounds = ($passRows | Measure-Object -Property rounds_to_pass -Average).Average
    $avgRepair = ($passRows | Measure-Object -Property repair_rounds -Average).Average
    $avgFails = ($passRows | Measure-Object -Property verify_fails -Average).Average
    Write-Host ("first_pass_rate: {0}/{1} = {2:P0}" -f $first, $n, ($(if ($n) { $first / $n } else { 0 })))
    Write-Host ("avg_rounds_to_pass: {0:N2}" -f $avgRounds)
    Write-Host ("avg_repair_rounds: {0:N2}" -f $avgRepair)
    Write-Host ("avg_verify_fails: {0:N2}" -f $avgFails)
}

$why = @{}
foreach ($r in $rows) {
    if (-not $r.why_multi -or $r.why_multi -eq 'none') { continue }
    $k = [string]$r.why_multi
    if (-not $why.ContainsKey($k)) { $why[$k] = 0 }
    $why[$k]++
}
Write-Host "why_multi (multi-attempt causes):"
if ($why.Count -eq 0) { Write-Host "  (none)" }
else {
    $why.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Key, $_.Value)
    }
}

$failStop = @($rows | Where-Object { $_.event -eq 'stop_fail' }).Count
Write-Host "stop_fail rows: $failStop"
exit 0