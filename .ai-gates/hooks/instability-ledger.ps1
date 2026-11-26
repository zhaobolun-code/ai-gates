# instability-ledger.ps1
# 影子期只追加不稳度账本。点源后调用函数。本文件不读 stdin，不拒绝业务写入。
# 计分初值来自设计第 2.2 节，只写进行。写门禁不读这些数，不算 T。

$script:InstabilityUserFailScore = 3
$script:InstabilityRepeatFailScore = 2

function Get-InstabilityHashHex {
    param([string]$Text, [int]$Take)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
        $hex = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        if ($Take -ge $hex.Length) { return $hex }
        return $hex.Substring(0, $Take)
    } finally {
        $sha.Dispose()
    }
}

function Test-InstabilityTempLedger {
    param([string]$LedgerDir)
    if ([string]::IsNullOrWhiteSpace($LedgerDir)) { return $false }
    $full = [System.IO.Path]::GetFullPath($LedgerDir).TrimEnd('\', '/')
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $prefix = $temp + [System.IO.Path]::DirectorySeparatorChar
    $underTemp = $full.Equals($temp, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $underTemp) { return $false }
    $norm = $full -replace '\\', '/'
    if ($norm -match '(?i)(^|/)\.ai-gates/hooks-log(/|$)') { return $false }
    return $true
}

function Test-InstabilityLaunchedScript {
    param([string]$ScriptName)
    $cmdArgs = @([Environment]::GetCommandLineArgs())
    for ($i = 0; $i -lt $cmdArgs.Count; $i++) {
        if ([string]$cmdArgs[$i] -ne '-File') { continue }
        if (($i + 1) -ge $cmdArgs.Count) { return $false }
        $path = [string]$cmdArgs[$i + 1]
        if ($path -match ('(?i)(^|[\\/])' + [regex]::Escape($ScriptName) + '$')) { return $true }
    }
    return $false
}

function Test-InstabilityInteractiveConsole {
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    try {
        if ([Console]::IsInputRedirected) { return $false }
    } catch {
        return $false
    }
    return $true
}

function Test-InstabilityWriter {
    param([string]$Writer, [string]$LedgerDir)
    if ($Writer -eq 'official-test') {
        return (Test-InstabilityTempLedger -LedgerDir $LedgerDir)
    }
    if ($Writer -eq 'hook') {
        return (Test-InstabilityLaunchedScript -ScriptName 'collect-instability-prompt.ps1')
    }
    if ($Writer -eq 'invalidate-script') {
        if (-not (Test-InstabilityLaunchedScript -ScriptName 'invalidate-instability-event.ps1')) { return $false }
        return (Test-InstabilityInteractiveConsole)
    }
    return $false
}

function Test-InstabilityExactSignal {
    param([string]$Line)
    if ($Line -ceq '治理信号：这次失败') { return 'user_fail' }
    if ($Line -ceq '治理信号：需求变了') { return 'demand' }
    if ($Line -ceq '治理选择：升级车道') { return 'choice' }
    if ($Line -ceq '治理选择：保持车道') { return 'choice' }
    if ($Line -ceq '治理选择：先处理') { return 'choice' }
    if ($Line -ceq '治理选择：新任务') { return 'new_task' }
    if ($Line -ceq '治理选择：降车道 Express') { return 'choice' }
    if ($Line -ceq '治理选择：降车道 Direct') { return 'choice' }
    if ($Line -ceq '治理选择：降车道 Standard') { return 'choice' }
    if ($Line -cmatch '^治理信号：这次没修好 issue_id=([A-Za-z0-9_.:-]+)$') { return 'fail_again' }
    if ($Line -cmatch '^治理信号：已经修好 issue_id=([A-Za-z0-9_.:-]+)$') { return 'resolved' }
    return $null
}

function Get-InstabilityIssueArg {
    param([string]$Line)
    $m = [regex]::Match([string]$Line, '^治理信号：(这次没修好|已经修好) issue_id=([A-Za-z0-9_.:-]+)$')
    if ($m.Success) { return $m.Groups[2].Value }
    return ''
}

function Get-InstabilitySignalLines {
    param([string]$Prompt)
    $found = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrEmpty($Prompt)) { return ,$found }
    $inFence = $false
    foreach ($raw in ([string]$Prompt -split "\r\n|\n|\r")) {
        $trim = $raw.Trim()
        if ($trim.StartsWith('```')) {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }
        if ($trim.StartsWith('>')) { continue }
        if (Test-InstabilityExactSignal -Line $trim) { $found.Add($trim) | Out-Null }
    }
    return ,$found
}

