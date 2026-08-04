<#
.SYNOPSIS
  运行时证据机械化校验（支柱 A · 最小实现）：把「Agent 读 Editor.log 后自己判断关键词命中」
  换成「脚本产出带时间戳的结构化 JSON 证据文件」，供 PM/CR 核对，而不是只信 Agent 的转述。

.DESCRIPTION
  背景/权威：.cursor/skills/references/unity-editor-log.md §A/§B
  本脚本不做任何"判定通过/拦截"——只产出确定性事实（命中数、样例行、日志新鲜度、编译错误扫描）。
  是否据此标 runtime-validated / static-checked 仍由 PM/CR 按 Skill 规则决定；脚本只保证
  "关键词到底命中没有、日志到底新不新鲜"不再是 Agent 一句转述，而是可复核的产物文件。
  可选体积门禁：在 Keywords 命中行解析 volume=…ml；minVolumeMl / minSumVolumeMl 默认 Or。

.PARAMETER Keywords
  必填。要在 Editor.log 中核对的关键词（通常取自当前 Step 的
  "Required Validation Logs Or Signals" / Mandatory 预期 Console 关键词），
  **逗号分隔的单个字符串**（例如 "kw1,kw2,kw3"），不是数组参数。
  这样跨进程调用（`powershell -File ... -Keywords "a,b"`）不会被 PowerShell 的
  位置参数绑定/数组转参数字符串行为坑到（数组跨进程边界会被拍扁成一个逗号字符串，
  或被误绑定到下一个位置参数）。

.PARAMETER ExpectAbsentKeywords
  可选。不应该出现的关键词/审计标签（同样逗号分隔，例如物理口径里明确禁止的现象，
  比如「满管液柱顶回高压源」对应的审计标签），命中即视为回归证据（`anyAbsentHit=true`）。
  跟 Keywords（应出现）互补：Keywords 只证明"预期事件发生了"，证不了"不该发生的事情
  没发生"；这个参数补的是后一半，让"这次改动引入了已知坏模式"也能被机械抓到，而不是
  只能靠人肉盯屏幕。

.PARAMETER Mode
  Any（默认）= 任一关键词命中即算 OverallHit；All = 全部关键词都要命中。
  仅作用于 -Keywords（应出现）；-ExpectAbsentKeywords 永远是"任一命中即算坏"，
  没有 All/Any 之分。

.PARAMETER SinceMinutes
  新鲜度窗口（分钟），默认 30。Editor.log 最后写入时间早于此窗口 → Fresh=false，
  对应 unity-editor-log.md「时间戳明显早于本次 Play → 说明日志可能不是本局」。

.PARAMETER EditorLogPath
  默认 Windows 标准路径 $env:LOCALAPPDATA\Unity\Editor\Editor.log。

.PARAMETER TailLines
  只扫描日志末尾这么多行（避免整份大文件灌进内存/上下文），默认 20000。
  ≤0 表示扫全文件。专用 batchmode -logFile（路径含 unity-verify-）在未显式传本参数时默认全文件，
  避免 kick/早期 LiquidIngress 被 -Tail 裁掉导致 G1 假红。

.PARAMETER MinVolumeMl
  可选。Keywords 命中行上解析到的 volume=…ml 单条最大值下限；未传则不启用该侧。

.PARAMETER MinSumVolumeMl
  可选。Keywords 命中行上 volume 累计和下限；未传则不启用该侧。
  两侧都传时默认 Or（max≥MinVolumeMl -or sum≥MinSumVolumeMl）。

.PARAMETER OutputPath
  证据 JSON 落盘路径。未指定时只打印到 stdout，不写文件。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/verify-runtime-evidence.ps1 `
    -Keywords "gas_dp_below_allows_conduit_return,ConduitDelta" `
    -OutputPath "Assets/.../证据/20260721-step2-verify.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Keywords,

    [string]$ExpectAbsentKeywords,

    [ValidateSet("Any", "All")]
    [string]$Mode = "Any",

    [int]$SinceMinutes = 30,

    [string]$EditorLogPath = "$env:LOCALAPPDATA\Unity\Editor\Editor.log",

    [int]$TailLines = 20000,

    [Nullable[double]]$MinVolumeMl = $null,

    [Nullable[double]]$MinSumVolumeMl = $null,

    [string]$OutputPath
)

