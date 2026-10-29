# gate-decision.ps1
# 判定真源。Cursor / Claude / Codex 的薄入口点源本文件。
# 本文件不读 stdin，不写 permission / permissionDecision。
# 宿主差异留在入口：允许时的字段名、会话键、Claude 是否把 .claude 当设施。

function Get-DangerousGitRules {
    return @(
        @{ Pattern = 'git\s+push\b[^\n]*(--force(?!-with-lease)\b|\s-f\b|\s\+\S+)'; Reason = '强制推送（--force / -f / +引用）可能覆盖远端历史，无法找回' },
        @{ Pattern = 'git\s+reset\b[^\n]*--hard\b'; Reason = '硬重置（--hard）会丢弃未提交的工作区改动' },
        @{ Pattern = 'git\s+clean\b[^\n]*-[a-zA-Z]*[dfx]'; Reason = 'git clean 会永久删除未跟踪文件' },
        @{ Pattern = 'git\s+checkout\b[^\n]*(--force(?!-with-lease)\b|\s-f\b|--\s|\.$|\s\.\s)'; Reason = 'checkout -f / --force 或 checkout 路径会丢弃未提交改动（对应「方案推翻」流程，须已征得用户确认）' },
        @{ Pattern = 'git\s+branch\b[^\n]*-D\b'; Reason = '强制删除分支（-D）不检查是否已合并' }
    )
}

function Get-NormalizedGitCommand {
    param([string]$CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return '' }
    $text = $CommandText -replace '(?i)\bgit\.exe\b', 'git'
    $opt = '(?:-C\s+(?:"[^"]*"|''[^'']*''|\S+)|--git-dir(?:=|\s+)(?:"[^"]*"|''[^'']*''|\S+)|--work-tree(?:=|\s+)(?:"[^"]*"|''[^'']*''|\S+))'
    $guard = 0
    while ($guard -lt 30 -and $text -match ('(?i)(\bgit\s+)' + $opt + '\s+')) {
        $text = [regex]::Replace($text, ('(?i)(\bgit\s+)' + $opt + '\s+'), '$1', 1)
        $guard++
    }
    return $text
}

function Test-GitCommandUnparsed {
    param([string]$CommandText)
    $norm = Get-NormalizedGitCommand -CommandText $CommandText
    return [bool]($norm -match '(?i)(?:^|[\r\n;&|])\s*git\s+-{1,2}\S')
}

function Test-DangerousGitCommand {
    param([string]$CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return $null }
    $norm = Get-NormalizedGitCommand -CommandText $CommandText
    foreach ($rule in (Get-DangerousGitRules)) {
        if ($norm -match $rule.Pattern) { return [string]$rule.Reason }
    }
    return $null
}

function Test-GitForceWithLease {
    param([string]$CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return $false }
    $norm = Get-NormalizedGitCommand -CommandText $CommandText
    return [bool]($norm -match 'git\s+push\b[^\n]*--force-with-lease\b')
}

function Get-ExplicitWritePaths {
    param([string]$CommandText)
    $paths = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return @($paths) }

    $cmdletPat = '(?i)\b(?:Set-Content|Add-Content|Out-File|Clear-Content)\b[^\r\n]*'
    foreach ($m in [Regex]::Matches($CommandText, $cmdletPat)) {
        $seg = $m.Value
        $flagQuoted = '(?i)(?:-Path|-LiteralPath|-FilePath)\s+["'']([^"'']+)["'']'
        $fm = [Regex]::Match($seg, $flagQuoted)
        if (-not $fm.Success) {
            $flagBare = '(?i)(?:-Path|-LiteralPath|-FilePath)\s+([^\s"'']+)'
            $fm = [Regex]::Match($seg, $flagBare)
        }
        if ($fm.Success) {
            $paths.Add($fm.Groups[1].Value.Trim()) | Out-Null
            continue
        }
        $quotePat = '["'']((?:\\.|[^"''])*)["'']'
        $qm = [Regex]::Match($seg, $quotePat)
        if ($qm.Success) {
            $paths.Add($qm.Groups[1].Value.Trim()) | Out-Null
            continue
        }
        $barePat = '(?i)\b(?:Set-Content|Add-Content|Out-File|Clear-Content)\s+((?:[^\s"''|;&<>])+)'
        $bm = [Regex]::Match($seg, $barePat)
        if ($bm.Success -and -not $bm.Groups[1].Value.StartsWith('-')) {
            $paths.Add($bm.Groups[1].Value.Trim()) | Out-Null
        }
    }

    $ioPat = '\[IO\.File\]::WriteAll\w*\(["'']([^"'']+)["'']'
    foreach ($m in [Regex]::Matches($CommandText, $ioPat)) {
        $paths.Add($m.Groups[1].Value.Trim()) | Out-Null
    }

    $redirPat = '(?<!\d|\*)(?:>>|>)\s*["'']?([^\s"'';|&<>]+)["'']?'
    foreach ($m in [Regex]::Matches($CommandText, $redirPat)) {
        $target = $m.Groups[1].Value.Trim()
        if ($target -match '^&') { continue }
        if ($target -eq 'NUL' -or $target -eq '$null') { continue }
        $paths.Add($target) | Out-Null
    }

    return @($paths)
}

