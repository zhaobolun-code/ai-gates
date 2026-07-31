# pre-commit-pipeline-advisory.ps1 — optional git pre-commit advisory (v3.2.0)
# Always exits 0 unless -Strict. Warn-only by default.
# Usage (manual): powershell -ExecutionPolicy Bypass -File .cursor/scripts/pre-commit-pipeline-advisory.ps1
# CI:       powershell -File .cursor/scripts/pre-commit-pipeline-advisory.ps1 -Strict -BaseRef origin/main
# Install hint: see .cursor/skills/MAINTAINER.md § optional pre-commit
# Gate B: detect-empty -FailOnCandidates
# Gate A: LabSDK Runtime .cs + editable=no
#   pre-commit: git diff --cached (+ LabSDK submodule tip drill)
#   CI (-BaseRef): git diff --name-only $BaseRef...HEAD (+ submodule tip drill)

param(
    [switch]$Strict,
    # When set (CI), scan changed files via triple-dot vs BaseRef instead of staged index
    [string]$BaseRef = ""
)

$ErrorActionPreference = "Continue"
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "pre-commit-pipeline-advisory: not a git repo, skip"
    exit 0
}

function Get-ExecutionDocRootsFromProjectContext {
    param([string]$ProjectContextPath)
    $roots = @()
    if (-not (Test-Path -LiteralPath $ProjectContextPath)) { return $roots }
    $content = Get-Content -LiteralPath $ProjectContextPath -Raw -Encoding UTF8
    if ($content -match '(?ms)^##\s+执行文档存放约定\s*\r?\n(.*?)(?=^##\s|\z)') {
        $section = $Matches[1]
        foreach ($m in [regex]::Matches($section, '`([^`]+)`')) {
            $p = ($m.Groups[1].Value -replace '\\', '/').Trim().TrimEnd('/')
            if (-not $p) { continue }
            if ($p -match 'execution-doc-template|执行文档黄金样例|references/') { continue }
            if ($p -match '/$') { $p = $p.TrimEnd('/') }
            $roots += $p
        }
    }
    return @($roots | Select-Object -Unique)
}

function Test-IsExecutionDocPath {
    param([string]$NormPath, [string[]]$Roots)
    if ($NormPath -eq '.cursor/skills/references/execution-doc-template.md') { return $true }
    foreach ($root in $Roots) {
        $prefix = ($root -replace '\\', '/').TrimEnd('/')
        if ($NormPath -eq $prefix -or $NormPath -like "$prefix/*") {
            if ($NormPath -match '\.md$') { return $true }
        }
    }
    return $false
}

function Test-HasEditableDeclaration {
    param([string]$Content)
    if ($Content -match '(?m)^[\s\-]*\*\*当前唯一可改码窗\*\*[：:]') { return $true }
    if ($Content -match '(?m)^[\s\-]*\*\*方案文件夹\*\*[：:]') { return $true }
    return $false
}

function Get-ChangedPaths {
    param([string]$BaseRef)
    if ($BaseRef) {
        Write-Host ("pre-commit-pipeline-advisory: changed_source=base-ref:{0}" -f $BaseRef)
        $paths = @(git diff --name-only --diff-filter=ACM "$BaseRef...HEAD" 2>$null)
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("pre-commit-pipeline-advisory: WARN git diff {0}...HEAD failed; trying two-dot" -f $BaseRef) -ForegroundColor Yellow
            $paths = @(git diff --name-only --diff-filter=ACM "$BaseRef" "HEAD" 2>$null)
        }
        return @($paths | Where-Object { $_ })
    }
    Write-Host "pre-commit-pipeline-advisory: changed_source=cached(staged)"
    return @(git diff --cached --name-only --diff-filter=ACM 2>$null | Where-Object { $_ })
}

function Get-SubmoduleShaPair {
    param(
        [string]$RepoRoot,
        [string]$BaseRef
    )
    $oldSha = $null
    $newSha = $null
    if ($BaseRef) {
        $oldSha = git -C $RepoRoot rev-parse ("{0}:Assets/LabSDK" -f $BaseRef) 2>$null
        if ($LASTEXITCODE -ne 0) { $oldSha = $null }
        $newSha = git -C $RepoRoot rev-parse "HEAD:Assets/LabSDK" 2>$null
        if ($LASTEXITCODE -ne 0) { $newSha = $null }
        return @($oldSha, $newSha)
    }
    $idxLine = git -C $RepoRoot ls-files -s -- "Assets/LabSDK" 2>$null | Select-Object -First 1
    if ($idxLine) {
        $parts = @($idxLine -split '\s+')
        if ($parts.Count -ge 2) { $newSha = $parts[1] }
    }
    $oldSha = git -C $RepoRoot rev-parse "HEAD:Assets/LabSDK" 2>$null
    if ($LASTEXITCODE -ne 0) { $oldSha = $null }
    return @($oldSha, $newSha)
}

