# File-heat helpers. ASCII-only source (Windows PS 5 parser).
# ai_pass subtracts 1 from each file (not below 0) and remembers the subtracted amount.
# human_fail adds that amount back, then adds 1. human_pass keeps the count and clears the memory.

function U-Heat([int[]]$codes) {
    return (-join ($codes | ForEach-Object { [char]$_ }))
}

function Get-ModuleFromDoc {
    param([string]$Doc)
    $pressure = U-Heat @(0x538B, 0x529B, 0x7CFB, 0x7EDF)
    $dissolve = U-Heat @(0x6EB6, 0x89E3)
    $reaction = U-Heat @(0x53CD, 0x5E94)
    if ($Doc -match $pressure) { return 'PressureManager' }
    if ($Doc -match $dissolve) { return 'DissolveManager' }
    if ($Doc -match $reaction) { return 'Reaction' }
    return 'other'
}

function Convert-HeatPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return ($Path.Trim() -replace '\\', '/')
}

function Read-RegressionHeatDocument {
    param([string]$Path)
    $doc = @{
        Entries = New-Object System.Collections.Generic.List[object]
        Files   = New-Object System.Collections.Generic.List[object]
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $doc }
    $section = ''
    $cur = $null
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $trim = $line.Trim()
        if ($trim -eq 'entries:') { if ($cur) { [void]$doc[$section].Add($cur) }; $section = 'Entries'; $cur = $null; continue }
        if ($trim -eq 'files:') { if ($cur) { [void]$doc[$section].Add($cur) }; $section = 'Files'; $cur = $null; continue }
        if ($section -eq 'Entries' -and $trim -match '^-\s*module:\s*(.+)$') {
            if ($cur) { $doc.Entries.Add($cur) }
            $cur = [ordered]@{ module = $Matches[1].Trim(); last_fail_ts = ''; fail_count = 0; max_stop_count = 0; heat = 'low' }
        } elseif ($section -eq 'Files' -and $trim -match '^-\s*path:\s*(.+)$') {
            if ($cur) { $doc.Files.Add($cur) }
            $cur = [ordered]@{ path = (Convert-HeatPath $Matches[1]); fail_count = 0; last_result = ''; last_updated = ''; unconfirmed_delta = 0; last_fail_ts = '' }
        } elseif ($cur -and $section -eq 'Entries' -and $trim -match '^last_fail_ts:\s*(.*)$') { $cur.last_fail_ts = $Matches[1].Trim() }
        elseif ($cur -and $section -eq 'Entries' -and $trim -match '^fail_count:\s*(\d+)') { $cur.fail_count = [int]$Matches[1] }
        elseif ($cur -and $section -eq 'Entries' -and $trim -match '^max_stop_count:\s*(\d+)') { $cur.max_stop_count = [int]$Matches[1] }
        elseif ($cur -and $section -eq 'Entries' -and $trim -match '^heat:\s*(.+)$') { $cur.heat = $Matches[1].Trim() }
        elseif ($cur -and $section -eq 'Files' -and $trim -match '^fail_count:\s*(\d+)') { $cur.fail_count = [int]$Matches[1] }
        elseif ($cur -and $section -eq 'Files' -and $trim -match '^last_result:\s*(.*)$') { $cur.last_result = $Matches[1].Trim() }
        elseif ($cur -and $section -eq 'Files' -and $trim -match '^last_updated:\s*(.*)$') { $cur.last_updated = $Matches[1].Trim() }
        elseif ($cur -and $section -eq 'Files' -and $trim -match '^unconfirmed_delta:\s*(\d+)') { $cur.unconfirmed_delta = [int]$Matches[1] }
        elseif ($cur -and $section -eq 'Files' -and $trim -match '^last_fail_ts:\s*(.*)$') { $cur.last_fail_ts = $Matches[1].Trim() }
    }
    if ($cur) { [void]$doc[$section].Add($cur) }
    return $doc
}

function Write-RegressionHeatDocument {
    param($Path, $Entries, $Files)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# regression heat (generated). Do not edit by hand.")
    [void]$sb.AppendLine('version: 1')
    [void]$sb.AppendLine('entries:')
    foreach ($e in $Entries) {
        [void]$sb.AppendLine("  - module: $($e.module)")
        [void]$sb.AppendLine("    last_fail_ts: $($e.last_fail_ts)")
        [void]$sb.AppendLine("    fail_count: $($e.fail_count)")
        [void]$sb.AppendLine("    max_stop_count: $($e.max_stop_count)")
        [void]$sb.AppendLine("    heat: $($e.heat)")
    }
    [void]$sb.AppendLine('files:')
    foreach ($f in $Files) {
        [void]$sb.AppendLine("  - path: $($f.path)")
        [void]$sb.AppendLine("    fail_count: $($f.fail_count)")
        [void]$sb.AppendLine("    last_result: $($f.last_result)")
        [void]$sb.AppendLine("    last_updated: $($f.last_updated)")
        [void]$sb.AppendLine("    unconfirmed_delta: $($f.unconfirmed_delta)")
        [void]$sb.AppendLine("    last_fail_ts: $($f.last_fail_ts)")
    }
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
}

