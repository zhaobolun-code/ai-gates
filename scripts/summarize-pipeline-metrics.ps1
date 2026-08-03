# summarize-pipeline-metrics.ps1 — 汇总 pipeline-snapshot.log + pipeline-recovery-log.md
# Usage: .\summarize-pipeline-metrics.ps1
param(
    [int]$LastDays = 30
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$snapshotPath = Join-Path $repoRoot ".cursor/pipeline-snapshot.log"
$recoveryPath = Join-Path $repoRoot ".cursor/pipeline-recovery-log.md"
$cutoff = (Get-Date).AddDays(-$LastDays)

Write-Host "=== pipeline metrics (last $LastDays days) ===" -ForegroundColor Cyan

# Snapshot JSONL
$laneCounts = @{}
$tierCounts = @{}
$eventCounts = @{}
$snapshotRows = 0

if (Test-Path -LiteralPath $snapshotPath) {
    Get-Content -LiteralPath $snapshotPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        try {
            $o = $line | ConvertFrom-Json
            $ts = [datetime]::Parse($o.ts)
            if ($ts -lt $cutoff) { return }
            $snapshotRows++
            if ($o.event) {
                if (-not $eventCounts.ContainsKey($o.event)) { $eventCounts[$o.event] = 0 }
                $eventCounts[$o.event]++
            }
            if ($o.lane) {
                if (-not $laneCounts.ContainsKey($o.lane)) { $laneCounts[$o.lane] = 0 }
                $laneCounts[$o.lane]++
            }
            if ($o.review_tier) {
                if (-not $tierCounts.ContainsKey($o.review_tier)) { $tierCounts[$o.review_tier] = 0 }
                $tierCounts[$o.review_tier]++
            }
        } catch {
            Write-Host "warn: skip invalid JSONL line" -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "snapshot log: (missing) $snapshotPath" -ForegroundColor DarkGray
}

Write-Host "`n--- snapshot events ($snapshotRows rows) ---" -ForegroundColor Cyan
if ($eventCounts.Count -eq 0) { Write-Host "  (none)" } else {
    $eventCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
}
Write-Host "lanes:"
if ($laneCounts.Count -eq 0) { Write-Host "  (none)" } else {
    $laneCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
}
Write-Host "review_tier:"
if ($tierCounts.Count -eq 0) { Write-Host "  (none)" } else {
    $tierCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
}

# Recovery log table
$deviationCounts = @{}
$recoveryRows = 0

if (Test-Path -LiteralPath $recoveryPath) {
    $inTable = $false
    Get-Content -LiteralPath $recoveryPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\|\s*日期\s*\|') { $inTable = $true; return }
        if ($inTable -and $_ -match '^\|\s*---') { return }
        if ($inTable -and $_ -match '^\|\s*(\d{4}-\d{2}-\d{2})\s*\|\s*([^|]+)\|') {
            $dateStr = $matches[1]
            $devType = $matches[2].Trim()
            if ($devType -match '示例') { return }
            try {
                $d = [datetime]::Parse($dateStr)
                if ($d -lt $cutoff) { return }
            } catch { return }
            $recoveryRows++
            if (-not $deviationCounts.ContainsKey($devType)) { $deviationCounts[$devType] = 0 }
            $deviationCounts[$devType]++
        }
    }
} else {
    Write-Host "`nrecovery log: (missing) $recoveryPath" -ForegroundColor DarkGray
}

Write-Host "`n--- recovery deviations ($recoveryRows rows) ---" -ForegroundColor Cyan
if ($deviationCounts.Count -eq 0) { Write-Host "  (none)" } else {
    $deviationCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
}

Write-Host "`nTip: TL sprint 汇总模板 → .cursor/skills/references/retrospective-metrics.md" -ForegroundColor DarkGray
