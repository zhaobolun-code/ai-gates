# link-platform.ps1 — 创建各 IDE 到中央技能库 .ai-gates/ 的传送门（软连接）。
#
# 单源约定（2026-08-04 起）：中央技能库 = 仓库根 .ai-gates/（git 跟踪），内含
#   skills/（Skill 文件）、hooks/（Cursor 7 个 + codex/ 8 个 + claude/ 12 个）、scripts/、
#   rules/、hooks.json（Cursor 接线）、codex/hooks.json + codex/config.toml（Codex 接线）、
#   claude/settings.json + claude/agents/（Claude Code 接线）、package-release.ps1、
#   README.md、LICENSE。
# 各 IDE 只认自己的目录，因此建传送门：
#   .cursor/skills|hooks|scripts|rules  → junction/符号链接 → .ai-gates/对应目录
#   .cursor/hooks.json                  → 文件链接（Windows 优先硬链接，跨卷退符号链接）
#   .codex                              → junction/符号链接 → .ai-gates/codex
#   .trae/skills                        → junction/符号链接 → .ai-gates/skills（或 .cursor/skills）
#   .claude/settings.json               → 文件链接 → .ai-gates/claude/settings.json
#   .claude/agents                      → junction/符号链接 → .ai-gates/claude/agents
#   .claude/skills                      → junction/符号链接 → .ai-gates/skills（Claude Code 技能）
#   （.claude/settings.local.json 为机器本地文件，保持不动，不做传送门）
# Windows 目录用 Junction（无需管理员；同卷）；Unix 用符号链接（link-platform.sh）。
#
# 用法（仓库根）：
#   powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1
#
# 幂等：已存在的合法链接直接确认；真实目录/文件占据传送门位置时：
#   - .codex：自动迁移（内容并入 .ai-gates/codex/ 后删除重建链接）——旧版 .codex 为真实目录。
#   - 其余：报错拒绝（防数据丢失），需人工处理。
param(
    # 真迁移模式：.codex 等旧真实目录存在时允许自动迁移（默认开）
    [switch]$NoMigrate
)
$ErrorActionPreference = 'Stop'
$portalConflicts = New-Object System.Collections.Generic.List[string]
$repoRoot = Split-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -Parent
$central = Join-Path $repoRoot '.ai-gates'
if (-not (Test-Path (Join-Path $central 'skills\CORE.md'))) {
    throw "central library not found: $central\skills\CORE.md"
}
$isWindows = ($env:OS -eq 'Windows_NT')
function New-DirPortal {
    param([string]$Link, [string]$Target, [string]$Label)
    if (Test-Path -LiteralPath $Link) {
        $it = Get-Item -LiteralPath $Link -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK (linked): $Label -> $($it.Target)" -ForegroundColor Green
            return
        }
        $portalConflicts.Add("$Label (real dir: $Link)") | Out-Null
        Write-Host "CONFLICT: $Label occupied by a real directory (old-version layout) - $Link" -ForegroundColor Yellow
        return
    }
    New-Item -ItemType Directory -Path (Split-Path $Link -Parent) -Force | Out-Null
    if ($isWindows) {
        New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
    }
    Write-Host "linked: $Label -> $Target" -ForegroundColor Green
}
function New-FilePortal {
    param([string]$Link, [string]$Target, [string]$Label)
    if (Test-Path -LiteralPath $Link) {
        $it = Get-Item -LiteralPath $Link -Force
        if ($it.LinkType) {
            Write-Host "OK (file portal exists): $Label" -ForegroundColor Green
            return
        }
        # 升级残留检测（2026-08-04）：真实文件且与中央库不一致 → 提示替换，不自动删除（防误删自定义接线）
        $same = (Get-FileHash -LiteralPath $Link -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
        if ($same) {
            Write-Host "OK (file matches central copy): $Label" -ForegroundColor Green
        } else {
            Write-Host "STALE: $Label is a real file and differs from $Target (old-version wiring)." -ForegroundColor Yellow
            $portalConflicts.Add("$Label (stale real file: $Link)") | Out-Null
            Write-Host "  Fix: remove $Link and re-run this script to link the new hooks.json." -ForegroundColor Yellow
            Write-Host "  (keep it only if you intentionally customized the project hooks wiring)" -ForegroundColor Yellow
        }
        return
    }
    New-Item -ItemType Directory -Path (Split-Path $Link -Parent) -Force | Out-Null
    try {
        New-Item -ItemType HardLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "linked (hardlink): $Label -> $Target" -ForegroundColor Green
    } catch {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
        Write-Host "linked (symlink): $Label -> $Target" -ForegroundColor Green
    }
}
function New-CodexPortal {
    $link = Join-Path $repoRoot '.codex'
    $target = Join-Path $central 'codex'
    if (Test-Path -LiteralPath $link) {
        $it = Get-Item -LiteralPath $link -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK (linked): .codex -> $($it.Target)" -ForegroundColor Green
            return
        }
        if ($NoMigrate) {
            throw ".codex exists as a real directory; re-run without -NoMigrate to migrate it into .ai-gates/codex/ and relink."
        }
        foreach ($f in @('hooks.json', 'config.toml')) {
            $src = Join-Path $link $f
            $dst = Join-Path $target $f
            if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) {
                Copy-Item -LiteralPath $src -Destination $dst -Force
                Write-Host "migrated: $src -> $dst" -ForegroundColor Yellow
            }
        }
        try {
            Remove-Item -LiteralPath $link -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "WARN: .codex is locked by a running session (config.toml in use). Content already migrated to .ai-gates/codex/; re-run link-platform.ps1 after closing Codex sessions to finish the link swap." -ForegroundColor Yellow
            return
        }
    }
    if ($isWindows) {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    }
    Write-Host "linked: .codex -> $target" -ForegroundColor Green
}
function New-ClaudePortal {
    # Claude Code 侧传送门（2026-08-10；mcp.json 2026-08-11）：
    #   .claude/settings.json → 文件链接 → .ai-gates/claude/settings.json（hooks 接线）
    #   .claude/agents        → junction → .ai-gates/claude/agents（岗位代理）
    #   .claude/skills        → junction → .ai-gates/skills（Skill 内容零移植）
    #   .mcp.json（项目根）   → 文件链接 → .ai-gates/claude/mcp.json（Claude Code MCP 接线；
    #                           注：Claude Code 不读取 .claude/mcp.json，不建该路径）
    # 注意：.claude 目录本身**不做** junction——.claude/settings.local.json 是机器本地
    # 权限文件（gitignore），必须留在真实目录里；只建子级传送门。
    $centralClaude = Join-Path $central 'claude'
    New-FilePortal -Link (Join-Path $repoRoot '.claude\settings.json') -Target (Join-Path $centralClaude 'settings.json') -Label '.claude/settings.json'
    New-FilePortal -Link (Join-Path $repoRoot '.mcp.json') -Target (Join-Path $centralClaude 'mcp.json') -Label '.mcp.json'
    New-DirPortal -Link (Join-Path $repoRoot '.claude\agents') -Target (Join-Path $centralClaude 'agents') -Label '.claude/agents'
    New-DirPortal -Link (Join-Path $repoRoot '.claude\skills') -Target (Join-Path $central 'skills') -Label '.claude/skills'
}