function Test-GateAuthStatePath {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    $norm = $FilePath -replace '\\', '/'
    return [bool]($norm -match '(?i)(?:^|/)hooks-log/(pm-gate|changelog-writes|knife-state)\.json$')
}

function Test-GeneratedWritePath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    $norm = $FilePath -replace '\\', '/'
    if ($norm -match '(?i)(?:^|/)(bin|obj|library|temp|logs|node_modules)(?:/|$)') { return $true }
    if ($norm -match '(?i)\.ai-gates/(tmp|hooks-log|verify|releases)(?:/|$)') { return $true }
    if ($norm -match '(?:^|/)\.git(?:/|$)') { return $true }
    return $false
}

function Test-InfraWritePath {
    param([string]$FilePath, [switch]$IncludeClaude)
    if (-not $FilePath) { return $false }
    $names = 'cursor|ai-gates|codex'
    if ($IncludeClaude) { $names = 'cursor|ai-gates|codex|claude' }
    return ($FilePath -match "[\\/]\.($names)[\\/]" -or $FilePath -match "^\.($names)[\\/]")
}

# 文件缺失 = 不新鲜。读坏或时间戳不可解析 = 放行（与写门禁 fail-open 相同）。
function Test-SessionStampFresh {
    param(
        [string]$FilePath,
        [string]$SessionId,
        [string]$StampName,
        [int]$FreshnessMinutes = 120
    )
    if ([string]::IsNullOrWhiteSpace($FilePath) -or -not (Test-Path -LiteralPath $FilePath)) { return $false }
    try {
        $raw = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch { return $true }
    $entry = $obj.$SessionId
    if (-not $entry -or -not $entry.$StampName) { return $false }
    try {
        $lastUtc = [DateTime]::Parse([string]$entry.$StampName).ToUniversalTime()
    } catch { return $true }
    return (([DateTime]::UtcNow - $lastUtc).TotalMinutes -le $FreshnessMinutes)
}

function Get-ShellWriteBlocks {
    param(
        [string[]]$Paths,
        [bool]$HasFreshPm,
        [bool]$HasFreshChangelog,
        [switch]$IncludeClaude
    )
    $blocks = New-Object System.Collections.Generic.List[object]
    foreach ($p in @($Paths)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-GateAuthStatePath -FilePath $p) {
            $blocks.Add([pscustomobject]@{ Path = $p; Reason = 'gate_auth_state' }) | Out-Null
            continue
        }
        if (Test-GeneratedWritePath -FilePath $p) { continue }
        if (Test-InfraWritePath -FilePath $p -IncludeClaude:$IncludeClaude) {
            if (-not $HasFreshChangelog) {
                $blocks.Add([pscustomobject]@{ Path = $p; Reason = 'infra_no_recent_changelog' }) | Out-Null
            }
        } elseif (-not $HasFreshPm) {
            $blocks.Add([pscustomobject]@{ Path = $p; Reason = 'business_no_fresh_pm' }) | Out-Null
        }
    }
    return ,$blocks
}

function Test-BusinessSourcePath {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    $norm = ($FilePath -replace '\\', '/')
    if ($norm -notmatch '\.(cs|lua)$') { return $false }
    if ($norm -match '/\.(ai-gates|cursor|claude|codex)/') { return $false }
    return $true
}

