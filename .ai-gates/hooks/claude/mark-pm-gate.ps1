# mark-pm-gate.ps1 -- Claude Code 版
# Stop hook -- observation only, never blocks（Claude Code Stop 事件输出无拦截语义）。
#
# 与 Codex 版的关键差异（2026-08-10）：Claude Code Stop 输入 payload 只有
# session_id / transcript_path / stop_hook_active，**没有** last_assistant_message 字段。
# 因此"最后一条助手消息文本"改为读 transcript_path 指向的会话 JSONL：
#   逐行解析，type=="assistant" 的行取 message.content 文本（string 或 {type:text,text}[]
#   数组），取最后一条非空文本做 [PM]/Auto 检测（语义与 Codex 版一致：Stop 在消息完整
#   生成后触发，只证明"最近一轮完整回复里出现过 [PM]"）。
# transcript 缺失/不可读/解析失败 → 跳过打点（观测语义，fail-open，不阻塞任何东西）。
# 真机验证点 #3：transcript JSONL 结构与字段名待实机确认（line type / message.content）。
#
# 目的（与 Cursor/Codex 版一致）：把"这轮回复里出现过 [PM] 标记"写进带时间戳、按
# session_id 分桶的 pm-gate.json，供 pm-gate-check.ps1（PreToolUse）在下一次写操作时
# 读取判断是否放行。已知局限：标记只证明"之前某一轮完整回复里出现过 [PM]"，等价于把
# CORE 硬门禁 #7 的"同条先 PM"退化成机械可查的"最近 N 分钟内该会话有没有 PM 判定过"。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$gateFile = Join-Path $LogDir 'pm-gate.json'

$raw = Read-HookStdin
$sessionId = "unknown"
$transcriptPath = ""
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $sessionId = Get-SessionId -Json $json -Raw $raw
    $tp = Get-Property $json 'transcript_path'
    if ($tp) { $transcriptPath = [string]$tp }
} catch {
    # parse 失败兜底：正则提取 session_id + transcript_path，[PM] 检测仍执行
    $m = [Regex]::Match($raw, '"session_id"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m.Success) { $sessionId = $m.Groups[1].Value }
    $m2 = [Regex]::Match($raw, '"transcript_path"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m2.Success) { $transcriptPath = $m2.Groups[1].Value -replace '\\\\', '\' }
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("PARSE_FAIL session={0} transcript={1}" -f $sessionId, $transcriptPath)
}

# session_id 兜底：transcript 文件名即 session id（<uuid>.jsonl）
if ($sessionId -eq "unknown" -and $transcriptPath -and ($transcriptPath -match '([^\\/]+)\.jsonl$')) {
    $sessionId = $Matches[1]
}

# 读 transcript JSONL，取最后一条助手消息文本（Claude Stop 输入无 last_assistant_message）
$text = ""
$fieldUsed = "none"
if (-not $transcriptPath -or -not (Test-Path -LiteralPath $transcriptPath)) {
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("INFO transcript_missing session={0} path={1}" -f $sessionId, $transcriptPath)
} else {
    try {
        $lines = [System.IO.File]::ReadAllLines($transcriptPath, [System.Text.Encoding]::UTF8)
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $t = $null
            try {
                $t = $line | ConvertFrom-Json -ErrorAction Stop
            } catch { continue }  # 非 JSON 行（脏尾/中断写）跳过
            if ($t.type -ne 'assistant') { continue }
            if (-not $t.message -or -not $t.message.content) { continue }
            $content = $t.message.content
            if ($content -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace([string]$content)) {
                    $text = [string]$content
                    $fieldUsed = 'transcript:assistant.content(string)'
                }
            } elseif ($content -is [System.Array]) {
                $parts = @()
                foreach ($blk in $content) {
                    if ($blk.type -eq 'text' -and $blk.text) { $parts += [string]$blk.text }
                }
                if ($parts.Count -gt 0) {
                    $text = ($parts -join "`n")
                    $fieldUsed = 'transcript:assistant.content(text[])'
                }
            }
        }
    } catch {
        Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("INFO transcript_unreadable session={0} msg={1}" -f $sessionId, $_.Exception.Message)
    }
}

# [PM] 作为岗位标记出现（CORE.md：首行标记 [PM]）；不要求必须在行首，宁可宽松不漏判。
$hasPmMarker = $text -match [Regex]::Escape("[PM]")

# 2026-08-05：Auto 链审计打点（预算护栏配套，见 loop-engineering §4）。
# - 批准消息含 Auto（「准 auto」「继续 Auto」「本窗 Auto」）→ auto_active=true + auto_started_at
# - Auto 激活期间每次 Stop（含无 [PM] 的 [developer]/[CR] 轮）→ auto_rounds+1（审计用，不改门禁语义）
$hasAuto = $text -match '(?i)\bAuto\b'

$gate = [ordered]@{}
if (Test-Path -LiteralPath $gateFile) {
    try {
        $existingRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
        $existing = $existingRaw | ConvertFrom-Json -ErrorAction Stop
        $existing.PSObject.Properties | ForEach-Object { $gate[$_.Name] = $_.Value }
    } catch {
        # 旧文件损坏就当空表重建，不阻塞
    }
}

$prev = $gate.$sessionId
$prevAutoActive = $false
$prevRounds = 0
if ($prev) {
    if ($prev.auto_active) { $prevAutoActive = $true }
    if ($prev.auto_rounds) { $prevRounds = [int]$prev.auto_rounds }
}

if ($hasPmMarker) {
    $snippet = $text.Substring(0, [Math]::Min(160, $text.Length))
    $entry = [ordered]@{
        lastPmAtUtc = [DateTime]::UtcNow.ToString('o')
        snippet     = $snippet
        sourceField = $fieldUsed
    }
    if ($hasAuto) {
        $entry.auto_active    = $true
        $entry.auto_startedAt = [DateTime]::UtcNow.ToString('o')
        $entry.auto_rounds    = 0
    } elseif ($prevAutoActive) {
        # 已在 Auto 链中的新一轮 [PM] 确认：保留 Auto 状态并累计轮次
        $entry.auto_active    = $true
        if ($prev.auto_startedAt) { $entry.auto_startedAt = $prev.auto_startedAt }
        $entry.auto_rounds    = $prevRounds + 1
    }
    $gate[$sessionId] = $entry
    $json2 = $gate | ConvertTo-Json -Depth 6
    Write-JsonAtomic -Path $gateFile -Content $json2
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("session={0} field={1} hasPm=True auto={2} rounds={3} wrote=pm-gate.json" -f $sessionId, $fieldUsed, $hasAuto, $entry.auto_rounds)
} elseif ($prevAutoActive) {
    # Auto 链内非 [PM] 轮（developer/CR/verify 等）：累计轮次，供诊断与预算审计
    $prev.auto_rounds = $prevRounds + 1
    $gate[$sessionId] = $prev
    $json2 = $gate | ConvertTo-Json -Depth 6
    Write-JsonAtomic -Path $gateFile -Content $json2
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("session={0} field={1} hasPm=False auto_rounds_inc={2}" -f $sessionId, $fieldUsed, ($prevRounds + 1))
} else {
    Write-HookAudit -LogDir $LogDir -FileName 'mark-pm-gate.log' -Line ("session={0} field={1} hasPm=False wrote=none" -f $sessionId, $fieldUsed)
}

Emit-StopEmpty
