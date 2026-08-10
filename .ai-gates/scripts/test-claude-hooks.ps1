# test-claude-hooks.ps1
# Claude Code 版 hooks 注入式回归测试（对齐 test-codex-hooks.ps1 的构造 stdin 思路，
# 验证脚本内部逻辑；验证不了 Claude Code 真实事件的触发与注入效果——那部分需真机
# 会话端到端验证，见 .ai-gates/skills/MAINTAINER.md 与 claude-hooks-common.ps1 头注释
# 真机验证点 #1-#4）。
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .ai-gates/scripts/test-claude-hooks.ps1
#
# 约定：所有脚本输出 stdout 必须是单一 JSON 行（allow=permissionDecision:"allow"；
# deny=带 reason）；本测试据此断言。
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$hooksClaudeDir = Join-Path $PSScriptRoot '..\hooks\claude'
$tmpRoot = Join-Path $env:TEMP ("claude-hooks-test-" + [Guid]::NewGuid().ToString('N'))
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
    $ps = Join-Path $hooksClaudeDir $Script
    if ($EditorLogPath) {
        $out = $Payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $ps -LogDir $LogDir -EditorLogPath $EditorLogPath 2>$null
    } else {
        $out = $Payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $ps -LogDir $LogDir 2>$null
    }
    return [string]::Join("`n", @($out))
}

# Claude Code 工具输入构造：Write/Edit/MultiEdit 用 file_path，NotebookEdit 用 notebook_path，Bash 用 command
function Get-WritePayload {
    param([string]$SessionId, [string]$FilePath, [string]$ToolName = "Write")
    if ($ToolName -eq 'NotebookEdit') {
        return (@{
            session_id      = $SessionId
            hook_event_name = 'PreToolUse'
            tool_name       = $ToolName
            tool_input      = @{ notebook_path = $FilePath }
        } | ConvertTo-Json -Compress -Depth 6)
    }
    return (@{
        session_id      = $SessionId
        hook_event_name = 'PreToolUse'
        tool_name       = $ToolName
        tool_input      = @{ file_path = $FilePath }
    } | ConvertTo-Json -Compress -Depth 6)
}

function Get-BashPayload {
    param([string]$SessionId, [string]$Command)
    return (@{
        session_id      = $SessionId
        hook_event_name = 'PreToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $Command }
    } | ConvertTo-Json -Compress -Depth 6)
}

function Get-StopPayload {
    param([string]$SessionId, [string]$TranscriptPath)
    return (@{
        session_id      = $SessionId
        hook_event_name = 'Stop'
        transcript_path = $TranscriptPath
        stop_hook_active = $true
    } | ConvertTo-Json -Compress -Depth 6)
}

$sid = 'test-session-0001'
$businessPath = 'Assets/Doc/Probe.cs'
$changelogPath = '.ai-gates/CHANGELOG.md'
$logPath = '.ai-gates/hooks-log/foo.log'
$claudeSettingsPath = '.claude/settings.json'
$claudeAgentPath = '.claude/agents/pm.md'

# ---------- A: git-safety-check ----------
$ld = Join-Path $tmpRoot 'A'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-BashPayload -SessionId $sid -Command 'git push --force origin main'
$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload $p -LogDir $ld
$json = $out | ConvertFrom-Json
Write-Case 'A1 git push --force -> deny' ($json.hookSpecificOutput.permissionDecision -eq 'deny' -and -not [string]::IsNullOrWhiteSpace($json.hookSpecificOutput.permissionDecisionReason) -and $json.hookSpecificOutput.hook_event_name -eq 'PreToolUse') $out

$p = Get-BashPayload -SessionId $sid -Command 'git status'
$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload $p -LogDir $ld
Write-Case 'A2 git status -> allow' ($out -match '"permissionDecision":"allow"') $out

$out = Invoke-Hook -Script 'git-safety-check.ps1' -Payload 'not-json{{{' -LogDir $ld
Write-Case 'A3 parse fail -> allow' ($out -match '"permissionDecision":"allow"') $out

# ---------- B: audit-write ----------
$ld = Join-Path $tmpRoot 'B'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-WritePayload -SessionId $sid -FilePath $businessPath
$out = Invoke-Hook -Script 'audit-write.ps1' -Payload $p -LogDir $ld
$audit = Get-Content -LiteralPath (Join-Path $ld 'write-audit.log') -Raw -Encoding UTF8
Write-Case 'B1 audit logs file_path + allow' ($out -match '"permissionDecision":"allow"' -and $audit -match 'Assets/Doc/Probe.cs' -and $audit -match $sid) $out

# ---------- C: pm-gate-check ----------
$ld = Join-Path $tmpRoot 'C'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-WritePayload -SessionId $sid -FilePath $businessPath
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C1 business no marker -> deny' ($out -match '"permissionDecision":"deny"' -and $out -match 'permissionDecisionReason') $out

$now = [DateTime]::UtcNow.ToString('o')
[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $now; snippet = 'PM 判定' } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C2 business fresh marker -> allow' ($out -match '"permissionDecision":"allow"') $out

