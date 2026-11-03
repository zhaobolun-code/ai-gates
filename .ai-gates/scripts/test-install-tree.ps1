# test-install-tree.ps1
# 只在临时目录证明：内容不同的文件被备份；源包没有的目标文件在删除前被备份；VERSION 不一致会失败。
# 不对真实仓库跑完整安装。

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'install-tree.ps1')

$failed = 0
function Assert-Install {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('install-tree-' + [Guid]::NewGuid().ToString('N'))
try {
    $srcLib = Join-Path $tmp 'src\.ai-gates'
    $dstLib = Join-Path $tmp 'dst\.ai-gates'
    New-Item -ItemType Directory -Path (Join-Path $srcLib 'skills') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dstLib 'skills') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $srcLib 'skills\VERSION') -Value "1.0.0`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $srcLib 'skills\keep.md') -Value 'new-keep' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $dstLib 'skills\VERSION') -Value "1.0.0`n" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $dstLib 'skills\keep.md') -Value 'old-keep' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $dstLib 'skills\orphan.md') -Value 'orphan-old' -Encoding UTF8

    $backup = Join-Path $dstLib 'tmp\upgrade-backup-test'
    Write-LibraryManifest -LibRoot $dstLib -Dirs @('skills') -OutFile (Join-Path $backup 'manifest-before.txt')
    Install-LibraryTree -SourceDir (Join-Path $srcLib 'skills') -DestDir (Join-Path $dstLib 'skills') -BackupRoot $backup -RelativePrefix 'skills'
    Write-LibraryManifest -LibRoot $dstLib -Dirs @('skills') -OutFile (Join-Path $backup 'manifest-after.txt')

    $bakKeep = Join-Path $backup 'skills\keep.md'
    Assert-Install 'changed file is backed up' ((Test-Path -LiteralPath $bakKeep) -and ((Get-Content -LiteralPath $bakKeep -Raw) -match 'old-keep')) $bakKeep
    $dstKeep = Get-Content -LiteralPath (Join-Path $dstLib 'skills\keep.md') -Raw
    Assert-Install 'changed file is overwritten' ($dstKeep -match 'new-keep') $dstKeep
    $bakOrphan = Join-Path $backup 'skills\orphan.md'
    Assert-Install 'orphan is backed up before delete' ((Test-Path -LiteralPath $bakOrphan) -and ((Get-Content -LiteralPath $bakOrphan -Raw) -match 'orphan-old')) $bakOrphan
    Assert-Install 'orphan is removed from dest' (-not (Test-Path -LiteralPath (Join-Path $dstLib 'skills\orphan.md'))) ''
    Assert-Install 'before manifest exists' (Test-Path -LiteralPath (Join-Path $backup 'manifest-before.txt')) ''
    Assert-Install 'after manifest exists' (Test-Path -LiteralPath (Join-Path $backup 'manifest-after.txt')) ''

    Assert-SkillsVersionCopied -SourceVersionFile (Join-Path $srcLib 'skills\VERSION') -DestVersionFile (Join-Path $dstLib 'skills\VERSION')
    Set-Content -LiteralPath (Join-Path $dstLib 'skills\VERSION') -Value "9.9.9`n" -Encoding UTF8
    $threw = $false
    try {
        Assert-SkillsVersionCopied -SourceVersionFile (Join-Path $srcLib 'skills\VERSION') -DestVersionFile (Join-Path $dstLib 'skills\VERSION')
    } catch {
        $threw = $true
    }
    Assert-Install 'version mismatch throws' $threw 'did not throw'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 1 }
Write-Host 'install-tree: all passed'
exit 0
