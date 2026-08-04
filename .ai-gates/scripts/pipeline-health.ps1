# pipeline-health.ps1 — 流水线体检（打点数据 → 机制健康度报告）
#
# 定位：pm-gate.json / changelog-writes.json / .ai-gates/hooks-log/*.log 的数据目前只用于
# 门禁实时判断（120 分钟内有没有流水等布尔判定），数据本身没有回馈。本脚本把
# 打点数据聚合成「最近 N 天机制健康度报告」，让 PM 判定从拍脑袋变看数据：
#   - [PM] 打点规模 / 最近活跃 / 来源分布（text / planner-subagent / developer-subagent）
#   - CHANGELOG 写流水规模 / 最近活跃
#   - 门禁 deny 触发次数（pm-gate-check.log）
#   - 打点解析健壮性（PARSE_FAIL 次数）
#   - 退化信号判定：打点缺失 / 门禁长期无触发 / 全链路静默（= 方向⑤「退化信号自动巡检」）
#
# 数据源（.ai-gates/hooks-log/）：
#   pm-gate.json                  [PM] 打点（UTC 时间）
#   changelog-writes.json         CHANGELOG 写流水（UTC 时间）
#   pm-gate-check.log             门禁行为审计（本地时间，yyyy-MM-dd HH:mm:ss | ...）
#   mark-pm-gate.log / mark-changelog-write.log  打点审计（含 PARSE_FAIL 插桩）
#   unity-compile-check.log       写后质量门命中审计（含 HIT）
#   hooks-policy-drift.log        漂移检测审计
#   pm-gate-disabled              kill switch（存在 = 门禁被人工禁用）
#
# 退化信号（WARN/CRIT）：
#   D1  打点文件缺失（pm-gate.json / changelog-writes.json）→ CRIT：对应门禁退化为 fail-open/初始态
#   D2  近 N 天门禁 deny = 0 但有打点 → WARN：门禁可能未接线或全豁免（机制形同虚设仍当已生效）
#   D3  近 N 天 PARSE_FAIL > 0 → WARN：打点链路不稳（大 payload 解析失败，fallback 兜底中）
#   D4  近 N 天打点 = 0 且 deny = 0 → CRIT：hook 链路全静默（hooks.json 未接线或 Cursor 侧失效）
#   D5  kill switch 存在 → INFO：门禁被人工禁用（豁免期内不判退化）
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pipeline-health.ps1
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pipeline-health.ps1 -Days 7
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pipeline-health.ps1 -OutFile pipeline-health-report.md
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pipeline-health.ps1 -JsonOutput
#
# 退出码：0 = 无退化信号；2 = 有 WARN/CRIT 退化信号（供 CI / 发布闸检查）。

param(
    [int]$Days = 30,
    [string]$OutFile = "",
    [switch]$JsonOutput
)

$ErrorActionPreference = "Stop"
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path }
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"

$sinceUtc = [DateTime]::UtcNow.AddDays(-$Days)

function Get-FileUtcTime {
    param([string]$Iso)
    if ([string]::IsNullOrWhiteSpace($Iso)) { return $null }
    try { return [DateTimeOffset]::Parse($Iso).UtcDateTime } catch { return $null }
}

# 读打点 json：返回 { Total, Recent, LatestUtc, SourceFields }
function Read-MarkFile {
    param([string]$Path, [string]$SourceFieldName)
    $result = [ordered]@{ Total = 0; Recent = 0; LatestUtc = $null; SourceFields = [ordered]@{} }
    if (-not (Test-Path -LiteralPath $Path)) { return $result }
    try {
        $data = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $props = @($data.PSObject.Properties)
        $result.Total = $props.Count
        $latest = [DateTime]::MinValue
        foreach ($p in $props) {
            $entry = $p.Value
            $t = $null
            if ($entry.PSObject.Properties.Name -contains "lastPmAtUtc") { $t = Get-FileUtcTime -Iso ([string]$entry.lastPmAtUtc) }
            elseif ($entry.PSObject.Properties.Name -contains "lastChangelogWriteAtUtc") { $t = Get-FileUtcTime -Iso ([string]$entry.lastChangelogWriteAtUtc) }
            if ($t) {
                if ($t -ge $sinceUtc) { $result.Recent++ }
                if ($t -gt $latest) { $latest = $t }
            }
            if ($SourceFieldName -and $entry.PSObject.Properties.Name -contains $SourceFieldName) {
                $f = [string]$entry.$SourceFieldName
                if (-not $result.SourceFields.Contains($f)) { $result.SourceFields[$f] = 0 }
                $result.SourceFields[$f]++
            }
        }
        if ($latest -gt [DateTime]::MinValue) { $result.LatestUtc = $latest }
    } catch {
        $result.Total = -1  # -1 = 文件损坏
    }
    return $result
}

# 统计 log 文件近 N 天匹配关键字的行数（行首时间戳 yyyy-MM-dd HH:mm:ss，本地时间 → UTC 比较；
# 排除测试/仿真会话行，避免 test-hooks / simulate-cursor-session 的刻意构造污染体检）
function Count-LogLines {
    param([string]$Path, [string]$Pattern, [string]$ExcludePattern = "__test__|__sim__")
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $count = 0
    try {
        foreach ($line in [System.IO.File]::ReadLines($Path, [System.Text.Encoding]::UTF8)) {
            if ($line -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
                # 注意：-match 会覆盖 $Matches，必须先取时间戳再匹配关键字
                $ts = $Matches[1]
                if ($ExcludePattern -and $line -match $ExcludePattern) { continue }
                if ($line -match $Pattern) {
                    $lineTime = [DateTime]::ParseExact($ts, "yyyy-MM-dd HH:mm:ss", $null)
                    if ($lineTime.ToUniversalTime() -ge $sinceUtc) { $count++ }
                }
            }
        }
    } catch {
        # 日志读取失败按 0 计（不阻塞体检）
    }
    return $count
}

