<#
.SYNOPSIS
  从 .ai-gates/pipeline-outcome.log 重算回归热度，写入 .ai-gates/regression-heat.yaml。
  （append-pipeline-outcome.ps1 在失败事件时增量更新；本脚本用于重算/防丢。）

.DESCRIPTION
  - 聚合事件 step_fail / stop_fail，按 doc 路径推断模块（压力系统→PressureManager、
    溶解→DissolveManager、反应→Reaction，其余 other）
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

function Get-ModuleFromDoc {
    param([string]$Doc)
    if ($Doc -match '压力系统') { return 'PressureManager' }
    if ($Doc -match '溶解') { return 'DissolveManager' }
    if ($Doc -match '反应') { return 'Reaction' }
    return 'other'
}

$agg = @{}
foreach ($line in (Get-Content -LiteralPath $logPath -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    try {
        $row = $line | ConvertFrom-Json -ErrorAction Stop
    } catch { continue }
    if ($row.event -notin @('step_fail', 'stop_fail')) { continue }
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

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 回归热度（自动生成：compute-failure-heat.ps1 从 pipeline-outcome.log 重算）")
[void]$sb.AppendLine("# 用途：plan-review-tiers §L1.5 触发（heat≥medium 或近 6 个月有记录）。勿手工编辑。")
[void]$sb.AppendLine('version: 1')
[void]$sb.AppendLine('entries:')
foreach ($mod in ($agg.Keys | Sort-Object)) {
    $e = $agg[$mod]
    $heat = 'low'
    if ($e.fail_count -ge 3 -or $e.max_stop_count -ge 2) { $heat = 'high' }
    elseif ($e.fail_count -eq 2 -or $e.max_stop_count -eq 1) { $heat = 'medium' }
    [void]$sb.AppendLine("  - module: $mod")
    [void]$sb.AppendLine("    last_fail_ts: $($e.last_fail_ts)")
    [void]$sb.AppendLine("    fail_count: $($e.fail_count)")
    [void]$sb.AppendLine("    max_stop_count: $($e.max_stop_count)")
    [void]$sb.AppendLine("    heat: $heat")
}

[System.IO.File]::WriteAllText($heatPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "heat written: $heatPath"
Write-Host ("modules: {0}" -f (($agg.Keys | Sort-Object) -join ', '))
exit 0
