# post-write-gate.ps1 -- Cursor 版（合并入口）
# postToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 把同一事件的两个观测门
# 合并为一次进程调用：mark-changelog-write.ps1（CHANGELOG 写打点，副作用落盘）+
# check-unity-compile.ps1（写后 Unity 编译错误提示，可注入 additional_context）。
#
# 语义与分开挂载时完全一致：
#   - changelog 打点先跑，保证 changelog-writes.json 副作用无条件发生；
#   - check-unity-compile 输出 context JSON（命中编译错误）或 {}（早退/无错误）；
#   - stdin 由本入口预读一次缓存到全局，两个子脚本共享同一 payload。
# 收益：Write/StrReplace/EditNotebook 事件的进程 spawn 从 2 次降到 1 次。

param(
    [string]$EditorLogPath = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

$null = Read-HookStdin   # 预读一次，子脚本走全局缓存

# changelog 打点先跑（副作用必须无条件发生）；无 stdout，丢弃
$null = & (Join-Path $PSScriptRoot 'mark-changelog-write.ps1')

# check-unity-compile 后跑：EditorLogPath 仅在显式传入时透传（默认走脚本内置默认路径）
if ($EditorLogPath) {
    $out = @(& (Join-Path $PSScriptRoot 'check-unity-compile.ps1') -EditorLogPath $EditorLogPath)
} else {
    $out = @(& (Join-Path $PSScriptRoot 'check-unity-compile.ps1'))
}
$final = $out | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{}'
}
Write-Output $final
exit 0
