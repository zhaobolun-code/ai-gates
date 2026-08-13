<#
.SYNOPSIS
  从 .ai-gates/lessons-learned.md 主表解析「连续触发晋升」升级候选，输出 .ai-gates/evolution-candidates.yaml。
  （机制 B：近 90 天 ≥2 次命中且最近命中 ≤30 天 + 晋升列为空 → 升级候选；候选≠已确认，须人工确认留痕 + 用户「准」。）

.DESCRIPTION
  - 表头用包含匹配定位列（真实表头第 3 列为「教训（一句话）」，用 -like 匹配，不硬编码列号）
  - 行末字段语义：末段=「晋升」、次末段=「作用域」；字段数超表头（作用域内嵌 | 的真实行）时溢出段并入作用域，
    不得因字段数超表头而误判/弃行
  - 日期前缀提取：「最近命中」单元格可能带后缀文本（如 2026-08-12（…二次命中）），按正则 ^\d{4}-\d{2}-\d{2} 提取；
    提取失败 → 该字段视为无命中并在 stderr 标注；行解析失败 → 跳过并 stderr 标注行号（fail-safe，不中断）；
    表头缺失 → 报错 exit 2
  - 候选判定（保守近似，单时间戳列无法数多次命中）：最近命中非空 ∧ 前缀日期距今 ≤30 天 ∧ 「晋升」列为空
    ∧ 「日期」前缀日期距今 ≤90 天 ∧ 日期 < 最近命中（= 近 90 天内 ≥2 个独立时间戳留痕：创建 + ≥1 命中）
  - 幂等：可反复运行；输出文件为机器产物，勿手工编辑

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/compute-evolution-candidates.ps1 -DryRun
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/compute-evolution-candidates.ps1
#>

[CmdletBinding()]
param(
    [string]$LessonsPath = "",
    [string]$OutPath = "",
    [switch]$DryRun
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

if (-not $LessonsPath) { $LessonsPath = Join-Path $repoRoot ".ai-gates\lessons-learned.md" }
if (-not $OutPath) { $OutPath = Join-Path $repoRoot ".ai-gates\evolution-candidates.yaml" }

if (-not (Test-Path -LiteralPath $LessonsPath)) {
    Write-Error "lessons-learned.md not found: $LessonsPath"
    exit 2
}

$DateRegex = '^\d{4}-\d{2}-\d{2}'

function Get-DatePrefix {
    param([string]$Cell)
    if ([string]::IsNullOrWhiteSpace($Cell)) { return $null }
    $m = [Regex]::Match($Cell, $DateRegex)
    if ($m.Success) { return $m.Value }
    return $null
}

# 行内容单元格提取：保留空单元格（晋升/作用域列常为空），仅去除首尾管道产生的空段
function Get-ContentCells {
    param([string]$Line)
    $parts = $Line -split '\|'
    if ($parts.Count -lt 3) { return @() }
    $cells = @()
    for ($k = 1; $k -lt $parts.Count - 1; $k++) {
        $cells += $parts[$k].Trim()
    }
    return $cells
}

$lines = Get-Content -LiteralPath $LessonsPath -Encoding UTF8

# 表头定位：包含匹配（教训 / 最近命中 / 晋升），不依赖列名逐字相等
$headerIdx = -1
$headerCells = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^\|') { continue }
    $cells = @(Get-ContentCells -Line $lines[$i])
    if ($cells.Count -ge 6 -and ($cells -like '*教训*') -and ($cells -like '*最近命中*') -and ($cells -like '*晋升*')) {
        $headerIdx = $i
        $headerCells = $cells
        break
    }
}
if ($headerIdx -lt 0) {
    Write-Error "lessons-learned.md table header not found (need columns containing 教训 / 最近命中 / 晋升)"
    exit 2
}

$idxDate = -1; $idxModule = -1; $idxLesson = -1; $idxLastHit = -1; $idxScope = -1; $idxPromoted = -1
for ($j = 0; $j -lt $headerCells.Count; $j++) {
    if ($headerCells[$j] -like '*日期*') { $idxDate = $j }
    if ($headerCells[$j] -like '*模块*') { $idxModule = $j }
    if ($headerCells[$j] -like '*教训*') { $idxLesson = $j }
    if ($headerCells[$j] -like '*最近命中*') { $idxLastHit = $j }
    if ($headerCells[$j] -like '*作用域*') { $idxScope = $j }
    if ($headerCells[$j] -like '*晋升*') { $idxPromoted = $j }
}
if ($idxDate -lt 0 -or $idxLesson -lt 0 -or $idxLastHit -lt 0 -or $idxPromoted -lt 0) {
    Write-Error "lessons-learned.md header missing required columns (日期 / 教训 / 最近命中 / 晋升)"
    exit 2
}
if ($idxScope -lt 0) { $idxScope = $idxPromoted - 1 }
$headerCount = $headerCells.Count

