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

$fileUnfinished = (U @(0x672A, 0x5B8C, 0x6210)) + ".md"
$filePhys = (U @(0x7269, 0x7406, 0x53E3, 0x5F84)) + ".md"
$dirEv = U @(0x8BC1, 0x636E)
$stDoing = U @(0x6267, 0x884C, 0x4E2D)
$stDone = U @(0x7B7E, 0x6536)

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

function Test-HasProp($obj, [string]$name) {
    if ($null -eq $obj) { return $false }
    return $null -ne $obj.PSObject.Properties[$name]
}

function Get-Sha256Hex([byte[]]$Bytes) {
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-FileSha256HexSoft([string]$LiteralPath) {
    if ([string]::IsNullOrWhiteSpace($LiteralPath)) { return $null }
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $hash = $sha.ComputeHash($fs)
        return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } catch {
        return $null
    } finally {
        if ($null -ne $fs) { $fs.Dispose() }
        $sha.Dispose()
    }
}

function Convert-ToObjArray($items) {
    $acc = New-Object System.Collections.ArrayList
    if ($null -ne $items) {
        foreach ($it in $items) { [void]$acc.Add($it) }
    }
    if ($acc.Count -eq 0) { return @() }
    return @($acc.ToArray())
}

function Get-PayloadHex($items) {
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($it in (Convert-ToObjArray $items)) {
        if ($null -eq $it) { continue }
        $p = [string]$it.path
        if (-not [string]::IsNullOrEmpty($p)) { [void]$paths.Add($p) }
    }
    $arr = Convert-ToObjArray $paths
    if ($arr.Count -gt 1) { [Array]::Sort($arr, [StringComparer]::Ordinal) }
    $map = @{}
    foreach ($it in (Convert-ToObjArray $items)) {
        if ($null -eq $it) { continue }
        $map[[string]$it.path] = [string]$it.sha256
    }
    $sb = New-Object System.Text.StringBuilder
    foreach ($p in $arr) {
        $h = [string]$map[$p]
        [void]$sb.Append($p)
        [void]$sb.Append("=")
        [void]$sb.Append($h)
        [void]$sb.Append("`n")
    }
    return (Get-Sha256Hex $utf8.GetBytes($sb.ToString()))
}

