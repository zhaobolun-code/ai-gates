# test-instability-ledger.ps1
# 影子期官方事件样例。只写临时目录，不写 hooks-log 里的正式账本。

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$hooksDir = Join-Path (Split-Path -Parent $scriptDir) 'hooks'
. (Join-Path $hooksDir 'instability-ledger.ps1')
. (Join-Path $hooksDir 'gate-decision.ps1')

$failed = 0
function Assert-Instability {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

function New-InstabilityTemp {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('instability-ledger-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Read-InstabilityTestRows {
    param([string]$Dir)
    return @(Read-InstabilityRows -Path (Join-Path $Dir 'instability-ledger.jsonl'))
}

$live = Join-Path (Split-Path -Parent $scriptDir) 'hooks-log\instability-ledger.jsonl'
$liveBefore = ''
if (Test-Path -LiteralPath $live) { $liveBefore = [System.IO.File]::ReadAllText($live, (New-Object System.Text.UTF8Encoding $false)) }

$refusedLive = Add-InstabilityPromptEvents -LedgerDir (Split-Path -Parent $live) -ConversationId 'c' -SourceId 's' -Prompt "治理信号：这次失败" -Writer 'official-test'
Assert-Instability 'official test cannot write the live ledger' $refusedLive.Refused $refusedLive.Reason
$refusedHook = Add-InstabilityPromptEvents -LedgerDir (New-InstabilityTemp) -ConversationId 'c' -SourceId 's' -Prompt "治理信号：这次失败" -Writer 'hook'
Assert-Instability 'hook writer refuses a process that is not the collector' $refusedHook.Refused $refusedHook.Reason
$refusedInv = Add-InstabilityInvalidation -LedgerDir (New-InstabilityTemp) -EventId 'evt-x' -Writer 'invalidate-script'
Assert-Instability 'invalidate writer refuses this process' $refusedInv.Refused $refusedInv.Reason

$dir = New-InstabilityTemp
try {
    $marker = 'PROMPT-MARKER-7f3a'
    $first = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-a' -SourceId 'src-1' -Prompt ("前言 $marker`n治理信号：这次失败") -Writer 'official-test'
    Assert-Instability 'user fail appends one scored row' (@($first.Appended).Count -eq 1 -and $first.Appended[0].score_delta -eq 3 -and $first.Appended[0].evidence_level -eq 'scored' -and $first.Appended[0].event_type -eq '用户信号' -and $first.Appended[0].status -eq 'open') "count=$(@($first.Appended).Count)"
    $issue = [string]$first.EchoIssueIds[0]
    Assert-Instability 'new failure echoes an issue id' ($issue -match '^iss-[0-9a-f]{12}$') $issue
    $state = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'new failure current is 3' ($state.Current -eq 3 -and $state.Peak -eq 3) "current=$($state.Current) peak=$($state.Peak)"
    $raw = [System.IO.File]::ReadAllText((Join-Path $dir 'instability-ledger.jsonl'), (New-Object System.Text.UTF8Encoding $false))
    Assert-Instability 'ledger keeps the matched line and not the prompt' ($raw -match '治理信号：这次失败' -and $raw -notmatch [regex]::Escape($marker)) ''

    $replay = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-a' -SourceId 'src-1' -Prompt ("前言 $marker`n治理信号：这次失败") -Writer 'official-test'
    $state = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'same source does not score twice' (@($replay.Appended).Count -eq 0 -and $state.Current -eq 3 -and $state.Rows -eq 1) "appended=$(@($replay.Appended).Count) rows=$($state.Rows)"

    $again = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-b' -SourceId 'src-2' -Prompt ("治理信号：这次没修好 issue_id=$issue") -Writer 'official-test'
    $stateA = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    $stateB = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-b:1'
    Assert-Instability 'repeat failure scores on the original task' (@($again.Appended).Count -eq 1 -and $again.Appended[0].score_delta -eq 2 -and $again.Appended[0].task_id -eq 'conv-a:1' -and $again.Appended[0].observed_task_id -eq 'conv-b:1' -and $again.Appended[0].status -eq 'open' -and $stateA.Current -eq 5 -and $stateB.Current -eq 0) "a=$($stateA.Current) b=$($stateB.Current) status=$($again.Appended[0].status)"

    $fixed = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-b' -SourceId 'src-3' -Prompt ("治理信号：已经修好 issue_id=$issue") -Writer 'official-test'
    $stateA = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'resolve offsets each open scored event once' (@($fixed.Appended).Count -eq 2 -and $stateA.Current -eq 0 -and $stateA.Peak -eq 5) "appended=$(@($fixed.Appended).Count) current=$($stateA.Current) peak=$($stateA.Peak)"
    $fixedAgain = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-b' -SourceId 'src-3' -Prompt ("治理信号：已经修好 issue_id=$issue") -Writer 'official-test'
    $stateA = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'resolve replay does not offset twice' (@($fixedAgain.Appended).Count -eq 0 -and $stateA.Current -eq 0 -and $stateA.Peak -eq 5) "current=$($stateA.Current)"

    $reopen = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-b' -SourceId 'src-4' -Prompt ("治理信号：这次没修好 issue_id=$issue") -Writer 'official-test'
    $stateA = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'failure after resolve reopens' (@($reopen.Appended).Count -eq 1 -and $reopen.Appended[0].status -eq 'reopened' -and $reopen.Appended[0].score_delta -eq 2 -and $stateA.Current -eq 2 -and $stateA.Peak -eq 5) "status=$($reopen.Appended[0].status) current=$($stateA.Current)"

    $void = Add-InstabilityInvalidation -LedgerDir $dir -EventId $reopen.Appended[0].event_id -Writer 'official-test'
    $stateA = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-a:1'
    Assert-Instability 'invalidate removes that score and keeps the peak' (@($void.Appended).Count -eq 1 -and $void.Appended[0].status -eq 'invalidated' -and $void.Appended[0].score_delta -eq -2 -and $stateA.Current -eq 0 -and $stateA.Peak -eq 5) "current=$($stateA.Current) peak=$($stateA.Peak)"
    $voidAgain = Add-InstabilityInvalidation -LedgerDir $dir -EventId $reopen.Appended[0].event_id -Writer 'official-test'
    Assert-Instability 'invalidate replay does not offset twice' (@($voidAgain.Appended).Count -eq 0 -and $voidAgain.Reason -eq 'not-open') $voidAgain.Reason
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

$dir = New-InstabilityTemp
try {
    $early = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-c' -SourceId 'src-early' -Prompt '治理信号：已经修好 issue_id=iss-doesnotexist' -Writer 'official-test'
    $late = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-c' -SourceId 'src-late' -Prompt '治理信号：这次失败' -Writer 'official-test'
    $state = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-c:1'
    Assert-Instability 'resolve before the failure does not invent a score' (@($early.Appended).Count -eq 0 -and $state.Current -eq 3 -and $state.Rows -eq 1) "early=$(@($early.Appended).Count) rows=$($state.Rows)"
    $unknown = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-c' -SourceId 'src-unknown' -Prompt '治理信号：这次没修好 issue_id=iss-missing0001' -Writer 'official-test'
    $state = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-c:1'
    Assert-Instability 'unknown issue is record only' ($unknown.Appended[0].evidence_level -eq 'record_only' -and $unknown.Appended[0].score_delta -eq 0 -and $state.Current -eq 3) "level=$($unknown.Appended[0].evidence_level) current=$($state.Current)"
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

$dir = New-InstabilityTemp
try {
    $prompt = "治理信号：这次失败`n治理选择：新任务`n治理信号：这次失败"
    $split = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-d' -SourceId 'src-split' -Prompt $prompt -Writer 'official-test'
    $oldTask = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-d:1'
    $newTask = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-d:2'
    Assert-Instability 'new task keeps the old score and starts the next task' ($oldTask.Current -eq 3 -and $newTask.Current -eq 3 -and @($split.EchoIssueIds).Count -eq 2) "old=$($oldTask.Current) new=$($newTask.Current) echo=$(@($split.EchoIssueIds).Count)"
    $rows = Read-InstabilityTestRows -Dir $dir
    $boundary = @($rows | Where-Object { $_.event_type -eq '任务边界' -and $_.task_id -eq 'conv-d:2' -and $_.score_delta -eq 0 })
    Assert-Instability 'new task writes a zero boundary on the new task' ($boundary.Count -eq 1) "count=$($boundary.Count)"

    $demand = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-d' -SourceId 'src-demand' -Prompt "治理信号：需求变了" -Writer 'official-test'
    $choice = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-d' -SourceId 'src-choice' -Prompt "治理选择：保持车道" -Writer 'official-test'
    Assert-Instability 'demand change and lane choice do not score' ($demand.Appended[0].score_delta -eq 0 -and $demand.Appended[0].evidence_level -eq 'record_only' -and $choice.Appended[0].score_delta -eq 0 -and $choice.Appended[0].evidence_level -eq 'control_verified' -and $choice.Appended[0].event_type -eq '用户选择') ''
    Assert-Instability 'shadow choice does not write a blocked mark' (-not (Test-Path -LiteralPath (Join-Path $dir 'blocked'))) ''

    $none = @()
    $fenced = '```' + "`n" + '治理信号：这次失败' + "`n" + '```'
    $none += @(Get-InstabilitySignalLines -Prompt $fenced)
    $none += @(Get-InstabilitySignalLines -Prompt '> 治理信号：这次失败')
    $none += @(Get-InstabilitySignalLines -Prompt '请看 治理信号：这次失败')
    $none += @(Get-InstabilitySignalLines -Prompt '治理信号:这次失败')
    $emptySignals = @($none | Where-Object { $_ })
    Assert-Instability 'fence quote partial and half-width lines do not match' ($emptySignals.Count -eq 0) "count=$($emptySignals.Count)"
    $skipped = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId 'conv-d' -SourceId 'src-skip' -Prompt "> 治理信号：这次失败`n请看 治理信号：这次失败" -Writer 'official-test'
    Assert-Instability 'non exact lines append nothing' (@($skipped.Appended).Count -eq 0) "count=$(@($skipped.Appended).Count)"

    $missing = Add-InstabilityPromptEvents -LedgerDir $dir -ConversationId '' -SourceId '' -Prompt '治理信号：这次失败' -Writer 'official-test'
    Assert-Instability 'missing source does not score' ($missing.Reason -eq 'missing-id' -and @($missing.Appended).Count -eq 0) $missing.Reason
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

$dir = New-InstabilityTemp
try {
    $lib = (Resolve-Path (Join-Path $hooksDir 'instability-ledger.ps1')).Path
    $mutex = 'Local\AiGatesInstabilityTest' + [Guid]::NewGuid().ToString('N')
    $jobs = @()
    for ($n = 0; $n -lt 4; $n++) {
        $jobs += Start-Job -ScriptBlock {
            param($LibPath, $Ledger, $MutexName)
            . $LibPath
            Add-InstabilityPromptEvents -LedgerDir $Ledger -ConversationId 'conv-race' -SourceId 'src-race' -Prompt '治理信号：这次失败' -Writer 'official-test' -MutexName $MutexName | Out-Null
        } -ArgumentList $lib, $dir, $mutex
    }
    $null = Wait-Job -Job $jobs
    $jobs | Receive-Job -ErrorAction SilentlyContinue | Out-Null
    $jobs | Remove-Job -Force | Out-Null
    $race = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-race:1'
    Assert-Instability 'concurrent replay of one source scores once' ($race.Current -eq 3 -and $race.Rows -eq 1) "current=$($race.Current) rows=$($race.Rows)"
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

$dir = New-InstabilityTemp
try {
    $hook = Join-Path $hooksDir 'collect-instability-prompt.ps1'
    $payload = @{
        conversation_id = 'conv-hook'
        generation_id = 'gen-hook-1'
        prompt = "正文 PROMPT-MARKER-hook`n治理信号：这次失败"
    } | ConvertTo-Json -Compress
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$hook`" -LedgerDir `"$dir`""
    $psi.WorkingDirectory = (Split-Path -Parent (Split-Path -Parent $scriptDir))
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $bytes = (New-Object System.Text.UTF8Encoding $false).GetBytes($payload)
    $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $hookState = Get-InstabilityTaskState -LedgerDir $dir -TaskId 'conv-hook:1'
    $echo = ''
    $echoPath = Join-Path $dir 'instability-echo.log'
    if (Test-Path -LiteralPath $echoPath) { $echo = [System.IO.File]::ReadAllText($echoPath, (New-Object System.Text.UTF8Encoding $false)) }
    Assert-Instability 'hook allows and records one failure' ($proc.ExitCode -eq 0 -and $stdout.Trim() -eq '{"continue":true,"permission":"allow"}' -and $hookState.Current -eq 3 -and $echo -match 'issue_id=iss-' -and $stdout -notmatch 'PROMPT-MARKER-hook') "exit=$($proc.ExitCode) stdout=$stdout stderr=$stderr current=$($hookState.Current)"

    $dir2 = New-InstabilityTemp
    $payload2 = @{ conversation_id = 'conv-hook'; prompt = "治理信号：这次失败" } | ConvertTo-Json -Compress
    $psi2 = New-Object System.Diagnostics.ProcessStartInfo
    $psi2.FileName = 'powershell.exe'
    $psi2.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$hook`" -LedgerDir `"$dir2`""
    $psi2.RedirectStandardInput = $true
    $psi2.RedirectStandardOutput = $true
    $psi2.RedirectStandardError = $true
    $psi2.UseShellExecute = $false
    $psi2.CreateNoWindow = $true
    $proc2 = [System.Diagnostics.Process]::Start($psi2)
    $bytes2 = (New-Object System.Text.UTF8Encoding $false).GetBytes($payload2)
    $proc2.StandardInput.BaseStream.Write($bytes2, 0, $bytes2.Length)
    $proc2.StandardInput.Close()
    $stdout2 = $proc2.StandardOutput.ReadToEnd()
    $proc2.WaitForExit()
    $port2 = ''
    $portPath2 = Join-Path $dir2 'instability-port.log'
    if (Test-Path -LiteralPath $portPath2) { $port2 = [System.IO.File]::ReadAllText($portPath2, (New-Object System.Text.UTF8Encoding $false)) }
    Assert-Instability 'hook without a message id does not score' ($proc2.ExitCode -eq 0 -and $stdout2.Trim() -eq '{"continue":true,"permission":"allow"}' -and -not (Test-Path -LiteralPath (Join-Path $dir2 'instability-ledger.jsonl')) -and $port2 -match 'missing-id') "stdout=$stdout2 port=$port2"
    Remove-Item -LiteralPath $dir2 -Recurse -Force -ErrorAction SilentlyContinue
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

$biz = Get-WriteGateVerdict -HostName cursor -Paths @('Assets/Foo.cs') -GateState Ok -OwnPm Missing
Assert-Instability 'business write stays allowed' ($biz.Allow -and $biz.Detail -eq 'business_write') $biz.Detail
$ledgerDeny = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/instability-ledger.jsonl') -GateState Ok -OwnPm Fresh
Assert-Instability 'editor cannot write the ledger' ((-not $ledgerDeny.Allow) -and $ledgerDeny.Detail -eq 'gate_auth_state') $ledgerDeny.Detail
$taskDeny = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/instability-tasks.json') -GateState Ok -OwnPm Fresh
Assert-Instability 'editor cannot write the task file' ((-not $taskDeny.Allow) -and $taskDeny.Detail -eq 'gate_auth_state') $taskDeny.Detail
Assert-Instability 'collector script name is denied' (Test-AuthScriptInvoke -CommandText 'powershell -File .ai-gates\hooks\collect-instability-prompt.ps1') ''
Assert-Instability 'invalidate script name is denied' (Test-AuthScriptInvoke -CommandText 'powershell -File .ai-gates/scripts/invalidate-instability-event.ps1') ''
Assert-Instability 'enable iteration stop-write script name is denied' (Test-AuthScriptInvoke -CommandText 'powershell -File .ai-gates/scripts/enable-instability-stop-write.ps1 -IterationT 3') ''
Assert-Instability 'disable iteration stop-write script name is denied' (Test-AuthScriptInvoke -CommandText 'powershell -File .ai-gates/scripts/disable-instability-stop-write.ps1') ''
$flagDeny = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/instability-stop-write.json') -GateState Ok -OwnPm Fresh
Assert-Instability 'editor cannot write the iteration flag' ((-not $flagDeny.Allow) -and $flagDeny.Detail -eq 'gate_auth_state') $flagDeny.Detail

$fastDir = New-InstabilityTemp
try {
    $null = Add-InstabilityPromptEvents -LedgerDir $fastDir -ConversationId 'conv-fast' -SourceId 'src-fast' -Prompt '治理信号：这次失败' -Writer 'official-test'
    $off = Get-InstabilityStopWriteMessage -LedgerDir $fastDir -SessionId 'conv-fast' -Paths @('Assets/Foo.cs')
    Assert-Instability 'stop-write stays off without a flag' ($null -eq $off) ([string]$off)
    $flagPath = Join-Path $fastDir 'instability-stop-write.json'
    $utf8Flag = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($flagPath, '{"schema":1,"enabled":true,"iterationT":3}', $utf8Flag)
    $on = Get-InstabilityStopWriteMessage -LedgerDir $fastDir -SessionId 'conv-fast' -Paths @('Assets/Foo.cs')
    Assert-Instability 'iteration threshold 3 stops a scored failure' ($on -match '迭代阈值 3') ([string]$on)
    [System.IO.File]::WriteAllText($flagPath, '{"schema":1,"enabled":true,"iterationT":10}', $utf8Flag)
    $under = Get-InstabilityStopWriteMessage -LedgerDir $fastDir -SessionId 'conv-fast' -Paths @('Assets/Foo.cs')
    Assert-Instability 'score under the iteration threshold still allows' ($null -eq $under) ([string]$under)
    [System.IO.File]::WriteAllText($flagPath, '{"schema":1,"enabled":true,"iterationT":3}', $utf8Flag)
    $note = Get-InstabilityStopWriteMessage -LedgerDir $fastDir -SessionId 'conv-fast' -Paths @('README.md')
    Assert-Instability 'iteration stop-write ignores non-business files' ($null -eq $note) ([string]$note)
} finally {
    Remove-Item -LiteralPath $fastDir -Recurse -Force -ErrorAction SilentlyContinue
}

$liveFlag = Join-Path (Split-Path -Parent $live) 'instability-stop-write.json'
$liveFlagBefore = Test-Path -LiteralPath $liveFlag
$enableScript = Join-Path $scriptDir 'enable-instability-stop-write.ps1'
$psiFlag = New-Object System.Diagnostics.ProcessStartInfo
$psiFlag.FileName = 'powershell.exe'
$psiFlag.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$enableScript`" -IterationT 3"
$psiFlag.RedirectStandardInput = $true
$psiFlag.RedirectStandardOutput = $true
$psiFlag.RedirectStandardError = $true
$psiFlag.UseShellExecute = $false
$psiFlag.CreateNoWindow = $true
$procFlag = [System.Diagnostics.Process]::Start($psiFlag)
$procFlag.StandardInput.Close()
$null = $procFlag.StandardOutput.ReadToEnd()
$procFlag.WaitForExit()
Assert-Instability 'redirected enable does not turn stop-write on' ($procFlag.ExitCode -ne 0 -and (Test-Path -LiteralPath $liveFlag) -eq $liveFlagBefore) "exit=$($procFlag.ExitCode)"

$liveAfter = ''
if (Test-Path -LiteralPath $live) { $liveAfter = [System.IO.File]::ReadAllText($live, (New-Object System.Text.UTF8Encoding $false)) }
Assert-Instability 'samples did not touch the live ledger' ($liveBefore -eq $liveAfter) ''

if ($failed -gt 0) {
    Write-Host "FAILED $failed"
    exit 1
}
Write-Host 'OK'
exit 0
