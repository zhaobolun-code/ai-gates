# bash-write-gate.ps1 -- Codex 版
# PreToolUse hook (matcher: ^Bash$) -- 显式文件写入门禁，补 apply_patch 门禁的 Bash 逃逸洞。
# 判定在 ../gate-decision.ps1。本文件只读 Codex 的 tool_input.command，写出 permissionDecision。
# 解析不确定 / 提取不到路径 / 非显式写入命令 → fail-open allow。
# Codex 允许时省略 permissionDecision（见 codex-hooks-common.ps1）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')
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
$blocks = Get-ShellWriteBlocks -Paths $paths -HasFreshPm $hasPm -HasFreshChangelog $hasLog
if ($blocks.Count -gt 0) {
    $blocked = @($blocks | ForEach-Object { $_.Path })
    $blockedReasons = @($blocks | ForEach-Object { $_.Reason })
    $hint = "逃生：先在本会话回复中发出 [PM] 标记（设施路径则先写 CHANGELOG），待 Stop hook 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或改用 apply_patch 走常规写门禁。"
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("DENY session={0} paths={1} reasons={2}" -f $sessionId, ($blocked -join ','), ($blockedReasons -join ','))
    Write-Output (Emit-PreToolUseDeny -Reason ("Bash write gate deny: explicit file write to {0} without {1}. {2}" -f ($blocked -join ', '), ($blockedReasons -join ', '), $hint))
    return
}

Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW write_paths_ok session={0} paths={1}" -f $sessionId, ($paths -join ','))
Emit-PreToolUseAllow
