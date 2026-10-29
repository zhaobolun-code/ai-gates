# 合成判定，不跑 dotnet test。覆盖全部跳过、零匹配、有失败、通过达标。
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'run-dotnet-editmode-tests.ps1')

$failed = 0
function Assert-Verdict {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

Assert-Verdict 'real pass is green' ((Test-EditModeGreen -Outcome 'Completed' -Total 80 -Passed 80 -Failed 0) -eq 0) ''
Assert-Verdict 'passed outcome is green' ((Test-EditModeGreen -Outcome 'Passed' -Total 70 -Passed 70 -Failed 0) -eq 0) ''
Assert-Verdict 'all skipped is not green' ((Test-EditModeGreen -Outcome 'Completed' -Total 80 -Passed 0 -Failed 0 -Skipped 80) -eq 2) ''
Assert-Verdict 'not executed is not green' ((Test-EditModeGreen -Outcome 'Completed' -Total 80 -Passed 0 -Failed 0 -NotExecuted 80) -eq 2) ''
Assert-Verdict 'zero matches is not green' ((Test-EditModeGreen -Outcome 'Completed' -Total 0 -Passed 0 -Failed 0) -eq 2) ''
Assert-Verdict 'failures are not green' ((Test-EditModeGreen -Outcome 'Failed' -Total 80 -Passed 70 -Failed 1) -eq 2) ''
Assert-Verdict 'bad outcome is not green' ((Test-EditModeGreen -Outcome 'Error' -Total 80 -Passed 80 -Failed 0) -eq 1) ''
Assert-Verdict 'passed below floor is not green' ((Test-EditModeGreen -Outcome 'Completed' -Total 80 -Passed 69 -Failed 0 -Skipped 11) -eq 2) ''

if ($failed -gt 0) { exit 1 }
Write-Host 'editmode-verdict: all passed'
exit 0
