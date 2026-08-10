# pm-gate-check.ps1 -- Claude Code 版
# PreToolUse hook (matcher: ^(Write|Edit|MultiEdit|NotebookEdit)$) -- 支柱 D。
#
# 与 Codex 版同源（2026-08-10 复制改写）：Claude Code 写工具输入为结构化字段
# （Write/Edit/MultiEdit=file_path，NotebookEdit=notebook_path），由 Get-TargetPaths 提取。
# 语义与 Cursor/Codex 版一致（见 MAINTAINER §Cursor Hooks）：
#   业务路径（非 .cursor/.ai-gates/.codex/.claude 设施）且无新鲜 [PM] 标记 →
#   permissionDecision=deny + reason 逃生提示。解析异常 → fail-open allow。
# 2026-08-10 Claude Code 契约：显式 allow 受支持（permissionDecision:"allow"）；
# deny 必须带非空 permissionDecisionReason（引擎呈现为 "Blocked by PreToolUse hook: ..."）。
#
# allow 旁路：
#   1. kill switch：存在 .ai-gates/hooks-log/pm-gate-disabled 时整条检查临时关闭（仍写审计）。
#   2. 该 session_id 在新鲜度窗口内有有效 [PM] 标记 → allow。
#
# 设施分级豁免（与 Cursor/Codex 版一致，2026-08-10 新增 .claude 接线设施）：
#   Level 0 全豁免 allow：CHANGELOG.md 自身；.ai-gates/hooks-log/**（运行时目录）；项目专属
#     .cursor 文件（project-context.md / regression-index.yaml / lessons-* / pipeline-*）；
#     .claude/settings.local.json（机器本地配置，gitignore，非交付物）。
#   Level 1 轻门禁（deny 硬拦 + 逃生）：.cursor/skills|hooks|scripts|rules/**、.cursor/hooks.json、
#     .codex/**、.claude/**（settings.json 接线、agents/、skills/ 传送门内容）→ 查
#     changelog-writes.json 该 session 最近 $FreshnessMinutes 分钟内有 CHANGELOG 写记录 → allow；
#     无 → deny（逃生：先写 CHANGELOG / kill switch / 手动编辑）；打点文件缺失 → deny（初始状态）；
#     损坏/时间戳不可解析 → fail-open allow。
#   Level 2 兜底 allow：其余设施文件（package-release.ps1、mcp.json、LICENSE、
#     ai_dev_*.7z、_release_staging/ 等）。根文档（README/SKILLS/USER-GUIDE/METHODOLOGY）2026-08-05 起
#     升入 Level 1：与 CORE 硬门禁 #7「README 属交付物」及「改 .ai-gates 设施先写 CHANGELOG」对齐。
#
# 混合写（业务 + 设施）语义（2026-08-04）：两道门禁都须通过——业务路径查
# [PM] 标记、设施路径查 CHANGELOG 流水；任一道 deny 即拦截（最严格者胜，不短路）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$gateFile = Join-Path $LogDir 'pm-gate.json'
$changelogFile = Join-Path $LogDir 'changelog-writes.json'
$killSwitch = Join-Path $LogDir 'pm-gate-disabled'

$FreshnessMinutes = 120

function Test-CursorInfraPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    return ($FilePath -match '[\\/]\.(cursor|ai-gates|codex|claude)[\\/]' -or $FilePath -match '^\.(cursor|ai-gates|codex|claude)[\\/]')
}

# 归一化：返回 .cursor/ 或 .ai-gates/ 之后的相对部分（统一正斜杠），供 Level 0/1 判定复用；
# .codex/** 映射为 codex/ 前缀、.claude/** 映射为 claude/ 前缀（接线设施，Level 1）。
function Get-CursorRelativePath {
    param([string]$FilePath)
    if (-not $FilePath) { return $null }
    $norm = $FilePath -replace '\\', '/'
    $m = [Regex]::Match($norm, '(?:^|/)\.(cursor|ai-gates)/(.*)$')
    if ($m.Success) { return $m.Groups[2].Value }
    $m2 = [Regex]::Match($norm, '(?:^|/)\.codex/(.*)$')
    if ($m2.Success) { return 'codex/' + $m2.Groups[1].Value }
    $m3 = [Regex]::Match($norm, '(?:^|/)\.claude/(.*)$')
    if ($m3.Success) { return 'claude/' + $m3.Groups[1].Value }
    return $null
}

