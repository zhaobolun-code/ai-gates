# test-codex-hooks.ps1
# Codex 版 hooks 注入式回归测试（对齐 test-hooks.ps1 的构造 stdin 思路，验证脚本内部逻辑；
# 验证不了 Codex 真实事件的触发与注入效果——那部分用真实 codex exec 端到端验证，见
# .cursor/skills/MAINTAINER.md §Codex Hooks）。
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/test-codex-hooks.ps1
#
# 约定：所有脚本输出 stdout 必须是单一 JSON 行（allow=无 permissionDecision；deny=带 reason）；
# 本测试据此断言。
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$hooksCodexDir = Join-Path $PSScriptRoot '..\hooks\codex'
$tmpRoot = Join-Path $env:TEMP ("codex-hooks-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

$passed = 0
$failed = 0
$failures = New-Object System.Collections.Generic.List[string]

function Write-Case {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        $script:passed++
        Write-Host ("PASS {0}" -f $Name) -ForegroundColor Green
    } else {
        $script:failed++
        $script:failures.Add(("{0}: {1}" -f $Name, $Detail)) | Out-Null
        Write-Host ("FAIL {0} -- {1}" -f $Name, $Detail) -ForegroundColor Red
    }
}

function Invoke-Hook {
    param(
        [string]$Script,
        [string]$Payload,
        [string]$LogDir,
        [string]$EditorLogPath = ""
    )
    $ps = Join-Path $hooksCodexDir $Script
    if ($EditorLogPath) {
        $out = $Payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $ps -LogDir $LogDir -EditorLogPath $EditorLogPath 2>$null
    } else {
        $out = $Payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $ps -LogDir $LogDir 2>$null
    }
    return [string]::Join("`n", @($out))
}

function Get-SessionPayload {
    param([string]$SessionId, [string]$ToolName = "apply_patch", [string]$Command = "")
    if ($Command) {
        return (@{
            session_id      = $SessionId
            hook_event_name = 'PreToolUse'
            tool_name       = $ToolName
            tool_input      = @{ command = $Command }
            cwd             = 'D:\Work\Chemical'
        } | ConvertTo-Json -Compress -Depth 6)
    }
    return (@{
        session_id      = $SessionId
        hook_event_name = 'PreToolUse'
        tool_name       = $ToolName
        tool_input      = @{ command = '*** Begin Patch' }
        cwd             = 'D:\Work\Chemical'
    } | ConvertTo-Json -Compress -Depth 6)
}

$sid = 'test-session-0001'
$patchBusiness = "*** Begin Patch`n*** Add File: Assets/Doc/Probe.cs`n+public class Probe {}`n*** End Patch`n"
$patchChangelog = "*** Begin Patch`n*** Update File: .ai-gates/CHANGELOG.md`n@@`n+- test`n*** End Patch`n"
$patchCursorSkill = "*** Begin Patch`n*** Add File: .cursor/skills/foo/SKILL.md`n+# x`n*** End Patch`n"
$patchLog = "*** Begin Patch`n*** Add File: .ai-gates/hooks-log/foo.log`n+x`n*** End Patch`n"
$patchReadme = "*** Begin Patch`n*** Update File: .cursor/README.md`n@@`n+x`n*** End Patch`n"
$patchAiSkills = "*** Begin Patch`n*** Add File: .ai-gates/skills/foo/SKILL.md`n+# x`n*** End Patch`n"
$patchAiReadme = "*** Begin Patch`n*** Update File: .ai-gates/README.md`n@@`n+x`n*** End Patch`n"
$patchCodexWiring = "*** Begin Patch`n*** Update File: .codex/hooks.json`n@@`n+x`n*** End Patch`n"

# ---------- A: git-safety-check ----------
$ld = Join-Path $tmpRoot 'A'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'Bash' -Command 'git push --force origin main'
$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload $p -LogDir $ld
$json = $out | ConvertFrom-Json
Write-Case 'A1 git push --force -> deny' ($json.hookSpecificOutput.permissionDecision -eq 'deny' -and -not [string]::IsNullOrWhiteSpace($json.hookSpecificOutput.permissionDecisionReason)) $out

