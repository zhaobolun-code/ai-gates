# git-safety-check.ps1 -- Codex 版
# PreToolUse hook (matcher: ^Bash$) — 高危 Git 命令门禁。
#
# Cursor 原版挂在 beforeShellExecution；Codex 无该事件，等价映射为 PreToolUse 的 Bash
# 工具（tool_input.command = 实际命令文本）。命中高危 Git 命令 → permissionDecision=deny
# + permissionDecisionReason（Codex 引擎将其作为 "Command blocked by PreToolUse hook:
# <reason>" 呈现给 Agent，工具被硬拦截）；逃生路径：用户确认安全后手动在终端执行 /
# 临时移除 .codex/hooks.json 中本 hook 条目 / 调整命令规避误判。
# 脚本任何异常都不影响原命令执行（fail-open，见 .cursor/hooks.json 的 failClosed:false 惯例）。
# 细则背景：CORE.md §Agent 失败模式与恢复 / references/rollback.md「任何回退前必须显式征得用户确认」。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')
. (Join-Path $PSScriptRoot '..\gate-decision.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$raw = Read-HookStdin
$cmd = ""
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($json.tool_input) {
        $cmd = [string](Get-Property $json.tool_input 'command')
    }
} catch {
    Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line "ALLOW 解析失败"
    Write-Output (Emit-PreToolUseAllow)
    return
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line "ALLOW 空命令"
    Write-Output (Emit-PreToolUseAllow)
    return
}

$gitReason = Test-DangerousGitCommand -CommandText $cmd
if ($gitReason) {
    Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("DENY cmd={0} reason={1}" -f $cmd, $gitReason)
    $shown = Redact-HookSecrets $cmd
    $reason = "检测到高危 Git 命令：$shown。原因：$gitReason。已被 Codex PreToolUse hook 拦截（deny）。逃生：若你确认安全，请在终端手动执行该命令；或临时移除 .codex/hooks.json 中本 hook 条目后重试；或调整命令规避误判。"
    Write-Output (Emit-PreToolUseDeny -Reason $reason)
    return
}

if (Test-GitCommandUnparsed -CommandText $cmd) {
    Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("ALLOW 未解析 cmd={0}" -f $cmd)
}

if (Test-GitForceWithLease -CommandText $cmd) {
    Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("ALLOW force-with-lease cmd={0}" -f $cmd)
}
Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("ALLOW cmd={0}" -f $cmd)
Emit-PreToolUseAllow
