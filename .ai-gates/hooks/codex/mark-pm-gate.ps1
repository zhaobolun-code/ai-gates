# mark-pm-gate.ps1 -- Codex
# 2026-11-11：打点已撤。不再写 pm-gate.json，不再输出 token 行。
param(
    [string]$LogDir = ""
)
$LogDir = $LogDir
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
exit 0
