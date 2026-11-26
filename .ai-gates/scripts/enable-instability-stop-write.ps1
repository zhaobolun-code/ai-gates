# enable-instability-stop-write.ps1
# 只允许人在 Agent 之外的本机交互终端打开这一轮的迭代停写。
# 临时阈值用参数传入。口令必须从控制台读入。模型调用和空文件都不算。

param(
    [Parameter(Mandatory = $true)][int]$IterationT
)

$ErrorActionPreference = 'Stop'

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

if ($IterationT -lt 3 -or $IterationT -gt 10) {
    Write-Host 'iteration threshold must be an integer from 3 to 10'
    exit 1
}

if (-not (Test-InteractiveConsole)) {
    Write-Host 'must run in an interactive console, not through Agent or redirected input'
    exit 1
}

Write-Host 'Type 打开迭代停写 to confirm (not through Agent):'
$line = [Console]::ReadLine()
if ($line -cne '打开迭代停写') {
    Write-Host 'phrase mismatch; not writing'
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gatesRoot = Split-Path -Parent $scriptDir
$logDir = Join-Path $gatesRoot 'hooks-log'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$path = Join-Path $logDir 'instability-stop-write.json'
$obj = [ordered]@{
    schema = 1
    enabled = $true
    iterationT = $IterationT
    source = 'interactive-console'
    confirmedAtUtc = [DateTime]::UtcNow.ToString('o')
}
$json = $obj | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "iteration stop-write enabled: $path"
exit 0
