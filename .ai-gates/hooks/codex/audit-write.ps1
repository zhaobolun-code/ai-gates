# audit-write.ps1 -- Codex 版
# PreToolUse hook (matcher: ^apply_patch$) -- audit only, never blocks.
#
# Cursor 原版 matcher 是 Write|StrReplace|EditNotebook；Codex 文件写入工具为 apply_patch
# （tool_input.command 含 patch 文本），路径从 patch 文本提取。本版本只记录紧凑摘要行
# （tool + session_id + path），不记录文件内容，避免日志膨胀与泄漏大 diff。
# 恒 allow（省略 permissionDecision —— Codex 显式 allow 不受支持，见 common 文件头）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

$raw = Read-HookStdin
$toolName = "unknown"
$sessionId = "unknown"
$paths = @()
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($json.tool_name) { $toolName = [string]$json.tool_name }
    $sessionId = Get-SessionId -Json $json -Raw $raw
    $paths = @(Get-TargetPaths -ToolInput $json.tool_input -Raw $raw)
} catch {
    # 解析失败不影响放行，只是日志信息不全
}

foreach ($p in $paths) {
    Write-HookAudit -LogDir $LogDir -FileName 'write-audit.log' -Line ("tool={0} | session={1} | path={2}" -f $toolName, $sessionId, $p)
}
if ($paths.Count -eq 0) {
    Write-HookAudit -LogDir $LogDir -FileName 'write-audit.log' -Line ("tool={0} | session={1} | path=<none-extracted>" -f $toolName, $sessionId)
}

Emit-PreToolUseAllow