# 状态对不上、读坏、缺文件 = 不拒绝。待测为真，或三个字段齐全且热修已满 2 次且车道未升 = 拒绝。
function Get-KnifeBusinessDeny {
    param([string]$FilePath, [string]$StateJson)
    if (-not (Test-BusinessSourcePath -FilePath $FilePath)) { return $null }
    if ([string]::IsNullOrWhiteSpace($StateJson)) { return $null }
    try { $state = $StateJson | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    if ($state.awaitingHumanTest -eq $true) { return 'awaiting_human_test' }
    $window = [string]$state.window
    $acceptance = [string]$state.acceptance
    $symptom = [string]$state.symptom
    if ([string]::IsNullOrWhiteSpace($window) -or [string]::IsNullOrWhiteSpace($acceptance) -or [string]::IsNullOrWhiteSpace($symptom)) { return $null }
    $count = 0
    try { $count = [int]$state.hotfixCount } catch { return $null }
    $lane = [string]$state.lane
    $hotfixLane = [string]$state.hotfixLane
    if (-not [string]::IsNullOrWhiteSpace($lane) -and -not [string]::IsNullOrWhiteSpace($hotfixLane) -and ($lane -ne $hotfixLane)) { return $null }
    if ($count -ge 2) { return 'third_hotfix' }
    return $null
}

# 旧上下文占比过高：输入至少 20 万，且缓存读达到输入的 80%。AlreadyPrompted 仅供调用方自行抑制。
function Test-OldContextHeavy {
    param($InputTokens, $CacheReadTokens, [bool]$AlreadyPrompted)
    if ($AlreadyPrompted) { return $false }
    if ($null -eq $InputTokens -or [int64]$InputTokens -lt 200000) { return $false }
    if ($null -eq $CacheReadTokens -or [int64]$CacheReadTokens -le 0) { return $false }
    return (([double]$CacheReadTokens / [double]$InputTokens) -ge 0.80)
}

# 满 5 位写成万，保留一位小数；整万不写小数。不足 5 位保持原数。空值写成未记到。
function Format-TokenCount {
    param($Value)
    if ($null -eq $Value) { return '未记到' }
    $n = [int64]$Value
    if ([Math]::Abs($n) -lt 10000) { return [string]$n }
    $wan = [Math]::Round(([double]$n) / 10000.0, 1, [MidpointRounding]::AwayFromZero)
    $text = $wan.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($text.EndsWith('.0')) { $text = $text.Substring(0, $text.Length - 2) }
    return ($text + '万')
}

# 本对话第一次记账时记下起点。之后又增加至少 20 万，才允许写换窗行。
function Get-ConversationFirstInput {
    param($StoredFirstInput, $CurrentInput)
    if ($null -ne $StoredFirstInput -and "$StoredFirstInput" -ne '') { return [int64]$StoredFirstInput }
    return [int64]$CurrentInput
}

function Test-ShowHandoverNotice {
    param($InputTokens, $CacheReadTokens, $FirstInput)
    $first = Get-ConversationFirstInput -StoredFirstInput $FirstInput -CurrentInput $InputTokens
    if (([int64]$InputTokens - $first) -lt 200000) { return $false }
    return Test-OldContextHeavy -InputTokens $InputTokens -CacheReadTokens $CacheReadTokens -AlreadyPrompted $false
}

# token 行是模型会原样抄的那段。ShowNotice 为真时必须换行，下一行写换窗通知。
function Get-TurnTokenLine {
    param(
        $InputTokens,
        $OutputTokens,
        $CacheReadTokens,
        $CacheWriteTokens,
        [bool]$ShowNotice
    )
    $line = "token：上一轮 输入 $(Format-TokenCount $InputTokens) / 输出 $(Format-TokenCount $OutputTokens) / 缓存读 $(Format-TokenCount $CacheReadTokens) / 缓存写 $(Format-TokenCount $CacheWriteTokens)"
    if ($ShowNotice) {
        $line = $line + "`n已满足换窗条件, 请执行换窗逻辑减少token消耗"
    }
    return $line
}

# 注入句把两行分开说。换行符在附加上下文里会被折成空格，所以用文字要求换行。
function Get-TurnTokenHint {
    param([string]$TokenLine)
    $parts = @($TokenLine -split "`r?`n", 2)
    $hint = "上一轮回复的实测 token 已记下。若本轮回复含 [PM]，在 YAML 结束后先单独写这一行，不要估算本轮，不要改数字：$($parts[0])"
    if ($parts.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace([string]$parts[1])) {
        $hint = $hint + " 写完后必须换行。下一行单独写：$($parts[1]) 禁止把这句接在 token 同一行，禁止用空格代替换行。每次过线都写。不要因此输出八段交接。"
    }
    return $hint
}

function Test-HumanTestEvidence {
    param([string]$Symptom, [string]$EvidenceText)
    if ([string]::IsNullOrWhiteSpace($Symptom)) { return $false }
    if ([string]::IsNullOrWhiteSpace($EvidenceText)) { return $false }
    return $EvidenceText.Contains($Symptom)
}

function Update-KnifeState {
    param(
        [string]$ExistingJson,
        [string]$Window,
        [string]$Acceptance,
        [string]$Symptom,
        [string]$Lane,
        [bool]$NeedsHumanTest
    )
    $count = 0
    $hotfixLane = $Lane
    if (-not [string]::IsNullOrWhiteSpace($ExistingJson)) {
        try {
            $old = $ExistingJson | ConvertFrom-Json -ErrorAction Stop
            $same = ([string]$old.window -eq $Window) -and ([string]$old.acceptance -eq $Acceptance) -and ([string]$old.symptom -eq $Symptom)
            if ($same) {
                $count = [int]$old.hotfixCount + 1
                if (-not [string]::IsNullOrWhiteSpace([string]$old.hotfixLane)) { $hotfixLane = [string]$old.hotfixLane }
            }
        } catch { }
    }
    return [pscustomobject]@{
        awaitingHumanTest = [bool]$NeedsHumanTest
        window = $Window
        acceptance = $Acceptance
        symptom = $Symptom
        hotfixCount = $count
        lane = $Lane
        hotfixLane = $hotfixLane
    }
}

function Test-CrStampPath {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    $norm = ($FilePath -replace '\\', '/')
    return [bool]($norm -match '(?i)(?:^|/)\.ai-gates/hooks-log/cr-stamp\.json$')
}

function Get-CrStampDeny {
    param([string]$FilePath, [bool]$IsMainWindow)
    if (-not (Test-CrStampPath -FilePath $FilePath)) { return $null }
    if ($IsMainWindow) { return 'cr_stamp_main_window' }
    return $null
}

function Test-OfficialChangelogPath {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    $norm = ($FilePath -replace '\\', '/').TrimEnd('/')
    return [bool]($norm -match '(?i)(?:^|/)\.ai-gates/CHANGELOG\.md$')
}

function Test-ReviewDispatchPath {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    $norm = ($FilePath -replace '\\', '/')
    return [bool]($norm -match '(?i)(?:方案审核派发|代码审核派发)\.md$')
}

function New-GateVerdict {
    param([bool]$Allow, [string]$Detail, [string]$Message = "")
    [pscustomobject]@{ Allow = $Allow; Detail = $Detail; Message = $Message }
}

function Get-PmDetailCode {
    param([string]$HostName, [string]$Kind)
    $session = $HostName -ne 'cursor'
    switch ($Kind) {
        'no_pm' { if ($session) { return 'no_pm_marker_for_session' } else { return 'no_pm_marker_for_conversation' } }
        'no_changelog' { if ($session) { return 'no_changelog_write_for_session_level1' } else { return 'no_changelog_write_for_conversation_level1' } }
        'parse_business' { if ($session) { return 'parse_failed_business_code' } else { return 'main_window_business_code' } }
        default { return $Kind }
    }
}

function Get-GateRelativePath {
    param([string]$FilePath, [bool]$IncludeClaude)
    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $null }
    $norm = $FilePath -replace '\\', '/'
    $m = [Regex]::Match($norm, '(?:^|/)\.(cursor|ai-gates)/(.*)$')
    if ($m.Success) { return $m.Groups[2].Value }
    $m2 = [Regex]::Match($norm, '(?:^|/)\.codex/(.*)$')
    if ($m2.Success) { return 'codex/' + $m2.Groups[1].Value }
    if ($IncludeClaude) {
        $m3 = [Regex]::Match($norm, '(?:^|/)\.claude/(.*)$')
        if ($m3.Success) { return 'claude/' + $m3.Groups[1].Value }
    }
    return $null
}

