# pre-shell-gate.ps1 -- Cursor beforeShellExecution 合并入口。
# 先 git-safety-check（高危 Git），再 bash-write-gate（显式写文件）。
# 任一门 deny 就输出该 JSON。子脚本用 return，避免 exit 把本进程一起带走。
# stdin 由 Read-HookStdin 缓存，两个子脚本共享。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

$null = Read-HookStdin

$out1 = @(& (Join-Path $PSScriptRoot 'git-safety-check.ps1'))
$deny1 = @($out1 | Where-Object { $_ -match '"permission"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny1) {
    Write-Output $deny1
    return
}

if ($LogDir) {
    $out2 = @(& (Join-Path $PSScriptRoot 'bash-write-gate.ps1') -LogDir $LogDir)
} else {
    $out2 = @(& (Join-Path $PSScriptRoot 'bash-write-gate.ps1'))
}
$deny2 = @($out2 | Where-Object { $_ -match '"permission"\s*:\s*"deny"' } | Select-Object -First 1)
if ($deny2) {
    Write-Output $deny2
    return
}
$final = $out2 | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($final)) {
    $final = '{"permission":"allow"}'
}
Write-Output $final
return
