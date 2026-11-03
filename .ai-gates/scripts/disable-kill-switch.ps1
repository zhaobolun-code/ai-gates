# disable-kill-switch.ps1
# 只允许人在 Agent 之外的本机交互终端关闭 PM 门禁 kill switch。
# 不接受任何参数；口令必须从控制台读入，不能用参数传入。
# 文件本来没有也算成功。

$ErrorActionPreference = 'Stop'
if ($args.Count -gt 0) {
    Write-Host 'this script accepts no parameters'
    exit 1
}

function Test-InteractiveConsole {
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    try {
        if ([Console]::IsInputRedirected) { return $false }
    } catch {
        return $false
    }
    return $true
}

if (-not (Test-InteractiveConsole)) {
    Write-Host 'must run in an interactive console, not through Agent or redirected input'
    exit 1
}

Write-Host 'Type DISABLE KILL SWITCH to confirm (not through Agent):'
$line = [Console]::ReadLine()
if ($line -cne 'DISABLE KILL SWITCH') {
    Write-Host 'phrase mismatch; not deleting'
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gatesRoot = Split-Path -Parent $scriptDir
$path = Join-Path $gatesRoot 'hooks-log\pm-gate-disabled'
if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force
    Write-Host "kill switch disabled: $path"
} else {
    Write-Host "kill switch already absent: $path"
}
exit 0