function Get-OrAddFileHeat {
    param($Files, [string]$Path)
    $key = Convert-HeatPath $Path
    foreach ($f in $Files) {
        if ($f.path -eq $key) { return $f }
    }
    $created = [ordered]@{ path = $key; fail_count = 0; last_result = ''; last_updated = ''; unconfirmed_delta = 0; last_fail_ts = '' }
    [void]$Files.Add($created)
    return $created
}

function Apply-FileHeatEvent {
    param($Files, [string]$Event, [string[]]$Paths, [string]$Day)
    foreach ($raw in @($Paths)) {
        $key = Convert-HeatPath $raw
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        $f = Get-OrAddFileHeat -Files $Files -Path $key
        if ($Event -eq 'ai_pass') {
            $delta = 0
            if ([int]$f.fail_count -gt 0) { $delta = 1 }
            $f.fail_count = [int]$f.fail_count - $delta
            $f.unconfirmed_delta = [int]$f.unconfirmed_delta + $delta
            $f.last_result = 'pass'
            $f.last_updated = $Day
        } elseif ($Event -eq 'human_fail') {
            $f.fail_count = [int]$f.fail_count + [int]$f.unconfirmed_delta + 1
            $f.unconfirmed_delta = 0
            $f.last_result = 'fail'
            $f.last_updated = $Day
            $f.last_fail_ts = $Day
        } elseif ($Event -eq 'human_pass') {
            $f.unconfirmed_delta = 0
            $f.last_result = 'pass'
            $f.last_updated = $Day
        }
    }
}

function Clear-ExpiredFileHeat {
    param($Files, [datetime]$Now)
    $cut = $Now.Date.AddDays(-20).ToString('yyyy-MM-dd')
    foreach ($f in $Files) {
        if ([string]::IsNullOrWhiteSpace([string]$f.last_fail_ts)) { continue }
        if ([string]$f.last_fail_ts -lt $cut) {
            $f.fail_count = 0
            $f.last_result = ''
            $f.unconfirmed_delta = 0
        }
    }
}

function Add-ModuleHeatFailure {
    param($Entries, [string]$Module, [string]$FailTs, [string]$StopCount, [int]$RepairRounds)
    $entry = $null
    foreach ($e in $Entries) {
        if ($e.module -eq $Module) { $entry = $e; break }
    }
    if (-not $entry) {
        $entry = [ordered]@{ module = $Module; last_fail_ts = ''; fail_count = 0; max_stop_count = 0; heat = 'low' }
        [void]$Entries.Add($entry)
    }
    $entry.last_fail_ts = $FailTs
    $entry.fail_count = [int]$entry.fail_count + 1
    $stop = 0
    if ($StopCount -match '^(\d+)/') { $stop = [int]$Matches[1] }
    if ($RepairRounds -gt $stop) { $stop = $RepairRounds }
    if ($stop -gt [int]$entry.max_stop_count) { $entry.max_stop_count = $stop }
    if ([int]$entry.fail_count -ge 3 -or [int]$entry.max_stop_count -ge 2) { $entry.heat = 'high' }
    elseif ([int]$entry.fail_count -eq 2 -or [int]$entry.max_stop_count -eq 1) { $entry.heat = 'medium' }
    else { $entry.heat = 'low' }
    return $entry
}

function Write-DirectLogEntry {
    param([string]$Root, [string]$Module, [string]$Event, [string[]]$Paths, [string]$Note, [string]$Ts)
    if ($Module -notmatch '^[A-Za-z0-9_.-]+$') { throw "module name is not a single path segment: $Module" }
    $dir = Join-Path $Root $Module
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $log = Join-Path $dir 'DIRECTLOG.md'
    $labelFiles = U-Heat @(0x6D89, 0x53CA, 0x6587, 0x4EF6)
    $labelCheck = U-Heat @(0x9A8C, 0x8BC1, 0x7ED3, 0x679C)
    $labelJudge = U-Heat @(0x5173, 0x952E, 0x5224, 0x65AD)
    $labelError = U-Heat @(0x4FEE, 0x6539, 0x9519, 0x8BEF, 0x8BB0, 0x5F55)
    $labelResult = U-Heat @(0x7ED3, 0x679C)
    $waitHuman = U-Heat @(0x5F85, 0x4EBA, 0x6D4B)
    $humanFailed = U-Heat @(0x4EBA, 0x6D4B, 0x5931, 0x8D25)
    $humanPassed = U-Heat @(0x4EBA, 0x6D4B, 0x901A, 0x8FC7)
    $result = $waitHuman
    if ($Event -eq 'human_fail') { $result = $humanFailed }
    elseif ($Event -eq 'human_pass') { $result = $humanPassed }
    $paths = (@($Paths | ForEach-Object { Convert-HeatPath $_ } | Where-Object { $_ }) -join '; ')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("## $Ts")
    [void]$sb.AppendLine("- ${labelFiles}: $paths")
    [void]$sb.AppendLine("- ${labelCheck}: $Event")
    if ($Note) {
        $noteLabel = $labelJudge
        if ($Event -eq 'human_fail') { $noteLabel = $labelError }
        [void]$sb.AppendLine("- ${noteLabel}: $Note")
    }
    [void]$sb.AppendLine("- ${labelResult}: $result")
    [void]$sb.AppendLine('')
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($log, $sb.ToString(), $enc)
    return $log
}
