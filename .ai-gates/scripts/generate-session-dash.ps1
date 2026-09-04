# Session dashboard static HTML. ASCII-only source (Windows PS 5 parser).
# Chinese via U(). Tail-read large hooks-log files (MAX_BYTES / MAX_TAIL_LINES).
# Default OutFile = .ai-gates/verify/session-dash.html
# No network calls. Not a billing page.
param(
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true

$MAX_BYTES = 1048576
$MAX_TAIL_LINES = 4096
$MAX_PREVIEW_LINES = 30

function U([int[]]$codes) {
    return (-join ($codes | ForEach-Object { [char]$_ }))
}

function Clip-Text([string]$s, [int]$n) {
    if ($null -eq $s) { return "" }
    if ($s.Length -le $n) { return $s }
    return $s.Substring(0, $n) + "`n...(truncated)"
}


# Disk may store path as UTF-8-as-GBK mojibake then UTF-8 again.
# Only repair display at preview time (never rewrite large logs).
function Repair-Mojibake([string]$s) {
    if ($null -eq $s -or $s.Length -eq 0) { return $s }
    $mk1 = [char]0x9356  # mojibake marker 1
    $mk2 = [char]0x9358  # mojibake marker 2
    $mk3 = [char]0x93B5  # mojibake marker 3
    $mk4 = [char]0x93C8  # mojibake marker 4
    $looksBad = ($s.IndexOf([string]$mk1, [StringComparison]::Ordinal) -ge 0) -or ($s.IndexOf([string]$mk2, [StringComparison]::Ordinal) -ge 0) -or ($s.IndexOf([string]$mk3, [StringComparison]::Ordinal) -ge 0) -or ($s.IndexOf([string]$mk4, [StringComparison]::Ordinal) -ge 0)
    if (-not $looksBad) { return $s }
    try {
        $enc936 = [System.Text.Encoding]::GetEncoding(936)
        $fixed = $utf8.GetString($enc936.GetBytes($s))
    } catch {
        return $s
    }
    $okDoc = U @(0x6587, 0x6863)
    $okPress = U @(0x538B, 0x529B)
    $okExec = U @(0x6267, 0x884C)
    $okPend = U @(0x672A, 0x5B8C, 0x6210)
    $adopt = ($fixed.IndexOf($okDoc, [StringComparison]::Ordinal) -ge 0) -or ($fixed.IndexOf($okPress, [StringComparison]::Ordinal) -ge 0) -or ($fixed.IndexOf($okExec, [StringComparison]::Ordinal) -ge 0) -or ($fixed.IndexOf($okPend, [StringComparison]::Ordinal) -ge 0)
    if ($adopt) {
        # Whole-line GBK round-trip destroys already-correct UTF-8 CJK (introduces U+07B7).
        $bad = [char]0x07B7
        $hadBad = ($s.IndexOf([string]$bad, [StringComparison]::Ordinal) -ge 0)
        $gotBad = ($fixed.IndexOf([string]$bad, [StringComparison]::Ordinal) -ge 0)
        if ($gotBad -and -not $hadBad) { return $s }
        return $fixed
    }
    return $s
}
function Html-Escape([string]$s) {
    if ($null -eq $s) { return "" }
    return (($s -replace "&", "&amp;") -replace "<", "&lt;") -replace ">", "&gt;"
}

$repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path }
$repoRoot = $repoRoot.Trim()

if (-not $OutFile) {
    $OutFile = Join-Path $repoRoot ".ai-gates\verify\session-dash.html"
}

$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
$pathAudit = Join-Path $logDir "write-audit.log"
$pathChangelog = Join-Path $logDir "mark-changelog-write.log"
$pathPmGate = Join-Path $logDir "pm-gate.json"

