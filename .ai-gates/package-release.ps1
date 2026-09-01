# package-release.ps1 - AI dev pipeline skill release packager
# Collects the files meant to be shared with other projects/teams into a 7z archive under .ai-gates/releases/.
# Usage (from repo root or anywhere):
#   powershell -ExecutionPolicy Bypass -File .ai-gates/package-release.ps1
#   powershell -ExecutionPolicy Bypass -File .ai-gates/package-release.ps1 -Version vX.Y.Z
#
# Packaged scope (see .ai-gates/skills/MAINTAINER.md §目录与同步策略 / project-local-config.md):
#   包顶层 = .ai-gates/（解压到目标项目根即得中央技能库 .ai-gates/）：
#     skills/    all files EXCEPT MAINTAINER.md (maintainer-only); after copy, references/design-patterns.md
#                is overwritten from templates/design-patterns.template.md (empty table)
#                本仓验证在仓库根 design-patterns.project.md（不拷）
#                CHANGELOG.md at pack root IS shipped for public trust
#     scripts/   *.ps1 / *.sh except Chemical-specific (e.g. ci-pressure-manager-gate.ps1)
#     rules/ai-dev-pipeline.mdc
#     hooks.json + hooks/*.ps1 + hooks/codex/*.ps1  (generic Cursor + Codex hooks)
#     codex/hooks.json + codex/config.toml  (Codex wiring, git-tracked central copy)
#     link-platform.ps1/.sh  (new-project one-shot portal creation)
#     METHODOLOGY.md + USER-GUIDE.md + README.md + LICENSE + CHANGELOG.md + PACKAGE-INFO.md
# Excluded: this script itself, project-context.md (含项目口诀), regression-index.yaml, pipeline-*.log,
#           hooks-log/ (runtime log), skills/MAINTAINER.md, scripts/ci-pressure-manager-gate.ps1,
#           lessons-learned.md / lessons-outline.md (错题本, .ai-gates 根, 本就不拷),
#           design-patterns.project.md（本仓验证，.ai-gates 根, 本就不拷）
#           skills/references/design-patterns.md staging 用空表模板覆盖

param(
    [string]$Version,
    # Step 3（2026-08-03）：打包前 validate 绿门。默认强制 validate-pipeline -Strict；
    # -SkipValidate 为显式逃生（维护者签字级），-ValidateScriptPath 供测试注入 stub。
    [switch]$SkipValidate,
    [string]$ValidateScriptPath
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

$skillsDir = Join-Path $repoRoot ".ai-gates/skills"
$scriptsDir = Join-Path $repoRoot ".ai-gates/scripts"
$rulesDir = Join-Path $repoRoot ".ai-gates/rules"

if (-not (Test-Path (Join-Path $skillsDir "CORE.md"))) {
    Write-Error "CORE.md not found under $skillsDir - check script location / repo layout."
    exit 1
}

# 2026-08-04 软连接改造：validate-pipeline 等会经 .cursor/ 传送门读取，先确保传送门就位
if (-not (Test-Path (Join-Path $repoRoot ".cursor/skills/CORE.md"))) {
    Write-Host "Portals missing — running link-platform.ps1 first..." -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot ".ai-gates/link-platform.ps1")
    if ($LASTEXITCODE -ne 0) {
        Write-Error "link-platform.ps1 failed; refusing to package."
        exit 1
    }
}

if (-not $Version) {
    $versionPath = Join-Path $skillsDir "VERSION"
    if (Test-Path -LiteralPath $versionPath) {
        $versionValue = (Get-Content -LiteralPath $versionPath -Encoding UTF8 -Raw).Trim()
        if ($versionValue -match '^\d+\.\d+\.\d+$') { $Version = "v$versionValue" }
    }
}
if (-not $Version) {
    Write-Error "Could not read version from .ai-gates/skills/VERSION. Pass one explicitly: -Version vX.Y.Z"
    exit 1
}
Write-Host "Version: $Version" -ForegroundColor Cyan

# --- locate 7z ---
$sevenZip = $null
$cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
if ($cmd) { $sevenZip = $cmd.Source }
elseif (Test-Path "$env:ProgramFiles\7-Zip\7z.exe") { $sevenZip = "$env:ProgramFiles\7-Zip\7z.exe" }
elseif (Test-Path "${env:ProgramFiles(x86)}\7-Zip\7z.exe") { $sevenZip = "${env:ProgramFiles(x86)}\7-Zip\7z.exe" }
if (-not $sevenZip) {
    Write-Error "7z.exe not found (not on PATH, not in default install dirs). Install 7-Zip: https://www.7-zip.org/"
    exit 1
}
Write-Host "7z: $sevenZip" -ForegroundColor DarkGray

