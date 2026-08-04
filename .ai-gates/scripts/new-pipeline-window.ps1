# new-pipeline-window.ps1 — 新建执行中窗齐套（未完成/物理口径/已完成索引/证据/.kit-v1）
# Usage (repo root):
#   powershell -NoProfile -File .cursor/scripts/new-pipeline-window.ps1 -Name foo
#   powershell -NoProfile -File .cursor/scripts/new-pipeline-window.ps1 -DocRoot "Assets/Doc/AI流水线" -Name foo
#   powershell -NoProfile -File .cursor/scripts/new-pipeline-window.ps1 -Name foo -Category "执行中"
#
# Defaults: -DocRoot from project-context §执行文档存放约定（否则 Assets/Doc）；-Category 执行中
# Fail-closed: existing window folder → error, no overwrite.

param(
    [string]$DocRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$Category = "执行中"
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git -C $scriptDir rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "../..")).Path
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $dir = Split-Path -Parent $LiteralPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($LiteralPath, $Content, $utf8NoBom)
}

function Resolve-DefaultDocRoot {
    param([string]$RepoRoot)
    $fallback = "Assets/Doc"
    $pc = Join-Path $RepoRoot ".cursor/project-context.md"
    if (-not (Test-Path -LiteralPath $pc)) { return $fallback }
    $raw = Get-Content -LiteralPath $pc -Raw -Encoding UTF8
    if ($raw -match '(?ms)^##\s+执行文档存放约定\s*\r?\n(.*?)(?=^##\s|\z)') {
        $section = $Matches[1]
        if ($section -match '`((?:Assets/)[^`]*?化学文档/压力系统)(?:/\{方案短名\}/|/)?`') {
            return ($Matches[1] -replace '\\', '/').TrimEnd('/')
        }
        if ($section -match '`((?:Assets/)[^`]+?)(?:/\{方案短名\}/|/)?`') {
            return ($Matches[1] -replace '\\', '/').TrimEnd('/')
        }
    }
    return $fallback
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Error "Name is required (方案短名)."
    exit 1
}
if ($Name -match '[\\/:*?\"|]' -or $Name.Contains('<') -or $Name.Contains('>')) {
    Write-Error "Name contains invalid path characters: $Name"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($DocRoot)) {
    $DocRoot = Resolve-DefaultDocRoot -RepoRoot $repoRoot
}
$DocRoot = ($DocRoot -replace '\\', '/').TrimEnd('/')
$Category = $Category.Trim().Trim('/').Trim('\')
if ([string]::IsNullOrWhiteSpace($Category)) {
    Write-Error "Category must not be empty."
    exit 1
}

$planLite = Join-Path $repoRoot ".cursor/skills/templates/plan-lite.md"
$physSpec = Join-Path $repoRoot ".cursor/skills/templates/phys-spec.md"
$indexTpl = Join-Path $repoRoot ".cursor/skills/templates/doc-folder-已完成-索引.md"
foreach ($t in @($planLite, $physSpec, $indexTpl)) {
    if (-not (Test-Path -LiteralPath $t)) {
        Write-Error "Missing template: $t"
        exit 1
    }
}

$windowRel = "$DocRoot/$Category/$Name"
$windowAbs = Join-Path $repoRoot ($windowRel -replace '/', [IO.Path]::DirectorySeparatorChar)
if (Test-Path -LiteralPath $windowAbs) {
    Write-Error "Window already exists (refuse overwrite): $windowRel"
    exit 1
}

$created = (Get-Date).ToString("yyyy-MM-dd")
$doneDir = Join-Path $windowAbs "已完成"
$evidenceDir = Join-Path $windowAbs "证据"
New-Item -ItemType Directory -Force -Path $doneDir | Out-Null
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

# 未完成.md — plan-lite 骨架 + 短名/日期
$plan = Get-Content -LiteralPath $planLite -Raw -Encoding UTF8
$plan = $plan -replace '\[功能名\]', $Name
$plan = $plan -replace '\{方案短名\}', $Name
$plan = $plan -replace 'Assets/Doc/\{主题\}/', "$DocRoot/$Category/"
$plan = $plan -replace '\[3 行以内：要做什么、解决什么现象\]', "[填写目标；创建于 $created]"
# A6：注入黄金场景子集占位（与 plan-lite 链接节措辞对齐；无则写无）
$goldenPlaceholder = '- 相关黄金场景子集：`.ai-gates/verify/golden-scenes.yaml`（无则写无）'
if ($plan -notmatch '相关黄金场景子集') {
    if ($plan -match '(?m)^## 链接\s*\r?\n') {
        $plan = $plan -replace '(?m)(^## 链接\s*\r?\n)', ('$1' + $goldenPlaceholder + "`n")
    }
    else {
        $plan = $goldenPlaceholder + "`n" + $plan
    }
}
$未完成Path = Join-Path $windowAbs "未完成.md"
Write-Utf8NoBomFile -LiteralPath $未完成Path -Content $plan

# 物理口径.md — phys-spec 骨架
$phys = Get-Content -LiteralPath $physSpec -Raw -Encoding UTF8
$phys = $phys -replace '\[功能名\]', $Name
$物理口径Path = Join-Path $windowAbs "物理口径.md"
Write-Utf8NoBomFile -LiteralPath $物理口径Path -Content $phys

# 已完成/_索引.md
$index = Get-Content -LiteralPath $indexTpl -Raw -Encoding UTF8
$索引Path = Join-Path $doneDir "_索引.md"
Write-Utf8NoBomFile -LiteralPath $索引Path -Content $index

# .kit-v1 — LiteralPath 友好；单行文本
$kitPath = Join-Path $windowAbs ".kit-v1"
$kitLine = "kit=v1 name=$Name created=$created"
Write-Utf8NoBomFile -LiteralPath $kitPath -Content ($kitLine + "`n")

Write-Host "Created window kit: $windowRel" -ForegroundColor Green
Write-Host "  未完成.md"
Write-Host "  物理口径.md"
Write-Host "  已完成/_索引.md"
Write-Host "  证据/"
Write-Host "  .kit-v1  ($kitLine)"
exit 0
