# check-hooks-drift.ps1 -- Codex 版
# SessionStart hook — Codex 侧接线漂移检测（对齐 Cursor 版 check-hooks-drift 思路的最小切口）。
#
# 校验对象（Codex 专属接线）：
#   1) .codex/config.toml 含 [features] hooks = true（否则 hooks 根本不加载）
#   2) .codex/hooks.json 可解析，且必需事件 → 脚本映射齐套：
#        SessionStart → check-hooks-drift；PreToolUse(^Bash$) → git-safety-check；
#        PreToolUse(^apply_patch$) → audit-write + pm-gate-check；
#        PostToolUse(^apply_patch$) → check-unity-compile + mark-changelog-write；Stop → mark-pm-gate
#   3) 每个被引用脚本存在于 .cursor/hooks/codex/
#   4) AGENTS.md 提及 Codex hooks（软提示；缺时算 drift，提示补文档）
# 漂移时：写 .ai-gates/hooks-log/codex-hooks-drift.json（侧写，防 additionalContext 偶发未注入）
# + stdout 返回 additionalContext；无漂移：清掉 drift 文件，返回 SessionStart 空壳。
# fail-open：任何异常返回空壳（SessionStart 无拦截语义）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$driftFile = Join-Path $LogDir 'codex-hooks-drift.json'

$cursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repoRoot = Split-Path $cursorRoot -Parent
$codexJson = Join-Path $repoRoot '.codex/hooks.json'
$codexToml = Join-Path $repoRoot '.codex/config.toml'
$agentsMd = Join-Path $repoRoot 'AGENTS.md'

function Write-Audit {
    param([string]$Line)
    Write-HookAudit -LogDir $LogDir -FileName 'hooks-policy-drift.log' -Line $Line
}

function Test-Bom {
    param([string]$Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    } catch {
        return $false
    }
}

function Test-PortalHealth {
    param([string]$RepoRoot)
    $issues = New-Object System.Collections.Generic.List[string]
    $central = Join-Path $RepoRoot '.ai-gates'
    foreach ($d in @('skills', 'hooks', 'scripts', 'rules')) {
        $link = Join-Path $RepoRoot (".cursor\$d")
        if (-not (Test-Path -LiteralPath $link)) {
            $issues.Add("portal missing: .cursor/$d (run link-platform.ps1)") | Out-Null
        } else {
            $it = Get-Item -LiteralPath $link -Force
            if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($it.Target -notmatch [regex]::Escape((Join-Path $central $d))) {
                    $issues.Add("portal target mismatch: .cursor/$d -> $($it.Target)") | Out-Null
                }
            } else {
                $issues.Add("portal occupied by real dir: .cursor/$d (migrate then run link-platform.ps1)") | Out-Null
            }
        }
    }
    $hooksLink = Join-Path $RepoRoot '.cursor\hooks.json'
    $centralHooks = Join-Path $central 'hooks.json'
    if (-not (Test-Path -LiteralPath $hooksLink)) {
        $issues.Add("portal missing: .cursor/hooks.json (run link-platform.ps1)") | Out-Null
    } else {
        $it = Get-Item -LiteralPath $hooksLink -Force
        if (-not $it.LinkType) {
            $h1 = (Get-FileHash -LiteralPath $hooksLink -Algorithm SHA256).Hash
            $h2 = (Get-FileHash -LiteralPath $centralHooks -Algorithm SHA256).Hash
            if ($h1 -ne $h2) {
                $issues.Add("stale real file: .cursor/hooks.json differs from .ai-gates/hooks.json (delete it, then run link-platform.ps1)") | Out-Null
            }
        }
    }
    $codex = Join-Path $RepoRoot '.codex'
    if (-not (Test-Path -LiteralPath $codex)) {
        $issues.Add("portal missing: .codex (run link-platform.ps1)") | Out-Null
    } else {
        $it = Get-Item -LiteralPath $codex -Force
        if (-not ($it.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            $issues.Add(".codex is a real dir (run link-platform.ps1 to auto-migrate)") | Out-Null
        }
    }
    return @($issues)
}

