# post-apply-patch-gate.ps1 -- Codex 版（合并入口）
# PostToolUse hook (matcher: ^apply_patch$) -- 把同一事件的两个观测门合并为一次进程调用：
#   mark-changelog-write.ps1（CHANGELOG 写打点，副作用落盘）+ check-unity-compile.ps1
#   （写后 Unity 编译错误提示，可注入 additionalContext）。
#
# 语义与分开挂载时完全一致：
#   - changelog 打点先跑，保证 changelog-writes.json 副作用无条件发生；
#   - check-unity-compile 输出 context JSON（命中编译错误）或空壳 JSON；输出其最后一行。
#   - stdin 由本入口预读一次缓存到全局，两个子脚本共享同一 payload。

param(
    [string]$LogDir = "",
    [string]$EditorLogPath = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$null = Read-HookStdin   # 预读一次，子脚本走全局缓存

# changelog 打点先跑（副作用必须无条件发生）；输出为空壳，丢弃
$null = & (Join-Path $PSScriptRoot 'mark-changelog-write.ps1') -LogDir $LogDir

# check-unity-compile 后跑：EditorLogPath 仅在显式传入时透传（默认走脚本内置默认路径）
if ($EditorLogPath) {
    $out = @(& (Join-Path $PSScriptRoot 'check-unity-compile.ps1') -LogDir $LogDir -EditorLogPath $EditorLogPath)
} else {
    $out = @(& (Join-Path $PSScriptRoot 'check-unity-compile.ps1') -LogDir $LogDir)
}
$final = $out | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{"hookSpecificOutput":{"hookEventName":"PostToolUse"}}'
}
Write-Output $final
exit 0
