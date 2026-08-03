# test-hooks.ps1 — 支柱 C（最小实现）：给 .cursor/hooks/ 下的机械化脚本
# （audit-write / git-safety-check / verify-runtime-evidence / update-doc-state /
#  mark-pm-gate / pm-gate-check）建一套可重复运行的行为回归测试。
#
# 定位：validate-pipeline.ps1 已经覆盖"Skill 文档层"的结构/版本一致性回归；
# 这个脚本补的是"机械化 Harness 层"（支柱 A/B/D 落地的 6 个 hook 脚本）——
# 用构造好的 stdin JSON / 临时目录喂给脚本，断言 exit code + 输出 JSON + 副作用文件，
# 而不是"看一眼脚本还在不在"。任何一个脚本被改坏（比如字段名改了、判定逻辑反了），
# 这里应该能测出来，而不是等到某次真实会话被误 deny/误放行才发现。
#
# 安全性：所有测试用例都用带 __test__ 前缀的隔离标识（conversation_id / 临时目录），
# 跑完在 finally 里精确撤销对 .cursor/hooks-log/ 真实文件的改动（备份/还原，而不是整份删除），
# 不会污染真实会话的 pm-gate.json / 审计日志。
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/test-hooks.ps1
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/test-hooks.ps1 -Verbose

param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path }
$hooksDir = Join-Path $repoRoot ".cursor\hooks"
$logDir = Join-Path $repoRoot ".cursor\hooks-log"
$gateFile = Join-Path $logDir "pm-gate.json"

$script:total = 0
$script:failed = 0
$script:results = @()

function Invoke-HookScript {
    param([string]$ScriptName, [string]$StdinJson, [hashtable]$ExtraArgs)
    $path = Join-Path $hooksDir $ScriptName
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $path)
    if ($ExtraArgs) {
        foreach ($k in $ExtraArgs.Keys) {
            $v = $ExtraArgs[$k]
            if ($v -is [bool]) {
                # [switch] 形参：命令行只能靠"出现/不出现"表达，不能再跟一个字符串值
                # （"-Init" "True" 会把 "True" 误绑定成下一个位置参数）。
                if ($v) { $argList += "-$k" }
            } else {
                $argList += "-$k"
                $argList += [string]$v
            }
        }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join " "
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($StdinJson -ne $null) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($StdinJson)
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    }
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [ordered]@{
        ExitCode = $proc.ExitCode
        Stdout   = $stdout
        Stderr   = $stderr
    }
}

function Assert-Test {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    $script:total++
    if ($Condition) {
        $script:results += "PASS | $Name"
        if ($VerboseOutput) { Write-Host "PASS: $Name" -ForegroundColor Green }
    } else {
        $script:failed++
        $script:results += "FAIL | $Name | $Detail"
        Write-Host "FAIL: $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "      $Detail" -ForegroundColor DarkYellow }
    }
}

function Get-Permission([string]$stdout) {
    try { return ($stdout | ConvertFrom-Json).permission } catch { return $null }
}

# ---------------------------------------------------------------------------
# 备份将被测试触碰的真实文件（pm-gate.json），跑完精确还原
# ---------------------------------------------------------------------------
$gateBackup = $null
if (Test-Path -LiteralPath $gateFile) {
    $gateBackup = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
}