$p = Get-SessionPayload -SessionId $sid -ToolName 'Bash' -Command 'git status'
$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload $p -LogDir $ld
Write-Case 'A2 git status -> allow(no permissionDecision)' ($out -notmatch 'permissionDecision') $out

$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload 'not-json{{{' -LogDir $ld
Write-Case 'A3 parse fail -> allow' ($out -notmatch 'permissionDecision') $out

# ---------- B: audit-write ----------
$ld = Join-Path $tmpRoot 'B'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchBusiness
$out = Invoke-Hook -Script 'audit-write.ps1' -Payload $p -LogDir $ld
$audit = Get-Content -LiteralPath (Join-Path $ld 'write-audit.log') -Raw -Encoding UTF8
Write-Case 'B1 audit logs patch path + allow' ($out -notmatch 'permissionDecision' -and $audit -match 'Assets/Doc/Probe.cs' -and $audit -match $sid) $out

# ---------- C: pm-gate-check ----------
$ld = Join-Path $tmpRoot 'C'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchBusiness
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C1 business no marker -> deny' ($out -match '"permissionDecision":"deny"' -and $out -match 'permissionDecisionReason') $out

$now = [DateTime]::UtcNow.ToString('o')
[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $now; snippet = 'PM 判定' } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C2 business fresh marker -> allow' ($out -notmatch 'permissionDecision') $out

$stale = [DateTime]::UtcNow.AddHours(-3).ToString('o')
[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $stale } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C3 business stale marker -> deny' ($out -match '"permissionDecision":"deny"') $out

New-Item -ItemType File -Path (Join-Path $ld 'pm-gate-disabled') -Force | Out-Null
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C4 kill switch -> allow' ($out -notmatch 'permissionDecision') $out
Remove-Item -LiteralPath (Join-Path $ld 'pm-gate-disabled') -Force

$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchCursorSkill
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C5 level1 no changelog -> deny' ($out -match '"permissionDecision":"deny"') $out