# 专用 unity-verify- 日志：未显式 -TailLines 时默认全文件（修 G1 LiquidIngress 假红）
if (-not $PSBoundParameters.ContainsKey('TailLines') -and
    $EditorLogPath -and ($EditorLogPath -match 'unity-verify-')) {
    $TailLines = 0
}

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

function New-Result {
    param($ok, $reason)
    [ordered]@{
        schema         = "verify-runtime-evidence/v1"
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        ok             = $ok
        reason         = $reason
        editorLogPath  = $EditorLogPath
        mode           = $Mode
        sinceMinutes   = $SinceMinutes
        keywords       = @()
        overallHit     = $false
        absentKeywords = @()
        anyAbsentHit   = $false
        fresh          = $false
        editorLogLastWriteUtc = $null
        ageMinutes     = $null
        compileErrors  = @()
        volumeMax      = $null
        volumeSum      = $null
        volumeSampleCount = 0
        minVolumeMl    = $null
        minSumVolumeMl = $null
        volumeGate     = "or"
        volumeGatePass = $true
    }
}

function Write-ResultAndExit {
    param($result, [int]$exitCode)

    $json = $result | ConvertTo-Json -Depth 6
    Write-Output $json

    if ($OutputPath) {
        $dir = Split-Path -Parent $OutputPath
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        # 带 BOM 的 UTF-8，避免中文关键词/样例行在部分工具里读成乱码
        [System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($true)))
    }

    exit $exitCode
}

