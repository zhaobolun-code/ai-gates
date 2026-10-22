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

try {
    $raw = [Console]::In.ReadToEnd()
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $cmd = [string]$json.command
} catch {
    Write-Output '{"permission":"allow"}'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Output '{"permission":"allow"}'
    exit 0
}

$dangerousPatterns = @(
    @{ Pattern = 'git\s+push\b[^\n]*(--force(?!-with-lease)\b|\s-f\b|\s\+\S+)'; Reason = '强制推送（--force / -f / +引用）可能覆盖远端历史，无法找回' },
    @{ Pattern = 'git\s+reset\b[^\n]*--hard\b'; Reason = '硬重置（--hard）会丢弃未提交的工作区改动' },
    @{ Pattern = 'git\s+clean\b[^\n]*-[a-zA-Z]*[dfx]'; Reason = 'git clean 会永久删除未跟踪文件' },
    @{ Pattern = 'git\s+checkout\b[^\n]*(--force(?!-with-lease)\b|\s-f\b|--\s|\.$|\s\.\s)'; Reason = 'checkout -f / --force 或 checkout 路径会丢弃未提交改动（对应「方案推翻」流程，须已征得用户确认）' },
    @{ Pattern = 'git\s+branch\b[^\n]*-D\b'; Reason = '强制删除分支（-D）不检查是否已合并' }
)

foreach ($rule in $dangerousPatterns) {
    if ($cmd -match $rule.Pattern) {
        $shown = Redact-HookSecrets $cmd
        $userMsg = "检测到高危 Git 命令：$shown`n原因：$($rule.Reason)`n已被 hook 拦截（deny）。逃生：若你确认安全，请在终端手动执行该命令；或临时移除 hooks.json 中本 hook 条目后重试；或调整命令规避误判。"
        $agentMsg = "hook 拦到高危 Git 命令 ($($rule.Reason))，已 deny（Cursor 2.2+ ask 无效，改硬拦）；逃生：用户手动执行 / 移除本 hook / 调整命令。"
        $result = @{
            permission   = "deny"
            user_message = $userMsg
            agent_message = $agentMsg
        }
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 0
    }
}

if ($cmd -match 'git\s+push\b[^\n]*--force-with-lease\b') {
    try {
        $logDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks-log'
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $shown = Redact-HookSecrets $cmd
        Add-Content -LiteralPath (Join-Path $logDir 'git-safety-check.log') -Value "$ts | ALLOW force-with-lease cmd=$shown" -Encoding UTF8
    } catch { }
}
Write-Output '{"permission":"allow"}'
exit 0
