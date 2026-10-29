# bash-write-gate.ps1 -- Cursor 版
# beforeShellExecution：显式写文件（Set-Content / Out-File / 重定向）走与写工具相同的新鲜度。
# 判定在 gate-decision.ps1。本文件只读 Cursor 的 command / conversation_id，写出 permission。
# 解析失败、提不到路径、非显式写入 → allow。failClosed 仍由 hooks.json 保持 false。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
. (Join-Path $PSScriptRoot 'gate-decision.ps1')

if (-not $LogDir) {
    $LogDir = Join-Path (Get-AiGatesProjectRoot) '.ai-gates\hooks-log'
    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
}
$gateFile = Join-Path $LogDir 'pm-gate.json'
$changelogFile = Join-Path $LogDir 'changelog-writes.json'
$killSwitch = Join-Path $LogDir 'pm-gate-disabled'
$auditFile = Join-Path $LogDir 'bash-write-gate.log'

function Write-BashAudit {
    param([string]$Line)
    try {
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $safe = Redact-HookSecrets $Line
        Add-Content -LiteralPath $auditFile -Value "$ts | $safe" -Encoding UTF8
    } catch { }
}

$raw = Read-HookStdin
$cmd = ""
$sessionId = "unknown"
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($json.conversation_id) { $sessionId = [string]$json.conversation_id }
    elseif ($json.session_id) { $sessionId = [string]$json.session_id }
    $cmd = [string]$json.command
    if ([string]::IsNullOrWhiteSpace($cmd) -and $json.tool_input) {
        $cmd = [string]$json.tool_input.command
    }
} catch {
    Write-BashAudit "ALLOW parse_failed_fail_open session=$sessionId"
    Write-Output '{"permission":"allow","reason":"parse_failed_fail_open"}'
    return
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Output '{"permission":"allow","reason":"empty_command"}'
    return
}

if (Test-Path -LiteralPath $killSwitch) {
    Write-BashAudit "ALLOW kill_switch_active session=$sessionId"
    Write-Output '{"permission":"allow","reason":"kill_switch_active"}'
    return
}

if (Test-AuthScriptInvoke -CommandText $cmd) {
    Write-BashAudit "DENY auth_script_invoke session=$sessionId"
    $result = @{
        permission    = "deny"
        user_message  = "Shell 不能直接运行打点脚本。这道门只认命令行里的脚本名；改名再跑，或用别的程序写状态文件，不在这道门里。"
        agent_message = "bash-write-gate deny auth_script_invoke"
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    return
}

$paths = @(Get-ExplicitWritePaths -CommandText $cmd)
if ($paths.Count -eq 0) {
    Write-BashAudit "ALLOW no_write_detected session=$sessionId"
    Write-Output '{"permission":"allow","reason":"no_write_detected"}'
    return
}

$hasPm = Test-SessionStampFresh -FilePath $gateFile -SessionId $sessionId -StampName 'lastPmAtUtc'
$hasLog = Test-SessionStampFresh -FilePath $changelogFile -SessionId $sessionId -StampName 'lastChangelogWriteAtUtc'
$blocks = Get-ShellWriteBlocks -Paths $paths -HasFreshPm $hasPm -HasFreshChangelog $hasLog
if ($blocks.Count -gt 0) {
    $pathText = ($blocks | ForEach-Object { $_.Path }) -join ', '
    $reasonText = ($blocks | ForEach-Object { $_.Reason }) -join ', '
    $hint = "逃生：业务路径先在本会话回复里发出 [PM]，设施路径先写 CHANGELOG，待打点后重试；或放置 .ai-gates/hooks-log/pm-gate-disabled 后重试；或改用 Write 工具。"
    Write-BashAudit ("DENY session={0} paths={1} reasons={2}" -f $sessionId, $pathText, $reasonText)
    $result = @{
        permission    = "deny"
        user_message  = "Shell 显式写文件被拦：$pathText。缺 $reasonText。$hint"
        agent_message = "bash-write-gate deny paths=$pathText reasons=$reasonText"
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    return
}

Write-BashAudit ("ALLOW write_paths_ok session={0} paths={1}" -f $sessionId, ($paths -join ','))
Write-Output '{"permission":"allow","reason":"write_paths_ok"}'
return
