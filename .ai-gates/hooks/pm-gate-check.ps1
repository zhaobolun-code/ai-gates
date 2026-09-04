# pm-gate-check.ps1
# preToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 支柱 D。
#
# 目的：机械化 CORE.md 硬门禁 #7 的**窗口层**近似——"最近 N 分钟内这个会话（conversation_id）
# 有没有出现过 [PM] 标记"，标记由 mark-pm-gate.ps1（afterAgentResponse）写入
# .ai-gates/hooks-log/pm-gate.json。
#
# 两层不得混名（门禁补洞 A2）：
#   window_pm / window_pm_not_this_turn = 本 hook 能证明的：窗口内曾打点。
#   this_turn_pm = CORE #7「本条已完成结构化判定」。Cursor preToolUse 拿不到
#   正在生成的助手文本，机器层做不到 this_turn_pm。允许写入时 reason 必须带
#   window_pm_not_this_turn，禁止写成 this_turn_pm / 同条已判定。
#
# 行为（与 MAINTAINER §Cursor Hooks 一致）：
#   业务路径（非 .cursor/**）且无新鲜 [PM] 标记 → permission=deny + user_message 逃生提示。
#   2026-08-03 改：Cursor 2.2+ 的 hook `permission: ask` 是官方确认 bug（不弹窗直接放行），
#   ask 只剩审计意义；改 deny（硬拦）+ 逃生路径（发 [PM] / kill switch / 手动编辑），不逼死路。
#   解析异常 → fail-open allow（避免 hook/落盘故障把人逼进死路）
#   hooks.json 对本 hook 须 failClosed=false
#
# allow 旁路：
#   1. kill switch：存在 .ai-gates/hooks-log/pm-gate-disabled 时整条检查临时关闭（仍写审计）。
#   2. 该 conversation_id 在新鲜度窗口内有有效 [PM] 标记 → allow。
#   3. 业务路径 inherited_parent_pm：本 conversation 无新鲜 [PM]，但唯一父 transcript 的 lastPmAtUtc
#      在 120 分钟内 → allow。禁止任意会话有 PM 即放行；禁止 Level 1 走继承。
#
# .cursor/** 分级豁免（2026-08-03 自我治理轻门禁，替代原"全豁免"）：
#   Level 0 全豁免 allow：CHANGELOG.md 自身；.ai-gates/hooks-log/**（运行时目录：
#     pm-gate.json / changelog-writes.json / *.log）；项目专属 .cursor 文件
#     （project-context.md / regression-index.yaml / lessons-* / pipeline-recovery-log.md
#     / pipeline-snapshot.log / pipeline-outcome.log 等，延续自救精神）。
#   Level 1 轻门禁（deny 硬拦 + 逃生）：.cursor/skills/**、.cursor/hooks/**、.cursor/scripts/**、
#     .cursor/hooks.json、.cursor/rules/** → 查 changelog-writes.json 该 conversation
#     最近 $FreshnessMinutes 分钟内有 CHANGELOG 写记录 → allow（reason=recent_changelog_write）；
#     无 → permission: deny（逃生：先写 CHANGELOG / kill switch / 手动编辑）；
#     打点文件缺失 → deny（初始状态 = 无任何会话有流水）；JSON 损坏 / 时间戳不可解析 → fail-open allow。
#   Level 2 兜底 allow：其余 .cursor/**（package-release.ps1、README.md、mcp.json、
#     LICENSE、ai_dev_*.7z、_release_staging/ 等）——打包产物/临时文件必然无 CHANGELOG 流水，
#     纳入轻门禁会频繁误 ask；自救通道延续。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$gateFile = Join-Path $logDir "pm-gate.json"
$changelogFile = Join-Path $logDir "changelog-writes.json"
$killSwitch = Join-Path $logDir "pm-gate-disabled"
$auditFile = Join-Path $logDir "pm-gate-check.log"

$FreshnessMinutes = 120

function Write-Audit {
    param([string]$Line)
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
    }
}

function Test-CursorInfraPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    return ($FilePath -match '[\\/]\.(cursor|ai-gates|codex)[\\/]' -or $FilePath -match '^\.(cursor|ai-gates|codex)[\\/]')
}

