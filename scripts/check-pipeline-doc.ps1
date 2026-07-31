# check-pipeline-doc.ps1 — 执行文档「文档状态」轻量校验（advisory，默认 warn）
# 当前版本读取 ../skills/VERSION；PM 门禁见 CORE #7；方案审核档位 L1/L1.5/L2/L3/跳过
# Supports: (1) template ## 文档状态 block (2) legacy inline **文档状态** | **可交给程序员** lines
# Usage:
#   .\check-pipeline-doc.ps1 -DocPath "path/to/方案.md"
#   .\check-pipeline-doc.ps1 -DocPath "..." -CheckGit
#   .\check-pipeline-doc.ps1 -DocPath "..." -CheckLinks
#   .\check-pipeline-doc.ps1 -DocPath "..." -CheckUniqueEditable
#   .\check-pipeline-doc.ps1 -DocPath "..." -Strict

param(
    [Parameter(Mandatory = $true)]
    [string]$DocPath,
    [switch]$CheckGit,
    [switch]$CheckLinks,
    [switch]$CheckUniqueEditable,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom
$versionPath = Join-Path $PSScriptRoot "../skills/VERSION"
if (-not (Test-Path -LiteralPath $versionPath)) {
    Write-Host "ERROR: missing ../skills/VERSION" -ForegroundColor Red
    exit 1
}
$pipelineVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
$warnings = @()
$errors = @()
$format = $null
$status = $null
$canDev = $null
$evidence = $null
$pipelineMode = $null
$lane = $null
$currentStep = $null
$planReviewTier = $null

$validStatuses = @(
    "draft(草稿)",
    "review-pending(待审核)",
    "implementation-ready(可实现)",
    "in-progress(实现中)",
    "blocked(已阻塞)",
    "step-completed(步骤完成)",
    "runtime-validated(运行已验证)",
    "completed(已归档)"
)

function Add-Issue($level, $message) {
    if ($level -eq "error") { $script:errors += $message }
    else { $script:warnings += $message }
}

function Normalize-CanDev([string]$raw) {
    if (-not $raw) { return $null }
    $r = $raw.Trim()
    if ($r -match '^是') { return '是' }
    if ($r -match '^否') { return '否' }
    return $r
}

function Get-RegressionModulesFromProjectContext {
    param([string]$ProjectContextPath)
    $mods = @()
    if (-not (Test-Path -LiteralPath $ProjectContextPath)) { return $mods }
    $pc = Get-Content -LiteralPath $ProjectContextPath -Raw -Encoding UTF8
    if ($pc -match '(?ms)^##\s+运行回归索引\s*\r?\n(.*?)(?=^##\s|\z)') {
        $section = $Matches[1]
        foreach ($line in ($section -split '\r?\n')) {
            if ($line -match '^\|\s*([^|]+?)\s*\|') {
                $mod = $Matches[1].Trim()
                if ($mod -and $mod -ne '模块' -and $mod -notmatch '^\-+$') {
                    $mods += ($mod -replace '\s*/\s*.*$', '').Trim()
                }
            }
        }
    }
    return @($mods | Where-Object { $_ } | Select-Object -Unique)
}

function Test-ContentHitsRegressionModule {
    param([string]$Text, [string[]]$Modules)
    if (-not $Text -or $Modules.Count -eq 0) { return $false }
    foreach ($m in $Modules) {
        if ($Text -match [regex]::Escape($m)) { return $true }
    }
    return $false
}

if (-not (Test-Path -LiteralPath $DocPath)) {
    Write-Error "File not found: $DocPath"
    exit 1
}

$content = Get-Content -LiteralPath $DocPath -Raw -Encoding UTF8

if ($content -match '(?ms)^##\s+文档状态\s*$') {
    $format = "template"
    if ($content -match '(?ms)^##\s+文档状态\s*\r?\n(.*?)(?=^##\s|\z)') {
        $block = $Matches[1]
    } else {
        $block = ""
    }

    $required = @("状态", "可交给程序员", "证据等级", "车道")
    foreach ($key in $required) {
        if ($block -notmatch "(?m)^[\s\-]*\*\*$key\*\*") {
            Add-Issue "warning" "Missing field: **$key**"
        }
    }

    if ($block -match '(?m)^[\s\-]*\*\*状态\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $status = $Matches[1].Trim()
    }
    $canDevRaw = $null
    if ($block -match '(?m)^[\s\-]*\*\*可交给程序员\*\*[：:]\s*(.+?)\s*$') {
        $canDevRaw = $Matches[1].Trim()
    }
    $canDev = Normalize-CanDev $canDevRaw

    if ($block -match '(?m)^[\s\-]*\*\*流水线模式\*\*') {
        Add-Issue "warning" "Deprecated field **流水线模式** — use **车道** (Express / Standard / Full); see lane-glossary.md"
    }

    if ($block -match '(?m)^[\s\-]*\*\*车道\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $lane = $Matches[1].Trim()
        if ($lane -notmatch 'Express|Standard|Full') {
            Add-Issue "warning" "Unknown 车道=$lane (expected Express / Standard / Full)"
        }
    } else {
        Add-Issue "warning" "Missing required field: **车道** (Express / Standard / Full)"
    }

    if ($block -match '(?m)^[\s\-]*\*\*当前 Step\(步骤\)\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $currentStep = $Matches[1].Trim()
    } else {
        Add-Issue "warning" "Recommended field missing: **当前 Step(步骤)**"
    }

    if ($block -match '(?m)^[\s\-]*\*\*证据等级\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $evidence = $Matches[1].Trim()
    }

    if ($block -match '(?m)^[\s\-]*\*\*方案审核档位\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $planReviewTier = $Matches[1].Trim()
        $validTiers = @('L1', 'L1.5', 'L2', 'L3', '跳过')
        $tierOk = $false
        foreach ($t in $validTiers) {
            if ($planReviewTier -like "*$t*") { $tierOk = $true; break }
        }
        if (-not $tierOk) {
            Add-Issue "warning" "Unknown 方案审核档位=$planReviewTier (expected L1 / L1.5 / L2 / L3 / 跳过)"
        }
    } elseif ($lane -eq 'Standard') {
        Add-Issue "warning" "Recommended field missing: **方案审核档位** (L1 or L1.5 for Standard)"
    }
}
elseif ($content -match '(?m)\*\*文档状态\*\*[：:]') {
    $format = "legacy"
    if ($content -match '(?m)\*\*文档状态\*\*[：:]\s*`([^`]+)`') {
        $status = $Matches[1].Trim()
    } elseif ($content -match '(?m)\*\*文档状态\*\*[：:]\s*([^|\r\n]+?)(?:\s*[|｜]|$)') {
        $status = $Matches[1].Trim()
    }

    $canDevRaw = $null
    if ($content -match '(?m)\*\*可交给程序员\*\*[：:]\s*([是否][^|\r\n]*)') {
        $canDevRaw = $Matches[1].Trim()
    }
    $canDev = Normalize-CanDev $canDevRaw

    if (-not $status) {
        Add-Issue "warning" "Legacy format: could not parse **文档状态** value"
    }
    if (-not $canDev) {
        Add-Issue "warning" "Legacy format: could not parse **可交给程序员** (是/否)"
    }
    if ($content -notmatch '(?m)\*\*车道\*\*' -and $content -notmatch '(?m)\*\*流水线模式\*\*') {
        Add-Issue "warning" "Legacy format: missing **车道** (Express / Standard / Full)"
    }
}
else {
    Add-Issue "error" "Missing '## 文档状态' section and no legacy **文档状态** inline field."
}

if ($format) {
    if ($status -and ($validStatuses -notcontains $status)) {
        Add-Issue "warning" "Unknown 状态=$status (not in state-machine enum)"
        if ($Strict) {
            Add-Issue "error" "Strict: invalid 状态=$status"
        }
    }

    $implStates = @(
        "implementation-ready(可实现)",
        "in-progress(实现中)",
        "step-completed(步骤完成)",
        "runtime-validated(运行已验证)",
        "completed(已归档)"
    )
    $activeDevStates = @(
        "implementation-ready(可实现)",
        "in-progress(实现中)",
        "in-progress(进行中)"
    )

    if ($canDev -eq "是") {
        if ($status -and ($implStates -notcontains $status)) {
            Add-Issue "warning" "可交给程序员=是 but 状态=$status (expected implementation-ready or later impl state)"
        }
        if ($status -eq "draft(草稿)" -or $status -eq "review-pending(待审核)") {
            Add-Issue "error" "可交给程序员=是 conflicts with 状态=$status"
        }
    }

    if ($canDev -eq "否") {
        if ($status -and ($activeDevStates -contains $status)) {
            Add-Issue "warning" "可交给程序员=否 but 状态=$status suggests implementation may be in progress"
        }
    }

    if ($status -eq "runtime-validated(运行已验证)" -or $status -eq "completed(已归档)") {
        if ($evidence -and $evidence -notmatch 'runtime-validated') {
            Add-Issue "warning" "状态=$status but 证据等级=$evidence (expected runtime-validated)"
        }
    }

    if ($status -eq "draft(草稿)" -or $status -eq "review-pending(待审核)") {
        if ($evidence -and $evidence -match 'runtime-validated') {
            Add-Issue "error" "状态=$status conflicts with 证据等级=$evidence"
        }
    }

    $terminalStates = @("step-completed(步骤完成)", "runtime-validated(运行已验证)", "completed(已归档)")
    if ($status -and ($terminalStates -contains $status) -and $canDev -eq "是") {
        Add-Issue "warning" "状态=$status but 可交给程序员=是 (usually 否 after step handoff)"
    }

    if ($format -eq "template" -and $lane -eq "Standard") {
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) {
            $scriptDir = Split-Path -Parent $PSCommandPath
            $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
        }
        $pcPath = Join-Path $repoRoot ".cursor/project-context.md"
        $regModules = Get-RegressionModulesFromProjectContext -ProjectContextPath $pcPath
        if (Test-ContentHitsRegressionModule -Text $content -Modules $regModules) {
            if ($planReviewTier -notlike '*L1.5*') {
                Add-Issue "warning" "Mandatory Code Changes appears to hit regression-index module but 方案审核档位 is not L1.5"
            }
        }
    }

    # Acceptance clauses (advisory; see skills/references/acceptance-and-delta.md)
    $hasAcceptanceSection = ($content -match '(?m)^##\s+验收条款') -or ($content -match '验收条款（实现不得超出）')
    $hasANumber = $content -match '(?m)^\s*[-*]\s*A\d+\s*[：:]'
    if (-not $hasAcceptanceSection -and -not $hasANumber) {
        Add-Issue "warning" "Missing acceptance clauses (A1...): add ## 验收条款 — see acceptance-and-delta.md"
        if ($Strict) {
            Add-Issue "error" "Strict: missing acceptance clauses A1..."
        }
    } elseif ($hasANumber -or $hasAcceptanceSection) {
        $hasStep = $content -match '(?m)^###\s*Step'
        $hasSatisfy = $content -match '满足验收'
        if ($hasStep -and -not $hasSatisfy) {
            Add-Issue "warning" "Steps present but missing 满足验收: A# — see acceptance-and-delta.md"
            if ($Strict) {
                Add-Issue "error" "Strict: Step missing 满足验收 reference"
            }
        }
    }
}

