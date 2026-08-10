# pre-bash-gate.ps1 -- Claude Code 版（合并入口）
# PreToolUse hook (matcher: ^Bash$) -- 把同一事件的两个门禁合并为一次进程调用：
#   git-safety-check.ps1（高危 Git deny）+ bash-write-gate.ps1（显式写文件门禁）。
#
# 语义与分开挂载时完全一致（2026-08-10 自 Codex 版复制改写）：
#   - 任一门禁 deny → 输出该 deny JSON 后退出（显式检测，不依赖子脚本 exit——
#     PowerShell `&` 上下文里子脚本的 exit 不会终止宿主进程，见 2026-08-06 实测）。
#   - 全部 allow → 输出最后一个 allow JSON（permissionDecision:"allow"，显式 allow 受支持）。
#   - stdin 由本入口预读一次缓存到全局，两个子脚本共享同一 payload
#     （Read-HookStdin 全局缓存，见 claude-hooks-common.ps1）。
# 收益：Bash 事件的进程 spawn 从 2 次降到 1 次（长会话省时间）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$null = Read-HookStdin   # 预读一次，子脚本走全局缓存

# git-safety 先跑：捕获其输出，命中 deny 立即短路输出
$out1 = @(& (Join-Path $PSScriptRoot 'git-safety-check.ps1') -LogDir $LogDir)
$deny1 = @($out1 | Where-Object { $_ -match '"permissionDecision"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny1) {
    Write-Output $deny1
    exit 0
}

# bash-write-gate 后跑：命中 deny 短路输出；否则输出其 allow JSON
$out2 = @(& (Join-Path $PSScriptRoot 'bash-write-gate.ps1') -LogDir $LogDir)
$deny2 = @($out2 | Where-Object { $_ -match '"permissionDecision"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny2) {
    Write-Output $deny2
    exit 0
}
$final = $out2 | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{"hookSpecificOutput":{"hook_event_name":"PreToolUse"}}'
}
Write-Output $final
exit 0