$stale = [DateTime]::UtcNow.AddHours(-3).ToString('o')
[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $stale } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C3 business stale marker -> deny' ($out -match '"permissionDecision":"deny"') $out

New-Item -ItemType File -Path (Join-Path $ld 'pm-gate-disabled') -Force | Out-Null
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C4 kill switch -> allow' ($out -match '"permissionDecision":"allow"') $out
Remove-Item -LiteralPath (Join-Path $ld 'pm-gate-disabled') -Force

# .claude 设施（Level 1：须近期 CHANGELOG 写）
$p = Get-WritePayload -SessionId $sid -FilePath $claudeSettingsPath
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C5 .claude/settings.json no changelog -> deny (level1)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out

[System.IO.File]::WriteAllText((Join-Path $ld 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C6 .claude/settings.json fresh changelog -> allow' ($out -match '"permissionDecision":"allow"') $out

# .claude/settings.local.json（机器本地，Level 0 豁免）
$p = Get-WritePayload -SessionId $sid -FilePath '.claude/settings.local.json'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C6b .claude/settings.local.json -> allow (level0)' ($out -match '"permissionDecision":"allow"') $out

# 经 .ai-gates/claude 路径写 settings.json（与 .claude 传送门路径等价，Level 1）
$p = Get-WritePayload -SessionId $sid -FilePath '.ai-gates/claude/settings.json'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C6c .ai-gates/claude/settings.json fresh changelog -> allow' ($out -match '"permissionDecision":"allow"') $out

$p = Get-WritePayload -SessionId $sid -FilePath '.ai-gates/claude/agents/pm.md'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C6d .ai-gates/claude/agents fresh changelog -> allow' ($out -match '"permissionDecision":"allow"') $out

$p = Get-WritePayload -SessionId $sid -FilePath $logPath
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C7 level0 hooks-log -> allow' ($out -match '"permissionDecision":"allow"') $out

$p = Get-WritePayload -SessionId $sid -FilePath $changelogPath
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C7b CHANGELOG 自身 -> allow (level0)' ($out -match '"permissionDecision":"allow"') $out

# 根 README.md 不是设施路径（Test-CursorInfraPath 只认 .cursor/.ai-gates/.codex/.claude）
# → 业务路径门禁：stale marker 应 deny、fresh marker 应 allow
$p = Get-WritePayload -SessionId $sid -FilePath 'README.md'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C8 根 README（业务路径）stale pm -> deny' ($out -match '"permissionDecision":"deny"' -and $out -match 'stale_pm_marker') $out

[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $now; snippet = 'PM 判定' } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C8b 根 README（业务路径）fresh pm -> allow' ($out -match '"permissionDecision":"allow"') $out

# .ai-gates/README.md 是设施内根文档 → Level 1 轻门禁（查 changelog 流水，不读 PM marker）
$p = Get-WritePayload -SessionId $sid -FilePath '.ai-gates/README.md'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C8c .ai-gates/README.md fresh changelog -> allow (level1)' ($out -match '"permissionDecision":"allow"') $out

Remove-Item -LiteralPath (Join-Path $ld 'changelog-writes.json') -Force
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C8d .ai-gates/README.md no changelog -> deny (level1)' ($out -match '"permissionDecision":"deny"' -and $out -match 'Level-1') $out
[System.IO.File]::WriteAllText((Join-Path $ld 'changelog-writes.json'), (@{ $sid = @{ lastChangelogWriteAtUtc = $now } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))

$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload 'not-json{{{' -LogDir $ld
Write-Case 'C9 parse fail -> allow' ($out -match '"permissionDecision":"allow"') $out

# NotebookEdit 路径提取（先清 marker，恢复无标记状态）
Remove-Item -LiteralPath (Join-Path $ld 'pm-gate.json') -Force
$p = Get-WritePayload -SessionId $sid -FilePath 'Assets/Doc/Probe.ipynb' -ToolName 'NotebookEdit'
$out = Invoke-Hook -Script 'pm-gate-check.ps1' -Payload $p -LogDir $ld
Write-Case 'C10 NotebookEdit 业务路径无标记 -> deny' ($out -match '"permissionDecision":"deny"') $out

# ---------- D: mark-pm-gate（transcript JSONL 解析） ----------
$ld = Join-Path $tmpRoot 'D'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$transcriptPm = Join-Path $ld 'transcript-pm.jsonl'
$transcriptNoPm = Join-Path $ld 'transcript-nopm.jsonl'
$transcriptStr = Join-Path $ld 'transcript-str.jsonl'
[System.IO.File]::WriteAllLines($transcriptPm, @(
    '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"做 Step 1"}]}}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"[PM] 判定：Standard。你下一步…"}]}}'
), (New-Object System.Text.UTF8Encoding($true)))
[System.IO.File]::WriteAllLines($transcriptNoPm, @(
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"普通回复，没有标记。"}]}}'
), (New-Object System.Text.UTF8Encoding($true)))
[System.IO.File]::WriteAllLines($transcriptStr, @(
    '{"type":"assistant","message":{"role":"assistant","content":"[PM] 判定：字符串 content 兼容。"}}'
), (New-Object System.Text.UTF8Encoding($true)))

