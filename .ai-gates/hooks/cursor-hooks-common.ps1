# cursor-hooks-common.ps1
# Cursor 版 hooks 共享库（被 .ai-gates/hooks/ 下各脚本点源加载；本文件无 param() 块）。
#
# 2026-08-06 合并入口（pre-write-gate.ps1 / post-write-gate.ps1）：同一事件多门禁改为
# 单进程内依次执行，stdin 只读一次并缓存到全局，后续子脚本共享同一 payload
# （子脚本点源本文件后仍会走此缓存，避免第二个门禁读到已耗尽的流）。
# 读取实现与 mark-changelog-write 的健壮模式一致（OpenStandardInput + StreamReader 显式
# UTF-8），避免超大 payload 时 PS5.1 Console.In.ReadToEnd 解析失败。
# 不在此函数内自旋等待：宿主 hooks.json 的 timeout 为底线；stdin 无 EOF 时由 timeout 杀进程。

function Read-HookStdin {
    if ($null -ne $global:AI_GATES_HOOK_STDIN_CACHE) { return $global:AI_GATES_HOOK_STDIN_CACHE }
    $stream = [Console]::OpenStandardInput()
    try {
        $reader = New-Object System.IO.StreamReader($stream, (New-Object System.Text.UTF8Encoding($false)))
        $raw = $reader.ReadToEnd()
        $reader.Close()
    } finally {
        $stream.Dispose()
    }
    if ($null -eq $raw) { $raw = "" }
    $global:AI_GATES_HOOK_STDIN_CACHE = $raw.TrimStart([char]0xFEFF)
    return $global:AI_GATES_HOOK_STDIN_CACHE
}

# 本文件位于 .ai-gates/hooks/（经 .cursor/hooks 传送门时 $PSScriptRoot 仍是 hooks 目录）。
if (-not $script:AiGatesHooksDir) {
    $script:AiGatesHooksDir = $PSScriptRoot
}

function Get-AiGatesProjectRoot {
    $envDir = [string]$env:CURSOR_PROJECT_DIR
    if (-not [string]::IsNullOrWhiteSpace($envDir) -and (Test-Path -LiteralPath $envDir)) {
        return $envDir
    }
    try {
        $git = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$git)) {
            return ([string]$git).Trim()
        }
    } catch { }
    $hooksDir = $script:AiGatesHooksDir
    if (-not $hooksDir) { $hooksDir = $PSScriptRoot }
    return (Split-Path (Split-Path $hooksDir -Parent) -Parent)
}

function Get-AiGatesHookChannel {
    if (-not [string]::IsNullOrWhiteSpace([string]$env:CURSOR_PLUGIN_ROOT)) {
        return 'plugin'
    }
    return 'project'
}

function Redact-HookSecrets {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $t = $Text
    foreach ($pat in @('github_pat_[A-Za-z0-9_]+', 'ghp_[A-Za-z0-9_]+', 'crsr_[A-Za-z0-9]+', '\bsk-[A-Za-z0-9]+')) {
        $t = [regex]::Replace($t, $pat, '[redacted]')
    }
    return [regex]::Replace($t, '(?i)(Authorization:\s*Bearer\s+)\S+', '${1}[redacted]')
}

