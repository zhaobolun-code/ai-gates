# audit-write.ps1
# preToolUse hook (matcher: Write|StrReplace|EditNotebook) -- audit only, never blocks.
# Purpose: build a machine-readable timeline for Hard Gate #7 ("no PM judgment, no deliverable edit"),
# so retrospectives can check whether code/docs were touched without a prior [PM] turn.
# This version only logs a compact summary line (tool + file path), NOT full file content,
# to keep the log small and avoid leaking large diffs into a plain-text log file.
# Always returns permission=allow -- purely observational, matches the "observe first, ask/deny later" plan.

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$logDir = Join-Path $PSScriptRoot "..\hooks-log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "write-audit.log"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$toolName = "unknown"
$filePath = "unknown"
$sessionId = "unknown"

try {
    $raw = [Console]::In.ReadToEnd()
    # Cursor 有时会在 stdin JSON 前带一个 UTF-8 BOM 字符，ConvertFrom-Json 一般能容忍，这里再兜底 Trim 一次。
    $raw = $raw.TrimStart([char]0xFEFF)
    $json = $raw | ConvertFrom-Json -ErrorAction Stop

    if ($json.tool_name) { $toolName = [string]$json.tool_name }
    if ($json.session_id) { $sessionId = [string]$json.session_id }

    if ($json.tool_input) {
        if ($json.tool_input.file_path) { $filePath = [string]$json.tool_input.file_path }
        elseif ($json.tool_input.path) { $filePath = [string]$json.tool_input.path }
        elseif ($json.tool_input.target_notebook) { $filePath = [string]$json.tool_input.target_notebook }
    }
} catch {
    # 解析失败不影响放行，只是这一行日志信息不全
}

$line = "$timestamp | tool=$toolName | session=$sessionId | path=$filePath"

try {
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
} catch {
    # 日志写失败不影响正常工具调用
}

Write-Output '{"permission":"allow"}'
exit 0
