# migrate-pipeline-window.ps1 — 方案夹在状态分类夹间迁移（Move + 改链）
# Usage (repo root):
#   powershell -NoProfile -File .cursor/scripts/migrate-pipeline-window.ps1 -DocFolder ".ai-gates/Doc/.../执行中/foo" -ToCategory 签收
#   powershell -NoProfile -File .cursor/scripts/migrate-pipeline-window.ps1 -DocFolder "..." -ToCategory 失败 -DryRun
#
# 行为：创建目标分类夹 → Move 方案夹（及同名 .meta）→ 改写夹内 **方案文件夹** →
#       repair-doc-crosslinks.ps1 -Path <docRoot> -Apply → REPORT。
# 不改 update-doc-state.ps1 Transition 表（状态机与 Move 分离）。

param(
    [Parameter(Mandatory = $true)]
    [string]$DocFolder,

    [Parameter(Mandatory = $true)]
    [ValidateSet("执行中", "签收", "失败", "回退", "停写", "换层")]
    [string]$ToCategory,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git -C $scriptDir rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "../..")).Path
}

$Categories = @("执行中", "签收", "失败", "回退", "停写", "换层")
$CategoryAlt = ($Categories | ForEach-Object { [regex]::Escape($_) }) -join "|"

function Resolve-DefaultDocRoot {
    param([string]$RepoRoot)
    $fallback = ".ai-gates/Doc"
    $pc = Join-Path $RepoRoot ".cursor/project-context.md"
    if (-not (Test-Path -LiteralPath $pc)) { return $fallback }
    $raw = Get-Content -LiteralPath $pc -Raw -Encoding UTF8
    if ($raw -match '(?ms)^##\s+执行文档存放约定\s*\r?\n(.*?)(?=^##\s|\z)') {
        $section = $Matches[1]
        if ($section -match '`((?:Assets/)[^`]*?化学文档/压力系统)(?:/\{方案短名\}/|/)?`') {
            return ($Matches[1] -replace '\\', '/').TrimEnd('/')
        }
        if ($section -match '`((?:Assets/)[^`]+?)(?:/\{方案短名\}/|/)?`') {
            return ($Matches[1] -replace '\\', '/').TrimEnd('/')
        }
    }
    return $fallback
}

