# assert-publish-reject-p1p2.ps1 — P1 placeholder + P2 schema/header/idempotent.
# ASCII-only source (Windows PS5). Does not -Apply the real lessons main table.
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[Console]::OutputEncoding = $utf8

function U([int[]]$codes) {
    return (-join ($codes | ForEach-Object { [char]$_ }))
}

function Resolve-RepoRoot {
    $p = $PSScriptRoot
    for ($i = 0; $i -lt 16; $i++) {
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

function Write-Utf8Bom([string]$path, [string]$text) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($path, $text, $utf8Bom)
}

function Invoke-Ps1([string]$file, [string[]]$argList) {
    $all = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $file) + $argList
    $p = Start-Process -FilePath "powershell" -ArgumentList $all -Wait -PassThru -NoNewWindow
    return [int]$p.ExitCode
}

function Invoke-Ps1Capture([string]$file, [string[]]$argList) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $quoted = @()
    foreach ($a in (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $file) + $argList)) {
        $quoted += ('"' + ($a -replace '"', '\"') + '"')
    }
    $psi.Arguments = ($quoted -join " ")
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $rp = [System.Diagnostics.Process]::Start($psi)
    $out = $rp.StandardOutput.ReadToEnd()
    $err = $rp.StandardError.ReadToEnd()
    $rp.WaitForExit()
    return @{ ExitCode = [int]$rp.ExitCode; Out = $out; Err = $err }
}

function Count-LessonRows([string]$path) {
    $n = 0
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    foreach ($line in [System.IO.File]::ReadAllLines($path, $utf8)) {
        if ($line -match '^\|\s*\d{4}-\d{2}-\d{2}\s*\|') { $n++ }
    }
    return $n
}

function New-TempLessons([string]$path) {
    $hdr = @(
        "| date | module | lesson | source | doc | hit | type | keywords | cause | fix | prevent | scope | promo |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    ) -join "`r`n"
    Write-Utf8Bom $path ($hdr + "`r`n")
}

$failed = 0
$repo = Resolve-RepoRoot
$fx = Join-Path $PSScriptRoot "fixtures\publish-reject"
$flow = "AI" + (U @(0x6D41, 0x6C34, 0x7EBF))
$qianshou = U @(0x7B7E, 0x6536)
$zhengju = U @(0x8BC1, 0x636E)
$oldSrc = Join-Path $repo (Join-Path ".ai-gates\Doc" (Join-Path $flow (Join-Path $qianshou (Join-Path "evolution-08-ge7-borrow" (Join-Path $zhengju "test-first")))))
$reject = Join-Path $repo ".ai-gates\scripts\test-publish-reject.ps1"
$commit = Join-Path $repo ".ai-gates\scripts\commit-lesson-pending.ps1"
$draft = Join-Path $repo ".ai-gates\scripts\draft-lesson-pending.ps1"
$tmp = Join-Path $repo ".ai-gates\tmp\publish-reject-p1p2"
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$tmpLessons = Join-Path $tmp "lessons-temp.md"
New-TempLessons $tmpLessons
$old = Join-Path $tmp "old-fx"
New-Item -ItemType Directory -Path $old -Force | Out-Null
$oldNames = @(
    "fx-pattern-create-ok.md",
    "fx-lesson-empty.md",
    "fx-lesson-no-cause.md",
    "fx-pattern-create-no-anchor.md",
    "fx-queue-no-origin.md",
    "fx-queue-slogan.md",
    "fx-lesson-valid.md",
    "fx-queue-ok.md",
    "assert-step2.ps1"
)
$hasOld = Test-Path -LiteralPath $oldSrc
if (-not $hasOld) {
    # Doc/ is maintainer-local; the install package has no Doc/. Skip the legacy fixture comparison instead of counting it as a failure.
    Write-Host ("SKIP old fixtures (maintainer Doc not installed): " + $oldSrc)
} else {
    foreach ($n in $oldNames) {
        $src = Join-Path $oldSrc $n
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Host ("FAIL missing old fixture " + $n)
            $failed++
        } else {
            Copy-Item -LiteralPath $src -Destination (Join-Path $old $n) -Force
        }
    }
}

