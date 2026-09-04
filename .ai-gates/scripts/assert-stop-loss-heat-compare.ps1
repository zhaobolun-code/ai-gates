# test-first A1-A4: stop-loss / heat compare page + diagnosis-gates pointer.
# ASCII-only source (Windows PS 5 parser). Chinese needles via U().
# Lesson 2026-08-18: A4 uses polarity (affirmative call vs ban/not words).
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

$repo = Resolve-RepoRoot
Write-Host ("CMD: powershell -File " + $PSCommandPath)
Write-Host ("repo=" + $repo)

$compareRel = ".ai-gates\skills\references\stop-loss-heat-compare.md"
$comparePath = Join-Path $repo $compareRel
$diagPath = Join-Path $repo ".ai-gates\skills\references\diagnosis-gates.md"
$needleFile = "stop-loss-heat-compare.md"

$nRemind = U @(0x63D0, 0x9192)
$nUpgrade = U @(0x5347, 0x7EA7, 0x4FE1, 0x53F7)
$nHard = U @(0x786C, 0x505C)
$nHardWl = U @(0x786C, 0x505C, 0x767D, 0x540D, 0x5355)
$nNoLift = (U @(0x4E0D, 0x5347)) + " Full"
$nHeji = U @(0x5408, 0x8BA1, 0x8FBE, 0x5230)
$nForceStop = U @(0x5F3A, 0x5236, 0x505C, 0x8F66)
$nReijian = U @(0x590D, 0x8BAE)
$nLeiji = U @(0x7D2F, 0x8BA1)
$nEquate = U @(0x7B49, 0x540C)
$nZhisun = U @(0x6B62, 0x635F)
$nFail = U @(0x5931, 0x8D25)
$nRexiu = U @(0x70ED, 0x4FEE)
$nXinKaiZhang = U @(0x65B0, 0x5F00, 0x70ED, 0x5EA6, 0x8D26)
$nXinKaiGang = U @(0x65B0, 0x5F00, 0x611F, 0x77E5, 0x5C97)
$nJin = U @(0x7981, 0x6B62)
$nBuDe = U @(0x4E0D, 0x5F97)
$ge = [char]0x2265

# --- A1 ---
$a1Exists = Test-Path -LiteralPath $comparePath
Assert-True "A1-compare-exists" $a1Exists ("missing: " + $compareRel)

$cmp = ""
if ($a1Exists) { $cmp = Read-Utf8 $comparePath }

$hasRemind = $a1Exists -and ($cmp.IndexOf($nRemind) -ge 0)
$hasUpgrade = $a1Exists -and ($cmp.IndexOf($nUpgrade) -ge 0)
$hasHard = $a1Exists -and ($cmp.IndexOf($nHard) -ge 0)
Assert-True "A1-tier-names" ($hasRemind -and $hasUpgrade -and $hasHard) "need tier names remind/upgrade/hardstop"

$anchor14 = $a1Exists -and ($cmp.IndexOf($nRemind) -ge 0) -and (($cmp.IndexOf(([char]0x00A7).ToString() + "1.4") -ge 0) -or ($cmp.IndexOf("1.4") -ge 0))
$anchorPrt = $a1Exists -and ($cmp.IndexOf($nUpgrade) -ge 0) -and ($cmp.IndexOf("plan-review-tiers") -ge 0) -and ($cmp.IndexOf($nNoLift) -ge 0)
$anchorHard = $a1Exists -and ($cmp.IndexOf($nHard) -ge 0) -and (($cmp.IndexOf(([char]0x00A7).ToString() + "0.1.1") -ge 0) -or ($cmp.IndexOf("0.1.1") -ge 0) -or ($cmp.IndexOf($nHardWl) -ge 0))
Assert-True "A1-tier-anchors" ($anchor14 -and $anchorPrt -and $anchorHard) "each tier must point 1.4 / plan-review-tiers+no-lift-Full / 0.1.1-or-hard-wl"