# --- 150-line soft cap (path contains 执行中; independent of .kit-v1) ---
if ($DocPath -match '执行中') {
    $lineCount = (Get-Content -LiteralPath $DocPath | Measure-Object -Line).Lines
    $hasExternalNote = ($content -match '已外置') -or ($content -match 'Mandatory-Step')
    if ($lineCount -gt 150 -and -not $hasExternalNote) {
        Add-Issue "warning" "执行中 doc has $lineCount lines (>150) without externalization note (已外置 / Mandatory-Step) — see doc-windowing.md"
        if ($Strict) {
            Add-Issue "error" "Strict: 执行中 doc exceeds 150 lines without externalization note"
        }
    }
}

# --- 物理口径 required when scheme root has .kit-v1 (independent of 执行中 path) ---
$docDirResolved = Split-Path -Parent (Resolve-Path -LiteralPath $DocPath).Path
$kitMarkerPath = Join-Path $docDirResolved '.kit-v1'
$physSpecPath = Join-Path $docDirResolved '物理口径.md'
if (Test-Path -LiteralPath $kitMarkerPath) {
    if (-not (Test-Path -LiteralPath $physSpecPath)) {
        Add-Issue "warning" "Scheme folder has .kit-v1 but missing 物理口径.md — see phys-spec.md / new-pipeline-window.ps1"
        if ($Strict) {
            Add-Issue "error" "Strict: .kit-v1 present but 物理口径.md missing"
        }
    }
}