$zhMissing = U @(0x7F3A, 0x6587, 0x4EF6)
$zhNotBill = U @(0x4E0D, 0x662F, 0x8D26, 0x5355)
$zhTitle = (U @(0x4F1A, 0x8BDD)) + (U @(0x76D1, 0x63A7))
$zhVol = U @(0x4F53, 0x79EF)
$zhBytes = U @(0x5B57, 0x8282)
$zhLines = U @(0x6761, 0x6570)
$zhBanTokenBill = (U @(0x7981, 0x6B62)) + " Token " + (U @(0x8BA1, 0x8D39))
$zhNotBillToken = $zhNotBill + " Token"
$zhWriteCount = (U @(0x5199, 0x5165)) + (U @(0x6B21, 0x6570))
$zhSessionCount = "session " + (U @(0x6570))
$zhScanBytes = (U @(0x626B, 0x63CF)) + $zhBytes
$zhWaterfall = (U @(0x65F6, 0x95F4)) + (U @(0x6761))
$zhToolShare = (U @(0x5DE5, 0x5177)) + (U @(0x5360, 0x6BD4))
$zhRawLog = (U @(0x539F, 0x6587)) + " log"
$zhAudit = "write-audit.log"
$zhCl = "mark-changelog-write.log"
$zhPm = "pm-gate.json"
$zhNoteObj = "pm-gate.json " + (U @(0x662F, 0x5BF9, 0x8C61, 0x4E0D, 0x662F, 0x65F6, 0x95F4, 0x7EBF))
$zhTool = U @(0x5DE5, 0x5177)
$zhCount = U @(0x6B21, 0x6570)

function Score-DecodedLine([string]$t) {
    $cjk = 0
    $fffd = 0
    if ($null -eq $t -or $t.Length -eq 0) {
        return @{ score = 0; fffd = 0 }
    }
    foreach ($ch in $t.ToCharArray()) {
        $c = [int][char]$ch
        if ($c -ge 0x4E00 -and $c -le 0x9FFF) { $cjk++ }
        elseif ($c -eq 0xFFFD) { $fffd++ }
    }
    return @{ score = ($cjk - (8 * $fffd)); fffd = $fffd }
}

