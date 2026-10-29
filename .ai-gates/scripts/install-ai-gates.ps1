<#
.SYNOPSIS
  ai-gates 一键安装/升级：从发布仓库拉取（或本地缓存）最新包 → 复制库内容到目标项目根
  → 跑 link-platform 建/校验传送门 → 写 .ai-gates/install-info.json（版本/来源/时间）。

.DESCRIPTION
  - -Source：git URL（默认官方 https://github.com/zhaobolun-code/ai-gates）或本地仓库/已解压包路径
  - -Tag：指定 tag；默认 = 源仓库最新语义化 tag（URL 用 git ls-remote，本地用 git describe/tag）
  - -TargetRoot：目标项目根（默认当前目录）
  - -UserCachePath：用户级缓存目录（默认 $HOME\.ai-gates-cache），多项目共用，避免重复拉取
  - -CheckUpdate：对比「本地已装版本」（install-info.json tag，缺失则读 skills/VERSION）与源仓库
    最新 tag，输出 UPDATE AVAILABLE / UP TO DATE / NOT INSTALLED，不改动
  - 安全校验：替换前确认源含 .ai-gates/ 且 skills/VERSION 为合法语义化版本，否则拒绝
  - 复制范围 = 库内容（skills/hooks/scripts/rules/codex、根文档、hooks.json、link-platform.*、
    LICENSE、VERSION 等），不含运行时目录（hooks-log/tmp/verify/releases/regression-heat 等项目自留）
  - 幂等：可反复运行；根上的官方入口会覆盖，内容不同时先备份到 tmp

.EXAMPLE
  # 安装/更新到当前项目（默认官方源，取最新 tag）
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/install-ai-gates.ps1

.EXAMPLE
  # 检查是否有新版（不安装）
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/install-ai-gates.ps1 -CheckUpdate
#>

[CmdletBinding()]
param(
    [string]$Source = 'https://github.com/zhaobolun-code/ai-gates',
    [string]$Tag = '',
    [string]$TargetRoot = '',
    [string]$UserCachePath = '',
    [switch]$CheckUpdate,
    [switch]$NoLink
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

if (-not $TargetRoot) { $TargetRoot = (Get-Location).Path }
if (-not $UserCachePath) { $UserCachePath = Join-Path $HOME '.ai-gates-cache' }

. (Join-Path $PSScriptRoot 'official-version.ps1')
function Get-Semver {
    param([string]$Version)
    return Get-OfficialSemver -Version $Version
}

function Compare-Semver {
    param($A, $B)
    if ($null -eq $A -and $null -eq $B) { return 0 }
    if ($null -eq $A) { return -1 }
    if ($null -eq $B) { return 1 }
    if ($A.Major -ne $B.Major) { return [Math]::Sign($A.Major - $B.Major) }
    if ($A.Minor -ne $B.Minor) { return [Math]::Sign($A.Minor - $B.Minor) }
    return [Math]::Sign($A.Patch - $B.Patch)
}

function Get-LatestTag {
    param([string]$RepoDir)
    $tag = (& git -C $RepoDir describe --tags --abbrev=0 2>$null | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace([string]$tag)) {
        $tag = (& git -C $RepoDir tag --sort=-v:refname 2>$null | Select-Object -First 1)
    }
    return ([string]$tag).Trim()
}

function Get-RemoteLatestTag {
    param([string]$RepoUrl)
    $lines = (& git ls-remote --tags $RepoUrl 2>$null | Out-String)
    $best = $null
    $bestVer = $null
    foreach ($line in ($lines -split "`r?`n")) {
        $m = [regex]::Match($line, 'refs/tags/(.+?)(\^\{\})?\s*$')
        if (-not $m.Success) { continue }
        $t = $m.Groups[1].Value
        if ($t -like '*^{}') { continue }
        $v = Get-Semver -Version $t
        if ($null -eq $v) { continue }
        if ($null -eq $bestVer -or (Compare-Semver $v $bestVer) -gt 0) { $best = $t; $bestVer = $v }
    }
    return $best
}

# 无 git / git 失败时的 tag 解析回退：仅支持 GitHub 形式 URL（releases/latest，退回 tags 列表）
function Get-GitHubLatestTagApi {
    param([string]$RepoUrl)
    $m = [regex]::Match($RepoUrl, 'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$')
    if (-not $m.Success) { return '' }
    $owner = $m.Groups[1].Value
    $repo = $m.Groups[2].Value
    $headers = @{ 'User-Agent' = 'ai-gates-installer' }
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/latest" -Headers $headers -ErrorAction Stop
        return [string]$rel.tag_name
    } catch {
        try {
            $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/tags?per_page=20" -Headers $headers -ErrorAction Stop
            $best = $null; $bestVer = $null
            foreach ($t in $tags) {
                $v = Get-Semver -Version ([string]$t.name)
                if ($null -eq $v) { continue }
                if ($null -eq $bestVer -or (Compare-Semver $v $bestVer) -gt 0) { $best = $t.name; $bestVer = $v }
            }
            return $best
        } catch { return '' }
    }
}

