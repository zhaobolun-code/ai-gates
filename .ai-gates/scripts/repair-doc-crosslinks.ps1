# repair-doc-crosslinks.ps1 — 跨窗短名分类夹路径纠错（默认只读）
# Usage (repo root):
#   powershell -NoProfile -File .cursor/scripts/repair-doc-crosslinks.ps1
#   powershell -NoProfile -File .cursor/scripts/repair-doc-crosslinks.ps1 -Path "Assets/Doc/.../未完成.md"
#   powershell -NoProfile -File .cursor/scripts/repair-doc-crosslinks.ps1 -Path "Assets/Doc/.../未完成.md" -Apply
#   powershell -NoProfile -File .cursor/scripts/repair-doc-crosslinks.ps1 -ForceRepo -Apply   # 显式全仓 Apply
#
# Scans Assets/Doc/** and project-context 文档根下 *.md（跳过 已完成/**、证据/**）。
# 提取 Markdown 链接 [text](url) 与反引号路径；只改分类夹段（CatShortRe），不造全仓相对路径重写器。
# -Apply: 改写 **md-link**；普通反引号路径 REPORT-ONLY（永不 Apply）。
#         例外：含 **方案文件夹** 的行内反引号路径，唯一短名命中时可 Apply。
#         无 -Path 时拒绝退出非零，除非显式 -ForceRepo。
# -Path: 可选，限制只扫描该文件或目录（仍用全仓短名索引判定唯一/歧义）。

