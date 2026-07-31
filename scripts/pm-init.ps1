# pm-init.ps1 — PM 初始化：探测 + 安全创建（半自动）
# Usage (repo root):
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -DocRoot "Assets/Doc"
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -InstallCodeGraph
#
# Default is probe-only. -Apply creates missing project-context (via init-project-context.ps1)
# and missing doc root dirs. -InstallCodeGraph only after explicit user consent.

param(
    [switch]$Apply,
    [string]$DocRoot = "Assets/Doc",
    [switch]$InstallCodeGraph
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

function Write-Status([string]$Name, [string]$State, [string]$Detail = "") {
    $line = "[$Name] $State"
    if ($Detail) { $line = "$line — $Detail" }
    Write-Host $line
}

$ctx = Join-Path $repoRoot ".cursor/project-context.md"
$yaml = Join-Path $repoRoot ".cursor/regression-index.yaml"
$codegraphDir = Join-Path $repoRoot ".codegraph"
$docAbs = Join-Path $repoRoot $DocRoot
$weeklyAbs = Join-Path $docAbs "Weekly"
$initScript = Join-Path $scriptDir "init-project-context.ps1"

Write-Host "=== PM Init probe ===" -ForegroundColor Cyan
Write-Host "repo: $repoRoot"

$ctxState = if (Test-Path -LiteralPath $ctx) { "present" } else { "missing" }
Write-Status "project-context" $ctxState $ctx

$yamlState = if (Test-Path -LiteralPath $yaml) { "present" } else { "missing" }
Write-Status "regression-index.yaml" $yamlState $yaml

$docState = if (Test-Path -LiteralPath $docAbs) { "present" } else { "missing" }
Write-Status "doc-root" $docState $DocRoot

$cgCli = Get-Command codegraph -ErrorAction SilentlyContinue
$cgDirOk = Test-Path -LiteralPath $codegraphDir
if ($cgDirOk -and $cgCli) { Write-Status "CodeGraph" "ready" ".codegraph/ + CLI" }
elseif ($cgDirOk) { Write-Status "CodeGraph" "partial" ".codegraph/ exists; CLI or MCP may need reload" }
elseif ($cgCli) { Write-Status "CodeGraph" "partial" "CLI found; run: codegraph init" }
else { Write-Status "CodeGraph" "missing" "need: codegraph install --platform cursor && codegraph init" }

if (-not $Apply) {
    Write-Host ""
    Write-Host "Probe only. Re-run with -Apply to create missing context/doc dirs." -ForegroundColor DarkGray
    Write-Host "After user consent, add -InstallCodeGraph to attempt CodeGraph setup." -ForegroundColor DarkGray
    exit 0
}

Write-Host ""
Write-Host "=== Apply ===" -ForegroundColor Cyan

if ($ctxState -eq "missing") {
    if (-not (Test-Path -LiteralPath $initScript)) {
        Write-Error "Missing $initScript"
        exit 1
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $initScript
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "Skip context create (already exists)." -ForegroundColor DarkGray
}

if (-not (Test-Path -LiteralPath $docAbs)) {
    New-Item -ItemType Directory -Force -Path $docAbs | Out-Null
    Write-Host "Created doc root: $DocRoot" -ForegroundColor Green
} else {
    Write-Host "Doc root exists: $DocRoot" -ForegroundColor DarkGray
}
if (-not (Test-Path -LiteralPath $weeklyAbs)) {
    New-Item -ItemType Directory -Force -Path $weeklyAbs | Out-Null
    Write-Host "Created: $DocRoot/Weekly" -ForegroundColor Green
}

if ($DocRoot -ne "Assets/Doc" -and $DocRoot -ne "Assets\Doc") {
    Write-Host "NOTE: DocRoot='$DocRoot' differs from default Assets/Doc — Agent must update project-context doc path section." -ForegroundColor Yellow
}

if ($InstallCodeGraph) {
    Write-Host ""
    Write-Host "=== CodeGraph install ===" -ForegroundColor Cyan
    if (-not $cgCli) {
        Write-Host "codegraph CLI not on PATH. Manual install required:" -ForegroundColor Yellow
        Write-Host "  codegraph install --platform cursor"
        Write-Host "  codegraph init"
        Write-Host "Then reload Cursor window / check .cursor/mcp.json" -ForegroundColor DarkGray
        exit 2
    }
    if (-not $cgDirOk) {
        Write-Host "Running: codegraph init"
        & codegraph init
        if ($LASTEXITCODE -ne 0) {
            Write-Host "codegraph init failed (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "Skip codegraph init (.codegraph/ exists)." -ForegroundColor DarkGray
    }
    Write-Host "Try: codegraph install --platform cursor"
    & codegraph install --platform cursor
    if ($LASTEXITCODE -ne 0) {
        Write-Host "codegraph install returned $LASTEXITCODE — check MCP / reload Cursor." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Still fill by hand: tech stack, Express upgrade table, regression index (>=1-2 rows) in .cursor/project-context.md"
Write-Host "Then: powershell -ExecutionPolicy Bypass -File .cursor/scripts/sync-regression-index.ps1 -Apply"
exit 0