$today = [DateTime]::Today
$candidates = @()

for ($i = $headerIdx + 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -notmatch '^\|') { continue }
    $cells = @(Get-ContentCells -Line $line)
    if ($cells.Count -lt 3) { continue }
    # 分隔行（---）跳过
    if (($cells -join '') -match '^[\s\-:]+$') { continue }

    if ($cells.Count -ne $headerCount) {
        if ($cells.Count -lt $headerCount) {
            [Console]::Error.WriteLine(("skip row {0}: expected {1} cells got {2} (fail-safe)" -f ($i + 1), $headerCount, $cells.Count))
            continue
        }
        # 字段数超表头：作用域内嵌 | 的真实行形态 → 溢出段并入作用域，按行末段取值
    }

    # 行末字段语义：末段=晋升、次末段=作用域；溢出并入作用域
    $promoted = $cells[$cells.Count - 1]
    $scope = $cells[$cells.Count - 2]
    if ($cells.Count -gt $headerCount) {
        $scopeParts = @($cells[$idxScope..($cells.Count - 2)])
        $scope = $scopeParts -join '|'
    }

    $dateStr = $cells[$idxDate]
    $lastHitStr = $cells[$idxLastHit]

    $datePrefix = Get-DatePrefix -Cell $dateStr
    if (-not $datePrefix) {
        [Console]::Error.WriteLine(("skip row {0}: 日期无有效前缀 '{1}' (fail-safe)" -f ($i + 1), $dateStr))
        continue
    }
    $lastHitPrefix = Get-DatePrefix -Cell $lastHitStr
    if (-not $lastHitPrefix) {
        if (-not [string]::IsNullOrWhiteSpace($lastHitStr)) {
            [Console]::Error.WriteLine(("note row {0}: 最近命中无日期前缀 '{1}'，视为无命中" -f ($i + 1), $lastHitStr))
        }
        continue
    }

    $dateDate = [DateTime]::ParseExact($datePrefix, 'yyyy-MM-dd', $null)
    $lastHitDate = [DateTime]::ParseExact($lastHitPrefix, 'yyyy-MM-dd', $null)

    $isCandidate = $true
    if (-not [string]::IsNullOrWhiteSpace($promoted)) { $isCandidate = $false }
    if (($today - $lastHitDate).Days -gt 30) { $isCandidate = $false }
    if (($today - $dateDate).Days -gt 90) { $isCandidate = $false }
    if ($dateDate -ge $lastHitDate) { $isCandidate = $false }

    if (-not $isCandidate) { continue }

    $lesson = [string]$cells[$idxLesson]
    if ($lesson.Length -gt 40) { $lesson = $lesson.Substring(0, 40) + '…' }

    $candidates += [ordered]@{
        date     = $datePrefix
        module   = [string]$cells[$idxModule]
        lesson   = $lesson
        last_hit = $lastHitPrefix
        hit_approx = 2
        promoted = $promoted
        source   = 'lessons'
    }
}

# ---------------------------------------------------------------------------
# 数据源 2：design-patterns.md 词条表「典故词」（判据仍 01-B；0 条命中合法）
# 不改上方 lessons 主路径的 90/30 数字。
# ---------------------------------------------------------------------------
$DesignPatternsPath = Join-Path $repoRoot ".ai-gates\skills\references\design-patterns.md"
$patternTerms = New-Object System.Collections.Generic.List[string]
$patternHitCount = 0