param(
    [switch]$Apply,
    [switch]$ForceRepo,
    [string]$Path = ""
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

if ($Apply -and [string]::IsNullOrWhiteSpace($Path) -and -not $ForceRepo) {
    Write-Host "ERROR: -Apply without -Path is refused (would rewrite whole repo). Re-run with -Path <file-or-dir> -Apply, or pass -ForceRepo to allow repo-wide Apply." -ForegroundColor Red
    exit 1
}

$Categories = @("执行中", "签收", "失败", "回退", "停写", "换层")
$CategoryAlt = ($Categories | ForEach-Object { [regex]::Escape($_) }) -join "|"
# Capture category + shortname (first segment after category)
$CatShortRe = [regex]::new("(?:^|[\\/])(?<cat>$CategoryAlt)[\\/](?<name>[^\\/#?\s``]+)")

function Resolve-DefaultDocRoot {
    param([string]$RepoRoot)
    $fallback = "Assets/Doc"
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
    $assetsDoc = Join-Path $RepoRoot "Assets/Doc"
    if (Test-Path -LiteralPath $assetsDoc) { $roots += , ((Resolve-Path -LiteralPath $assetsDoc).Path) }
    $overrideRel = Resolve-DefaultDocRoot -RepoRoot $RepoRoot
    $overrideAbs = Join-Path $RepoRoot ($overrideRel.Replace('/', [string][IO.Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $overrideAbs) {
        $resolved = (Resolve-Path -LiteralPath $overrideAbs).Path
        if (-not ($roots | Where-Object { $_ -eq $resolved })) { $roots += , $resolved }
    }
    return , $roots
}

function Test-SkipScanPath {
    param([string]$FullPath)
    $norm = $FullPath -replace '\\', '/'
    if ($norm -match '/已完成(/|$)') { return $true }
    if ($norm -match '/证据(/|$)') { return $true }
    return $false
}

function Get-ShortNameIndex {
    param([string[]]$DocRoots, [string[]]$Cats)
    # shortname -> Object[] of @{ Category; DirPath }
    $index = @{}
    foreach ($root in $DocRoots) {
        $catDirs = @(Get-ChildItem -LiteralPath $root -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $Cats -contains $_.Name })
        foreach ($catDir in $catDirs) {
            if (Test-SkipScanPath -FullPath $catDir.FullName) { continue }
            $catName = $catDir.Name
            foreach ($child in @(Get-ChildItem -LiteralPath $catDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                if ($Cats -contains $child.Name) { continue }
                $sn = $child.Name
                if (-not $index.ContainsKey($sn)) { $index[$sn] = @() }
                $dup = $false
                foreach ($ex in @($index[$sn])) {
                    if ($ex.Category -eq $catName -and $ex.DirPath -eq $child.FullName) { $dup = $true; break }
                }
                if (-not $dup) {
                    $index[$sn] = @($index[$sn]) + @([pscustomobject]@{ Category = $catName; DirPath = $child.FullName })
                }
            }
        }
    }
    return $index
}

function Get-PathRefsFromLine {
    param([string]$Line)
    $refs = New-Object System.Collections.ArrayList
    # Markdown links [text](url) — Apply candidates
    foreach ($m in [regex]::Matches($Line, '\[[^\]]*\]\((?<url>[^)]+)\)')) {
        $url = $m.Groups['url'].Value.Trim()
        if ($url -match '^(https?://|mailto:)') { continue }
        $urlNoAnchor = ($url -split '#', 2)[0].Trim()
        if (-not $urlNoAnchor) { continue }
        $urlNorm = $urlNoAnchor.Replace('\', '/')
        $cm = $CatShortRe.Match($urlNorm)
        if (-not $cm.Success) { continue }
        $sn = $cm.Groups['name'].Value
        if ($sn -match '[{}]') { continue } # template placeholders like {短名}
        [void]$refs.Add([pscustomobject]@{
                Kind       = 'md-link'
                Raw        = $urlNoAnchor
                FullMatch  = $m.Value
                Category   = $cm.Groups['cat'].Value
                ShortName  = $sn
                SpanStart  = [int]$m.Index
                SpanLength = [int]$m.Length
                Applyable  = $true
            })
    }
    # Backtick path refs: default REPORT-ONLY (never Apply) — avoids rewriting narrative/acceptance prose.
    # Exception: line carrying **方案文件夹** — unique-hit category segment may Apply (A1).
    $isSchemeFolderLine = ($Line -match '\*\*方案文件夹\*\*')
    foreach ($m in [regex]::Matches($Line, '`(?<path>[^`\r\n]+)`')) {
        $path = $m.Groups['path'].Value.Trim()
        if ($path -match '^(https?://|mailto:)') { continue }
        if ($path -notmatch '[\\/]') { continue }
        $pathNorm = $path.Replace('\', '/')
        $cm = $CatShortRe.Match($pathNorm)
        if (-not $cm.Success) { continue }
        $sn = $cm.Groups['name'].Value
        if ($sn -match '[{}]') { continue }
        $overlap = $false
        foreach ($prev in $refs) {
            if ($prev.Kind -ne 'md-link') { continue }
            $ps = $prev.SpanStart; $pe = $ps + $prev.SpanLength
            if ($m.Index -ge $ps -and $m.Index -lt $pe) { $overlap = $true; break }
        }
        if ($overlap) { continue }
        [void]$refs.Add([pscustomobject]@{
                Kind       = 'backtick'
                Raw        = $path
                FullMatch  = $m.Value
                Category   = $cm.Groups['cat'].Value
                ShortName  = $sn
                SpanStart  = [int]$m.Index
                SpanLength = [int]$m.Length
                Applyable  = [bool]$isSchemeFolderLine
            })
    }
    return @($refs.ToArray())
}

function Rewrite-CategoryInText {
    param(
        [string]$Text,
        [string]$OldCategory,
        [string]$NewCategory,
        [string]$ShortName
    )
    # Replace category segment immediately before /{shortname} (both separators)
    $out = $Text.Replace(("$OldCategory/$ShortName"), ("$NewCategory/$ShortName"))
    $out = $out.Replace(("$OldCategory\$ShortName"), ("$NewCategory\$ShortName"))
    return $out
}

$docRoots = Get-DocRoots -RepoRoot $repoRoot
if ($docRoots.Count -eq 0) {
    Write-Host "repair-doc-crosslinks: no doc roots found under repo." -ForegroundColor Yellow
    exit 0
}

$index = Get-ShortNameIndex -DocRoots $docRoots -Cats $Categories
$mdFiles = @()
$scanRoots = $docRoots
if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $pathCandidate = $Path
    if (-not [IO.Path]::IsPathRooted($pathCandidate)) {
        $pathCandidate = Join-Path $repoRoot ($Path -replace '/', [IO.Path]::DirectorySeparatorChar)
    }
    if (-not (Test-Path -LiteralPath $pathCandidate)) {
        Write-Error "Path not found: $Path"
        exit 1
    }
    $scanRoots = @((Resolve-Path -LiteralPath $pathCandidate).Path)
}
foreach ($root in $scanRoots) {
    $item = Get-Item -LiteralPath $root
    if ($item.PSIsContainer) {
        foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -Filter "*.md" -File -ErrorAction SilentlyContinue)) {
            if (Test-SkipScanPath -FullPath $f.FullName) { continue }
            $mdFiles += , $f.FullName
        }
    } else {
        if ($item.Extension -ieq '.md' -and -not (Test-SkipScanPath -FullPath $item.FullName)) {
            $mdFiles += , $item.FullName
        }
    }
}

$issues = @()
$applied = 0

foreach ($filePath in $mdFiles) {
    $rel = $filePath.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.Encoding]::UTF8)
    $fileChanged = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $refs = @(Get-PathRefsFromLine -Line $line)
        if ($refs.Count -eq 0) { continue }
        # Apply replacements from right to left to keep indices stable
        $ordered = @($refs | Sort-Object -Property SpanStart -Descending)
        $newLine = $line
        $lineChanged = $false
        foreach ($ref in $ordered) {
            $sn = $ref.ShortName
            $declared = $ref.Category
            if (-not $index.ContainsKey($sn)) {
                $issues += ,[pscustomobject]@{
                    File = $rel; Line = ($i + 1); Kind = 'missing'
                    Old = $ref.Raw; Suggest = $null
                    Note = "shortname not found on disk"
                    Applyable = [bool]$ref.Applyable
                    RefKind = $ref.Kind
                }
                continue
            }
            $hits = @($index[$sn])
            $cats = @($hits | ForEach-Object { $_.Category } | Select-Object -Unique)
            if ($cats.Count -ge 2) {
                $catList = $cats -join ', '
                $issues += ,[pscustomobject]@{
                    File = $rel; Line = ($i + 1); Kind = 'ambiguous'
                    Old = $ref.Raw; Suggest = $null
                    Note = "ambiguous categories: $catList (no auto-fix)"
                    Applyable = [bool]$ref.Applyable
                    RefKind = $ref.Kind
                }
                continue
            }
            $realCat = $cats[0]
            if ($realCat -eq $declared) { continue }
            $suggested = Rewrite-CategoryInText -Text $ref.Raw -OldCategory $declared -NewCategory $realCat -ShortName $sn
            if ($ref.Applyable) {
                $issues += ,[pscustomobject]@{
                    File = $rel; Line = ($i + 1); Kind = 'mismatch'
                    Old = $ref.Raw; Suggest = $suggested
                    Note = "unique hit -> $realCat"
                    Applyable = $true
                    RefKind = $ref.Kind
                }
                if ($Apply) {
                    $segment = $newLine.Substring($ref.SpanStart, $ref.SpanLength)
                    $fixedSegment = Rewrite-CategoryInText -Text $segment -OldCategory $declared -NewCategory $realCat -ShortName $sn
                    $newLine = $newLine.Substring(0, $ref.SpanStart) + $fixedSegment + $newLine.Substring($ref.SpanStart + $ref.SpanLength)
                    $lineChanged = $true
                    $applied++
                }
            } else {
                # Ordinary backtick / non-Applyable: readonly report only — never an Apply candidate
                $issues += ,[pscustomobject]@{
                    File = $rel; Line = ($i + 1); Kind = 'backtick-report'
                    Old = $ref.Raw; Suggest = $suggested
                    Note = "readonly report only (not Apply candidate); unique hit -> $realCat"
                    Applyable = $false
                    RefKind = $ref.Kind
                }
            }
        }
        if ($lineChanged) {
            $lines[$i] = $newLine
            $fileChanged = $true
        }
    }
    if ($Apply -and $fileChanged) {
        [System.IO.File]::WriteAllLines($filePath, $lines, $utf8NoBom)
    }
}

