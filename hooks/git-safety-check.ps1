# git-safety-check.ps1
# beforeShellExecution hook — 硬门禁机械化第一版（observe/ask，不做硬 deny）。
# 命中高危 Git 命令时返回 permission=ask，交回用户在 Cursor 里手动确认/拒绝；
# 脚本任何异常都不影响原命令执行（失败开放，见 .cursor/hooks.json 的 failClosed:false）。
# 细则背景：CORE.md §Agent 失败模式与恢复 / references/rollback.md「任何回退前必须显式征得用户确认」。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

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
    @{ Pattern = 'git\s+push\b[^\n]*(--force\b|--force-with-lease\b|\s-f\b)'; Reason = '强制推送（--force / -f）可能覆盖远端历史，无法找回' },
    @{ Pattern = 'git\s+reset\b[^\n]*--hard\b'; Reason = '硬重置（--hard）会丢弃未提交的工作区改动' },
    @{ Pattern = 'git\s+clean\b[^\n]*-[a-zA-Z]*[dfx]'; Reason = 'git clean 会永久删除未跟踪文件' },
    @{ Pattern = 'git\s+checkout\b[^\n]*(--\s|\.$|\s\.\s)'; Reason = 'checkout 会丢弃指定文件的未提交改动（对应「方案推翻」流程，须已征得用户确认）' },
    @{ Pattern = 'git\s+branch\b[^\n]*-D\b'; Reason = '强制删除分支（-D）不检查是否已合并' }
)

foreach ($rule in $dangerousPatterns) {
    if ($cmd -match $rule.Pattern) {
        $userMsg = "检测到高危 Git 命令：$cmd`n原因：$($rule.Reason)`n请确认这是你（或本轮已明确同意的操作），不确定就选择拒绝。"
        $agentMsg = "hook 拦到高危 Git 命令 ($($rule.Reason))，已转人工确认（ask），不是自动拒绝；用户确认后会继续执行。"
        $result = @{
            permission   = "ask"
            user_message = $userMsg
            agent_message = $agentMsg
        }
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 0
    }
}

Write-Output '{"permission":"allow"}'
exit 0
