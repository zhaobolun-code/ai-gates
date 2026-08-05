<#
.SYNOPSIS
  回归索引模块冒烟验证：按 .ai-gates/regression-index.yaml 生成模块级验收清单，
  命中有 golden 场景的条目自动跑 run-unity-verify-golden.ps1，其余标"须人工 Play"，
  汇总写入窗口证据目录 smoke-evidence.md。

.DESCRIPTION
  - -Module PressureManager|DissolveManager|Reaction|all（默认 all）
  - 自动命中规则：golden 场景的 notes/title 与回归场景标题存在子串重叠 → auto-run
  - -SkipUnity：不跑 Unity，仅生成人工核对清单（无 UNITY_EXE 时等价）
  - 证据写入：优先 -OutputDir，否则窗口证据目录，否则 .ai-gates/verify/_smoke-out/
  - 诚实边界：auto-run 绿色 ≠ 业务手测签收；golden 绿 ≠ A# 过（与 run-unity-verify-golden 同约定）

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/verify-regression-smoke.ps1 -Module PressureManager -OutputDir "Assets/Doc/xxx/证据"
#>

[CmdletBinding()]
param(
    [ValidateSet('PressureManager', 'DissolveManager', 'Reaction', 'all')]
    [string]$Module = 'all',
    [switch]$SkipUnity,
    [string]$UnityExe = $env:UNITY_EXE,
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (& git -C $scriptDir rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$repoRoot)) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")).Path
} else {
    $repoRoot = ([string]$repoRoot).Trim()
}

$indexPath = Join-Path $repoRoot ".ai-gates\regression-index.yaml"
$goldenPath = Join-Path $repoRoot ".ai-gates\verify\golden-scenes.yaml"

if (-not (Test-Path -LiteralPath $indexPath)) {
    Write-Error "regression-index.yaml missing: $indexPath (run .ai-gates/scripts/sync-regression-index.ps1 -Apply first)"
    exit 2
}

# --- 解析 YAML（轻量：只读 entries 的 module/scenario/steps/console_keywords） ---
function Read-SimpleYamlEntries {
    param([string]$Path)
    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $trim = $line.Trim()
        if ($trim -match '^-\s*module:\s*(.+)$') {
            if ($current) { $entries.Add($current) }
            $current = [ordered]@{ module = $Matches[1].Trim(); scenario = ''; steps = ''; keywords = @() }
        } elseif ($current -and $trim -match '^scenario:\s*(.+)$') {
            $current.scenario = $Matches[1].Trim()
        } elseif ($current -and $trim -match '^steps:\s*(.+)$') {
            $current.steps = $Matches[1].Trim()
        } elseif ($current -and $trim -match '^\s*-\s*(\S.+)$' -and $current.steps) {
            $current.keywords += $Matches[1].Trim()
        }
    }
    if ($current) { $entries.Add($current) }
    # 注意：PS5.1 中 @() 包 List[object]（内含 OrderedDictionary）会抛 "Argument types do not match"，用 ToArray()
    return $entries.ToArray()
}

function Read-GoldenScenes {
    param([string]$Path)
    $scenes = New-Object System.Collections.Generic.List[object]
    $current = $null
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $trim = $line.Trim()
        if ($trim -match '^-\s*id:\s*(.+)$') {
            if ($current) { $scenes.Add($current) }
            $current = [ordered]@{ id = $Matches[1].Trim(); title = ''; notes = '' }
        } elseif ($current -and $trim -match '^title:\s*(.+)$') {
            $current.title = $Matches[1].Trim()
        } elseif ($current -and $trim -match '^notes:\s*(.+)$') {
            $current.notes = $Matches[1].Trim()
        }
    }
    if ($current) { $scenes.Add($current) }
    return $scenes.ToArray()
}

$entries = @(Read-SimpleYamlEntries -Path $indexPath)
if ($Module -ne 'all') { $entries = @($entries | Where-Object { $_.module -eq $Module }) }
if ($entries.Count -eq 0) {
    Write-Error "no regression-index entries for module=$Module"
    exit 2
}

$scenes = @()
if (Test-Path -LiteralPath $goldenPath) { $scenes = @(Read-GoldenScenes -Path $goldenPath) }

$zhEvidence = [string]([char]0x8BC1) + [char]0x636E  # 证据
if (-not $OutputDir) { $OutputDir = Join-Path $repoRoot ".ai-gates\verify\_smoke-out\$zhEvidence" }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$goldenRunner = Join-Path $scriptDir "run-unity-verify-golden.ps1"
$rows = New-Object System.Collections.Generic.List[string]
$failCount = 0

foreach ($e in $entries) {
    # 与 golden 场景按标题/notes 子串重叠匹配（归一化去空白）
    $norm = $e.scenario -replace '\s+', ''
    $matchScene = $null
    foreach ($s in $scenes) {
        $hay = (($s.title + ' ' + $s.notes) -replace '\s+', '')
        $needle = $norm.Substring(0, [Math]::Min(10, $norm.Length))
        if ($needle.Length -ge 3 -and $hay.Contains($needle)) { $matchScene = $s; break }
    }
    if ($matchScene -and -not $SkipUnity -and $UnityExe) {
        Write-Host "[smoke] auto-run golden $($matchScene.id) for: $($e.scenario)" -ForegroundColor Cyan
        $goldOut = Join-Path $OutputDir ("golden-" + $matchScene.id)
        New-Item -ItemType Directory -Force -Path $goldOut | Out-Null
        & powershell -NoProfile -ExecutionPolicy Bypass -File $goldenRunner -SceneId $matchScene.id -UnityExe $UnityExe -OutputDir $goldOut 2>&1 | Out-String | Write-Host
        $ok = ($LASTEXITCODE -eq 0)
        if (-not $ok) { $failCount++ }
        $rows.Add(("| {0} | {1} | auto (G{2}) | {3} |" -f $e.module, $e.scenario, $matchScene.id, $(if ($ok) { '通过' } else { '失败' }))) | Out-Null
    } else {
        $kw = ($e.keywords | Where-Object { $_ }) -join ' / '
        $rows.Add(("| {0} | {1} | 人工 Play | 步骤：{2}；关键字：{3}" -f $e.module, $e.scenario, $e.steps, $kw)) | Out-Null
    }
}

$md = @(
    "# 回归冒烟验证（$Module · $(Get-Date -Format 'yyyy-MM-dd HH:mm')）"
    ''
    '> 机器自动验证 ≠ 业务手测签收；golden 绿 ≠ A# 过。回归索引行仍须按 A# 人工确认。'
    ''
    '| 模块 | 场景 | 方式 | 说明 |'
    '| --- | --- | --- | --- |'
    ($rows -join "`n")
) -join "`n"

$outFile = Join-Path $OutputDir "smoke-evidence.md"
[System.IO.File]::WriteAllText($outFile, $md, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "smoke evidence: $outFile"
Write-Host ("status: rows={0} auto_fail={1}" -f $rows.Count, $failCount)

# 有 auto 失败时非 0 退出（人工清单场景不产生失败）
if ($failCount -gt 0) { exit 1 }
exit 0
