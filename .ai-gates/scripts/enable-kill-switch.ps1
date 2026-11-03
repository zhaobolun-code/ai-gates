# enable-kill-switch.ps1
# 只允许人在 Agent 之外的本机交互终端启用 PM 门禁 kill switch。
# 不接受任何参数；口令必须从控制台读入，不能用参数传入。
# 空文件和 Agent 写入不算确认。

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

Write-Host 'Type ENABLE KILL SWITCH to confirm (not through Agent):'
$line = [Console]::ReadLine()
if ($line -cne 'ENABLE KILL SWITCH') {
    Write-Host 'phrase mismatch; not writing'
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gatesRoot = Split-Path -Parent $scriptDir
$logDir = Join-Path $gatesRoot 'hooks-log'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$path = Join-Path $logDir 'pm-gate-disabled'
$obj = [ordered]@{
    schema = 1
    source = 'interactive-console'
    phrase = 'ENABLE KILL SWITCH'
    host = [string]$Host.Name
    confirmedAtUtc = [DateTime]::UtcNow.ToString('o')
}
$json = $obj | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "kill switch enabled: $path"
exit 0