function Expect-Exit([string]$label, [int]$code, [int]$want) {
    if ($code -ne $want) {
        Write-Host ("FAIL " + $label + " want " + $want + " got " + $code)
        $script:failed++
    } else {
        Write-Host ("OK " + $label + " exit=" + $code)
    }
}
function Expect-NonZero([string]$label, [int]$code) {
    if ($code -eq 0) {
        Write-Host ("FAIL " + $label + " want non-0 got 0")
        $script:failed++
    } else {
        Write-Host ("OK " + $label + " exit=" + $code)
    }
}
function Expect-Zero([string]$label, [int]$code) {
    Expect-Exit $label $code 0
}

# source: no affirmative call line with both commit script name and -Apply
$draftSrc = Read-Utf8 $draft
$commitNeedle = "commit-lesson-pending" + ".ps1"
$badLine = $false
foreach ($ln in ($draftSrc -split "`r?`n")) {
    if ($ln -match '^\s*#' ) { continue }
    if (($ln.IndexOf($commitNeedle) -ge 0) -and ($ln.IndexOf("-Apply") -ge 0)) { $badLine = $true }
}
if ($badLine) {
    Write-Host "FAIL draft has commit-lesson-pending.ps1 and -Apply on one call line"
    $failed++
} else {
    Write-Host "OK draft has no Apply on commit call line"
}

# 1 cause placeholder -> gate 2; commit dry-run non-0; temp table unchanged
$p1a = Join-Path $fx "fx-lesson-cause-placeholder.md"
Expect-Exit "p1 cause placeholder gate" (Invoke-Ps1 $reject @("-PendingPath", $p1a)) 2
$before = Count-LessonRows $tmpLessons
Expect-NonZero "p1 cause placeholder commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $p1a, "-LessonsPath", $tmpLessons))
$after = Count-LessonRows $tmpLessons
if ($before -ne $after) {
    Write-Host ("FAIL p1 cause placeholder lessons grew " + $before + " -> " + $after)
    $failed++
} else {
    Write-Host ("OK p1 cause placeholder lessons rows " + $after)
}

# 2 fix template
$p1b = Join-Path $fx "fx-lesson-fix-template.md"
Expect-Exit "p1 fix template gate" (Invoke-Ps1 $reject @("-PendingPath", $p1b)) 2
Expect-NonZero "p1 fix template commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $p1b, "-LessonsPath", $tmpLessons))

# 3 template-only
$p1c = Join-Path $fx "fx-lesson-template-only.md"
Expect-Exit "p1 template-only gate" (Invoke-Ps1 $reject @("-PendingPath", $p1c)) 2
Expect-NonZero "p1 template-only commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $p1c, "-LessonsPath", $tmpLessons))

# 4 valid mechanism
$p1d = Join-Path $fx "fx-lesson-valid-mechanism.md"
Expect-Exit "p1 valid gate" (Invoke-Ps1 $reject @("-PendingPath", $p1d)) 0
$before = Count-LessonRows $tmpLessons
Expect-Zero "p1 valid commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $p1d, "-LessonsPath", $tmpLessons))
$after = Count-LessonRows $tmpLessons
if ($before -ne $after) {
    Write-Host ("FAIL p1 valid dry-run lessons grew " + $before + " -> " + $after)
    $failed++
} else {
    Write-Host ("OK p1 valid dry-run lessons rows " + $after)
}