function Get-InstabilityPromptFields {
    param([string]$RawJson)
    $names = New-Object System.Collections.Generic.List[string]
    $result = [pscustomobject]@{
        Prompt = ''
        ConversationId = ''
        SourceId = ''
        KeyNames = $names
        Readable = $false
    }
    if ([string]::IsNullOrWhiteSpace($RawJson)) { return $result }
    try { $payload = $RawJson | ConvertFrom-Json -ErrorAction Stop } catch { return $result }
    $result.Readable = $true
    foreach ($p in @($payload.PSObject.Properties)) { $names.Add([string]$p.Name) | Out-Null }
    foreach ($name in @('prompt', 'text', 'user_prompt', 'message')) {
        $v = $payload.$name
        if ($v -is [string] -and -not [string]::IsNullOrEmpty($v)) {
            $result.Prompt = $v
            break
        }
    }
    foreach ($name in @('conversation_id', 'conversationId', 'session_id', 'sessionId')) {
        $v = [string]$payload.$name
        if (-not [string]::IsNullOrWhiteSpace($v)) {
            $result.ConversationId = $v
            break
        }
    }
    foreach ($name in @('generation_id', 'generationId', 'message_id', 'messageId', 'prompt_id', 'promptId', 'request_id', 'requestId')) {
        $v = [string]$payload.$name
        if (-not [string]::IsNullOrWhiteSpace($v)) {
            $result.SourceId = $v
            break
        }
    }
    return $result
}

function Read-InstabilityRows {
    param([string]$Path)
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        foreach ($line in [System.IO.File]::ReadAllLines($Path, (New-Object System.Text.UTF8Encoding $false))) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $rows.Add(($line | ConvertFrom-Json -ErrorAction Stop)) | Out-Null } catch { }
        }
    }
    return ,$rows.ToArray()
}

function Read-InstabilityTasks {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return @{} }
    try {
        $obj = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
    $map = @{}
    if (-not $obj -or -not $obj.sessions) { return $map }
    foreach ($p in @($obj.sessions.PSObject.Properties)) {
        $seq = 1
        try { $seq = [int]$p.Value.seq } catch { $seq = 1 }
        $taskId = [string]$p.Value.task_id
        if ([string]::IsNullOrWhiteSpace($taskId)) { $taskId = ([string]$p.Name + ':' + $seq) }
        $map[[string]$p.Name] = [pscustomobject]@{ seq = $seq; task_id = $taskId }
    }
    return $map
}

function Write-InstabilityTasks {
    param([string]$Path, $Map)
    $sessions = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($k in @($Map.Keys | Sort-Object)) {
        $sessions[$k] = [ordered]@{
            seq = [int]$Map[$k].seq
            task_id = [string]$Map[$k].task_id
        }
    }
    $json = ([ordered]@{ sessions = $sessions } | ConvertTo-Json -Compress -Depth 5)
    $enc = New-Object System.Text.UTF8Encoding $false
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $tmp = $Path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, $enc)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    Move-Item -LiteralPath $tmp -Destination $Path | Out-Null
}

function Get-InstabilityUnsettledScored {
    param([System.Collections.IList]$Rows, [string]$IssueId)
    $settled = @{}
    foreach ($r in $Rows) {
        $st = [string]$r.status
        if ($st -ne 'resolved' -and $st -ne 'invalidated') { continue }
        $target = [string]$r.target_event_id
        if ($target) { $settled[$target] = $true }
    }
    $open = New-Object System.Collections.Generic.List[object]
    foreach ($r in $Rows) {
        if ([string]$r.issue_id -ne $IssueId) { continue }
        if ([string]$r.evidence_level -ne 'scored') { continue }
        $delta = 0
        try { $delta = [int]$r.score_delta } catch { continue }
        if ($delta -le 0) { continue }
        if ($settled.ContainsKey([string]$r.event_id)) { continue }
        $open.Add($r) | Out-Null
    }
    return ,$open.ToArray()
}

function Get-InstabilityIssueTask {
    param([System.Collections.IList]$Rows, [string]$IssueId)
    foreach ($r in $Rows) {
        if ([string]$r.issue_id -eq $IssueId -and -not [string]::IsNullOrWhiteSpace([string]$r.task_id)) {
            return [string]$r.task_id
        }
    }
    return ''
}