function Get-WritePathClass {
    param([string]$FilePath, [bool]$IncludeClaude, [bool]$RootReadmeIsFacility, [bool]$RootDocsAreLevel1 = $false)
    if (Test-CrStampPath -FilePath $FilePath) { return 'stamp' }
    if (Test-GeneratedWritePath -FilePath $FilePath) { return 'generated' }
    $rel = Get-GateRelativePath -FilePath $FilePath -IncludeClaude $IncludeClaude
    $norm = [string]$FilePath -replace '\\', '/'
    $infra = [bool]$rel
    if (-not $infra) {
        if ($norm -match '(?:^|/)\.(cursor|ai-gates|codex)(?:/|$)') { $infra = $true }
        elseif ($IncludeClaude -and $norm -match '(?:^|/)\.claude(?:/|$)') { $infra = $true }
    }
    if (-not $infra) {
        if ($RootReadmeIsFacility -and $norm -match '(?i)(?:^|/)README\.md$') { return 'level1' }
        return 'business'
    }
    if (-not $rel) { return 'level2' }
    if ($rel -match '(?i)(?:^|/)hooks-log/cr-stamp\.json$') { return 'stamp' }
    if (Test-OfficialChangelogPath -FilePath $FilePath) { return 'level0' }
    if ($rel -match '(?:^|/)hooks-log(?:/|$)') { return 'level0' }
    if ($rel -match '(?:^|/)(project-context\.md|regression-index\.yaml|lessons-[^/]*|pipeline-recovery-log\.md|pipeline-snapshot\.log|pipeline-outcome\.log)$') { return 'level0' }
    if ($rel -match '(?:^|/)settings\.local\.json$') { return 'level0' }
    if ($rel -match '(?:^|/)(skills|hooks|scripts|rules)(?:/|$)') { return 'level1' }
    if ($rel -eq 'hooks.json') { return 'level1' }
    if ($rel -match '^codex(?:/|$)') { return 'level1' }
    if ($IncludeClaude -and $rel -match '^claude(?:/|$)') { return 'level1' }
    # 只认 .ai-gates 根上这四份。 .cursor/README.md 收成 README.md 后不能再升 Level 1。
    if (($IncludeClaude -or $RootDocsAreLevel1) -and $norm -match '(?i)(?:^|/)\.ai-gates/(README|SKILLS|USER-GUIDE|METHODOLOGY)\.md$') { return 'level1' }
    return 'level2'
}