try {
    Write-Host "=== test-hooks (支柱 C) ===" -ForegroundColor Cyan
    Write-Host "repo: $repoRoot`n"

    # --- audit-write.ps1：永远 allow + exit 0 ---
    $r = Invoke-HookScript -ScriptName "audit-write.ps1" -StdinJson '{"tool_name":"Write","tool_input":{"file_path":"foo.md"},"session_id":"s1"}'
    Assert-Test "audit-write: allow on normal Write" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "audit-write.ps1" -StdinJson 'not-json-garbage'
    Assert-Test "audit-write: allow even on malformed stdin (fail-open)" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # --- git-safety-check.ps1：danger -> ask，safe -> allow ---
    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git push origin main --force"}'
    Assert-Test "git-safety-check: force push -> ask" ((Get-Permission $r.Stdout) -eq "ask") "stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git status"}'
    Assert-Test "git-safety-check: git status -> allow" ((Get-Permission $r.Stdout) -eq "allow") "stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git reset --hard HEAD~1"}'
    Assert-Test "git-safety-check: reset --hard -> ask" ((Get-Permission $r.Stdout) -eq "ask") "stdout=$($r.Stdout)"

    # --- verify-runtime-evidence.ps1：构造临时 Editor.log fixture ---
    $tmpLog = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-editor-$([Guid]::NewGuid().ToString('N')).log"
    @(
        "some noise line",
        "hit_keyword_alpha fired at t=1",
        "another noise line"
    ) -join "`n" | Set-Content -LiteralPath $tmpLog -Encoding UTF8

    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "hit_keyword_alpha"; EditorLogPath = $tmpLog; SinceMinutes = 30
    }
    $evJson = $null
    try { $evJson = $r.Stdout | ConvertFrom-Json } catch {}
    Assert-Test "verify-runtime-evidence: hit + fresh + no compile errors -> exit 0" ($r.ExitCode -eq 0 -and $evJson -and $evJson.overallHit -eq $true -and $evJson.fresh -eq $true) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "keyword_not_present"; EditorLogPath = $tmpLog; SinceMinutes = 30
    }
    Assert-Test "verify-runtime-evidence: keyword miss -> exit 1" ($r.ExitCode -eq 1) "exit=$($r.ExitCode)"

    @("error CS1002: ; expected") -join "`n" | Add-Content -LiteralPath $tmpLog -Encoding UTF8
    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "hit_keyword_alpha"; EditorLogPath = $tmpLog; SinceMinutes = 30
    }
    try { $evJson = $r.Stdout | ConvertFrom-Json } catch {}
    Assert-Test "verify-runtime-evidence: compile error present -> exit 1 even if keyword hit" ($r.ExitCode -eq 1 -and $evJson.compileErrors.Count -ge 1) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "hit_keyword_alpha"; EditorLogPath = (Join-Path ([System.IO.Path]::GetTempPath()) "does-not-exist-$([Guid]::NewGuid().ToString('N')).log")
    }
    Assert-Test "verify-runtime-evidence: missing log file -> exit 2" ($r.ExitCode -eq 2) "exit=$($r.ExitCode)"

    # --- ExpectAbsentKeywords 回归检查（支柱 A 加厚）：不该出现的关键词命中即判失败 ---
    @("good_event fired", "bad_event_should_not_happen triggered") -join "`n" | Set-Content -LiteralPath $tmpLog -Encoding UTF8
    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "good_event"; ExpectAbsentKeywords = "bad_event_should_not_happen"; EditorLogPath = $tmpLog
    }
    try { $evJson = $r.Stdout | ConvertFrom-Json } catch {}
    Assert-Test "verify-runtime-evidence: ExpectAbsentKeywords hit -> exit 1, anyAbsentHit=true" ($r.ExitCode -eq 1 -and $evJson.anyAbsentHit -eq $true) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    @("good_event fired") -join "`n" | Set-Content -LiteralPath $tmpLog -Encoding UTF8
    $r = Invoke-HookScript -ScriptName "..\scripts\verify-runtime-evidence.ps1" -StdinJson $null -ExtraArgs @{
        Keywords = "good_event"; ExpectAbsentKeywords = "bad_event_should_not_happen"; EditorLogPath = $tmpLog
    }
    try { $evJson = $r.Stdout | ConvertFrom-Json } catch {}
    Assert-Test "verify-runtime-evidence: ExpectAbsentKeywords miss -> exit 0, anyAbsentHit=false" ($r.ExitCode -eq 0 -and $evJson.anyAbsentHit -eq $false) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    Remove-Item -LiteralPath $tmpLog -ErrorAction SilentlyContinue -Force

    # --- update-doc-state.ps1：临时方案夹, 完整状态机走一遍 ---
    $tmpDoc = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-docfolder-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tmpDoc -Force | Out-Null
    try {
        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Init = $true }
        Assert-Test "update-doc-state: Init -> exit 0, docStatus=draft" ($r.ExitCode -eq 0 -and ($r.Stdout | ConvertFrom-Json).docStatus -eq "draft") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "implementation-ready" }
        Assert-Test "update-doc-state: illegal jump draft->implementation-ready -> exit 3" ($r.ExitCode -eq 3) "exit=$($r.ExitCode) stderr=$($r.Stderr)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "review-pending" }
        Assert-Test "update-doc-state: legal draft->review-pending -> exit 0" ($r.ExitCode -eq 0 -and ($r.Stdout | ConvertFrom-Json).docStatus -eq "review-pending") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "implementation-ready" }
        Assert-Test "update-doc-state: legal review-pending->implementation-ready -> exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "in-progress" }
        Assert-Test "update-doc-state: legal implementation-ready->in-progress -> exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode)"

        for ($i = 1; $i -le 3; $i++) {
            $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; IncrementAutoSteps = $true }
        }
        $stateJson = $r.Stdout | ConvertFrom-Json
        Assert-Test "update-doc-state: auto_steps budget trips max_auto_steps at 3" ($stateJson.autoStepsDone -ge 3 -and $stateJson.reason -eq "max_auto_steps") "stdout=$($r.Stdout)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; ResetAutoSteps = $true }
        Assert-Test "update-doc-state: ResetAutoSteps clears counter" ((($r.Stdout | ConvertFrom-Json).autoStepsDone) -eq 0) "stdout=$($r.Stdout)"

        for ($i = 1; $i -le 2; $i++) {
            $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; IncrementRepairRounds = $true }
        }
        $stateJson = $r.Stdout | ConvertFrom-Json
        Assert-Test "update-doc-state: repair_rounds budget trips fuse at 2" ($stateJson.repairRounds -ge 2 -and $stateJson.stopReason -eq "fuse") "stdout=$($r.Stdout)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "completed" }
        Assert-Test "update-doc-state: illegal in-progress->completed (must go via step-completed/runtime-validated) -> exit 3" ($r.ExitCode -eq 3) "exit=$($r.ExitCode)"

        $r = Invoke-HookScript -ScriptName "..\scripts\update-doc-state.ps1" -StdinJson $null -ExtraArgs @{ DocFolder = $tmpDoc; Transition = "completed"; Force = $true; ForceReason = "test-forced-override" }
        Assert-Test "update-doc-state: Force override bypasses legality -> exit 0" ($r.ExitCode -eq 0 -and ($r.Stdout | ConvertFrom-Json).docStatus -eq "completed") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        $historyPath = Join-Path $tmpDoc ".state-history.jsonl"
        $historyLines = @(Get-Content -LiteralPath $historyPath -ErrorAction SilentlyContinue)
        $forcedLine = $historyLines | Where-Object { $_ -match '"forced":true' }
        Assert-Test "update-doc-state: forced transition recorded in history" ($forcedLine.Count -ge 1) "history lines=$($historyLines.Count)"
    } finally {
        Remove-Item -LiteralPath $tmpDoc -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- mark-pm-gate.ps1 + pm-gate-check.ps1：联动测试（用 __test__ 前缀会话号隔离） ---
    # A4 / A5 / A6
    $convFresh = "__test__conv-fresh-$([Guid]::NewGuid().ToString('N'))"
    $convAlt = "__test__conv-alt-$([Guid]::NewGuid().ToString('N'))"
    $convNone = "__test__conv-none-$([Guid]::NewGuid().ToString('N'))"
    $markLog = Join-Path $logDir "mark-pm-gate.log"
    $hooksJsonPath = Join-Path $repoRoot ".cursor\hooks.json"
    # 避免残留 kill switch 污染 A5「缺标记 → ask」断言
    $killSwitchPre = Join-Path $logDir "pm-gate-disabled"
    if (Test-Path -LiteralPath $killSwitchPre) {
        Remove-Item -LiteralPath $killSwitchPre -Force -ErrorAction SilentlyContinue
    }

    # A5：缺标记业务 Write → ask（不是 deny；与 MAINTAINER observe/ask 一致）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Foo.cs" }; conversation_id = $convNone } | ConvertTo-Json -Compress)
    Assert-Test "A5 pm-gate-check: no marker business Write -> ask (exit 0)" ($r.ExitCode -eq 0 -and ((Get-Permission $r.Stdout) -eq "ask")) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A4：text 字段命中 [PM] → 新鲜 pm-gate.json + mark-pm-gate.log 含 wrote=
    $r = Invoke-HookScript -ScriptName "mark-pm-gate.ps1" -StdinJson (@{ text = "[PM] 测试判定，你下一步：..."; conversation_id = $convFresh } | ConvertTo-Json -Compress)
    Assert-Test "A4 mark-pm-gate: [PM] via text -> exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode)"

    $gateNow = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Test "A4 mark-pm-gate: gate file contains fresh conversation entry (text)" ($null -ne $gateNow.$convFresh.lastPmAtUtc) "gate keys=$($gateNow.PSObject.Properties.Name -join ',')"

    $markLogTail = ""
    if (Test-Path -LiteralPath $markLog) {
        $markLogTail = (Get-Content -LiteralPath $markLog -Encoding UTF8 | Select-Object -Last 20) -join "`n"
    }
    Assert-Test "A4 mark-pm-gate: audit log contains wrote= after text mark" ($markLogTail -match "wrote=" -and $markLogTail -match [Regex]::Escape($convFresh)) "tail=$markLogTail"

    # A4：备选字段 response（无 text）也能落盘
    $r = Invoke-HookScript -ScriptName "mark-pm-gate.ps1" -StdinJson (@{ response = "[PM] 备选字段判定"; conversation_id = $convAlt } | ConvertTo-Json -Compress)
    Assert-Test "A4 mark-pm-gate: [PM] via response (no text) -> exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode)"
    $gateAlt = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Test "A4 mark-pm-gate: gate file contains fresh conversation entry (response)" ($null -ne $gateAlt.$convAlt.lastPmAtUtc) "gate keys=$($gateAlt.PSObject.Properties.Name -join ',')"
    $markLogTail2 = ""
    if (Test-Path -LiteralPath $markLog) {
        $markLogTail2 = (Get-Content -LiteralPath $markLog -Encoding UTF8 | Select-Object -Last 20) -join "`n"
    }
    Assert-Test "A4 mark-pm-gate: audit log wrote= after response mark" ($markLogTail2 -match "wrote=pm-gate.json" -and $markLogTail2 -match [Regex]::Escape($convAlt) -and $markLogTail2 -match "field=response") "tail=$markLogTail2"

    # A5：新鲜标记 → allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Foo.cs" }; conversation_id = $convFresh } | ConvertTo-Json -Compress)
    Assert-Test "A5 pm-gate-check: fresh marker -> allow" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "mark-pm-gate.ps1" -StdinJson (@{ text = "这轮没有 PM 标记，纯闲聊"; conversation_id = $convNone } | ConvertTo-Json -Compress)
    $gateNow2 = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Test "mark-pm-gate: text without [PM] -> does NOT create gate entry" ($null -eq $gateNow2.$convNone) "gate keys=$($gateNow2.PSObject.Properties.Name -join ',')"

    # A5：.cursor/** → allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\hooks.json" }; conversation_id = $convNone } | ConvertTo-Json -Compress)
    Assert-Test "A5 pm-gate-check: .cursor/ path exempt -> allow even without marker" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A5：kill-switch → allow
    $killSwitch = Join-Path $logDir "pm-gate-disabled"
    "" | Set-Content -LiteralPath $killSwitch -Encoding UTF8
    try {
        $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Foo.cs" }; conversation_id = $convNone } | ConvertTo-Json -Compress)
        Assert-Test "A5 pm-gate-check: kill switch present -> allow regardless" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    } finally {
        Remove-Item -LiteralPath $killSwitch -ErrorAction SilentlyContinue -Force
    }

    # 解析异常对业务路径 → allow（fail-open；与 MAINTAINER 一致）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson 'garbage-not-json'
    Assert-Test "A5 pm-gate-check: malformed stdin -> allow (fail-open)" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A6：全部 hook failClosed:false（含 pm-gate-check）
    $hooksCfg = Get-Content -LiteralPath $hooksJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $allHookEntries = @()
    foreach ($ev in $hooksCfg.hooks.PSObject.Properties) {
        foreach ($entry in @($ev.Value)) {
            $allHookEntries += [pscustomobject]@{ Event = $ev.Name; Command = [string]$entry.command; FailClosed = [bool]$entry.failClosed }
        }
    }
    $anyTrue = @($allHookEntries | Where-Object { $_.FailClosed })
    $hasCheck = (@($allHookEntries | Where-Object { $_.Command -match 'pm-gate-check\.ps1' }).Count -ge 1)
    Assert-Test "A6 hooks.json: all hooks failClosed=false (incl. pm-gate-check)" (($allHookEntries.Count -ge 4) -and $hasCheck -and ($anyTrue.Count -eq 0)) "entries=$($allHookEntries | ConvertTo-Json -Compress)"

}
finally {
    # 精确还原 pm-gate.json：只删掉本次测试写入的 __test__ 前缀会话，保留任何真实会话数据
    if (Test-Path -LiteralPath $gateFile) {
        try {
            $final = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $rebuilt = [ordered]@{}
            foreach ($p in $final.PSObject.Properties) {
                if ($p.Name -notlike "__test__*") { $rebuilt[$p.Name] = $p.Value }
            }
            if ($rebuilt.Count -eq 0 -and -not $gateBackup) {
                Remove-Item -LiteralPath $gateFile -ErrorAction SilentlyContinue -Force
            } else {
                [System.IO.File]::WriteAllText($gateFile, ($rebuilt | ConvertTo-Json -Depth 6), $utf8Bom)
            }
        } catch {
            if ($gateBackup) { [System.IO.File]::WriteAllText($gateFile, $gateBackup, $utf8Bom) }
        }
    }
}

Write-Host "`n=== summary ===" -ForegroundColor Cyan
Write-Host "total=$script:total failed=$script:failed"
if ($script:failed -gt 0) {
    Write-Host "test-hooks: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "test-hooks: OK" -ForegroundColor Green
    exit 0
}
