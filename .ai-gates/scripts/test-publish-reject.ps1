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

function Get-RepoRoot {
    $p = $PSScriptRoot
    if (-not $p) { $p = Split-Path -Parent $MyInvocation.MyCommand.Path }
    for ($i = 0; $i -lt 12; $i++) {
        $ver = Join-Path $p ".ai-gates\skills\VERSION"
        if (Test-Path -LiteralPath $ver) { return $p }
        $p = Split-Path -Parent $p
        if (-not $p) { break }
    }
    throw "cannot resolve repo root from " + $PSScriptRoot
}

function Test-PlaceholderCauseFix([string]$cause, [string]$fix) {
    # keep in sync with commit-lesson-pending.ps1 Test-PlaceholderCauseFix
    $needles = @(
        "原因待人写",
        "原因待确认",
        "Fix the failing check",
        "keep cause and fix non-empty"
    )
    foreach ($n in $needles) {
        if ($cause.IndexOf($n) -ge 0 -or $fix.IndexOf($n) -ge 0) {
            Fail-Reject ("无证据 cause/fix placeholder " + $n)
        }
    }
}

function Test-HoleLines($map) {
    # keep in sync with commit-lesson-pending.ps1 Test-HoleLines
    $origin = ""
    if ($map.ContainsKey("origin")) {
        $origin = ([string]$map["origin"]).Trim().Trim([char]34).Trim([char]39).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($origin)) { return }
    if (@("逆链", "思考碰撞") -notcontains $origin) { return }

    $sig = ""
    $trig = ""
    $nxt = ""
    if ($map.ContainsKey("hole_signature")) { $sig = ([string]$map["hole_signature"]).Trim().Trim([char]34).Trim([char]39).Trim() }
    if ($map.ContainsKey("hole_trigger")) { $trig = ([string]$map["hole_trigger"]).Trim().Trim([char]34).Trim([char]39).Trim() }
    if ($map.ContainsKey("hole_next")) { $nxt = ([string]$map["hole_next"]).Trim().Trim([char]34).Trim([char]39).Trim() }

    if ([string]::IsNullOrWhiteSpace($sig) -or [string]::IsNullOrWhiteSpace($trig) -or [string]::IsNullOrWhiteSpace($nxt)) {
        Fail-Reject ("无证据 origin=" + $origin + " missing hole_signature/hole_trigger/hole_next")
    }

    if ($sig -notmatch '^([^/|]{2,16})/(A#|Mandatory|机器现象|失败标准|冻结表|不选的)$') {
        Fail-Reject "无证据 hole_signature must match 洞种/锚类型"
    }
    $kind = $Matches[1]
    foreach ($w in @("类似", "大概", "可能", "应该")) {
        if ($kind.IndexOf($w) -ge 0) {
            Fail-Reject ("无证据 hole_signature forbidden word " + $w)
        }
    }
    $holeFields = @{ hole_trigger = $trig; hole_next = $nxt }
    foreach ($fname in @("hole_trigger", "hole_next")) {
        $val = [string]$holeFields[$fname]
        $compact = [regex]::Replace($val, '\s', '')
        if ($compact.Length -lt 4) {
            Fail-Reject ("无证据 " + $fname + " too short")
        }
        foreach ($p in @("后续处理", "待确认", "下次注意", "后续再看")) {
            if ($val.IndexOf($p) -ge 0) {
                Fail-Reject ("无证据 " + $fname + " placeholder " + $p)
            }
        }
    }
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
    Test-PlaceholderCauseFix $cause $fix
    Test-HoleLines $map
}

function Test-HasContent([string]$s) {
    return -not [string]::IsNullOrWhiteSpace($s)
}

function Test-NameAsTableCell([string]$name, [string]$filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $false }
    $want = $name.Trim()
    if ($want -eq "") { return $false }
    $text = Read-Utf8 $filePath
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -notmatch '^\|') { continue }
        $cells = @(Get-Cells $line)
        if ($cells.Count -eq 0) { continue }
        if ($cells[0] -match '^-+$') { continue }
        foreach ($c in $cells) {
            if ($c -eq $want) { return $true }
        }
    }
    return $false
}

function Test-CreateAnchorPath([string]$anchor) {
    $a = $anchor.Trim()
    $colon = $a.LastIndexOf([char]':')
    if ($colon -le 0 -or $colon -ge ($a.Length - 1)) {
        Fail-Reject "无证据 create anchor not path:symbol"
    }
    $rel = $a.Substring(0, $colon).Trim() -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($rel)) {
        Fail-Reject "无证据 create anchor not path:symbol"
    }
    $repo = Get-RepoRoot
    $p1 = Join-Path $repo $rel
    $p2 = Join-Path $repo (Join-Path ".ai-gates" $rel)
    if ((Test-Path -LiteralPath $p1) -or (Test-Path -LiteralPath $p2)) { return }
    Fail-Reject "无证据 create anchor path missing"
}

