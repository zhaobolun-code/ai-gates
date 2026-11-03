# mark-changelog-write.ps1
# postToolUse hook (matcher: Write|StrReplace|EditNotebook) -- 自我治理轻门禁打点（观测，不拦截）。
#
# 目的：把"这一轮写操作的目标是 .ai-gates/CHANGELOG.md"这件事落盘到
# .ai-gates/hooks-log/changelog-writes.json（按 conversation_id 记 lastChangelogWriteAtUtc），
# 供 pm-gate-check.ps1（preToolUse）的 Level 1 轻门禁读取：会话内最近 N 分钟写过
# CHANGELOG → 写 .cursor/skills|hooks|scripts|rules|hooks.json 设施 allow；无 → deny。
# Level 1 放行只证明本会话 120 分钟内写过正式 .ai-gates/CHANGELOG.md，
# 不证明条目描述了即将修改的文件或内容。打点不绑到文件范围或变更摘要。
#
# 为什么用 postToolUse：preToolUse 多个 hook 并行执行时序不可保证（audit-write 落盘
# 可能晚于 pm-gate-check 读取），打点必须放"写后事件"（postToolUse），证明"已写"
# 而非"打算写"；matcher 只是事件过滤，CHANGELOG 判断必须在脚本内做。
#
# 2026-08-03 健壮化（诊断插桩 → 修复，真演复现）：
#   真实 Cursor 环境对超大 stdin（写大文件全文，~81KB）调用时，PS5.1 的
#   [Console]::In.ReadToEnd() + ConvertFrom-Json 解析失败，导致打点不落盘、
#   Level 1 轻门禁误拦（changelog-writes.json 缺失 → deny）。
#   修复：① 读取改 [Console]::OpenStandardInput() + StreamReader 显式 UTF-8；
#         ② ConvertFrom-Json 失败时 fallback 正则提取 conversation_id + file_path，
#            路径匹配 changelog.md 仍照常打点——打点链路不因 parse 失败而断。
#   PARSE_FAIL 审计插桩保留，便于后续收敛。
#
# 复用 mark-pm-gate.ps1 的 Write-GateAtomic 原子写模式（同目录 temp + Replace）+ 审计风格。
# 纯观测、无拦截语义：一切异常 exit 0（fail-open，与 MAINTAINER 已知限制 #1 同哲学）。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
. (Join-Path $PSScriptRoot 'gate-decision.ps1')

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$repoRoot = Get-AiGatesProjectRoot
$logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$changelogFile = Join-Path $logDir "changelog-writes.json"
$auditFile = Join-Path $logDir "mark-changelog-write.log"

# mark-changelog-write.log 超过 8MB 时，只从末尾读 2MB 写回（不把整文件装进内存）。
# 截断失败必须吞掉，不得阻断后续 Add-Content / exit 0。
function Limit-MarkChangelogAuditLog {
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
        # 截断失败不阻断调用方追加
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

function Write-Audit {
    param([string]$Line)
    try { Limit-MarkChangelogAuditLog -Path $auditFile } catch { }
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
        # 审计失败不阻塞 exit 0
    }
}

function Write-GateAtomic {
    param([string]$Content)
    $tempPath = Join-Path $logDir ("changelog-writes.json.tmp." + [Guid]::NewGuid().ToString("N"))
    $bakPath = Join-Path $logDir ("changelog-writes.json.bak." + [Guid]::NewGuid().ToString("N"))
    try {
        [System.IO.File]::WriteAllText($tempPath, $Content, $utf8Bom)
        if (Test-Path -LiteralPath $changelogFile) {
            [System.IO.File]::Replace($tempPath, $changelogFile, $bakPath)
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::Move($tempPath, $changelogFile)
        }
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $bakPath) {
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# 打点落盘（主路径与 parse fallback 共用）：合并既有记录 + 写当前会话
function Write-ChangelogMark {
    param([string]$ConvId)
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
    $records[$ConvId] = [ordered]@{
        lastChangelogWriteAtUtc = [DateTime]::UtcNow.ToString("o")
    }
    $json2 = $records | ConvertTo-Json -Depth 6
    Write-GateAtomic -Content $json2
}

# 正则提取路径（parse 失败兜底；与 pm-gate-check.ps1 的 Get-PathFromRaw 同思路）
function Get-PathFromRaw {
    param([string]$Raw)
    return Get-HookTargetPathFromRaw -Raw $Raw
}

# 正则提取会话 id（parse 失败兜底）
function Get-ConversationIdFromRaw {
    param([string]$Raw)
    $m = [Regex]::Match($Raw, '"conversation_id"\s*:\s*"((?:\\.|[^"\\])*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

$conversationId = "unknown"
$targetPath = $null
$isChangelog = $false
$wrote = "none"

try {
    # 读取 stdin：共享 Read-HookStdin（OpenStandardInput + StreamReader 显式 UTF-8 +
    # 全局缓存，合并入口预读一次后子脚本共享同一 payload）。
    $raw = Read-HookStdin
    $json = $raw | ConvertFrom-Json -ErrorAction Stop

    $conversationId = if ($json.conversation_id) { [string]$json.conversation_id } else { "unknown" }

    if ($json.tool_input) {
        if ($json.tool_input.file_path) { $targetPath = [string]$json.tool_input.file_path }
        elseif ($json.tool_input.path) { $targetPath = [string]$json.tool_input.path }
        elseif ($json.tool_input.target_notebook) { $targetPath = [string]$json.tool_input.target_notebook }
    }

    # 只有 .ai-gates/CHANGELOG.md 打点。子目录里的同名文件不算。
    if (Test-OfficialChangelogPath -FilePath $targetPath) {
        $isChangelog = $true
        Write-ChangelogMark -ConvId $conversationId
        $wrote = "changelog-writes.json"
    }
} catch {
    # parse 失败（真实大 payload 场景）：fallback 正则提取 conversation_id + path，
    # 路径匹配 changelog.md 仍照常打点——打点链路不因 parse 失败而断。
    # PARSE_FAIL 插桩保留用于收敛（err 区分 JSON 语法错 vs 读取/编码异常）。
    try {
        $rawStr = [string]$raw
        $fallbackConv = Get-ConversationIdFromRaw -Raw $rawStr
        if ($fallbackConv) { $conversationId = $fallbackConv }
        $fallbackPath = Get-PathFromRaw -Raw $rawStr
        if ($fallbackPath) { $targetPath = $fallbackPath }

        if (Test-OfficialChangelogPath -FilePath $targetPath) {
            $isChangelog = $true
            Write-ChangelogMark -ConvId $conversationId
            $wrote = "changelog-writes.json"
        } else {
            $wrote = "fallback_no_match"
        }

        $errMsg = ($_.Exception.Message -replace '\r?\n', ' ')
        $rawLen = if ($null -eq $raw) { -1 } elseif ($raw -is [string]) { $raw.Length } else { -2 }
        Write-Audit "PARSE_FAIL rawLen=$rawLen err=$errMsg conv=$conversationId path=$targetPath"
    } catch {
        $wrote = "error"
    }
}

Write-Audit "conversation=$conversationId path=$targetPath isChangelog=$isChangelog wrote=$wrote"

# postToolUse 无 permission 字段语义；正常退出即可
exit 0
