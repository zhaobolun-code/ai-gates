# audit-write.ps1 -- Claude Code 版
# PreToolUse hook (matcher: ^(Write|Edit|MultiEdit|NotebookEdit)$) -- audit only, never blocks.
#
# 与 Codex 版同源（2026-08-10 复制改写）：Claude Code 写工具输入是结构化字段
# （Write/Edit/MultiEdit=file_path，NotebookEdit=notebook_path），由 Get-TargetPaths 提取。
# 本版本只记录紧凑摘要行（tool + session_id + path），不记录文件内容，避免日志膨胀与泄漏大 diff。
# 恒 allow（显式 permissionDecision:allow，见 common 文件头契约）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

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