# --- 0. 拆分逗号分隔的关键词字符串 ---
$KeywordList = @($Keywords -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
if ($KeywordList.Count -eq 0) {
    throw "Keywords 拆分后为空，请检查 -Keywords 参数（逗号分隔，例如 'kw1,kw2'）"
}

# --- 1. 日志文件存在性（不存在 = 不阻塞，如实上报） ---
if (-not (Test-Path -LiteralPath $EditorLogPath)) {
    $result = New-Result -ok $false -reason "editor_log_not_found"
    Write-ResultAndExit -result $result -exitCode 2
}

# --- 2. 新鲜度：文件最后写入时间 vs 窗口 ---
$logFile = Get-Item -LiteralPath $EditorLogPath
$ageMinutes = [Math]::Round(([DateTime]::UtcNow - $logFile.LastWriteTimeUtc).TotalMinutes, 1)
$fresh = $ageMinutes -le $SinceMinutes

# --- 3. 读取行（TailLines≤0 = 全文件；否则末尾 N 行） ---
# 注意：Get-Content 返回的字符串带有 FileSystem provider 挂的 PSPath/PSDrive 等隐藏
# NoteProperty；直接丢进 ConvertTo-Json -Depth>1 会把这些属性（含 PSDrive.Provider）
# 一起递归序列化，输出可以炸到几 MB。这里显式转成纯 [string]，去掉附加属性。
$rawLines = if ($TailLines -le 0) {
    Get-Content -LiteralPath $EditorLogPath -Encoding UTF8 -ErrorAction SilentlyContinue
} else {
    Get-Content -LiteralPath $EditorLogPath -Tail $TailLines -Encoding UTF8 -ErrorAction SilentlyContinue
}
$lines = [string[]]@()
if ($rawLines) {
    $lines = @($rawLines | ForEach-Object { [string]$_ })
}

# --- 4. 逐关键词统计命中 + 样例行（最多 5 条） ---
$keywordResults = @()
$hitCount = 0
foreach ($kw in $KeywordList) {
    $matchedLines = $lines | Where-Object { $_ -match [Regex]::Escape($kw) }
    $count = ($matchedLines | Measure-Object).Count
    if ($count -gt 0) { $hitCount++ }
    $samples = $matchedLines | Select-Object -Last 5
    $keywordResults += [ordered]@{
        keyword = $kw
        count   = $count
        samples = @($samples)
    }
}

$overallHit = if ($Mode -eq "All") { $hitCount -eq $KeywordList.Count } else { $hitCount -gt 0 }

# --- 4b. 不应命中的关键词（回归证据；任一命中即坏） ---
$absentKeywordResults = @()
$anyAbsentHit = $false
if ($ExpectAbsentKeywords) {
    $AbsentList = @($ExpectAbsentKeywords -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
    foreach ($kw in $AbsentList) {
        $matchedLines = $lines | Where-Object { $_ -match [Regex]::Escape($kw) }
        $count = ($matchedLines | Measure-Object).Count
        if ($count -gt 0) { $anyAbsentHit = $true }
        $absentKeywordResults += [ordered]@{
            keyword = $kw
            count   = $count
            samples = @($matchedLines | Select-Object -Last 5)
        }
    }
}

# --- 4c. Keywords 命中行上的 volume=…ml 解析 + Or 门禁 ---
$volumeEnabled = $PSBoundParameters.ContainsKey('MinVolumeMl') -or $PSBoundParameters.ContainsKey('MinSumVolumeMl')
$volRegex = New-Object System.Text.RegularExpressions.Regex(
    'volume=([0-9]*\.?[0-9]+)ml',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$volumeSamples = New-Object System.Collections.Generic.List[double]
foreach ($line in $lines) {
    $hitsAnyKw = $false
    foreach ($kw in $KeywordList) {
        if ($line -match [Regex]::Escape($kw)) { $hitsAnyKw = $true; break }
    }
    if (-not $hitsAnyKw) { continue }
    foreach ($m in $volRegex.Matches($line)) {
        [void]$volumeSamples.Add([double]$m.Groups[1].Value)
    }
}
$volumeSampleCount = $volumeSamples.Count
$volumeMax = if ($volumeSampleCount -gt 0) { ($volumeSamples | Measure-Object -Maximum).Maximum } else { $null }
$volumeSum = if ($volumeSampleCount -gt 0) { [Math]::Round(($volumeSamples | Measure-Object -Sum).Sum, 6) } else { $null }

$volumeGatePass = $true
$volumeFailReason = $null
if ($volumeEnabled) {
    if ($volumeSampleCount -eq 0) {
        $volumeGatePass = $false
        $volumeFailReason = "volume_samples_missing"
    } else {
        $hasMin = $PSBoundParameters.ContainsKey('MinVolumeMl')
        $hasSum = $PSBoundParameters.ContainsKey('MinSumVolumeMl')
        $maxOk = if ($hasMin) { $volumeMax -ge [double]$MinVolumeMl } else { $false }
        $sumOk = if ($hasSum) { $volumeSum -ge [double]$MinSumVolumeMl } else { $false }
        if ($hasMin -and $hasSum) {
            $volumeGatePass = $maxOk -or $sumOk
        } elseif ($hasMin) {
            $volumeGatePass = $maxOk
        } else {
            $volumeGatePass = $sumOk
        }
        if (-not $volumeGatePass) { $volumeFailReason = "volume_gate_fail" }
    }
}

# --- 5. 附带编译错误扫描（unity-editor-log.md §A） ---
$compileErrorLines = $lines | Where-Object { $_ -match "error CS\d{4}" } | Select-Object -Last 20

# --- 6. 汇总输出 ---
$result = New-Result -ok $true -reason $null
$result.editorLogLastWriteUtc = $logFile.LastWriteTimeUtc.ToString("o")
$result.ageMinutes = $ageMinutes
$result.fresh = $fresh
$result.keywords = $keywordResults
$result.overallHit = $overallHit
$result.absentKeywords = $absentKeywordResults
$result.anyAbsentHit = $anyAbsentHit
$result.compileErrors = @($compileErrorLines)
$result.volumeMax = $volumeMax
$result.volumeSum = $volumeSum
$result.volumeSampleCount = $volumeSampleCount
$result.minVolumeMl = if ($PSBoundParameters.ContainsKey('MinVolumeMl')) { [double]$MinVolumeMl } else { $null }
$result.minSumVolumeMl = if ($PSBoundParameters.ContainsKey('MinSumVolumeMl')) { [double]$MinSumVolumeMl } else { $null }
$result.volumeGate = "or"
$result.volumeGatePass = $volumeGatePass

if ($anyAbsentHit) {
    $result.reason = "expect_absent_keyword_hit"
} elseif (-not $fresh) {
    $result.reason = "stale_log_possibly_not_this_run"
} elseif ($volumeFailReason) {
    $result.reason = $volumeFailReason
}

$baseGreen = $fresh -and $overallHit -and -not $anyAbsentHit -and ($compileErrorLines.Count -eq 0)
$exitCode = if ($baseGreen -and $volumeGatePass) { 0 } else { 1 }
if (-not $baseGreen -or -not $volumeGatePass) { $result.ok = $false }
Write-ResultAndExit -result $result -exitCode $exitCode