function Get-WindowFpDiskItems([string]$repo, [string]$dirRel) {
    $list = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($dirRel)) { return $list }
    $dirFull = Join-Path $repo ($dirRel.Replace("/", "\"))
    if (-not (Test-Path -LiteralPath $dirFull)) { return $list }
    $files = New-Object System.Collections.Generic.List[string]
    [void]$files.Add((Join-Path $dirFull $fileUnfinished))
    $phys = Join-Path $dirFull $filePhys
    if (Test-Path -LiteralPath $phys) { [void]$files.Add($phys) }
    $mands = @(Get-ChildItem -LiteralPath $dirFull -File -Filter "Mandatory-Step*.md" -ErrorAction SilentlyContinue)
    foreach ($m in $mands) { [void]$files.Add($m.FullName) }
    foreach ($full in $files) {
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $name = [IO.Path]::GetFileName($full)
        $rel = ($dirRel.TrimEnd("/") + "/" + $name)
        $hash = Get-FileSha256HexSoft $full
        [void]$list.Add(@{ path = $rel; sha256 = $hash; name = $name; full = $full })
    }
    return $list
}

function Get-FreshInfo($node, [string]$repo) {
    $hasFp = (Test-HasProp $node "fp") -and (-not [string]::IsNullOrWhiteSpace([string]$node.fp))
    $hasFiles = (Test-HasProp $node "fpFiles") -and ($null -ne $node.fpFiles)
    $hasDir = (Test-HasProp $node "dir") -and (-not [string]::IsNullOrWhiteSpace([string]$node.dir))
    if (-not $hasFp -or -not $hasFiles -or -not $hasDir) {
        return @{ status = "absent"; changed = @() }
    }
    $dirRel = ([string]$node.dir).Replace("\", "/")
    $current = @(Get-WindowFpDiskItems $repo $dirRel)
    $stored = @($node.fpFiles)
    $storedMap = @{}
    foreach ($s in $stored) {
        if ($null -eq $s) { continue }
        $sp = ([string]$s.path).Replace("\", "/")
        $storedMap[$sp] = [string]$s.sha256
    }
    $changed = New-Object "System.Collections.Generic.HashSet[string]"
    foreach ($s in $stored) {
        if ($null -eq $s) { continue }
        $sp = ([string]$s.path).Replace("\", "/")
        $cur = $null
        foreach ($c in $current) {
            if ([string]$c.path -eq $sp) { $cur = $c; break }
        }
        $base = [IO.Path]::GetFileName($sp)
        if ($null -eq $cur) { [void]$changed.Add($base) }
        elseif ([string]$cur.sha256 -ne [string]$storedMap[$sp]) { [void]$changed.Add($base) }
    }
    foreach ($c in $current) {
        $cp = [string]$c.path
        if (-not $storedMap.ContainsKey($cp)) { [void]$changed.Add([string]$c.name) }
    }
    $payload = Get-PayloadHex $current
    $status = "stale"
    if (($payload -eq [string]$node.fp) -and ($changed.Count -eq 0)) { $status = "fresh" }
    return @{ status = $status; changed = (Convert-ToObjArray $changed) }
}

function Convert-NeighborOut($nb, [string]$repo, [string]$winStatus) {
    $cite = $null
    if (Test-HasProp $nb "cite") { $cite = $nb.cite }
    $citeOut = $null
    if ($null -ne $cite) {
        $file = [string]$cite.file
        $sha = [string]$cite.sha256
        $citeStatus = $null
        if (-not [string]::IsNullOrWhiteSpace($file)) {
            $full = Join-Path $repo ($file.Replace("/", "\"))
            $now = Get-FileSha256HexSoft $full
            if ($null -eq $now -or $now -ne $sha) { $citeStatus = "stale" }
        }
        $citeOut = @{
            file     = $file
            quote    = [string]$cite.quote
            sha256   = $sha
            raw      = [string]$cite.raw
            resolved = [string]$cite.resolved
        }
        if ($citeStatus) { $citeOut["status"] = $citeStatus }
    }
    $out = @{
        id     = [string]$nb.id
        score  = [int]$nb.score
        signal = [string]$nb.signal
        broken = [bool]$nb.broken
    }
    if (Test-HasProp $nb "grade") { $out["grade"] = [string]$nb.grade }
    if ($null -ne $citeOut) { $out["cite"] = $citeOut }
    return $out
}

function Emit-Card([string]$path, [string]$id, [string]$repo) {
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Id is required"
    }
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Output "MISSING"
        exit 1
    }
    $raw = [System.IO.File]::ReadAllText($path, $utf8)
    $j = $null
    try {
        $j = $raw | ConvertFrom-Json
    } catch {
        Write-Output "MISSING"
        exit 1
    }
    if ($null -eq $j) {
        Write-Output "MISSING"
        exit 1
    }
    $node = $null
    foreach ($n in @($j.nodes)) {
        if ($n.id -eq $id) { $node = $n; break }
    }
    if ($null -eq $node) {
        Write-Output "MISSING"
        $inFog = $false
        foreach ($f in @($j.fog)) {
            if ([string]$f -eq $id) { $inFog = $true; break }
        }
        if (-not $inFog) {
            $mini = [ordered]@{
                gaps = @(@{ kind = "unexplored"; id = $id })
            }
            Write-Output ($mini | ConvertTo-Json -Depth 6 -Compress)
        }
        exit 1
    }
    $fresh = Get-FreshInfo $node $repo
    $nbOut = New-Object System.Collections.Generic.List[object]
    foreach ($nb in @($node.neighbors)) {
        if ($null -eq $nb) { continue }
        [void]$nbOut.Add((Convert-NeighborOut $nb $repo ([string]$fresh.status)))
    }
    $gapsOut = New-Object System.Collections.Generic.List[object]
    if (Test-HasProp $node "gaps") {
        foreach ($g in @($node.gaps)) {
            if ($null -eq $g) { continue }
            $ge = @{ kind = [string]$g.kind }
            if (Test-HasProp $g "id") { $ge["id"] = [string]$g.id }
            [void]$gapsOut.Add($ge)
        }
    }
    $recOut = $null
    if ((Test-HasProp $node "rec") -and ($null -ne $node.rec) -and (Test-HasProp $node.rec "id") -and (-not [string]::IsNullOrWhiteSpace([string]$node.rec.id))) {
        $recOut = @{ id = [string]$node.rec.id; why = [string]$node.rec.why }
    }
    $freshOut = @{ status = [string]$fresh.status }
    if ([string]$fresh.status -eq "stale") { $freshOut["changed"] = @($fresh.changed) }
    $nbArr = @()
    if ($nbOut.Count -gt 0) { $nbArr = @($nbOut.ToArray()) }
    $gapArr = @()
    if ($gapsOut.Count -gt 0) { $gapArr = @($gapsOut.ToArray()) }
    $genVal = $null
    if (Test-HasProp $j "generated") { $genVal = [string]$j.generated }
    $card = [ordered]@{
        id        = [string]$node.id
        state     = [string]$node.state
        neighbors = $nbArr
        rec       = $recOut
        generated = $genVal
        jsonPath  = [string]$path
        fresh     = $freshOut
        gaps      = $gapArr
    }
    if (Test-HasProp $node "dir") { $card["dir"] = [string]$node.dir }
    ($card | ConvertTo-Json -Depth 10 -Compress)
    exit 0
}

function Fail-SC([string]$msg) {
    Write-Output ("SELFCHECK_FAIL " + $msg)
    exit 1
}

function Invoke-Child([string]$file, [string]$argLine) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$file`" $argLine"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ code = [int]$p.ExitCode; out = [string]$out; err = [string]$err }
}

function Parse-CardText([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $line = $text.Trim()
    foreach ($row in ($text -split "`n")) {
        $t = $row.Trim()
        if ($t.StartsWith("{")) { $line = $t; break }
    }
    try { return ($line | ConvertFrom-Json) } catch { return $null }
}

function Get-CardFailReason($card) {
    if ($null -eq $card) { return "card-null" }
    if (-not (Test-HasProp $card "fresh")) { return "missing-fresh" }
    if (-not (Test-HasProp $card "gaps")) { return "missing-gaps" }
    if (Test-HasProp $card "pins") { return "has-pins" }
    $st = ""
    if (Test-HasProp $card.fresh "status") { $st = [string]$card.fresh.status }
    if (@("fresh", "stale", "absent") -notcontains $st) { return "bad-fresh-status" }
    foreach ($nb in @($card.neighbors)) {
        if ($null -eq $nb) { continue }
        if (-not (Test-HasProp $nb "grade")) { return "neighbor-missing-grade" }
        $g = [string]$nb.grade
        if (@("confirmed", "supported", "inferred") -notcontains $g) { return "bad-grade" }
        if (-not (Test-HasProp $nb "cite")) { return "neighbor-missing-cite" }
        $c = $nb.cite
        if ($null -eq $c) { return "cite-null" }
        if ($c -is [System.Array]) { return "cite-array" }
        if ([string]::IsNullOrEmpty([string]$c.file)) { return "cite-file-empty" }
        if ([string]::IsNullOrEmpty([string]$c.quote)) { return "cite-quote-empty" }
        if ([string]::IsNullOrEmpty([string]$c.raw)) { return "cite-raw-empty" }
        if ([string]::IsNullOrEmpty([string]$c.resolved)) { return "cite-resolved-empty" }
        if (([string]$c.quote).Length -gt 80) { return "cite-quote-gt80" }
    }
    return ""
}

function Find-Nb($card, [string]$nid) {
    foreach ($nb in @($card.neighbors)) {
        if ($null -ne $nb -and [string]$nb.id -eq $nid) { return $nb }
    }
    return $null
}

function Get-RelTableHeader() {
    $p1 = (U @(0x7A97, 0x8DEF, 0x5F84)) + [string][char]0xFF08 + (U @(0x4E3B, 0x9898, 0x77ED, 0x540D)) + [string][char]0xFF09
    $p2 = U @(0x5173, 0x7CFB)
    $p3 = U @(0x72B6, 0x6001)
    $p4 = (U @(0x5173, 0x952E, 0x7ED3, 0x8BBA)) + [string][char]0xFF08 + (U @(0x4E00, 0x53E5)) + [string][char]0xFF09
    return ("| " + $p1 + " | " + $p2 + " | " + $p3 + " | " + $p4 + " |`n| --- | --- | --- | --- |")
}

function New-Unfinished([string]$title, [string]$rows, [string]$body) {
    $h = "## " + (U @(0x7A97, 0x53E3, 0x5173, 0x7CFB, 0x6458, 0x8981))
    $g = "## " + (U @(0x76EE, 0x6807))
    $tbl = (Get-RelTableHeader) + "`n" + $rows
    return ("# " + $title + "`n`n" + $h + "`n`n" + $tbl + "`n`n" + $g + "`n`n" + $body + "`n")
}

function Write-FxFile([string]$path, [string]$text) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($path, $text, $utf8)
}

function Invoke-SelfCheck([string]$repo) {
    $structRel = ".ai-gates\skills\references\fog-map-structure.md"
    $structPath = Join-Path $repo $structRel
    if (-not (Test-Path -LiteralPath $structPath)) {
        Fail-SC "missing structure page"
    }
    $txt = [System.IO.File]::ReadAllText($structPath, $utf8)
    $scriptRelFwd = ".ai-gates/scripts/query-fog-card.ps1"
    $scriptRelBack = ".ai-gates\scripts\query-fog-card.ps1"
    if (($txt.IndexOf($scriptRelFwd) -lt 0) -and ($txt.IndexOf($scriptRelBack) -lt 0)) {
        Fail-SC "structure page must name query script path"
    }
    $ban = U @(0x7981, 0x6B62)
    $use = U @(0x7528)
    $banUseRead = $ban + $use + " Read"
    $banSpaceRead = $ban + " Read"
    $fogJson = "fog-map.json"
    $hasBanRead = ($txt.IndexOf($banUseRead) -ge 0) -or ($txt.IndexOf($banSpaceRead) -ge 0)
    if ((-not $hasBanRead) -or ($txt.IndexOf($fogJson) -lt 0)) {
        Fail-SC "structure page must ban Read of whole fog-map.json"
    }
    if ($txt.IndexOf("fresh.status") -lt 0) { Fail-SC "structure missing fresh.status" }
    if ($txt.IndexOf("confirmed") -lt 0 -or $txt.IndexOf("supported") -lt 0 -or $txt.IndexOf("inferred") -lt 0) {
        Fail-SC "structure missing grade enum"
    }
    foreach ($k in @("undocumented", "thin-evidence", "pending", "unexplored")) {
        if ($txt.IndexOf($k) -lt 0) { Fail-SC ("structure missing gaps kind " + $k) }
    }
    $claim = (U @(0x4E0D, 0x5F97, 0x636E, 0x6B64, 0x58F0, 0x79F0, 0x5173, 0x7CFB, 0x4ECD, 0x6210, 0x7ACB))
    if ($txt.IndexOf($claim) -lt 0) { Fail-SC "structure missing stale-claim ban" }
    $everyAsk = "每个 Step " + (U @(0x6536, 0x53E3)) + (U @(0x90FD, 0x95EE))
    $idxAsk = $txt.IndexOf($everyAsk)
    while ($idxAsk -ge 0) {
        $start = [Math]::Max(0, $idxAsk - 10)
        $pre = $txt.Substring($start, $idxAsk - $start)
        if ($pre.IndexOf($ban) -lt 0) { Fail-SC "unnegated ask-every-step" }
        $idxAsk = $txt.IndexOf($everyAsk, $idxAsk + 1)
    }

    $src = [IO.File]::ReadAllText($PSCommandPath, $utf8)
    $emitIdx = $src.IndexOf("function Emit-Card")
    $selfIdx = $src.IndexOf("function Invoke-SelfCheck")
    if ($emitIdx -ge 0 -and $selfIdx -gt $emitIdx) {
        $emitBody = $src.Substring($emitIdx, $selfIdx - $emitIdx)
        if ($emitBody.IndexOf("generate-fog-map.ps1") -ge 0) { Fail-SC "emit-calls-generate" }
    }

    foreach ($sk in @("planner\SKILL.md", "developer\SKILL.md", "code-reviewer\SKILL.md")) {
        $sp = Join-Path (Join-Path $repo ".ai-gates\skills") $sk
        if (-not (Test-Path -LiteralPath $sp)) { Fail-SC ("missing skill " + $sk) }
        $stxt = [IO.File]::ReadAllText($sp, $utf8)
        if ($stxt.IndexOf("fresh.status") -ge 0) { Fail-SC ("skill copied fresh.status " + $sk) }
        if ($stxt.IndexOf("thin-evidence") -ge 0) { Fail-SC ("skill copied gaps " + $sk) }
    }

    $themeDir = Join-Path $repo (Join-Path ".ai-gates\Doc" ("AI" + (U @(0x6D41, 0x6C34, 0x7EBF))))
    $probeId = U @(0x89C4, 0x5219, 0x7FFB, 0x9519, 0x672C, 0x8BC4, 0x6D4B)
    $probe = Invoke-Child $PSCommandPath ("-DocRoot `"$themeDir`" -Id `"$probeId`"")
    if ($probe.code -ne 0) {
        Write-Output ("SELFCHECK_FAIL probe exit=" + $probe.code)
        if ($probe.out) { Write-Output $probe.out }
        if ($probe.err) { Write-Output $probe.err }
        exit 1
    }
    if ($probe.out.IndexOf("neighbors") -lt 0) {
        Fail-SC "probe output missing neighbors"
    }

    $neg = [pscustomobject]@{ id = "n"; neighbors = @(); rec = $null }
    if ((Get-CardFailReason $neg) -eq "") { Fail-SC "neg-missing-keys-passed" }
    $negPins = [pscustomobject]@{
        id        = "n"
        fresh     = [pscustomobject]@{ status = "fresh" }
        gaps      = @()
        neighbors = @()
        pins      = @("x")
    }
    if ((Get-CardFailReason $negPins) -eq "") { Fail-SC "neg-pins-passed" }
    $negQuote = [pscustomobject]@{
        id        = "n"
        fresh     = [pscustomobject]@{ status = "fresh" }
        gaps      = @()
        neighbors = @([pscustomobject]@{
            id    = "o"
            grade = "confirmed"
            cite  = [pscustomobject]@{ file = "a.md"; quote = ""; raw = "r"; resolved = "o" }
        })
    }
    if ((Get-CardFailReason $negQuote) -eq "") { Fail-SC "neg-empty-quote-passed" }

    $fxRoot = Join-Path $repo ".ai-gates\tmp\fog-readcard-fx"
    $fxOutDir = Join-Path $repo ".ai-gates\tmp\fog-readcard-out"
    $fxDlog = Join-Path $repo ".ai-gates\tmp\fog-readcard-dlog"
    foreach ($d in @($fxRoot, $fxOutDir, $fxDlog)) {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
        New-Item -ItemType Directory -Path $d | Out-Null
    }

    $rowC = "| Confirmed | upstream | " + $stDone + " | name-col row no full id |"
    $rowG = "| FX-GhostNoDir | related | " + $stDone + " | undocumented name |"
    $rowO = "| OtherAlias | related | " + $stDone + " | FX-OtherCol other-col hit |"
    $doingMd = New-Unfinished "FX-Doing" ($rowC + "`n" + $rowG + "`n" + $rowO) "body names FX-Supported and FX-Inferred for over-threshold."
    $confMd = New-Unfinished "FX-Confirmed" "| UnrelatedConfirmed | related | $stDone | no reverse name of doing |" "signed off window for rec."
    $otherMd = New-Unfinished "FX-OtherCol" "| Doing | upstream | $stDone | reverse so both-sides rel |" "other col window."
    $supMd = New-Unfinished "FX-Supported" "| NobodyHere | related | $stDone | no rel to doing |" "supported body does not name FX-Doing."
    $infMd = New-Unfinished "FX-Inferred" "| NobodyHere2 | related | $stDone | no rel |" "inferred window body silent."
    $penMd = New-Unfinished "FX-PendingEv" "| NobodyHere3 | related | $stDone | no rel |" "pending window body silent."

    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDoing) "FX-Doing") $fileUnfinished) $doingMd
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDoing) "FX-Doing") "Mandatory-Step01.md") "# M1`n"
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-Confirmed") $fileUnfinished) $confMd
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDoing) "FX-OtherCol") $fileUnfinished) $otherMd
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-Supported") $fileUnfinished) $supMd
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-Inferred") $fileUnfinished) $infMd
    Write-FxFile (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-PendingEv") $fileUnfinished) $penMd
    Write-FxFile (Join-Path (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-Supported") $dirEv) "ev.md") "mentions FX-Doing in evidence.`n"
    Write-FxFile (Join-Path (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-PendingEv") $dirEv) "only.md") "evidence-only FX-Doing.`n"

    $gen = Join-Path $repo ".ai-gates\scripts\generate-fog-map.ps1"
    $outHtml = Join-Path $fxOutDir "fog-map.html"
    $jsonPath = Join-Path $fxOutDir "fog-map.json"
    $genRun = Invoke-Child $gen ("-DocRoot `"$fxRoot`" -OutFile `"$outHtml`" -DirectLogRoot `"$fxDlog`"")
    if ($genRun.code -ne 0) {
        Write-Output ("SELFCHECK_FAIL generate-fx exit=" + $genRun.code)
        if ($genRun.out) { Write-Output $genRun.out }
        if ($genRun.err) { Write-Output $genRun.err }
        exit 1
    }
    if (-not (Test-Path -LiteralPath $jsonPath)) { Fail-SC "fixture json missing" }
    $lean = [IO.File]::ReadAllText($jsonPath, $utf8) | ConvertFrom-Json
    $doingNode = $null
    foreach ($n in @($lean.nodes)) {
        if ([string]$n.id -eq "FX-Doing") { $doingNode = $n; break }
    }
    if ($null -eq $doingNode) { Fail-SC "fixture node FX-Doing missing" }
    if (Test-HasProp $doingNode "pins") { Fail-SC "lean node has pins" }
    if (-not (Test-HasProp $doingNode "dir") -or [string]::IsNullOrWhiteSpace([string]$doingNode.dir)) {
        Fail-SC "lean node missing dir"
    }
    $expectDir = (".ai-gates/tmp/fog-readcard-fx/" + $stDoing + "/FX-Doing")
    if (([string]$doingNode.dir).Replace("\", "/") -ne $expectDir) { Fail-SC "dir-mismatch" }

    $qDoing = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qDoing.code -ne 0) { Fail-SC ("query FX-Doing exit=" + $qDoing.code) }
    $card = Parse-CardText $qDoing.out
    $why = Get-CardFailReason $card
    if ($why -ne "") { Fail-SC ("positive-card " + $why) }
    if ([string]$card.fresh.status -ne "fresh") { Fail-SC "expected-fresh" }

    $kinds = @()
    foreach ($g in @($card.gaps)) { $kinds += [string]$g.kind }
    foreach ($need in @("undocumented", "thin-evidence", "pending")) {
        if ($kinds -notcontains $need) { Fail-SC ("gaps missing " + $need) }
    }
    $allowed = @("undocumented", "thin-evidence", "pending", "unexplored")
    foreach ($g in @($card.gaps)) {
        if ($allowed -notcontains [string]$g.kind) { Fail-SC ("fifth-kind " + $g.kind) }
    }
    $pendingIds = @()
    $undocIds = @()
    foreach ($g in @($card.gaps)) {
        if ([string]$g.kind -eq "pending") { $pendingIds += [string]$g.id }
        if ([string]$g.kind -eq "undocumented") { $undocIds += [string]$g.id }
    }
    if ($pendingIds -notcontains "FX-PendingEv") { Fail-SC "pending missing FX-PendingEv" }
    if ($pendingIds -contains "FX-Inferred") { Fail-SC "inferred-in-pending" }
    if ($undocIds -notcontains "FX-GhostNoDir") { Fail-SC "undocumented missing FX-GhostNoDir" }
    if ($null -ne (Find-Nb $card "FX-PendingEv")) { Fail-SC "pending-in-neighbors" }

    $nbC = Find-Nb $card "FX-Confirmed"
    if ($null -eq $nbC) { Fail-SC "missing neighbor FX-Confirmed" }
    if ([string]$nbC.grade -ne "confirmed") { Fail-SC "confirmed-grade" }
    $qc = [string]$nbC.cite.quote
    if ($qc.IndexOf("Confirmed") -lt 0) { Fail-SC "confirmed-quote-not-name-row" }
    if ($qc.IndexOf("FX-Confirmed") -ge 0) { Fail-SC "confirmed-quote-has-full-id" }
    if ([string]$nbC.cite.raw -ne "Confirmed") { Fail-SC "confirmed-raw" }
    if ([string]$nbC.cite.resolved -ne "FX-Confirmed") { Fail-SC "confirmed-resolved" }

    $nbO = Find-Nb $card "FX-OtherCol"
    if ($null -eq $nbO) { Fail-SC "missing neighbor FX-OtherCol" }
    if ([string]$nbO.grade -ne "confirmed") { Fail-SC "othercol-grade" }
    $qo = [string]$nbO.cite.quote
    if ($qo.Length -eq 0) { Fail-SC "othercol-quote-empty" }
    if ($qo.IndexOf("FX-OtherCol") -lt 0) { Fail-SC "othercol-quote-not-other-col-row" }
    if ($qo.IndexOf("OtherAlias") -lt 0) { Fail-SC "othercol-quote-wrong-row" }
    if ([string]$nbO.cite.raw -ne "FX-OtherCol") { Fail-SC "othercol-raw" }
    if ([string]$nbO.cite.resolved -ne "FX-OtherCol") { Fail-SC "othercol-resolved" }
    if (([string]$nbO.cite.file).IndexOf("FX-Doing") -lt 0) { Fail-SC "cite-not-ordinal-earlier" }
    if (([string]$nbO.cite.file).IndexOf("FX-OtherCol") -ge 0) { Fail-SC "cite-from-later-side" }

    $nbS = Find-Nb $card "FX-Supported"
    if ($null -eq $nbS) { Fail-SC "missing neighbor FX-Supported" }
    if ([string]$nbS.grade -ne "supported") { Fail-SC "supported-grade" }
    if (([string]$nbS.cite.file).IndexOf($dirEv) -lt 0) { Fail-SC "supported-cite-not-evidence" }

    $nbI = Find-Nb $card "FX-Inferred"
    if ($null -eq $nbI) { Fail-SC "missing neighbor FX-Inferred" }
    if ([string]$nbI.grade -ne "inferred") { Fail-SC "inferred-grade" }

    if ($null -eq $card.rec -or -not (Test-HasProp $card.rec "id")) { Fail-SC "doing-rec-null" }
    if ([string]$card.rec.id -ne "FX-Confirmed") { Fail-SC "doing-rec-id" }
    if (@("supported", "inferred") -contains [string]$card.rec.id) { Fail-SC "rec-bad-grade-target" }

    $qConf = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Confirmed`"")
    if ($qConf.code -ne 0) { Fail-SC ("query FX-Confirmed exit=" + $qConf.code) }
    $cardConf = Parse-CardText $qConf.out
    $whyC = Get-CardFailReason $cardConf
    if ($whyC -ne "") { Fail-SC ("confirmed-card " + $whyC) }
    if ($null -ne $cardConf.rec) {
        Fail-SC "nondoing-rec-not-null"
    }

    $qFake = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-NoSuchZZZ`"")
    if ($qFake.code -eq 0) { Fail-SC "fake-id-exit0" }
    if ($qFake.out.IndexOf("MISSING") -lt 0) { Fail-SC "fake-id-missing" }
    if ($qFake.out.IndexOf("unexplored") -lt 0) { Fail-SC "fake-id-unexplored" }

    $qFog = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-GhostNoDir`"")
    if ($qFog.code -eq 0) { Fail-SC "fog-id-exit0" }
    if ($qFog.out.IndexOf("MISSING") -lt 0) { Fail-SC "fog-id-missing" }
    if ($qFog.out.IndexOf("unexplored") -ge 0) { Fail-SC "fog-id-unexplored" }

    $doingDir = Join-Path (Join-Path $fxRoot $stDoing) "FX-Doing"
    $ufPath = Join-Path $doingDir $fileUnfinished
    $ufItem = Get-Item -LiteralPath $ufPath
    $oldWrite = $ufItem.LastWriteTimeUtc
    $oldBytes = [IO.File]::ReadAllBytes($ufPath)
    $ufItem.LastWriteTimeUtc = $oldWrite.AddHours(3)
    $qMtime = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qMtime.code -ne 0) { Fail-SC ("mtime-query exit=" + $qMtime.code) }
    $cardM = Parse-CardText $qMtime.out
    if ([string]$cardM.fresh.status -ne "fresh") { Fail-SC "mtime-not-fresh" }
    $ufItem = Get-Item -LiteralPath $ufPath
    $ufItem.LastWriteTimeUtc = $oldWrite

    [IO.File]::WriteAllBytes($ufPath, ($oldBytes + [byte[]](0x0A, 0x78)))
    $ufItem2 = Get-Item -LiteralPath $ufPath
    $ufItem2.LastWriteTimeUtc = $oldWrite
    $qByte = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qByte.code -ne 0) { Fail-SC ("byte-query exit=" + $qByte.code + " must-be-0-on-stale-card") }
    $cardB = Parse-CardText $qByte.out
    if ([string]$cardB.fresh.status -ne "stale") { Fail-SC "byte-not-stale" }
    $chB = @($cardB.fresh.changed)
    if ($chB -notcontains $fileUnfinished) { Fail-SC "byte-changed-missing-unfinished" }
    if (-not (Test-HasProp $cardB "neighbors") -or -not (Test-HasProp $cardB "gaps")) { Fail-SC "stale-missing-neighbors-or-gaps" }
    [IO.File]::WriteAllBytes($ufPath, $oldBytes)
    (Get-Item -LiteralPath $ufPath).LastWriteTimeUtc = $oldWrite

    $physPath = Join-Path $doingDir $filePhys
    Write-FxFile $physPath "# phys`n"
    $qPhys = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qPhys.code -ne 0) { Fail-SC ("add-phys exit=" + $qPhys.code) }
    $cardP = Parse-CardText $qPhys.out
    if ([string]$cardP.fresh.status -ne "stale") { Fail-SC "add-phys-still-fresh" }
    if (@($cardP.fresh.changed) -notcontains $filePhys) { Fail-SC "add-phys-changed" }
    Remove-Item -LiteralPath $physPath -Force

    $mandPath = Join-Path $doingDir "Mandatory-Step01.md"
    $mandBytes = [IO.File]::ReadAllBytes($mandPath)
    Remove-Item -LiteralPath $mandPath -Force
    $qDel = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qDel.code -ne 0) { Fail-SC ("del-mand exit=" + $qDel.code) }
    $cardD = Parse-CardText $qDel.out
    if ([string]$cardD.fresh.status -ne "stale") { Fail-SC "del-mand-not-stale" }
    if (@($cardD.fresh.changed) -notcontains "Mandatory-Step01.md") { Fail-SC "del-mand-changed" }
    [IO.File]::WriteAllBytes($mandPath, $mandBytes)

    $evPath = Join-Path (Join-Path (Join-Path (Join-Path $fxRoot $stDone) "FX-Supported") $dirEv) "ev.md"
    $evOld = [IO.File]::ReadAllBytes($evPath)
    [IO.File]::WriteAllText($evPath, "mentions FX-Doing in evidence.`nchanged`n", $utf8)
    $qCite = Invoke-Child $PSCommandPath ("-JsonPath `"$jsonPath`" -Id `"FX-Doing`"")
    if ($qCite.code -ne 0) { Fail-SC ("cite-change exit=" + $qCite.code) }
    $cardCite = Parse-CardText $qCite.out
    if ([string]$cardCite.fresh.status -ne "fresh") { Fail-SC "cite-change-window-stale" }
    $nbCite = Find-Nb $cardCite "FX-Supported"
    if ($null -eq $nbCite) { Fail-SC "cite-change-missing-supported" }
    if (-not (Test-HasProp $nbCite.cite "status") -or [string]$nbCite.cite.status -ne "stale") {
        Fail-SC "cite-change-not-stale"
    }
    [IO.File]::WriteAllBytes($evPath, $evOld)

    $stripped = $lean | ConvertTo-Json -Depth 12
    $j2 = $stripped | ConvertFrom-Json
    foreach ($n in @($j2.nodes)) {
        if ([string]$n.id -eq "FX-Doing") {
            $n.PSObject.Properties.Remove("fp") | Out-Null
            $n.PSObject.Properties.Remove("fpFiles") | Out-Null
        }
    }
    $absJson = Join-Path $fxOutDir "fog-map-absent.json"
    [IO.File]::WriteAllText($absJson, ($j2 | ConvertTo-Json -Depth 12), $utf8)
    $qAbs = Invoke-Child $PSCommandPath ("-JsonPath `"$absJson`" -Id `"FX-Doing`"")
    if ($qAbs.code -ne 0) { Fail-SC ("absent-query exit=" + $qAbs.code) }
    $cardA = Parse-CardText $qAbs.out
    if ([string]$cardA.fresh.status -ne "absent") { Fail-SC "absent-status" }
    if (-not (Test-HasProp $cardA "neighbors") -or -not (Test-HasProp $cardA "gaps")) { Fail-SC "absent-missing-card-fields" }

    Write-Output "SELFCHECK_OK"
    exit 0
}

$repo = Resolve-RepoRoot
if ($SelfCheck) {
    Invoke-SelfCheck $repo
}

$resolved = Resolve-JsonPath $repo $JsonPath $DocRoot
Emit-Card $resolved $Id $repo
