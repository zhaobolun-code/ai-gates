# git-safety-check.ps1 -- Claude Code 版
# PreToolUse hook (matcher: ^Bash$) — 高危 Git 命令门禁。
#
# 与 Codex 版同源（2026-08-10 复制改写）：Claude Code 的 Bash 工具输入
# tool_input.command = 实际命令文本。命中高危 Git 命令 → permissionDecision=deny
# + permissionDecisionReason（Claude Code 引擎将其作为 "Blocked by PreToolUse hook:
# <reason>" 呈现给 Agent，工具被硬拦截）；逃生路径：用户确认安全后手动在终端执行 /
# 临时移除 .claude/settings.json 中本 hook 条目 / 调整命令规避误判。
# 脚本任何异常都不影响原命令执行（fail-open；Claude Code 无 failClosed 概念，脚本恒 exit 0）。
# 细则背景：CORE.md §Agent 失败模式与恢复 / references/rollback.md「任何回退前必须显式征得用户确认」。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$raw = Read-HookStdin
$cmd = ""
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($json.tool_input) {
        $cmd = [string](Get-Property $json.tool_input 'command')
    }
} catch {
    # 解析异常 fail-open：不影响原命令执行
    Write-Output (Emit-PreToolUseAllow)
    return
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Output (Emit-PreToolUseAllow)
    return
}

$dangerousPatterns = @(
    @{ Pattern = 'git\s+push\b[^\n]*(--force\b|--force-with-lease\b|\s-f\b)'; Reason = '强制推送（--force / -f）可能覆盖远端历史，无法找回' },
    @{ Pattern = 'git\s+reset\b[^\n]*--hard\b'; Reason = '硬重置（--hard）会丢弃未提交的工作区改动' },
    @{ Pattern = 'git\s+clean\b[^\n]*-[a-zA-Z]*[dfx]'; Reason = 'git clean 会永久删除未跟踪文件' },
    @{ Pattern = 'git\s+checkout\b[^\n]*(--\s|\.$|\s\.\s)'; Reason = 'checkout 会丢弃指定文件的未提交改动（对应「方案推翻」流程，须已征得用户确认）' },
    @{ Pattern = 'git\s+branch\b[^\n]*-D\b'; Reason = '强制删除分支（-D）不检查是否已合并' }
)

foreach ($rule in $dangerousPatterns) {
    if ($cmd -match $rule.Pattern) {
        Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("DENY cmd={0} reason={1}" -f $cmd, $rule.Reason)
        $reason = "检测到高危 Git 命令：$cmd。原因：$($rule.Reason)。已被 Claude Code PreToolUse hook 拦截（deny）。逃生：若你确认安全，请在终端手动执行该命令；或临时移除 .claude/settings.json 中本 hook 条目后重试；或调整命令规避误判。"
        Write-Output (Emit-PreToolUseDeny -Reason $reason)
        return
    }
}

Write-HookAudit -LogDir $LogDir -FileName 'git-safety-check.log' -Line ("ALLOW cmd={0}" -f $cmd)
Emit-PreToolUseAllow