# --- validate 绿门（2026-08-03 Step 3）：打包前强制 validate-pipeline -Strict ---
if (-not $ValidateScriptPath) {
    $ValidateScriptPath = Join-Path $repoRoot ".ai-gates/scripts/validate-pipeline.ps1"
}
if ($SkipValidate) {
    Write-Host "WARNING: -SkipValidate 已指定——跳过 validate-pipeline -Strict（维护者签字级逃生；打包前请自行确认全绿）。" -ForegroundColor Yellow
} else {
    Write-Host "Running validate-pipeline -Strict before packaging..." -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScriptPath -Strict
    $validateExit = $LASTEXITCODE
    if ($validateExit -ne 0) {
        # ErrorActionPreference=Stop 下 Write-Error 会终止脚本，退出码 1——正好是拒绝语义
        Write-Error ("validate-pipeline -Strict FAILED (exit {0})；已拒绝打包。需显式 -SkipValidate 才可继续（维护者签字级逃生）。" -f $validateExit)
        exit 1
    }
    Write-Host "validate-pipeline -Strict: OK" -ForegroundColor Green
}

# --- staging (deleted at the end, never left behind) ---
$stage = Join-Path $repoRoot ".ai-gates/_release_staging"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$stageRoot = Join-Path $stage ".ai-gates"
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

