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
        Add-Content -LiteralPath $auditFile -Value "$ts | channel=$channel skip=true reason=$Reason" -Encoding UTF8
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
