# pre-write-gate.ps1 -- Cursor 版（合并入口）
# preToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 把同一事件的两个门禁
# 合并为一次进程调用：audit-write.ps1（写审计，恒 allow）+ pm-gate-check.ps1（PM 写门禁，可 deny）。
#
# 语义与分开挂载时完全一致：
#   - pm-gate-check deny → 显式检测并输出 deny JSON（不依赖子脚本 exit——
#     PowerShell `&` 上下文里子脚本的 exit 不会终止宿主进程，见 2026-08-06 实测；
#     子脚本判定点已改为输出后 `return` 终止，保证单行 JSON）。
#   - 全部 allow → 输出 pm-gate-check 的 allow JSON（{"permission":"allow"}）。
#   - audit-write 的审计副作用（write-audit.log）在捕获时照常落盘。
#   - stdin 由本入口预读一次缓存到全局，两个子脚本共享同一 payload
#     （Read-HookStdin 全局缓存，见 cursor-hooks-common.ps1）。
# 收益：Write/StrReplace/EditNotebook 事件的进程 spawn 从 2 次降到 1 次。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

$null = Read-HookStdin   # 预读一次，子脚本走全局缓存

# audit-write 恒 allow：副作用（write-audit.log）照常发生，输出丢弃
$null = & (Join-Path $PSScriptRoot 'audit-write.ps1')

# pm-gate-check：命中 deny 短路输出；allow → 输出其 allow JSON
$out = @(& (Join-Path $PSScriptRoot 'pm-gate-check.ps1'))
$deny = @($out | Where-Object { $_ -match '"permission"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny) {
    Write-Output $deny
    exit 0
}
$final = $out | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{"permission":"allow"}'
}
Write-Output $final
exit 0