function Get-DocRoots {
    param([string]$RepoRoot)
    $roots = @()
    $assetsDoc = Join-Path $RepoRoot ".ai-gates/Doc"
    if (Test-Path -LiteralPath $assetsDoc) { $roots += , ((Resolve-Path -LiteralPath $assetsDoc).Path) }
    $overrideRel = Resolve-DefaultDocRoot -RepoRoot $RepoRoot
    $overrideAbs = Join-Path $RepoRoot ($overrideRel.Replace('/', [string][IO.Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $overrideAbs) {
        $resolved = (Resolve-Path -LiteralPath $overrideAbs).Path
        if (-not ($roots | Where-Object { $_ -eq $resolved })) { $roots += , $resolved }
    }
    # Emit flat string[] (avoid `return , $roots` nesting under `@()`).
    return @($roots)
}

function Get-RepoRelative {
    param([string]$AbsPath, [string]$RepoRoot)
    $full = [IO.Path]::GetFullPath($AbsPath)
    $rootFull = [IO.Path]::GetFullPath($RepoRoot)
    if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($rootFull.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

# Resolve source folder
$srcCandidate = $DocFolder
if (-not [IO.Path]::IsPathRooted($srcCandidate)) {
    $srcCandidate = Join-Path $repoRoot ($DocFolder -replace '/', [IO.Path]::DirectorySeparatorChar)
}
if (-not (Test-Path -LiteralPath $srcCandidate)) {
    Write-Error "DocFolder not found: $DocFolder"
    exit 1
}
$srcAbs = (Resolve-Path -LiteralPath $srcCandidate).Path
if (-not (Get-Item -LiteralPath $srcAbs).PSIsContainer) {
    Write-Error "DocFolder must be a directory (方案夹): $DocFolder"
    exit 1
}

$srcRel = Get-RepoRelative -AbsPath $srcAbs -RepoRoot $repoRoot
$catMatch = [regex]::Match($srcRel, "(?:^|/)(?<cat>$CategoryAlt)/(?<name>[^/]+)/?$")
if (-not $catMatch.Success) {
    Write-Error "Cannot parse category/shortname from path: $srcRel (expected .../{分类夹}/{方案短名})"
    exit 1
}
$fromCat = $catMatch.Groups['cat'].Value
$shortName = $catMatch.Groups['name'].Value
if ($fromCat -eq $ToCategory) {
    Write-Host "migrate-pipeline-window: already in category=$ToCategory path=$srcRel (no-op)"
    exit 0
}

$dstRel = [regex]::Replace($srcRel, "(?<=^|/)$([regex]::Escape($fromCat))(?=/)", $ToCategory)
$dstAbs = Join-Path $repoRoot ($dstRel -replace '/', [IO.Path]::DirectorySeparatorChar)
$dstParent = Split-Path -Parent $dstAbs
$metaSrc = "$srcAbs.meta"
$metaDst = "$dstAbs.meta"

Write-Host "migrate-pipeline-window: mode=$(if ($DryRun) { 'DryRun' } else { 'Apply' })"
Write-Host "  from: $srcRel"
Write-Host "  to:   $dstRel"
Write-Host "  shortname: $shortName  $fromCat -> $ToCategory"

if (Test-Path -LiteralPath $dstAbs) {
    Write-Error "Target already exists (refuse overwrite): $dstRel"
    exit 1
}

if ($DryRun) {
    Write-Host "DryRun: would create parent=$dstParent"
    Write-Host "DryRun: would Move folder + optional .meta"
    Write-Host "DryRun: would rewrite **方案文件夹** backticks inside window"
    Write-Host "DryRun: would run repair-doc-crosslinks.ps1 -Path <each docRoot> -Apply"
    exit 0
}

if (-not (Test-Path -LiteralPath $dstParent)) {
    New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
    Write-Host "Created category parent: $(Get-RepoRelative -AbsPath $dstParent -RepoRoot $repoRoot)"
}

Move-Item -LiteralPath $srcAbs -Destination $dstAbs
Write-Host "Moved folder -> $dstRel"
if (Test-Path -LiteralPath $metaSrc) {
    if (Test-Path -LiteralPath $metaDst) {
        Write-Host "WARN: target .meta already exists, left source .meta at $metaSrc" -ForegroundColor Yellow
    } else {
        Move-Item -LiteralPath $metaSrc -Destination $metaDst
        Write-Host "Moved .meta"
    }
}

# Rewrite **方案文件夹** lines inside migrated window (category segment only)
$rewritten = 0
foreach ($md in @(Get-ChildItem -LiteralPath $dstAbs -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue)) {
    $norm = $md.FullName -replace '\\', '/'
    if ($norm -match '/已完成(/|$)' -or $norm -match '/证据(/|$)') { continue }
    $lines = [System.IO.File]::ReadAllLines($md.FullName, [System.Text.Encoding]::UTF8)
    $changed = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -notmatch '\*\*方案文件夹\*\*') { continue }
        $newLine = $line.Replace("$fromCat/$shortName", "$ToCategory/$shortName")
        $newLine = $newLine.Replace("$fromCat\$shortName", "$ToCategory\$shortName")
        if ($newLine -ne $line) {
            $lines[$i] = $newLine
            $changed = $true
            $rewritten++
        }
    }
    if ($changed) {
        [System.IO.File]::WriteAllLines($md.FullName, $lines, $utf8NoBom)
    }
}
Write-Host "Rewrote **方案文件夹** lines: $rewritten"

# repair md-links (+ 方案文件夹 backticks) under each doc root — always with -Path (never ForceRepo)
$repairScript = Join-Path $scriptDir "repair-doc-crosslinks.ps1"
$docRoots = @(Get-DocRoots -RepoRoot $repoRoot)
foreach ($root in $docRoots) {
    $rootRel = Get-RepoRelative -AbsPath $root -RepoRoot $repoRoot
    Write-Host "Running repair-doc-crosslinks -Path $rootRel -Apply ..."
    & powershell -NoProfile -File $repairScript -Path $root -Apply
    if ($LASTEXITCODE -ne 0) {
        Write-Error "repair-doc-crosslinks failed for Path=$rootRel exit=$LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Write-Host "migrate-pipeline-window: DONE newPath=$dstRel" -ForegroundColor Green
exit 0