try {
    $null = Read-HookStdin  # drain stdin (SessionStart 载荷可忽略)
    $issues = New-Object System.Collections.Generic.List[string]

    # 1) features.hooks
    if (-not (Test-Path -LiteralPath $codexToml)) {
        $issues.Add(".codex/config.toml missing ([features] hooks = true)") | Out-Null
    } else {
        $tomlRaw = [System.IO.File]::ReadAllText($codexToml, [System.Text.Encoding]::UTF8)
        if ($tomlRaw -notmatch '(?im)^\s*\[features\]\s*$' -or $tomlRaw -notmatch '(?im)^\s*hooks\s*=\s*true\s*$') {
            $issues.Add(".codex/config.toml must contain [features] hooks = true") | Out-Null
        }
    }

    # 2) hooks.json 必需事件映射
    $expected = @(
        @{ Event = 'SessionStart';  Matcher = $null;        Scripts = @('check-hooks-drift.ps1') },
        @{ Event = 'PreToolUse';    Matcher = '^Bash$';     Scripts = @('git-safety-check.ps1') },
        @{ Event = 'PreToolUse';    Matcher = '^apply_patch$'; Scripts = @('audit-write.ps1', 'pm-gate-check.ps1') },
        @{ Event = 'PostToolUse';   Matcher = '^apply_patch$'; Scripts = @('check-unity-compile.ps1', 'mark-changelog-write.ps1') },
        @{ Event = 'Stop';          Matcher = $null;        Scripts = @('mark-pm-gate.ps1') }
    )
    $foundScripts = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $codexJson)) {
        $issues.Add(".codex/hooks.json missing") | Out-Null
    } else {
        try {
            $hooksRaw = [System.IO.File]::ReadAllText($codexJson, [System.Text.Encoding]::UTF8)
            $hooksCfg = $hooksRaw | ConvertFrom-Json -ErrorAction Stop
            foreach ($ev in $hooksCfg.hooks.PSObject.Properties) {
                foreach ($group in @($ev.Value)) {
                    foreach ($handler in @($group.hooks)) {
                        if ($handler.type -eq 'command' -and $handler.command) {
                            $m = [Regex]::Match([string]$handler.command, '-File\s+([^\s"]+)')
                            if ($m.Success) { $foundScripts.Add($m.Groups[1].Value.Trim('"')) | Out-Null }
                        }
                    }
                }
            }
        } catch {
            $issues.Add(".codex/hooks.json unreadable/invalid JSON") | Out-Null
        }
        foreach ($exp in $expected) {
            $scriptOk = $false
            foreach ($s in $exp.Scripts) {
                $matchFound = ($foundScripts | Where-Object { $_ -match [Regex]::Escape($s) + '$' })
                if ($matchFound) { $scriptOk = $true }
            }
            if (-not $scriptOk) {
                $issues.Add(("missing wiring: {0} -> {1}" -f $exp.Event, ($exp.Scripts -join ', '))) | Out-Null
            }
        }
    }

    # 3) 被引用脚本存在且为 UTF-8 BOM
    foreach ($s in $foundScripts) {
        $abs = Join-Path $repoRoot ($s -replace '[\\/]', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $abs)) {
            $issues.Add("referenced hook script missing: $s") | Out-Null
        } elseif (-not (Test-Bom -Path $abs)) {
            $issues.Add("hook script must be UTF-8 BOM: $s") | Out-Null
        }
    }

    # 4) AGENTS.md 文档提示（软）
    if (-not (Test-Path -LiteralPath $agentsMd)) {
        $issues.Add("AGENTS.md missing (Codex 入口路由文档)") | Out-Null
    } elseif ((Get-Content -LiteralPath $agentsMd -Raw -Encoding UTF8) -notmatch 'hook') {
        $issues.Add("AGENTS.md 未提及 Codex hooks 接线说明") | Out-Null
    }

    # 5) 传送门健康（升级残留 / 缺失提示）
    $portal = @(Test-PortalHealth -RepoRoot $repoRoot)
    foreach ($p in $portal) { $issues.Add($p) | Out-Null }

    if ($issues.Count -eq 0) {
        if (Test-Path -LiteralPath $driftFile) {
            Remove-Item -LiteralPath $driftFile -Force -ErrorAction SilentlyContinue
        }
        Write-Audit 'OK no_drift'
        Emit-SessionStartEmpty
    }

    $hint = 'Codex hooks wiring drifted from .codex/hooks.json / .codex/config.toml / .cursor/hooks/codex/. Align or update docs, then re-run: powershell -File .cursor/scripts/check-hooks-policy.ps1'
    if ($portal.Count -gt 0) {
        $hint += ' Portal issues: run: powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1 (idempotent).'
    }
    $payload = [ordered]@{
        ok        = $false
        checkedAt = (Get-Date).ToUniversalTime().ToString('o')
        issues    = @($issues)
        hint      = $hint
    }
    [System.IO.File]::WriteAllText($driftFile, ($payload | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Write-Audit ("DRIFT issues={0}" -f ($issues -join '; '))

    $ctx = @"
[codex-hooks-drift] SessionStart detected Codex hooks wiring drift:
- $($issues -join "`n- ")
Side channel: .ai-gates/hooks-log/codex-hooks-drift.json
Do not silently ignore: fix .codex/hooks.json / .codex/config.toml / .cursor/hooks/codex/, then restart session.
"@
    Emit-SessionStartContext -Context $ctx
} catch {
    Write-Audit ("ERROR fail_open msg={0}" -f $_.Exception.Message)
    Emit-SessionStartEmpty
}