function Test-PatternMap($map) {
    $name = ""
    if ($map.ContainsKey("name")) { $name = [string]$map["name"] }
    if (Test-EmptyTalk $name) {
        Fail-Reject "空话 name/title"
    }
    $status = ""
    if ($map.ContainsKey("status")) { $status = ([string]$map["status"]).Trim().ToLowerInvariant() }
    $allowedStatus = @("pending", "committed", "rejected", "revise")
    if ($allowedStatus -notcontains $status) {
        Fail-Reject "无证据 bad status"
    }
    $action = ""
    if ($map.ContainsKey("action")) { $action = ([string]$map["action"]).Trim().ToLowerInvariant() }
    if ([string]::IsNullOrWhiteSpace($action)) {
        Fail-Reject "无证据 missing action"
    }
    $allowedAction = @("improve", "optimize_description", "create")
    if ($allowedAction -notcontains $action) {
        Fail-Reject "无证据 bad action"
    }
    $destination = ""
    if ($map.ContainsKey("destination")) { $destination = ([string]$map["destination"]).Trim().ToLowerInvariant() }
    $allowedDest = @("design-patterns", "maxim", "maxim-generic", "allusion")
    if ($allowedDest -notcontains $destination) {
        Fail-Reject "无证据 bad destination"
    }
    $symptom = ""
    if ($map.ContainsKey("symptom")) { $symptom = [string]$map["symptom"] }
    $pack = ""
    if ($map.ContainsKey("pack")) { $pack = [string]$map["pack"] }
    $verifyStatus = ""
    if ($map.ContainsKey("verify_status")) { $verifyStatus = [string]$map["verify_status"] }
    $forbid = ""
    if ($map.ContainsKey("forbid")) { $forbid = [string]$map["forbid"] }
    if (-not (Test-HasContent $symptom)) { Fail-Reject "无证据 missing symptom" }
    if (-not (Test-HasContent $pack)) { Fail-Reject "无证据 missing pack" }
    if (-not (Test-HasContent $verifyStatus)) { Fail-Reject "无证据 missing verify_status" }
    if (-not (Test-HasContent $forbid)) { Fail-Reject "无证据 missing forbid" }
    $anchor = ""
    if ($map.ContainsKey("anchor")) { $anchor = [string]$map["anchor"] }
    if ($action -eq "create" -and [string]::IsNullOrWhiteSpace($anchor)) {
        Fail-Reject "无证据 create missing anchor"
    }
    if ($action -eq "create") {
        Test-CreateAnchorPath $anchor
    }
    if ($action -eq "improve" -or $action -eq "optimize_description") {
        $repo = Get-RepoRoot
        $t1 = Join-Path $repo ".ai-gates\skills\references\design-patterns.md"
        $t2 = Join-Path $repo ".ai-gates\design-patterns.project.md"
        $hit = (Test-NameAsTableCell $name $t1) -or (Test-NameAsTableCell $name $t2)
        if (-not $hit) {
            Fail-Reject "无证据 name not a table cell"
        }
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
        if (($joined -match 'origin') -and ($joined -match 'notes')) {
            for ($i = 0; $i -lt $cells.Count; $i++) {
                $h = $cells[$i].ToLowerInvariant()
                if ($h -eq "state") { $idxState = $i }
                if ($h -eq "origin") { $idxOrigin = $i }
                if ($h -eq "notes") { $idxNotes = $i }
                if ($h -eq "id") { $idxId = $i }
                if ($h -eq "title") { $idxTitle = $i }
            }
            $headerSeen = $true
            break
        }
    }
    if (-not $headerSeen) {
        Fail-Reject "无证据 queue missing origin/notes header"
    }
    if ($idxState -lt 0 -or $idxOrigin -lt 0 -or $idxNotes -lt 0 -or $idxTitle -lt 0) {
        Fail-Reject "无证据 queue header missing state/origin/notes/title"
    }
    $headerSeen = $false
    foreach ($line in $lines) {
        if ($line -notmatch '^\|') { continue }
        $cells = @(Get-Cells $line)
        if ($cells.Count -eq 0) { continue }
        $joined = ($cells -join " ").ToLowerInvariant()
        if (-not $headerSeen -and ($joined -match 'origin') -and ($joined -match 'notes')) {
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