if (-not (Test-Path -LiteralPath $DesignPatternsPath)) {
    [Console]::Error.WriteLine(("note: design-patterns.md not found: {0} (0 terms)" -f $DesignPatternsPath))
} else {
    $dpLines = Get-Content -LiteralPath $DesignPatternsPath -Encoding UTF8
    $dpHeaderIdx = -1
    $dpHeaderCells = @()
    for ($di = 0; $di -lt $dpLines.Count; $di++) {
        if ($dpLines[$di] -notmatch '^\|') { continue }
        $dpCells = @(Get-ContentCells -Line $dpLines[$di])
        if ($dpCells.Count -ge 1 -and ($dpCells -like '*典故词*')) {
            $dpHeaderIdx = $di
            $dpHeaderCells = $dpCells
            break
        }
    }
    $idxTerm = -1
    for ($dj = 0; $dj -lt $dpHeaderCells.Count; $dj++) {
        if ($dpHeaderCells[$dj] -like '*典故词*') { $idxTerm = $dj; break }
    }
    if ($dpHeaderIdx -lt 0 -or $idxTerm -lt 0) {
        [Console]::Error.WriteLine("note: design-patterns.md 词条表表头未找到（典故词）；0 terms")
    } else {
        for ($di = $dpHeaderIdx + 1; $di -lt $dpLines.Count; $di++) {
            $dpLine = $dpLines[$di]
            if ($dpLine -notmatch '^\|') { break }
            $dpCells = @(Get-ContentCells -Line $dpLine)
            if ($dpCells.Count -lt 1) { continue }
            if (($dpCells -join '') -match '^[\s\-:]+$') { continue }
            if ($idxTerm -ge $dpCells.Count) { continue }
            $term = ([string]$dpCells[$idxTerm]).Trim()
            if (-not [string]::IsNullOrWhiteSpace($term)) {
                [void]$patternTerms.Add($term)
            }
        }
    }

    if ($patternTerms.Count -gt 0) {
        for ($i = $headerIdx + 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -notmatch '^\|') { continue }
            $cells = @(Get-ContentCells -Line $line)
            if ($cells.Count -lt 3) { continue }
            if (($cells -join '') -match '^[\s\-:]+$') { continue }

            $promoted = $cells[$cells.Count - 1]
            $dateStr = $cells[$idxDate]
            $lastHitStr = $cells[$idxLastHit]
            $datePrefix = Get-DatePrefix -Cell $dateStr
            if (-not $datePrefix) { continue }
            $lastHitPrefix = Get-DatePrefix -Cell $lastHitStr
            if (-not $lastHitPrefix) { continue }

            $dateDate = [DateTime]::ParseExact($datePrefix, 'yyyy-MM-dd', $null)
            $lastHitDate = [DateTime]::ParseExact($lastHitPrefix, 'yyyy-MM-dd', $null)

            $isCandidate = $true
            if (-not [string]::IsNullOrWhiteSpace($promoted)) { $isCandidate = $false }
            if (($today - $lastHitDate).Days -gt 30) { $isCandidate = $false }
            if (($today - $dateDate).Days -gt 90) { $isCandidate = $false }
            if ($dateDate -ge $lastHitDate) { $isCandidate = $false }
            if (-not $isCandidate) { continue }

            $rowText = ($cells -join '|')
            $matchedTerm = $null
            foreach ($term in $patternTerms) {
                if ($rowText.IndexOf($term, [System.StringComparison]::Ordinal) -ge 0) {
                    $matchedTerm = $term
                    break
                }
            }
            if (-not $matchedTerm) { continue }

            $lesson = [string]$cells[$idxLesson]
            if ($lesson.Length -gt 40) { $lesson = $lesson.Substring(0, 40) + '…' }

            $patternHitCount++
            $candidates += [ordered]@{
                date       = $datePrefix
                module     = [string]$cells[$idxModule]
                lesson     = $lesson
                last_hit   = $lastHitPrefix
                hit_approx = 2
                promoted   = $promoted
                source     = 'design-patterns'
                pattern    = $matchedTerm
            }
        }
    }
}

Write-Host ("design-patterns terms: {0}" -f $patternTerms.Count)
if ($patternTerms.Count -gt 0) {
    Write-Host ("- {0}" -f ($patternTerms -join ', '))
}
Write-Host ("design-patterns source hits: {0}" -f $patternHitCount)

if ($DryRun) {
    Write-Host ("candidates: {0}" -f $candidates.Count)
    foreach ($c in $candidates) {
        $src = $c.source
        Write-Host ("- {0} | {1} | 最近命中={2} | 命中近似={3} | 晋升='{4}' | source={5}" -f $c.date, $c.module, $c.last_hit, $c.hit_approx, $c.promoted, $src)
    }
    exit 0
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 升级候选（自动生成：compute-evolution-candidates.ps1，勿手工编辑）")
[void]$sb.AppendLine("# 判据（保守近似，单时间戳列无法数多次命中）：最近命中 ≤30 天 ∧ 晋升列为空 ∧ 创建 ≤90 天 ∧ 日期 < 最近命中（≥2 独立时间戳留痕）")
[void]$sb.AppendLine("# 候选≠已确认：须人工确认留痕 + 用户「准」后方可升级（见 lessons-learned §时效归档）；同族错误不重复计数")
[void]$sb.AppendLine("# 数据源：lessons=主表 01-B；design-patterns=词条表典故词命中且 01-B（0 条合法）")
[void]$sb.AppendLine('version: 1')
[void]$sb.AppendLine('candidates:')
foreach ($c in $candidates) {
    [void]$sb.AppendLine("  - date: $($c.date)")
    [void]$sb.AppendLine("    module: $($c.module)")
    [void]$sb.AppendLine("    lesson: $($c.lesson)")
    [void]$sb.AppendLine("    last_hit: $($c.last_hit)")
    [void]$sb.AppendLine("    hit_approx: $($c.hit_approx)")
    [void]$sb.AppendLine("    promoted: '$($c.promoted)'")
    [void]$sb.AppendLine("    source: $($c.source)")
    if ($c['pattern']) {
        [void]$sb.AppendLine("    pattern: $($c.pattern)")
    }
}

[System.IO.File]::WriteAllText($OutPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "evolution candidates written: $OutPath"
Write-Host ("candidates: {0}" -f $candidates.Count)
exit 0