# hole: reverse missing signature must reject; empty origin still passes
$pHoleNoSig = Join-Path $fx "fx-lesson-reverse-no-signature.md"
Expect-Exit "hole reverse no signature gate" (Invoke-Ps1 $reject @("-PendingPath", $pHoleNoSig)) 2
$beforeHole = Count-LessonRows $tmpLessons
Expect-NonZero "hole reverse no signature commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $pHoleNoSig, "-LessonsPath", $tmpLessons))
$afterHoleReject = Count-LessonRows $tmpLessons
if ($beforeHole -ne $afterHoleReject) {
    Write-Host ("FAIL hole reverse no signature lessons grew " + $beforeHole + " -> " + $afterHoleReject)
    $failed++
} else {
    Write-Host ("OK hole reverse no signature lessons rows " + $afterHoleReject)
}
$pHoleEmpty = Join-Path $fx "fx-lesson-origin-empty.md"
Expect-Exit "hole origin empty gate" (Invoke-Ps1 $reject @("-PendingPath", $pHoleEmpty)) 0
Expect-Zero "hole origin empty commit dry-run" (Invoke-Ps1 $commit @("-PendingPath", $pHoleEmpty, "-LessonsPath", $tmpLessons))
$afterHoleEmpty = Count-LessonRows $tmpLessons
if ($beforeHole -ne $afterHoleEmpty) {
    Write-Host ("FAIL hole origin empty dry-run lessons grew " + $beforeHole + " -> " + $afterHoleEmpty)
    $failed++
} else {
    Write-Host ("OK hole origin empty dry-run lessons rows " + $afterHoleEmpty)
}

# 5 action delete missing fields
$p2del = Join-Path $fx "fx-pattern-action-delete.md"
Expect-Exit "p2 action delete gate" (Invoke-Ps1 $reject @("-PendingPath", $p2del)) 2

# 6 existing create-ok (only when the maintainer Doc fixtures exist)
if ($hasOld) {
    $oldCreate = Join-Path $old "fx-pattern-create-ok.md"
    Expect-Exit "p2 existing create-ok" (Invoke-Ps1 $reject @("-PendingPath", $oldCreate)) 0
}

# improve with real table cell. The install package ships an empty pattern table;
# skip when the fixture name is absent from both tables instead of failing.
$p2imp = Join-Path $fx "fx-pattern-improve-ok.md"
$impName = ""
$impMatch = [regex]::Match((Read-Utf8 $p2imp), '(?m)^\s*name\s*:\s*"?([^"\r\n]+)"?\s*$')
if ($impMatch.Success) { $impName = $impMatch.Groups[1].Value.Trim() }
$impTableHit = $false
foreach ($tbl in @((Join-Path $repo ".ai-gates\skills\references\design-patterns.md"), (Join-Path $repo ".ai-gates\design-patterns.project.md"))) {
    if ((Test-Path -LiteralPath $tbl) -and $impName -and ((Read-Utf8 $tbl).IndexOf($impName) -ge 0)) { $impTableHit = $true }
}
if ($impTableHit) {
    Expect-Exit "p2 improve real name" (Invoke-Ps1 $reject @("-PendingPath", $p2imp)) 0
} else {
    Write-Host "SKIP p2 improve real name (no matching pattern-table cell)"
}

# 7 queue header
$qNo = Join-Path $fx "fx-queue-no-header.md"
$qEmpty = Join-Path $fx "fx-queue-header-empty.md"
Expect-Exit "p2 queue no header" (Invoke-Ps1 $reject @("-QueuePath", $qNo)) 2
Expect-Exit "p2 queue header empty" (Invoke-Ps1 $reject @("-QueuePath", $qEmpty)) 0