# --- -CheckLinks: category-prefix links in this single doc ---
if ($CheckLinks) {
    $repoRootForLinks = git rev-parse --show-toplevel 2>$null
    if (-not $repoRootForLinks) {
        $scriptDirForLinks = Split-Path -Parent $PSCommandPath
        $repoRootForLinks = (Resolve-Path (Join-Path $scriptDirForLinks "../..")).Path
    }
    $categoryPrefixRe = '(执行中|签收|失败|回退|停写|换层)/'
    $mdLinkMatches = [regex]::Matches($content, '\[[^\]]*\]\(([^)]+)\)')
    foreach ($m in $mdLinkMatches) {
        $rawUrl = $m.Groups[1].Value.Trim()
        if ($rawUrl -match '^(https?://|mailto:)') { continue }
        $urlNoAnchor = ($rawUrl -split '#', 2)[0].Trim()
        if (-not $urlNoAnchor) { continue }
        if ($urlNoAnchor -notmatch $categoryPrefixRe) { continue }
        if ($urlNoAnchor -match '^[a-zA-Z]:[\\/]' -or $urlNoAnchor.StartsWith('\\')) {
            $candidate = $urlNoAnchor
        } elseif ($urlNoAnchor -match '^(Assets|\.cursor)[/\\]') {
            $candidate = Join-Path $repoRootForLinks ($urlNoAnchor -replace '/', [IO.Path]::DirectorySeparatorChar)
        } else {
            $candidate = Join-Path $docDirResolved ($urlNoAnchor -replace '/', [IO.Path]::DirectorySeparatorChar)
        }
        try {
            $candidateFull = [IO.Path]::GetFullPath($candidate)
        } catch {
            $candidateFull = $candidate
        }
        if (-not (Test-Path -LiteralPath $candidateFull)) {
            Add-Issue "warning" "Broken category-prefix link: $urlNoAnchor"
            if ($Strict) {
                Add-Issue "error" "Strict: broken category-prefix link: $urlNoAnchor"
            }
        }
    }
}

