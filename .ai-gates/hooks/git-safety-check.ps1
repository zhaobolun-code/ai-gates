# git-safety-check.ps1
# beforeShellExecution hook — 高危 Git 命令门禁。
# 命中高危 Git 命令时返回 permission=deny + user_message 逃生提示（2026-08-03 由 ask 改：
# Cursor 2.2+ 的 hook `permission: ask` 是官方确认 bug，不弹窗直接放行，只剩 deny/allow 有效）；
# 逃生路径：用户确认安全后手动在终端执行，或临时移除本 hook 条目（hooks.json），或编辑命令规避误判。
# 脚本任何异常都不影响原命令执行（失败开放，见 .cursor/hooks.json 的 failClosed:false）。
# 细则背景：CORE.md §Agent 失败模式与恢复 / references/rollback.md「任何回退前必须显式征得用户确认」。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
. (Join-Path $PSScriptRoot 'gate-decision.ps1')

function Write-GitSafetyLine {
    param([string]$Line)
    $logDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks-log'
    try {
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath (Join-Path $logDir 'git-safety-check.log') -Value "$ts | $Line" -Encoding UTF8
    } catch {
        try { [Console]::Error.WriteLine("git-safety-check log failed: $Line") } catch { }
    }
}

try {
    $raw = Read-HookStdin
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $cmd = [string]$json.command
} catch {
    Write-GitSafetyLine "ALLOW 解析失败"
    Write-Output '{"permission":"allow"}'
    return
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-GitSafetyLine "ALLOW 空命令"
    Write-Output '{"permission":"allow"}'
    return
}

$gitReason = Test-DangerousGitCommand -CommandText $cmd
if ($gitReason) {
    $shown = Redact-HookSecrets $cmd
    $userMsg = "检测到高危 Git 命令：$shown`n原因：$gitReason`n已被 hook 拦截（deny）。逃生：若你确认安全，请在终端手动执行该命令；或临时移除 hooks.json 中本 hook 条目后重试；或调整命令规避误判。"
    $agentMsg = "hook 拦到高危 Git 命令 ($gitReason)，已 deny（Cursor 2.2+ ask 无效，改硬拦）；逃生：用户手动执行 / 移除本 hook / 调整命令。"
    $result = @{
        permission    = "deny"
        user_message  = $userMsg
        agent_message = $agentMsg
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    return
}

if (Test-GitCommandUnparsed -CommandText $cmd) {
    $shown = Redact-HookSecrets $cmd
    Write-GitSafetyLine "ALLOW 未解析 cmd=$shown"
}

if (Test-GitForceWithLease -CommandText $cmd) {
    $shown = Redact-HookSecrets $cmd
    Write-GitSafetyLine "ALLOW force-with-lease cmd=$shown"
}
Write-Output '{"permission":"allow"}'
return