function Get-RuntimeCsFromChanged {
    param(
        [string]$RepoRoot,
        [string[]]$Changed,
        [string]$BaseRef
    )
    # $script:GateADrillError set on tip-changed but drill unavailable (Strict → fail)
    $script:GateADrillError = $null
    $runtime = New-Object System.Collections.Generic.List[string]
    foreach ($rel in $Changed) {
        $norm = ($rel -replace '\\', '/')
        if ($norm -match '^Assets/LabSDK/Runtime/.+\.cs$') {
            if (-not $runtime.Contains($norm)) { [void]$runtime.Add($norm) }
        }
    }
    $labTouched = @($Changed | Where-Object {
        $n = $_ -replace '\\', '/'
        ($n -eq 'Assets/LabSDK') -or ($n -like 'Assets/LabSDK/*')
    })
    if ($labTouched.Count -eq 0) { return @($runtime.ToArray()) }

    $subRoot = Join-Path $RepoRoot "Assets/LabSDK"
    if (-not (Test-Path -LiteralPath $subRoot)) {
        $script:GateADrillError = "LabSDK path missing (checkout submodules?)"
        Write-Host ("pre-commit-pipeline-advisory: Gate A drill FAIL: {0}" -f $script:GateADrillError) -ForegroundColor Red
        return @($runtime.ToArray())
    }

    $pair = @(Get-SubmoduleShaPair -RepoRoot $RepoRoot -BaseRef $BaseRef)
    $oldSha = $pair[0]
    $newSha = $pair[1]
    if (-not $oldSha -or -not $newSha) {
        $script:GateADrillError = ("LabSDK tip unresolved (old={0} new={1})" -f $oldSha, $newSha)
        Write-Host ("pre-commit-pipeline-advisory: Gate A drill FAIL: {0}" -f $script:GateADrillError) -ForegroundColor Red
        return @($runtime.ToArray())
    }
    if ($oldSha -eq $newSha) {
        Write-Host ("pre-commit-pipeline-advisory: Gate A LabSDK tip unchanged (old={0})" -f $oldSha)
        return @($runtime.ToArray())
    }

    $oldShort = $oldSha.Substring(0, [Math]::Min(8, $oldSha.Length))
    $newShort = $newSha.Substring(0, [Math]::Min(8, $newSha.Length))
    Write-Host ("pre-commit-pipeline-advisory: Gate A drill LabSDK submodule {0}...{1}" -f $oldShort, $newShort)
    $subFiles = @(git -C $subRoot diff --name-only --diff-filter=ACM ("{0}...{1}" -f $oldSha, $newSha) 2>$null)
    $diffExit = $LASTEXITCODE
    if ($diffExit -ne 0 -or $subFiles.Count -eq 0) {
        $subFiles = @(git -C $subRoot diff --name-only --diff-filter=ACM $oldSha $newSha 2>$null)
        $diffExit = $LASTEXITCODE
    }
    # tip 已变但 diff 失败或完全空 → 对象不可用（GHA 未 checkout submodule 等）→ 禁伪绿 skip
    if ($diffExit -ne 0 -or $subFiles.Count -eq 0) {
        $script:GateADrillError = ("LabSDK tip changed but git -C Assets/LabSDK diff failed/empty (exit={0} files={1}; need submodule objects)" -f $diffExit, $subFiles.Count)
        Write-Host ("pre-commit-pipeline-advisory: Gate A drill FAIL: {0}" -f $script:GateADrillError) -ForegroundColor Red
        return @($runtime.ToArray())
    }
    foreach ($f in $subFiles) {
        $nf = ($f -replace '\\', '/')
        if ($nf -match '^Runtime/.+\.cs$') {
            $fullRel = "Assets/LabSDK/$nf"
            if (-not $runtime.Contains($fullRel)) { [void]$runtime.Add($fullRel) }
        } elseif ($nf -match '^Assets/LabSDK/Runtime/.+\.cs$') {
            if (-not $runtime.Contains($nf)) { [void]$runtime.Add($nf) }
        }
    }
    return @($runtime.ToArray())
}

