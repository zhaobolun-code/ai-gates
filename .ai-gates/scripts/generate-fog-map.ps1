# Fog-map 5.0 generator. ASCII-only source (Windows PS 5 parser).
# No -DocRoot: scan project-context doc-root PARENT themes + .ai-gates/Doc themes.
# Skip DirectLog folder. Do not recurse Assets/LabSDK or Assets.
# With -DocRoot: keep single-root (4.x probes).
# No -OutFile: default .ai-gates/verify/fog-map.html (create dir if missing).
# JSON: roots[] is the scan set. Keep "root" = roots[0] so 4.x readers that
# still read DATA.root / lean.json.root do not treat a missing key as 0.
# Do not edit fog-map-structure.md in this step (Step1).
param(
    [string]$DocRoot,
    [string]$OutFile,
    [string]$DirectLogRoot
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true

function U([int[]]$codes) {
    return (-join ($codes | ForEach-Object { [char]$_ }))
}

$repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path }
$repoRoot = $repoRoot.Trim()

$stDoing = U @(0x6267, 0x884C, 0x4E2D)
$stDone = U @(0x7B7E, 0x6536)
$stPause = U @(0x505C, 0x5199)
$stNo = U @(0x672A, 0x901A, 0x8FC7)
$stFail = U @(0x5931, 0x8D25)
$stLayer = U @(0x6362, 0x5C42)
$stBack = U @(0x56DE, 0x9000)
$fileUnfinished = (U @(0x672A, 0x5B8C, 0x6210)) + ".md"
$filePhys = (U @(0x7269, 0x7406, 0x53E3, 0x5F84)) + ".md"
$dirDone = U @(0x5DF2, 0x5B8C, 0x6210)
$fileIdxCn = "_" + (U @(0x7D22, 0x5F15)) + ".md"
$dirEv = U @(0x8BC1, 0x636E)
$zhTong = U @(0x76F4, 0x901A, 0x6587, 0x6863)
$fileDirectLog = "DIRECTLOG.md"

# DocRoot / scanRoots resolved after $stateMap (need terminal-state folder names).
if (-not $OutFile) {
    $OutFile = Join-Path $repoRoot ".ai-gates\verify\fog-map.html"
}
if (-not $DirectLogRoot) {
    $DirectLogRoot = Join-Path $repoRoot (Join-Path ".ai-gates\Doc" $zhTong)
}

$stateMap = @{
    $stDoing = "doing"
    $stDone  = "done"
    $stPause = "pause"
    $stNo    = "fail"
    $stFail  = "fail"
    $stLayer = "layer"
    $stBack  = "fail"
}

$clipDoc = 8000
$clipEv = 4000
$maxEv = 6
$okExt = @(".md", ".json", ".txt", ".log")

