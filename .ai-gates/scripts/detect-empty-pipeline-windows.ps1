# detect-empty-pipeline-windows.ps1 — 空壳执行中窗检出 / 归档（默认 dry-run）
# Usage (repo root):
#   powershell -NoProfile -File .cursor/scripts/detect-empty-pipeline-windows.ps1
#   powershell -NoProfile -File .cursor/scripts/detect-empty-pipeline-windows.ps1 -Apply
#
# 扫描 .ai-gates/Doc + project-context 文档路径的主题父目录下 **/执行中/*。
# 合取判据：isEmptyShell = hasTemplatePlaceholder && !hasRealStepTitle && !hasEvidenceJson && !hasLiveState
# -Apply：归档到 {docRoot}/签收/_空壳清扫-YYYYMMDD/{短名}/（Move，不 Delete）。

param(
    [switch]$Apply,
    # dry-run 且 candidates>0 时 exit 1；默认仍 exit 0（兼容旧调用）
    [switch]$FailOnCandidates
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

$LiveStates = @(
    "in-progress",
    "runtime-validated",
    "step-completed",
    "implementation-ready",
    "blocked"
)

function Resolve-DefaultDocRoot {
    param([string]$RepoRoot)
    $fallback = ".ai-gates/Doc"
    $pc = Join-Path $RepoRoot ".cursor/project-context.md"
    if (-not (Test-Path -LiteralPath $pc)) { return $fallback }
    $raw = Get-Content -LiteralPath $pc -Raw -Encoding UTF8
    if ($raw -match '(?ms)^##\s+执行文档存放约定\s*\r?\n(.*?)(?=^##\s|\z)') {
        $section = $Matches[1]
        if ($section -match '`((?:Assets/)[^`]+?)(?:/\{方案短名\}/|/)?`') {
            return ($Matches[1] -replace '\\', '/').TrimEnd('/')
        }
    }
    return $fallback
}

function Add-UniqueDocRoot {
    param([System.Collections.Generic.List[string]]$List, [string]$Abs)
    if (-not $Abs -or -not (Test-Path -LiteralPath $Abs)) { return }
    $resolved = (Resolve-Path -LiteralPath $Abs).Path
    if (-not ($List | Where-Object { $_ -eq $resolved })) { [void]$List.Add($resolved) }
}

function Get-DocRoots {
    param([string]$RepoRoot)
    $roots = New-Object System.Collections.Generic.List[string]
    Add-UniqueDocRoot -List $roots -Abs (Join-Path $RepoRoot ".ai-gates/Doc")
    $overrideRel = Resolve-DefaultDocRoot -RepoRoot $RepoRoot
    $overrideNorm = (($overrideRel -replace '\\', '/').TrimEnd('/'))
    if (-not $overrideNorm -or $overrideNorm -eq ".ai-gates/Doc") {
        return @($roots.ToArray())
    }
    $overrideAbs = Join-Path $RepoRoot ($overrideRel.Replace('/', [string][IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $overrideAbs)) { return @($roots.ToArray()) }
    $parentAbs = Split-Path -Parent $overrideAbs
    $repoFull = [IO.Path]::GetFullPath($RepoRoot)
    $parentFull = [IO.Path]::GetFullPath($parentAbs)
    if ($parentFull.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase) -and ($parentFull.Length -gt $repoFull.Length)) {
        Add-UniqueDocRoot -List $roots -Abs $parentAbs
    } else {
        Add-UniqueDocRoot -List $roots -Abs $overrideAbs
    }
    return @($roots.ToArray())
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

function Test-HasTemplatePlaceholder {
    param([string]$Content)
    if ($Content -match '\[填写目标') { return $true }
    if ($Content -match '###\s*Step\s*1\s*[—\-]\s*\[名称\]') { return $true }
    if ($Content -match '\[3 行以内：要做什么') { return $true }
    if ($Content -match '\[功能名\]') { return $true }
    return $false
}

function Test-HasRealStepTitle {
    param([string]$Content)
    foreach ($m in [regex]::Matches($Content, '(?m)^###\s*Step\s*\d+\s*[—\-]\s*(.+?)\s*$')) {
        $title = $m.Groups[1].Value.Trim()
        if (-not $title) { continue }
        # placeholder titles like [名称] / [可选] do not count as real
        if ($title -match '^\[') { continue }
        return $true
    }
    return $false
}

function Test-HasEvidenceJson {
    param([string]$WindowAbs)
    $ev = Join-Path $WindowAbs "证据"
    if (-not (Test-Path -LiteralPath $ev)) { return $false }
    foreach ($f in @(Get-ChildItem -LiteralPath $ev -Recurse -Filter "*.json" -File -ErrorAction SilentlyContinue)) {
        if ($f.Length -gt 0) { return $true }
    }
    return $false
}

function Test-HasLiveState {
    param([string]$WindowAbs)
    $statePath = Join-Path $WindowAbs ".state.json"
    if (-not (Test-Path -LiteralPath $statePath)) { return $false }
    try {
        $st = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $status = [string]$st.docStatus
        if (-not $status) { return $false }
        foreach ($live in $LiveStates) {
            if ($status -eq $live -or $status -like "$live*") { return $true }
        }
    } catch {
        return $false
    }
    return $false
}

$docRoots = @($(Get-DocRoots -RepoRoot $repoRoot) | ForEach-Object { $_ } | Where-Object { $_ -is [string] -and $_ })
$candidates = @()
$scanned = 0

foreach ($root in $docRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $rootFull = [IO.Path]::GetFullPath($root)
    $execDirs = @(Get-ChildItem -LiteralPath $rootFull -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "执行中" })
    foreach ($execDir in $execDirs) {
        foreach ($child in @(Get-ChildItem -LiteralPath $execDir.FullName -Directory -ErrorAction SilentlyContinue)) {
            if ($child.Name -match '^_') { continue } # skip archive buckets
            $scanned++
            $未完成 = Join-Path $child.FullName "未完成.md"
            if (-not (Test-Path -LiteralPath $未完成)) {
                $slice = Join-Path $child.FullName "express-slice.md"
                if (Test-Path -LiteralPath $slice) {
                    Write-Host ("WARN slice-only (not empty-shell Apply): {0}" -f (Get-RepoRelative -AbsPath $child.FullName -RepoRoot $repoRoot))
                }
                continue
            }
            $content = Get-Content -LiteralPath $未完成 -Raw -Encoding UTF8
            $hasTpl = Test-HasTemplatePlaceholder -Content $content
            $hasReal = Test-HasRealStepTitle -Content $content
            $hasJson = Test-HasEvidenceJson -WindowAbs $child.FullName
            $hasLive = Test-HasLiveState -WindowAbs $child.FullName
            $isEmpty = $hasTpl -and (-not $hasReal) -and (-not $hasJson) -and (-not $hasLive)
            if (-not $isEmpty) { continue }
            $docRootForChild = $rootFull
            foreach ($r in $docRoots) {
                if (-not ($r -is [string]) -or -not $r) { continue }
                $rFull = [IO.Path]::GetFullPath($r)
                if ($child.FullName.StartsWith($rFull, [StringComparison]::OrdinalIgnoreCase)) {
                    # prefer longest matching doc root
                    if ($rFull.Length -ge $docRootForChild.Length) { $docRootForChild = $rFull }
                }
            }
            $candidates += ,[pscustomobject]@{
                Path     = Get-RepoRelative -AbsPath $child.FullName -RepoRoot $repoRoot
                AbsPath  = $child.FullName
                DocRoot  = $docRootForChild
                ShortName = $child.Name
                hasTemplatePlaceholder = $hasTpl
                hasRealStepTitle = $hasReal
                hasEvidenceJson = $hasJson
                hasLiveState = $hasLive
            }
        }
    }
}

$modeLabel = if ($Apply) { 'Apply' } else { 'dry-run' }
Write-Host "detect-empty-pipeline-windows: mode=$modeLabel scanned=$scanned candidates=$($candidates.Count)"

foreach ($c in $candidates) {
    Write-Host ("CANDIDATE {0}  tpl={1} realStep={2} evidenceJson={3} liveState={4}" -f `
        $c.Path, $c.hasTemplatePlaceholder, $c.hasRealStepTitle, $c.hasEvidenceJson, $c.hasLiveState)
}

if (-not $Apply) {
    Write-Host "dry-run: no disk changes. Re-run with -Apply to archive candidates under 签收/_空壳清扫-YYYYMMDD/."
    if ($FailOnCandidates -and $candidates.Count -gt 0) {
        Write-Host "FailOnCandidates: candidates=$($candidates.Count) -> exit 1" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if ($candidates.Count -eq 0) {
    Write-Host "Apply: nothing to archive."
    exit 0
}

$stamp = Get-Date -Format "yyyyMMdd"
$archived = 0
foreach ($c in $candidates) {
    # Re-check evidence JSON immediately before move (A2: 有证据 JSON 不入候选 / 不归档)
    if (Test-HasEvidenceJson -WindowAbs $c.AbsPath) {
        Write-Host "SKIP (evidence JSON appeared): $($c.Path)" -ForegroundColor Yellow
        continue
    }
    $bucketRel = "签收/_空壳清扫-$stamp"
    $bucketAbs = Join-Path $c.DocRoot ($bucketRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $bucketAbs)) {
        New-Item -ItemType Directory -Force -Path $bucketAbs | Out-Null
    }
    $dstAbs = Join-Path $bucketAbs $c.ShortName
    if (Test-Path -LiteralPath $dstAbs) {
        Write-Host "SKIP (target exists): $(Get-RepoRelative -AbsPath $dstAbs -RepoRoot $repoRoot)" -ForegroundColor Yellow
        continue
    }
    Move-Item -LiteralPath $c.AbsPath -Destination $dstAbs
    $metaSrc = "$($c.AbsPath).meta"
    $metaDst = "$dstAbs.meta"
    if ((Test-Path -LiteralPath $metaSrc) -and -not (Test-Path -LiteralPath $metaDst)) {
        Move-Item -LiteralPath $metaSrc -Destination $metaDst
    }
    Write-Host "ARCHIVED $($c.Path) -> $(Get-RepoRelative -AbsPath $dstAbs -RepoRoot $repoRoot)" -ForegroundColor Green
    $archived++
}

Write-Host "detect-empty-pipeline-windows: archived=$archived"
exit 0
