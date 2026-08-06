# test-hooks.ps1 — 支柱 C（最小实现）：给 .cursor/hooks/ 下的机械化脚本
# （audit-write / git-safety-check / verify-runtime-evidence / update-doc-state /
#  mark-pm-gate / pm-gate-check / check-unity-compile）建一套可重复运行的行为回归测试。
#
# 定位：validate-pipeline.ps1 已经覆盖"Skill 文档层"的结构/版本一致性回归；
# 这个脚本补的是"机械化 Harness 层"（支柱 A/B/D 落地的 7 个 hook 脚本）——
# 用构造好的 stdin JSON / 临时目录喂给脚本，断言 exit code + 输出 JSON + 副作用文件，
# 而不是"看一眼脚本还在不在"。任何一个脚本被改坏（比如字段名改了、判定逻辑反了），
# 这里应该能测出来，而不是等到某次真实会话被误 deny/误放行才发现。
#
# 安全性：所有测试用例都用带 __test__ 前缀的隔离标识（conversation_id / 临时目录），
# 跑完在 finally 里精确撤销对 .ai-gates/hooks-log/ 真实文件的改动（备份/还原，而不是整份删除），
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
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
$gateFile = Join-Path $logDir "pm-gate.json"
$changelogWritesFile = Join-Path $logDir "changelog-writes.json"

$script:total = 0
$script:failed = 0
$script:results = @()

function Invoke-HookScript {
    param([string]$ScriptName, [string]$StdinJson, [hashtable]$ExtraArgs)
    $path = if ([System.IO.Path]::IsPathRooted($ScriptName)) { $ScriptName } else { Join-Path $hooksDir $ScriptName }
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
# 备份将被测试触碰的真实文件（pm-gate.json / changelog-writes.json），跑完精确还原
# ---------------------------------------------------------------------------
$gateBackup = $null
if (Test-Path -LiteralPath $gateFile) {
    $gateBackup = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
}
$changelogWritesBackup = $null
if (Test-Path -LiteralPath $changelogWritesFile) {
    $changelogWritesBackup = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8)
}

