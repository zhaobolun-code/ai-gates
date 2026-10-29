# test-gate-decision.ps1
# 同一批判定夹具，不经宿主 JSON。三端入口各自的封套测试仍在 test-hooks / test-claude-hooks / test-codex-hooks。

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\hooks\gate-decision.ps1')

$failed = 0
function Assert-Decision {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

Assert-Decision 'force push has a reason' ([bool](Test-DangerousGitCommand -CommandText 'git push origin main --force')) ''
Assert-Decision 'status is not dangerous' (-not (Test-DangerousGitCommand -CommandText 'git status')) ''
Assert-Decision 'reset hard has a reason' ([bool](Test-DangerousGitCommand -CommandText 'git reset --hard HEAD~1')) ''
Assert-Decision 'force-with-lease is not a deny' (-not (Test-DangerousGitCommand -CommandText 'git push --force-with-lease')) ''
Assert-Decision 'force-with-lease is marked' (Test-GitForceWithLease -CommandText 'git push --force-with-lease') ''
Assert-Decision 'dash C force push is denied' ([bool](Test-DangerousGitCommand -CommandText 'git -C repo push --force')) ''
Assert-Decision 'dash C hard reset is denied' ([bool](Test-DangerousGitCommand -CommandText 'git -C ./some-repo reset --hard')) ''
Assert-Decision 'git dir hard reset is denied' ([bool](Test-DangerousGitCommand -CommandText 'git --git-dir=repo/.git reset --hard')) ''
Assert-Decision 'lease after dash C is not a deny' (-not (Test-DangerousGitCommand -CommandText 'git -C repo push --force-with-lease')) ''
Assert-Decision 'unknown git option stays unparsed' (Test-GitCommandUnparsed -CommandText 'git --no-such-opt status') ''
Assert-Decision 'paginate status is parsed' (-not (Test-GitCommandUnparsed -CommandText 'git --paginate status')) ''
Assert-Decision 'known global option is parsed' (-not (Test-GitCommandUnparsed -CommandText 'git -C repo status')) ''
Assert-Decision 'quoted dash C hard reset is denied' ([bool](Test-DangerousGitCommand -CommandText 'git -C "my repo" reset --hard')) ''
Assert-Decision 'second command after semicolon is denied' ([bool](Test-DangerousGitCommand -CommandText 'git status; git -C repo reset --hard')) ''
Assert-Decision 'newline separated force push is denied' ([bool](Test-DangerousGitCommand -CommandText "git status`ngit -C repo push --force")) ''
Assert-Decision 'env prefix hard reset is denied' ([bool](Test-DangerousGitCommand -CommandText 'GIT_DIR=repo git reset --hard')) ''
Assert-Decision 'bash wrapper force push is denied' ([bool](Test-DangerousGitCommand -CommandText 'bash -lc "git push --force"')) ''
Assert-Decision 'paginate before dash C is denied' ([bool](Test-DangerousGitCommand -CommandText 'git --paginate -C repo push --force')) ''
Assert-Decision 'paginate before dash C is parsed' (-not (Test-GitCommandUnparsed -CommandText 'git --paginate -C repo push --force')) ''
Assert-Decision 'unknown option with force push is denied' ([bool](Test-DangerousGitCommand -CommandText 'git --no-such-opt push --force')) ''
Assert-Decision 'unknown option status is not denied' (-not (Test-DangerousGitCommand -CommandText 'git --no-such-opt status')) ''
Assert-Decision 'config then force push is denied' ([bool](Test-DangerousGitCommand -CommandText 'git -c user.email=a@b.com push --force')) ''
Assert-Decision 'log patch is not denied' (-not (Test-DangerousGitCommand -CommandText 'git log -p')) ''
. (Join-Path $PSScriptRoot 'official-version.ps1')
Assert-Decision 'plain version is official' (Test-OfficialVersion -Version '5.1.0') ''
Assert-Decision 'v prefix is official' (Test-OfficialVersion -Version 'v5.1.0') ''
Assert-Decision 'garbage suffix is not official' (-not (Test-OfficialVersion -Version '5.1.0garbage')) ''
Assert-Decision 'v tag matches pack version' (Test-TagMatchesPackVersion -Tag 'v5.2.0' -PackVersion '5.2.0') ''
Assert-Decision 'different tag does not match pack' (-not (Test-TagMatchesPackVersion -Tag 'v5.2.0' -PackVersion '5.1.0')) ''

$paths = @(Get-ExplicitWritePaths -CommandText 'Set-Content -Path Assets/Foo.cs -Value 1')
Assert-Decision 'set-content path extracted' ($paths -contains 'Assets/Foo.cs') ($paths -join ',')
$none = @(Get-ExplicitWritePaths -CommandText 'git status')
Assert-Decision 'git status extracts no write path' ($none.Count -eq 0) "count=$($none.Count)"

Assert-Decision 'tmp is generated' (Test-GeneratedWritePath -FilePath '.ai-gates/tmp/x.txt') ''
Assert-Decision 'cursor path is infra' (Test-InfraWritePath -FilePath '.cursor/hooks/a.ps1') ''
Assert-Decision 'claude path needs the switch' ((-not (Test-InfraWritePath -FilePath '.claude/settings.json')) -and (Test-InfraWritePath -FilePath '.claude/settings.json' -IncludeClaude)) ''

$deny = Get-ShellWriteBlocks -Paths @('Assets/Foo.cs') -HasFreshPm $false -HasFreshChangelog $false
Assert-Decision 'business without pm blocks' ($deny.Count -eq 1 -and $deny[0].Reason -eq 'business_no_fresh_pm') "count=$($deny.Count)"
$ok = Get-ShellWriteBlocks -Paths @('Assets/Foo.cs') -HasFreshPm $true -HasFreshChangelog $false
Assert-Decision 'business with pm allows' ($ok.Count -eq 0) "count=$($ok.Count)"
$gen = Get-ShellWriteBlocks -Paths @('.ai-gates/tmp/x.txt') -HasFreshPm $false -HasFreshChangelog $false
Assert-Decision 'generated path allows' ($gen.Count -eq 0) "count=$($gen.Count)"
$authShell = @(Get-ShellWriteBlocks -Paths @('.ai-gates/hooks-log/pm-gate.json') -HasFreshPm $true -HasFreshChangelog $true)
Assert-Decision 'shell cannot forge pm stamp' ($authShell.Count -eq 1 -and $authShell[0].Reason -eq 'gate_auth_state') "count=$($authShell.Count)"
$authLog = Get-ShellWriteBlocks -Paths @('.ai-gates/hooks-log/git-safety-check.log') -HasFreshPm $false -HasFreshChangelog $false
Assert-Decision 'shell can still append a hook log' ($authLog.Count -eq 0) "count=$($authLog.Count) reason=$($authLog[0].Reason)"
$authWrite = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/changelog-writes.json') -GateState Ok -OwnPm Fresh
Assert-Decision 'editor cannot forge changelog stamp' ((-not $authWrite.Allow) -and $authWrite.Detail -eq 'gate_auth_state') $authWrite.Detail
$knifeWrite = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/knife-state.json') -GateState Ok -OwnPm Missing -ParentHasFreshPm $true
Assert-Decision 'child cannot forge knife state' ((-not $knifeWrite.Allow) -and $knifeWrite.Detail -eq 'gate_auth_state') $knifeWrite.Detail
$infra = Get-ShellWriteBlocks -Paths @('.cursor/skills/a.md') -HasFreshPm $true -HasFreshChangelog $false
Assert-Decision 'infra without changelog blocks' ($infra.Count -eq 1 -and $infra[0].Reason -eq 'infra_no_recent_changelog') "count=$($infra.Count)"

$await = '{"awaitingHumanTest":true,"window":"w","acceptance":"A1","symptom":"left still full","hotfixCount":0,"lane":"Direct","hotfixLane":"Direct"}'
Assert-Decision 'awaiting human test blocks cs' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.cs' -StateJson $await) -eq 'awaiting_human_test') ''
Assert-Decision 'awaiting human test ignores md' ((Get-KnifeBusinessDeny -FilePath 'README.md' -StateJson $await) -eq $null) ''
$second = '{"awaitingHumanTest":false,"window":"w","acceptance":"A1","symptom":"left still full","hotfixCount":1,"lane":"Direct","hotfixLane":"Direct"}'
Assert-Decision 'second hotfix still allows' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.cs' -StateJson $second) -eq $null) ''
$third = '{"awaitingHumanTest":false,"window":"w","acceptance":"A1","symptom":"left still full","hotfixCount":2,"lane":"Direct","hotfixLane":"Direct"}'
Assert-Decision 'third hotfix blocks' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.lua' -StateJson $third) -eq 'third_hotfix') ''
$up = '{"awaitingHumanTest":false,"window":"w","acceptance":"A1","symptom":"left still full","hotfixCount":4,"lane":"Standard","hotfixLane":"Direct"}'
Assert-Decision 'lane upgrade allows' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.cs' -StateJson $up) -eq $null) ''
$gap = '{"awaitingHumanTest":false,"window":"w","acceptance":"","symptom":"left still full","hotfixCount":9,"lane":"Direct","hotfixLane":"Direct"}'
Assert-Decision 'missing acceptance allows' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.cs' -StateJson $gap) -eq $null) ''
Assert-Decision 'bad state allows' ((Get-KnifeBusinessDeny -FilePath 'Assets/Foo.cs' -StateJson '{') -eq $null) ''
Assert-Decision 'screenshot ratio is heavy' (Test-OldContextHeavy -InputTokens 1514997 -CacheReadTokens 1504512 -AlreadyPrompted $false) ''
Assert-Decision 'eighty percent at floor is heavy' (Test-OldContextHeavy -InputTokens 200000 -CacheReadTokens 160000 -AlreadyPrompted $false) ''
Assert-Decision 'just under eighty is not heavy' (-not (Test-OldContextHeavy -InputTokens 200000 -CacheReadTokens 159999 -AlreadyPrompted $false)) ''
Assert-Decision 'small thread is not heavy' (-not (Test-OldContextHeavy -InputTokens 199999 -CacheReadTokens 199999 -AlreadyPrompted $false)) ''
Assert-Decision 'already prompted stays quiet' (-not (Test-OldContextHeavy -InputTokens 1514997 -CacheReadTokens 1504512 -AlreadyPrompted $true)) ''
Assert-Decision 'four digits stay plain' ((Format-TokenCount 9999) -eq '9999') ''
Assert-Decision 'screenshot input uses wan' ((Format-TokenCount 406259) -eq '40.6万') ''
Assert-Decision 'screenshot cache uses wan' ((Format-TokenCount 403840) -eq '40.4万') ''
Assert-Decision 'exact wan drops the decimal' ((Format-TokenCount 10000) -eq '1万') ''
Assert-Decision 'missing count stays unmarked' ((Format-TokenCount $null) -eq '未记到') ''
$heavyLine = Get-TurnTokenLine -InputTokens 406259 -OutputTokens 333 -CacheReadTokens 403840 -CacheWriteTokens 0 -ShowNotice $true
$notice = '已满足换窗条件, 请执行换窗逻辑减少token消耗'
Assert-Decision 'heavy token line has a second line' ($heavyLine.StartsWith('token：上一轮 输入 40.6万 / 输出 333 / 缓存读 40.4万 / 缓存写 0') -and $heavyLine.EndsWith("`n$notice")) $heavyLine
$heavyHint = Get-TurnTokenHint -TokenLine $heavyLine
Assert-Decision 'heavy hint demands a line break' ($heavyHint.Contains('必须换行') -and $heavyHint.Contains($notice) -and $heavyHint.Contains('禁止用空格代替换行')) $heavyHint
$again = Get-TurnTokenLine -InputTokens 623730 -OutputTokens 3660 -CacheReadTokens 617216 -CacheWriteTokens 0 -ShowNotice $true
Assert-Decision 'heavy token line repeats' ($again.StartsWith('token：上一轮 输入 62.4万 / 输出 3660 / 缓存读 61.7万 / 缓存写 0') -and $again.Contains("`n$notice")) $again
$freshHeavy = Get-TurnTokenLine -InputTokens 2194958 -OutputTokens 50265 -CacheReadTokens 1853056 -CacheWriteTokens 0 -ShowNotice $false
Assert-Decision 'fresh heavy window has numbers only' ($freshHeavy -eq 'token：上一轮 输入 219.5万 / 输出 5万 / 缓存读 185.3万 / 缓存写 0') $freshHeavy
Assert-Decision 'first sample does not notice' (-not (Test-ShowHandoverNotice -InputTokens 2194958 -CacheReadTokens 1853056 -FirstInput $null)) ''
Assert-Decision 'flat window does not notice' (-not (Test-ShowHandoverNotice -InputTokens 2194958 -CacheReadTokens 1853056 -FirstInput 2194958)) ''
Assert-Decision 'growth of twenty wan notices' (Test-ShowHandoverNotice -InputTokens 2394958 -CacheReadTokens 2000000 -FirstInput 2194958) ''
Assert-Decision 'growth just under does not notice' (-not (Test-ShowHandoverNotice -InputTokens 2394957 -CacheReadTokens 2000000 -FirstInput 2194958)) ''
$lightLine = Get-TurnTokenLine -InputTokens 32322 -OutputTokens 1476 -CacheReadTokens 5376 -CacheWriteTokens 0
Assert-Decision 'light token line has no second line' ($lightLine -eq 'token：上一轮 输入 3.2万 / 输出 1476 / 缓存读 5376 / 缓存写 0') $lightLine
Assert-Decision 'evidence must contain the symptom' (Test-HumanTestEvidence -Symptom 'left still full' -EvidenceText 'saw left still full') ''
Assert-Decision 'empty evidence does not clear' (-not (Test-HumanTestEvidence -Symptom 'left still full' -EvidenceText '')) ''
$decisionText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\hooks\gate-decision.ps1") -Raw -Encoding UTF8
Assert-Decision 'knife codes stay in the source' ($decisionText.Contains('awaiting_human_test') -and $decisionText.Contains('third_hotfix')) ''
$first = Update-KnifeState -ExistingJson '' -Window 'w' -Acceptance 'A1' -Symptom 'left full' -Lane 'Direct' -NeedsHumanTest $true
Assert-Decision 'first knife awaits test' ($first.awaitingHumanTest -eq $true -and $first.hotfixCount -eq 0 -and $first.hotfixLane -eq 'Direct') ''
$again = Update-KnifeState -ExistingJson ($first | ConvertTo-Json -Compress) -Window 'w' -Acceptance 'A1' -Symptom 'left full' -Lane 'Direct' -NeedsHumanTest $true
Assert-Decision 'same knife increments hotfix' ($again.hotfixCount -eq 1 -and $again.hotfixLane -eq 'Direct') ''
Assert-Decision 'stamp path recognized' (Test-CrStampPath -FilePath '.ai-gates/hooks-log/cr-stamp.json') ''
Assert-Decision 'main window cannot write stamp' ((Get-CrStampDeny -FilePath '.ai-gates/hooks-log/cr-stamp.json' -IsMainWindow $true) -eq 'cr_stamp_main_window') ''
Assert-Decision 'reviewer can write stamp' ((Get-CrStampDeny -FilePath '.ai-gates/hooks-log/cr-stamp.json' -IsMainWindow $false) -eq $null) ''
$cursorMiss = Get-WriteGateVerdict -HostName cursor -Paths @('Assets/Foo.cs') -GateState Missing -OwnPm Missing
Assert-Decision 'cursor missing gate uses conversation code' ((-not $cursorMiss.Allow) -and $cursorMiss.Detail -eq 'gate_file_missing') $cursorMiss.Detail
$claudeParse = Get-WriteGateVerdict -HostName claude -Paths @('Assets/Foo.cs') -ParseFailed $true -OwnPm Fresh
Assert-Decision 'claude parse fail keeps its code' ((-not $claudeParse.Allow) -and $claudeParse.Detail -eq 'parse_failed_business_code' -and $claudeParse.Message.Contains('main_window_business_code')) $claudeParse.Detail
$cursorParse = Get-WriteGateVerdict -HostName cursor -Paths @('Assets/Foo.cs') -ParseFailed $true -OwnPm Fresh
Assert-Decision 'cursor parse fail stays main window code' ((-not $cursorParse.Allow) -and $cursorParse.Detail -eq 'main_window_business_code') $cursorParse.Detail
$rootReadme = Get-WriteGateVerdict -HostName cursor -Paths @('README.md') -GateState Ok -OwnPm Fresh
Assert-Decision 'root readme is not facility' ($rootReadme.Allow -and $rootReadme.Detail -eq 'window_pm_not_this_turn') $rootReadme.Detail
$stamp = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/hooks-log/cr-stamp.json') -OwnPm Fresh
Assert-Decision 'verdict blocks main window stamp' ((-not $stamp.Allow) -and $stamp.Detail -eq 'cr_stamp_main_window') $stamp.Detail
$planDispatch = 'Assets/LabSDK/证据/_方案审核派发.md'
Assert-Decision 'plan dispatch path recognized' (Test-ReviewDispatchPath -FilePath $planDispatch) ''
Assert-Decision 'verify dispatch is not the review file' (-not (Test-ReviewDispatchPath -FilePath '证据/_Step01-验收派发.md')) ''
$mainDispatch = Get-WriteGateVerdict -HostName cursor -Paths @($planDispatch) -GateState Ok -OwnPm Fresh
Assert-Decision 'main window cannot write plan dispatch' ((-not $mainDispatch.Allow) -and $mainDispatch.Detail -eq 'dispatch_main_window') $mainDispatch.Detail
$codeDispatch = Get-WriteGateVerdict -HostName cursor -Paths @('证据/_Step02-代码审核派发.md') -GateState Ok -OwnPm Fresh
Assert-Decision 'main window cannot write code dispatch' ((-not $codeDispatch.Allow) -and $codeDispatch.Detail -eq 'dispatch_main_window') $codeDispatch.Detail
$childDispatch = Get-WriteGateVerdict -HostName cursor -Paths @($planDispatch) -GateState Ok -OwnPm Missing -ParentHasFreshPm $true
Assert-Decision 'planner child can write plan dispatch' ($childDispatch.Allow) $childDispatch.Detail
$rootLog = (($script:AiGatesDecisionRoot -replace '\\', '/').TrimEnd('/')) + '/.ai-gates/CHANGELOG.md'
Assert-Decision 'official changelog is this repo root' ((Test-OfficialChangelogPath -FilePath '.ai-gates/CHANGELOG.md') -and (Test-OfficialChangelogPath -FilePath $rootLog) -and ((Get-WritePathClass -FilePath $rootLog -IncludeClaude $false -RootReadmeIsFacility $false) -eq 'level0')) $rootLog
Assert-Decision 'other root changelog does not unlock' (-not (Test-OfficialChangelogPath -FilePath 'D:/repo/.ai-gates/CHANGELOG.md')) ''
Assert-Decision 'nested changelog does not unlock' (-not (Test-OfficialChangelogPath -FilePath 'subproject/.ai-gates/CHANGELOG.md')) ''
$copyOnto = @(Get-ExplicitWritePaths -CommandText 'Copy-Item -Path forged.json -Destination .ai-gates/hooks-log/knife-state.json')
$copyBlocks = @(Get-ShellWriteBlocks -Paths $copyOnto -HasFreshPm $true -HasFreshChangelog $true)
Assert-Decision 'copy onto knife state blocks' ($copyBlocks.Count -eq 1 -and $copyBlocks[0].Reason -eq 'gate_auth_state') ($copyOnto -join ',')
$moved = @(Get-ExplicitWritePaths -CommandText 'Move-Item .ai-gates/hooks-log/pm-gate.json .ai-gates/tmp/pm-gate.json')
Assert-Decision 'move source is extracted' ($moved -contains '.ai-gates/hooks-log/pm-gate.json') ($moved -join ',')
$removed = @(Get-ExplicitWritePaths -CommandText 'Remove-Item -LiteralPath .ai-gates\hooks-log\changelog-writes.json -Force')
$removeBlocks = @(Get-ShellWriteBlocks -Paths $removed -HasFreshPm $true -HasFreshChangelog $true)
Assert-Decision 'remove auth state blocks' ($removeBlocks.Count -eq 1 -and $removeBlocks[0].Reason -eq 'gate_auth_state') ($removed -join ',')
$appendLog = Get-ExplicitWritePaths -CommandText 'Add-Content -Path .ai-gates/hooks-log/git-safety-check.log -Value x'
$appendBlocks = Get-ShellWriteBlocks -Paths $appendLog -HasFreshPm $false -HasFreshChangelog $false
Assert-Decision 'hook log append still allowed' ($appendBlocks.Count -eq 0) "count=$($appendBlocks.Count)"
Assert-Decision 'auth script name is denied' (Test-AuthScriptInvoke -CommandText 'powershell -File .ai-gates\hooks\mark-pm-gate.ps1') ''
Assert-Decision 'renamed script name is not denied' (-not (Test-AuthScriptInvoke -CommandText 'powershell -File .\copied-gate.ps1')) ''
Assert-Decision 'skills changelog does not unlock' ((-not (Test-OfficialChangelogPath -FilePath '.ai-gates/skills/CHANGELOG.md')) -and (Get-WritePathClass -FilePath 'D:/repo/.ai-gates/skills/CHANGELOG.md' -IncludeClaude $false -RootReadmeIsFacility $false) -eq 'level1') ''
Assert-Decision 'hooks changelog does not unlock' ((-not (Test-OfficialChangelogPath -FilePath '.ai-gates/hooks/CHANGELOG.md')) -and (Get-WritePathClass -FilePath 'D:/repo/.ai-gates/hooks/CHANGELOG.md' -IncludeClaude $false -RootReadmeIsFacility $false) -eq 'level1') ''
Assert-Decision 'scripts changelog does not unlock' ((-not (Test-OfficialChangelogPath -FilePath '.ai-gates/scripts/CHANGELOG.md')) -and (Get-WritePathClass -FilePath 'D:/repo/.ai-gates/scripts/CHANGELOG.md' -IncludeClaude $false -RootReadmeIsFacility $false) -eq 'level1') ''
$readme = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\README.md') -Raw -Encoding UTF8
$installUrl = [regex]::Match($readme, 'raw\.githubusercontent\.com/zhaobolun-code/ai-gates/[^/\s]+/(\S+?install-ai-gates\.ps1)')
$installLocal = Join-Path (Split-Path $PSScriptRoot -Parent) (($installUrl.Groups[1].Value -replace '^\.ai-gates/','') -replace '/','\')
Assert-Decision 'readme install url matches the script' ($installUrl.Success -and (Test-Path -LiteralPath $installLocal)) $installUrl.Value
Assert-Decision 'other hooks-log file is not the stamp' (-not (Test-CrStampPath -FilePath '.ai-gates/hooks-log/pm-gate.json')) ''
$noParent = Get-WriteGateVerdict -HostName cursor -Paths @('Assets/Foo.cs') -GateState Ok -OwnPm Missing
Assert-Decision 'no parent tells this session to emit PM' ((-not $noParent.Allow) -and $noParent.Detail -eq 'no_pm_marker_for_conversation' -and $noParent.Message.Contains('先在本会话回复中发出')) $noParent.Detail
$parentDeny = Get-WriteGateVerdict -HostName cursor -Paths @('Assets/Foo.cs') -GateState Ok -OwnPm Missing -ParentId 'parent-1'
Assert-Decision 'child deny does not tell the child to emit PM' ((-not $parentDeny.Allow) -and $parentDeny.Detail -eq 'parent_pm_not_marked' -and $parentDeny.Message.Contains('子窗不要发') -and -not $parentDeny.Message.Contains('先在本会话回复中发出')) $parentDeny.Detail
$cursorReadme = Get-WriteGateVerdict -HostName cursor -Paths @('.cursor/README.md') -ChangelogState Missing
Assert-Decision 'cursor readme stays level2' ($cursorReadme.Allow) $cursorReadme.Detail
$cursorAiReadme = Get-WriteGateVerdict -HostName cursor -Paths @('.ai-gates/README.md') -ChangelogState Missing
Assert-Decision 'cursor ai-gates readme stays level2' ($cursorAiReadme.Allow) $cursorAiReadme.Detail
$claudeCursorReadme = Get-WriteGateVerdict -HostName claude -Paths @('.cursor/README.md') -ChangelogState Missing -IncludeClaude $true -RootDocsAreLevel1 $true
Assert-Decision 'claude cursor readme stays level2' ($claudeCursorReadme.Allow) $claudeCursorReadme.Detail
$claudeAiReadme = Get-WriteGateVerdict -HostName claude -Paths @('.ai-gates/USER-GUIDE.md') -ChangelogState Missing -IncludeClaude $true -RootDocsAreLevel1 $true
Assert-Decision 'claude ai-gates root doc stays level1' ((-not $claudeAiReadme.Allow) -and $claudeAiReadme.Detail -eq 'changelog_writes_missing_level1') $claudeAiReadme.Detail
$codexCursorReadme = Get-WriteGateVerdict -HostName codex -Paths @('.cursor/METHODOLOGY.md') -ChangelogState Missing -RootDocsAreLevel1 $true
Assert-Decision 'codex cursor root doc stays level2' ($codexCursorReadme.Allow) $codexCursorReadme.Detail
$codexAiReadme = Get-WriteGateVerdict -HostName codex -Paths @('.ai-gates/SKILLS.md') -ChangelogState Missing -RootDocsAreLevel1 $true
Assert-Decision 'codex ai-gates root doc stays level1' ((-not $codexAiReadme.Allow) -and $codexAiReadme.Detail -eq 'changelog_writes_missing_level1') $codexAiReadme.Detail

$freezePath = Join-Path $PSScriptRoot "fixtures\pm-gate-deny-freeze.json"
$freeze = Get-Content -LiteralPath $freezePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gateFiles = @{
    cursor = Join-Path $PSScriptRoot "..\hooks\pm-gate-check.ps1"
    claude = Join-Path $PSScriptRoot "..\hooks\claude\pm-gate-check.ps1"
    codex  = Join-Path $PSScriptRoot "..\hooks\codex\pm-gate-check.ps1"
}
foreach ($hostName in @("cursor", "claude", "codex")) {
    $text = Get-Content -LiteralPath $gateFiles[$hostName] -Raw -Encoding UTF8
    $sourceText = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\hooks\gate-decision.ps1") -Raw -Encoding UTF8
    $combined = $text + "`n" + $sourceText
    foreach ($code in @($freeze.$hostName)) {
        Assert-Decision ("freeze " + $hostName + " " + $code) ($combined.Contains($code)) "missing"
    }
}

if ($failed -gt 0) { exit 1 }
Write-Host "gate-decision: all passed"
exit 0