# 归一化：返回 .cursor/ 或 .ai-gates/ 之后的相对部分（统一正斜杠），供 Level 0/1 判定复用；
# .codex/** 映射为 codex/ 前缀（接线设施，Level 1）。
function Get-CursorRelativePath {
    param([string]$FilePath)
    if (-not $FilePath) { return $null }
    $norm = $FilePath -replace '\\', '/'
    $m = [Regex]::Match($norm, '(?:^|/)\.(cursor|ai-gates)/(.*)$')
    if ($m.Success) { return $m.Groups[2].Value }
    $m2 = [Regex]::Match($norm, '(?:^|/)\.codex/(.*)$')
    if ($m2.Success) { return 'codex/' + $m2.Groups[1].Value }
    return $null
}

# Level 0 全豁免：CHANGELOG.md 自身 / hooks-log 运行时 / 项目专属 .cursor 文件
function Test-CursorLevel0Path {
    param([string]$FilePath)
    $rel = Get-CursorRelativePath -FilePath $FilePath
    if (-not $rel) { return $false }
    # CHANGELOG.md 自身（路径以 changelog.md 结尾即可，大小写不敏感）
    if ($rel -match '(?i)(?:^|[\\/])changelog\.md$') { return $true }
    # .ai-gates/hooks-log/** 运行时目录（pm-gate.json / changelog-writes.json / *.log）
    if ($rel -match '(?:^|/)hooks-log(?:/|$)') { return $true }
    # 项目专属 .cursor 文件（自救通道延续；MAINTAINER §目录与同步策略）
    if ($rel -match '(?:^|/)(project-context\.md|regression-index\.yaml|lessons-[^/]*|pipeline-recovery-log\.md|pipeline-snapshot\.log|pipeline-outcome\.log)$') { return $true }
    return $false
}

# Level 1 轻门禁：skill/hook/script/rules 设施 + hooks.json
function Test-CursorLevel1Path {
    param([string]$FilePath)
    $rel = Get-CursorRelativePath -FilePath $FilePath
    if (-not $rel) { return $false }
    if ($rel -match '(?:^|/)(skills|hooks|scripts|rules)(?:/|$)') { return $true }
    if ($rel -eq 'hooks.json') { return $true }
    if ($rel -match '^codex(?:/|$)') { return $true }
    return $false
}

function Get-PathFromRaw {
    param([string]$Raw)
    foreach ($pat in @(
        '"file_path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"target_notebook"\s*:\s*"((?:\\.|[^"\\])*)"'
    )) {
        $m = [Regex]::Match($Raw, $pat)
        if ($m.Success) {
            $s = $m.Groups[1].Value -replace '\\/', '/' -replace '\\\\', '\'
            return $s
        }
    }
    return $null
}

function Emit-Allow {
    param([string]$Reason)
    Write-Audit "ALLOW reason=$Reason"
    $payload = @{ permission = "allow"; reason = $Reason }
    Write-Output ($payload | ConvertTo-Json -Compress)
}

function Emit-Deny {
    param([string]$ConversationId, [string]$Detail, [string]$UserHint = "", [string]$BaseMsg = "")
    Write-Audit "DENY conversation=$ConversationId detail=$Detail"
    # Cursor 2.2+ 的 hook `permission: ask` 是官方确认的已知 bug（不弹窗直接放行，
    # 见 forum.cursor.com/t/hooks-ask-permission-broken-in-2-4-21）——ask 只剩审计意义，
    # 门禁实际失效。2026-08-03 起改 deny + user_message 逃生提示（官方 workaround）。
    # BaseMsg 分场景：业务路径提示 [PM] 标记；Level 1 提示 CHANGELOG 流水
    # （2026-08-03 真演教训：统一文案误导 agent 以为发 [PM] 能解锁 Level 1）。
    if (-not $BaseMsg) {
        $BaseMsg = "PM gate deny detail=$Detail : no window_pm (no [PM] marker within $FreshnessMinutes min). This is the 120-min window, NOT this_turn_pm / CORE #7 same-turn judgment. Escape: emit [PM] in reply / edit .cursor path / place hooks-log/pm-gate-disabled, then retry."
    }
    if ($UserHint) {
        $userMsg = "$BaseMsg $UserHint"
    } else {
        $userMsg = $BaseMsg
    }
    $agentMsg = "preToolUse: conversation=$ConversationId no fresh [PM] within $FreshnessMinutes min ($Detail); deny (hard block, Cursor 2.2+ ask bug; follow user_message escape paths)."
    $result = @{
        permission    = "deny"
        user_message  = $userMsg
        agent_message = $agentMsg
    }
    Write-Output ($result | ConvertTo-Json -Compress)
}