function Read-Utf8([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    return [IO.File]::ReadAllText($path, $utf8)
}

function Clip-Text([string]$s, [int]$n) {
    if ($null -eq $s) { return "" }
    if ($s.Length -le $n) { return $s }
    return $s.Substring(0, $n) + "`n...(truncated)"
}

function Get-PinKind([string]$name) {
    if ($name -match "dispatch|plan-review") { return "dispatch" }
    $pai = U @(0x6D3E, 0x53D1)
    $shen = U @(0x5BA1, 0x6838)
    if ($name.Contains($pai) -or $name.Contains($shen)) { return "dispatch" }
    if ($name -match "implement|CR") { return "report" }
    $shi = U @(0x5B9E, 0x73B0)
    $dai = U @(0x4EE3, 0x7801)
    if ($name.Contains($shi) -or $name.Contains($dai)) { return "report" }
    $hei = U @(0x9ED1, 0x677F)
    if ($name.Contains($hei) -or $name -match "blackboard") { return "board" }
    $cuo = U @(0x9519, 0x9898)
    if ($name.Contains($cuo) -or $name -match "lesson") { return "lesson" }
    return "other"
}

function Get-CsTokens([string]$text) {
    $set = New-Object "System.Collections.Generic.HashSet[string]"
    if (-not $text) { return @() }
    [regex]::Matches($text, "[A-Za-z_][\w.]*\.cs") | ForEach-Object { [void]$set.Add($_.Value) }
    return @($set)
}

function Test-IdInText([string]$text, [string]$target, [string[]]$idsLenDesc) {
    if ([string]::IsNullOrEmpty($text) -or [string]::IsNullOrEmpty($target)) { return $false }
    $start = 0
    $tlen = $target.Length
    while ($start -le $text.Length - $tlen) {
        $pos = $text.IndexOf($target, $start, [StringComparison]::Ordinal)
        if ($pos -lt 0) { return $false }
        $shadowed = $false
        foreach ($other in $idsLenDesc) {
            if ($other.Length -le $tlen) { break }
            if ($pos + $other.Length -le $text.Length -and $text.Substring($pos, $other.Length) -eq $other) {
                $shadowed = $true
                break
            }
            $inner = $other.IndexOf($target, [StringComparison]::Ordinal)
            if ($inner -gt 0) {
                $back = $pos - $inner
                if ($back -ge 0 -and $back + $other.Length -le $text.Length -and $text.Substring($back, $other.Length) -eq $other) {
                    $shadowed = $true
                    break
                }
            }
        }
        if (-not $shadowed) { return $true }
        $start = $pos + 1
    }
    return $false
}

function Strip-RelJunk([string]$cell, [string[]]$stateKeys) {
    $cell = $cell.Trim().Trim([char]0x60).Trim()
    foreach ($st in $stateKeys) {
        $prefix = $st + "/"
        if ($cell.StartsWith($prefix)) {
            $cell = $cell.Substring($prefix.Length)
            break
        }
    }
    $lPar = [string][char]0xFF08
    $rPar = [string][char]0xFF09
    $cell = [regex]::Replace($cell, "[" + [regex]::Escape($lPar) + "\(][^" + [regex]::Escape($rPar) + "\)]*[" + [regex]::Escape($rPar) + "\)]\s*$", "")
    return $cell.Trim().Trim([char]0x60).TrimEnd("/").Trim()
}

function Get-RelNames([string]$relBlock, [string[]]$stateKeys) {
    $names = New-Object "System.Collections.Generic.HashSet[string]"
    if ([string]::IsNullOrEmpty($relBlock)) { return $names }
    $enumComma = [string][char]0x3001
    foreach ($line in ($relBlock -split "`n")) {
        if ($line -notmatch "^\s*\|") { continue }
        $parts = @($line -split "\|")
        if ($parts.Count -lt 3) { continue }
        $cell = $parts[1].Trim().Trim([char]0x60).Trim()
        if ($cell.Length -eq 0) { continue }
        if ($cell -match (U @(0x7A97, 0x8DEF, 0x5F84))) { continue }
        if ($cell -match "^:?-+:?$") { continue }
        $chunks = @($cell -split ("\s+/\s+|" + [regex]::Escape($enumComma)))
        foreach ($chunk in $chunks) {
            $one = Strip-RelJunk $chunk $stateKeys
            if ($one.Length -lt 2) { continue }
            if ($one.StartsWith([string][char]0xFF08) -or $one.StartsWith("(")) { continue }
            [void]$names.Add($one)
        }
    }
    return $names
}

$stateKeys = @($stateMap.Keys)
$scanRoots = New-Object System.Collections.Generic.List[string]
$explicitDocRoot = -not [string]::IsNullOrWhiteSpace($DocRoot)
if ($explicitDocRoot) {
    if (-not (Test-Path -LiteralPath $DocRoot)) {
        Write-Error "DocRoot not found: $DocRoot"
    }
    [void]$scanRoots.Add((Resolve-Path -LiteralPath $DocRoot).Path)
} else {
    $chem = U @(0x5316, 0x5B66, 0x6587, 0x6863)
    $chemParent = Join-Path $repoRoot "Assets\LabSDK\Runtime\Pennon\ExplorationLab\$chem"
    $gatesDoc = Join-Path $repoRoot ".ai-gates\Doc"
    foreach ($parent in @($chemParent, $gatesDoc)) {
        if (-not (Test-Path -LiteralPath $parent)) { continue }
        $themes = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue)
        foreach ($theme in $themes) {
            if ($theme.Name -eq $zhTong) { continue }
            $isTheme = $false
            foreach ($st in $stateKeys) {
                if (Test-Path -LiteralPath (Join-Path $theme.FullName $st)) { $isTheme = $true; break }
            }
            if ($isTheme) { [void]$scanRoots.Add($theme.FullName) }
        }
    }
}
if ($scanRoots.Count -eq 0) {
    Write-Error "no scan roots"
}
$DocRoot = [string]$scanRoots[0]

