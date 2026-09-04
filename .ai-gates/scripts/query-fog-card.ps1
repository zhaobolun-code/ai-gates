# query-fog-card.ps1 — print one fog-map node card by short id.
# ASCII-only source (Windows PS 5 parser).
# Lesson 2026-08-12: do not require rg of this script's own filename.
param(
    [string]$Id = "",
    [string]$JsonPath = "",
    [string]$DocRoot = "",
    [switch]$SelfCheck
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

function Resolve-JsonPath([string]$repo, [string]$jsonPath, [string]$docRoot) {
    if (-not [string]::IsNullOrWhiteSpace($jsonPath)) {
        return $jsonPath
    }
    if (-not [string]::IsNullOrWhiteSpace($docRoot)) {
        return (Join-Path $docRoot "fog-map.json")
    }
    return (Join-Path $repo ".ai-gates\verify\fog-map.json")
}

function Emit-Card([string]$path, [string]$id) {
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Id is required"
    }
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Output "MISSING"
        exit 1
    }
    $raw = [System.IO.File]::ReadAllText($path, $utf8)
    $j = $raw | ConvertFrom-Json
    $node = $null
    foreach ($n in @($j.nodes)) {
        if ($n.id -eq $id) { $node = $n; break }
    }
    if ($null -eq $node) {
        Write-Output "MISSING"
        exit 1
    }
    $card = [ordered]@{
        id        = $node.id
        state     = $node.state
        neighbors = $node.neighbors
        rec       = $node.rec
        generated = $j.generated
        jsonPath  = $path
    }
    ($card | ConvertTo-Json -Depth 8 -Compress)
    exit 0
}

function Invoke-SelfCheck([string]$repo) {
    $structRel = ".ai-gates\skills\references\fog-map-structure.md"
    $structPath = Join-Path $repo $structRel
    if (-not (Test-Path -LiteralPath $structPath)) {
        Write-Output "SELFCHECK_FAIL missing structure page"
        exit 1
    }
    $txt = [System.IO.File]::ReadAllText($structPath, $utf8)
    $scriptRelFwd = ".ai-gates/scripts/query-fog-card.ps1"
    $scriptRelBack = ".ai-gates\scripts\query-fog-card.ps1"
    if (($txt.IndexOf($scriptRelFwd) -lt 0) -and ($txt.IndexOf($scriptRelBack) -lt 0)) {
        Write-Output "SELFCHECK_FAIL structure page must name query script path"
        exit 1
    }
    # Ban sentence: forbid using Read to open whole fog-map.json (A2).
    $ban = U @(0x7981, 0x6B62)
    $use = U @(0x7528)
    $banUseRead = $ban + $use + " Read"
    $banSpaceRead = $ban + " Read"
    $fogJson = "fog-map.json"
    $hasBanRead = ($txt.IndexOf($banUseRead) -ge 0) -or ($txt.IndexOf($banSpaceRead) -ge 0)
    if ((-not $hasBanRead) -or ($txt.IndexOf($fogJson) -lt 0)) {
        Write-Output "SELFCHECK_FAIL structure page must ban Read of whole fog-map.json"
        exit 1
    }

    $themeDir = Join-Path $repo (Join-Path ".ai-gates\Doc" ("AI" + (U @(0x6D41, 0x6C34, 0x7EBF))))
    $probeId = U @(0x89C4, 0x5219, 0x7FFB, 0x9519, 0x672C, 0x8BC4, 0x6D4B)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -DocRoot `"$themeDir`" -Id `"$probeId`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        Write-Output ("SELFCHECK_FAIL probe exit=" + $p.ExitCode)
        if ($out) { Write-Output $out }
        if ($err) { Write-Output $err }
        exit 1
    }
    if ($out.IndexOf("neighbors") -lt 0) {
        Write-Output "SELFCHECK_FAIL probe output missing neighbors"
        Write-Output $out
        exit 1
    }
    Write-Output "SELFCHECK_OK"
    exit 0
}

$repo = Resolve-RepoRoot
if ($SelfCheck) {
    Invoke-SelfCheck $repo
}

$resolved = Resolve-JsonPath $repo $JsonPath $DocRoot
Emit-Card $resolved $Id
