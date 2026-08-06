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
  - 幂等：可反复运行；已存在同名根文档跳过（不覆盖项目专属文件）

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

function Get-Semver {
    param([string]$Version)
    $v = ([string]$Version).Trim() -replace '^[vV]', ''
    $m = [regex]::Match($v, '^(\d+)\.(\d+)\.(\d+)')
    if (-not $m.Success) { return $null }
    return [pscustomobject]@{ Major = [int]$m.Groups[1].Value; Minor = [int]$m.Groups[2].Value; Patch = [int]$m.Groups[3].Value; Raw = $v }
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

# 源类型判定
$isUrl = $Source -match '^(https?://|git@|ssh://)'
$isLocalRepo = (-not $isUrl) -and (Test-Path -LiteralPath (Join-Path $Source '.git'))
$isLocalPack = (-not $isUrl) -and (-not $isLocalRepo) -and (Test-Path -LiteralPath (Join-Path $Source '.ai-gates'))

# 最新 tag：URL 用 ls-remote，本地仓库用 describe/tag；本地已解压包无 tag
$latestTag = ''
if ($isUrl) { $latestTag = Get-RemoteLatestTag -RepoUrl $Source }
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

# 安装模式：解析源（URL 先取最新 tag 再浅克隆；git stderr 在 Stop 下会误判为终止错误，故临时降级）
if ($isLocalRepo) {
    $workRepo = $Source
} elseif ($isUrl) {
    $cloneDir = Join-Path $UserCachePath ("src-" + $(if ($latestTag) { $latestTag } else { 'working' }))
    if (Test-Path -LiteralPath $cloneDir) { Remove-Item -LiteralPath $cloneDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $cloneDir -Parent) | Out-Null
    $prevEp = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($latestTag) { $gout = & git clone --depth 1 --branch $latestTag $Source $cloneDir 2>&1 | Out-String }
        else { $gout = & git clone --depth 1 $Source $cloneDir 2>&1 | Out-String }
    } finally {
        $ErrorActionPreference = $prevEp
    }
    if ($LASTEXITCODE -ne 0) { throw "git clone failed: $Source`n$gout" }
    $workRepo = $cloneDir
} elseif ($isLocalPack) {
    # 本地已解压包：直接使用（无 tag，Tag 落到 working-tree）
    $workRepo = $Source
} else {
    throw "source not found / not a git repo / not an extracted pack: $Source"
}

if (-not $Tag) { $Tag = $latestTag }
if (-not $Tag) { $Tag = 'working-tree' }

# 安全校验：源必须是合法 ai-gates 包（.ai-gates/ + skills/VERSION 语义化版本），否则拒绝替换
$srcLib = Join-Path $workRepo '.ai-gates'
if (-not (Test-Path -LiteralPath $srcLib)) { throw "source does not look like an ai-gates pack (no .ai-gates/): $workRepo" }
$srcVersionFile = Join-Path $srcLib 'skills\VERSION'
if (-not (Test-Path -LiteralPath $srcVersionFile)) { throw "source pack missing skills/VERSION: $srcVersionFile" }
$srcVerRaw = (Get-Content -LiteralPath $srcVersionFile -Raw -Encoding UTF8).Trim()
if ($null -eq (Get-Semver -Version $srcVerRaw)) { throw "source pack VERSION not semver: '$srcVerRaw'" }

$targetLib = Join-Path $TargetRoot '.ai-gates'
New-Item -ItemType Directory -Force -Path $targetLib | Out-Null

# 库内容目录（运行时目录 hooks-log/tmp/verify/releases 不复制，项目自留）
foreach ($d in @('skills', 'hooks', 'scripts', 'rules', 'codex')) {
    $src = Join-Path $srcLib $d
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $targetLib -Recurse -Force
    }
}
foreach ($f in @('hooks.json', 'link-platform.ps1', 'link-platform.sh', 'README.md', 'USER-GUIDE.md', 'METHODOLOGY.md', 'LICENSE', 'CHANGELOG.md')) {
    $src = Join-Path $srcLib $f
    if (Test-Path -LiteralPath $src) {
        $dst = Join-Path $targetLib $f
        if (-not (Test-Path -LiteralPath $dst)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    }
}

if (-not $NoLink) {
    $linkScript = Join-Path $targetLib 'link-platform.ps1'
    if (Test-Path -LiteralPath $linkScript) {
        Push-Location $TargetRoot
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $linkScript 2>&1 | Out-String | Write-Host
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
