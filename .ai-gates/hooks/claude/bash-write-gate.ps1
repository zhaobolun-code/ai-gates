# bash-write-gate.ps1 -- Claude Code 版
# PreToolUse hook (matcher: ^Bash$) -- 显式文件写入门禁，补 Write/Edit/MultiEdit 门禁的 Bash 逃逸洞。
#
# 背景（2026-08-05，Claude 版 2026-08-10 复制改写）：pm-gate-check.ps1 只挂在
# ^(Write|Edit|MultiEdit|NotebookEdit)$；Bash 里 Set-Content / Out-File /
# [IO.File]::WriteAll* / 重定向 等显式写文件命令不受写门禁约束。本钩子把"显式写文件"的
# Bash 命令纳入同一套语义：
#   - 业务路径（非 .cursor/.ai-gates/.codex/.claude 设施）→ 须会话内新鲜 [PM] 标记（120 分钟）
#   - .cursor/.ai-gates/.codex/.claude 设施路径 → 须近期 CHANGELOG 写（120 分钟）
#   - 生成/运行时目录白名单放行（bin/obj/Library/Temp/Logs/node_modules/.git、
#     .ai-gates/{tmp,hooks-log,verify,releases}）
# 解析不确定 / 提取不到路径 / 非显式写入命令 → fail-open allow（与 git-safety-check 同惯例）。
# 逃生：kill switch（.ai-gates/hooks-log/pm-gate-disabled）/ 手动编辑 / 改用 Write/Edit。
#
# 注意：本钩子只拦"显式写文件"命令，不拦构建/测试（dotnet build、Unity batchmode 等
# 通过自身引擎写生成文件）；生成目录白名单兜底放行，误判靠 fail-open + 逃生通道兜底。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')
. (Join-Path $PSScriptRoot '..\gate-decision.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$gateFile = Join-Path $LogDir 'pm-gate.json'
$changelogFile = Join-Path $LogDir 'changelog-writes.json'
$killSwitch = Join-Path $LogDir 'pm-gate-disabled'
$FreshnessMinutes = 120

function Test-KillSwitch {
    return (Test-Path -LiteralPath $killSwitch)
}

$raw = Read-HookStdin
$cmd = ""
$sessionId = "unknown"
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $sessionId = Get-SessionId -Json $json -Raw $raw
    if ($json.tool_input) {
        $cmd = [string](Get-Property $json.tool_input 'command')
    }
} catch {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW parse_failed_fail_open session={0}" -f $sessionId)
    Write-Output (Emit-PreToolUseAllow)
    return
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Output (Emit-PreToolUseAllow)
    return
}

if (Test-KillSwitch) {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW kill_switch_active session={0}" -f $sessionId)
    Write-Output (Emit-PreToolUseAllow)
    return
}

if (Test-AuthScriptInvoke -CommandText $cmd) {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("DENY auth_script_invoke session={0}" -f $sessionId)
    Write-Output (Emit-PreToolUseDeny -Reason "Bash write gate deny: auth_script_invoke. The shell gate only matches the script name. A renamed copy or another program writing the state file is outside this gate.")
    return
}

$paths = @(Get-ExplicitWritePaths -CommandText $cmd)
if ($paths.Count -eq 0) {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW no_write_detected session={0}" -f $sessionId)
    Write-Output (Emit-PreToolUseAllow)
    return
}

$hasPm = Test-SessionStampFresh -FilePath $gateFile -SessionId $sessionId -StampName 'lastPmAtUtc' -FreshnessMinutes $FreshnessMinutes
$hasLog = Test-SessionStampFresh -FilePath $changelogFile -SessionId $sessionId -StampName 'lastChangelogWriteAtUtc' -FreshnessMinutes $FreshnessMinutes
$blocks = Get-ShellWriteBlocks -Paths $paths -HasFreshPm $hasPm -HasFreshChangelog $hasLog -IncludeClaude
$blocked = @($blocks | ForEach-Object { $_.Path })
$blockedReasons = @($blocks | ForEach-Object { $_.Reason })

if ($blocked.Count -gt 0) {
    $hint = "逃生：先在本会话回复中发出 [PM] 标记（设施路径则先写 CHANGELOG），待 Stop hook 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或改用 Write/Edit 走常规写门禁。"
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("DENY session={0} paths={1} reasons={2}" -f $sessionId, ($blocked -join ','), ($blockedReasons -join ','))
    Write-Output (Emit-PreToolUseDeny -Reason ("Bash write gate deny: explicit file write to {0} without {1}. {2}" -f ($blocked -join ', '), ($blockedReasons -join ', '), $hint))
    return
}

Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW write_paths_ok session={0} paths={1}" -f $sessionId, ($paths -join ','))
Emit-PreToolUseAllow