function Read-TailText([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ ok = $false; text = ""; bytes = 0; lines = 0; fileBytes = 0 }
    }
    $fi = Get-Item -LiteralPath $path
    $fileBytes = [int64]$fi.Length
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $take = [int64]$MAX_BYTES
        if ($fileBytes -lt $take) { $take = $fileBytes }
        if ($take -gt 0) {
            [void]$fs.Seek(-$take, [System.IO.SeekOrigin]::End)
        }
        $buf = New-Object byte[] $take
        $read = 0
        while ($read -lt $take) {
            $n = $fs.Read($buf, $read, [int]($take - $read))
            if ($n -le 0) { break }
            $read += $n
        }
    } finally {
        $fs.Close()
    }
    # Per-line decode: mixed UTF-8 paths + GBK exception text in same file.
    # Split on 0x0A (strip trailing 0x0D); score CJK - 8*FFFD; tie keeps UTF-8.
    $enc936 = [System.Text.Encoding]::GetEncoding(936)
    $decoded = New-Object System.Collections.Generic.List[string]
    $segStart = 0
    for ($i = 0; $i -lt $read; $i++) {
        if ($buf[$i] -ne 0x0A) { continue }
        $len = $i - $segStart
        if ($len -gt 0 -and $buf[$segStart + $len - 1] -eq 0x0D) { $len-- }
        if ($len -le 0) {
            [void]$decoded.Add("")
        } else {
            $t8 = $utf8.GetString($buf, $segStart, $len)
            $t9 = $enc936.GetString($buf, $segStart, $len)
            $s8 = Score-DecodedLine $t8
            $s9 = Score-DecodedLine $t9
            $pick = $t8
            # Well-formed UTF-8 (no FFFD): keep UTF-8 - GBK misread inflates CJK.
            # Only compare scores when UTF-8 shows replacement chars (likely GBK bytes).
            if ($s8.fffd -gt 0 -and $s9.score -gt $s8.score) { $pick = $t9 }
            [void]$decoded.Add((Repair-Mojibake $pick))
        }
        $segStart = $i + 1
    }
    if ($segStart -lt $read) {
        $len = $read - $segStart
        if ($len -gt 0 -and $buf[$segStart + $len - 1] -eq 0x0D) { $len-- }
        if ($len -le 0) {
            [void]$decoded.Add("")
        } else {
            $t8 = $utf8.GetString($buf, $segStart, $len)
            $t9 = $enc936.GetString($buf, $segStart, $len)
            $s8 = Score-DecodedLine $t8
            $s9 = Score-DecodedLine $t9
            $pick = $t8
            # Well-formed UTF-8 (no FFFD): keep UTF-8 - GBK misread inflates CJK.
            # Only compare scores when UTF-8 shows replacement chars (likely GBK bytes).
            if ($s8.fffd -gt 0 -and $s9.score -gt $s8.score) { $pick = $t9 }
            [void]$decoded.Add((Repair-Mojibake $pick))
        }
    } elseif ($read -gt 0 -and $buf[$read - 1] -eq 0x0A) {
        [void]$decoded.Add("")
    }
    # Seek mid-file: first segment may be a partial line - drop it.
    if ($fileBytes -gt $MAX_BYTES -and $decoded.Count -gt 0) {
        $decoded.RemoveAt(0)
    }
    $allLines = $decoded
    if ($allLines.Count -gt $MAX_TAIL_LINES) {
        $start = $allLines.Count - $MAX_TAIL_LINES
        $slice = New-Object System.Collections.Generic.List[string]
        for ($j = $start; $j -lt $allLines.Count; $j++) {
            [void]$slice.Add($allLines[$j])
        }
        $allLines = $slice
    }
    $text = ($allLines -join "`n")
    $lineCount = @($allLines | Where-Object { $_ -ne "" }).Count
    return @{
        ok        = $true
        text      = $text
        bytes     = $read
        lines     = $lineCount
        fileBytes = $fileBytes
    }
}
function Parse-AuditStats([string]$text) {
    $writeCount = 0
    $sessions = New-Object "System.Collections.Generic.HashSet[string]"
    $hourMap = @{}
    $toolMap = @{}
    if (-not $text) {
        return @{
            writeCount = 0
            sessionCount = 0
            hourCounts = @{}
            toolCounts = @{}
        }
    }
    foreach ($raw in ($text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $tool = "unknown"
        $tm = [regex]::Match($raw, 'tool=([^\s|]+)')
        if ($tm.Success) { $tool = $tm.Groups[1].Value }
        if (-not $toolMap.ContainsKey($tool)) { $toolMap[$tool] = 0 }
        $toolMap[$tool] = [int]$toolMap[$tool] + 1

        $sm = [regex]::Match($raw, 'session=([^\s|]+)')
        if ($sm.Success) {
            $sid = $sm.Groups[1].Value
            if ($sid -and $sid -ne "unknown") { [void]$sessions.Add($sid) }
        }

        if ($tool -eq "Write") {
            $writeCount++
            $hm = [regex]::Match($raw, '^(\d{4}-\d{2}-\d{2}\s+\d{2})')
            $hourKey = "unknown"
            if ($hm.Success) { $hourKey = $hm.Groups[1].Value }
            if (-not $hourMap.ContainsKey($hourKey)) { $hourMap[$hourKey] = 0 }
            $hourMap[$hourKey] = [int]$hourMap[$hourKey] + 1
        }
    }
    return @{
        writeCount = $writeCount
        sessionCount = $sessions.Count
        hourCounts = $hourMap
        toolCounts = $toolMap
    }
}

function Format-PmGateSummary([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ ok = $false; html = ("<p>" + (Html-Escape $zhMissing) + "</p>"); bytes = 0 }
    }
    $raw = [System.IO.File]::ReadAllText($path, $utf8)
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<p>")
    [void]$sb.Append((Html-Escape $zhNoteObj))
    [void]$sb.Append("</p><ul>")
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        $shown = 0
        foreach ($name in @("session_id", "marked_at_ms", "sourceField", "action", "step", "window")) {
            $p = $obj.PSObject.Properties[$name]
            if ($null -eq $p) { continue }
            $summary = Clip-Text ([string]$p.Value) 80
            [void]$sb.Append("<li><code>")
            [void]$sb.Append((Html-Escape $name))
            [void]$sb.Append("</code> = ")
            [void]$sb.Append((Html-Escape $summary))
            [void]$sb.Append("</li>")
            $shown++
        }
        if ($shown -eq 0) {
            foreach ($p in @($obj.PSObject.Properties | Select-Object -First 6)) {
                $val = $p.Value
                $summary = ""
                if ($null -eq $val) {
                    $summary = "null"
                } elseif ($val -is [string] -or $val -is [ValueType]) {
                    $summary = Clip-Text ([string]$val) 80
                } else {
                    $summary = "{...}"
                }
                [void]$sb.Append("<li><code>")
                [void]$sb.Append((Html-Escape ([string]$p.Name)))
                [void]$sb.Append("</code> = ")
                [void]$sb.Append((Html-Escape $summary))
                [void]$sb.Append("</li>")
            }
        }
    } catch {
        [void]$sb.Append("<li>")
        [void]$sb.Append((Html-Escape (Clip-Text $raw 200)))
        [void]$sb.Append("</li>")
    }
    [void]$sb.Append("</ul>")
    return @{ ok = $true; html = $sb.ToString(); bytes = $bytes }
}

