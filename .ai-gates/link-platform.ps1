# link-platform.ps1 — 创建各 IDE 到中央技能库 .ai-gates/ 的传送门（软连接）。
#
# 单源约定（2026-08-04 起）：中央技能库 = 仓库根 .ai-gates/（git 跟踪），内含
#   skills/（Skill 文件）、hooks/（Cursor 7 个 + codex/ 8 个）、scripts/、rules/、
#   hooks.json（Cursor 接线）、codex/hooks.json + codex/config.toml（Codex 接线）、
#   package-release.ps1、README.md、LICENSE。
# 各 IDE 只认自己的目录，因此建传送门：
#   .cursor/skills|hooks|scripts|rules  → junction/符号链接 → .ai-gates/对应目录
#   .cursor/hooks.json                  → 文件链接（Windows 优先硬链接，跨卷退符号链接）
#   .codex                              → junction/符号链接 → .ai-gates/codex
#   .trae/skills                        → junction/符号链接 → .ai-gates/skills（或 .cursor/skills）
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
        throw "portal path occupied by a real directory (refusing to delete): $Link"
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
        Write-Host "OK (file portal exists): $Label" -ForegroundColor Green
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
function New-TraePortal {
    $link = Join-Path $repoRoot '.trae\skills'
    $target = Join-Path $central 'skills'
    if (Test-Path -LiteralPath $link) {
        $it = Get-Item -LiteralPath $link -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK (linked): .trae/skills -> $($it.Target)" -ForegroundColor Green
            return
        }
        throw ".trae/skills exists as a real directory; migrate it manually then re-run."
    }
    New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
    if ($isWindows) {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    }
    Write-Host "linked: .trae/skills -> $target" -ForegroundColor Green
}
Write-Host "=== link-platform: central = $central ===" -ForegroundColor Cyan
foreach ($d in @('skills', 'hooks', 'scripts', 'rules')) {
    New-DirPortal -Link (Join-Path $repoRoot ".cursor\$d") -Target (Join-Path $central $d) -Label ".cursor/$d"
}
New-FilePortal -Link (Join-Path $repoRoot '.cursor\hooks.json') -Target (Join-Path $central 'hooks.json') -Label '.cursor/hooks.json'
New-CodexPortal
New-TraePortal
Write-Host 'link-platform: all portals ready.' -ForegroundColor Green
