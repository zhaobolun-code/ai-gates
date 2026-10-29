# check-volume.ps1
# Fail when a role SKILL.md exceeds its recorded line cap,
# or a references/*.md name is absent from reference-routing.md.
# 行数按 UTF-8 计，和编辑器一致。不指定编码时，中文页会被少计。
param()
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path }
$skills = Join-Path $repoRoot ".ai-gates\skills"
$capsPath = Join-Path $scriptDir "fixtures\skill-line-caps.json"
$routePath = Join-Path $skills "references\reference-routing.md"
$failed = 0
$caps = [System.IO.File]::ReadAllText($capsPath, $utf8) | ConvertFrom-Json
foreach ($p in $caps.PSObject.Properties) {
    $skill = Join-Path $skills ($p.Name + "\SKILL.md")
    if (-not (Test-Path -LiteralPath $skill)) {
        Write-Host "FAIL missing $skill"
        $failed++
        continue
    }
    $lines = @(Get-Content -LiteralPath $skill -Encoding UTF8).Count
    $cap = [int]$p.Value
    if ($lines -gt $cap) {
        Write-Host "FAIL $($p.Name) lines=$lines cap=$cap"
        $failed++
    } else {
        Write-Host "PASS $($p.Name) lines=$lines cap=$cap"
    }
}
$route = [System.IO.File]::ReadAllText($routePath, $utf8)
$refs = Get-ChildItem -LiteralPath (Join-Path $skills "references") -Filter "*.md"
foreach ($r in $refs) {
    if ($route.IndexOf($r.Name) -lt 0) {
        Write-Host "FAIL unrouted $($r.Name)"
        $failed++
    }
}
if ($failed -gt 0) { Write-Host "check-volume: FAILED $failed"; exit 1 }
Write-Host "check-volume: OK refs=$($refs.Count)"
exit 0