function Render-DetailsPreview([string]$title, $tail, [string[]]$previewLines) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<details><summary>")
    [void]$sb.Append((Html-Escape $title))
    [void]$sb.Append("</summary>")
    if (-not $tail.ok) {
        [void]$sb.Append("<p>")
        [void]$sb.Append((Html-Escape $zhMissing))
        [void]$sb.Append("</p></details>")
        return $sb.ToString()
    }
    $meta = "{0}: {1} {2} | {3}: {4} | file {0}: {5} {2}" -f $zhVol, $tail.bytes, $zhBytes, $zhLines, $tail.lines, $tail.fileBytes
    [void]$sb.Append("<p class=""meta"">")
    [void]$sb.Append((Html-Escape $meta))
    [void]$sb.Append("</p><pre>")
    $n = 0
    foreach ($ln in $previewLines) {
        if ($n -ge $MAX_PREVIEW_LINES) { break }
        [void]$sb.Append((Html-Escape (Clip-Text (Repair-Mojibake $ln) 200)))
        [void]$sb.Append("`n")
        $n++
    }
    if ($previewLines.Count -gt $MAX_PREVIEW_LINES) {
        [void]$sb.Append("...(truncated)`n")
    }
    [void]$sb.Append("</pre></details>")
    return $sb.ToString()
}

$auditTail = Read-TailText $pathAudit
$clTail = Read-TailText $pathChangelog
$stats = Parse-AuditStats $auditTail.text
$scanBytes = [int64]$auditTail.bytes + [int64]$clTail.bytes
$pm = Format-PmGateSummary $pathPmGate

$auditPreview = @()
if ($auditTail.ok -and $auditTail.text) {
    $auditPreview = @($auditTail.text -split "`r?`n" | Where-Object { $_ -ne "" } | Select-Object -Last $MAX_PREVIEW_LINES)
}
$clPreview = @()
if ($clTail.ok -and $clTail.text) {
    $clPreview = @($clTail.text -split "`r?`n" | Where-Object { $_ -ne "" } | Select-Object -Last $MAX_PREVIEW_LINES)
}

$hourMax = 1
foreach ($k in @($stats.hourCounts.Keys)) {
    $v = [int]$stats.hourCounts[$k]
    if ($v -gt $hourMax) { $hourMax = $v }
}

$genAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$htmlParts = New-Object System.Text.StringBuilder
[void]$htmlParts.Append(@"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<title>$zhTitle</title>
<style>
body{font-family:Segoe UI,Meiryo,sans-serif;margin:24px;background:#f7f7f5;color:#222}
h1{font-size:1.6rem;margin:0 0 8px}
.banner{padding:12px 14px;background:#fff3cd;border:1px solid #e0c36a;margin:12px 0}
.meta{color:#555;font-size:0.9rem}
.kpis{display:flex;flex-wrap:wrap;gap:12px;margin:16px 0}
.kpi{flex:1 1 140px;background:#fff;border:1px solid #ddd;padding:14px 16px;min-width:120px}
.kpi .n{font-size:2rem;font-weight:700;line-height:1.2}
.kpi .l{color:#555;font-size:0.85rem;margin-top:4px}
section{margin:18px 0;padding:12px;background:#fff;border:1px solid #ddd}
.bar-row{display:flex;align-items:center;gap:8px;margin:6px 0}
.bar-row .lbl{width:130px;font-size:12px;color:#444;flex-shrink:0}
.bar{height:14px;background:#4a90d9;border-radius:2px;min-width:2px}
table.share{border-collapse:collapse;font-size:13px}
table.share th,table.share td{border:1px solid #ddd;padding:4px 8px;text-align:left}
details{margin:10px 0;padding:8px;background:#fafafa;border:1px solid #e0e0e0}
details summary{cursor:pointer;font-weight:600}
pre{white-space:pre-wrap;word-break:break-all;font-size:12px;max-height:240px;overflow:auto;margin:8px 0 0}
code{font-size:12px}
</style>
</head>
<body>
"@)
[void]$htmlParts.Append("<h1>")
[void]$htmlParts.Append((Html-Escape $zhTitle))
[void]$htmlParts.Append("</h1>")
[void]$htmlParts.Append("<div class=""banner""><strong>")
[void]$htmlParts.Append((Html-Escape $zhNotBill))
[void]$htmlParts.Append("</strong> - ")
[void]$htmlParts.Append((Html-Escape $zhBanTokenBill))
[void]$htmlParts.Append(" / ")
[void]$htmlParts.Append((Html-Escape $zhNotBillToken))
[void]$htmlParts.Append("</div>")
[void]$htmlParts.Append("<p class=""meta"">generated ")
[void]$htmlParts.Append((Html-Escape $genAt))
[void]$htmlParts.Append(" | MAX_BYTES=")
[void]$htmlParts.Append("$MAX_BYTES")
[void]$htmlParts.Append(" MAX_TAIL_LINES=")
[void]$htmlParts.Append("$MAX_TAIL_LINES")
[void]$htmlParts.Append("</p>")

[void]$htmlParts.Append("<div class=""kpis"">")
[void]$htmlParts.Append("<div class=""kpi""><div class=""n"">")
[void]$htmlParts.Append("$($stats.writeCount)")
[void]$htmlParts.Append("</div><div class=""l"">")
[void]$htmlParts.Append((Html-Escape $zhWriteCount))
[void]$htmlParts.Append("</div></div>")
[void]$htmlParts.Append("<div class=""kpi""><div class=""n"">")
[void]$htmlParts.Append("$($stats.sessionCount)")
[void]$htmlParts.Append("</div><div class=""l"">")
[void]$htmlParts.Append((Html-Escape $zhSessionCount))
[void]$htmlParts.Append("</div></div>")
[void]$htmlParts.Append("<div class=""kpi""><div class=""n"">")
[void]$htmlParts.Append("$scanBytes")
[void]$htmlParts.Append("</div><div class=""l"">")
[void]$htmlParts.Append((Html-Escape $zhScanBytes))
[void]$htmlParts.Append("</div></div>")
[void]$htmlParts.Append("</div>")

[void]$htmlParts.Append("<section><h2>")
[void]$htmlParts.Append((Html-Escape $zhWaterfall))
[void]$htmlParts.Append("</h2>")
$hourKeys = @($stats.hourCounts.Keys | Sort-Object)
if ($hourKeys.Count -eq 0) {
    [void]$htmlParts.Append("<p class=""meta"">0 Write</p>")
} else {
    foreach ($hk in $hourKeys) {
        $cnt = [int]$stats.hourCounts[$hk]
        $pct = [Math]::Max(2, [int](100.0 * $cnt / $hourMax))
        [void]$htmlParts.Append("<div class=""bar-row""><span class=""lbl"">")
        [void]$htmlParts.Append((Html-Escape $hk))
        [void]$htmlParts.Append("</span><div class=""bar"" style=""width:")
        [void]$htmlParts.Append("$pct")
        [void]$htmlParts.Append("%""></div><span class=""meta"">")
        [void]$htmlParts.Append("$cnt")
        [void]$htmlParts.Append("</span></div>")
    }
}
[void]$htmlParts.Append("</section>")

[void]$htmlParts.Append("<section><h2>")
[void]$htmlParts.Append((Html-Escape $zhToolShare))
[void]$htmlParts.Append("</h2><table class=""share""><tr><th>")
[void]$htmlParts.Append((Html-Escape $zhTool))
[void]$htmlParts.Append("</th><th>")
[void]$htmlParts.Append((Html-Escape $zhCount))
[void]$htmlParts.Append("</th></tr>")
$toolKeys = @($stats.toolCounts.Keys | Sort-Object)
foreach ($tk in $toolKeys) {
    [void]$htmlParts.Append("<tr><td>")
    [void]$htmlParts.Append((Html-Escape $tk))
    [void]$htmlParts.Append("</td><td>")
    [void]$htmlParts.Append("$($stats.toolCounts[$tk])")
    [void]$htmlParts.Append("</td></tr>")
}
[void]$htmlParts.Append("</table></section>")

[void]$htmlParts.Append("<section><h2>")
[void]$htmlParts.Append((Html-Escape $zhPm))
[void]$htmlParts.Append("</h2>")
if ($pm.ok) {
    $pmMeta = "{0}: {1} {2}" -f $zhVol, $pm.bytes, $zhBytes
    [void]$htmlParts.Append("<p class=""meta"">")
    [void]$htmlParts.Append((Html-Escape $pmMeta))
    [void]$htmlParts.Append("</p>")
}
[void]$htmlParts.Append($pm.html)
[void]$htmlParts.Append("</section>")

[void]$htmlParts.Append((Render-DetailsPreview ($zhRawLog + " - " + $zhAudit) $auditTail $auditPreview))
[void]$htmlParts.Append((Render-DetailsPreview ($zhRawLog + " - " + $zhCl) $clTail $clPreview))

[void]$htmlParts.Append("</body></html>`n")

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
[System.IO.File]::WriteAllText($OutFile, $htmlParts.ToString(), $utf8Bom)
Write-Host ("wrote {0}" -f $OutFile)