# 8 idempotent Apply on temp table
$applyPending = Join-Path $tmp "_lesson-pending-apply.md"
$applyLessons = Join-Path $tmp "lessons-apply.md"
Copy-Item -LiteralPath $p1d -Destination $applyPending -Force
New-TempLessons $applyLessons
$r1 = Invoke-Ps1Capture $commit @("-PendingPath", $applyPending, "-LessonsPath", $applyLessons, "-Apply")
Expect-Zero "p2 idempotent first Apply" $r1.ExitCode
$n1 = Count-LessonRows $applyLessons
if ($n1 -ne 1) {
    Write-Host ("FAIL p2 idempotent first Apply rows=" + $n1)
    $failed++
} else {
    Write-Host "OK p2 idempotent first Apply rows=1"
}
$pendText = Read-Utf8 $applyPending
$pendText = [regex]::Replace($pendText, '(?m)^(\s*status\s*:\s*)committed\b', '${1}pending', 1)
Write-Utf8Bom $applyPending $pendText
$r2 = Invoke-Ps1Capture $commit @("-PendingPath", $applyPending, "-LessonsPath", $applyLessons, "-Apply")
Expect-Zero "p2 idempotent second Apply" $r2.ExitCode
$n2 = Count-LessonRows $applyLessons
if ($n2 -ne 1) {
    Write-Host ("FAIL p2 idempotent second Apply rows=" + $n2)
    $failed++
} else {
    Write-Host "OK p2 idempotent second Apply rows=1"
}
$existWord = U @(0x5DF2, 0x5B58, 0x5728)
$blob2 = [string]$r2.Out + [string]$r2.Err
if ($blob2.IndexOf($existWord) -lt 0) {
    Write-Host "FAIL p2 idempotent second Apply missing already-exists mark"
    $failed++
} else {
    Write-Host "OK p2 idempotent printed already-exists mark"
}
$pendAfter = Read-Utf8 $applyPending
if ($pendAfter -notmatch '(?m)^\s*status\s*:\s*committed\b') {
    Write-Host "FAIL p2 idempotent pending status not committed"
    $failed++
} else {
    Write-Host "OK p2 idempotent pending status committed"
}

# 9 old fixtures (same expect as assert-step2.ps1)
$step2Code = -1
if ($hasOld) {
    Expect-NonZero "old empty-talk lesson" (Invoke-Ps1 $reject @("-PendingPath", (Join-Path $old "fx-lesson-empty.md")))
    Expect-NonZero "old missing cause" (Invoke-Ps1 $reject @("-PendingPath", (Join-Path $old "fx-lesson-no-cause.md")))
    Expect-NonZero "old create no anchor" (Invoke-Ps1 $reject @("-PendingPath", (Join-Path $old "fx-pattern-create-no-anchor.md")))
    Expect-NonZero "old shareable missing origin" (Invoke-Ps1 $reject @("-QueuePath", (Join-Path $old "fx-queue-no-origin.md")))
    Expect-NonZero "old shareable slogan notes" (Invoke-Ps1 $reject @("-QueuePath", (Join-Path $old "fx-queue-slogan.md")))
    Expect-Zero "old valid lesson" (Invoke-Ps1 $reject @("-PendingPath", (Join-Path $old "fx-lesson-valid.md")))
    Expect-Zero "old valid pattern create" (Invoke-Ps1 $reject @("-PendingPath", (Join-Path $old "fx-pattern-create-ok.md")))
    Expect-Zero "old valid shareable" (Invoke-Ps1 $reject @("-QueuePath", (Join-Path $old "fx-queue-ok.md")))

    $step2 = Join-Path $old "assert-step2.ps1"
    if (Test-Path -LiteralPath $step2) {
        $step2Code = Invoke-Ps1 $step2 @()
        Write-Host ("assert-step2 exit=" + $step2Code)
        if ($step2Code -ne 0) {
            Write-Host "FAIL assert-step2 non-zero"
            $failed++
        } else {
            Write-Host "OK assert-step2 exit=0"
        }
    } else {
        Write-Host "FAIL missing assert-step2.ps1"
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host ("assert-publish-reject-p1p2 FAILED count=" + $failed)
    exit 1
}
Write-Host "assert-publish-reject-p1p2 OK"
if ($hasOld) { Write-Host ("assert-step2 exit=" + $step2Code) }
exit 0
