# bash-write-gate.ps1 -- Codex 版
# PreToolUse hook (matcher: ^Bash$) -- 显式文件写入门禁，补 apply_patch 门禁的 Bash 逃逸洞。
#
# 背景（2026-08-05）：pm-gate-check.ps1 只挂在 ^apply_patch$；Bash 里 Set-Content /
# Out-File / [IO.File]::WriteAll* / 重定向 等显式写文件命令不受写门禁约束，与 Cursor 版
# 只覆盖 Write 工具同类。本钩子把"显式写文件"的 Bash 命令纳入同一套语义：
#   - 业务路径（非 .cursor/.ai-gates/.codex 设施）→ 须会话内新鲜 [PM] 标记（120 分钟）
#   - .cursor/.ai-gates/.codex 设施路径 → 须近期 CHANGELOG 写（120 分钟）
#   - 生成/运行时目录白名单放行（bin/obj/Library/Temp/Logs/node_modules/.git、
#     .ai-gates/{tmp,hooks-log,verify,releases}）
# 解析不确定 / 提取不到路径 / 非显式写入命令 → fail-open allow（与 git-safety-check 同惯例）。
# 逃生：kill switch（.ai-gates/hooks-log/pm-gate-disabled）/ 手动编辑 / 改用 apply_patch。
#
# 注意：本钩子只拦"显式写文件"命令，不拦构建/测试（dotnet build、Unity batchmode 等
# 通过自身引擎写生成文件）；生成目录白名单兜底放行，误判靠 fail-open + 逃生通道兜底。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$gateFile = Join-Path $LogDir 'pm-gate.json'
$changelogFile = Join-Path $LogDir 'changelog-writes.json'
$killSwitch = Join-Path $LogDir 'pm-gate-disabled'
$FreshnessMinutes = 120

function Test-KillSwitch {
    return (Test-Path -LiteralPath $killSwitch)
}

function Test-InfraPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    return ($FilePath -match '[\\/]\.(cursor|ai-gates|codex)[\\/]' -or $FilePath -match '^\.(cursor|ai-gates|codex)[\\/]')
}

function Test-GeneratedPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    $norm = $FilePath -replace '\\', '/'
    if ($norm -match '(?i)(?:^|/)(bin|obj|library|temp|logs|node_modules)(?:/|$)') { return $true }
    if ($norm -match '(?i)\.ai-gates/(tmp|hooks-log|verify|releases)(?:/|$)') { return $true }
    if ($norm -match '(?:^|/)\.git(?:/|$)') { return $true }
    return $false
}

# 从 Bash 命令文本提取显式写文件的目标路径（尽力而为；提取不到返回空数组，主流程 fail-open）。
function Get-BashWritePaths {
    param([string]$CommandText)
    $paths = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return @($paths) }

    # 1) PowerShell 写 cmdlet：-Path / -LiteralPath / 相邻引号或裸 token
    $cmdletPat = '(?i)\b(?:Set-Content|Add-Content|Out-File|Clear-Content)\b[^\r\n]*'
    foreach ($m in [Regex]::Matches($CommandText, $cmdletPat)) {
        $seg = $m.Value
        # 带引号路径优先（支持含空格路径）；否则取 -Path 后的裸 token（不含引号/空格）
        $flagQuoted = '(?i)(?:-Path|-LiteralPath|-FilePath)\s+["'']([^"'']+)["'']'
        $fm = [Regex]::Match($seg, $flagQuoted)
        if (-not $fm.Success) {
            $flagBare = '(?i)(?:-Path|-LiteralPath|-FilePath)\s+([^\s"'']+)'
            $fm = [Regex]::Match($seg, $flagBare)
        }
        if ($fm.Success) {
            $paths.Add($fm.Groups[1].Value.Trim()) | Out-Null
            continue
        }
        $quotePat = '["'']((?:\\.|[^"''])*)["'']'
        $qm = [Regex]::Match($seg, $quotePat)
        if ($qm.Success) {
            $paths.Add($qm.Groups[1].Value.Trim()) | Out-Null
            continue
        }
        # 裸 token（非 - 开头、非纯命令动词），取第一个
        $barePat = '(?i)\b(?:Set-Content|Add-Content|Out-File|Clear-Content)\s+((?:[^\s"''|;&<>])+)'
        $bm = [Regex]::Match($seg, $barePat)
        if ($bm.Success -and -not $bm.Groups[1].Value.StartsWith('-')) {
            $paths.Add($bm.Groups[1].Value.Trim()) | Out-Null
        }
    }

    # 2) [IO.File]::WriteAllText/Lines/Bytes
    $ioPat = '\[IO\.File\]::WriteAll\w*\(["'']([^"'']+)["'']'
    foreach ($m in [Regex]::Matches($CommandText, $ioPat)) {
        $paths.Add($m.Groups[1].Value.Trim()) | Out-Null
    }

    # 3) 重定向 > 或 >>（排除 2>&1 / 1>&2 / *>&1 等句柄重定向）
    $redirPat = '(?<!\d|\*)(?:>>|>)\s*["'']?([^\s"'';|&<>]+)["'']?'
    foreach ($m in [Regex]::Matches($CommandText, $redirPat)) {
        $target = $m.Groups[1].Value.Trim()
        if ($target -match '^&') { continue }
        if ($target -eq 'NUL' -or $target -eq '$null') { continue }
        $paths.Add($target) | Out-Null
    }

    return @($paths)
}

