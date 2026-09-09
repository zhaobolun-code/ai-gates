# summarize-session-trace.ps1 — write/session counts from write-audit.log + pm-gate.json.
# Reuses session-dash tail idea (last bytes). Does NOT use Score-DecodedLine as session score.
# Default: do not write session_score. Does not write lessons main table.
param(
    [string]$LogDir = "",
    [string]$OutPath = "",
    [switch]$IncludeSessionScore
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[Console]::OutputEncoding = $utf8

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

function Get-OutDir([string]$repo) {
    if (-not [string]::IsNullOrWhiteSpace($env:AI_GATES_WINDOW)) {
        $w = $env:AI_GATES_WINDOW
        $ev = Join-Path $w "证据"
        if (-not (Test-Path -LiteralPath $ev)) { New-Item -ItemType Directory -Path $ev -Force | Out-Null }
        return $ev
    }
    $exec = Join-Path $repo ".ai-gates\Doc\AI流水线\执行中"
    $wips = @()
    if (Test-Path -LiteralPath $exec) {
        $wips = @(Get-ChildItem -LiteralPath $exec -Recurse -Filter "未完成.md" -ErrorAction SilentlyContinue)
    }
    if ($wips.Count -eq 1) {
        $ev = Join-Path (Split-Path -Parent $wips[0].FullName) "证据"
        if (-not (Test-Path -LiteralPath $ev)) { New-Item -ItemType Directory -Path $ev -Force | Out-Null }
        return $ev
    }
    $tmp = Join-Path $repo ".ai-gates\tmp\session-scan"
    if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }
    return $tmp
}

function Read-TailRaw([string]$path, [int]$maxBytes) {
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ ok = $false; text = ""; fileBytes = 0 }
    }
    $fi = Get-Item -LiteralPath $path
    $fileBytes = [int64]$fi.Length
    $take = [int64]$maxBytes
    if ($fileBytes -lt $take) { $take = $fileBytes }
    if ($take -le 0) { return @{ ok = $true; text = ""; fileBytes = $fileBytes } }
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        [void]$fs.Seek(-$take, [System.IO.SeekOrigin]::End)
        $buf = New-Object byte[] $take
        $read = $fs.Read($buf, 0, [int]$take)
        $text = $utf8.GetString($buf, 0, $read)
        return @{ ok = $true; text = $text; fileBytes = $fileBytes }
    } finally { $fs.Close() }
}

$repo = Resolve-RepoRoot
if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $repo ".ai-gates\hooks-log"
}
$LogDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogDir)

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path (Get-OutDir $repo) "session-trace.md"
}
$OutPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)
$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$audit = Read-TailRaw (Join-Path $LogDir "write-audit.log") 262144
$writeCount = 0
if ($audit.ok -and -not [string]::IsNullOrWhiteSpace($audit.text)) {
    $writeCount = @($audit.text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

$sessionCount = 0
$pmPath = Join-Path $LogDir "pm-gate.json"
if (Test-Path -LiteralPath $pmPath) {
    try {
        $pm = Get-Content -LiteralPath $pmPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sessionCount = @($pm.PSObject.Properties).Count
    } catch {
        $sessionCount = 0
    }
}

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# session-trace")
[void]$lines.Add("")
[void]$lines.Add(("generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")))
[void]$lines.Add(("write_audit_file_bytes: " + $audit.fileBytes))
[void]$lines.Add(("write_count: " + $writeCount))
[void]$lines.Add(("session_keys: " + $sessionCount))
[void]$lines.Add("source: write-audit.log / pm-gate.json")
[void]$lines.Add("note: this summary is not lessons main table")
if ($IncludeSessionScore) {
    [void]$lines.Add("session_score: omitted-by-default")
    [void]$lines.Add("disclaimer: session_score 不得替代 A# / Unity 人测")
}
$body = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($OutPath, $body, $utf8Bom)
Write-Host ("wrote " + $OutPath + " write_count=" + $writeCount + " session_keys=" + $sessionCount)
exit 0