function Test-CursorLevel0Path {
    param([string]$FilePath)
    $rel = Get-CursorRelativePath -FilePath $FilePath
    if (-not $rel) { return $false }
    if ($rel -match '(?i)(?:^|/)changelog\.md$') { return $true }
    if ($rel -match '(?:^|/)hooks-log(?:/|$)') { return $true }
    if ($rel -match '(?:^|/)(project-context\.md|regression-index\.yaml|lessons-[^/]*|pipeline-recovery-log\.md|pipeline-snapshot\.log|pipeline-outcome\.log)$') { return $true }
    return $false
}

function Test-CursorLevel1Path {
    param([string]$FilePath)
    $rel = Get-CursorRelativePath -FilePath $FilePath
    if (-not $rel) { return $false }
    # 机器本地配置（.claude/settings.local.json，gitignore）→ 不算 Level 1，走 Level 0/2 豁免
    if ($rel -match '(?:^|/)(settings\.local\.json)$') { return $false }
    if ($rel -match '(?:^|/)(skills|hooks|scripts|rules)(?:/|$)') { return $true }
    if ($rel -eq 'hooks.json') { return $true }
    if ($rel -match '^codex(?:/|$)') { return $true }
    if ($rel -match '^claude(?:/|$)') { return $true }
    if ($rel -match '(?i)^(README|SKILLS|USER-GUIDE|METHODOLOGY)\.md$') { return $true }
    return $false
}

# 业务门禁：无新鲜 [PM] → 返回 deny reason 字符串（主流程 emit+return）；通过返回 $true
function Test-BusinessGate {
    param([string]$SessionId)
    if (-not (Test-Path -LiteralPath $gateFile)) {
        $hint = "逃生：先在本会话回复中发出 [PM] 标记（如「PM 判定：…」），待 Stop hook 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=gate_file_missing" -f $SessionId)
        return ("PM gate deny detail=gate_file_missing : no fresh [PM] marker detected. " + $hint)
    }
    try {
        $gateRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
        $gate = $gateRaw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $hint = "逃生：先在本会话回复中发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=gate_file_unreadable" -f $SessionId)
        return ("PM gate deny detail=gate_file_unreadable : no fresh [PM] marker detected. " + $hint)
    }
    $entry = $gate.$SessionId
    if (-not $entry -or -not $entry.lastPmAtUtc) {
        $hint = "逃生：先在本会话回复中发出 [PM] 标记（如「PM 判定：…」），待 Stop hook 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=no_pm_marker_for_session" -f $SessionId)
        return ("PM gate deny detail=no_pm_marker_for_session : no fresh [PM] marker detected. " + $hint)
    }
    try {
        $lastPmUtc = [DateTime]::Parse($entry.lastPmAtUtc).ToUniversalTime()
    } catch {
        $hint = "逃生：先在本会话回复中重新发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=timestamp_unparseable" -f $SessionId)
        return ("PM gate deny detail=timestamp_unparseable : no fresh [PM] marker detected. " + $hint)
    }
    $ageMinutes = ([DateTime]::UtcNow - $lastPmUtc).TotalMinutes
    if ($ageMinutes -gt $FreshnessMinutes) {
        $hint = "逃生：先在本会话回复中重新发出 [PM] 标记（标记已超 $FreshnessMinutes 分钟），待打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=stale_pm_marker_age={1}min" -f $SessionId, [Math]::Round($ageMinutes, 1))
        return (("PM gate deny detail=stale_pm_marker_age={0}min : no fresh [PM] marker detected. " -f [Math]::Round($ageMinutes, 1)) + $hint)
    }
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("ALLOW fresh_pm_marker_age={0}min" -f [Math]::Round($ageMinutes, 1))
    return $true
}