function Get-EditableDeclarationSources {
    param(
        [string]$RepoRoot,
        [string[]]$Changed,
        [string[]]$ExecDocRoots
    )
    $sources = New-Object System.Collections.Generic.List[string]
    foreach ($rel in $Changed) {
        $norm = $rel -replace '\\', '/'
        if ($norm -like 'Assets/Doc/_examples/*') { continue }
        if (-not (Test-IsExecutionDocPath -NormPath $norm -Roots $ExecDocRoots)) { continue }
        $full = Join-Path $RepoRoot ($norm -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $docContent = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        if (Test-HasEditableDeclaration -Content $docContent) {
            if (-not $sources.Contains($full)) { [void]$sources.Add($full) }
        }
    }
    if ($sources.Count -gt 0) { return @($sources.ToArray()) }

    $inProgressName = [string]::new(@([char]0x6267, [char]0x884C, [char]0x4E2D))
    $pendingFileName = [string]::new(@([char]0x672A, [char]0x5B8C, [char]0x6210)) + ".md"
    foreach ($rootRel in $ExecDocRoots) {
        $rootAbs = Join-Path $RepoRoot ($rootRel -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $rootAbs)) { continue }
        $execDirs = @(Get-ChildItem -LiteralPath $rootAbs -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $inProgressName })
        foreach ($execDir in $execDirs) {
            foreach ($child in @(Get-ChildItem -LiteralPath $execDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                if ($child.Name -match '^_') { continue }
                $pendingPath = Join-Path $child.FullName $pendingFileName
                if (-not (Test-Path -LiteralPath $pendingPath)) { continue }
                $docContent = Get-Content -LiteralPath $pendingPath -Raw -Encoding UTF8
                if (Test-HasEditableDeclaration -Content $docContent) {
                    if (-not $sources.Contains($pendingPath)) { [void]$sources.Add($pendingPath) }
                }
            }
        }
    }
    return @($sources.ToArray())
}

