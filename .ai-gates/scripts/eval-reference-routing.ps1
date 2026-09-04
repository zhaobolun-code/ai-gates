# eval-reference-routing.ps1 — zero-API trigger-table scorer.
# Match case utterance against reference-routing.md trigger cells (contains/keywords).
# Positive: expect filename ranks first. Negative: forbid filename must not rank first.
# No paid API. ASCII-only source (Windows PS 5 parser).
# Lesson 2026-08-12: do not require rg of this script's own filename.
param(
    [string]$CasesPath = "",
    [string]$RoutingPath = ""
)
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

function U([int[]]$codes) {
    return (-join ($codes | ForEach-Object { [char]$_ }))
}

function Resolve-RepoRoot {
    $p = $PSScriptRoot
    for ($i = 0; $i -lt 12; $i++) {
        $ver = Join-Path $p ".ai-gates\skills\VERSION"
        if (Test-Path -LiteralPath $ver) { return $p }
        $p = Split-Path -Parent $p
        if (-not $p) { break }
    }
    throw "cannot resolve repo root from " + $PSScriptRoot
}

function Read-Utf8([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing: " + $path }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

$tick = [char]96
$tBan = U @(31105, 27490)
$tLoad = U @(21152, 36733)
$tNoRead = U @(19981, 35835)
$tAnd = [char]19988
$tOr = [char]25110
$tDoing = U @(25191, 34892, 20013)
$tSigned = U @(31614, 25910)
$tLq = [char]0x300C
$tRq = [char]0x300D
$quoteRe = $tLq + "([^" + $tRq + "]+)" + $tRq

$repo = Resolve-RepoRoot
Write-Host ("CMD: powershell -File " + $PSCommandPath)
Write-Host ("repo=" + $repo)

if ([string]::IsNullOrWhiteSpace($RoutingPath)) {
    $RoutingPath = Join-Path $repo ".ai-gates\skills\references\reference-routing.md"
}
if ([string]::IsNullOrWhiteSpace($CasesPath)) {
    $hits = @(Get-ChildItem -LiteralPath (Join-Path $repo ".ai-gates\Doc") -Recurse -Filter "routing-cases.json" -ErrorAction SilentlyContinue)
    if ($hits.Count -eq 0) { throw "routing-cases.json not found under .ai-gates/Doc" }
    $prefer = @($hits | Where-Object { $_.FullName.IndexOf($tDoing) -ge 0 })
    if ($prefer.Count -gt 0) { $CasesPath = $prefer[0].FullName }
    else { $CasesPath = $hits[0].FullName }
}

$routingTxt = Read-Utf8 $RoutingPath
$casesObj = (Read-Utf8 $CasesPath) | ConvertFrom-Json
$cases = @($casesObj.cases)

# file -> list of load keywords (from trigger column only)
$fileKw = @{}
$ownerSet = New-Object "System.Collections.Generic.HashSet[string]"

function Get-LoadPart([string]$trigger) {
    $cut = $trigger.Length
    $iLoad = $trigger.IndexOf($tLoad)
    $iBan = $trigger.IndexOf($tBan)
    $iNo = $trigger.IndexOf($tNoRead)
    if ($iLoad -ge 0 -and $iLoad -lt $cut) { $cut = $iLoad }
    if ($iBan -ge 0 -and $iBan -lt $cut) { $cut = $iBan }
    if ($iNo -ge 0 -and $iNo -lt $cut) { $cut = $iNo }
    if ($cut -le 0) { return "" }
    return $trigger.Substring(0, $cut)
}

function Add-Keywords([string]$load) {
    $kws = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($load)) { return $kws }
    foreach ($m in [regex]::Matches($load, $quoteRe)) {
        $inner = $m.Groups[1].Value.Trim()
        if ($inner.Length -ge 2 -and $inner.IndexOf("/") -lt 0) { $kws.Add($inner) }
    }
    $cleaned = $load -replace "\*\*", "" -replace $quoteRe, " "
    $parts = $cleaned -split "[/|+\uFF1B;\u3001\uFF0C,]"
    foreach ($p in $parts) {
        $t = $p.Trim()
        $t = $t.Trim("(", ")", ([char]0xFF08), ([char]0xFF09), " ")
        if ($t.Length -lt 2) { continue }
        if ($t -match "^\d+$") { continue }
        if ($t.IndexOf($tAnd) -ge 0) { continue }
        foreach ($q in ($t -split [string]$tOr)) {
            $u = $q.Trim()
            $u = $u.Trim("*", " ", "(", ")")
            if ($u.Length -ge 2 -and $u -notmatch "^\d+$") { $kws.Add($u) }
        }
    }
    return $kws
}

foreach ($line in ($routingTxt -split "`r?`n")) {
    if ($line -notmatch "^\|") { continue }
    $md = [regex]::Match($line, ([regex]::Escape([string]$tick) + "([A-Za-z0-9._-]+\.md)" + [regex]::Escape([string]$tick)))
    if (-not $md.Success) { continue }
    $file = $md.Groups[1].Value
    [void]$ownerSet.Add($file)
    $cells = @($line.Trim().Trim("|").Split("|"))
    if ($cells.Count -lt 1) { continue }
    $trigger = $cells[0].Trim()
    $load = Get-LoadPart $trigger
    $kws = Add-Keywords $load
    if (-not $fileKw.ContainsKey($file)) { $fileKw[$file] = New-Object System.Collections.Generic.List[string] }
    foreach ($k in $kws) {
        if (-not $fileKw[$file].Contains($k)) { $fileKw[$file].Add($k) }
    }
}

function Get-Score([string]$utterance, [string]$file) {
    if (-not $fileKw.ContainsKey($file)) { return 0 }
    $score = 0
    foreach ($k in $fileKw[$file]) {
        if ($utterance.IndexOf($k) -ge 0) { $score++ }
    }
    return $score
}

function Get-Ranked([string]$utterance) {
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($f in $fileKw.Keys) {
        $s = Get-Score $utterance $f
        $rows.Add([pscustomobject]@{ file = $f; score = $s })
    }
    return @($rows | Sort-Object @{ Expression = { $_.score }; Descending = $true }, @{ Expression = { $_.file } })
}

function Get-UniqueFirst($ranked) {
    if ($null -eq $ranked -or $ranked.Count -eq 0) { return $null }
    $top = $ranked[0]
    if ($top.score -le 0) { return $null }
    if ($ranked.Count -gt 1 -and $ranked[1].score -eq $top.score) { return $null }
    return $top.file
}

function Test-RanksFront($ranked, [string]$expect) {
    if ($null -eq $ranked -or $ranked.Count -eq 0) { return $false }
    $max = [int]$ranked[0].score
    if ($max -le 0) { return $false }
    foreach ($r in $ranked) {
        if ([int]$r.score -lt $max) { break }
        if ([string]$r.file -eq $expect) { return $true }
    }
    return $false
}

$fail = 0
$pass = 0
$pos = 0
$neg = 0
$ownersBad = @()

Write-Host ("cases=" + $CasesPath)
Write-Host ("routing=" + $RoutingPath)
Write-Host ("table-files=" + $ownerSet.Count)

foreach ($c in $cases) {
    $id = [string]$c.id
    $kind = [string]$c.kind
    $utt = [string]$c.utterance
    $ranked = Get-Ranked $utt
    $first = Get-UniqueFirst $ranked
    $top3 = @($ranked | Select-Object -First 3 | ForEach-Object { $_.file + "=" + $_.score })
    if ($kind -eq "positive") {
        $script:pos++
        $expect = [string]$c.expect
        if (-not $ownerSet.Contains($expect)) { $ownersBad += ($id + ":" + $expect) }
        $ok = Test-RanksFront $ranked $expect
        $detail = "first=" + $first + " expect=" + $expect + " top=" + ($top3 -join ",")
        if ($ok) { $script:pass++; Write-Host ("[PASS] " + $id + " " + $detail) }
        else { $script:fail++; Write-Host ("[FAIL] " + $id + " " + $detail) }
    } elseif ($kind -eq "negative") {
        $script:neg++
        $forbid = [string]$c.forbid
        if (-not $ownerSet.Contains($forbid)) { $ownersBad += ($id + ":" + $forbid) }
        $ok = ($first -ne $forbid)
        $detail = "first=" + $first + " forbid=" + $forbid + " top=" + ($top3 -join ",")
        if ($ok) { $script:pass++; Write-Host ("[PASS] " + $id + " " + $detail) }
        else { $script:fail++; Write-Host ("[FAIL] " + $id + " " + $detail) }
    } else {
        $script:fail++
        Write-Host ("[FAIL] " + $id + " unknown kind=" + $kind)
    }
}

if ($pos -lt 5) { $fail++; Write-Host ("[FAIL] A1-positive-ge5 pos=" + $pos) }
else { $pass++; Write-Host ("[PASS] A1-positive-ge5 pos=" + $pos) }
if ($neg -lt 5) { $fail++; Write-Host ("[FAIL] A1-negative-ge5 neg=" + $neg) }
else { $pass++; Write-Host ("[PASS] A1-negative-ge5 neg=" + $neg) }
if ($ownersBad.Count -gt 0) { $fail++; Write-Host ("[FAIL] A3-owners-in-table " + ($ownersBad -join ",")) }
else { $pass++; Write-Host "[PASS] A3-owners-in-table" }

Write-Host ("pass=" + $pass + " fail=" + $fail)
if ($fail -gt 0) { exit 1 }
exit 0
