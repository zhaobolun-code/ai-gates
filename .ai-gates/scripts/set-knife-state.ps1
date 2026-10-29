param(
    [Parameter(Mandatory = $true)][string]$Window,
    [Parameter(Mandatory = $true)][string]$Acceptance,
    [Parameter(Mandatory = $true)][string]$Symptom,
    [Parameter(Mandatory = $true)][string]$Lane,
    [switch]$NeedsHumanTest,
    [string]$StatePath = ""
)
$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\hooks\gate-decision.ps1")
# StatePath 不采用。只写本仓库固定的 knife-state.json。
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$StatePath = Join-Path $root ".ai-gates\hooks-log\knife-state.json"
$dir = Split-Path -Parent $StatePath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$existing = ""
if (Test-Path -LiteralPath $StatePath) {
    try { $existing = [System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8) } catch { $existing = "" }
}
$next = Update-KnifeState -ExistingJson $existing -Window $Window -Acceptance $Acceptance -Symptom $Symptom -Lane $Lane -NeedsHumanTest ([bool]$NeedsHumanTest)
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($StatePath, ($next | ConvertTo-Json -Compress), $utf8)
exit 0