$mismatch = @($issues | Where-Object { $_.Kind -eq 'mismatch' })
$backtickReport = @($issues | Where-Object { $_.Kind -eq 'backtick-report' })
$ambiguous = @($issues | Where-Object { $_.Kind -eq 'ambiguous' })
$missing = @($issues | Where-Object { $_.Kind -eq 'missing' })

$modeLabel = if ($Apply) { 'Apply' } else { 'readonly' }
Write-Host "repair-doc-crosslinks: roots=$($docRoots.Count) files=$($mdFiles.Count) mode=$modeLabel"
Write-Host "mismatch(apply-candidates)=$($mismatch.Count) backtick-report=$($backtickReport.Count) ambiguous=$($ambiguous.Count) missing=$($missing.Count) applied=$applied"

foreach ($it in $issues) {
    if ($it.Kind -eq 'mismatch') {
        Write-Host "$($it.File):$($it.Line) $($it.Old) -> $($it.Suggest)"
    } elseif ($it.Kind -eq 'backtick-report') {
        Write-Host "$($it.File):$($it.Line) $($it.Old) -> REPORT-ONLY $($it.Suggest) ($($it.Note))" -ForegroundColor DarkGray
    } elseif ($it.Kind -eq 'ambiguous') {
        Write-Host "$($it.File):$($it.Line) $($it.Old) -> AMBIGUOUS ($($it.Note))" -ForegroundColor Yellow
    } else {
        Write-Host "$($it.File):$($it.Line) $($it.Old) -> MISSING ($($it.Note))" -ForegroundColor Yellow
    }
}

if (-not $Apply -and $mismatch.Count -gt 0) {
    Write-Host "Hint: re-run with -Path <file-or-dir> -Apply to rewrite unique-hit md-link and **方案文件夹** backtick mismatches (ordinary backticks stay report-only)." -ForegroundColor Cyan
}

exit 0
