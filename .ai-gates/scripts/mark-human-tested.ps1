# 把 knife-state.json 的 awaitingHumanTest 翻成 false。
# 证据文件里必须包含状态里的现象句。对不上就不改文件。
param(
    [string]$StatePath = "",
    [string]$EvidencePath = ""
)
$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\hooks\gate-decision.ps1")
# StatePath 不采用。现象句包含只防止记错现象，不证明操作者是人。
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { exit 1 }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$StatePath = Join-Path $root ".ai-gates\hooks-log\knife-state.json"
if (-not (Test-Path -LiteralPath $StatePath) -or -not (Test-Path -LiteralPath $EvidencePath)) { exit 1 }
$stateRaw = [System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8)
$evidence = [System.IO.File]::ReadAllText($EvidencePath, [System.Text.Encoding]::UTF8)
try { $state = $stateRaw | ConvertFrom-Json -ErrorAction Stop } catch { exit 1 }
if (-not (Test-HumanTestEvidence -Symptom ([string]$state.symptom) -EvidenceText $evidence)) { exit 1 }
$state.awaitingHumanTest = $false
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($StatePath, ($state | ConvertTo-Json -Compress), $utf8)
exit 0
