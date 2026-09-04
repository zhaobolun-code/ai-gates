# test-first A1-A10: session-dash static page + USER-GUIDE pointer.
# ASCII-only source (Windows PS 5 parser). Chinese needles via U().
# Lesson 2026-08-18: polarity (affirmative call vs ban/not words).
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

$here = $PSScriptRoot

function Resolve-RepoRoot {
    $p = $here
    for ($i = 0; $i -lt 16; $i++) {
        $ver = Join-Path $p ".ai-gates\skills\VERSION"
        if (Test-Path -LiteralPath $ver) { return $p }
        $p = Split-Path -Parent $p
        if (-not $p) { break }
    }
    throw "cannot resolve repo root from $here"
}

function Read-Utf8([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing: " + $path }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function U([int[]]$cps) {
    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($c in $cps) { [void]$chars.Add([char]$c) }
    return (-join $chars.ToArray())
}

$fail = 0
$pass = 0

function Assert-True([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) {
        $script:pass++
        Write-Host "[PASS] $name"
    } else {
        $script:fail++
        Write-Host "[FAIL] $name :: $detail"
    }
}

function Test-AffirmativePhrase([string]$src, [string]$phrase) {
    $bu = [char]0x4E0D
    $jin = U @(0x7981, 0x6B62)
    $bude = U @(0x4E0D, 0x5F97)
    $idx = 0
    while ($true) {
        $i = $src.IndexOf($phrase, $idx)
        if ($i -lt 0) { break }
        $prefix = ""
        if ($i -gt 0) {
            $start = [Math]::Max(0, $i - 12)
            $prefix = $src.Substring($start, $i - $start)
        }
        $hasNeg = ($prefix.IndexOf([string]$bu) -ge 0) -or ($prefix.IndexOf($jin) -ge 0) -or ($prefix.IndexOf($bude) -ge 0)
        if (-not $hasNeg) { return $true }
        $idx = $i + $phrase.Length
    }
    return $false
}

function Test-HasEmDash([string]$s) {
    return ($s.IndexOf([char]0x2014) -ge 0)
}

function Test-PreOnlyInDetails([string]$html) {
    $idx = 0
    while ($true) {
        $i = $html.IndexOf("<pre", $idx, [StringComparison]::OrdinalIgnoreCase)
        if ($i -lt 0) { return $true }
        $before = $html.Substring(0, $i)
        $lastOpen = $before.LastIndexOf("<details", [StringComparison]::OrdinalIgnoreCase)
        $lastClose = $before.LastIndexOf("</details>", [StringComparison]::OrdinalIgnoreCase)
        if ($lastOpen -lt 0 -or $lastOpen -lt $lastClose) { return $false }
        $idx = $i + 4
    }
}

$repo = Resolve-RepoRoot
Write-Host ("CMD: powershell -File " + $PSCommandPath)
Write-Host ("repo=" + $repo)

$guidePath = Join-Path $repo ".ai-gates\USER-GUIDE.md"
$genPath = Join-Path $repo ".ai-gates\scripts\generate-session-dash.ps1"
$htmlPath = Join-Path $repo ".ai-gates\verify\session-dash.html"
$needleHtml = "session-dash.html"

$nShuangJi = U @(0x53CC, 0x51FB)
$nZhiJieDaKai = U @(0x76F4, 0x63A5, 0x6253, 0x5F00, 0x6587, 0x4EF6)
$nBuShiZhangDan = U @(0x4E0D, 0x662F, 0x8D26, 0x5355)
$nTokenJiFei = "Token " + (U @(0x8BA1, 0x8D39))
$nZhangDanToken = (U @(0x8D26, 0x5355)) + " Token"
$nTiaoShu = U @(0x6761, 0x6570)
$nZiJie = U @(0x5B57, 0x8282)
$nTiJi = U @(0x4F53, 0x79EF)
$nJiBen = U @(0x57FA, 0x672C, 0x64CD, 0x4F5C)

# --- A1 USER-GUIDE ---
$guideOk = Test-Path -LiteralPath $guidePath
$guide = ""
if ($guideOk) { $guide = Read-Utf8 $guidePath }

$a1RowOk = $false
$a1HttpBad = $false
if ($guideOk) {
    $sec = $guide
    $iSec = $guide.IndexOf($nJiBen)
    if ($iSec -ge 0) { $sec = $guide.Substring($iSec) }
    $lines = $sec -split "`r?`n"
    foreach ($ln in $lines) {
        if ($ln.IndexOf($needleHtml) -lt 0) { continue }
        $hasOpen = ($ln.IndexOf($nShuangJi) -ge 0) -or ($ln.IndexOf($nZhiJieDaKai) -ge 0)
        if ($hasOpen) { $a1RowOk = $true }
        if (($ln.IndexOf("http://") -ge 0) -or ($ln.IndexOf("localhost") -ge 0)) {
            $a1HttpBad = $true
        }
    }
}
Assert-True "A1-guide-row" ($guideOk -and $a1RowOk -and (-not $a1HttpBad)) ("need session-dash.html + shuangji/zhijie; http/localhost bad=$a1HttpBad")

# --- A2 HTML ---
$htmlOk = Test-Path -LiteralPath $htmlPath
$html = ""
if ($htmlOk) { $html = Read-Utf8 $htmlPath }

$a2NotBill = $htmlOk -and ($html.IndexOf($nBuShiZhangDan) -ge 0)
$a2BadToken = $false
if ($htmlOk) {
    if (Test-AffirmativePhrase $html $nTokenJiFei) { $a2BadToken = $true }
    if (Test-AffirmativePhrase $html $nZhangDanToken) { $a2BadToken = $true }
}
$a2Vol = $htmlOk -and (($html.IndexOf($nTiaoShu) -ge 0) -or ($html.IndexOf($nZiJie) -ge 0) -or ($html.IndexOf($nTiJi) -ge 0))
Assert-True "A2-html-not-bill" ($a2NotBill -and (-not $a2BadToken) -and $a2Vol) ("notBill=$a2NotBill badToken=$a2BadToken vol=$a2Vol")

# --- A3 generate script tail-read constants ---
$genOk = Test-Path -LiteralPath $genPath
$gen = ""
if ($genOk) { $gen = Read-Utf8 $genPath }

$a3MaxBytes = $genOk -and ($gen -match 'MAX_BYTES\s*=\s*1048576')
$a3MaxTail = $genOk -and ($gen -match 'MAX_TAIL_LINES\s*=\s*4096')
$a3Seek = $genOk -and (($gen.IndexOf("FileStream") -ge 0) -or ($gen.IndexOf("Seek") -ge 0) -or ($gen.IndexOf(".Position") -ge 0))
$a3Banned = $false
if ($genOk) {
    $glines = $gen -split "`r?`n"
    foreach ($gl in $glines) {
        $mentionsLog = ($gl.IndexOf("mark-changelog-write.log") -ge 0) -or ($gl.IndexOf("write-audit.log") -ge 0)
        $mentionsBad = ($gl.IndexOf("ReadAllText") -ge 0) -or ($gl.IndexOf("Get-Content -Raw") -ge 0)
        if ($mentionsLog -and $mentionsBad) { $a3Banned = $true }
    }
}
Assert-True "A3-tail-read" ($a3MaxBytes -and $a3MaxTail -and $a3Seek -and (-not $a3Banned)) ("MAX_BYTES=$a3MaxBytes MAX_TAIL=$a3MaxTail seek=$a3Seek banned=$a3Banned")

# --- A4 no HTTP client + html exists (caller runs generate first) ---
$a4Http = $false
if ($genOk) {
    if (($gen.IndexOf("Invoke-RestMethod") -ge 0) -or ($gen.IndexOf("Invoke-WebRequest") -ge 0)) {
        $a4Http = $true
    }
}
Assert-True "A4-html-written" ($htmlOk -and (-not $a4Http)) ("htmlExists=$htmlOk invokeHttp=$a4Http")

# --- A5 KPI + bar ---
$kpiMatches = @()
if ($htmlOk) {
    $kpiMatches = [regex]::Matches($html, 'class="kpi"')
}
$a5Kpi = $htmlOk -and ($kpiMatches.Count -ge 3)
$a5Bar = $htmlOk -and ($html.IndexOf('class="bar"') -ge 0)
Assert-True "A5-kpi-bar" ($a5Kpi -and $a5Bar) ("kpiCount=$($kpiMatches.Count) hasBar=$a5Bar")

# --- A6 no U+2014 in generate script and html ---
$a6Gen = $genOk -and (-not (Test-HasEmDash $gen))
$a6Html = $htmlOk -and (-not (Test-HasEmDash $html))
Assert-True "A6-no-emdash" ($a6Gen -and $a6Html) ("genOk=$a6Gen htmlOk=$a6Html")

# --- A7 details wrap + pre only inside details ---
$a7Details = $htmlOk -and ($html.IndexOf("<details") -ge 0)
$a7PreOk = $htmlOk -and (Test-PreOnlyInDetails $html)
Assert-True "A7-details-pre" ($a7Details -and $a7PreOk) ("hasDetails=$a7Details preOnlyInDetails=$a7PreOk")

# --- A8 html file size < 100000 bytes ---
$htmlLen = 0
if ($htmlOk) { $htmlLen = [int64](Get-Item -LiteralPath $htmlPath).Length }
$a8Ok = $htmlOk -and ($htmlLen -lt 100000)
Assert-True "A8-html-size" $a8Ok ("html Length=$htmlLen need <100000")


# --- A9 mojibake repaired in html preview; Repair-Mojibake present ---
# Needle = literal mojibake of hua-xue prefix (UTF-8-as-GBK): chars U+9356 U+6827
$a9MojibakeNeedle = -join @([char]0x9356, [char]0x6827, [char]0xE11F)  # literal mojibake of hua-xue-wen prefix
$a9HasFn = $genOk -and ($gen.IndexOf("Repair-Mojibake") -ge 0)
$a9NoMojibake = $htmlOk -and ($html.IndexOf($a9MojibakeNeedle) -lt 0)
Assert-True "A9-mojibake-repair" ($a9HasFn -and $a9NoMojibake) ("hasFn=$a9HasFn noMojibake=$a9NoMojibake")
# --- A10: GBK-as-UTF8 marker U+07B7 absent; PARSE_FAIL implies 无法识别 ---
$a10Marker = [char]0x07B7
$a10Wufa = -join @([char]0x65E0, [char]0x6CD5, [char]0x8BC6, [char]0x522B)
$a10NoMarker = $htmlOk -and ($html.IndexOf([string]$a10Marker, [StringComparison]::Ordinal) -lt 0)
$a10ParseOk = $true
if ($htmlOk -and ($html.IndexOf("PARSE_FAIL", [StringComparison]::Ordinal) -ge 0)) {
    $a10ParseOk = ($html.IndexOf($a10Wufa, [StringComparison]::Ordinal) -ge 0)
}
Assert-True "A10-gbk-line-decode" ($a10NoMarker -and $a10ParseOk) ("noU07B7=$a10NoMarker parseOk=$a10ParseOk")
Write-Host ("RESULT pass=$pass fail=$fail")
if ($fail -gt 0) { exit 1 }
exit 0