function Test-InstabilityIssueHasScored {
    param([System.Collections.IList]$Rows, [string]$IssueId)
    foreach ($r in $Rows) {
        if ([string]$r.issue_id -ne $IssueId) { continue }
        if ([string]$r.evidence_level -ne 'scored') { continue }
        try { if ([int]$r.score_delta -gt 0) { return $true } } catch { }
    }
    return $false
}

function New-InstabilityRow {
    param(
        [string]$TaskId,
        [string]$ObservedTaskId,
        [string]$IssueId,
        [string]$EventId,
        [string]$EventType,
        [string]$EvidenceLevel,
        [int]$ScoreDelta,
        [string]$SourceId,
        [string]$TargetEventId,
        [string]$EvidenceRef,
        [string]$Status
    )
    if (-not (Get-Command Redact-HookSecrets -ErrorAction SilentlyContinue)) {
        $common = Join-Path $PSScriptRoot 'cursor-hooks-common.ps1'
        if (Test-Path -LiteralPath $common) { . $common }
    }
    $ref = [string]$EvidenceRef
    if (Get-Command Redact-HookSecrets -ErrorAction SilentlyContinue) {
        $ref = [string](Redact-HookSecrets -Text $ref)
    }
    return [pscustomobject]@{
        task_id = [string]$TaskId
        observed_task_id = [string]$ObservedTaskId
        issue_id = [string]$IssueId
        event_id = [string]$EventId
        event_type = [string]$EventType
        evidence_level = [string]$EvidenceLevel
        score_delta = [int]$ScoreDelta
        source_id = [string]$SourceId
        target_event_id = [string]$TargetEventId
        evidence_ref = $ref
        status = [string]$Status
        observed_at = [DateTime]::UtcNow.ToString('o')
    }
}

function Add-InstabilityLedgerRow {
    param([string]$Path, $Row, [System.Collections.IList]$Rows, $Seen)
    $id = [string]$Row.event_id
    if ($Seen.ContainsKey($id)) { return $false }
    $enc = New-Object System.Text.UTF8Encoding $false
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = ($Row | ConvertTo-Json -Compress -Depth 4)
    $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $sw = New-Object System.IO.StreamWriter($fs, $enc)
    try {
        $sw.WriteLine($json)
        $sw.Flush()
    } finally {
        $sw.Dispose()
    }
    $Rows.Add($Row) | Out-Null
    $Seen[$id] = $true
    return $true
}

function Invoke-InstabilityLocked {
    param([string]$MutexName, [scriptblock]$Body)
    $name = $MutexName
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Local\AiGatesInstabilityLedger' }
    $mutex = New-Object System.Threading.Mutex($false, $name)
    $got = $false
    try {
        try { $got = $mutex.WaitOne(8000) }
        catch [System.Threading.AbandonedMutexException] { $got = $true }
        if (-not $got) { return 'lock-timeout' }
        $null = & $Body
        return ''
    } finally {
        if ($got) {
            try { $mutex.ReleaseMutex() | Out-Null } catch { }
        }
        $mutex.Dispose()
    }
}

function Publish-InstabilityResult {
    param($Result)
    if ($Result.Appended -is [System.Collections.IList] -and -not ($Result.Appended -is [System.Array])) {
        $Result.Appended = $Result.Appended.ToArray()
    }
    $echoProp = $Result.PSObject.Properties['EchoIssueIds']
    if ($echoProp -and $echoProp.Value -is [System.Collections.IList] -and -not ($echoProp.Value -is [System.Array])) {
        $Result.EchoIssueIds = $echoProp.Value.ToArray()
    }
    return $Result
}