function New-TraePortal {
    $link = Join-Path $repoRoot '.trae\skills'
    $target = Join-Path $central 'skills'
    if (Test-Path -LiteralPath $link) {
        $it = Get-Item -LiteralPath $link -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK (linked): .trae/skills -> $($it.Target)" -ForegroundColor Green
        } else {
            $portalConflicts.Add(".trae/skills (real dir: $link)") | Out-Null
            Write-Host "CONFLICT: .trae/skills occupied by a real directory (old-version layout) - $link" -ForegroundColor Yellow
        }
    } else {
        New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
        if ($isWindows) {
            New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
        }
        Write-Host "linked: .trae/skills -> $target" -ForegroundColor Green
    }
    # 2026-08-05：Trae 侧规则目录传送门（.trae/rules -> .ai-gates/rules），与 Cursor 侧对齐。
    $linkRules = Join-Path $repoRoot '.trae\rules'
    $targetRules = Join-Path $central 'rules'
    if (Test-Path -LiteralPath $linkRules) {
        $it = Get-Item -LiteralPath $linkRules -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK (linked): .trae/rules -> $($it.Target)" -ForegroundColor Green
        } else {
            $portalConflicts.Add(".trae/rules (real dir: $linkRules)") | Out-Null
            Write-Host "CONFLICT: .trae/rules occupied by a real directory - $linkRules" -ForegroundColor Yellow
        }
    } else {
        New-Item -ItemType Directory -Path (Split-Path $linkRules -Parent) -Force | Out-Null
        if ($isWindows) {
            New-Item -ItemType Junction -Path $linkRules -Target $targetRules | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $linkRules -Target $targetRules | Out-Null
        }
        Write-Host "linked: .trae/rules -> $targetRules" -ForegroundColor Green
    }
}

