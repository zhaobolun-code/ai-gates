# init-project-context.ps1 — 新项目初始化 project-context（v3.2.0）
# Usage: powershell -ExecutionPolicy Bypass -File .cursor/scripts/init-project-context.ps1
#   -Force  overwrite existing .cursor/project-context.md

param([switch]$Force)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$target = Join-Path $repoRoot ".cursor/project-context.md"
$template = Join-Path $repoRoot ".cursor/skills/project-context.template.md"
$yamlTemplate = Join-Path $repoRoot ".cursor/skills/references/regression-index.template.yaml"
$yamlTarget = Join-Path $repoRoot ".cursor/regression-index.yaml"
$recoveryLogTemplate = Join-Path $repoRoot ".cursor/skills/templates/pipeline-recovery-log.md"
$recoveryLogTarget = Join-Path $repoRoot ".cursor/pipeline-recovery-log.md"
$snapshotLogTemplate = Join-Path $repoRoot ".cursor/skills/templates/pipeline-snapshot-log.md"
$snapshotLogTarget = Join-Path $repoRoot ".cursor/pipeline-snapshot.log"

if (-not (Test-Path -LiteralPath $template)) {
    Write-Error "Missing template: $template"
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null

if ((Test-Path -LiteralPath $target) -and -not $Force) {
    Write-Host "Already exists: $target (use -Force to overwrite)" -ForegroundColor Yellow
} else {
    Copy-Item -LiteralPath $template -Destination $target -Force
    Write-Host "Created: $target" -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $yamlTarget)) {
    if (Test-Path -LiteralPath $yamlTemplate) {
        Copy-Item -LiteralPath $yamlTemplate -Destination $yamlTarget -Force
        Write-Host "Created: $yamlTarget (optional; edit entries)" -ForegroundColor Green
    }
} else {
    Write-Host "YAML already exists: $yamlTarget" -ForegroundColor DarkGray
}

if (-not (Test-Path -LiteralPath $recoveryLogTarget)) {
    if (Test-Path -LiteralPath $recoveryLogTemplate) {
        Copy-Item -LiteralPath $recoveryLogTemplate -Destination $recoveryLogTarget -Force
        Write-Host "Created: $recoveryLogTarget (optional recovery metrics)" -ForegroundColor Green
    }
} else {
    Write-Host "Recovery log already exists: $recoveryLogTarget" -ForegroundColor DarkGray
}

if (-not (Test-Path -LiteralPath $snapshotLogTarget)) {
    @(
        "# pipeline-snapshot.log — JSONL, one JSON object per line"
        "# Template: .cursor/skills/templates/pipeline-snapshot-log.md"
    ) | Set-Content -LiteralPath $snapshotLogTarget -Encoding UTF8
    Write-Host "Created: $snapshotLogTarget (optional PM metrics)" -ForegroundColor Green
} else {
    Write-Host "Snapshot log already exists: $snapshotLogTarget" -ForegroundColor DarkGray
}

Write-Host "`nNext steps:"
Write-Host "  1. Edit .cursor/project-context.md (tech stack, Express upgrade table, regression index)"
Write-Host "  2. regression-index.yaml was created alongside — run sync-regression-index.ps1 after editing the MD table"
Write-Host "  3. (Recommended) codegraph install --platform cursor && codegraph init"
Write-Host "Until initialized, Agent uses CORE §无 project-context 冷启动 (missing-coldstart)." -ForegroundColor DarkGray