function Add-InstabilityPromptEvents {
    param(
        [string]$LedgerDir,
        [string]$ConversationId,
        [string]$SourceId,
        [string]$Prompt,
        [string]$Writer,
        [string]$MutexName = ''
    )
    $appended = New-Object System.Collections.Generic.List[object]
    $echo = New-Object System.Collections.Generic.List[string]
    $out = [pscustomobject]@{ Appended = $appended; EchoIssueIds = $echo; Refused = $false; Reason = '' }
    if (-not (Test-InstabilityWriter -Writer $Writer -LedgerDir $LedgerDir)) {
        $out.Refused = $true
        $out.Reason = 'writer-refused'
        return (Publish-InstabilityResult $out)
    }
    if ($Writer -eq 'official-test' -and [string]::IsNullOrWhiteSpace($MutexName)) {
        $MutexName = 'Local\AiGatesInstabilityTest' + (Get-InstabilityHashHex -Text $LedgerDir -Take 12)
    }
    $lockReason = Invoke-InstabilityLocked -MutexName $MutexName -Body {
        if ([string]::IsNullOrWhiteSpace($ConversationId) -or [string]::IsNullOrWhiteSpace($SourceId)) {
            $out.Reason = 'missing-id'
            return
        }
        $lines = Get-InstabilitySignalLines -Prompt $Prompt
        if ($null -eq $lines -or $lines.Count -eq 0) { return }
        $ledgerPath = Join-Path $LedgerDir 'instability-ledger.jsonl'
        $taskPath = Join-Path $LedgerDir 'instability-tasks.json'
        $tasks = Read-InstabilityTasks -Path $taskPath
        if ($null -eq $tasks) {
            $out.Reason = 'tasks-unreadable'
            return
        }
        $loaded = Read-InstabilityRows -Path $ledgerPath
        $rows = New-Object System.Collections.Generic.List[object]
        if ($null -ne $loaded) {
            foreach ($item in $loaded) { $rows.Add($item) | Out-Null }
        }
        $seen = @{}
        foreach ($r in $rows) { $seen[[string]$r.event_id] = $true }
        if (-not $tasks.ContainsKey($ConversationId)) {
            $tasks[$ConversationId] = [pscustomobject]@{ seq = 1; task_id = ($ConversationId + ':1') }
        }
        $seq = [int]$tasks[$ConversationId].seq
        $taskId = [string]$tasks[$ConversationId].task_id
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            $kind = [string](Test-InstabilityExactSignal -Line $line)
            if ($kind -eq 'new_task') {
                $eventId = 'evt-' + (Get-InstabilityHashHex -Text ($SourceId + "`n" + $i + "`n" + $line) -Take 24)
                if ($seen.ContainsKey($eventId)) {
                    foreach ($r in $rows) {
                        if ([string]$r.event_id -eq $eventId) {
                            $taskId = [string]$r.task_id
                            $tail = $taskId.Split(':')[-1]
                            try { $seq = [int]$tail } catch { }
                        }
                    }
                    continue
                }
                $seq = $seq + 1
                $taskId = $ConversationId + ':' + $seq
                $tasks[$ConversationId] = [pscustomobject]@{ seq = $seq; task_id = $taskId }
                Write-InstabilityTasks -Path $taskPath -Map $tasks
                $row = New-InstabilityRow -TaskId $taskId -ObservedTaskId $taskId -IssueId '' -EventId $eventId -EventType '任务边界' -EvidenceLevel 'control_verified' -ScoreDelta 0 -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
                if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) { $appended.Add($row) | Out-Null }
                continue
            }
            $eventId = 'evt-' + (Get-InstabilityHashHex -Text ($SourceId + "`n" + $i + "`n" + $line) -Take 24)
            if ($kind -eq 'user_fail') {
                if ($seen.ContainsKey($eventId)) { continue }
                $issueId = 'iss-' + (Get-InstabilityHashHex -Text ($SourceId + "`n" + $i + "`n" + $line) -Take 12)
                $row = New-InstabilityRow -TaskId $taskId -ObservedTaskId $taskId -IssueId $issueId -EventId $eventId -EventType '用户信号' -EvidenceLevel 'scored' -ScoreDelta $script:InstabilityUserFailScore -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
                if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) {
                    $appended.Add($row) | Out-Null
                    $echo.Add($issueId) | Out-Null
                }
                continue
            }
            if ($kind -eq 'fail_again') {
                if ($seen.ContainsKey($eventId)) { continue }
                $issueId = Get-InstabilityIssueArg -Line $line
                $origin = Get-InstabilityIssueTask -Rows $rows -IssueId $issueId
                $open = Get-InstabilityUnsettledScored -Rows $rows -IssueId $issueId
                if ($null -eq $open) { $open = @() }
                $hasScored = Test-InstabilityIssueHasScored -Rows $rows -IssueId $issueId
                if ($open.Count -gt 0 -and $origin) {
                    $row = New-InstabilityRow -TaskId $origin -ObservedTaskId $taskId -IssueId $issueId -EventId $eventId -EventType '修复失败' -EvidenceLevel 'scored' -ScoreDelta $script:InstabilityRepeatFailScore -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
                } elseif ($hasScored -and $origin) {
                    $row = New-InstabilityRow -TaskId $origin -ObservedTaskId $taskId -IssueId $issueId -EventId $eventId -EventType '修复失败' -EvidenceLevel 'scored' -ScoreDelta $script:InstabilityRepeatFailScore -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'reopened'
                } else {
                    $row = New-InstabilityRow -TaskId $taskId -ObservedTaskId $taskId -IssueId $issueId -EventId $eventId -EventType '只记录' -EvidenceLevel 'record_only' -ScoreDelta 0 -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
                }
                if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) { $appended.Add($row) | Out-Null }
                continue
            }
            if ($kind -eq 'resolved') {
                $issueId = Get-InstabilityIssueArg -Line $line
                $open = Get-InstabilityUnsettledScored -Rows $rows -IssueId $issueId
                if ($null -eq $open) { $open = @() }
                foreach ($target in $open) {
                    $offsetId = 'evt-' + (Get-InstabilityHashHex -Text ($SourceId + "`n" + $i + "`n" + $line + "`n" + [string]$target.event_id) -Take 24)
                    if ($seen.ContainsKey($offsetId)) { continue }
                    $delta = -1 * [int]$target.score_delta
                    $row = New-InstabilityRow -TaskId ([string]$target.task_id) -ObservedTaskId $taskId -IssueId $issueId -EventId $offsetId -EventType '恢复' -EvidenceLevel 'resolution_verified' -ScoreDelta $delta -SourceId $SourceId -TargetEventId ([string]$target.event_id) -EvidenceRef $line -Status 'resolved'
                    if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) { $appended.Add($row) | Out-Null }
                }
                continue
            }
            if ($seen.ContainsKey($eventId)) { continue }
            if ($kind -eq 'demand') {
                $row = New-InstabilityRow -TaskId $taskId -ObservedTaskId $taskId -IssueId '' -EventId $eventId -EventType '只记录' -EvidenceLevel 'record_only' -ScoreDelta 0 -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
            } else {
                $row = New-InstabilityRow -TaskId $taskId -ObservedTaskId $taskId -IssueId '' -EventId $eventId -EventType '用户选择' -EvidenceLevel 'control_verified' -ScoreDelta 0 -SourceId $SourceId -TargetEventId '' -EvidenceRef $line -Status 'open'
            }
            if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) { $appended.Add($row) | Out-Null }
        }
        $tasks[$ConversationId] = [pscustomobject]@{ seq = $seq; task_id = $taskId }
        Write-InstabilityTasks -Path $taskPath -Map $tasks
    }
    if ($lockReason) { $out.Reason = [string]$lockReason }
    return (Publish-InstabilityResult $out)
}