# 业务路径子窗继承：仅当本 conversation 无新鲜 [PM]，且唯一父 transcript 存在，且
# （父 lastPmAtUtc 在 120 分钟内，或父 transcript 近 120 分钟内已含字面 [PM]）。
# 禁止任意会话有 PM 即放行。找不到父 / 父不新鲜 / 父文件>1 / conversation_id=unknown → 仍 DENY。禁止把 Level 1 改成继承。
function Resolve-UniqueParentConversationId {
    param([string]$ChildId)
    if ([string]::IsNullOrWhiteSpace($ChildId) -or $ChildId -eq "unknown") {
        return $null
    }
    $projectsRoot = Join-Path $env:USERPROFILE ".cursor\projects"
    if (-not (Test-Path -LiteralPath $projectsRoot)) { return $null }
    $hits = New-Object System.Collections.Generic.List[string]
    try {
        $projDirs = [System.IO.Directory]::GetDirectories($projectsRoot)
    } catch {
        return $null
    }
    foreach ($proj in $projDirs) {
        $transcriptsRoot = Join-Path $proj "agent-transcripts"
        if (-not [System.IO.Directory]::Exists($transcriptsRoot)) { continue }
        try {
            $parentDirs = [System.IO.Directory]::GetDirectories($transcriptsRoot)
        } catch {
            continue
        }
        foreach ($parentDir in $parentDirs) {
            $childFile = Join-Path $parentDir ("subagents\" + $ChildId + ".jsonl")
            if ([System.IO.File]::Exists($childFile)) {
                $hits.Add([System.IO.Path]::GetFileName($parentDir))
            }
        }
    }
    if ($hits.Count -ne 1) { return $null }
    return $hits[0]
}

function Test-ParentTranscriptHasRecentPm {
    param([string]$ParentId)
    if ([string]::IsNullOrWhiteSpace($ParentId) -or $ParentId -eq "unknown") { return $false }
    $projectsRoot = Join-Path $env:USERPROFILE ".cursor\projects"
    if (-not (Test-Path -LiteralPath $projectsRoot)) { return $false }
    try {
        $projDirs = [System.IO.Directory]::GetDirectories($projectsRoot)
    } catch {
        return $false
    }
    foreach ($proj in $projDirs) {
        $file = Join-Path $proj ("agent-transcripts\" + $ParentId + "\" + $ParentId + ".jsonl")
        if (-not [System.IO.File]::Exists($file)) { continue }
        try {
            $info = New-Object System.IO.FileInfo $file
            $ageMin = ([DateTime]::UtcNow - $info.LastWriteTimeUtc).TotalMinutes
            if ($ageMin -gt $FreshnessMinutes) { continue }
            $len = $info.Length
            if ($len -le 0) { continue }
            $start = [Math]::Max([int64]0, $len - 524288)
            $fs = [System.IO.File]::Open($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $null = $fs.Seek($start, [System.IO.SeekOrigin]::Begin)
                $toRead = [int]($len - $start)
                $buf = New-Object byte[] $toRead
                $read = $fs.Read($buf, 0, $toRead)
            } finally {
                $fs.Dispose()
            }
            $text = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
            if ($text.Contains('[PM]')) { return $true }
        } catch {
            continue
        }
    }
    return $false
}

function Get-ChildSessionDenyHint {
    return "子窗不要发 [PM]，也不要把 [PM] 写进 resume 提示词。主窗须在自己的回复里发出 [PM]，等 afterAgentResponse 写入 pm-gate.json 后再派或续写。或主窗代写并标明未开子窗。或放置 hooks-log/pm-gate-disabled / 手动编辑。"
}

function Get-InheritedParentPmReason {
    param(
        [string]$ConversationId,
        $Gate
    )
    if ($ConversationId -eq "unknown") { return $null }
    $parentId = Resolve-UniqueParentConversationId -ChildId $ConversationId
    if (-not $parentId) { return $null }
    $parentEntry = $Gate.$parentId
    if ($parentEntry -and $parentEntry.lastPmAtUtc) {
        try {
            $parentPmUtc = [DateTime]::Parse($parentEntry.lastPmAtUtc).ToUniversalTime()
            $parentAgeMinutes = ([DateTime]::UtcNow - $parentPmUtc).TotalMinutes
            if ($parentAgeMinutes -le $FreshnessMinutes) {
                return ("window_pm_not_this_turn_inherited_parent_pm_age={0}min parent={1}" -f [Math]::Round($parentAgeMinutes, 1), $parentId)
            }
        } catch { }
    }
    if (Test-ParentTranscriptHasRecentPm -ParentId $parentId) {
        return ("window_pm_not_this_turn_inherited_parent_pm_transcript parent={0}" -f $parentId)
    }
    return $null
}

# kill switch first (no stdin parse needed)
if (Test-Path -LiteralPath $killSwitch) {
    Emit-Allow "kill_switch_active"
    return
}

$raw = ""
try {
    $raw = Read-HookStdin
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    $fallbackPath = Get-PathFromRaw -Raw $raw
    if (Test-CursorInfraPath -FilePath $fallbackPath) {
        Emit-Allow "cursor_infra_path_exempt_parse_fallback"
        return
    }
    # fail-open：解析失败不硬拦（与 MAINTAINER 一致；避免 mark 落盘故障连环死路）
    Emit-Allow "parse_failed_fail_open"
    return
}

$conversationId = if ($json.conversation_id) { [string]$json.conversation_id } else { "unknown" }

$filePath = $null
if ($json.tool_input) {
    if ($json.tool_input.file_path) { $filePath = [string]$json.tool_input.file_path }
    elseif ($json.tool_input.path) { $filePath = [string]$json.tool_input.path }
    elseif ($json.tool_input.target_notebook) { $filePath = [string]$json.tool_input.target_notebook }
}

# --- .cursor/** 分级（2026-08-03 自我治理轻门禁） ---
if (Test-CursorInfraPath -FilePath $filePath) {
    # Level 0 全豁免（kill switch 已最优先处理）
    if (Test-CursorLevel0Path -FilePath $filePath) {
        Emit-Allow "cursor_level0_exempt"
        return
    }
    # Level 1 轻门禁：查 changelog-writes.json 会话内新鲜 CHANGELOG 写记录
    if (Test-CursorLevel1Path -FilePath $filePath) {
        # Level 1 专用 BaseMsg：明确此门禁看 CHANGELOG 写流水、不看 [PM] 标记
        # （2026-08-03 真演教训：统一文案误导 agent 以为发 [PM] 能解锁 Level 1）。
        $level1BaseMsg = "PM gate Level-1 deny : no fresh CHANGELOG write for this conversation within $FreshnessMinutes min (changing .cursor facilities requires a CHANGELOG entry; this gate does NOT read [PM] markers). Escape: write CHANGELOG first / place hooks-log/pm-gate-disabled / manual edit, then retry."
        # 打点文件缺失 = 系统里还没有任何会话成功写过 CHANGELOG（初始状态）——本会话
        # 必然无流水，与「有文件但无记录」同语义 → deny + 逃生提示（2026-08-03 两连修：
        # 先 fail-open allow → ask；再因 Cursor 2.2+ ask 无效 → deny）。
        if (-not (Test-Path -LiteralPath $changelogFile)) {
            $hint = "逃生：先写 .ai-gates/CHANGELOG.md（CHANGELOG 自身 Level 0 豁免）后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch，临时全放行）后重试；或手动编辑目标文件。"
            Emit-Deny -ConversationId $conversationId -Detail "changelog_writes_missing_level1" -UserHint $hint -BaseMsg $level1BaseMsg
            return
        }
        try {
            $changelogRaw = [System.IO.File]::ReadAllText($changelogFile, [System.Text.Encoding]::UTF8)
            $changelog = $changelogRaw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Emit-Allow "changelog_writes_unreadable_fail_open"
            return
        }
        # 语法合法但顶层非对象（数组/标量，如 [..] / ".." / null）时 ConvertFrom-Json
        # 不抛错，$changelog.$conversationId 恒为 $null 会误走 ask——与「JSON 损坏 →
        # fail-open allow」语义一致，此处同样按损坏处理直接放行。
        if (-not ($changelog -is [System.Management.Automation.PSCustomObject])) {
            Emit-Allow "changelog_writes_nonobject_fail_open"
            return
        }
        $changelogEntry = $changelog.$conversationId
        if (-not $changelogEntry -or -not $changelogEntry.lastChangelogWriteAtUtc) {
            # 无 CHANGELOG 写记录 → deny（硬拦，Cursor 2.2+ ask 无效），提示逃生路径
            $hint = "逃生：先写 .ai-gates/CHANGELOG.md（CHANGELOG 自身 Level 0 豁免）后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
            Emit-Deny -ConversationId $conversationId -Detail "no_changelog_write_for_conversation_level1" -UserHint $hint -BaseMsg $level1BaseMsg
            return
        }
        try {
            $lastChangelogUtc = [DateTime]::Parse($changelogEntry.lastChangelogWriteAtUtc).ToUniversalTime()
        } catch {
            Emit-Allow "changelog_timestamp_unparseable_fail_open"
            return
        }
        $changelogAgeMinutes = ([DateTime]::UtcNow - $lastChangelogUtc).TotalMinutes
        if ($changelogAgeMinutes -gt $FreshnessMinutes) {
            $hint = "逃生：重新写 .ai-gates/CHANGELOG.md（Included 条目）后再试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
            Emit-Deny -ConversationId $conversationId -Detail ("stale_changelog_write_age={0}min_level1" -f [Math]::Round($changelogAgeMinutes,1)) -UserHint $hint -BaseMsg $level1BaseMsg
            return
        }
        Emit-Allow ("recent_changelog_write_age={0}min" -f [Math]::Round($changelogAgeMinutes,1))
        return
    }
    # Level 2 兜底：其余 .cursor/**（package-release.ps1 / README.md / mcp.json / LICENSE /
    # ai_dev_*.7z / _release_staging/ 等）保持 allow——打包产物/临时文件无 CHANGELOG 流水
    Emit-Allow "cursor_level2_fallback"
    return
}

# --- 业务路径：原 PM 标记新鲜度检查不变（ask→deny，Cursor 2.2+ ask 无效） ---
if (-not (Test-Path -LiteralPath $gateFile)) {
    $hint = "逃生：先在本会话回复中发出 [PM] 标记（如「PM 判定：…」），待 mark-pm-gate 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
    Emit-Deny -ConversationId $conversationId -Detail "gate_file_missing" -UserHint $hint
    return
}

try {
    $gateRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
    $gate = $gateRaw | ConvertFrom-Json -ErrorAction Stop
} catch {
    $hint = "逃生：先在本会话回复中发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
    Emit-Deny -ConversationId $conversationId -Detail "gate_file_unreadable" -UserHint $hint
    return
}

$entry = $gate.$conversationId
if (-not $entry -or -not $entry.lastPmAtUtc) {
    $inheritReason = Get-InheritedParentPmReason -ConversationId $conversationId -Gate $gate
    if ($inheritReason) { Emit-Allow $inheritReason; return }
    $parentId = Resolve-UniqueParentConversationId -ChildId $conversationId
    if ($parentId) {
        Emit-Deny -ConversationId $conversationId -Detail "parent_pm_not_marked" -UserHint (Get-ChildSessionDenyHint) -BaseMsg "PM gate deny detail=parent_pm_not_marked : unique parent transcript found but parent has no fresh [PM]. Child must not emit [PM]."
        return
    }
    $hint = "逃生：先在本会话回复中发出 [PM] 标记（如「PM 判定：…」），待 mark-pm-gate 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
    Emit-Deny -ConversationId $conversationId -Detail "no_pm_marker_for_conversation" -UserHint $hint
    return
}

try {
    $lastPmUtc = [DateTime]::Parse($entry.lastPmAtUtc).ToUniversalTime()
} catch {
    $hint = "逃生：先在本会话回复中重新发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
    Emit-Deny -ConversationId $conversationId -Detail "timestamp_unparseable" -UserHint $hint
    return
}

$ageMinutes = ([DateTime]::UtcNow - $lastPmUtc).TotalMinutes
if ($ageMinutes -gt $FreshnessMinutes) {
    $inheritReason = Get-InheritedParentPmReason -ConversationId $conversationId -Gate $gate
    if ($inheritReason) { Emit-Allow $inheritReason; return }
    $parentId = Resolve-UniqueParentConversationId -ChildId $conversationId
    if ($parentId) {
        Emit-Deny -ConversationId $conversationId -Detail "parent_pm_not_marked" -UserHint (Get-ChildSessionDenyHint) -BaseMsg "PM gate deny detail=parent_pm_not_marked : unique parent transcript found but parent has no fresh [PM]. Child must not emit [PM]."
        return
    }
    $hint = "逃生：先在本会话回复中重新发出 [PM] 标记（标记已超 $FreshnessMinutes 分钟），待打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。"
    Emit-Deny -ConversationId $conversationId -Detail ("stale_pm_marker_age={0}min" -f [Math]::Round($ageMinutes,1)) -UserHint $hint
    return
}

Emit-Allow ("window_pm_not_this_turn_age={0}min" -f [Math]::Round($ageMinutes,1))
