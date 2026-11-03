# install-tree.ps1
# 安装覆盖 skills/hooks/scripts/rules/codex 前的备份、清单与 VERSION 核验。
# 由 install-ai-gates.ps1 点源。

function Get-FileSha256Hex {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-RelativeTreePath {
    param([string]$Root, [string]$FullName)
    $root = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($FullName)
    $rel = $full.Substring($root.Length).TrimStart('\', '/')
    return ($rel -replace '\\', '/')
}

function Get-LibraryFileList {
    param([string]$LibRoot, [string[]]$Dirs)
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($d in $Dirs) {
        $dir = Join-Path $LibRoot $d
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $root = (Resolve-Path -LiteralPath $dir).Path
        Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = (Join-Path $d (Get-RelativeTreePath -Root $root -FullName $_.FullName)) -replace '\\', '/'
            $items.Add([pscustomobject]@{ Rel = $rel; Hash = (Get-FileSha256Hex $_.FullName); FullName = $_.FullName }) | Out-Null
        }
    }
    return @($items | Sort-Object Rel)
}

function Write-LibraryManifest {
    param([string]$LibRoot, [string[]]$Dirs, [string]$OutFile)
    $parent = Split-Path -Parent $OutFile
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($it in (Get-LibraryFileList -LibRoot $LibRoot -Dirs $Dirs)) {
        $lines.Add(("{0}`t{1}" -f $it.Rel, $it.Hash)) | Out-Null
    }
    $text = ($lines -join "`n")
    if ($text) { $text = $text + "`n" }
    [System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding($true)))
}

function Backup-LibraryFile {
    param([string]$SourceFile, [string]$BackupRoot, [string]$Rel)
    $dest = Join-Path $BackupRoot ($Rel -replace '/', '\')
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Copy-Item -LiteralPath $SourceFile -Destination $dest -Force
}

function Backup-ChangedAndOrphanLibraryFiles {
    param([string]$SourceDir, [string]$DestDir, [string]$BackupRoot, [string]$RelativePrefix)
    if (-not (Test-Path -LiteralPath $DestDir)) { return }
    $srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')
    $dstRoot = (Resolve-Path -LiteralPath $DestDir).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $DestDir -Recurse -File -Force | ForEach-Object {
        $relInside = $_.FullName.Substring($dstRoot.Length).TrimStart('\')
        $srcFile = Join-Path $srcRoot $relInside
        $rel = (($RelativePrefix + '/' + ($relInside -replace '\\', '/')) -replace '\\', '/')
        if (-not (Test-Path -LiteralPath $srcFile)) {
            Backup-LibraryFile -SourceFile $_.FullName -BackupRoot $BackupRoot -Rel $rel
        } elseif ((Get-FileSha256Hex $_.FullName) -ne (Get-FileSha256Hex $srcFile)) {
            Backup-LibraryFile -SourceFile $_.FullName -BackupRoot $BackupRoot -Rel $rel
        }
    }
}

function Remove-LibraryOrphans {
    param([string]$SourceDir, [string]$DestDir)
    if (-not (Test-Path -LiteralPath $DestDir)) { return }
    $srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')
    $dstRoot = (Resolve-Path -LiteralPath $DestDir).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $DestDir -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($dstRoot.Length).TrimStart('\')
        $srcFile = Join-Path $srcRoot $rel
        if (-not (Test-Path -LiteralPath $srcFile)) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
}

function Install-LibraryTree {
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$BackupRoot,
        [string]$RelativePrefix
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) { return }
    Backup-ChangedAndOrphanLibraryFiles -SourceDir $SourceDir -DestDir $DestDir -BackupRoot $BackupRoot -RelativePrefix $RelativePrefix
    $parent = Split-Path -Parent $DestDir
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $SourceDir -Destination $parent -Recurse -Force
    Remove-LibraryOrphans -SourceDir $SourceDir -DestDir $DestDir
}

function Assert-SkillsVersionCopied {
    param([string]$SourceVersionFile, [string]$DestVersionFile)
    if (-not (Test-Path -LiteralPath $SourceVersionFile)) {
        throw "source skills/VERSION missing: $SourceVersionFile"
    }
    if (-not (Test-Path -LiteralPath $DestVersionFile)) {
        throw "dest skills/VERSION missing after copy: $DestVersionFile"
    }
    $src = [System.IO.File]::ReadAllText($SourceVersionFile)
    $dst = [System.IO.File]::ReadAllText($DestVersionFile)
    if ($src -ne $dst) {
        throw "skills/VERSION mismatch after copy: source and dest text differ"
    }
}