[System.IO.File]::WriteAllText((Join-Path $ld 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C6 level1 fresh changelog -> allow' ($out -notmatch 'permissionDecision') $out

$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchLog
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C7 level0 hooks-log -> allow' ($out -notmatch 'permissionDecision') $out

$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchReadme
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C8 level2 other cursor -> allow' ($out -notmatch 'permissionDecision') $out

$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload 'not-json{{{' -LogDir $ld
Write-Case 'C9 parse fail -> allow' ($out -notmatch 'permissionDecision') $out

# ---------- C13-C16: .ai-gates / .codex 中央库路径分级（2026-08-04 软连接改造） ----------
$ldG = Join-Path $tmpRoot 'C13'
New-Item -ItemType Directory -Path $ldG -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchAiSkills
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldG
Write-Case 'C13 .ai-gates/skills no changelog -> deny (level1)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out
[System.IO.File]::WriteAllText((Join-Path $ldG 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldG
Write-Case 'C14 .ai-gates/skills fresh changelog -> allow' ($out -notmatch 'permissionDecision') $out
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchAiReadme
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldG
Write-Case 'C15 .ai-gates/README.md fresh changelog -> allow (level1)' ($out -notmatch 'permissionDecision') $out
Remove-Item -LiteralPath (Join-Path $ldG 'changelog-writes.json') -Force -ErrorAction SilentlyContinue
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldG
Write-Case 'C15b .ai-gates/README.md no changelog -> deny (level1)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchCodexWiring
Remove-Item -LiteralPath (Join-Path $ldG 'changelog-writes.json') -Force -ErrorAction SilentlyContinue
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldG
Write-Case 'C16 .codex wiring no changelog -> deny (level1)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out

# ---------- C10-C12: mixed patch（业务 + .cursor 设施）两道门禁都须通过 ----------
$patchMixed = "*** Begin Patch`n*** Add File: Assets/Doc/Probe.cs`n+public class Probe {}`n*** Update File: .cursor/skills/foo/SKILL.md`n@@`n+x`n*** End Patch`n"
$ldM = Join-Path $tmpRoot 'C10'
New-Item -ItemType Directory -Path $ldM -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchMixed

[System.IO.File]::WriteAllText((Join-Path $ldM 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldM
Write-Case 'C10 mixed fresh changelog no pm -> deny (business gate)' ($out -match '"permissionDecision":"deny"' -and $out -match 'PM gate deny') $out

[System.IO.File]::WriteAllText((Join-Path $ldM 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
Remove-Item -LiteralPath (Join-Path $ldM 'changelog-writes.json') -Force
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldM
Write-Case 'C11 mixed fresh pm no changelog -> deny (level1 gate)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out

[System.IO.File]::WriteAllText((Join-Path $ldM 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ldM
Write-Case 'C12 mixed both fresh -> allow' ($out -notmatch 'permissionDecision') $out

# ---------- D: mark-pm-gate ----------
$ld = Join-Path $tmpRoot 'D'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = @{ session_id = $sid; hook_event_name = 'Stop'; last_assistant_message = '[PM] 判定：允许继续。' } | ConvertTo-Json -Compress
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$gate = Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'D1 stop with [PM] -> marker written' ($gate.$sid.lastPmAtUtc -and $gate.$sid.snippet -match 'PM') ($gate | ConvertTo-Json -Compress)

$p = @{ session_id = $sid; hook_event_name = 'Stop'; last_assistant_message = '普通回复，没有标记。' } | ConvertTo-Json -Compress
$before = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$after = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
Write-Case 'D2 stop without [PM] -> no marker' ($after -eq $before) "before=$before after=$after"

# ---------- E: mark-changelog-write ----------
$ld = Join-Path $tmpRoot 'E'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchChangelog
$null = Invoke-Hook -Script 'mark-changelog-write.ps1' -Payload $p -LogDir $ld
$cw = Get-Content -LiteralPath (Join-Path $ld 'changelog-writes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'E1 changelog patch -> record written' ([bool]$cw.$sid.lastChangelogWriteAtUtc) ($cw | ConvertTo-Json -Compress)

$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchBusiness
$null = Invoke-Hook -Script 'mark-changelog-write.ps1' -Payload $p -LogDir $ld
$cw2 = Get-Content -LiteralPath (Join-Path $ld 'changelog-writes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'E2 business patch -> no new changelog record' ($cw2.$sid.lastChangelogWriteAtUtc -eq $cw.$sid.lastChangelogWriteAtUtc) ($cw2 | ConvertTo-Json -Compress)

# ---------- F: check-unity-compile ----------
$ld = Join-Path $tmpRoot 'F'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$editorLog = Join-Path $ld 'Editor.log'
[System.IO.File]::WriteAllText($editorLog, "Some line`nAssets/Probe.cs(10,20): error CS1000: boom`n", (New-Object System.Text.UTF8Encoding($true)))
$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchBusiness
$out = Invoke-Hook -Script 'check-unity-compile.ps1' -Payload $p -LogDir $ld -EditorLogPath $editorLog
Write-Case 'F1 code patch + fresh error -> additionalContext' ($out -match 'additionalContext' -and $out -match 'error CS') $out

$p = Get-SessionPayload -SessionId $sid -ToolName 'apply_patch' -Command $patchLog
$out = Invoke-Hook -Script 'check-unity-compile.ps1' -Payload $p -LogDir $ld -EditorLogPath $editorLog
Write-Case 'F2 non-code patch -> empty' ($out -notmatch 'additionalContext') $out

# ---------- G: check-hooks-drift ----------
$ld = Join-Path $tmpRoot 'G'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$null = Invoke-Hook -Script 'check-hooks-drift.ps1' -Payload '{}' -LogDir $ld
Write-Case 'G1 wiring ok -> no drift context' (-not (Test-Path -LiteralPath (Join-Path $ld 'codex-hooks-drift.json'))) 'drift file created'

# ---------- 汇总 ----------
Write-Host ''
Write-Host ("passed={0} failed={1}" -f $passed, $failed)
if ($failed -gt 0) {
    Write-Host 'failures:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor Red }
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
exit 0