function Add-InstabilityInvalidation {
    param(
        [string]$LedgerDir,
        [string]$EventId,
        [string]$Writer,
        [string]$MutexName = ''
    )
    $appended = New-Object System.Collections.Generic.List[object]
    $out = [pscustomobject]@{ Appended = $appended; Refused = $false; Reason = '' }
    if (-not (Test-InstabilityWriter -Writer $Writer -LedgerDir $LedgerDir)) {
        $out.Refused = $true
        $out.Reason = 'writer-refused'
        return (Publish-InstabilityResult $out)
    }
    if ([string]::IsNullOrWhiteSpace($EventId)) {
        $out.Reason = 'missing-event'
        return (Publish-InstabilityResult $out)
    }
    if ($Writer -eq 'official-test' -and [string]::IsNullOrWhiteSpace($MutexName)) {
        $MutexName = 'Local\AiGatesInstabilityTest' + (Get-InstabilityHashHex -Text $LedgerDir -Take 12)
    }
    $lockReason = Invoke-InstabilityLocked -MutexName $MutexName -Body {
        $ledgerPath = Join-Path $LedgerDir 'instability-ledger.jsonl'
        $loaded = Read-InstabilityRows -Path $ledgerPath
        $rows = New-Object System.Collections.Generic.List[object]
        if ($null -ne $loaded) {
            foreach ($item in $loaded) { $rows.Add($item) | Out-Null }
        }
        $seen = @{}
        $target = $null
        foreach ($r in $rows) {
            $seen[[string]$r.event_id] = $true
            if ([string]$r.event_id -eq $EventId) { $target = $r }
        }
        if ($null -eq $target) {
            $out.Reason = 'not-found'
            return
        }
        $open = Get-InstabilityUnsettledScored -Rows $rows -IssueId ([string]$target.issue_id)
        if ($null -eq $open) { $open = @() }
        $still = $false
        foreach ($r in $open) {
            if ([string]$r.event_id -eq $EventId) { $still = $true }
        }
        if (-not $still) {
            $out.Reason = 'not-open'
            return
        }
        $offsetId = 'evt-' + (Get-InstabilityHashHex -Text ("invalidate`n" + $EventId) -Take 24)
        if ($seen.ContainsKey($offsetId)) {
            $out.Reason = 'replay'
            return
        }
        $delta = -1 * [int]$target.score_delta
        $source = 'interactive-console'
        if ($Writer -eq 'official-test') { $source = 'official-test' }
        $row = New-InstabilityRow -TaskId ([string]$target.task_id) -ObservedTaskId ([string]$target.task_id) -IssueId ([string]$target.issue_id) -EventId $offsetId -EventType '作废' -EvidenceLevel 'resolution_verified' -ScoreDelta $delta -SourceId $source -TargetEventId $EventId -EvidenceRef ('作废 event_id=' + $EventId) -Status 'invalidated'
        if (Add-InstabilityLedgerRow -Path $ledgerPath -Row $row -Rows $rows -Seen $seen) { $appended.Add($row) | Out-Null }
    }
    if ($lockReason) { $out.Reason = [string]$lockReason }
    return (Publish-InstabilityResult $out)
}