function Get-WriteDenyHint {
    param([string]$Detail)
    if ($Detail -eq 'parent_pm_not_marked') {
        return '子窗不要发 [PM]，也不要把 [PM] 写进 resume 提示词。主窗须在自己的回复里发出 [PM]，等打点写入 pm-gate.json 后再派或续写。或主窗代写并标明未开子窗。或放置 hooks-log/pm-gate-disabled / 手动编辑。'
    }
    $childTail = ' 若本窗是子窗：不要发 [PM]，也不要把 [PM] 写进 resume，等主窗回复打点或主窗代写。'
    if ($Detail -like 'stale_changelog_write_age*' -or $Detail -like 'no_changelog_write_*' -or $Detail -eq 'changelog_writes_missing_level1') {
        return '逃生：先写 .ai-gates/CHANGELOG.md（CHANGELOG 自身 Level 0 豁免）后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。顺序见 MAINTAINER 文首「改 skill 五步」。'
    }
    if ($Detail -like 'stale_pm_marker_age*') {
        return ('逃生：先在本会话回复中重新发出 [PM] 标记（标记已超 120 分钟），待打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。' + $childTail)
    }
    if ($Detail -eq 'timestamp_unparseable') {
        return ('逃生：先在本会话回复中重新发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。' + $childTail)
    }
    if ($Detail -eq 'gate_file_unreadable') {
        return ('逃生：先在本会话回复中发出 [PM] 标记，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。' + $childTail)
    }
    if ($Detail -eq 'main_window_business_code' -or $Detail -eq 'parse_failed_business_code' -or $Detail -eq 'cr_stamp_main_window' -or $Detail -eq 'dispatch_main_window' -or $Detail -eq 'gate_auth_state' -or $Detail -eq 'awaiting_human_test' -or $Detail -eq 'third_hotfix') {
        return 'Do not edit the file in this window.'
    }
    return ('逃生：先在本会话回复中发出 [PM] 标记（如「PM 判定：…」），待 mark-pm-gate 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或手动编辑目标文件。' + $childTail)
}

function Complete-GateDeny {
    param([string]$Detail, [string]$Base)
    $hint = Get-WriteDenyHint -Detail $Detail
    if ([string]::IsNullOrWhiteSpace($hint)) { return $Base }
    return ($Base.TrimEnd() + ' ' + $hint)
}