try {
    Write-Host "=== test-hooks (支柱 C) ===" -ForegroundColor Cyan
    Write-Host "repo: $repoRoot`n"

    # --- audit-write.ps1：永远 allow + exit 0 ---
    $r = Invoke-HookScript -ScriptName "audit-write.ps1" -StdinJson '{"tool_name":"Write","tool_input":{"file_path":"foo.md"},"session_id":"s1"}'
    Assert-Test "audit-write: allow on normal Write" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "audit-write.ps1" -StdinJson 'not-json-garbage'
    Assert-Test "audit-write: allow even on malformed stdin (fail-open)" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # --- git-safety-check.ps1：danger -> deny，safe -> allow（Cursor 2.2+ ask 无效改 deny） ---
    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git push origin main --force"}'
    Assert-Test "git-safety-check: force push -> deny" ((Get-Permission $r.Stdout) -eq "deny") "stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git status"}'
    Assert-Test "git-safety-check: git status -> allow" ((Get-Permission $r.Stdout) -eq "allow") "stdout=$($r.Stdout)"

    $r = Invoke-HookScript -ScriptName "git-safety-check.ps1" -StdinJson '{"command":"git reset --hard HEAD~1"}'
    Assert-Test "git-safety-check: reset --hard -> deny" ((Get-Permission $r.Stdout) -eq "deny") "stdout=$($r.Stdout)"

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
    # 避免残留 kill switch 污染 A5「缺标记 → deny」断言
    $killSwitchPre = Join-Path $logDir "pm-gate-disabled"
    if (Test-Path -LiteralPath $killSwitchPre) {
        Remove-Item -LiteralPath $killSwitchPre -Force -ErrorAction SilentlyContinue
    }

    # A5：缺标记业务 Write → deny（Cursor 2.2+ ask 无效改硬拦；逃生提示在 user_message）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Foo.cs" }; conversation_id = $convNone } | ConvertTo-Json -Compress)
    Assert-Test "A5 pm-gate-check: no marker business Write -> deny (exit 0)" ($r.ExitCode -eq 0 -and ((Get-Permission $r.Stdout) -eq "deny")) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

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

    # --- A1.x：.cursor/** 分级轻门禁（2026-08-03 自我治理；替代原"全豁免"） ---
    $convL1None = "__test__conv-l1-none-$([Guid]::NewGuid().ToString('N'))"
    $convL1Fresh = "__test__conv-l1-fresh-$([Guid]::NewGuid().ToString('N'))"

    # A1.2 先落盘：mark-changelog-write（CHANGELOG.md）→ changelog-writes.json 建立该会话记录。
    # 顺序依赖：A1.2 必须先于「A1.2 续」执行（同会话写 skills 设施需已有新鲜流水）；
    # A1.1 的「无流水 → deny」不依赖文件存在——文件缺失同样 deny（初始状态无流水，
    # 2026-08-03 真演修复，见 A1.5）。
    $r = Invoke-HookScript -ScriptName "mark-changelog-write.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".ai-gates\CHANGELOG.md" }; conversation_id = $convL1Fresh } | ConvertTo-Json -Compress)
    Assert-Test "A1.2 mark-changelog-write: CHANGELOG write -> exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode)"
    $cwNow = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Assert-Test "A1.2 mark-changelog-write: changelog-writes.json contains conversation entry" ($null -ne $cwNow.$convL1Fresh.lastChangelogWriteAtUtc) "keys=$($cwNow.PSObject.Properties.Name -join ',')"

    # A1.1：Level 1（skills）无 CHANGELOG 流水 → deny、exit 0、消息含 CHANGELOG（逃生提示）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\skills\foo.md" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.1 pm-gate-check: Level1 skills no changelog flow -> deny, msg has CHANGELOG" ($r.ExitCode -eq 0 -and ((Get-Permission $r.Stdout) -eq "deny") -and $r.Stdout -match "CHANGELOG") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A1.2 续：同会话（convL1Fresh）写 skills 设施 → allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\skills\foo.md" }; conversation_id = $convL1Fresh } | ConvertTo-Json -Compress)
    Assert-Test "A1.2 pm-gate-check: Level1 skills with fresh changelog flow -> allow" ((Get-Permission $r.Stdout) -eq "allow" -and $r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A1.3：Level 0 豁免——CHANGELOG.md 自身 / hooks-log 运行时 / 项目专属文件，均 allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".ai-gates\CHANGELOG.md" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.3 pm-gate-check: CHANGELOG.md itself Level0 exempt -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".ai-gates\hooks-log\pm-gate.json" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.3 pm-gate-check: hooks-log runtime Level0 exempt -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\project-context.md" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.3 pm-gate-check: project-context.md Level0 exempt -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A1.4：业务路径回归（原 A5 语义保留）——无标记 deny / 有新鲜标记 allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets\Foo.cs" }; conversation_id = $convNone } | ConvertTo-Json -Compress)
    Assert-Test "A1.4 pm-gate-check: business path no marker -> deny (Cursor 2.2+ ask bug)" ((Get-Permission $r.Stdout) -eq "deny") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets\Foo.cs" }; conversation_id = $convFresh } | ConvertTo-Json -Compress)
    Assert-Test "A1.4 pm-gate-check: business path fresh marker -> allow (original behavior)" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # A1.5：changelog-writes.json 缺失 = 初始状态（无任何会话有 CHANGELOG 流水）→
    # Level 1 写 skills 设施应 deny（硬拦 + 逃生提示）。2026-08-03 两连修：先 fail-open
    # allow → ask（真演第一步「没弹 ask」根因）；再因 Cursor 2.2+ ask 无效（官方确认）→ deny。
    # 备份/删除与断言整体用 try/finally 包裹：断言中途抛异常也保证备份回写，
    # 避免污染真实会话的 changelog-writes.json（测试隔离原则）。
    $cwTmpBackup = $null
    try {
        if (Test-Path -LiteralPath $changelogWritesFile) {
            $cwTmpBackup = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8)
            Remove-Item -LiteralPath $changelogWritesFile -Force
        }
        $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\scripts\x.ps1" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
        Assert-Test "A1.5 pm-gate-check: changelog-writes.json missing + Level1 -> deny, msg has CHANGELOG" ($r.ExitCode -eq 0 -and ((Get-Permission $r.Stdout) -eq "deny") -and $r.Stdout -match "CHANGELOG") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    } finally {
        # 无论断言成败都还原备份；备份为空说明原文件本就不存在，无需回写
        if ($cwTmpBackup) {
            [System.IO.File]::WriteAllText($changelogWritesFile, $cwTmpBackup, $utf8Bom)
        }
    }

    # A1.7：Level 2 兜底——其余 .cursor/**（package-release.ps1 / README.md / _release_staging 产物）无流水 → allow（非 ask）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".ai-gates\package-release.ps1" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.7 pm-gate-check: Level2 fallback package-release.ps1 no flow -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".cursor\README.md" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.7 pm-gate-check: Level2 fallback README.md no flow -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = ".ai-gates\_release_staging\ai_dev_x.7z" }; conversation_id = $convL1None } | ConvertTo-Json -Compress)
    Assert-Test "A1.7 pm-gate-check: Level2 fallback _release_staging artifact -> allow" ((Get-Permission $r.Stdout) -eq "allow") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

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
    Assert-Test "A6 hooks.json: all hooks failClosed=false (incl. pm-gate-check + sessionStart)" (($allHookEntries.Count -ge 5) -and $hasCheck -and ($anyTrue.Count -eq 0)) "entries=$($allHookEntries | ConvertTo-Json -Compress)"

    # A1.6 集成：postToolUse 含 mark-changelog-write 且 failClosed:false；MAINTAINER hooks 表 7 行
    $markEntry = @($allHookEntries | Where-Object { $_.Command -match 'mark-changelog-write\.ps1' -and $_.Event -eq 'postToolUse' -and -not $_.FailClosed })
    Assert-Test "A1.6 hooks.json: postToolUse mark-changelog-write failClosed=false" ($markEntry.Count -ge 1) "entries=$($allHookEntries | ConvertTo-Json -Compress)"
    $maintainerRaw = [System.IO.File]::ReadAllText((Join-Path $repoRoot ".cursor\skills\MAINTAINER.md"), [System.Text.Encoding]::UTF8)
    # 只统计 §Cursor Hooks 小节内表格行——其他小节的表（流程稳定性规则等）也含 .ps1 文件名
    $maintainerLines = $maintainerRaw -split "`n"
    $hooksSecStart = -1; $hooksSecEnd = $maintainerLines.Count
    for ($i = 0; $i -lt $maintainerLines.Count; $i++) {
        if ($hooksSecStart -lt 0 -and $maintainerLines[$i] -match '^## Cursor Hooks') { $hooksSecStart = $i }
        elseif ($hooksSecStart -ge 0 -and $maintainerLines[$i] -match '^## ') { $hooksSecEnd = $i; break }
    }
    $hookTableRows = @($maintainerLines[$hooksSecStart..($hooksSecEnd - 1)] | Where-Object { $_ -match '^\|' -and $_ -match '\.ps1' })
    Assert-Test "A1.6 MAINTAINER: hooks table has 7 rows incl. mark-changelog-write" ($hooksSecStart -ge 0 -and $hookTableRows.Count -eq 7 -and $maintainerRaw -match 'mark-changelog-write') "rows=$($hookTableRows.Count)"

    # A7：sessionStart 漂移检测 — 当前仓应无漂移；stdout 为 {} 或无可解析 additional_context
    $driftFile = Join-Path $logDir "hooks-policy-drift.json"
    $driftBackup = $null
    if (Test-Path -LiteralPath $driftFile) {
        $driftBackup = Get-Content -LiteralPath $driftFile -Raw -Encoding UTF8
        Remove-Item -LiteralPath $driftFile -Force -ErrorAction SilentlyContinue
    }
    try {
        $r = Invoke-HookScript -ScriptName "check-hooks-drift.ps1" -StdinJson '{}'
        Assert-Test "A7 check-hooks-drift: exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode) stderr=$($r.Stderr)"
        $driftJson = $null
        try { $driftJson = $r.Stdout | ConvertFrom-Json } catch { $driftJson = $null }
        Assert-Test "A7 check-hooks-drift: stdout valid JSON" ($null -ne $driftJson) "stdout=$($r.Stdout)"
        $hasCtx = $false
        if ($driftJson -and $driftJson.PSObject.Properties.Name -contains 'additional_context') {
            $hasCtx = -not [string]::IsNullOrWhiteSpace([string]$driftJson.additional_context)
        }
        Assert-Test "A7 check-hooks-drift: no drift on healthy repo (no additional_context)" (-not $hasCtx) "stdout=$($r.Stdout)"
        Assert-Test "A7 check-hooks-drift: no drift file after OK" (-not (Test-Path -LiteralPath $driftFile)) "driftFile still present"

        $policyScript = Join-Path $scriptDir "check-hooks-policy.ps1"
        . $policyScript
        $pr = Get-HooksPolicyReport -RepoRoot $repoRoot
        Assert-Test "A7 check-hooks-policy: Get-HooksPolicyReport Ok=true" ($pr.Ok -eq $true) ("issues=" + (($pr.Issues) -join '; '))
    } finally {
        if ($null -ne $driftBackup) {
            [System.IO.File]::WriteAllText($driftFile, $driftBackup, $utf8Bom)
        } elseif (Test-Path -LiteralPath $driftFile) {
            # leave clean if test created one unexpectedly — already asserted absent on OK
        }
    }

    # --- A2：BOM 机械化检查（2026-08-03 Step 2）——Get-HooksPolicyReport -HooksDir/-ScriptsDir 注入 ---
    $tmpBomDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-bom-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tmpBomDir -Force | Out-Null
    try {
        # A2.1：fixture 含无 BOM fake.ps1 → Ok=false 且 Issues 含 "UTF-8 BOM"
        $noBomPath = Join-Path $tmpBomDir "fake-nobom.ps1"
        [System.IO.File]::WriteAllText($noBomPath, "# fake no bom`n", $utf8NoBom)
        $withBomPath = Join-Path $tmpBomDir "fake-withbom.ps1"
        [System.IO.File]::WriteAllText($withBomPath, "# fake with bom`n", $utf8Bom)
        $r2 = Get-HooksPolicyReport -RepoRoot $repoRoot -HooksDir $tmpBomDir -ScriptsDir $tmpBomDir
        $bomIssues2 = @($r2.Issues | Where-Object { $_ -match 'UTF-8 BOM' })
        Assert-Test "A2.1 Get-HooksPolicyReport: no-BOM fixture -> Ok=false + UTF-8 BOM issue" ($r2.Ok -eq $false -and $bomIssues2.Count -ge 1) "ok=$($r2.Ok) issues=$($r2.Issues -join '; ')"

        # A2.2：fixture 全 BOM → 无 "UTF-8 BOM" issue（不要求 Ok=true——tmp 目录本就缺 hooks.json 等）
        Remove-Item -LiteralPath $noBomPath -Force
        $r3 = Get-HooksPolicyReport -RepoRoot $repoRoot -HooksDir $tmpBomDir -ScriptsDir $tmpBomDir
        $bomIssues3 = @($r3.Issues | Where-Object { $_ -match 'UTF-8 BOM' })
        Assert-Test "A2.2 Get-HooksPolicyReport: all-BOM fixture -> no UTF-8 BOM issue" ($bomIssues3.Count -eq 0) "issues=$($r3.Issues -join '; ')"

        # A2.3：真实仓库无 BOM 违规（8 个存量无 BOM ps1 已重存；hooks/ 与 scripts/ 全 BOM）
        $r4 = Get-HooksPolicyReport -RepoRoot $repoRoot
        $bomIssues4 = @($r4.Issues | Where-Object { $_ -match 'UTF-8 BOM' })
        Assert-Test "A2.3 Get-HooksPolicyReport: real repo no BOM issues" ($bomIssues4.Count -eq 0) "issues=$($r4.Issues -join '; ')"
    } finally {
        Remove-Item -LiteralPath $tmpBomDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- A3：package-release validate 绿门（2026-08-03 Step 3）---
    # 用 -Version v9.9.9 隔离产物，避免覆盖 .cursor/ 下既有 ai_dev_v3.x.7z；
    # stub validate 经 -ValidateScriptPath 注入（exit 1 / exit 0 两种）。
    $relScript = Join-Path $repoRoot ".ai-gates\package-release.ps1"
    $relTestVersion = "v9.9.9"
    $relTestOut = Join-Path $repoRoot ".ai-gates\releases\ai_dev_$relTestVersion.7z"
    $relBefore = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot ".cursor") -Filter "ai_dev_*.7z" -File |
        ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" })
    $stubFail = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-validate-fail-$([Guid]::NewGuid().ToString('N')).ps1"
    $stubOk = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-validate-ok-$([Guid]::NewGuid().ToString('N')).ps1"
    Set-Content -LiteralPath $stubFail -Value "exit 1" -Encoding UTF8
    Set-Content -LiteralPath $stubOk -Value "exit 0" -Encoding UTF8
    try {
        # A3.1：stub validate exit 1 + 无 -SkipValidate → exit 非 0、输出含拒绝句、不产出新 7z
        $r = Invoke-HookScript -ScriptName $relScript -StdinJson $null -ExtraArgs @{ Version = $relTestVersion; ValidateScriptPath = $stubFail }
        $combined = $r.Stdout + "`n" + $r.Stderr
        $relAfter1 = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot ".cursor") -Filter "ai_dev_*.7z" -File |
            ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" })
        Assert-Test "A3.1 package-release: stub validate exit1 -> exit!=0 + reject msg + no new 7z" ($r.ExitCode -ne 0 -and $combined -match '已拒绝打包' -and $combined -match 'SkipValidate' -and (Compare-Object $relBefore $relAfter1).Count -eq 0) "exit=$($r.ExitCode) out=$($combined)"

        # A3.2：stub validate exit 0 → 越过 validate 门（绿门通过消息；不因 validate 阶段失败）
        $r = Invoke-HookScript -ScriptName $relScript -StdinJson $null -ExtraArgs @{ Version = $relTestVersion; ValidateScriptPath = $stubOk }
        $combined2 = $r.Stdout + "`n" + $r.Stderr
        Assert-Test "A3.2 package-release: stub validate exit0 -> passes validate gate" ($combined2 -match 'validate-pipeline -Strict: OK' -and $combined2 -notmatch '已拒绝打包') "exit=$($r.ExitCode) out=$($combined2)"

        # A3.3：-SkipValidate + stub validate exit 1 → 跳过 validate 门（进入后续流程，不因 validate 拦截）
        $r = Invoke-HookScript -ScriptName $relScript -StdinJson $null -ExtraArgs @{ Version = $relTestVersion; ValidateScriptPath = $stubFail; SkipValidate = $true }
        $combined3 = $r.Stdout + "`n" + $r.Stderr
        Assert-Test "A3.3 package-release: -SkipValidate + stub exit1 -> skips validate gate" ($combined3 -match 'WARNING: -SkipValidate' -and $combined3 -notmatch '已拒绝打包') "exit=$($r.ExitCode) out=$($combined3)"
    } finally {
        Remove-Item -LiteralPath $stubFail, $stubOk -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $relTestOut -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $repoRoot ".ai-gates\_release_staging") -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- A8：check-unity-compile.ps1 写后质量门（postToolUse） ---
    # 经 -EditorLogPath 注入临时 fixture；命中 → additional_context + 审计落盘；
    # 日志缺失 / 解析异常 / 非代码路径 → 恒 allow exit 0。
    $compileLog = Join-Path $logDir "unity-compile-check.log"
    $compileLogBackup = $null
    if (Test-Path -LiteralPath $compileLog) {
        $compileLogBackup = Get-Content -LiteralPath $compileLog -Raw -Encoding UTF8
        Remove-Item -LiteralPath $compileLog -Force -ErrorAction SilentlyContinue
    }
    $tmpUnityLog = Join-Path ([System.IO.Path]::GetTempPath()) "test-hooks-unitycompile-$([Guid]::NewGuid().ToString('N')).log"
    try {
        # 命中：含 error CS1002 的临时日志 + .cs 路径 → additional_context、无 deny、审计落盘
        @("some noise line", "Assets/Foo.cs(12,3): error CS1002: ; expected", "more noise") -join "`n" |
            Set-Content -LiteralPath $tmpUnityLog -Encoding UTF8
        $r = Invoke-HookScript -ScriptName "check-unity-compile.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Foo.cs" } } | ConvertTo-Json -Compress) -ExtraArgs @{ EditorLogPath = $tmpUnityLog }
        $hitJson = $null
        try { $hitJson = $r.Stdout | ConvertFrom-Json } catch { }
        $hasCtx = $false
        if ($hitJson -and $hitJson.PSObject.Properties.Name -contains 'additional_context') {
            $hasCtx = -not [string]::IsNullOrWhiteSpace([string]$hitJson.additional_context)
        }
        Assert-Test "A8 check-unity-compile: CS error hit -> additional_context, no deny" ($r.ExitCode -eq 0 -and $hasCtx -and $r.Stdout -notmatch 'deny') "exit=$($r.ExitCode) stdout=$($r.Stdout)"
        $compileLogTail = ""
        if (Test-Path -LiteralPath $compileLog) {
            $compileLogTail = (Get-Content -LiteralPath $compileLog -Encoding UTF8 | Select-Object -Last 5) -join "`n"
        }
        Assert-Test "A8 check-unity-compile: audit line written on hit" ($compileLogTail -match "HIT" -and $compileLogTail -match [Regex]::Escape("Assets/Foo.cs")) "tail=$compileLogTail"

        # 无错：日志无 CS 错误 → 静默 allow（无 additional_context）
        "no compile error here" | Set-Content -LiteralPath $tmpUnityLog -Encoding UTF8
        $r = Invoke-HookScript -ScriptName "check-unity-compile.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Bar.cs" } } | ConvertTo-Json -Compress) -ExtraArgs @{ EditorLogPath = $tmpUnityLog }
        $noErrJson = $null
        try { $noErrJson = $r.Stdout | ConvertFrom-Json } catch { }
        $noErrCtx = ""
        if ($noErrJson -and $noErrJson.PSObject.Properties.Name -contains 'additional_context') { $noErrCtx = [string]$noErrJson.additional_context }
        Assert-Test "A8 check-unity-compile: no compile error -> silent allow" ($r.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($noErrCtx)) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        # 非代码路径（.md）：即使日志含错误也静默 allow
        @("Assets/Foo.cs(12,3): error CS1002: ; expected") -join "`n" | Set-Content -LiteralPath $tmpUnityLog -Encoding UTF8
        $r = Invoke-HookScript -ScriptName "check-unity-compile.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Doc/notes.md" } } | ConvertTo-Json -Compress) -ExtraArgs @{ EditorLogPath = $tmpUnityLog }
        Assert-Test "A8 check-unity-compile: non-code path -> silent allow" ($r.ExitCode -eq 0 -and $r.Stdout.Trim() -eq "{}") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        # 日志缺失 → 静默 allow exit 0
        $r = Invoke-HookScript -ScriptName "check-unity-compile.ps1" -StdinJson (@{ tool_name = "Write"; tool_input = @{ file_path = "Assets/Baz.cs" } } | ConvertTo-Json -Compress) -ExtraArgs @{ EditorLogPath = (Join-Path ([System.IO.Path]::GetTempPath()) "missing-$([Guid]::NewGuid().ToString('N')).log") }
        Assert-Test "A8 check-unity-compile: missing log -> silent allow exit 0" ($r.ExitCode -eq 0 -and $r.Stdout.Trim() -eq "{}") "exit=$($r.ExitCode) stdout=$($r.Stdout)"

        # 解析异常（坏 stdin）→ fail-open allow exit 0
        $r = Invoke-HookScript -ScriptName "check-unity-compile.ps1" -StdinJson 'garbage-not-json' -ExtraArgs @{ EditorLogPath = $tmpUnityLog }
        Assert-Test "A8 check-unity-compile: malformed stdin -> fail-open allow" ($r.ExitCode -eq 0 -and $r.Stdout.Trim() -eq "{}") "exit=$($r.ExitCode) stdout=$($r.Stdout)"
    } finally {
        Remove-Item -LiteralPath $tmpUnityLog -ErrorAction SilentlyContinue -Force
        if ($null -ne $compileLogBackup) {
            [System.IO.File]::WriteAllText($compileLog, $compileLogBackup, $utf8Bom)
        } elseif (Test-Path -LiteralPath $compileLog) {
            Remove-Item -LiteralPath $compileLog -Force -ErrorAction SilentlyContinue
        }
    }

    # --- A9：协议级 hook 仿真台（发布闸「真演证据」自动化）---
    # 完整模拟一次 Cursor 2.2 会话的 hook 调用序列（大 payload ≥80KB、中文/特殊字符），
    # 断言打点链路不因大 payload 断链、门禁随会话状态流转（无流水 deny → 写 CHANGELOG 后 allow）。
    # 等价一次真实会话 hook 链路真演——覆盖注入式小 JSON 覆盖不到的真实协议形态
    # （2026-08-03 真演 81KB 解析失败 / ask 权限 bug 两连教训，见 MAINTAINER 发布检查清单）。
    $r = Invoke-HookScript -ScriptName "..\scripts\simulate-cursor-session.ps1" -StdinJson $null
    Assert-Test "A9 simulate-cursor-session: protocol-level session sim all pass" ($r.ExitCode -eq 0) "exit=$($r.ExitCode) stdout=$($r.Stdout)"

    # --- A10：流水线体检脚本可运行（数据闭环，只读聚合 hooks-log）---
    # 只读聚合打点数据输出体检报告；exit 0=健康 / 2=有退化信号（不因退化而 fail 测试）。
    $r = Invoke-HookScript -ScriptName "..\scripts\pipeline-health.ps1" -StdinJson $null -ExtraArgs @{ Days = 30 }
    Assert-Test "A10 pipeline-health: report generates (exit 0 or 2)" ($r.ExitCode -eq 0 -or $r.ExitCode -eq 2) "exit=$($r.ExitCode) stderr=$($r.Stderr)"
    Assert-Test "A10 pipeline-health: report contains 流水线体检" ($r.Stdout -match "流水线体检") "stdout=$($r.Stdout)"

}
finally {
    # 精确还原 pm-gate.json：只删掉本次测试写入的 __test__/__sim__ 前缀会话，保留任何真实会话数据
    if (Test-Path -LiteralPath $gateFile) {
        try {
            $final = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $rebuilt = [ordered]@{}
            foreach ($p in $final.PSObject.Properties) {
                if ($p.Name -notlike "__test__*" -and $p.Name -notlike "__sim__*") { $rebuilt[$p.Name] = $p.Value }
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
    # 精确还原 changelog-writes.json：只删掉本次测试写入的 __test__/__sim__ 前缀会话，保留任何真实会话数据
    if (Test-Path -LiteralPath $changelogWritesFile) {
        try {
            $cwFinal = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $cwRebuilt = [ordered]@{}
            foreach ($p in $cwFinal.PSObject.Properties) {
                if ($p.Name -notlike "__test__*" -and $p.Name -notlike "__sim__*") { $cwRebuilt[$p.Name] = $p.Value }
            }
            if ($cwRebuilt.Count -eq 0 -and -not $changelogWritesBackup) {
                Remove-Item -LiteralPath $changelogWritesFile -ErrorAction SilentlyContinue -Force
            } else {
                [System.IO.File]::WriteAllText($changelogWritesFile, ($cwRebuilt | ConvertTo-Json -Depth 6), $utf8Bom)
            }
        } catch {
            if ($changelogWritesBackup) { [System.IO.File]::WriteAllText($changelogWritesFile, $changelogWritesBackup, $utf8Bom) }
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
