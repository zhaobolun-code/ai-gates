# pm-init.ps1 — PM 初始化：探测 + 引导式安全创建（半自动）
# Usage (repo root):
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -DocRoot ".ai-gates/Doc"
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -InstallCodeGraph
#
# Default is probe-only (zero side effects). -Apply runs guided init:
#   1) create missing project-context (via init-project-context.ps1, never overwrites)
#   2) create missing doc root dirs
#   3) print "next-step checklist": rules alignment (link-trae-skills) + optional CodeGraph.
# -InstallCodeGraph only after explicit user consent. No npm involved.

param(
    [switch]$Apply,
    [string]$DocRoot = ".ai-gates/Doc",
    [switch]$InstallCodeGraph
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

function Write-Status([string]$Name, [string]$State, [string]$Detail = "") {
    $line = "[$Name] $State"
    if ($Detail) { $line = "$line — $Detail" }
    Write-Host $line
}

$ctx = Join-Path $repoRoot ".cursor/project-context.md"
$yaml = Join-Path $repoRoot ".ai-gates/regression-index.yaml"
$codegraphDir = Join-Path $repoRoot ".codegraph"
$docAbs = Join-Path $repoRoot $DocRoot
$weeklyAbs = Join-Path $docAbs "Weekly"
$initScript = Join-Path $scriptDir "init-project-context.ps1"
# rules 对齐探测（仅 -Apply 清单使用；probe 模式零副作用）
$traeSkills = Join-Path $repoRoot ".trae/skills"
$traeRules = Join-Path $repoRoot ".trae/rules/ai-dev-pipeline.md"

Write-Host "=== PM Init probe ===" -ForegroundColor Cyan
Write-Host "repo: $repoRoot"

$ctxState = if (Test-Path -LiteralPath $ctx) { "present" } else { "missing" }
Write-Status "project-context" $ctxState $ctx

$yamlState = if (Test-Path -LiteralPath $yaml) { "present" } else { "missing" }
Write-Status "regression-index.yaml" $yamlState $yaml

$docState = if (Test-Path -LiteralPath $docAbs) { "present" } else { "missing" }
Write-Status "doc-root" $docState $DocRoot

$cgCli = Get-Command codegraph -ErrorAction SilentlyContinue
$cgDirOk = Test-Path -LiteralPath $codegraphDir
if ($cgDirOk -and $cgCli) { Write-Status "CodeGraph" "ready" ".codegraph/ + CLI" }
elseif ($cgDirOk) { Write-Status "CodeGraph" "partial" ".codegraph/ exists; CLI or MCP may need reload" }
elseif ($cgCli) { Write-Status "CodeGraph" "partial" "CLI found; run: codegraph init" }
else { Write-Status "CodeGraph" "missing" "need: codegraph install --platform cursor && codegraph init" }

$policyScript = Join-Path $scriptDir "check-hooks-policy.ps1"
if (Test-Path -LiteralPath $policyScript) {
    . $policyScript
    $rt = Get-HooksRuntimeStatus
    if ($rt.Code -eq "hooks_not_wired_no_pwsh") {
        Write-Status "machine-hooks" "not-wired" "hooks_not_wired_no_pwsh — no pwsh; do not report hooks wired"
    } else {
        Write-Status "machine-hooks" "interpreter-ok" "$($rt.Code); interpreter available ≠ this client wired (Trae=soft)"
    }
} else {
    Write-Status "machine-hooks" "unknown" "check-hooks-policy.ps1 missing"
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "Probe only. Re-run with -Apply to create missing context/doc dirs." -ForegroundColor DarkGray
    Write-Host "After user consent, add -InstallCodeGraph to attempt CodeGraph setup." -ForegroundColor DarkGray
    exit 0
}

Write-Host ""
Write-Host "=== Apply ===" -ForegroundColor Cyan

# rules 对齐探测（只读，不写）：.trae/skills 是否已联接 .cursor/skills；.trae/rules 是否已落位
$traeSkillsLinked = $false
if (Test-Path -LiteralPath $traeSkills) {
    $item = Get-Item -LiteralPath $traeSkills -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        # PS 5.1（.NET Framework）下 $item.Target 不存在；Resolve-Path 对 junction 会解析到目标
        $t = (Resolve-Path -LiteralPath $traeSkills -ErrorAction SilentlyContinue).Path
        if ($t -eq (Join-Path $repoRoot ".cursor\skills") -or $t -like "*\.cursor\skills" -or $t -eq (Join-Path $repoRoot ".ai-gates\skills") -or $t -like "*\.ai-gates\skills") { $traeSkillsLinked = $true }
    }
}
$traeRulesOk = Test-Path -LiteralPath $traeRules
$rulesAligned = $traeSkillsLinked -and $traeRulesOk