# 根目录说明默认不算设施。HostName 决定会话字段用 conversation 还是 session。
function Get-WriteGateVerdict {
    param(
        [string]$HostName,
        [string[]]$Paths,
        [bool]$ParseFailed,
        [ValidateSet('Missing','Unreadable','Ok')][string]$GateState = 'Missing',
        [ValidateSet('Missing','Unparseable','Fresh','Stale')][string]$OwnPm = 'Missing',
        [ValidateSet('Missing','Unreadable','NonObject','Ok')][string]$ChangelogState = 'Missing',
        [ValidateSet('Missing','Unparseable','Fresh','Stale')][string]$ChangelogStamp = 'Missing',
        [bool]$ParentHasFreshPm = $false,
        [string]$ParentId = "",
        [string]$InheritReason = "",
        [string]$KnifeJson = "",
        [bool]$IncludeClaude = $false,
        [bool]$RootReadmeIsFacility = $false,
        [bool]$RootDocsAreLevel1 = $false,
        [int]$AgeMinutes = 0
    )
    $pathsIn = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $classes = @()
    foreach ($p in $pathsIn) {
        $classes += Get-WritePathClass -FilePath $p -IncludeClaude $IncludeClaude -RootReadmeIsFacility $RootReadmeIsFacility -RootDocsAreLevel1 $RootDocsAreLevel1
    }
    $hasBusiness = ((-not $ParseFailed) -and $pathsIn.Count -eq 0) -or ($classes -contains 'business')
    $hasLevel1 = $classes -contains 'level1'
    $hasStamp = $classes -contains 'stamp'
    $businessCode = @($pathsIn | Where-Object { Test-BusinessSourcePath -FilePath $_ })

    if ($ParseFailed) {
        if ($OwnPm -eq 'Fresh' -and $businessCode.Count -gt 0) {
            $code = Get-PmDetailCode -HostName $HostName -Kind 'parse_business'
            $base = 'PM gate deny detail=main_window_business_code : stdin parse failed, path is business .cs/.lua, and this session has its own [PM]. Dispatch a programmer subagent.'
            return New-GateVerdict -Allow $false -Detail $code -Message (Complete-GateDeny -Detail $code -Base $base)
        }
        return New-GateVerdict -Allow $true -Detail 'parse_failed_fail_open'
    }

    if ($hasStamp -and $OwnPm -eq 'Fresh') {
        $base = 'PM gate deny detail=cr_stamp_main_window : only the code-reviewer subagent may write hooks-log/cr-stamp.json.'
        return New-GateVerdict -Allow $false -Detail 'cr_stamp_main_window' -Message (Complete-GateDeny -Detail 'cr_stamp_main_window' -Base $base)
    }

    $authState = @($pathsIn | Where-Object { Test-GateAuthStatePath -FilePath $_ })
    if ($authState.Count -gt 0) {
        $base = 'PM gate deny detail=gate_auth_state : pm-gate.json, changelog-writes.json, and knife-state.json are written by the hooks and the official scripts. Do not write them from the editor or an explicit shell redirect.'
        return New-GateVerdict -Allow $false -Detail 'gate_auth_state' -Message (Complete-GateDeny -Detail 'gate_auth_state' -Base $base)
    }

    $dispatch = @($pathsIn | Where-Object { Test-ReviewDispatchPath -FilePath $_ })
    if ($dispatch.Count -gt 0 -and $OwnPm -eq 'Fresh') {
        $base = 'PM gate deny detail=dispatch_main_window : the main window must not edit review dispatch files. The planner refreshes the plan dispatch. The programmer refreshes the code dispatch.'
        return New-GateVerdict -Allow $false -Detail 'dispatch_main_window' -Message (Complete-GateDeny -Detail 'dispatch_main_window' -Base $base)
    }

    $businessAllow = $null
    if ($hasBusiness) {
        if ($GateState -eq 'Missing') {
            $base = 'PM gate deny detail=gate_file_missing : no fresh [PM] marker detected.'
            return New-GateVerdict -Allow $false -Detail 'gate_file_missing' -Message (Complete-GateDeny -Detail 'gate_file_missing' -Base $base)
        }
        if ($GateState -eq 'Unreadable') {
            $base = 'PM gate deny detail=gate_file_unreadable : no fresh [PM] marker detected.'
            return New-GateVerdict -Allow $false -Detail 'gate_file_unreadable' -Message (Complete-GateDeny -Detail 'gate_file_unreadable' -Base $base)
        }
        if ($OwnPm -eq 'Unparseable') {
            $base = 'PM gate deny detail=timestamp_unparseable : no fresh [PM] marker detected.'
            return New-GateVerdict -Allow $false -Detail 'timestamp_unparseable' -Message (Complete-GateDeny -Detail 'timestamp_unparseable' -Base $base)
        }
        if ($OwnPm -eq 'Fresh' -and $businessCode.Count -gt 0) {
            $base = 'PM gate deny detail=main_window_business_code : this session has its own [PM], so it is the main window. It must not edit business .cs/.lua. Dispatch a programmer subagent.'
            return New-GateVerdict -Allow $false -Detail 'main_window_business_code' -Message (Complete-GateDeny -Detail 'main_window_business_code' -Base $base)
        }
        if ($OwnPm -eq 'Fresh') { $businessAllow = 'window_pm_not_this_turn' }
        elseif ($ParentHasFreshPm) {
            if ([string]::IsNullOrWhiteSpace($InheritReason)) { $businessAllow = 'window_pm_not_this_turn_inherited_parent_pm' }
            else { $businessAllow = $InheritReason }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ParentId)) {
            $base = 'PM gate deny detail=parent_pm_not_marked : unique parent transcript found but parent has no fresh [PM]. Child must not emit [PM].'
            return New-GateVerdict -Allow $false -Detail 'parent_pm_not_marked' -Message (Complete-GateDeny -Detail 'parent_pm_not_marked' -Base $base)
        }
        elseif ($OwnPm -eq 'Stale') {
            $detail = 'stale_pm_marker_age'
            if ($AgeMinutes -gt 0) { $detail = ('stale_pm_marker_age={0}min' -f [Math]::Round($AgeMinutes, 1)) }
            $base = "PM gate deny detail=stale_pm_marker_age=${AgeMinutes}min : no fresh [PM] marker detected."
            return New-GateVerdict -Allow $false -Detail $detail -Message (Complete-GateDeny -Detail $detail -Base $base)
        }
        else {
            $noPm = Get-PmDetailCode -HostName $HostName -Kind 'no_pm'
            $base = "PM gate deny detail=$noPm : no fresh [PM] marker detected."
            return New-GateVerdict -Allow $false -Detail $noPm -Message (Complete-GateDeny -Detail $noPm -Base $base)
        }
        if ($businessAllow -and $businessCode.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($KnifeJson)) {
            foreach ($bp in $businessCode) {
                $knife = Get-KnifeBusinessDeny -FilePath $bp -StateJson $KnifeJson
                if ($knife) {
                    $base = "PM gate deny detail=$knife : business .cs/.lua stays blocked until the knife state allows it."
                    return New-GateVerdict -Allow $false -Detail $knife -Message (Complete-GateDeny -Detail $knife -Base $base)
                }
            }
        }
    }

    if ($hasLevel1) {
        $level1Base = 'PM gate Level-1 deny : no fresh CHANGELOG write for this session within 120 min (changing facilities requires a CHANGELOG entry; this gate does NOT read [PM] markers). Order: MAINTAINER.md 「改 skill 五步」.'
        if ($ChangelogState -eq 'Missing') {
            return New-GateVerdict -Allow $false -Detail 'changelog_writes_missing_level1' -Message (Complete-GateDeny -Detail 'changelog_writes_missing_level1' -Base $level1Base)
        }
        if ($ChangelogState -eq 'Unreadable') { return New-GateVerdict -Allow $true -Detail 'changelog_writes_unreadable_fail_open' }
        if ($ChangelogState -eq 'NonObject') { return New-GateVerdict -Allow $true -Detail 'changelog_writes_nonobject_fail_open' }
        if ($ChangelogStamp -eq 'Unparseable') { return New-GateVerdict -Allow $true -Detail 'changelog_timestamp_unparseable_fail_open' }
        if ($ChangelogStamp -eq 'Missing') {
            $code = Get-PmDetailCode -HostName $HostName -Kind 'no_changelog'
            return New-GateVerdict -Allow $false -Detail $code -Message (Complete-GateDeny -Detail $code -Base $level1Base)
        }
        if ($ChangelogStamp -eq 'Stale') {
            $detail = 'stale_changelog_write_age'
            if ($AgeMinutes -gt 0) { $detail = ('stale_changelog_write_age={0}min_level1' -f [Math]::Round($AgeMinutes, 1)) }
            return New-GateVerdict -Allow $false -Detail $detail -Message (Complete-GateDeny -Detail $detail -Base $level1Base)
        }
        if (-not $businessAllow) { return New-GateVerdict -Allow $true -Detail 'recent_changelog_write' }
    }

    if ($businessAllow) { return New-GateVerdict -Allow $true -Detail $businessAllow }
    return New-GateVerdict -Allow $true -Detail 'allow'
}