# --- A2 ---
$diagOk = Test-Path -LiteralPath $diagPath
$diag = ""
$countNeedle = 0
if ($diagOk) {
    $diag = Read-Utf8 $diagPath
    $idx = 0
    while ($true) {
        $i = $diag.IndexOf($needleFile, $idx)
        if ($i -lt 0) { break }
        $countNeedle++
        $idx = $i + $needleFile.Length
    }
}
Assert-True "A2-pointer-once" ($diagOk -and ($countNeedle -eq 1)) ("needle count=$countNeedle want=1")

# --- A3 (numbers must remain) ---
$a3aTight = $false
if ($diagOk) {
    $iH = $diag.IndexOf($nHeji)
    if ($iH -ge 0) {
        $win = $diag.Substring($iH, [Math]::Min(40, $diag.Length - $iH))
        $a3aTight = ($win.IndexOf("3") -ge 0) -and ($win.IndexOf($nForceStop) -ge 0)
    }
}
Assert-True "A3-stop-loss-3" $a3aTight "need heji + 3 + force-stop nearby"

$a3b = $false
if ($diagOk) {
    $tokGe2 = $ge.ToString() + "2"
    $idx2 = 0
    while (-not $a3b) {
        $i2 = $diag.IndexOf($tokGe2, $idx2)
        if ($i2 -lt 0) { break }
        $start = $i2 - 40
        if ($start -lt 0) { $start = 0 }
        $len = 80
        if (($start + $len) -gt $diag.Length) { $len = $diag.Length - $start }
        $win = $diag.Substring($start, $len)
        if (($win.IndexOf($nFail) -ge 0) -and ($diag.IndexOf($nReijian) -ge 0) -and ($diag.IndexOf($nRexiu) -ge 0)) {
            $a3b = $true
            break
        }
        $idx2 = $i2 + $tokGe2.Length
    }
}
Assert-True "A3-hotfix-ge2-reconsider" $a3b "need ge2 near fail + reconsider; hotfix present"

$a3c = $false
if ($diagOk) {
    $tokGe3 = $ge.ToString() + "3"
    $i3 = $diag.IndexOf($tokGe3)
    if ($i3 -ge 0) {
        $start = [Math]::Max(0, $i3 - 24)
        $win = $diag.Substring($start, [Math]::Min(60, $diag.Length - $start))
        $a3c = ($win.IndexOf($nLeiji) -ge 0) -and ($diag.IndexOf($nEquate) -ge 0) -and ($diag.IndexOf($nZhisun) -ge 0)
    }
}
Assert-True "A3-cum-ge3-equate-stop" $a3c "need leiji+ge3 + equate + stop-loss"

# --- A4 polarity ---
$hasPrefixed = $false
if ($a1Exists) {
    $idx = 0
    while ($true) {
        $i = $cmp.IndexOf($nXinKaiZhang, $idx)
        if ($i -lt 0) { break }
        $start = [Math]::Max(0, $i - 12)
        $prefix = $cmp.Substring($start, $i - $start)
        if (($prefix.IndexOf([string]([char]0x4E0D)) -ge 0) -or ($prefix.IndexOf($nJin) -ge 0) -or ($prefix.IndexOf($nBuDe) -ge 0)) {
            $hasPrefixed = $true
            break
        }
        $idx = $i + $nXinKaiZhang.Length
    }
}
Assert-True "A4-ban-new-heat-ledger" $hasPrefixed "need ban/not prefix + new-heat-ledger"

$badZhang = $a1Exists -and (Test-AffirmativePhrase $cmp $nXinKaiZhang)
$badGang = $a1Exists -and (Test-AffirmativePhrase $cmp $nXinKaiGang)
Assert-True "A4-no-affirmative-new-heat" ((-not $badZhang) -and (-not $badGang)) "affirmative new-heat-ledger or new-sense-role without ban"

Write-Host ("SUMMARY pass=$pass fail=$fail")
if ($fail -gt 0) { exit 1 } else { exit 0 }