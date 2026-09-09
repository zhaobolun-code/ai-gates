# check-skill-growth.ps1 — skill/rule growth gate vs baseline snapshot.
# Thresholds hardcoded: line >15%, byte >20%, net added lines >80.
# Structure bad = missing markdown "## " or yaml fence count not even.
# Fail: exit 2, copy Target into FailDir, do not write Baseline / source of truth.
# Success: exit 0, do not modify Baseline.
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [Parameter(Mandatory = $true)]
    [string]$Baseline,
    [Parameter(Mandatory = $true)]
    [string]$FailDir
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

function Resolve-Abs([string]$p) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
}

$Target = Resolve-Abs $Target
$Baseline = Resolve-Abs $Baseline
$FailDir = Resolve-Abs $FailDir

if (-not (Test-Path -LiteralPath $Target)) { throw "missing Target: $Target" }
if (-not (Test-Path -LiteralPath $Baseline)) { throw "missing Baseline: $Baseline" }

$tgtBytes = [System.IO.File]::ReadAllBytes($Target)
$baseBytes = [System.IO.File]::ReadAllBytes($Baseline)
$tgtText = [System.IO.File]::ReadAllText($Target, $utf8)
$baseText = [System.IO.File]::ReadAllText($Baseline, $utf8)

$tgtLines = [System.IO.File]::ReadAllLines($Target, $utf8)
$baseLines = [System.IO.File]::ReadAllLines($Baseline, $utf8)
$tgtN = @($tgtLines).Count
$baseN = @($baseLines).Count

$lineGrowth = 0.0
if ($baseN -eq 0) {
    if ($tgtN -gt 0) { $lineGrowth = 1.0 }
} else {
    $lineGrowth = ([double]($tgtN - $baseN)) / [double]$baseN
}
$byteGrowth = 0.0
if ($baseBytes.Length -eq 0) {
    if ($tgtBytes.Length -gt 0) { $byteGrowth = 1.0 }
} else {
    $byteGrowth = ([double]($tgtBytes.Length - $baseBytes.Length)) / [double]$baseBytes.Length
}
$netAdded = $tgtN - $baseN

$structBad = $false
if ($tgtText -notmatch '(?m)^## ') { $structBad = $true }
$fenceCount = ([regex]::Matches($tgtText, '(?m)^```')).Count
if (($fenceCount % 2) -ne 0) { $structBad = $true }

$fail = $false
$why = New-Object System.Collections.Generic.List[string]
if ($lineGrowth -gt 0.15) { $fail = $true; $why.Add("line>15% ($lineGrowth)") }
if ($byteGrowth -gt 0.20) { $fail = $true; $why.Add("byte>20% ($byteGrowth)") }
if ($netAdded -gt 80) { $fail = $true; $why.Add("net>80 ($netAdded)") }
if ($structBad) { $fail = $true; $why.Add("structure-bad missing ## or odd yaml fence") }

Write-Host ("targetLines=" + $tgtN + " baselineLines=" + $baseN + " netAdded=" + $netAdded)
Write-Host ("lineGrowth=" + $lineGrowth + " byteGrowth=" + $byteGrowth + " fences=" + $fenceCount)

if ($fail) {
    if (-not (Test-Path -LiteralPath $FailDir)) {
        New-Item -ItemType Directory -Path $FailDir -Force | Out-Null
    }
    $dest = Join-Path $FailDir ([IO.Path]::GetFileName($Target))
    Copy-Item -LiteralPath $Target -Destination $dest -Force
    Write-Host ("FAIL copied to FailDir: " + $dest + " reasons=" + ($why -join "; "))
    exit 2
}

Write-Host "PASS growth within threshold; Baseline unchanged"
exit 0