$windows = New-Object System.Collections.Generic.List[object]
$idSet = New-Object "System.Collections.Generic.HashSet[string]"

foreach ($themeRoot in $scanRoots) {
foreach ($st in $stateKeys) {
    $dir = Join-Path $themeRoot $st
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $kids = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue)
    foreach ($folder in $kids) {
        $id = $folder.Name
        if ($idSet.Contains($id)) { continue }
        $unfinished = Join-Path $folder.FullName $fileUnfinished
        if (-not (Test-Path -LiteralPath $unfinished)) { continue }
        [void]$idSet.Add($id)
        $body = Read-Utf8 $unfinished
        $phys = Read-Utf8 (Join-Path $folder.FullName $filePhys)
        $idx = Read-Utf8 (Join-Path $folder.FullName (Join-Path $dirDone "_index.md"))
        if (-not $idx) { $idx = Read-Utf8 (Join-Path $folder.FullName (Join-Path $dirDone $fileIdxCn)) }
        $mandFiles = @(Get-ChildItem -LiteralPath $folder.FullName -Filter "Mandatory-Step*.md" -File -ErrorAction SilentlyContinue)
        $mandText = ($mandFiles | ForEach-Object { Read-Utf8 $_.FullName }) -join "`n"
        $pins = New-Object System.Collections.Generic.List[object]
        [void]$pins.Add(@{ kind = "doc"; name = $fileUnfinished; text = (Clip-Text $body $clipDoc) })
        if ($phys) { [void]$pins.Add(@{ kind = "doc"; name = $filePhys; text = (Clip-Text $phys $clipDoc) }) }
        foreach ($mf in $mandFiles) {
            [void]$pins.Add(@{ kind = "doc"; name = $mf.Name; text = (Clip-Text (Read-Utf8 $mf.FullName) $clipDoc) })
        }
        if ($idx) { [void]$pins.Add(@{ kind = "doc"; name = ($dirDone + "/" + $fileIdxCn); text = (Clip-Text $idx 3000) }) }
        $evDir = Join-Path $folder.FullName $dirEv
        $evCount = 0
        if (Test-Path -LiteralPath $evDir) {
            $evFiles = @(Get-ChildItem -LiteralPath $evDir -File -ErrorAction SilentlyContinue |
                Where-Object { $okExt -contains $_.Extension.ToLowerInvariant() } |
                Sort-Object LastWriteTime -Descending)
            $evCount = $evFiles.Count
            foreach ($ef in ($evFiles | Select-Object -First $maxEv)) {
                [void]$pins.Add(@{
                    kind = (Get-PinKind $ef.Name)
                    name = ($dirEv + "/" + $ef.Name)
                    text = (Clip-Text (Read-Utf8 $ef.FullName) $clipEv)
                })
            }
        }
        $combo = "$body`n$phys`n$mandText"
        $relHead = "## " + (U @(0x7A97, 0x53E3, 0x5173, 0x7CFB, 0x6458, 0x8981))
        $relBlock = ""
        $m = [regex]::Match($combo, [regex]::Escape($relHead) + "(.*?)(?=`n## |\z)", "Singleline")
        if ($m.Success) { $relBlock = $m.Groups[1].Value }
        $relNames = Get-RelNames $relBlock $stateKeys
        $relNameList = New-Object System.Collections.Generic.List[string]
        foreach ($rn in $relNames) { [void]$relNameList.Add([string]$rn) }
        $sealA = U @(0x6B64, 0x8DEF, 0x4E0D, 0x901A)
        $sealB = U @(0x6B62, 0x635F)
        $sealed = ($combo.Contains($sealA) -or $combo.Contains($sealB))
        $epoch = New-Object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)
        $bestT = $folder.CreationTimeUtc
        $ufItem = Get-Item -LiteralPath $unfinished
        if ($ufItem.CreationTimeUtc -lt $bestT) { $bestT = $ufItem.CreationTimeUtc }
        if (Test-Path -LiteralPath $evDir) {
            Get-ChildItem -LiteralPath $evDir -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.CreationTimeUtc -lt $bestT) { $bestT = $_.CreationTimeUtc }
            }
        }
        $discoverUnix = [int64]($bestT.ToUniversalTime() - $epoch).TotalSeconds
        $windows.Add([pscustomobject]@{
            id         = $id
            stateLabel = $st
            cls        = $stateMap[$st]
            relBlock   = $relBlock
            relNames   = $relNameList
            combo      = $combo
            cs         = @(Get-CsTokens $combo)
            sealed     = [bool]$sealed
            evCount    = $evCount
            pins       = $pins
            t          = $discoverUnix
        }) | Out-Null
    }
}
}