function Get-HookTargetPathFromRaw {
    param([string]$Raw)
    if ([string]::IsNullOrEmpty($Raw)) { return $null }
    $fileLine = [regex]::Match($Raw, '\*\*\*\s+(?:Update|Add|Delete)\s+File:\s*([^\r\n]+)')
    if ($fileLine.Success) {
        $p = $fileLine.Groups[1].Value.Trim().Trim('"').Trim()
        if ($p) { return ($p -replace '\\/', '/' -replace '\\\\', '\') }
    }
    $head = $Raw
    $cut = [regex]::Match($Raw, '"(?:old_string|new_string|contents|content|patch|diff)"\s*:')
    if ($cut.Success -and $cut.Index -gt 0) { $head = $Raw.Substring(0, $cut.Index) }
    foreach ($pat in @(
        '"file_path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"path"\s*:\s*"((?:\\.|[^"\\])*)"',
        '"target_notebook"\s*:\s*"((?:\\.|[^"\\])*)"'
    )) {
        $m = [regex]::Match($head, $pat)
        if ($m.Success) {
            return ($m.Groups[1].Value -replace '\\/', '/' -replace '\\\\', '\')
        }
    }
    return $null
}

function Write-AiGatesHookSkipAudit {
    param([string]$Reason)
    try {
        $root = Get-AiGatesProjectRoot
        $logDir = Join-Path $root '.ai-gates\hooks-log'
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $auditFile = Join-Path $logDir 'plugin-hook-skip.log'
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $channel = Get-AiGatesHookChannel
        $safeReason = Redact-HookSecrets $Reason
        Add-Content -LiteralPath $auditFile -Value "$ts | channel=$channel skip=true reason=$safeReason" -Encoding UTF8
    } catch { }
}

function Test-AiGatesShouldRunHook {
    # 插件进程 + 项目 .cursor/hooks 已落地 → 空跑（两套声明都在，门禁只执行一遍）。
    # 项目进程不看 CURSOR_PLUGIN_ROOT 泄漏：跳过只放在 hooks/plugin/invoke.ps1。
    if ((Get-AiGatesHookChannel) -ne 'plugin') { return $true }
    $root = Get-AiGatesProjectRoot
    $projectHooksJson = Join-Path $root '.cursor\hooks.json'
    $projectGate = Join-Path $root '.cursor\hooks\pre-write-gate.ps1'
    if ((Test-Path -LiteralPath $projectHooksJson) -and (Test-Path -LiteralPath $projectGate)) {
        Write-AiGatesHookSkipAudit -Reason 'plugin_when_project_hooks_present'
        return $false
    }
    return $true
}

# 每个 *.log 超过 8MB 时，只从末尾读 2MB 写回（不把整文件装进内存）。
# 截断失败必须吞掉，不得阻断后续 Add-Content / exit 0。
function Limit-HookAuditLog {
    param([string]$Path)
    $maxBytes = 8 * 1024 * 1024
    $keepBytes = 2 * 1024 * 1024
    $tempPath = $null
    $bakPath = $null
    $fs = $null
    $outFs = $null
    try {
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if (-not (Test-Path -LiteralPath $Path)) { return }

        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $len = $fs.Length
        if ($len -le $maxBytes) { return }

        $readLen = [int64]$keepBytes
        if ($readLen -gt $len) { $readLen = $len }
        [void]$fs.Seek(-$readLen, [System.IO.SeekOrigin]::End)
        $buf = New-Object byte[] $readLen
        $got = 0
        while ($got -lt $readLen) {
            $n = $fs.Read($buf, $got, [int]($readLen - $got))
            if ($n -le 0) { break }
            $got += $n
        }
        $fs.Dispose()
        $fs = $null
        if ($got -le 0) { return }

        $start = 0
        $nl = -1
        for ($i = 0; $i -lt $got; $i++) {
            if ($buf[$i] -eq 10) { $nl = $i; break }
        }
        if ($nl -ge 0) { $start = $nl + 1 }
        $end = $got
        if ($nl -ge 0 -and $end -gt $start -and $buf[$end - 1] -ne 10) {
            $lastNl = -1
            for ($j = $end - 1; $j -ge $start; $j--) {
                if ($buf[$j] -eq 10) { $lastNl = $j; break }
            }
            if ($lastNl -ge $start) { $end = $lastNl + 1 }
        }

        $dir = Split-Path $Path -Parent
        $leaf = Split-Path $Path -Leaf
        $tempPath = Join-Path $dir ($leaf + '.tmp.' + [Guid]::NewGuid().ToString('N'))
        $bakPath = Join-Path $dir ($leaf + '.bak.' + [Guid]::NewGuid().ToString('N'))
        $outFs = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $writeLen = $end - $start
        if ($writeLen -lt 0) { $writeLen = 0 }
        if ($writeLen -eq 0 -and $nl -lt 0) {
            $start = 0
            $writeLen = $got
        }
        if ($writeLen -gt 0) { $outFs.Write($buf, $start, [int]$writeLen) }
        $outFs.Dispose()
        $outFs = $null

        [System.IO.File]::Replace($tempPath, $Path, $bakPath)
        $tempPath = $null
        Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        $bakPath = $null
    } catch {
    } finally {
        if ($null -ne $fs) { try { $fs.Dispose() } catch { } }
        if ($null -ne $outFs) { try { $outFs.Dispose() } catch { } }
        if ($tempPath -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if ($bakPath -and (Test-Path -LiteralPath $bakPath)) {
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Limit-OversizedHookLogs {
    param([string]$LogDir)
    if ([string]::IsNullOrWhiteSpace($LogDir)) { return }
    if (-not (Test-Path -LiteralPath $LogDir)) { return }
    $maxBytes = 8 * 1024 * 1024
    foreach ($f in @(Get-ChildItem -LiteralPath $LogDir -File -Filter *.log -ErrorAction SilentlyContinue)) {
        if ($f.Length -gt $maxBytes) {
            Limit-HookAuditLog -Path $f.FullName
        }
    }
}

if (-not $global:AI_GATES_HOOK_LOG_SWEEP) {
    $global:AI_GATES_HOOK_LOG_SWEEP = $true
    try {
        Limit-OversizedHookLogs -LogDir (Join-Path (Get-AiGatesProjectRoot) '.ai-gates\hooks-log')
    } catch { }
}
