# invalidate-instability-event.ps1
# 只允许人在 Agent 之外的本机交互终端作废一条尚未结清的计分事件。
# 口令必须从控制台读入，不能用参数传入。模型调用和空文件都不算。

param(
    [Parameter(Mandatory = $true)][string]$EventId
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

if (-not (Test-InteractiveConsole)) {
    Write-Host 'must run in an interactive console, not through Agent or redirected input'
    exit 1
}

Write-Host 'Type 作废这条事件 to confirm (not through Agent):'
$line = [Console]::ReadLine()
if ($line -cne '作废这条事件') {
    Write-Host 'phrase mismatch; not writing'
    exit 1
}

if ([string]::IsNullOrWhiteSpace($EventId)) {
    Write-Host 'missing event id'
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gatesRoot = Split-Path -Parent $scriptDir
. (Join-Path $gatesRoot 'hooks\instability-ledger.ps1')
$ledgerDir = Join-Path $gatesRoot 'hooks-log'
$result = Add-InstabilityInvalidation -LedgerDir $ledgerDir -EventId $EventId -Writer 'invalidate-script'
if ($result.Refused) {
    Write-Host 'writer refused'
    exit 1
}
if (@($result.Appended).Count -eq 0) {
    Write-Host ("not invalidated: " + [string]$result.Reason)
    exit 1
}
Write-Host 'invalidated'
exit 0