function Invoke-GateAUniqueEditable {
    param(
        [string]$RepoRoot,
        [string]$CheckScript,
        [string[]]$Changed,
        [string[]]$ExecDocRoots,
        [switch]$StrictMode,
        [string]$ChangedSourceLabel,
        [string]$BaseRef
    )
    $runtimeCs = @(Get-RuntimeCsFromChanged -RepoRoot $RepoRoot -Changed $Changed -BaseRef $BaseRef)
    if ($script:GateADrillError) {
        Write-Host ("pre-commit-pipeline-advisory: Gate A fail-closed ({0})" -f $script:GateADrillError) -ForegroundColor $(if ($StrictMode) { 'Red' } else { 'Yellow' })
        if ($StrictMode) { return $true }
        return $false
    }
    if ($runtimeCs.Count -eq 0) {
        Write-Host ("pre-commit-pipeline-advisory: Gate A skip (no Assets/LabSDK/Runtime/**/*.cs in {0})" -f $ChangedSourceLabel)
        return $false
    }

    Write-Host ("pre-commit-pipeline-advisory: Gate A - Runtime .cs in {0} ({1}); checking unique-editable declarations" -f $ChangedSourceLabel, $runtimeCs.Count)
    $sources = @(Get-EditableDeclarationSources -RepoRoot $RepoRoot -Changed $Changed -ExecDocRoots $ExecDocRoots)
    if ($sources.Count -eq 0) {
        Write-Host "pre-commit-pipeline-advisory: Gate A skip (no declaration sources; Express-safe)"
        return $false
    }

    $yes = 0
    $no = 0
    foreach ($src in $sources) {
        $rel = $src
        $rootFull = [IO.Path]::GetFullPath($RepoRoot)
        $srcFull = [IO.Path]::GetFullPath($src)
        if ($srcFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            $rel = $srcFull.Substring($rootFull.Length).TrimStart('\', '/').Replace('\', '/')
        }
        Write-Host ("pre-commit-pipeline-advisory: Gate A CheckUniqueEditable {0}" -f $rel)
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $CheckScript -DocPath $src -CheckUniqueEditable 2>&1 | Out-String
        Write-Host $out
        if ($out -match 'editable=yes') { $yes++ }
        elseif ($out -match 'editable=no') { $no++ }
        else {
            Write-Host ("pre-commit-pipeline-advisory: Gate A WARN could not parse editable for {0}" -f $rel) -ForegroundColor Yellow
        }
    }

    if ($yes -gt 0) {
        Write-Host ("pre-commit-pipeline-advisory: Gate A pass (editable=yes count={0})" -f $yes)
        return $false
    }
    if ($no -gt 0 -and $yes -eq 0) {
        $msg = "Gate A: Assets/LabSDK/Runtime/**/*.cs changed but all declaration sources editable=no (sources=$($sources.Count); via $ChangedSourceLabel)"
        Write-Host ("pre-commit-pipeline-advisory: {0}" -f $msg) -ForegroundColor $(if ($StrictMode) { 'Red' } else { 'Yellow' })
        return $true
    }
    Write-Host "pre-commit-pipeline-advisory: Gate A skip (no parseable editable labels)"
    return $false
}

Push-Location $repoRoot
try {
    $scriptsDir = Join-Path $repoRoot ".cursor/scripts"
    $checkScript = Join-Path $scriptsDir "check-pipeline-doc.ps1"
    $syncScript = Join-Path $scriptsDir "sync-regression-index.ps1"
    $detectScript = Join-Path $scriptsDir "detect-empty-pipeline-windows.ps1"
    $projectContext = Join-Path $repoRoot ".cursor/project-context.md"

    $changedSourceLabel = if ($BaseRef) { "base-ref:$BaseRef" } else { "cached(staged)" }
    $changed = @(Get-ChangedPaths -BaseRef $BaseRef)
    Write-Host ("pre-commit-pipeline-advisory: changed_count={0}" -f $changed.Count)
    $fail = $false

    $indexTouched = @($changed | Where-Object {
        $_ -replace '\\', '/' -match '(^|/)\.cursor/project-context\.md$' -or
        $_ -replace '\\', '/' -match '(^|/)\.cursor/regression-index\.yaml$'
    })
    if ($indexTouched.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $syncScript)) {
            Write-Host "pre-commit-pipeline-advisory: sync-regression-index.ps1 missing" -ForegroundColor $(if ($Strict) { 'Red' } else { 'Yellow' })
            if ($Strict) { $fail = $true }
        } else {
            Write-Host "pre-commit-pipeline-advisory: regression index files in changed set, running sync check"
            $syncArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $syncScript)
            if ($Strict) { $syncArgs += "-Strict" }
            & powershell @syncArgs
            if ($LASTEXITCODE -ne 0) { $fail = $true }
        }
    }

    $execDocRoots = Get-ExecutionDocRootsFromProjectContext -ProjectContextPath $projectContext
    if ($execDocRoots.Count -eq 0) {
        $execDocRoots = @('Assets/Doc')
    }

    if (-not (Test-Path -LiteralPath $checkScript)) {
        Write-Host "pre-commit-pipeline-advisory: check-pipeline-doc.ps1 missing (Gate A / doc check unavailable)" -ForegroundColor $(if ($Strict) { 'Red' } else { 'Yellow' })
        if ($Strict) { $fail = $true }
    } else {
        $docPaths = @($changed | Where-Object {
            $norm = $_ -replace '\\', '/'
            if ($norm -like 'Assets/Doc/_examples/*') { return $false }
            Test-IsExecutionDocPath -NormPath $norm -Roots $execDocRoots
        })

        foreach ($rel in $docPaths) {
            $full = Join-Path $repoRoot $rel
            if (-not (Test-Path -LiteralPath $full)) { continue }
            Write-Host ("pre-commit-pipeline-advisory: checking {0}" -f $rel)
            $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $checkScript, "-DocPath", $full, "-CheckGit")
            if ($Strict) { $args += "-Strict" }
            & powershell @args
            if ($LASTEXITCODE -ne 0) { $fail = $true }
        }

        $gateAHit = Invoke-GateAUniqueEditable -RepoRoot $repoRoot -CheckScript $checkScript `
            -Changed $changed -ExecDocRoots $execDocRoots -StrictMode:$Strict `
            -ChangedSourceLabel $changedSourceLabel -BaseRef $BaseRef
        if ($gateAHit) { $fail = $true }
    }

    if (-not (Test-Path -LiteralPath $detectScript)) {
        Write-Host "pre-commit-pipeline-advisory: detect-empty-pipeline-windows.ps1 missing (Gate B unavailable)" -ForegroundColor $(if ($Strict) { 'Red' } else { 'Yellow' })
        if ($Strict) { $fail = $true }
    } else {
        Write-Host "pre-commit-pipeline-advisory: Gate B - detect-empty -FailOnCandidates"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $detectScript -FailOnCandidates
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("pre-commit-pipeline-advisory: Gate B candidates present (exit={0})" -f $LASTEXITCODE) -ForegroundColor $(if ($Strict) { 'Red' } else { 'Yellow' })
            if ($Strict) { $fail = $true }
        } else {
            Write-Host "pre-commit-pipeline-advisory: Gate B pass"
        }
    }

    $pmGate = Join-Path $scriptsDir "ci-pressure-manager-gate.ps1"
    if (Test-Path -LiteralPath $pmGate) {
        $maybePm = @($changed | Where-Object {
            $norm = $_ -replace '\\', '/'
            ($norm -match '(^|/)PressureManager(/|$)') -or
            ($norm -eq 'Assets/LabSDK') -or
            ($norm -like 'Assets/LabSDK/*')
        })
        if ($maybePm.Count -gt 0) {
            Write-Host "pre-commit-pipeline-advisory: possible PressureManager touch in changed set; advisory only (hard gate = CI / explicit local)"
            & powershell -NoProfile -ExecutionPolicy Bypass -File $pmGate -Advisory | Out-Host
        }
    }

    if ($fail -and $Strict) { exit 1 }
    exit 0
}
finally {
    Pop-Location
}