try {
    Write-Host "Copying skills (excluding MAINTAINER.md)..."
    $stageSkills = Join-Path $stageRoot "skills"
    Copy-Item -Path $skillsDir -Destination $stageSkills -Recurse -Force
    Remove-Item -Path (Join-Path $stageSkills "MAINTAINER.md") -Force -ErrorAction SilentlyContinue

    Write-Host "Replacing design-patterns.md with empty-table template (project verification stays in design-patterns.project.md)..."
    $dpTemplate = Join-Path $stageSkills "templates/design-patterns.template.md"
    $dpDest = Join-Path $stageSkills "references/design-patterns.md"
    if (-not (Test-Path -LiteralPath $dpTemplate)) {
        Write-Error "skills/templates/design-patterns.template.md missing; refusing to ship filled 本仓验证 rows."
        exit 1
    }
    Copy-Item -LiteralPath $dpTemplate -Destination $dpDest -Force

    Write-Host "Copying scripts..."
    $stageScripts = Join-Path $stageRoot "scripts"
    New-Item -ItemType Directory -Force -Path $stageScripts | Out-Null
    # NOTE: -Include only filters correctly when -Path ends in a wildcard (classic gotcha)
    # Exclude Chemical/LabSDK-specific CI helpers (not generic Skill surface).
    $scriptExclude = @('ci-pressure-manager-gate.ps1')
    Get-ChildItem -Path (Join-Path $scriptsDir "*") -Include *.ps1, *.sh -File -ErrorAction SilentlyContinue |
        Where-Object { $scriptExclude -notcontains $_.Name } |
        Copy-Item -Destination $stageScripts -Force

    Write-Host "Copying rules/ai-dev-pipeline.mdc..."
    $mdcPath = Join-Path $rulesDir "ai-dev-pipeline.mdc"
    if (Test-Path $mdcPath) {
        $stageRules = Join-Path $stageRoot "rules"
        New-Item -ItemType Directory -Force -Path $stageRules | Out-Null
        Copy-Item -Path $mdcPath -Destination $stageRules -Force
    }

    Write-Host "Copying hooks.json + hooks/*.ps1 + hooks/codex/*.ps1..."
    $hooksJsonPath = Join-Path $repoRoot ".ai-gates/hooks.json"
    $hooksDir = Join-Path $repoRoot ".ai-gates/hooks"
    if (Test-Path $hooksJsonPath) {
        Copy-Item -Path $hooksJsonPath -Destination (Join-Path $stageRoot "hooks.json") -Force
    }
    if (Test-Path $hooksDir) {
        $stageHooks = Join-Path $stageRoot "hooks"
        New-Item -ItemType Directory -Force -Path $stageHooks | Out-Null
        Get-ChildItem -Path (Join-Path $hooksDir "*") -Include *.ps1, *.sh -File -ErrorAction SilentlyContinue |
            Copy-Item -Destination $stageHooks -Force
        $codexHooksDir = Join-Path $hooksDir "codex"
        if (Test-Path $codexHooksDir) {
            $stageCodexHooks = Join-Path $stageHooks "codex"
            New-Item -ItemType Directory -Force -Path $stageCodexHooks | Out-Null
            Get-ChildItem -Path (Join-Path $codexHooksDir "*") -Include *.ps1 -File -ErrorAction SilentlyContinue |
                Copy-Item -Destination $stageCodexHooks -Force
        }
    }

    Write-Host "Copying codex wiring (hooks.json + config.toml)..."
    $stageCodex = Join-Path $stageRoot "codex"
    New-Item -ItemType Directory -Force -Path $stageCodex | Out-Null
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/codex/hooks.json") -Destination $stageCodex -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/codex/config.toml") -Destination $stageCodex -Force

    Write-Host "Copying link-platform.* + docs (README/METHODOLOGY/USER-GUIDE/LICENSE/CHANGELOG)..."
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/link-platform.ps1") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/link-platform.sh") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/README.md") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/METHODOLOGY.md") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/USER-GUIDE.md") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/LICENSE") -Destination $stageRoot -Force
    Copy-Item -Path (Join-Path $repoRoot ".ai-gates/CHANGELOG.md") -Destination $stageRoot -Force

    # 2026-08-04：显式排除 tmp 文件夹（防御性）。中间产物暂存区在 .ai-gates/tmp/，
    # 本就不在打包源内；此步兜底——即使未来 tmp 出现在被拷贝的目录里（如 skills/tmp），
    # 也绝不会混进 7z。
    Write-Host "Excluding tmp folders from package (defensive)..."
    Get-ChildItem -Path $stageRoot -Recurse -Directory -Filter "tmp" -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host ("  exclude: {0}" -f $_.FullName) -ForegroundColor DarkYellow
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }

    Write-Host "Writing PACKAGE-INFO.md (version pointer; MAINTAINER.md not shipped; CHANGELOG.md is)..."
    $packedAt = Get-Date -Format "yyyy-MM-dd"
    $infoLines = @(
        "# AI 开发流水线 Skill - 打包信息",
        "",
        "- 版本：$Version",
        "- 打包日期：$packedAt",
        "- 来源：本包由 .ai-gates/package-release.ps1 从中央技能库生成，仅含随 Skill 分发的通用文件。",
        "",
        "## 本包不含（按设计，维护者专属）",
        "",
        "- MAINTAINER.md：版本升级策略、RC 转正条件、发布检查清单，含源仓库专属的审计记录，不通用",
        "- 项目词条本仓验证：`.ai-gates/design-patterns.project.md` 不进包；进包的 skills/references/design-patterns.md 为空表手续",
        "- 错题本 / 口诀本：.ai-gates/lessons-*.md、.cursor/project-context.md 本就不拷",
        "",
        "## 本包含变更历史",
        "",
        "- CHANGELOG.md：随包分发，便于公开仓/Release 增信与接入方对照版本。",
        "",
        "维护策略与发布清单仍以源仓库 MAINTAINER.md 为准；本包已随附 references/skill-eval-checklist.md（迷你 Harness，可直接用于新项目自测）。",
        "",
        "## 首次接入新项目",
        "",
        "1. 解压本包到目标仓库根：包顶层 = 中央技能库 .ai-gates/ 的内容（skills/、hooks/、scripts/、rules/、codex/、link-platform.* 等），无需额外嵌套",
        "2. 在 Agent 窗口粘贴「项目经理 升级 ai-gates」（=PM upgrade ai-gates），由 Agent 建好传送门（自动建 .cursor/*、.codex、.trae/skills 软连接；手动运行 .ai-gates/link-platform.ps1 亦可，非必需）",
        "3. 先读 .ai-gates/README.md（30 秒看懂 + 安装）→ .ai-gates/USER-GUIDE.md（口令与第一次接入）→ 需要时再读 .ai-gates/METHODOLOGY.md（为什么这么设计）",
        "4. Codex 用户：按源仓库示例创建根级 AGENTS.md（入口路由；本包不含，项目相关），再在 Agent 粘贴「项目经理 初始化」（项目经理=PM，初始化=init，升级=upgrade，检查健康=doctor），填写 project-context 后提需求",
        "",
        "## 预期（避免「不好用」）",
        "",
        "- 不是万能药：每步仍要人验收；须自建项目说明（project-context）",
        "- 入口固定为「项目经理 + 需求」；跳过容易乱",
        "- 复杂问题仍可能失败并归档——那是叫停换路，不是流程坏了",
        "",
        "版本号以 skills/VERSION 为准；变更摘要见 CHANGELOG.md（包根）。"
    )
    Set-Content -Path (Join-Path $stageRoot "PACKAGE-INFO.md") -Value $infoLines -Encoding UTF8

$outFile = Join-Path $repoRoot ".ai-gates/releases/ai_dev_$Version.7z"
$releasesDir = Split-Path $outFile -Parent
if (-not (Test-Path -LiteralPath $releasesDir)) {
    New-Item -ItemType Directory -Force -Path $releasesDir | Out-Null
}
if (Test-Path $outFile) { Remove-Item -Force $outFile }

    Write-Host "Packing to $outFile ..." -ForegroundColor Cyan
    # Archive the contents of $stage (包顶层 = .ai-gates 内容；解压到项目根即得中央技能库)。
    Push-Location $stage
    try {
        & $sevenZip a -t7z -mx=9 $outFile "*" | Out-Null
        $zipExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($zipExit -ne 0) {
        Write-Error "7z packing failed, exit code $zipExit"
        exit 1
    }

    Write-Host ""
    Write-Host "Done: $outFile" -ForegroundColor Green
    Write-Host "Extract at the target project root, then run .ai-gates/link-platform.ps1 (or .sh) to create portals." -ForegroundColor DarkGray
} finally {
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
}