function Resolve-UniqueParentConversationId {
    param([string]$ChildId)
    if ([string]::IsNullOrWhiteSpace($ChildId) -or $ChildId -eq 'unknown') { return $null }
    $projectsRoot = Join-Path $env:USERPROFILE '.cursor\projects'
    if (-not (Test-Path -LiteralPath $projectsRoot)) { return $null }
    $hits = New-Object System.Collections.Generic.List[string]
    try { $projDirs = [System.IO.Directory]::GetDirectories($projectsRoot) } catch { return $null }
    foreach ($proj in $projDirs) {
        $transcriptsRoot = Join-Path $proj 'agent-transcripts'
        if (-not [System.IO.Directory]::Exists($transcriptsRoot)) { continue }
        try { $parentDirs = [System.IO.Directory]::GetDirectories($transcriptsRoot) } catch { continue }
        foreach ($parentDir in $parentDirs) {
            $childFile = Join-Path $parentDir ('subagents\' + $ChildId + '.jsonl')
            if ([System.IO.File]::Exists($childFile)) { $hits.Add([System.IO.Path]::GetFileName($parentDir)) | Out-Null }
        }
    }
    if ($hits.Count -ne 1) { return $null }
    return $hits[0]
}

function Test-ParentTranscriptHasRecentPm {
    param([string]$ParentConversationId)
    if ([string]::IsNullOrWhiteSpace($ParentConversationId) -or $ParentConversationId -eq 'unknown') { return $false }
    $projectsRoot = Join-Path $env:USERPROFILE '.cursor\projects'
    if (-not (Test-Path -LiteralPath $projectsRoot)) { return $false }
    try { $projDirs = [System.IO.Directory]::GetDirectories($projectsRoot) } catch { return $false }
    foreach ($proj in $projDirs) {
        $file = Join-Path $proj ('agent-transcripts\' + $ParentConversationId + '\' + $ParentConversationId + '.jsonl')
        if (-not [System.IO.File]::Exists($file)) { continue }
        try {
            $info = New-Object System.IO.FileInfo $file
            if (([DateTime]::UtcNow - $info.LastWriteTimeUtc).TotalMinutes -gt 120) { continue }
            $len = [int64]$info.Length
            if ($len -le 0) { continue }
            $chunk = [int64]524288
            $maxScan = [int64]4194304
            $scanned = [int64]0
            $end = $len
            while ($end -gt 0 -and $scanned -lt $maxScan) {
                $start = $end - $chunk
                if ($start -lt 0) { $start = 0 }
                $take = [int]($end - $start)
                $fs = [System.IO.File]::Open($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                try {
                    $null = $fs.Seek($start, [System.IO.SeekOrigin]::Begin)
                    $buf = New-Object byte[] $take
                    $read = $fs.Read($buf, 0, $take)
                } finally { $fs.Dispose() }
                if ($read -le 0) { break }
                $text = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
                if ($text.Contains('[PM]')) { return $true }
                $scanned += $take
                $newest = $null
                foreach ($m in [regex]::Matches($text, '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?')) {
                    try {
                        $t = [DateTime]::Parse($m.Value).ToUniversalTime()
                        if (-not $newest -or $t -gt $newest) { $newest = $t }
                    } catch { }
                }
                if ($newest -and (([DateTime]::UtcNow - $newest).TotalMinutes -gt 120)) { break }
                if ($start -eq 0) { break }
                $nextEnd = $start + 32
                if ($nextEnd -ge $end) { break }
                $end = $nextEnd
            }
        } catch { continue }
    }
    return $false
}

function Get-InheritedParentPmReason {
    param([string]$ConversationId, $Gate)
    if ($ConversationId -eq 'unknown') { return $null }
    $foundParent = Resolve-UniqueParentConversationId -ChildId $ConversationId
    if (-not $foundParent) { return $null }
    $parentEntry = $Gate.$foundParent
    if ($parentEntry -and $parentEntry.lastPmAtUtc) {
        try {
            $parentPmUtc = [DateTime]::Parse([string]$parentEntry.lastPmAtUtc).ToUniversalTime()
            $parentAgeMinutes = ([DateTime]::UtcNow - $parentPmUtc).TotalMinutes
            if ($parentAgeMinutes -le 120) {
                return ('window_pm_not_this_turn_inherited_parent_pm_age={0}min parent={1}' -f [Math]::Round($parentAgeMinutes, 1), $foundParent)
            }
        } catch { }
    }
    if (Test-ParentTranscriptHasRecentPm -ParentConversationId $foundParent) {
        return ('window_pm_not_this_turn_inherited_parent_pm_transcript parent={0}' -f $foundParent)
    }
    return $null
}

function Resolve-WriteGateVerdictFromFiles {
    param(
        [string]$HostName,
        [string]$SessionId,
        [string[]]$Paths,
        [bool]$ParseFailed,
        [string]$LogDir,
        [bool]$IncludeClaude = $false,
        [bool]$RootDocsAreLevel1 = $false,
        [bool]$RootReadmeIsFacility = $false
    )
    if ([string]::IsNullOrWhiteSpace($SessionId)) { $SessionId = 'unknown' }
    $gateState = 'Missing'
    $own = 'Missing'
    $ageMinutes = 0
    $gate = $null
    $gateFile = Join-Path $LogDir 'pm-gate.json'
    if (Test-Path -LiteralPath $gateFile) {
        try {
            $gate = [System.IO.File]::ReadAllText($gateFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
            $gateState = 'Ok'
            $entry = $gate.$SessionId
            if ($entry -and $entry.lastPmAtUtc) {
                try {
                    $last = [DateTime]::Parse([string]$entry.lastPmAtUtc).ToUniversalTime()
                    $ageMinutes = [int]([DateTime]::UtcNow - $last).TotalMinutes
                    if (([DateTime]::UtcNow - $last).TotalMinutes -le 120) { $own = 'Fresh' } else { $own = 'Stale' }
                } catch { $own = 'Unparseable' }
            }
        } catch { $gateState = 'Unreadable' }
    }
    $changelogState = 'Missing'
    $changelogStamp = 'Missing'
    $changelogAge = 0
    $changelogFile = Join-Path $LogDir 'changelog-writes.json'
    if (Test-Path -LiteralPath $changelogFile) {
        try {
            $changelog = [System.IO.File]::ReadAllText($changelogFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
            if (-not ($changelog -is [System.Management.Automation.PSCustomObject])) { $changelogState = 'NonObject' }
            else {
                $changelogState = 'Ok'
                $centry = $changelog.$SessionId
                if ($centry -and $centry.lastChangelogWriteAtUtc) {
                    try {
                        $clast = [DateTime]::Parse([string]$centry.lastChangelogWriteAtUtc).ToUniversalTime()
                        $changelogAge = [int]([DateTime]::UtcNow - $clast).TotalMinutes
                        if (([DateTime]::UtcNow - $clast).TotalMinutes -le 120) { $changelogStamp = 'Fresh' } else { $changelogStamp = 'Stale' }
                    } catch { $changelogStamp = 'Unparseable' }
                }
            }
        } catch { $changelogState = 'Unreadable' }
    }
    $parentId = ''
    $parentFresh = $false
    $inheritReason = ''
    $needsParent = $false
    if (-not $ParseFailed -and $gateState -eq 'Ok' -and $own -ne 'Fresh') {
        $clean = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($clean.Count -eq 0) { $needsParent = $true }
        else {
            foreach ($p in $clean) {
                $cls = Get-WritePathClass -FilePath $p -IncludeClaude $IncludeClaude -RootReadmeIsFacility $RootReadmeIsFacility -RootDocsAreLevel1 $RootDocsAreLevel1
                if ($cls -eq 'business') { $needsParent = $true }
            }
        }
    }
    if ($needsParent -and $gate) {
        $inheritReason = [string](Get-InheritedParentPmReason -ConversationId $SessionId -Gate $gate)
        if (-not [string]::IsNullOrWhiteSpace($inheritReason)) { $parentFresh = $true }
        else {
            $foundParent = Resolve-UniqueParentConversationId -ChildId $SessionId
            if ($foundParent) { $parentId = [string]$foundParent }
        }
    }
    $knife = ''
    $knifePath = Join-Path $LogDir 'knife-state.json'
    if (Test-Path -LiteralPath $knifePath) {
        try { $knife = [System.IO.File]::ReadAllText($knifePath, [System.Text.Encoding]::UTF8) } catch { $knife = '' }
    }
    $ageForVerdict = $ageMinutes
    if ($changelogStamp -eq 'Stale' -and $changelogAge -gt $ageForVerdict) { $ageForVerdict = $changelogAge }
    return Get-WriteGateVerdict -HostName $HostName -Paths $Paths -ParseFailed $ParseFailed -GateState $gateState -OwnPm $own -ChangelogState $changelogState -ChangelogStamp $changelogStamp -ParentHasFreshPm $parentFresh -ParentId $parentId -InheritReason $inheritReason -KnifeJson $knife -IncludeClaude $IncludeClaude -RootReadmeIsFacility $RootReadmeIsFacility -RootDocsAreLevel1 $RootDocsAreLevel1 -AgeMinutes $ageForVerdict
}