if ($ctxState -eq "missing") {
    if (-not (Test-Path -LiteralPath $initScript)) {
        Write-Error "Missing $initScript"
        exit 1
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $initScript
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "Skip context create (already exists)." -ForegroundColor DarkGray
}

if (-not (Test-Path -LiteralPath $docAbs)) {
    New-Item -ItemType Directory -Force -Path $docAbs | Out-Null
    Write-Host "Created doc root: $DocRoot" -ForegroundColor Green
} else {
    Write-Host "Doc root exists: $DocRoot" -ForegroundColor DarkGray
}
if (-not (Test-Path -LiteralPath $weeklyAbs)) {
    New-Item -ItemType Directory -Force -Path $weeklyAbs | Out-Null
    Write-Host "Created: $DocRoot/Weekly" -ForegroundColor Green
}

if ($DocRoot -ne ".ai-gates/Doc" -and $DocRoot -ne ".ai-gates\Doc") {
    Write-Host "NOTE: DocRoot='$DocRoot' differs from default .ai-gates/Doc — Agent must update project-context doc path section." -ForegroundColor Yellow
}

if ($InstallCodeGraph) {
    Write-Host ""
    Write-Host "=== CodeGraph install ===" -ForegroundColor Cyan
    if (-not $cgCli) {
        Write-Host "codegraph CLI not on PATH. Manual install required:" -ForegroundColor Yellow
        Write-Host "  codegraph install --platform cursor"
        Write-Host "  codegraph init"
        Write-Host "Then reload Cursor window / check .cursor/mcp.json" -ForegroundColor DarkGray
        exit 2
    }
    if (-not $cgDirOk) {
        Write-Host "Running: codegraph init"
        & codegraph init
        if ($LASTEXITCODE -ne 0) {
            Write-Host "codegraph init failed (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "Skip codegraph init (.codegraph/ exists)." -ForegroundColor DarkGray
    }
    Write-Host "Try: codegraph install --platform cursor"
    & codegraph install --platform cursor
    if ($LASTEXITCODE -ne 0) {
        Write-Host "codegraph install returned $LASTEXITCODE — check MCP / reload Cursor." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== 下一步清单（引导式 init） ===" -ForegroundColor Cyan
# 1. project-context（-Apply 已自动创建/跳过；幂等不覆盖）
$ctxText = if ($ctxState -eq "missing") { "已调用 init-project-context.ps1 生成（不覆盖已有文件）" } else { "已存在，跳过（不覆盖）" }
Write-Host "1. [done] init-project-context：.cursor/project-context.md $ctxText；打开填写技术栈 / Express 升级表 / 回归索引。"
# 2. rules 对齐（提示/调用 link-trae-skills；只做联接不做内容改写）
if ($rulesAligned) {
    Write-Host "2. [done] rules 对齐：.trae/skills 已联接 .cursor/skills；.trae/rules/ai-dev-pipeline.md 已存在。"
} else {
    Write-Host "2. [todo] rules 对齐（.mdc ↔ .trae）：" -ForegroundColor Yellow
    if (-not $traeSkillsLinked) {
    Write-Host "   - 运行联接（Trae 用）：powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/link-trae-skills.ps1（或 .ai-gates/link-platform.ps1 一次建齐所有传送门）"
    }
    if (-not $traeRulesOk) {
        Write-Host "   - 复制规则：copy .cursor/rules/ai-dev-pipeline.mdc → .trae/rules/ai-dev-pipeline.md"
    }
}
# 3. CodeGraph（可选；保持须用户同意，未自动执行）
if ($cgDirOk -and $cgCli) {
    Write-Host "3. [done] CodeGraph：.codegraph/ + CLI 已就绪（必要时重载 Cursor）。"
} elseif ($cgDirOk) {
    Write-Host "3. [todo·可选] CodeGraph：.codegraph/ 已存在但 CLI/MCP 需重载 Cursor；如安装：codegraph install --platform cursor"
} else {
    Write-Host "3. [todo·可选] CodeGraph 安装（须用户同意后执行）：codegraph install --platform cursor && codegraph init"
}
# 4. 人工填写
Write-Host "4. [人工] 填写 .cursor/project-context.md 的回归索引（≥1~2 行），然后运行：powershell -ExecutionPolicy Bypass -File .cursor/scripts/sync-regression-index.ps1 -Apply"
Write-Host ""
Write-Host "按清单逐步确认后，用「项目经理 + 需求」开工（未初始化前 Agent 走 CORE §无 project-context 冷启动，保守 Standard）。" -ForegroundColor DarkGray
exit 0