$pmGate = Read-MarkFile -Path (Join-Path $logDir "pm-gate.json") -SourceFieldName "sourceField"
$cw = Read-MarkFile -Path (Join-Path $logDir "changelog-writes.json")
$denyCount = Count-LogLines -Path (Join-Path $logDir "pm-gate-check.log") -Pattern "DENY|deny"
$parseFailMarkPm = Count-LogLines -Path (Join-Path $logDir "mark-pm-gate.log") -Pattern "PARSE_FAIL"
$parseFailMarkCw = Count-LogLines -Path (Join-Path $logDir "mark-changelog-write.log") -Pattern "PARSE_FAIL"
$unityHit = Count-LogLines -Path (Join-Path $logDir "unity-compile-check.log") -Pattern "HIT"
$killSwitch = Test-Path -LiteralPath (Join-Path $logDir "pm-gate-disabled")

# 退化信号判定
$signals = @()
$level = "OK"
if ($pmGate.Total -lt 0 -or $cw.Total -lt 0) {
    $signals += "CRIT D1a 打点文件损坏（pm-gate.json / changelog-writes.json 解析失败）"; $level = "CRIT"
} elseif (-not (Test-Path -LiteralPath (Join-Path $logDir "pm-gate.json")) -or -not (Test-Path -LiteralPath (Join-Path $logDir "changelog-writes.json"))) {
    $signals += "CRIT D1 打点文件缺失：门禁退化为 fail-open/初始态"; $level = "CRIT"
}
$parseFailTotal = $parseFailMarkPm + $parseFailMarkCw
if ($parseFailTotal -gt 0) {
    $signals += "WARN D3 近 $Days 天 PARSE_FAIL x$parseFailTotal（mark-pm-gate $parseFailMarkPm / mark-changelog-write $parseFailMarkCw）打点链路不稳，fallback 兜底中"; if ($level -ne "CRIT") { $level = "WARN" }
}
if ($killSwitch) {
    $signals += "INFO D5 kill switch 存在：门禁被人工禁用（豁免期内不判退化）"
}
if (-not $killSwitch -and ($pmGate.Recent -gt 0 -or $cw.Recent -gt 0)) {
    if ($denyCount -eq 0) {
        $signals += "WARN D2 近 $Days 天有打点但门禁 deny=0：门禁可能未接线或全豁免（机制形同虚设仍当已生效）"; if ($level -ne "CRIT") { $level = "WARN" }
    }
}
if ($pmGate.Recent -eq 0 -and $cw.Recent -eq 0 -and $denyCount -eq 0 -and -not $killSwitch) {
    $signals += "CRIT D4 近 $Days 天打点与 deny 全为 0：hook 链路全静默（hooks.json 未接线或 Cursor 侧失效）"; $level = "CRIT"
}
if ($signals.Count -eq 0) {
    $signals += "OK 近 $Days 天无退化信号：打点正常、门禁有触发、链路稳定"
}

$latestPmStr = if ($pmGate.LatestUtc) { $pmGate.LatestUtc.ToString("yyyy-MM-dd HH:mm:ss'Z'") } else { "无" }
$latestCwStr = if ($cw.LatestUtc) { $cw.LatestUtc.ToString("yyyy-MM-dd HH:mm:ss'Z'") } else { "无" }
$fieldSummary = if ($pmGate.SourceFields.Count -gt 0) { ($pmGate.SourceFields.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " / " } else { "—" }

$report = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString("o")
    days = $Days
    pmGate = [ordered]@{ total = $pmGate.Total; recent = $pmGate.Recent; latestUtc = $latestPmStr; sourceFields = $fieldSummary }
    changelogWrites = [ordered]@{ total = $cw.Total; recent = $cw.Recent; latestUtc = $latestCwStr }
    gateDeny = $denyCount
    parseFail = $parseFailTotal
    unityCompileHit = $unityHit
    killSwitchActive = $killSwitch
    signals = $signals
    level = $level
}

if ($JsonOutput) {
    $report | ConvertTo-Json -Depth 6
} else {
    $md = @()
    $md += "# 流水线体检（近 $Days 天 · $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))Z）"
    $md += ""
    $md += "## [PM] 打点（pm-gate.json）"
    $md += "- 会话数：$($pmGate.Total)（近 $Days 天 $($pmGate.Recent)）· 最近：$latestPmStr"
    $md += "- 来源分布：$fieldSummary"
    $md += ""
    $md += "## CHANGELOG 写流水（changelog-writes.json）"
    $md += "- 会话数：$($cw.Total)（近 $Days 天 $($cw.Recent)）· 最近：$latestCwStr"
    $md += ""
    $md += "## 门禁与质量门"
    $md += "- 门禁 deny：$denyCount 次 · PARSE_FAIL：$parseFailTotal 次 · Unity 编译命中：$unityHit 次"
    $md += "- kill switch：$killSwitch"
    $md += ""
    $md += "## 退化信号"
    foreach ($s in $signals) { $md += "- $s" }
    $md += ""
    $md += "> 退出码 0=健康 / 2=有退化信号。数据源：.ai-gates/hooks-log/（本脚本见 scripts/pipeline-health.ps1）。"
    $mdText = $md -join "`n"
    if ($OutFile) {
        [System.IO.File]::WriteAllText((Join-Path (Get-Location) $OutFile), $mdText + "`n", $utf8Bom)
        Write-Host "已写报告：$OutFile"
    }
    $mdText
}

if ($level -eq "CRIT" -or $level -eq "WARN") { exit 2 }
exit 0