if (Test-Path -LiteralPath $DirectLogRoot) {
    $modDirs = @(Get-ChildItem -LiteralPath $DirectLogRoot -Directory -ErrorAction SilentlyContinue)
    foreach ($modDir in $modDirs) {
        $modName = $modDir.Name
        $logPath = Join-Path $modDir.FullName $fileDirectLog
        if (-not (Test-Path -LiteralPath $logPath)) { continue }
        $logBody = Read-Utf8 $logPath
        $logCs = @(Get-CsTokens $logBody)
        $pinName = $zhTong + "/" + $modName + "/" + $fileDirectLog
        $pinText = Clip-Text $logBody $clipDoc
        foreach ($w in $windows) {
            $hit = $false
            if ([string]$w.id -eq $modName) { $hit = $true }
            else {
                foreach ($tok in $logCs) {
                    if (@($w.cs) -contains $tok) { $hit = $true; break }
                }
            }
            if (-not $hit) { continue }
            $dup = $false
            foreach ($p in $w.pins) {
                if ([string]$p.name -eq $pinName) { $dup = $true; break }
            }
            if ($dup) { continue }
            [void]$w.pins.Add(@{ kind = "other"; name = $pinName; text = $pinText })
        }
    }
}

$idsLenDesc = @($windows | ForEach-Object { $_.id } | Sort-Object { -$_.Length }, { $_ })
$byId = @{}
foreach ($w in $windows) { $byId[$w.id] = $w }

foreach ($w in $windows) {
    $resolved = New-Object System.Collections.Generic.List[string]
    $seen = New-Object "System.Collections.Generic.HashSet[string]"
    foreach ($name in $w.relNames) {
        $hit = $null
        if ($idSet.Contains($name)) { $hit = $name }
        else {
            $suffixHits = @($idsLenDesc | Where-Object { $_.EndsWith("-" + $name) -or $_ -eq $name })
            if ($suffixHits.Count -eq 1) { $hit = $suffixHits[0] }
            else {
                foreach ($id in $idsLenDesc) {
                    if ($name.StartsWith($id)) { $hit = $id; break }
                    if ($id.StartsWith($name) -and ($id.Length - $name.Length) -le 8) { $hit = $id; break }
                }
            }
        }
        $use = $(if ($hit) { $hit } else { $name })
        if ($seen.Add($use)) { [void]$resolved.Add($use) }
    }
    $w.relNames = $resolved
}

$edges = New-Object System.Collections.Generic.List[object]
$near = New-Object System.Collections.Generic.List[object]
$mentionedMissing = New-Object "System.Collections.Generic.HashSet[string]"

for ($i = 0; $i -lt $windows.Count; $i++) {
    for ($j = $i + 1; $j -lt $windows.Count; $j++) {
        $a = $windows[$i]
        $b = $windows[$j]
        $parts = New-Object System.Collections.Generic.List[string]
        $score = 0
        $broken = $false
        $inRelA = ($a.relNames -contains $b.id) -or (Test-IdInText $a.relBlock $b.id $idsLenDesc)
        $inRelB = ($b.relNames -contains $a.id) -or (Test-IdInText $b.relBlock $a.id $idsLenDesc)
        if ($inRelA -or $inRelB) { $score += 5; [void]$parts.Add("rel +5") }
        $inBodyA = (-not $inRelA) -and (Test-IdInText $a.combo $b.id $idsLenDesc)
        $inBodyB = (-not $inRelB) -and (Test-IdInText $b.combo $a.id $idsLenDesc)
        if ($inBodyA -or $inBodyB) { $score += 3; [void]$parts.Add("body +3") }
        $share = @($a.cs | Where-Object { $b.cs -contains $_ })
        if ($share.Count -gt 0) { $score += 3; [void]$parts.Add("cs +3") }
        $evHit = $false
        foreach ($p in $a.pins) {
            if ($p.name.StartsWith($dirEv) -and (Test-IdInText $p.text $b.id $idsLenDesc)) { $evHit = $true }
        }
        foreach ($p in $b.pins) {
            if ($p.name.StartsWith($dirEv) -and (Test-IdInText $p.text $a.id $idsLenDesc)) { $evHit = $true }
        }
        if ($evHit) { $score += 2; [void]$parts.Add("evidence +2") }
        if ($a.sealed -or $b.sealed) {
            if ($inRelA -or $inRelB -or $inBodyA -or $inBodyB) {
                $broken = $true
                if ($score -lt 5) { $score = 5 }
                [void]$parts.Add("broken-bridge")
            }
        }
        $obj = @{
            a      = $a.id
            b      = $b.id
            score  = [int]$score
            parts  = @($parts)
            broken = [bool]$broken
        }
        if ($score -ge 3) { $edges.Add($obj) }
        elseif ($score -ge 1) { $near.Add($obj) }
    }
}

