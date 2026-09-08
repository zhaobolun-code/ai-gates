# check-rule-invariants.ps1 — 承重句 canary（维护层，不进 Agent 日常必读）
# 检查 CORE / 入口路由 / AGENTS.md / always-on .mdc 是否仍含关键句。
# 不是全文相等：各文件允许摘要，但点名的子串丢了就红。
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/check-rule-invariants.ps1
#   powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/check-rule-invariants.ps1 -RepoRoot D:\path

param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom

if (-not $RepoRoot) {
    $RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    }
}

function Test-FileNeedles {
    param(
        [string]$Rel,
        [string[]]$Needles
    )
    $path = Join-Path $RepoRoot $Rel
    if (-not (Test-Path -LiteralPath $path)) {
        return @("missing: $Rel")
    }
    $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $miss = @()
    foreach ($n in $Needles) {
        if ($raw.IndexOf($n) -lt 0) {
            $miss += ("missing needle in {0}: {1}" -f $Rel, $n)
        }
    }
    return $miss
}

$checks = @(
    @{
        Rel     = ".cursor/skills/CORE.md"
        Needles = @(
            "无 PM 门禁不改交付物",
            "复用四问",
            "按 CORE 重来"
        )
    },
    @{
        Rel     = ".cursor/skills/references/agent-entry-route.md"
        Needles = @(
            "复用四问",
            "你下一步"
        )
    },
    @{
        Rel     = "AGENTS.md"
        Needles = @(
            "无本轮 ``[PM]`` 判定不得创建/修改交付物",
            "项目经理"
        )
    },
    @{
        Rel     = ".cursor/rules/ai-dev-pipeline.mdc"
        Needles = @(
            "硬门禁 #7",
            "你下一步",
            "agent-entry-route.md"
        )
    }
)

$issues = New-Object System.Collections.Generic.List[string]
foreach ($c in $checks) {
    foreach ($hit in (Test-FileNeedles -Rel $c.Rel -Needles $c.Needles)) {
        $issues.Add($hit) | Out-Null
    }
}

$trae = Join-Path $RepoRoot ".trae/rules/ai-dev-pipeline.md"
if (Test-Path -LiteralPath $trae) {
    foreach ($hit in (Test-FileNeedles -Rel ".trae/rules/ai-dev-pipeline.md" -Needles @("硬门禁 #7", "agent-entry-route.md"))) {
        $issues.Add($hit) | Out-Null
    }
}

if ($issues.Count -gt 0) {
    Write-Host "rule invariants: FAILED" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "rule invariants: OK ($($checks.Count) files)" -ForegroundColor Green
exit 0
