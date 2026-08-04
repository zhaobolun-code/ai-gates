# sync-regression-index.ps1 — compare/regenerate .ai-gates/regression-index.yaml from .cursor/project-context.md (v2.1.0)
# MD table is authoritative. Default: warn on drift; -Strict exits 1; -Apply regenerates YAML from MD (removes manual dual-write).
# Usage:
#   .\sync-regression-index.ps1              # check only, warn on drift
#   .\sync-regression-index.ps1 -Strict       # check only, exit 1 on drift
#   .\sync-regression-index.ps1 -Apply        # regenerate YAML from MD, no drift possible after this

param([switch]$Strict, [switch]$Apply)

$ErrorActionPreference = "Stop"
$warnings = @()
$errors = @()

function Add-Issue($level, $message) {
    if ($level -eq "error") { $script:errors += $message }
    else { $script:warnings += $message }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}
$mdPath = Join-Path $repoRoot ".cursor/project-context.md"
$yamlPath = Join-Path $repoRoot ".ai-gates/regression-index.yaml"
$templatePath = Join-Path $repoRoot ".cursor/skills/references/regression-index.template.yaml"

if (-not (Test-Path -LiteralPath $mdPath)) {
    Write-Host "SKIP: Missing $mdPath — run init-project-context.ps1 or copy project-context.template.md" -ForegroundColor Yellow
    exit 0
}
if (-not (Test-Path -LiteralPath $yamlPath)) {
    Add-Issue "error" "Missing project regression index: $yamlPath — copy from $templatePath"
    foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }
    exit 1
}

$mdContent = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
$yamlContent = Get-Content -LiteralPath $yamlPath -Raw -Encoding UTF8

# Parse MD table rows under ## 运行回归索引 (skip header + separator)
$mdEntries = @()
if ($mdContent -match '(?ms)^##\s+运行回归索引\s*\r?\n(.*?)(?=^##\s|\z)') {
    $section = $Matches[1]
    foreach ($line in ($section -split '\r?\n')) {
        if ($line -notmatch '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$') { continue }
        $mod = $Matches[1].Trim()
        $scn = $Matches[2].Trim()
        $steps = $Matches[3].Trim()
        $kw = $Matches[4].Trim()
        if ($mod -match '^-+$' -or $mod -eq '模块') { continue }
        $mdEntries += [PSCustomObject]@{ Module = $mod; Scenario = $scn; Steps = $steps; Keywords = $kw }
    }
} else {
    Add-Issue "error" "Could not find ## 运行回归索引 section in project-context.md"
}

if ($Apply) {
    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }
        Write-Host "ABORT: cannot -Apply, MD table unparsable." -ForegroundColor Red
        exit 1
    }
    $lines = @()
    $lines += "# 运行回归索引（本项目脚本可读副本 — 由 sync-regression-index.ps1 -Apply 自动生成，勿手工编辑）"
    $lines += "# 权威来源：.cursor/project-context.md「运行回归索引」表"
    $lines += "# 重新生成：powershell -ExecutionPolicy Bypass -File .cursor/scripts/sync-regression-index.ps1 -Apply"
    $lines += ""
    $lines += "version: 1"
    $lines += "entries:"
    foreach ($e in $mdEntries) {
        $kwList = @($e.Keywords -split '\s*、\s*|\s*,\s*' | Where-Object { $_ } | ForEach-Object { $_ -replace '^`|`$', '' })
        $lines += "  - module: $($e.Module)"
        $lines += "    scenario: $($e.Scenario)"
        $lines += "    steps: $($e.Steps -replace '"', '\"')"
        $lines += "    console_keywords:"
        foreach ($kw in $kwList) { $lines += "      - $kw" }
        $lines += ""
    }
    Set-Content -LiteralPath $yamlPath -Value ($lines -join "`r`n") -Encoding UTF8
    Write-Host "APPLIED: regenerated $yamlPath from MD ($($mdEntries.Count) entries). YAML/MD 双写风险已消除。" -ForegroundColor Green
    exit 0
}

# Parse YAML entries (- module: / scenario:)
$yamlEntries = @()
$yamlBlocks = [regex]::Matches($yamlContent, '(?ms)-\s*module:\s*(.+?)\r?\n\s*scenario:\s*(.+?)(?:\r?\n|$)')
foreach ($m in $yamlBlocks) {
    $yamlEntries += [PSCustomObject]@{
        Module   = $m.Groups[1].Value.Trim()
        Scenario = $m.Groups[2].Value.Trim()
    }
}

Write-Host "sync-regression-index: MD=$($mdEntries.Count) YAML=$($yamlEntries.Count)"

if ($mdEntries.Count -ne $yamlEntries.Count) {
    Add-Issue "warning" "Entry count mismatch: MD=$($mdEntries.Count) YAML=$($yamlEntries.Count)"
}

function Key($e) { return ($e.Module + '|' + $e.Scenario) }

$mdKeys = @($mdEntries | ForEach-Object { Key $_ })
$yamlKeys = @($yamlEntries | ForEach-Object { Key $_ })

foreach ($k in $mdKeys) {
    if ($yamlKeys -notcontains $k) {
        Add-Issue "warning" "In MD but not YAML: $k"
    }
}
foreach ($k in $yamlKeys) {
    if ($mdKeys -notcontains $k) {
        Add-Issue "warning" "In YAML but not MD: $k"
    }
}

foreach ($w in $warnings) { Write-Host "WARN: $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }

if ($errors.Count -gt 0) { exit 1 }
if ($Strict -and $warnings.Count -gt 0) { exit 1 }
if ($warnings.Count -eq 0) { Write-Host "OK: MD and YAML regression index aligned." -ForegroundColor Green }
exit 0