function Migrate-ProjectState {
    # 老用户升级（2026-08-05）：.cursor 根的项目状态/中间文件 → .ai-gates 对应位置。
    # 目标已存在则跳过（不覆盖）；拷贝成功后删除旧源（等同移动，避免双份漂移）。
    $mappings = @(
        @{ Name = 'regression-index.yaml';    From = '.cursor\regression-index.yaml';    To = 'regression-index.yaml' },
        @{ Name = 'lessons-learned.md';       From = '.cursor\lessons-learned.md';       To = 'lessons-learned.md' },
        @{ Name = 'lessons-outline.md';       From = '.cursor\lessons-outline.md';       To = 'lessons-outline.md' },
        @{ Name = 'pipeline-outcome.log';     From = '.cursor\pipeline-outcome.log';     To = 'pipeline-outcome.log' },
        @{ Name = 'pipeline-snapshot.log';    From = '.cursor\pipeline-snapshot.log';    To = 'pipeline-snapshot.log' },
        @{ Name = 'pipeline-recovery-log.md'; From = '.cursor\pipeline-recovery-log.md'; To = 'pipeline-recovery-log.md' },
        @{ Name = 'hooks-log';                From = '.cursor\hooks-log';                To = 'hooks-log' },
        @{ Name = 'tmp';                      From = '.cursor\tmp';                      To = 'tmp' },
        @{ Name = 'verify';                   From = '.cursor\verify';                   To = 'verify' }
    )
    foreach ($m in $mappings) {
        $src = Join-Path $repoRoot $m.From
        $dst = Join-Path $central $m.To
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (Test-Path -LiteralPath $dst) {
            Write-Host "MIGRATE skip (target exists): .ai-gates/$($m.To)" -ForegroundColor DarkGray
            continue
        }
        try {
            if ((Get-Item -LiteralPath $src -Force).PSIsContainer) {
                Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
            } else {
                Copy-Item -LiteralPath $src -Destination $dst -Force
            }
            Remove-Item -LiteralPath $src -Recurse -Force
            Write-Host "MIGRATED: .cursor/$($m.Name) -> .ai-gates/$($m.To)" -ForegroundColor Green
        } catch {
            Write-Host "MIGRATE WARN: $($m.Name) copy failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host "=== link-platform: central = $central ===" -ForegroundColor Cyan
Migrate-ProjectState
foreach ($d in @('skills', 'hooks', 'scripts', 'rules')) {
    New-DirPortal -Link (Join-Path $repoRoot ".cursor\$d") -Target (Join-Path $central $d) -Label ".cursor/$d"
}
New-FilePortal -Link (Join-Path $repoRoot '.cursor\hooks.json') -Target (Join-Path $central 'hooks.json') -Label '.cursor/hooks.json'
New-CodexPortal
New-ClaudePortal
New-TraePortal
if ($portalConflicts.Count -gt 0) {
    Write-Host ""
    Write-Host "=== 升级处理指引 ===" -ForegroundColor Cyan
    Write-Host "以下位置被旧版真实目录/文件占据，脚本拒绝自动删除（防误删项目数据）：" -ForegroundColor Yellow
    $portalConflicts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "处理步骤：" -ForegroundColor Cyan
    Write-Host "1) 确认 .cursor/skills|hooks|scripts|rules 里没有项目自己放的文件（按设计只放技能内容）；"
    Write-Host "2) 删除这些旧目录和旧的 .cursor/hooks.json；"
    Write-Host "3) 项目状态文件（regression-index.yaml、lessons-*、pipeline-*.log、hooks-log/、tmp/、verify/）已自动迁入 .ai-gates/；保留、不要删：.cursor/project-context.md、mcp.json；"
    Write-Host "4) 删除后重新运行本脚本。"
    Write-Host "（.codex 旧真实目录会自动迁移，无需手动删。）" -ForegroundColor DarkGray
    exit 1
}
Write-Host 'link-platform: all portals ready.' -ForegroundColor Green
