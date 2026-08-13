# mark-changelog-write.ps1 -- Claude Code 版
# PostToolUse hook (matcher: ^(Write|Edit|MultiEdit|NotebookEdit)$) -- 自我治理轻门禁打点（观测，不拦截）。
#
# 与 Codex 版同源（2026-08-10 复制改写）：Claude Code 写工具路径走结构化字段
# （file_path / notebook_path，见 Get-TargetPaths）。把"这一轮写操作的目标是
# .ai-gates/CHANGELOG.md"落盘到 .ai-gates/hooks-log/changelog-writes.json
# （按 session_id 记 lastChangelogWriteAtUtc），供 pm-gate-check.ps1（PreToolUse）的
# Level 1 轻门禁读取。
#
# 为什么用 PostToolUse：与 Cursor 版一致——preToolUse 多个 hook 并行执行时序不可保证，
# 打点必须放"写后事件"证明"已写"而非"打算写"；matcher 只是事件过滤，CHANGELOG 判定在脚本内做。
# 纯观测、无拦截语义：一切异常 exit 0（fail-open）。

param(
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'claude-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }
$changelogFile = Join-Path $LogDir 'changelog-writes.json'

$raw = Read-HookStdin
$sessionId = "unknown"
$paths = @()
$isChangelog = $false
$wrote = "none"

try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $sessionId = Get-SessionId -Json $json -Raw $raw
    $paths = @(Get-TargetPaths -ToolInput $json.tool_input -Raw $raw)
} catch {
    $sessionId = Get-SessionId -Json $null -Raw $raw
    $paths = @(Get-TargetPaths -ToolInput $null -Raw $raw)
}

# CHANGELOG 判定：大小写不敏感，路径可含 .cursor/skills/ 前缀
foreach ($p in $paths) {
    if ($p -match '(?i)(?:^|[\\/])changelog\.md$') {
        $isChangelog = $true
        break
    }
}

if ($isChangelog) {
    $records = [ordered]@{}
    if (Test-Path -LiteralPath $changelogFile) {
        try {
            $existingRaw = [System.IO.File]::ReadAllText($changelogFile, [System.Text.Encoding]::UTF8)
            $existing = $existingRaw | ConvertFrom-Json -ErrorAction Stop
            $existing.PSObject.Properties | ForEach-Object { $records[$_.Name] = $_.Value }
        } catch {
            # 旧文件损坏就当空表重建，不阻塞
        }
    }
    $records[$sessionId] = [ordered]@{
        lastChangelogWriteAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $json2 = $records | ConvertTo-Json -Depth 6
    Write-JsonAtomic -Path $changelogFile -Content $json2
    $wrote = "changelog-writes.json"
}

Write-HookAudit -LogDir $LogDir -FileName 'mark-changelog-write.log' -Line ("session={0} paths={1} isChangelog={2} wrote={3}" -f $sessionId, ($paths -join ','), $isChangelog, $wrote)
Emit-PostToolUseEmpty
