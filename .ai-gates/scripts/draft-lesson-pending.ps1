# draft-lesson-pending.ps1 — fail output -> 证据/_lesson-pending.md yaml.
# ASCII-only source (Windows PS 5 parser). Output is yaml.
# Lesson 2026-08-12: do not require rg of this script's own filename.
# Default does not pass the Apply switch to the commit script (A2).
param(
    [string]$FailPath = "",
    [string]$FailText = "",
    [string]$OutPath = "",
    [switch]$SkipCommitCheck
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true
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

function Write-Utf8Bom([string]$path, [string]$text) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($path, $text, $utf8Bom)
}

function Get-RepoRel([string]$abs, [string]$repo) {
    $full = [System.IO.Path]::GetFullPath($abs)
    $root = [System.IO.Path]::GetFullPath($repo)
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($root.Length).TrimStart("\", "/")
        return ($rel -replace "\\", "/")
    }
    return ($full -replace "\\", "/")
}

function Quote-Yaml([string]$s) {
    $t = [string]$s
    $t = $t.Replace("\", "\\").Replace('"', '\"')
    return '"' + $t + '"'
}

function Get-FailBlob {
    if (-not [string]::IsNullOrWhiteSpace($FailText)) { return $FailText }
    if (-not [string]::IsNullOrWhiteSpace($FailPath)) { return (Read-Utf8 $FailPath) }
    throw "need -FailPath or -FailText"
}

function Get-FailToken([string]$blob, [ref]$detailRef) {
    $rx = [regex]'\[FAIL\]\s+(\S+)\s*::(.*)'
    $m = $rx.Match($blob)
    if (-not $m.Success) { throw "no [FAIL] token :: line in fail input" }
    $detailRef.Value = $m.Groups[2].Value.Trim()
    return $m.Groups[1].Value.Trim()
}

$repo = Resolve-RepoRoot
$blob = Get-FailBlob
$detail = ""
$token = Get-FailToken $blob ([ref]$detail)
if ([string]::IsNullOrWhiteSpace($token)) { throw "empty token after [FAIL]" }

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    if (-not [string]::IsNullOrWhiteSpace($FailPath)) {
        $failAbs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FailPath)
        $failDir = Split-Path -Parent $failAbs
        $leaf = Split-Path -Leaf $failDir
        if ($leaf -eq "test-first") {
            $OutPath = Join-Path (Split-Path -Parent $failDir) "_lesson-pending.md"
        }
    }
}
if ([string]::IsNullOrWhiteSpace($OutPath)) { throw "need -OutPath (default is window evidence _lesson-pending.md)" }
$OutPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)

$date = Get-Date -Format "yyyy-MM-dd"
$flow = U @(0x6D41, 0x7A0B)
$srcType = "Skill" + $flow
$docRel = Get-RepoRel $OutPath $repo
if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "fail token " + $token }

$lesson = "Fail output token " + $token + ": " + $detail
if ($lesson.Length -lt 8) { $lesson = $lesson + " (drafted from fail line)" }
$cause = "Assert failed at token " + $token + ": " + $detail
$fix = "Fix the failing check " + $token + " then re-run; keep cause and fix non-empty"
if ($cause.Trim().Length -lt 4) { $cause = $cause + " cause" }
if ($fix.Trim().Length -lt 4) { $fix = $fix + " fix" }

$yaml = @(
    "status: pending",
    "date: $date",
    "module: Skill",
    "lesson: $(Quote-Yaml $lesson)",
    "source: $srcType",
    "doc: $(Quote-Yaml $docRel)",
    "type: $srcType",
    "keywords: $(Quote-Yaml $token)",
    "cause: $(Quote-Yaml $cause)",
    "fix: $(Quote-Yaml $fix)"
) -join "`n"

$tick = [char]96
$fence = ([string]$tick) + ([string]$tick) + ([string]$tick)
$body = $fence + "yaml`n" + $yaml + "`n" + $fence + "`n"
Write-Utf8Bom $OutPath $body
Write-Host ("drafted " + $OutPath)
Write-Host ("token=" + $token)

if ($SkipCommitCheck) {
    exit 0
}

$commitName = "commit-lesson-pending" + ".ps1"
$commitFile = Join-Path $repo (Join-Path ".ai-gates\scripts" $commitName)
if (-not (Test-Path -LiteralPath $commitFile)) { throw "missing commit script: " + $commitFile }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell"
# dry-run only: do not pass the Apply switch (A2)
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$commitFile`" -PendingPath `"$OutPath`""
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$p = [System.Diagnostics.Process]::Start($psi)
$cout = $p.StandardOutput.ReadToEnd()
$cerr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
if ($cout) { Write-Host $cout.TrimEnd() }
if ($p.ExitCode -ne 0) {
    if ($cerr) { Write-Host $cerr.TrimEnd() }
    throw "commit dry-run exit=" + $p.ExitCode
}
exit 0
