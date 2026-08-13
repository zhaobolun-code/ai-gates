<#
.SYNOPSIS
  从 trx / regression-heat.yaml / pipeline-outcome.log / .codegraph/ 只读聚合覆盖度表，
  写入 .ai-gates/coverage-map.yaml。

.DESCRIPTION
  - 三维并列、源内行键：测过=trx test_fullname；失败过=heat module/path；结构覆盖=.codegraph 相对路径
  - 禁止跨源 join、禁止 coverage_percent、禁止伪造 100%
  - 顶层元数据键仅 generated_by / source_fingerprint；数据块仅 tested / failed / structure
  - 缺源：trx 缺 → tested.status=missing（exit 0）；heat 缺 → failed 整块 missing；
    outcome 缺 → outcome_event_count=missing（heat 行仍列出）；无 .codegraph/ → structure.index_absent
  - -Verify：重算后点名比对 generated_by、source_fingerprint、三块行键集合、各行行值、
    点名标量（outcome_event_count / file_count）与块状态；禁止只比条数。yaml 不存在或不一致 → 非 0

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/compute-coverage-map.ps1
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/compute-coverage-map.ps1 -Verify
#>

[CmdletBinding()]
param(
    [switch]$Verify
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (& git -C $scriptDir rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$repoRoot)) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")).Path
} else {
    $repoRoot = ([string]$repoRoot).Trim()
}

