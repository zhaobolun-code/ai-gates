# test-link-platform.ps1
# 只在临时目录演链接健康与 .codex 迁移。不对真实仓库的 .cursor/.codex 动手。

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$linkScript = Join-Path $scriptDir '..\link-platform.ps1'
$failed = 0

function Assert-Link {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

function New-FakeGatesRepo {
    param([string]$Root, [string]$ConfigText = 'central-config')
    $central = Join-Path $Root '.ai-gates'
    foreach ($d in @('skills', 'hooks', 'scripts', 'rules', 'codex', 'claude', 'claude\agents')) {
        New-Item -ItemType Directory -Path (Join-Path $central $d) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $central 'skills\CORE.md') -Value '# core' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $central 'hooks.json') -Value '{}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $central 'codex\hooks.json') -Value '{}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $central 'codex\config.toml') -Value $ConfigText -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $central 'claude\settings.json') -Value '{}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $central 'claude\mcp.json') -Value '{}' -Encoding UTF8
}

function Invoke-LinkPlatform {
    param([string]$Root, [switch]$AcceptCodexMigration)
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $linkScript, '-RepoRoot', $Root)
    if ($AcceptCodexMigration) { $argList += '-AcceptCodexMigration' }
    $out = & (Get-Process -Id $PID).Path @argList 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

$tmpStale = Join-Path ([System.IO.Path]::GetTempPath()) ('link-stale-' + [Guid]::NewGuid().ToString('N'))
$tmpCodex = Join-Path ([System.IO.Path]::GetTempPath()) ('link-codex-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmpStale -Force | Out-Null
    New-FakeGatesRepo -Root $tmpStale
    $wrong = Join-Path $tmpStale 'wrong-skills'
    New-Item -ItemType Directory -Path $wrong -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmpStale '.cursor') -Force | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $tmpStale '.cursor\skills') -Target $wrong | Out-Null
    $r = Invoke-LinkPlatform -Root $tmpStale
    Assert-Link 'stale link output contains STALE' ($r.Output -match 'STALE') $r.Output
    Assert-Link 'stale skills is not OK linked' ($r.Output -notmatch 'OK \(linked\): \.cursor/skills') $r.Output

    New-Item -ItemType Directory -Path $tmpCodex -Force | Out-Null
    New-FakeGatesRepo -Root $tmpCodex -ConfigText 'central-config'
    $oldCodex = Join-Path $tmpCodex '.codex'
    New-Item -ItemType Directory -Path $oldCodex -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $oldCodex 'config.toml') -Value 'old-config' -Encoding UTF8
    $r = Invoke-LinkPlatform -Root $tmpCodex
    $oldItem = Get-Item -LiteralPath $oldCodex -Force
    $isReparse = [bool]($oldItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
    Assert-Link 'without accept, old .codex dir remains' ((Test-Path -LiteralPath $oldCodex) -and -not $isReparse) "reparse=$isReparse"
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $tmpCodex '.ai-gates\tmp') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'codex-migrate-backup-*' })
    Assert-Link 'without accept, backup exists' ($backups.Count -ge 1) "count=$($backups.Count)"
    $bakFile = Join-Path $backups[0].FullName 'config.toml'
    Assert-Link 'backup holds old content' ((Test-Path -LiteralPath $bakFile) -and ((Get-Content -LiteralPath $bakFile -Raw) -match 'old-config')) $bakFile
    $centralCfg = Get-Content -LiteralPath (Join-Path $tmpCodex '.ai-gates\codex\config.toml') -Raw
    Assert-Link 'central config unchanged without accept' ($centralCfg -match 'central-config') $centralCfg

    $r = Invoke-LinkPlatform -Root $tmpCodex -AcceptCodexMigration
    $newItem = Get-Item -LiteralPath $oldCodex -Force
    $nowReparse = [bool]($newItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
    Assert-Link 'with accept, .codex becomes a link' $nowReparse "attrs=$($newItem.Attributes)"
    $centralAfter = Get-Content -LiteralPath (Join-Path $tmpCodex '.ai-gates\codex\config.toml') -Raw
    Assert-Link 'central config still original after accept' ($centralAfter -match 'central-config' -and $centralAfter -notmatch 'old-config') $centralAfter
    $bakAfter = Get-ChildItem -LiteralPath (Join-Path $tmpCodex '.ai-gates\tmp') -Directory | Where-Object { $_.Name -like 'codex-migrate-backup-*' } | ForEach-Object { Join-Path $_.FullName 'config.toml' } | Where-Object { Test-Path -LiteralPath $_ }
    $bakHit = $false
    foreach ($b in $bakAfter) {
        if ((Get-Content -LiteralPath $b -Raw) -match 'old-config') { $bakHit = $true }
    }
    Assert-Link 'backup still has old content after accept' $bakHit ($bakAfter -join ',')
} finally {
    Remove-Item -LiteralPath $tmpStale -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpCodex -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 1 }
Write-Host 'link-platform: all passed'
exit 0