# 源类型判定
$isUrl = $Source -match '^(https?://|git@|ssh://)'
$isLocalRepo = (-not $isUrl) -and (Test-Path -LiteralPath (Join-Path $Source '.git'))
$isLocalPack = (-not $isUrl) -and (-not $isLocalRepo) -and (Test-Path -LiteralPath (Join-Path $Source '.ai-gates'))

# 最新 tag：URL 用 ls-remote，本地仓库用 describe/tag；本地已解压包无 tag
$latestTag = ''
if ($isUrl) {
    if (Get-Command git -ErrorAction SilentlyContinue) { $latestTag = Get-RemoteLatestTag -RepoUrl $Source }
    if (-not $latestTag) { $latestTag = Get-GitHubLatestTagApi -RepoUrl $Source }
}
elseif ($isLocalRepo) { $latestTag = Get-LatestTag -RepoDir $Source }

$infoPath = Join-Path $TargetRoot ".ai-gates\install-info.json"
if ($CheckUpdate) {
    # CheckUpdate 只解析 tag，不克隆源（URL 走 ls-remote，零落盘）
    if (-not $Tag) { $Tag = $latestTag }
    if (-not $Tag) { $Tag = 'working-tree' }
    $installed = $null
    if (Test-Path -LiteralPath $infoPath) {
        try {
            $info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $installed = $info.tag
        } catch { }
    }
    $localVersionPath = Join-Path $TargetRoot '.ai-gates\skills\VERSION'
    if (-not $installed -and (Test-Path -LiteralPath $localVersionPath)) {
        $installed = (Get-Content -LiteralPath $localVersionPath -Raw -Encoding UTF8).Trim()
    }
    $instVer = Get-Semver -Version $installed
    $latestVer = Get-Semver -Version $Tag
    if ($null -eq $instVer) {
        Write-Host "NOT INSTALLED: no usable local version under $TargetRoot (latest=$Tag, source=$Source)"
    } elseif ($null -eq $latestVer) {
        Write-Host "CHECK FAILED: cannot parse latest tag '$Tag'; manual check needed"
    } elseif ((Compare-Semver $latestVer $instVer) -gt 0) {
        Write-Host "UPDATE AVAILABLE: local=$installed latest=$Tag (source=$Source)"
    } else {
        Write-Host "UP TO DATE: $installed"
    }
    exit 0
}

# 显式 -Tag 优先。没传才用远端或本地仓库的最新 tag。本地仓库不传 -Tag 时拷工作区，不把 describe 记成已检出的 tag。
$checkoutTag = $latestTag
if (-not [string]::IsNullOrWhiteSpace($Tag)) { $checkoutTag = $Tag.Trim() }
$cloneSource = $isUrl -or ($isLocalRepo -and -not [string]::IsNullOrWhiteSpace($Tag))

# 安装模式：URL 或「本地仓库 + -Tag」按 checkoutTag 浅克隆；git stderr 在 Stop 下会误判为终止错误，故临时降级
if ($isLocalRepo -and [string]::IsNullOrWhiteSpace($Tag)) {
    $workRepo = $Source
} elseif ($cloneSource) {
    $cacheName = if ($checkoutTag) { $checkoutTag } else { 'working' }
    $cloneDir = Join-Path $UserCachePath ("src-" + $cacheName)
    if (Test-Path -LiteralPath $cloneDir) { Remove-Item -LiteralPath $cloneDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $cloneDir -Parent) | Out-Null
    $hasGit = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    if ($hasGit) {
        $prevEp = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            if ($checkoutTag) { $gout = & git clone --depth 1 --branch $checkoutTag $Source $cloneDir 2>&1 | Out-String }
            else { $gout = & git clone --depth 1 $Source $cloneDir 2>&1 | Out-String }
        } finally {
            $ErrorActionPreference = $prevEp
        }
        if ($LASTEXITCODE -ne 0) {
            if (-not $isUrl) { throw "cannot checkout tag '$checkoutTag' from $Source" }
            Write-Host ("WARN git clone failed, fallback to zip: {0}" -f $gout.Trim())
            $hasGit = $false
        }
    }
    if (-not $hasGit) {
        # 无 git / clone 失败 → 下载同一个 tag 的 zip。不再改去最新 tag。
        if (-not $isUrl) { throw "cannot checkout tag '$checkoutTag' from $Source" }
        if (-not $checkoutTag) { throw "cannot resolve latest tag without git for: $Source" }
        $zipUrl = "$Source/archive/refs/tags/$checkoutTag.zip"
        $zipFile = Join-Path $UserCachePath ("ai-gates-$checkoutTag.zip")
        New-Item -ItemType Directory -Force -Path (Split-Path $zipFile -Parent) | Out-Null
        Write-Host "downloading $zipUrl ..."
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing
        Expand-Archive -LiteralPath $zipFile -DestinationPath $cloneDir -Force
        # zip 内顶层形如 ai-gates-<tag>/；把其中的 .ai-gates 提升到 $cloneDir 根
        $inner = Get-ChildItem -LiteralPath $cloneDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        $innerAi = Join-Path $inner.FullName '.ai-gates'
        if ($inner -and (Test-Path -LiteralPath $innerAi)) {
            $finalAi = Join-Path $cloneDir '.ai-gates'
            if (Test-Path -LiteralPath $finalAi) { Remove-Item -LiteralPath $finalAi -Recurse -Force }
            Move-Item -LiteralPath $innerAi -Destination $finalAi
        }
        Remove-Item -LiteralPath $zipFile -Force -ErrorAction SilentlyContinue
    }
    $workRepo = $cloneDir
} elseif ($isLocalPack) {
    # 本地已解压包：直接使用（无 tag，Tag 落到 working-tree）
    $workRepo = $Source
} else {
    throw "source not found / not a git repo / not an extracted pack: $Source"
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
    if ($isLocalRepo) { $Tag = 'working-tree' }
    elseif ($checkoutTag) { $Tag = $checkoutTag }
    else { $Tag = 'working-tree' }
}

