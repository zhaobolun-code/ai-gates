<#
.SYNOPSIS
  ai-gates 一键安装/升级：从发布仓库拉取（或本地缓存）最新包 → 复制库内容到目标项目根
  → 跑 link-platform 建传送门 → 写 .ai-gates/install-info.json（版本/来源/时间）。

.DESCRIPTION
  - -Source：发布仓库路径（默认 D:\Work\ai-gates-publish）或 git URL
  - -Tag：指定 tag；默认 = 源仓库最新 tag（git describe --tags --abbrev=0）
  - -TargetRoot：目标项目根（默认当前目录）
  - -UserCachePath：用户级缓存目录（默认 $HOME\.ai-gates-cache），多项目共用，避免重复拉取
  - -CheckUpdate：只对比 install-info.json 与源仓库最新 tag，输出是否有新版，不改动
  - 复制范围 = 库内容（skills/hooks/scripts/rules/codex、根文档、hooks.json、link-platform.*、
    LICENSE、VERSION 等），不含运行时目录（hooks-log/tmp/verify/releases 项目自留）
  - 幂等：可反复运行；已存在同名文件跳过（不覆盖项目专属文件）

.EXAMPLE
  # 安装到当前项目
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/install-ai-gates.ps1

.EXAMPLE
  # 检查是否有新版（不安装）
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/install-ai-gates.ps1 -CheckUpdate
#>

[CmdletBinding()]
param(
    [string]$Source = 'D:\Work\ai-gates-publish',
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

function Get-LatestTag {
    param([string]$RepoDir)
    $tag = (& git -C $RepoDir describe --tags --abbrev=0 2>$null | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace([string]$tag)) {
        $tag = (& git -C $RepoDir tag --sort=-v:refname 2>$null | Select-Object -First 1)
    }
    return ([string]$tag).Trim()
}

# 解析源：本地目录直接用；URL 则浅克隆到用户缓存
$workRepo = $Source
if (-not (Test-Path -LiteralPath (Join-Path $Source '.git'))) {
    $cloneDir = Join-Path $UserCachePath 'src'
    New-Item -ItemType Directory -Force -Path $cloneDir | Out-Null
    & git clone --depth 1 $Source $cloneDir 2>&1 | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "git clone failed: $Source" }
    $workRepo = $cloneDir
}

$latestTag = Get-LatestTag -RepoDir $workRepo
if (-not $Tag) { $Tag = $latestTag }
if (-not $Tag) { $Tag = 'working-tree' }

$infoPath = Join-Path $TargetRoot ".ai-gates\install-info.json"
if ($CheckUpdate) {
    if (Test-Path -LiteralPath $infoPath) {
        $info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($info.tag -ne $Tag) {
            Write-Host "UPDATE AVAILABLE: installed=$($info.tag) latest=$Tag (source=$Source)"
        } else {
            Write-Host "UP TO DATE: $Tag"
        }
    } else {
        Write-Host "NOT INSTALLED: no .ai-gates/install-info.json under $TargetRoot (latest=$Tag)"
    }
    exit 0
}

$srcLib = Join-Path $workRepo '.ai-gates'
if (-not (Test-Path -LiteralPath $srcLib)) { throw "source .ai-gates missing: $srcLib" }

$targetLib = Join-Path $TargetRoot '.ai-gates'
New-Item -ItemType Directory -Force -Path $targetLib | Out-Null

# 库内容目录（运行时目录 hooks-log/tmp/verify/releases 不复制，项目自留）
foreach ($d in @('skills', 'hooks', 'scripts', 'rules', 'codex')) {
    $src = Join-Path $srcLib $d
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $targetLib -Recurse -Force
    }
}
foreach ($f in @('hooks.json', 'link-platform.ps1', 'link-platform.sh', 'README.md', 'SKILLS.md', 'USER-GUIDE.md', 'METHODOLOGY.md', 'LICENSE')) {
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
