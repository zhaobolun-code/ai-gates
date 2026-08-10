# check-hooks-drift.ps1 -- Claude Code 版
# SessionStart hook — Claude Code 侧接线漂移检测（2026-08-10 自 Codex 版改写）。
#
# 校验对象（Claude Code 专属接线）：
#   1) .claude/settings.json 存在且可解析（Claude Code 无 config.toml；hooks 由
#      settings.json 的 hooks 键加载，且 settings.json 是 .ai-gates/claude/ 的文件传送门）
#   2) settings.json 的 hooks 键必需事件 → 脚本映射齐套：
#        SessionStart → check-hooks-drift；PreToolUse(^Bash$) → pre-bash-gate；
#        PreToolUse(^(Write|Edit|MultiEdit|NotebookEdit)$) → pre-write-gate；
#        PostToolUse(^(Write|Edit|MultiEdit|NotebookEdit)$) → post-write-gate；Stop → mark-pm-gate
#   3) 每个被引用脚本存在于 .ai-gates/hooks/claude/ 且为 UTF-8 BOM
#   4) CLAUDE.md 或 AGENTS.md 提及 Claude hooks（软提示；缺时算 drift，提示补文档）
# 漂移时：写 .ai-gates/hooks-log/claude-hooks-drift.json（侧写，防 additionalContext 偶发未注入）
# + stdout 返回 additionalContext；无漂移：清掉 drift 文件，返回 SessionStart 空壳。
# fail-open：任何异常返回空壳（SessionStart 无拦截语义）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$driftFile = Join-Path $LogDir 'claude-hooks-drift.json'

$cursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repoRoot = Split-Path $cursorRoot -Parent
$claudeSettings = Join-Path $repoRoot '.claude/settings.json'
$centralClaude = Join-Path $repoRoot '.ai-gates/claude'
$agentsMd = Join-Path $repoRoot 'AGENTS.md'
$claudeMd = Join-Path $repoRoot 'CLAUDE.md'

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
    # .claude/settings.json：文件传送门（硬链接或与中央一致）
    $settingsLink = Join-Path $RepoRoot '.claude\settings.json'
    $centralSettings = Join-Path $central 'claude/settings.json'
    if (-not (Test-Path -LiteralPath $settingsLink)) {
        $issues.Add("portal missing: .claude/settings.json (run link-platform.ps1)") | Out-Null
    } else {
        $it = Get-Item -LiteralPath $settingsLink -Force
        if (-not $it.LinkType) {
            $h1 = (Get-FileHash -LiteralPath $settingsLink -Algorithm SHA256).Hash
            $h2 = (Get-FileHash -LiteralPath $centralSettings -Algorithm SHA256).Hash
            if ($h1 -ne $h2) {
                $issues.Add("stale real file: .claude/settings.json differs from .ai-gates/claude/settings.json (delete it, then run link-platform.ps1)") | Out-Null
            }
        }
    }
    # .claude/agents 与 .claude/skills：目录传送门（junction）
    foreach ($d in @('agents', 'skills')) {
        $link = Join-Path $RepoRoot (".claude\$d")
        if (-not (Test-Path -LiteralPath $link)) {
            $issues.Add("portal missing: .claude/$d (run link-platform.ps1)") | Out-Null
        } else {
            $it = Get-Item -LiteralPath $link -Force
            if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $targetExpected = if ($d -eq 'skills') { Join-Path $central 'skills' } else { Join-Path $central 'claude/agents' }
                if ($it.Target -notmatch [regex]::Escape($targetExpected)) {
                    $issues.Add("portal target mismatch: .claude/$d -> $($it.Target)") | Out-Null
                }
            } else {
                $issues.Add("portal occupied by real dir: .claude/$d (migrate then run link-platform.ps1)") | Out-Null
            }
        }
    }
    return @($issues)
}