if ($CheckGit) {
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) {
        Push-Location $repoRoot
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $changed = @(git diff --name-only HEAD 2>&1 | Where-Object { $_ -is [string] -and $_ -notmatch '^(warning:|fatal:)' })
            if ($changed.Count -eq 0) {
                $changed = @(git diff --name-only --cached 2>&1 | Where-Object { $_ -is [string] -and $_ -notmatch '^(warning:|fatal:)' })
            }
            if ($changed.Count -eq 0) {
                $changed = @(git diff --name-only 2>&1 | Where-Object { $_ -is [string] -and $_ -notmatch '^(warning:|fatal:)' })
            }
            $ErrorActionPreference = $prevEap
            $codeFiles = @($changed | Where-Object { $_ -match '\.(cs|lua|tsx?|jsx?)$' })
            if ($codeFiles.Count -gt 0 -and $canDev -eq "否") {
                Add-Issue "warning" "Git has $($codeFiles.Count) code file change(s) but 可交给程序员=否 — confirm Express 小改 or update 文档状态"
            }
            $assetOnly = @($changed | Where-Object {
                $_ -match '\.(prefab|unity|asset|mat|controller|anim|meta)$' -or $_ -like 'ProjectSettings/*'
            })
            $logicFiles = @($changed | Where-Object { $_ -match '\.(cs|lua|shader|compute)$' })
            if ($assetOnly.Count -gt 0 -and $logicFiles.Count -eq 0 -and $assetOnly.Count -le 5) {
                Add-Issue "warning" "Git has $($assetOnly.Count) prefab/asset change(s) with no code files — may fit Express asset sub-class if <=5 files"
            }
        } finally {
            Pop-Location
        }
    } else {
        Add-Issue "warning" "-CheckGit skipped: not a git repository"
    }
}