foreach ($w in $windows) {
    foreach ($name in $w.relNames) {
        if (-not $idSet.Contains($name)) { [void]$mentionedMissing.Add($name) }
    }
}

function Get-Recommend([string]$id) {
    $w = $byId[$id]
    if ($w.cls -ne "doing") { return $null }
    $cands = @($edges | Where-Object { $_.a -eq $id -or $_.b -eq $id })
    foreach ($e in ($cands | Sort-Object { -$_.score })) {
        $other = if ($e.a -eq $id) { $e.b } else { $e.a }
        $ow = $byId[$other]
        if ($ow.cls -eq "done") {
            $sig = if ($e.parts -and $e.parts.Count -gt 0) { $e.parts[0] } else { "rel" }
            return @{ id = $other; why = "signed-off neighbor ($sig)" }
        }
    }
    if ($cands.Count -gt 0) {
        $e = $cands | Sort-Object { -$_.score } | Select-Object -First 1
        $other = if ($e.a -eq $id) { $e.b } else { $e.a }
        return @{ id = $other; why = "highest-score neighbor" }
    }
    return $null
}

$covPath = Join-Path $repoRoot ".ai-gates\coverage-map.yaml"
$heatPath = Join-Path $repoRoot ".ai-gates\regression-heat.yaml"
$covAvail = Test-Path -LiteralPath $covPath
$heatAvail = Test-Path -LiteralPath $heatPath
$covMods = @{}
$heatMods = @{}
if ($covAvail) {
    $covTxt = Read-Utf8 $covPath
    foreach ($cm in [regex]::Matches($covTxt, '(?m)^\s*-\s*module:\s*"?([^"\r\n]+)"?')) {
        $name = $cm.Groups[1].Value.Trim()
        if ($name.Length -gt 0 -and -not $covMods.ContainsKey($name)) { $covMods[$name] = "module" }
    }
}
if ($heatAvail) {
    $heatTxt = Read-Utf8 $heatPath
    foreach ($hm in [regex]::Matches($heatTxt, '(?ms)-\s*module:\s*"?([^"\r\n]+)"?.*?heat:\s*"?([A-Za-z]+)')) {
        $heatMods[$hm.Groups[1].Value.Trim()] = $hm.Groups[2].Value.Trim()
    }
}

