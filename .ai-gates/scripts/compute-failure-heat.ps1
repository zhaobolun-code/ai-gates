<#
.SYNOPSIS
  从 .ai-gates/pipeline-outcome.log 重算回归热度，写入 .ai-gates/regression-heat.yaml。
  （append-pipeline-outcome.ps1 在失败事件时增量更新；本脚本用于重算/防丢。）

.DESCRIPTION
  - 聚合事件 step_fail / stop_fail / human_fail，按 doc 路径推断模块。
  - 文件次数按日志重放 ai_pass / human_fail / human_pass。近 20 天没有新的人测失败则归零。
  - heat 档位：fail_count>=3 或 max_stop_count>=2 → high；==2 或 max_stop_count==1 → medium；否则 low
  - 幂等：可反复运行；勿手工编辑输出文件

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/compute-failure-heat.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (& git -C $scriptDir rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$repoRoot)) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")).Path
} else {
    $repoRoot = ([string]$repoRoot).Trim()
}

$logPath = Join-Path $repoRoot ".ai-gates\pipeline-outcome.log"
$heatPath = Join-Path $repoRoot ".ai-gates\regression-heat.yaml"

if (-not (Test-Path -LiteralPath $logPath)) {
    Write-Error "pipeline-outcome.log not found: $logPath"
    exit 2
}

. (Join-Path $scriptDir 'file-heat-lib.ps1')

$agg = @{}
$fileRows = New-Object System.Collections.Generic.List[object]
foreach ($line in (Get-Content -LiteralPath $logPath -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    try {
        $row = $line | ConvertFrom-Json -ErrorAction Stop
    } catch { continue }
    if ($row.event -in @('ai_pass', 'human_fail', 'human_pass') -and $row.files) {
        $fileRows.Add($row) | Out-Null
    }
    if ($row.event -notin @('step_fail', 'stop_fail', 'human_fail')) { continue }
    $mod = Get-ModuleFromDoc -Doc ([string]$row.doc)
    if (-not $agg.ContainsKey($mod)) {
        $agg[$mod] = [ordered]@{ last_fail_ts = ''; fail_count = 0; max_stop_count = 0 }
    }
    $e = $agg[$mod]
    $e.fail_count = $e.fail_count + 1
    $stop = 0
    if ($row.stop_count -match '^(\d+)/') { $stop = [int]$Matches[1] }
    if ([int]$row.repair_rounds -gt $stop) { $stop = [int]$row.repair_rounds }
    if ($stop -gt $e.max_stop_count) { $e.max_stop_count = $stop }
    $ts = [string]$row.ts
    if ($ts -gt $e.last_fail_ts) { $e.last_fail_ts = $ts }
}

$entries = New-Object System.Collections.Generic.List[object]
foreach ($mod in ($agg.Keys | Sort-Object)) {
    $e = $agg[$mod]
    $heat = 'low'
    if ($e.fail_count -ge 3 -or $e.max_stop_count -ge 2) { $heat = 'high' }
    elseif ($e.fail_count -eq 2 -or $e.max_stop_count -eq 1) { $heat = 'medium' }
    [void]$entries.Add([ordered]@{
        module = $mod; last_fail_ts = $e.last_fail_ts; fail_count = $e.fail_count
        max_stop_count = $e.max_stop_count; heat = $heat
    })
}
$files = New-Object System.Collections.Generic.List[object]
foreach ($row in $fileRows) {
    $day = ([string]$row.ts)
    if ($day.Length -ge 10) { $day = $day.Substring(0, 10) }
    Apply-FileHeatEvent -Files $files -Event ([string]$row.event) -Paths @($row.files) -Day $day
}
Clear-ExpiredFileHeat -Files $files -Now (Get-Date)
Write-RegressionHeatDocument -Path $heatPath -Entries $entries -Files $files
Write-Host "heat written: $heatPath"
Write-Host ("modules: {0}" -f (($agg.Keys | Sort-Object) -join ', '))
exit 0