# --- -CheckUniqueEditable: REPORT path_exists / category / editable / reason (A3) ---
if ($CheckUniqueEditable) {
    $repoRootUe = git rev-parse --show-toplevel 2>$null
    if (-not $repoRootUe) {
        $scriptDirUe = Split-Path -Parent $PSCommandPath
        $repoRootUe = (Resolve-Path (Join-Path $scriptDirUe "../..")).Path
    }
    $CategoriesUe = @("执行中", "签收", "失败", "回退", "停写", "换层")
    $CategoryAltUe = ($CategoriesUe | ForEach-Object { [regex]::Escape($_) }) -join "|"

    $uniqueRaw = $null
    $schemeFolderRaw = $null
    if ($content -match '(?m)^[\s\-]*\*\*当前唯一可改码窗\*\*[：:]\s*(.+?)\s*$') {
        $uniqueRaw = $Matches[1].Trim().Trim('`')
    }
    if ($content -match '(?m)^[\s\-]*\*\*方案文件夹\*\*[：:]\s*`?([^`\r\n]+?)`?\s*$') {
        $schemeFolderRaw = $Matches[1].Trim().TrimEnd('/', '\')
    }

    $resolvedRel = $null
    if ($uniqueRaw -and $uniqueRaw -ne "本窗" -and $uniqueRaw -match '[\\/]') {
        $resolvedRel = ($uniqueRaw -replace '\\', '/').TrimEnd('/')
    } elseif ($schemeFolderRaw) {
        $resolvedRel = ($schemeFolderRaw -replace '\\', '/').TrimEnd('/')
    } else {
        $resolvedRel = ($docDirResolved.Substring([IO.Path]::GetFullPath($repoRootUe).Length).TrimStart('\', '/') -replace '\\', '/')
    }

    $pathExists = $false
    $category = $null
    $absCandidate = $null
    if ($resolvedRel) {
        if ($resolvedRel -match '^[a-zA-Z]:[\\/]' -or $resolvedRel.StartsWith('//')) {
            $absCandidate = $resolvedRel
        } else {
            $absCandidate = Join-Path $repoRootUe ($resolvedRel -replace '/', [IO.Path]::DirectorySeparatorChar)
        }
        try { $absCandidate = [IO.Path]::GetFullPath($absCandidate) } catch { }
        $pathExists = Test-Path -LiteralPath $absCandidate
        $cm = [regex]::Match(($resolvedRel -replace '\\', '/'), "(?:^|/)(?<cat>$CategoryAltUe)(?:/|$)")
        if ($cm.Success) { $category = $cm.Groups['cat'].Value }
    }

    # 止损 =3/3 from 文档状态 / body / .state.json
    $stopLossMaxed = $false
    $stopLossNote = $null
    if ($content -match '(?m)止损[^\r\n]*?=\s*(\d+)\s*/\s*(\d+)') {
        if ([int]$Matches[1] -ge [int]$Matches[2] -and [int]$Matches[2] -gt 0) {
            $stopLossMaxed = $true
            $stopLossNote = "$($Matches[1])/$($Matches[2])"
        }
    }
    if (-not $stopLossMaxed) {
        foreach ($m in [regex]::Matches($content, '(?m)([^=\r\n]{1,40})=\s*(\d+)\s*/\s*(\d+)')) {
            $label = $m.Groups[1].Value
            if ($label -notmatch '止损' -and $label -notmatch 'stopLoss' -and $label -notmatch 'StopLoss') { continue }
            if ([int]$m.Groups[2].Value -ge [int]$m.Groups[3].Value -and [int]$m.Groups[3].Value -gt 0) {
                $stopLossMaxed = $true
                $stopLossNote = $m.Value.Trim()
                break
            }
        }
    }
    $stateJsonPath = Join-Path $docDirResolved ".state.json"
    if ((-not $stopLossMaxed) -and (Test-Path -LiteralPath $stateJsonPath)) {
        try {
            $st = Get-Content -LiteralPath $stateJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($st.stopLossCounters) {
                foreach ($p in $st.stopLossCounters.PSObject.Properties) {
                    $cur = [int]$p.Value.count
                    $mx = [int]$p.Value.max
                    if ($mx -gt 0 -and $cur -ge $mx) {
                        $stopLossMaxed = $true
                        $stopLossNote = "$($p.Name)=$cur/$mx"
                        break
                    }
                }
            }
        } catch { }
    }

    $statusNorm = $null
    if ($status) {
        $statusNorm = ($status -split '\(')[0].Trim()
    }

    $editable = $true
    $reasonParts = @()
    if (-not $pathExists) {
        $editable = $false
        $reasonParts += "path_missing"
    }
    if ($category -and $category -ne "执行中") {
        $editable = $false
        $reasonParts += "category=$category"
    }
    if (-not $category -and $resolvedRel) {
        $editable = $false
        $reasonParts += "category_unparsed"
    }
    if ($statusNorm -eq "completed") {
        $editable = $false
        $reasonParts += "status=completed"
    }
    if ($stopLossMaxed) {
        $editable = $false
        $reasonParts += "stop_loss_maxed=$stopLossNote"
    }
    if ($editable) { $reasonParts = @("ok_in_progress_window") }

    $editableLabel = if ($editable) { "yes" } else { "no" }
    $existsLabel = if ($pathExists) { "yes" } else { "no" }
    $reason = ($reasonParts -join ";")
    Write-Host ("unique_editable: path={0} path_exists={1} category={2} editable={3} reason={4}" -f `
        $resolvedRel, $existsLabel, $(if ($category) { $category } else { "null" }), $editableLabel, $reason)

    if (-not $uniqueRaw -and -not $schemeFolderRaw) {
        Add-Issue "warning" "CheckUniqueEditable: missing **当前唯一可改码窗** and **方案文件夹**"
    }
    if (-not $editable) {
        Add-Issue "warning" "CheckUniqueEditable: editable=no ($reason)"
        if ($Strict) {
            Add-Issue "error" "Strict: unique editable window is not editable ($reason)"
        }
    }
}

Write-Host "check-pipeline-doc (v$pipelineVersion): $DocPath"
if ($format) { Write-Host "format: $format" }
if ($status) { Write-Host "状态: $status" }
if ($canDev) { Write-Host "可交给程序员: $canDev" }
if ($planReviewTier) { Write-Host "方案审核档位: $planReviewTier" }
foreach ($w in $warnings) { Write-Host "WARN: $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }

if ($Strict -and ($warnings.Count -gt 0 -or $errors.Count -gt 0)) { exit 1 }
if ($errors.Count -gt 0) { exit 1 }
exit 0
