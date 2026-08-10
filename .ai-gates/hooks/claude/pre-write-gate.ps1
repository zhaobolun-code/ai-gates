# pre-write-gate.ps1 -- Claude Code 版（合并入口）
# PreToolUse hook (matcher: ^(Write|Edit|MultiEdit|NotebookEdit)$) -- 把同一事件的两个
# 门禁合并为一次进程调用：
#   audit-write.ps1（写审计，恒 allow）+ pm-gate-check.ps1（PM 写门禁，可 deny）。
#
# 语义与分开挂载时完全一致（2026-08-10 自 Codex 版 pre-apply-patch-gate.ps1 复制改写）：
#   - pm-gate-check deny → 显式检测并输出 deny JSON（不依赖子脚本 exit——
#     PowerShell `&` 上下文里子脚本的 exit 不会终止宿主进程，见 2026-08-06 实测）。
#   - 全部 allow → 输出 pm-gate-check 的 allow JSON（permissionDecision:"allow"）。
#   - audit-write 的审计副作用（write-audit.log）在捕获时照常落盘。
#   - stdin 由本入口预读一次缓存到全局，两个子脚本共享同一 payload。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$null = Read-HookStdin   # 预读一次，子脚本走全局缓存

# audit-write 恒 allow：副作用（write-audit.log）照常发生，输出丢弃
$null = & (Join-Path $PSScriptRoot 'audit-write.ps1') -LogDir $LogDir

# pm-gate-check：命中 deny 短路输出；allow → 输出其 allow JSON
$out = @(& (Join-Path $PSScriptRoot 'pm-gate-check.ps1') -LogDir $LogDir)
$deny = @($out | Where-Object { $_ -match '"permissionDecision"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny) {
    Write-Output $deny
    exit 0
}
$final = $out | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{"hookSpecificOutput":{"hook_event_name":"PreToolUse"}}'
}
Write-Output $final
exit 0
