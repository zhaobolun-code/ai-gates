# mark-pm-gate.ps1 -- Copilot CLI
# 2026-11-11：打点已撤。不再写 pm-gate.json。stdout 固定是 {}。
param(
    [string]$LogDir = ""
)
$LogDir = $LogDir
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
Write-Output '{}'
exit 0