$trxPath = Join-Path $repoRoot ".ai-gates\verify\editmode-tests.trx"
$heatPath = Join-Path $repoRoot ".ai-gates\regression-heat.yaml"
$outcomePath = Join-Path $repoRoot ".ai-gates\pipeline-outcome.log"
$codegraphDir = Join-Path $repoRoot ".codegraph"
$outPath = Join-Path $repoRoot ".ai-gates\coverage-map.yaml"

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$utf8Bom = New-Object System.Text.UTF8Encoding $true

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-FileSha256Hex {
    param([string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return "ABSENT" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($LiteralPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $hash = $sha.ComputeHash($fs)
        return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } catch {
        $info = Get-Item -LiteralPath $LiteralPath
        $fallback = "UNREADABLE:{0}:{1}" -f $info.Length, $info.LastWriteTimeUtc.Ticks
        return Get-Sha256Hex -Bytes $utf8NoBom.GetBytes($fallback)
    } finally {
        if ($null -ne $fs) { $fs.Dispose() }
        $sha.Dispose()
    }
}

function ConvertTo-YamlDoubleQuoted {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    $escaped = $Value.Replace("\", "\\").Replace('"', '\"')
    return '"' + $escaped + '"'
}

function ConvertFrom-YamlScalar {
    param([string]$Raw)
    if ($null -eq $Raw) { return "" }
    $t = $Raw.Trim()
    if ($t.Length -ge 2 -and $t.StartsWith('"') -and $t.EndsWith('"')) {
        $inner = $t.Substring(1, $t.Length - 2)
        return $inner.Replace('\"', '"').Replace("\\", "\")
    }
    if ($t.Length -ge 2 -and $t.StartsWith("'") -and $t.EndsWith("'")) {
        return $t.Substring(1, $t.Length - 2)
    }
    return $t
}

function Get-OutcomeEventCount {
    param([string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return "missing" }
    $n = 0
    foreach ($line in (Get-Content -LiteralPath $LiteralPath -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $trim = $line.TrimStart()
        if ($trim.StartsWith("#")) { continue }
        $n++
    }
    return $n
}

function Get-HeatRows {
    param([string]$LiteralPath)
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $rows }
    $current = $null
    foreach ($line in (Get-Content -LiteralPath $LiteralPath -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $trim = $line.TrimStart()
        if ($trim.StartsWith("#")) { continue }
        if ($line -match '^\s+-\s+(module|path):\s*(.*)$') {
            if ($null -ne $current) { $rows.Add($current) }
            $keyName = $Matches[1]
            $keyVal = ConvertFrom-YamlScalar -Raw $Matches[2]
            $current = [ordered]@{
                _keyName = $keyName
                _key     = $keyVal
            }
            $current[$keyName] = $keyVal
            continue
        }
        if ($null -ne $current -and $line -match '^\s+(\w+):\s*(.*)$') {
            $fk = $Matches[1]
            if ($fk -eq "entries" -or $fk -eq "version") { continue }
            $current[$fk] = ConvertFrom-YamlScalar -Raw $Matches[2]
        }
    }
    if ($null -ne $current) { $rows.Add($current) }
    return $rows
}

function Get-TrxRows {
    param([string]$LiteralPath)
    $map = New-Object "System.Collections.Generic.SortedDictionary[string,string]" ([StringComparer]::Ordinal)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $map }
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.Load($LiteralPath)
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("t", "http://microsoft.com/schemas/VisualStudio/TeamTest/2010")
    $nodes = $xml.SelectNodes("//t:UnitTestResult", $ns)
    if ($null -eq $nodes -or $nodes.Count -eq 0) {
        $nodes = $xml.SelectNodes("//UnitTestResult")
    }
    if ($null -eq $nodes) { return $map }
    foreach ($n in $nodes) {
        $name = [string]$n.GetAttribute("testName")
        $outcome = [string]$n.GetAttribute("outcome")
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $map[$name] = $outcome
    }
    return $map
}

function Get-CodegraphRows {
    param([string]$DirPath)
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $DirPath)) { return $rows }
    $rootFull = (Resolve-Path -LiteralPath $DirPath).Path.TrimEnd("\", "/")
    $files = @(Get-ChildItem -LiteralPath $DirPath -Recurse -File -Force -ErrorAction Stop)
    $relList = New-Object System.Collections.Generic.List[string]
    foreach ($f in $files) {
        $name = $f.Name
        if ($name -like '*.db-wal' -or $name -like '*.db-shm') { continue }
        $full = $f.FullName
        if ($full.Length -le $rootFull.Length) { continue }
        $rel = $full.Substring($rootFull.Length).TrimStart("\", "/").Replace("\", "/")
        $relList.Add($rel)
    }
    $arr = @($relList)
    if ($arr.Count -gt 1) {
        [Array]::Sort($arr, [StringComparer]::Ordinal)
    }
    foreach ($rel in $arr) {
        $rows.Add([ordered]@{ path = $rel })
    }
    return $rows
}

function Get-CodegraphFingerprintPayload {
    param([string]$DirPath)
    if (-not (Test-Path -LiteralPath $DirPath)) { return "ABSENT" }
    $rows = Get-CodegraphRows -DirPath $DirPath
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($r in $rows) { $lines.Add([string]$r.path) }
    return (($lines -join "`n") + "`n")
}

function Get-CoverageMap {
    $trxPresent = Test-Path -LiteralPath $trxPath
    $heatPresent = Test-Path -LiteralPath $heatPath
    $outcomePresent = Test-Path -LiteralPath $outcomePath
    $cgPresent = Test-Path -LiteralPath $codegraphDir

    $trxFp = Get-FileSha256Hex -LiteralPath $trxPath
    $heatFp = Get-FileSha256Hex -LiteralPath $heatPath
    $outcomeFp = Get-FileSha256Hex -LiteralPath $outcomePath
    $cgFp = Get-Sha256Hex -Bytes $utf8NoBom.GetBytes((Get-CodegraphFingerprintPayload -DirPath $codegraphDir))
    if (-not $cgPresent) { $cgFp = "ABSENT" }

    $payload = "trx=$trxFp`nheat=$heatFp`noutcome=$outcomeFp`ncodegraph=$cgFp`n"
    $fingerprint = Get-Sha256Hex -Bytes $utf8NoBom.GetBytes($payload)

    $testedStatus = "missing"
    $testedRows = New-Object System.Collections.Generic.List[object]
    if ($trxPresent) {
        $testedStatus = "present"
        $trxMap = Get-TrxRows -LiteralPath $trxPath
        foreach ($name in $trxMap.Keys) {
            $testedRows.Add([ordered]@{
                test_fullname = $name
                outcome       = [string]$trxMap[$name]
            })
        }
    }

    $failedStatus = "missing"
    $failedRows = New-Object System.Collections.Generic.List[object]
    $outcomeCount = Get-OutcomeEventCount -LiteralPath $outcomePath
    if ($heatPresent) {
        $failedStatus = "present"
        $heatRows = Get-HeatRows -LiteralPath $heatPath
        $keyed = New-Object "System.Collections.Generic.SortedDictionary[string,object]" ([StringComparer]::Ordinal)
        foreach ($hr in $heatRows) {
            $k = [string]$hr["_key"]
            if ([string]::IsNullOrWhiteSpace($k)) { continue }
            $keyed[$k] = $hr
        }
        foreach ($k in $keyed.Keys) {
            $hr = $keyed[$k]
            $row = [ordered]@{}
            $keyName = [string]$hr["_keyName"]
            if ([string]::IsNullOrWhiteSpace($keyName)) { $keyName = "module" }
            $row[$keyName] = [string]$hr["_key"]
            foreach ($fk in @("last_fail_ts", "fail_count", "max_stop_count", "heat")) {
                if ($hr.Contains($fk)) { $row[$fk] = [string]$hr[$fk] }
            }
            foreach ($fk in @($hr.Keys)) {
                if ($fk -like "_*") { continue }
                if ($fk -eq $keyName) { continue }
                if ($row.Contains($fk)) { continue }
                $row[$fk] = [string]$hr[$fk]
            }
            $failedRows.Add($row)
        }
    }

    $structureStatus = "index_absent"
    $structureRows = New-Object System.Collections.Generic.List[object]
    $fileCount = "missing"
    if ($cgPresent) {
        $structureStatus = "present"
        $structureRows = Get-CodegraphRows -DirPath $codegraphDir
        $fileCount = @($structureRows).Count
    }

    return [ordered]@{
        generated_by        = "compute-coverage-map.ps1"
        source_fingerprint  = $fingerprint
        tested              = [ordered]@{
            status = $testedStatus
            rows   = $testedRows
        }
        failed              = [ordered]@{
            status               = $failedStatus
            outcome_event_count  = $outcomeCount
            rows                 = $failedRows
        }
        structure           = [ordered]@{
            status     = $structureStatus
            file_count = $fileCount
            rows       = $structureRows
        }
    }
}

function Write-CoverageMapYaml {
    param($Map, [string]$LiteralPath)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# 覆盖度表（自动生成：compute-coverage-map.ps1）")
    [void]$sb.AppendLine("# 勿手工编辑覆盖率/计数字段。权威：skills/references/coverage-map.md")
    [void]$sb.AppendLine("# 顶层元数据键 generated_by / source_fingerprint 与数据块仅三块不互斥。")
    [void]$sb.AppendLine("# 禁止跨源 coverage_percent；heat≠覆盖度。")
    $gen = [string]$Map['generated_by']
    $fp = [string]$Map['source_fingerprint']
    [void]$sb.AppendLine("generated_by: $gen")
    [void]$sb.AppendLine(("source_fingerprint: {0}" -f (ConvertTo-YamlDoubleQuoted -Value $fp)))

    $tested = $Map['tested']
    [void]$sb.AppendLine("tested:")
    [void]$sb.AppendLine(("  status: {0}" -f [string]$tested['status']))
    $trows = $tested['rows']
    if ($null -eq $trows -or $trows.Count -eq 0) {
        [void]$sb.AppendLine("  rows: []")
    } else {
        [void]$sb.AppendLine("  rows:")
        foreach ($r in $trows) {
            $tn = ConvertTo-YamlDoubleQuoted -Value ([string]$r['test_fullname'])
            [void]$sb.AppendLine("    - test_fullname: $tn")
            [void]$sb.AppendLine(("      outcome: {0}" -f [string]$r['outcome']))
        }
    }

    $failed = $Map['failed']
    [void]$sb.AppendLine("failed:")
    [void]$sb.AppendLine(("  status: {0}" -f [string]$failed['status']))
    $oec = [string]$failed['outcome_event_count']
    [void]$sb.AppendLine("  outcome_event_count: $oec")
    $frows = $failed['rows']
    if ($null -eq $frows -or $frows.Count -eq 0) {
        [void]$sb.AppendLine("  rows: []")
    } else {
        [void]$sb.AppendLine("  rows:")
        foreach ($r in $frows) {
            $first = $true
            foreach ($k in $r.Keys) {
                $v = [string]$r[$k]
                if ($first) {
                    if ($k -eq "last_fail_ts" -or $k -eq "module" -or $k -eq "path" -or $k -eq "heat") {
                        $qv = ConvertTo-YamlDoubleQuoted -Value $v
                        [void]$sb.AppendLine("    - ${k}: $qv")
                    } else {
                        [void]$sb.AppendLine("    - ${k}: $v")
                    }
                    $first = $false
                } else {
                    if ($k -eq "last_fail_ts" -or $k -eq "module" -or $k -eq "path" -or $k -eq "heat") {
                        $qv = ConvertTo-YamlDoubleQuoted -Value $v
                        [void]$sb.AppendLine("      ${k}: $qv")
                    } else {
                        [void]$sb.AppendLine("      ${k}: $v")
                    }
                }
            }
        }
    }

    $structure = $Map['structure']
    [void]$sb.AppendLine("structure:")
    [void]$sb.AppendLine(("  status: {0}" -f [string]$structure['status']))
    [void]$sb.AppendLine(("  file_count: {0}" -f [string]$structure['file_count']))
    $srows = $structure['rows']
    if ($null -eq $srows -or $srows.Count -eq 0) {
        [void]$sb.AppendLine("  rows: []")
    } else {
        [void]$sb.AppendLine("  rows:")
        foreach ($r in $srows) {
            $pv = ConvertTo-YamlDoubleQuoted -Value ([string]$r['path'])
            [void]$sb.AppendLine("    - path: $pv")
        }
    }

    $dir = Split-Path -Parent $LiteralPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($LiteralPath, $sb.ToString(), $utf8Bom)
}

function Parse-CoverageMapYaml {
    param([string]$LiteralPath)
    $text = [System.IO.File]::ReadAllText($LiteralPath, $utf8Bom)
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) {
        $text = $text.Substring(1)
    }
    $lines = $text -split "`r`n|`n|`r", -1

    $topKeys = New-Object System.Collections.Generic.List[string]
    $parsed = [ordered]@{
        generated_by       = $null
        source_fingerprint = $null
        tested             = [ordered]@{ status = $null; rows = (New-Object System.Collections.Generic.List[object]); extra = (New-Object System.Collections.Generic.List[string]) }
        failed             = [ordered]@{ status = $null; outcome_event_count = $null; rows = (New-Object System.Collections.Generic.List[object]); extra = (New-Object System.Collections.Generic.List[string]) }
        structure          = [ordered]@{ status = $null; file_count = $null; rows = (New-Object System.Collections.Generic.List[object]); extra = (New-Object System.Collections.Generic.List[string]) }
        extra_top          = (New-Object System.Collections.Generic.List[string])
    }
    $block = $null
    $row = $null
    $inRows = $false

    foreach ($line in $lines) {
        if ($null -eq $line) { continue }
        if ($line -match '^\s*#') { continue }
        if ($line.Trim().Length -eq 0) { continue }

        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            if ($null -ne $row -and $null -ne $block) {
                $parsed[$block].rows.Add($row)
                $row = $null
            }
            $k = $Matches[1]
            $v = $Matches[2]
            $topKeys.Add($k)
            $inRows = $false
            $block = $null
            if ($k -eq "generated_by") {
                $parsed.generated_by = ConvertFrom-YamlScalar -Raw $v
            } elseif ($k -eq "source_fingerprint") {
                $parsed.source_fingerprint = ConvertFrom-YamlScalar -Raw $v
            } elseif ($k -eq "tested" -or $k -eq "failed" -or $k -eq "structure") {
                $block = $k
            } else {
                $parsed.extra_top.Add($k)
            }
            continue
        }

        if ($null -eq $block) { continue }

        if ($line -match '^  ([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            if ($null -ne $row) {
                $parsed[$block].rows.Add($row)
                $row = $null
            }
            $fk = $Matches[1]
            $fv = $Matches[2].Trim()
            $inRows = $false
            if ($fk -eq "status") {
                $parsed[$block].status = ConvertFrom-YamlScalar -Raw $fv
            } elseif ($fk -eq "outcome_event_count") {
                $parsed[$block].outcome_event_count = ConvertFrom-YamlScalar -Raw $fv
            } elseif ($fk -eq "file_count") {
                $parsed[$block].file_count = ConvertFrom-YamlScalar -Raw $fv
            } elseif ($fk -eq "rows") {
                if ($fv -eq "[]") {
                    $inRows = $false
                } else {
                    $inRows = $true
                }
            } else {
                $parsed[$block].extra.Add($fk)
            }
            continue
        }

        if ($inRows -and $line -match '^    - ([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            if ($null -ne $row) { $parsed[$block].rows.Add($row) }
            $row = [ordered]@{}
            $row[$Matches[1]] = ConvertFrom-YamlScalar -Raw $Matches[2]
            continue
        }

        if ($null -ne $row -and $line -match '^      ([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            $row[$Matches[1]] = ConvertFrom-YamlScalar -Raw $Matches[2]
            continue
        }
    }
    if ($null -ne $row -and $null -ne $block) {
        $parsed[$block].rows.Add($row)
    }
    $parsed["_topKeys"] = $topKeys
    return $parsed
}

function Get-RowKey {
    param($Row, [string]$Block)
    if ($Block -eq "tested") { return [string]$Row["test_fullname"] }
    if ($Block -eq "structure") { return [string]$Row["path"] }
    if ($Row.Contains("module")) { return [string]$Row["module"] }
    if ($Row.Contains("path")) { return [string]$Row["path"] }
    return ""
}

function ConvertTo-RowMap {
    param($Rows, [string]$Block)
    $map = New-Object "System.Collections.Generic.SortedDictionary[string,object]" ([StringComparer]::Ordinal)
    if ($null -eq $Rows) { return $map }
    foreach ($r in $Rows) {
        $k = Get-RowKey -Row $r -Block $Block
        if ([string]::IsNullOrWhiteSpace($k)) {
            throw "VERIFY FAIL: $Block row missing row-key"
        }
        $map[$k] = $r
    }
    return $map
}

function Get-OrderedKeys {
    param($Dict)
    $list = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Dict) { return $list }
    foreach ($k in $Dict.Keys) { $list.Add([string]$k) }
    return $list
}

function Test-ScalarEqual {
    param($A, $B)
    return ([string]$A) -eq ([string]$B)
}

function Invoke-VerifyCoverageMap {
    param($Fresh, [string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Host "VERIFY FAIL: yaml not found: $LiteralPath"
        exit 1
    }
    $disk = Parse-CoverageMapYaml -LiteralPath $LiteralPath
    $fails = New-Object System.Collections.Generic.List[string]

    if (-not (Test-ScalarEqual -A $disk.generated_by -B $Fresh.generated_by)) {
        $fails.Add(("generated_by disk='{0}' fresh='{1}'" -f $disk.generated_by, $Fresh.generated_by))
    }
    if (-not (Test-ScalarEqual -A $disk.source_fingerprint -B $Fresh.source_fingerprint)) {
        $fails.Add(("source_fingerprint mismatch disk='{0}' fresh='{1}'" -f $disk.source_fingerprint, $Fresh.source_fingerprint))
    }

    $allowedTop = @("generated_by", "source_fingerprint", "tested", "failed", "structure")
    foreach ($k in @($disk["_topKeys"])) {
        if ($allowedTop -notcontains $k) {
            $fails.Add("extra top-level key: $k")
        }
    }
    foreach ($need in $allowedTop) {
        if (@($disk["_topKeys"]) -notcontains $need) {
            $fails.Add("missing top-level key: $need")
        }
    }
    foreach ($k in @($disk.extra_top)) {
        $fails.Add("extra top-level key: $k")
    }

    foreach ($block in @("tested", "failed", "structure")) {
        $d = $disk[$block]
        $f = $Fresh[$block]
        if (-not (Test-ScalarEqual -A $d.status -B $f.status)) {
            $fails.Add(("{0}.status disk='{1}' fresh='{2}'" -f $block, $d.status, $f.status))
        }
        foreach ($extra in @($d.extra)) {
            $fails.Add(("{0} extra field: {1}" -f $block, $extra))
        }
        if ($block -eq "failed") {
            if (-not (Test-ScalarEqual -A $d.outcome_event_count -B $f.outcome_event_count)) {
                $fails.Add(("failed.outcome_event_count disk='{0}' fresh='{1}'" -f $d.outcome_event_count, $f.outcome_event_count))
            }
        }
        if ($block -eq "structure") {
            if (-not (Test-ScalarEqual -A $d.file_count -B $f.file_count)) {
                $fails.Add(("structure.file_count disk='{0}' fresh='{1}'" -f $d.file_count, $f.file_count))
            }
        }

        $dMap = ConvertTo-RowMap -Rows $d['rows'] -Block $block
        $fMap = ConvertTo-RowMap -Rows $f['rows'] -Block $block
        $dKeys = Get-OrderedKeys -Dict $dMap
        $fKeys = Get-OrderedKeys -Dict $fMap
        if ($dKeys.Count -ne $fKeys.Count) {
            $fails.Add(("{0} row-key count disk={1} fresh={2} (named set, not a dummy count field)" -f $block, $dKeys.Count, $fKeys.Count))
        }
        foreach ($k in $dKeys) {
            if (-not $fMap.ContainsKey($k)) {
                $fails.Add(("{0} extra row-key on disk: {1}" -f $block, $k))
            }
        }
        foreach ($k in $fKeys) {
            if (-not $dMap.ContainsKey($k)) {
                $fails.Add(("{0} missing row-key on disk: {1}" -f $block, $k))
            }
        }
        foreach ($k in $fKeys) {
            if (-not $dMap.ContainsKey($k)) { continue }
            $dr = $dMap[$k]
            $fr = $fMap[$k]
            $fFieldKeys = Get-OrderedKeys -Dict $fr
            foreach ($fk in $fFieldKeys) {
                if ($fk -like "_*") { continue }
                $dv = $dr[$fk]
                $fv = $fr[$fk]
                if (-not (Test-ScalarEqual -A $dv -B $fv)) {
                    $fails.Add(("{0}[{1}].{2} disk='{3}' fresh='{4}'" -f $block, $k, $fk, $dv, $fv))
                }
            }
            $dFieldKeys = Get-OrderedKeys -Dict $dr
            $freshKeySet = Get-OrderedKeys -Dict $fr
            foreach ($dk in $dFieldKeys) {
                if ($dk -like "_*") { continue }
                if ($freshKeySet -notcontains $dk) {
                    $fails.Add(("{0}[{1}] extra row field on disk: {2}" -f $block, $k, $dk))
                }
            }
        }
    }

    if ($fails.Count -gt 0) {
        Write-Host "VERIFY FAIL:"
        foreach ($m in $fails) { Write-Host ("  - {0}" -f $m) }
        exit 1
    }
    Write-Host "coverage-map verify: OK"
    exit 0
}

$map = Get-CoverageMap

if ($Verify) {
    Invoke-VerifyCoverageMap -Fresh $map -LiteralPath $outPath
}

Write-CoverageMapYaml -Map $map -LiteralPath $outPath
Write-Host "coverage-map written: $outPath"
Write-Host ("tested.status={0} rows={1}" -f [string]$map['tested']['status'], $map['tested']['rows'].Count)
Write-Host ("failed.status={0} rows={1} outcome_event_count={2}" -f [string]$map['failed']['status'], $map['failed']['rows'].Count, $map['failed']['outcome_event_count'])
Write-Host ("structure.status={0} file_count={1}" -f [string]$map['structure']['status'], $map['structure']['file_count'])
Write-Host ("source_fingerprint={0}" -f [string]$map['source_fingerprint'])
exit 0