function Test-BusinessFresh {
    param([string]$SessionId)
    if (-not (Test-Path -LiteralPath $gateFile)) { return $false }
    try {
        $gateRaw = Get-Content -LiteralPath $gateFile -Raw -Encoding UTF8
        $gate = $gateRaw | ConvertFrom-Json -ErrorAction Stop
    } catch { return $true }  # 读取异常 fail-open（同 pm-gate-check）
    $entry = $gate.$SessionId
    if (-not $entry -or -not $entry.lastPmAtUtc) { return $false }
    try {
        $lastUtc = [DateTime]::Parse($entry.lastPmAtUtc).ToUniversalTime()
    } catch { return $true }
    return (([DateTime]::UtcNow - $lastUtc).TotalMinutes -le $FreshnessMinutes)
}

function Test-ChangelogFresh {
    param([string]$SessionId)
    if (-not (Test-Path -LiteralPath $changelogFile)) { return $false }
    try {
        $raw = [System.IO.File]::ReadAllText($changelogFile, [System.Text.Encoding]::UTF8)
        $changelog = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch { return $true }  # 读取异常 fail-open
    $entry = $changelog.$SessionId
    if (-not $entry -or -not $entry.lastChangelogWriteAtUtc) { return $false }
    try {
        $lastUtc = [DateTime]::Parse($entry.lastChangelogWriteAtUtc).ToUniversalTime()
    } catch { return $true }
    return (([DateTime]::UtcNow - $lastUtc).TotalMinutes -le $FreshnessMinutes)
}

$raw = Read-HookStdin
$cmd = ""
$sessionId = "unknown"
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $sessionId = Get-SessionId -Json $json -Raw $raw
    if ($json.tool_input) {
        $cmd = [string](Get-Property $json.tool_input 'command')
    }
} catch {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW parse_failed_fail_open session={0}" -f $sessionId)
    Emit-PreToolUseAllow
}

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Emit-PreToolUseAllow
}

if (Test-KillSwitch) {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW kill_switch_active session={0}" -f $sessionId)
    Emit-PreToolUseAllow
}

$paths = @(Get-BashWritePaths -CommandText $cmd)
if ($paths.Count -eq 0) {
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW no_write_detected session={0}" -f $sessionId)
    Emit-PreToolUseAllow
}

$blocked = New-Object System.Collections.Generic.List[string]
$blockedReasons = New-Object System.Collections.Generic.List[string]
foreach ($p in $paths) {
    if (Test-GeneratedPath -FilePath $p) { continue }
    if (Test-InfraPath -FilePath $p) {
        if (-not (Test-ChangelogFresh -SessionId $sessionId)) {
            $blocked.Add($p) | Out-Null
            $blockedReasons.Add("infra_no_recent_changelog") | Out-Null
        }
    } else {
        if (-not (Test-BusinessFresh -SessionId $sessionId)) {
            $blocked.Add($p) | Out-Null
            $blockedReasons.Add("business_no_fresh_pm") | Out-Null
        }
    }
}

if ($blocked.Count -gt 0) {
    $hint = "逃生：先在本会话回复中发出 [PM] 标记（设施路径则先写 CHANGELOG），待 Stop hook 打点后重试；或人工确认后放置 .ai-gates/hooks-log/pm-gate-disabled（kill switch）后重试；或改用 apply_patch 走常规写门禁。"
    Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("DENY session={0} paths={1} reasons={2}" -f $sessionId, ($blocked -join ','), ($blockedReasons -join ','))
    Emit-PreToolUseDeny -Reason ("Bash write gate deny: explicit file write to {0} without {1}. {2}" -f ($blocked -join ', '), ($blockedReasons -join ', '), $hint)
}

Write-HookAudit -LogDir $LogDir -FileName 'bash-write-gate.log' -Line ("ALLOW write_paths_ok session={0} paths={1}" -f $sessionId, ($paths -join ','))
Emit-PreToolUseAllow