try {
    $null = Read-HookStdin  # drain stdin (SessionStart 载荷可忽略)
    $issues = New-Object System.Collections.Generic.List[string]

    # 1) .claude/settings.json 存在（Claude Code 无 config.toml；hooks 由 settings.json 加载）
    if (-not (Test-Path -LiteralPath $claudeSettings)) {
        $issues.Add(".claude/settings.json missing (run link-platform.ps1)") | Out-Null
    }

    # 2) settings.json 的 hooks 键必需事件映射
    # 2026-08-06 合并入口（沿用）：同一事件多门禁已合成单脚本（pre-*-gate.ps1），
    # 单进程内依次执行原门禁脚本；此处接线期望随之更新。
    # 2026-08-10 Claude Code 版：matcher 为工具名正则；Claude 写工具 = Write|Edit|MultiEdit|NotebookEdit。
    $expected = @(
        @{ Event = 'SessionStart';  Matcher = $null;        Scripts = @('check-hooks-drift.ps1') },
        @{ Event = 'PreToolUse';    Matcher = '^Bash$';     Scripts = @('pre-bash-gate.ps1') },
        @{ Event = 'PreToolUse';    Matcher = '^(Write|Edit|MultiEdit|NotebookEdit)$'; Scripts = @('pre-write-gate.ps1') },
        @{ Event = 'PostToolUse';   Matcher = '^(Write|Edit|MultiEdit|NotebookEdit)$'; Scripts = @('post-write-gate.ps1') },
        @{ Event = 'Stop';          Matcher = $null;        Scripts = @('mark-pm-gate.ps1') }
    )
    $foundScripts = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $claudeSettings)) {
        $issues.Add(".claude/settings.json missing") | Out-Null
    } else {
        try {
            $hooksRaw = [System.IO.File]::ReadAllText($claudeSettings, [System.Text.Encoding]::UTF8)
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
            $issues.Add(".claude/settings.json unreadable/invalid JSON") | Out-Null
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

    # 4) CLAUDE.md / AGENTS.md 文档提示（软）
    $docMd = if (Test-Path -LiteralPath $claudeMd) { $claudeMd } elseif (Test-Path -LiteralPath $agentsMd) { $agentsMd } else { $null }
    if (-not $docMd) {
        $issues.Add("CLAUDE.md/AGENTS.md missing (Claude Code 入口路由文档)") | Out-Null
    } elseif ((Get-Content -LiteralPath $docMd -Raw -Encoding UTF8) -notmatch 'hook') {
        $issues.Add("CLAUDE.md/AGENTS.md 未提及 Claude Code hooks 接线说明") | Out-Null
    }

    # 5) 安装信息与包版本一致性（本地检查；远端最新版用 install-ai-gates.ps1 -CheckUpdate）
    $installInfo = Join-Path $repoRoot '.ai-gates\install-info.json'
    $versionFile = Join-Path $repoRoot '.ai-gates\skills\VERSION'
    if (Test-Path -LiteralPath $installInfo) {
        try {
            $ii = Get-Content -LiteralPath $installInfo -Raw -Encoding UTF8 | ConvertFrom-Json
            if (Test-Path -LiteralPath $versionFile) {
                $ver = (Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8).Trim()
                if ($ii.tag -and $ii.tag -notmatch [regex]::Escape($ver)) {
                    $issues.Add("install-info tag ($($ii.tag)) != pack VERSION ($ver); run: powershell -File .ai-gates/scripts/install-ai-gates.ps1 -CheckUpdate") | Out-Null
                }
            }
        } catch {
            # install-info 解析失败不阻塞（fail-open）
        }
    }

    # 6) 传送门健康（升级残留 / 缺失提示）
    $portal = @(Test-PortalHealth -RepoRoot $repoRoot)
    foreach ($p in $portal) { $issues.Add($p) | Out-Null }

    if ($issues.Count -eq 0) {
        if (Test-Path -LiteralPath $driftFile) {
            Remove-Item -LiteralPath $driftFile -Force -ErrorAction SilentlyContinue
        }
        Write-Audit 'OK no_drift'
        $ctx = @"
[claude-hooks-live] 机器强制层提醒（2026-08-10 适配版，真机验证点）：
- Claude Code 侧 PreToolUse/PostToolUse 对 Bash 与 Write|Edit|MultiEdit|NotebookEdit 是否如文档触发、session_id 是否可用——首次会话请自查 .ai-gates/hooks-log/ 打点（pm-gate-check.log / write-audit.log / mark-pm-gate.log）。
- 若 deny 未生效：检查 .claude/settings.json 是否被真实文件占用（非传送门），或字段名 hook_event_name 与实机不符（见 claude-hooks-common.ps1 头注释真机验证点 #1）。
- 验证钩子内部逻辑：powershell -File .ai-gates/scripts/test-claude-hooks.ps1
"@
        Write-Output (Emit-SessionStartContext -Context $ctx)
        return
    }

    $hint = 'Claude Code hooks wiring drifted from .claude/settings.json / .ai-gates/hooks/claude/. Align or update docs, then re-run link-platform.ps1.'
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
[claude-hooks-drift] SessionStart detected Claude Code hooks wiring drift:
- $($issues -join "`n- ")
Side channel: .ai-gates/hooks-log/claude-hooks-drift.json
Do not silently ignore: fix .claude/settings.json / .ai-gates/hooks/claude/, then restart session.
"@
    Emit-SessionStartContext -Context $ctx
} catch {
    Write-Audit ("ERROR fail_open msg={0}" -f $_.Exception.Message)
    Emit-SessionStartEmpty
}