$p = Get-StopPayload -SessionId $sid -TranscriptPath $transcriptPm
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$gate = Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'D1 stop transcript with [PM] -> marker written' ($gate.$sid.lastPmAtUtc -and $gate.$sid.snippet -match 'PM') ($gate | ConvertTo-Json -Compress)

$p = Get-StopPayload -SessionId $sid -TranscriptPath $transcriptNoPm
$before = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$after = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
Write-Case 'D2 stop transcript without [PM] -> no marker' ($after -eq $before) "before=$before after=$after"

$p = Get-StopPayload -SessionId $sid -TranscriptPath $transcriptStr
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$gate3 = Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'D3 stop transcript content as string -> marker written' ([bool]$gate3.$sid.lastPmAtUtc) ($gate3 | ConvertTo-Json -Compress)

$p = Get-StopPayload -SessionId $sid -TranscriptPath (Join-Path $ld 'missing.jsonl')
$before = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
$null = Invoke-Hook -Script 'mark-pm-gate.ps1' -Payload $p -LogDir $ld
$after = (Get-Content -LiteralPath (Join-Path $ld 'pm-gate.json') -Raw -Encoding UTF8).Length
Write-Case 'D4 transcript missing -> no marker, no crash' ($after -eq $before) "before=$before after=$after"

# ---------- E: mark-changelog-write ----------
$ld = Join-Path $tmpRoot 'E'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-WritePayload -SessionId $sid -FilePath $changelogPath
$null = Invoke-Hook -Script 'mark-changelog-write.ps1' -Payload $p -LogDir $ld
$cw = Get-Content -LiteralPath (Join-Path $ld 'changelog-writes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'E1 changelog write -> record written' ([bool]$cw.$sid.lastChangelogWriteAtUtc) ($cw | ConvertTo-Json -Compress)

$p = Get-WritePayload -SessionId $sid -FilePath $businessPath
$null = Invoke-Hook -Script 'mark-changelog-write.ps1' -Payload $p -LogDir $ld
$cw2 = Get-Content -LiteralPath (Join-Path $ld 'changelog-writes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Case 'E2 business write -> no new changelog record' ($cw2.$sid.lastChangelogWriteAtUtc -eq $cw.$sid.lastChangelogWriteAtUtc) ($cw2 | ConvertTo-Json -Compress)

# ---------- F: check-unity-compile ----------
$ld = Join-Path $tmpRoot 'F'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$editorLog = Join-Path $ld 'Editor.log'
[System.IO.File]::WriteAllText($editorLog, "Some line`nAssets/Probe.cs(10,20): error CS1000: boom`n", (New-Object System.Text.UTF8Encoding($true)))
$p = Get-WritePayload -SessionId $sid -FilePath 'Assets/Probe.cs'
$out = Invoke-Hook -Script 'check-unity-compile.ps1' -Payload $p -LogDir $ld -EditorLogPath $editorLog
Write-Case 'F1 code write + fresh error -> additionalContext' ($out -match 'additionalContext' -and $out -match 'error CS') $out

$p = Get-WritePayload -SessionId $sid -FilePath $logPath
$out = Invoke-Hook -Script 'check-unity-compile.ps1' -Payload $p -LogDir $ld -EditorLogPath $editorLog
Write-Case 'F2 non-code write -> empty' ($out -notmatch 'additionalContext') $out

# ---------- G: check-hooks-drift（本仓库接线自检；传送门未建时也应 fail-open 不崩） ----------
$ld = Join-Path $tmpRoot 'G'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$out = Invoke-Hook -Script 'check-hooks-drift.ps1' -Payload '{}' -LogDir $ld
$parsedOk = $true
try { $null = $out | ConvertFrom-Json -ErrorAction Stop } catch { $parsedOk = $false }
Write-Case 'G1 drift check runs, stdout parseable JSON' $parsedOk $out

# ---------- H: 合并入口 ----------
$ld = Join-Path $tmpRoot 'H'
New-Item -ItemType Directory -Path $ld -Force | Out-Null
$p = Get-BashPayload -SessionId $sid -Command 'git push --force origin main'
$out = Invoke-Hook -Script 'pre-bash-gate.ps1' -Payload $p -LogDir $ld
Write-Case 'H1 pre-bash-gate git push --force -> deny' ($out -match '"permissionDecision":"deny"') $out

$p = Get-WritePayload -SessionId $sid -FilePath $businessPath
$out = Invoke-Hook -Script 'pre-write-gate.ps1' -Payload $p -LogDir $ld
Write-Case 'H2 pre-write-gate business no marker -> deny' ($out -match '"permissionDecision":"deny"') $out

[System.IO.File]::WriteAllText((Join-Path $ld 'pm-gate.json'), (@{ $sid = @{ lastPmAtUtc = $now; snippet = 'PM 判定' } } | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
$out = Invoke-Hook -Script 'pre-write-gate.ps1' -Payload $p -LogDir $ld
Write-Case 'H3 pre-write-gate fresh pm -> allow' ($out -match '"permissionDecision":"allow"' -and $out -notmatch '"deny"') $out

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