# Level 1 轻门禁：无会话内新鲜 CHANGELOG 流水 → 返回 deny reason 字符串（主流程 emit+return）；通过返回 $true
function Test-Level1Gate {
    param([string]$SessionId)
    $level1BaseMsg = "PM gate Level-1 deny : no fresh CHANGELOG write for this session within $FreshnessMinutes min (changing .cursor facilities requires a CHANGELOG entry; this gate does NOT read [PM] markers)."
    if (-not (Test-Path -LiteralPath $changelogFile)) {
        $hint = "逃生：先写 .ai-gates/CHANGELOG.md（CHANGELOG 自身 Level 0 豁免）后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch，临时全放行）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=changelog_writes_missing_level1" -f $SessionId)
        return ($level1BaseMsg + ' ' + $hint)
    }
    try {
        $changelogRaw = [System.IO.File]::ReadAllText($changelogFile, [System.Text.Encoding]::UTF8)
        $changelog = $changelogRaw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW changelog_writes_unreadable_fail_open'
        return $true
    }
    if (-not ($changelog -is [System.Management.Automation.PSCustomObject])) {
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW changelog_writes_nonobject_fail_open'
        return $true
    }
    $changelogEntry = $changelog.$SessionId
    if (-not $changelogEntry -or -not $changelogEntry.lastChangelogWriteAtUtc) {
        $hint = "逃生：先写 .ai-gates/CHANGELOG.md（CHANGELOG 自身 Level 0 豁免）后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=no_changelog_write_for_session_level1" -f $SessionId)
        return ($level1BaseMsg + ' ' + $hint)
    }
    try {
        $lastChangelogUtc = [DateTime]::Parse($changelogEntry.lastChangelogWriteAtUtc).ToUniversalTime()
    } catch {
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW changelog_timestamp_unparseable_fail_open'
        return $true
    }
    $changelogAgeMinutes = ([DateTime]::UtcNow - $lastChangelogUtc).TotalMinutes
    if ($changelogAgeMinutes -gt $FreshnessMinutes) {
        $hint = "逃生：重新写 .ai-gates/CHANGELOG.md（Included 条目）后再试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
        Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("DENY session={0} detail=stale_changelog_write_age={1}min_level1" -f $SessionId, [Math]::Round($changelogAgeMinutes, 1))
        return ($level1BaseMsg + ' ' + $hint)
    }
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("ALLOW recent_changelog_write_age={0}min" -f [Math]::Round($changelogAgeMinutes, 1))
    return $true
}

# kill switch first (no stdin parse needed)
if (Test-Path -LiteralPath $killSwitch) {
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW kill_switch_active'
    Write-Output (Emit-PreToolUseAllow)
    return
}

$raw = Read-HookStdin
$json = $null
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    # fail-open：解析失败不硬拦（与 MAINTAINER 一致；避免 mark 落盘故障连环死路）
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line 'ALLOW parse_failed_fail_open'
    Write-Output (Emit-PreToolUseAllow)
    return
}

$sessionId = Get-SessionId -Json $json -Raw $raw
$paths = @(Get-TargetPaths -ToolInput $json.tool_input -Raw $raw)

if ($paths.Count -eq 0) {
    # 无法提取路径：无法证明豁免，按业务路径走门禁（保守；逃生通道仍可用）
    Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("INFO session={0} no_path_extracted_treat_as_business" -f $sessionId)
    $paths = @("__no_path__")
}

$hasBusiness = $false
$hasLevel1 = $false
$hasLevel0Or2 = $false
foreach ($p in $paths) {
    if (-not (Test-CursorInfraPath -FilePath $p)) { $hasBusiness = $true }
    elseif (Test-CursorLevel1Path -FilePath $p) { $hasLevel1 = $true }
    else { $hasLevel0Or2 = $true }
}

# 两道门禁都须通过（业务查 [PM]、.cursor 设施查 CHANGELOG）；任一道 deny 即拦截
if ($hasBusiness) {
    $gateResult = Test-BusinessGate -SessionId $sessionId
    if ($gateResult -ne $true) {
        Write-Output (Emit-PreToolUseDeny -Reason $gateResult)
        return
    }
}
if ($hasLevel1) {
    $gateResult = Test-Level1Gate -SessionId $sessionId
    if ($gateResult -ne $true) {
        Write-Output (Emit-PreToolUseDeny -Reason $gateResult)
        return
    }
}

# 业务门禁 + Level 1 均通过（或仅 Level 0/Level 2 豁免路径）
Write-HookAudit -LogDir $LogDir -FileName 'pm-gate-check.log' -Line ("ALLOW gates_passed paths={0}" -f ($paths -join ','))
Emit-PreToolUseAllow