# 安全校验：源必须是合法 ai-gates 包（.ai-gates/ + skills/VERSION 语义化版本），否则拒绝替换
$srcLib = Join-Path $workRepo '.ai-gates'
if (-not (Test-Path -LiteralPath $srcLib)) { throw "source does not look like an ai-gates pack (no .ai-gates/): $workRepo" }
$srcVersionFile = Join-Path $srcLib 'skills\VERSION'
if (-not (Test-Path -LiteralPath $srcVersionFile)) { throw "source pack missing skills/VERSION: $srcVersionFile" }
$srcVerRaw = (Get-Content -LiteralPath $srcVersionFile -Raw -Encoding UTF8).Trim()
if ($null -eq (Get-Semver -Version $srcVerRaw)) { throw "source pack VERSION not semver: '$srcVerRaw'" }
if ($Tag -ne 'working-tree' -and -not (Test-TagMatchesPackVersion -Tag $Tag -PackVersion $srcVerRaw)) {
    throw "tag '$Tag' does not match skills/VERSION '$srcVerRaw'; install stopped before replacing the target"
}

$targetLib = Join-Path $TargetRoot '.ai-gates'
New-Item -ItemType Directory -Force -Path $targetLib | Out-Null

function Test-SameFileBytes {
    param([string]$Left, [string]$Right)
    if (-not (Test-Path -LiteralPath $Left) -or -not (Test-Path -LiteralPath $Right)) { return $false }
    return (Get-FileHash -LiteralPath $Left -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Right -Algorithm SHA256).Hash
}

function Backup-ChangedOfficialFile {
    param([string]$SourceFile, [string]$DestFile, [string]$BackupRoot)
    if (-not (Test-Path -LiteralPath $DestFile)) { return }
    if (Test-SameFileBytes -Left $SourceFile -Right $DestFile) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    Copy-Item -LiteralPath $DestFile -Destination (Join-Path $BackupRoot (Split-Path -Leaf $DestFile)) -Force
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

# 库内容目录（运行时目录 hooks-log/tmp/verify/releases 不复制，项目自留）
foreach ($d in @('skills', 'hooks', 'scripts', 'rules', 'codex')) {
    $src = Join-Path $srcLib $d
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $targetLib -Recurse -Force
        Remove-LibraryOrphans -SourceDir $src -DestDir (Join-Path $targetLib $d)
    }
}
$backupRoot = Join-Path $targetLib ("tmp\upgrade-backup-" + (Get-Date -Format 'yyyyMMddHHmmss'))
foreach ($f in @('hooks.json', 'link-platform.ps1', 'link-platform.sh', 'README.md', 'USER-GUIDE.md', 'METHODOLOGY.md', 'LICENSE', 'CHANGELOG.md')) {
    $src = Join-Path $srcLib $f
    if (Test-Path -LiteralPath $src) {
        $dst = Join-Path $targetLib $f
        Backup-ChangedOfficialFile -SourceFile $src -DestFile $dst -BackupRoot $backupRoot
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

if (-not $NoLink) {
    $linkScript = Join-Path $targetLib 'link-platform.ps1'
    if (Test-Path -LiteralPath $linkScript) {
        Push-Location $TargetRoot
        try {
            & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $linkScript 2>&1 | Out-String | Write-Host
        } finally {
            Pop-Location
        }
    }
}

$info = [ordered]@{
    source       = $Source
    tag          = $Tag
    installedAtUtc = [DateTime]::UtcNow.ToString('o')
    targetRoot   = $TargetRoot
}
New-Item -ItemType Directory -Force -Path (Split-Path $infoPath -Parent) | Out-Null
[System.IO.File]::WriteAllText($infoPath, ($info | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "installed: $Tag -> $TargetRoot/.ai-gates (install-info: $infoPath)"
exit 0