$nodes = New-Object System.Collections.Generic.List[object]
foreach ($w in $windows) {
    $deg = @($edges | Where-Object { $_.a -eq $w.id -or $_.b -eq $w.id }).Count
    $rec = Get-Recommend $w.id
    $preview = $null
    foreach ($p in $w.pins) {
        if ($p.kind -eq "board" -or $p.kind -eq "report") { $preview = $p.name; break }
    }
    if (-not $preview) {
        foreach ($p in $w.pins) {
            if ($p.name.StartsWith($dirEv)) { $preview = $p.name; break }
        }
    }
    $pinAl = New-Object System.Collections.ArrayList
    foreach ($p in $w.pins) {
        [void]$pinAl.Add(@{ kind = [string]$p.kind; name = [string]$p.name; text = [string]$p.text })
    }
    $relOut = New-Object System.Collections.ArrayList
    foreach ($rn in $w.relNames) { [void]$relOut.Add([string]$rn) }
    $node = @{
        id         = [string]$w.id
        state      = [string]$w.cls
        stateLabel = [string]$w.stateLabel
        cls        = [string]$w.cls
        island     = [bool]($deg -eq 0)
        evCount    = [int]$w.evCount
        pins       = $pinAl.ToArray()
    }
    $relCopy = New-Object System.Collections.ArrayList
    foreach ($rn in $relOut) { [void]$relCopy.Add([string]$rn) }
    $node["_discovered"] = [int64]$w.t
    $node["_rels"] = $relCopy
    if ($rec) { $node["rec"] = $rec } else { $node["rec"] = $null }
    if ($preview) { $node["preview"] = [string]$preview } else { $node["preview"] = $null }
    $covHit = $null
    foreach ($mod in @($covMods.Keys)) {
        if (([string]$w.id).IndexOf($mod, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $covHit = [string]$covMods[$mod]; break }
        if (([string]$w.combo).IndexOf($mod, [StringComparison]::Ordinal) -ge 0) { $covHit = [string]$covMods[$mod]; break }
        foreach ($tok in @($w.cs)) {
            if (([string]$tok).IndexOf($mod, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $covHit = [string]$covMods[$mod]; break }
        }
        if ($covHit) { break }
    }
    $heatHit = $null
    foreach ($mod in @($heatMods.Keys)) {
        if (([string]$w.id).IndexOf($mod, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $heatHit = [string]$heatMods[$mod]; break }
        if (([string]$w.combo).IndexOf($mod, [StringComparison]::Ordinal) -ge 0) { $heatHit = [string]$heatMods[$mod]; break }
        foreach ($tok in @($w.cs)) {
            if (([string]$tok).IndexOf($mod, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $heatHit = [string]$heatMods[$mod]; break }
        }
        if ($heatHit) { break }
    }
    $node["coverage"] = $covHit
    $node["heatBand"] = $heatHit
    [void]$nodes.Add($node)
}

Write-Host ("scan windows={0} edges={1} near={2} fog={3}" -f $windows.Count, $edges.Count, $near.Count, $mentionedMissing.Count)

function Convert-NodeJson($item) {
    $unix = 0
    $relArr = New-Object System.Collections.ArrayList
    if ($item.ContainsKey("_discovered")) {
        $unix = [int64]$item["_discovered"]
        $item.Remove("_discovered") | Out-Null
    }
    if ($item.ContainsKey("_rels")) {
        foreach ($r in $item["_rels"]) { [void]$relArr.Add([string]$r) }
        $item.Remove("_rels") | Out-Null
    }
    $j = ConvertTo-Json -InputObject $item -Depth 8 -Compress
    $relParts = New-Object System.Collections.Generic.List[string]
    foreach ($r in $relArr) {
        [void]$relParts.Add((ConvertTo-Json -InputObject ([string]$r) -Compress))
    }
    $relJson = if ($relParts.Count -eq 0) { "[]" } else { "[" + ($relParts -join ",") + "]" }
    if ($j.EndsWith("}")) { $j = $j.Substring(0, $j.Length - 1) }
    return ($j + ",`"discovered`":$unix,`"rels`":$relJson}")
}

function ConvertTo-JsArrayJson($items) {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($null -ne $items) {
        foreach ($item in $items) {
            [void]$parts.Add((ConvertTo-Json -InputObject $item -Depth 8 -Compress))
        }
    }
    if ($parts.Count -eq 0) { return "[]" }
    return "[" + ($parts -join ",") + "]"
}

function ConvertTo-NodeArrayJson($items) {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($null -ne $items) {
        foreach ($item in $items) {
            [void]$parts.Add((Convert-NodeJson $item))
        }
    }
    if ($parts.Count -eq 0) { return "[]" }
    return "[" + ($parts -join ",") + "]"
}

$edgePlain = New-Object System.Collections.ArrayList
foreach ($e in $edges) {
    $pArr = New-Object System.Collections.ArrayList
    if ($null -ne $e.parts) { foreach ($p in $e.parts) { [void]$pArr.Add([string]$p) } }
    [void]$edgePlain.Add(@{ a = [string]$e.a; b = [string]$e.b; score = [int]$e.score; parts = $pArr.ToArray(); broken = [bool]$e.broken })
}
$nearPlain = New-Object System.Collections.ArrayList
foreach ($e in $near) {
    $pArr = New-Object System.Collections.ArrayList
    if ($null -ne $e.parts) { foreach ($p in $e.parts) { [void]$pArr.Add([string]$p) } }
    [void]$nearPlain.Add(@{ a = [string]$e.a; b = [string]$e.b; score = [int]$e.score; parts = $pArr.ToArray(); broken = [bool]$e.broken })
}
$nodePlain = New-Object System.Collections.ArrayList
foreach ($n in $nodes) {
    $pinOut = New-Object System.Collections.ArrayList
    if ($null -ne $n.pins) {
        foreach ($p in $n.pins) {
            [void]$pinOut.Add(@{ kind = [string]$p.kind; name = [string]$p.name; text = [string]$p.text })
        }
    }
    $recOut = $null
    if ($n.rec) { $recOut = @{ id = [string]$n.rec.id; why = [string]$n.rec.why } }
    $plain = @{
        id         = [string]$n.id
        state      = [string]$n.state
        stateLabel = [string]$n.stateLabel
        cls        = [string]$n.cls
        island     = [bool]$n.island
        rec        = $recOut
        evCount    = [int]$n.evCount
        preview    = $(if ($n.preview) { [string]$n.preview } else { $null })
        pins       = $pinOut.ToArray()
    }
    if ($n.ContainsKey("_discovered")) { $plain["_discovered"] = $n["_discovered"] }
    if ($n.ContainsKey("_rels")) { $plain["_rels"] = $n["_rels"] }
    if ($n.ContainsKey("coverage")) { $plain["coverage"] = $n["coverage"] }
    if ($n.ContainsKey("heatBand")) { $plain["heatBand"] = $n["heatBand"] }
    [void]$nodePlain.Add($plain)
}

$genJson = ConvertTo-Json -InputObject (Get-Date -Format "yyyy-MM-dd HH:mm") -Compress
$rootJson = ConvertTo-Json -InputObject ([string]$scanRoots[0]) -Compress
$rootList = New-Object System.Collections.ArrayList
foreach ($sr in $scanRoots) { [void]$rootList.Add([string]$sr) }
$rootsJson = ConvertTo-JsArrayJson $rootList
$covSrcJson = if ($covAvail) { ConvertTo-Json -InputObject ".ai-gates/coverage-map.yaml" -Compress } else { "null" }
$heatSrcJson = if ($heatAvail) { ConvertTo-Json -InputObject ".ai-gates/regression-heat.yaml" -Compress } else { "null" }
$json = "{" +
    '"generated":' + $genJson + "," +
    '"root":' + $rootJson + "," +
    '"roots":' + $rootsJson + "," +
    '"coverageSrc":' + $covSrcJson + "," +
    '"heatSrc":' + $heatSrcJson + "," +
    '"nodes":' + (ConvertTo-NodeArrayJson $nodePlain) + "," +
    '"edges":' + (ConvertTo-JsArrayJson $edgePlain) + "," +
    '"near":' + (ConvertTo-JsArrayJson $nearPlain) + "," +
    '"fog":' + (ConvertTo-JsArrayJson $mentionedMissing) +
    "}"
$json = $json.Replace("</", "<\/")

$tplPath = Join-Path $PSScriptRoot "fog-map.template.html"
$tpl = [IO.File]::ReadAllText($tplPath, $utf8)
$html = $tpl.Replace("__DATA__", $json)
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
[IO.File]::WriteAllText($OutFile, $html, $utf8Bom)

$jsonOutFile = [IO.Path]::ChangeExtension($OutFile, ".json")

function Convert-LeanNodeJson($item) {
    $idJ = ConvertTo-Json -InputObject ([string]$item.id) -Compress
    $stJ = ConvertTo-Json -InputObject ([string]$item.state) -Compress
    $lbJ = ConvertTo-Json -InputObject ([string]$item.stateLabel) -Compress
    $isJ = if ($item.island) { "true" } else { "false" }
    $recJ = if ($null -eq $item.rec) { "null" } else { ConvertTo-Json -InputObject $item.rec -Compress -Depth 5 }
    $nbJ = ConvertTo-JsArrayJson $item.neighbors
    $evJ = [int]$item.evCount
    return ("{0}`"id`":{1},`"state`":{2},`"stateLabel`":{3},`"island`":{4},`"rec`":{5},`"neighbors`":{6},`"evCount`":{7}{8}" -f "{", $idJ, $stJ, $lbJ, $isJ, $recJ, $nbJ, $evJ, "}")
}

function ConvertTo-LeanNodeArrayJson($items) {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($null -ne $items) {
        foreach ($item in $items) {
            [void]$parts.Add((Convert-LeanNodeJson $item))
        }
    }
    if ($parts.Count -eq 0) { return "[]" }
    return "[" + ($parts -join ",") + "]"
}

function Test-HasJsonKey($obj, [string]$key) {
    if ($null -eq $obj) { return $false }
    return $null -ne $obj.PSObject.Properties[$key]
}

$leanNodes = New-Object System.Collections.ArrayList
foreach ($n in $nodes) {
    $nbList = New-Object System.Collections.ArrayList
    foreach ($e in $edges) {
        $other = $null
        if ([string]$e.a -eq [string]$n.id) { $other = $e.b }
        elseif ([string]$e.b -eq [string]$n.id) { $other = $e.a }
        if ($null -eq $other) { continue }
        $sig = "rel"
        if ($null -ne $e.parts -and @($e.parts).Count -gt 0) { $sig = [string](@($e.parts)[0]) }
        [void]$nbList.Add(@{
            id     = [string]$other
            score  = [int]$e.score
            signal = $sig
            broken = [bool]$e.broken
        })
    }
    $recOut = $null
    if ($n.rec) { $recOut = @{ id = [string]$n.rec.id; why = [string]$n.rec.why } }
    [void]$leanNodes.Add(@{
        id         = [string]$n.id
        state      = [string]$n.state
        stateLabel = [string]$n.stateLabel
        island     = [bool]$n.island
        rec        = $recOut
        neighbors  = $nbList.ToArray()
        evCount    = [int]$n.evCount
    })
}

$fogPlain = New-Object System.Collections.ArrayList
foreach ($f in $mentionedMissing) { [void]$fogPlain.Add([string]$f) }

$leanJson = "{" +
    '"generated":' + $genJson + "," +
    '"root":' + $rootJson + "," +
    '"roots":' + $rootsJson + "," +
    '"nodes":' + (ConvertTo-LeanNodeArrayJson $leanNodes) + "," +
    '"edges":' + (ConvertTo-JsArrayJson $edgePlain) + "," +
    '"fog":' + (ConvertTo-JsArrayJson $fogPlain) +
    "}"
[IO.File]::WriteAllText($jsonOutFile, $leanJson, $utf8)

if (-not (Test-Path -LiteralPath $jsonOutFile)) {
    Write-Error ("lean json missing file: {0}" -f $jsonOutFile)
}
$parsedLean = ConvertFrom-Json (Read-Utf8 $jsonOutFile)
if (-not (Test-HasJsonKey $parsedLean "generated")) { Write-Error "lean json missing key: generated" }
if (-not (Test-HasJsonKey $parsedLean "root")) { Write-Error "lean json missing key: root" }
if (-not (Test-HasJsonKey $parsedLean "roots")) { Write-Error "lean json missing key: roots" }
if (-not (Test-HasJsonKey $parsedLean "nodes")) { Write-Error "lean json missing key: nodes" }
if (-not (Test-HasJsonKey $parsedLean "fog")) { Write-Error "lean json missing key: fog" }
$hasEdgesKey = Test-HasJsonKey $parsedLean "edges"
$hasAnyNeighbors = $false
foreach ($pn in @($parsedLean.nodes)) {
    if ($null -eq $pn) { continue }
    if (-not (Test-HasJsonKey $pn "id")) { Write-Error "lean json node missing key: id" }
    if (-not (Test-HasJsonKey $pn "state")) { Write-Error "lean json node missing key: state" }
    if (-not (Test-HasJsonKey $pn "rec")) { Write-Error ("lean json node missing key: rec id={0}" -f $pn.id) }
    if (Test-HasJsonKey $pn "pins") { Write-Error ("lean json node has forbidden pins id={0}" -f $pn.id) }
    if (Test-HasJsonKey $pn "neighbors") { $hasAnyNeighbors = $true }
}
if (-not $hasEdgesKey -and -not $hasAnyNeighbors) {
    Write-Error "lean json missing edges and neighbors"
}

Write-Host ("windows={0} edges={1} near={2} fog={3} json={4}" -f $nodes.Count, $edges.Count, $near.Count, $mentionedMissing.Count, $jsonOutFile)
Write-Host ("wrote {0}" -f $OutFile)
