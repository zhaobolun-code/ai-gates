# test-publish-reject.ps1 — publish gate (lesson / pattern / shareable).
# 拒收清单（须可 rg）：无证据；空话；删具体事实；origin；anchor；无特别经验；本次无
# Default: exit 0 pass, exit 2 reject. Does not write lessons main table. No -Apply.
param(
    [string]$PendingPath = "",
    [string]$QueuePath = "",
    [string]$QueueId = ""
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

function Read-Utf8([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing: " + $path }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Get-YamlBlock([string]$text) {
    if ($text -match '(?s)```yaml\s*(.*?)\s*```') {
        return $Matches[1]
    }
    throw "pending file missing yaml fenced block"
}

function Get-YamlMap([string]$yaml) {
    $map = @{}
    foreach ($line in ($yaml -split "`r?`n")) {
        if ($line -match '^\s*#' -or $line.Trim() -eq "") { continue }
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim()
            $quoted = $false
            if ($v -match '^"(.*)"$') { $v = $Matches[1]; $quoted = $true }
            elseif ($v -match "^'(.*)'$") { $v = $Matches[1]; $quoted = $true }
            if (-not $quoted -and $v -match '^([^#]+)') { $v = $Matches[1].Trim() }
            $map[$k] = $v
        }
    }
    return $map
}

function Fail-Reject([string]$reason) {
    Write-Host ("REJECT " + $reason)
    exit 2
}

function Test-EmptyTalk([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $true }
    $t = $s.Trim()
    if ($t.Length -lt 8) { return $true }
    if ($t -match "无特别经验|本次无") { return $true }
    return $false
}

function Test-MechanismNotes([string]$notes) {
    if ([string]::IsNullOrWhiteSpace($notes)) { return $false }
    $t = $notes.Trim()
    if ($t.Length -lt 20) { return $false }
    if ($t -match "禁止|须|不得|不是|机制|去上下文化|过闸|改正|错因|≠") { return $true }
    return $false
}

function Test-LessonMap($map) {
    $lesson = ""
    if ($map.ContainsKey("lesson")) { $lesson = [string]$map["lesson"] }
    $cause = ""
    if ($map.ContainsKey("cause")) { $cause = [string]$map["cause"] }
    $fix = ""
    if ($map.ContainsKey("fix")) { $fix = [string]$map["fix"] }
    if (Test-EmptyTalk $lesson) {
        Fail-Reject "空话 lesson 无特别经验/本次无 or length"
    }
    if ([string]::IsNullOrWhiteSpace($cause) -or [string]::IsNullOrWhiteSpace($fix)) {
        Fail-Reject "无证据 cause/fix"
    }
    if ($cause.Trim().Length -lt 4 -or $fix.Trim().Length -lt 4) {
        Fail-Reject "无证据 cause/fix too short"
    }
}

function Test-PatternMap($map) {
    $name = ""
    if ($map.ContainsKey("name")) { $name = [string]$map["name"] }
    if (Test-EmptyTalk $name) {
        Fail-Reject "空话 name/title"
    }
    $action = ""
    if ($map.ContainsKey("action")) { $action = ([string]$map["action"]).Trim().ToLowerInvariant() }
    if ([string]::IsNullOrWhiteSpace($action)) {
        Fail-Reject "无证据 missing action"
    }
    $anchor = ""
    if ($map.ContainsKey("anchor")) { $anchor = [string]$map["anchor"] }
    if ($action -eq "create" -and [string]::IsNullOrWhiteSpace($anchor)) {
        Fail-Reject "无证据 create missing anchor"
    }
}

function Get-Cells([string]$line) {
    $parts = $line -split '\|'
    $cells = @()
    if ($parts.Count -lt 3) { return $cells }
    for ($k = 1; $k -lt $parts.Count - 1; $k++) {
        $cells += $parts[$k].Trim()
    }
    return $cells
}

function Test-Queue([string]$text, [string]$wantId) {
    $lines = $text -split "`r?`n"
    $idxState = -1
    $idxOrigin = -1
    $idxNotes = -1
    $idxId = -1
    $idxTitle = -1
    $headerSeen = $false
    $checked = 0
    foreach ($line in $lines) {
        if ($line -notmatch '^\|') { continue }
        $cells = @(Get-Cells $line)
        if ($cells.Count -eq 0) { continue }
        $joined = ($cells -join " ").ToLowerInvariant()
        if (-not $headerSeen -and ($joined -match 'origin') -and ($joined -match 'notes')) {
            for ($i = 0; $i -lt $cells.Count; $i++) {
                $h = $cells[$i].ToLowerInvariant()
                if ($h -eq "state") { $idxState = $i }
                if ($h -eq "origin") { $idxOrigin = $i }
                if ($h -eq "notes") { $idxNotes = $i }
                if ($h -eq "id") { $idxId = $i }
                if ($h -eq "title") { $idxTitle = $i }
            }
            $headerSeen = $true
            continue
        }
        if (-not $headerSeen) { continue }
        if ($cells[0] -match '^-+$') { continue }
        $id = ""
        if ($idxId -ge 0 -and $idxId -lt $cells.Count) { $id = $cells[$idxId] }
        $state = ""
        if ($idxState -ge 0 -and $idxState -lt $cells.Count) { $state = $cells[$idxState].ToLowerInvariant() }
        if (-not [string]::IsNullOrWhiteSpace($wantId)) {
            if ($id -ne $wantId) { continue }
        } else {
            if ($state -ne "shareable") { continue }
        }
        $checked++
        $title = ""
        if ($idxTitle -ge 0 -and $idxTitle -lt $cells.Count) { $title = $cells[$idxTitle] }
        $origin = ""
        if ($idxOrigin -ge 0 -and $idxOrigin -lt $cells.Count) { $origin = $cells[$idxOrigin] }
        $notes = ""
        if ($idxNotes -ge 0 -and $idxNotes -lt $cells.Count) { $notes = $cells[$idxNotes] }
        if (Test-EmptyTalk $title) {
            Fail-Reject "空话 shareable title"
        }
        if ([string]::IsNullOrWhiteSpace($origin) -or $origin.Trim().Length -lt 8) {
            Fail-Reject "无证据 shareable missing origin"
        }
        if (Test-EmptyTalk $origin) {
            Fail-Reject "空话 shareable origin"
        }
        if (-not (Test-MechanismNotes $notes)) {
            Fail-Reject "删具体事实 shareable notes"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($wantId) -and $checked -eq 0) {
        Fail-Reject "无证据 queue id not found"
    }
}

if (-not [string]::IsNullOrWhiteSpace($QueuePath)) {
    $qp = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($QueuePath)
    Test-Queue (Read-Utf8 $qp) $QueueId
    Write-Host "PASS queue"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($PendingPath)) {
    Write-Host "need -PendingPath or -QueuePath"
    exit 1
}

$pp = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PendingPath)
$text = Read-Utf8 $pp
$map = Get-YamlMap (Get-YamlBlock $text)
$isPattern = $false
if ($map.ContainsKey("action") -or $map.ContainsKey("destination") -or $map.ContainsKey("symptom") -or $map.ContainsKey("anchor")) {
    $isPattern = $true
}
$leaf = [IO.Path]::GetFileName($pp).ToLowerInvariant()
if ($leaf.IndexOf("pattern-pending") -ge 0) { $isPattern = $true }
if ($leaf.IndexOf("lesson-pending") -ge 0) { $isPattern = $false }

if ($isPattern) {
    Test-PatternMap $map
    Write-Host "PASS pattern"
    exit 0
}

Test-LessonMap $map
Write-Host "PASS lesson"
exit 0