function Get-InstabilityTaskState {
    param([string]$LedgerDir, [string]$TaskId)
    $path = Join-Path $LedgerDir 'instability-ledger.jsonl'
    $rows = Read-InstabilityRows -Path $path
    if ($null -eq $rows) { $rows = @() }
    $sum = 0
    $peak = 0
    $count = 0
    foreach ($r in $rows) {
        if ([string]$r.task_id -ne $TaskId) { continue }
        $count++
        try { $sum += [int]$r.score_delta } catch { }
        $cur = $sum
        if ($cur -lt 0) { $cur = 0 }
        if ($cur -gt $peak) { $peak = $cur }
    }
    $current = $sum
    if ($current -lt 0) { $current = 0 }
    return [pscustomobject]@{ Current = $current; Peak = $peak; Rows = $count }
}

function Read-InstabilityIterationThreshold {
    param([string]$FlagPath)
    if ([string]::IsNullOrWhiteSpace($FlagPath) -or -not (Test-Path -LiteralPath $FlagPath)) { return $null }
    try {
        $obj = [System.IO.File]::ReadAllText($FlagPath, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json -ErrorAction Stop
    } catch { return $null }
    if ($null -eq $obj) { return $null }
    try { if ([int]$obj.schema -ne 1) { return $null } } catch { return $null }
    if ($obj.enabled -ne $true) { return $null }
    $threshold = 0
    try { $threshold = [int]$obj.iterationT } catch { return $null }
    if ($threshold -lt 3 -or $threshold -gt 10) { return $null }
    return $threshold
}

function Get-InstabilityStopWriteMessage {
    param([string]$LedgerDir, [string]$SessionId, [string[]]$Paths)
    if ([string]::IsNullOrWhiteSpace($SessionId) -or $SessionId -eq 'unknown') { return $null }
    $business = @()
    if (Get-Command Test-BusinessSourcePath -ErrorAction SilentlyContinue) {
        $business = @($Paths | Where-Object { Test-BusinessSourcePath -FilePath $_ })
    }
    if ($business.Count -eq 0) { return $null }
    $threshold = Read-InstabilityIterationThreshold -FlagPath (Join-Path $LedgerDir 'instability-stop-write.json')
    if ($null -eq $threshold) { return $null }
    $tasks = Read-InstabilityTasks -Path (Join-Path $LedgerDir 'instability-tasks.json')
    if ($null -eq $tasks -or -not $tasks.ContainsKey($SessionId)) { return $null }
    $taskId = [string]$tasks[$SessionId].task_id
    if ([string]::IsNullOrWhiteSpace($taskId)) { return $null }
    $state = Get-InstabilityTaskState -LedgerDir $LedgerDir -TaskId $taskId
    if ($state.Current -lt $threshold) { return $null }
    return ('不稳度 ' + $state.Current + ' 已到迭代阈值 ' + $threshold + '。这一轮先停业务写入。')
}
