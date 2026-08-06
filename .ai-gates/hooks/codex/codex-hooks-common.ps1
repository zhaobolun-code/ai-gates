# codex-hooks-common.ps1
# Codex 版 hooks 共享库（被 .cursor/hooks/codex/ 下各脚本点源加载；本文件无 param() 块）。
#
# 2026-08-04 在 codex-cli 0.146.0-alpha.9.2 上实测确定的 Codex hook 输出契约（勿凭
# Cursor 习惯猜测）：
#   - PreToolUse 允许 = 省略 permissionDecision（permissionDecision:"allow" 会被引擎
#     判定为 unsupported → hook Failed → fail-open 放行；显式 allow 反而触发"Failed"）。
#   - PreToolUse 拒绝 = permissionDecision:"deny" + 非空 permissionDecisionReason，
#     引擎把 reason 作为 "Command blocked by PreToolUse hook: <reason>" 呈现给 Agent，
#     工具调用被硬拦截。
#   - PreToolUse 的 permissionDecision:"ask" 不支持（报 unsupported）。
#   - PostToolUse / SessionStart 可带 additionalContext 注入上下文（实测端到端可达模型）。
#   - Stop 输出无 hookSpecificOutput，返回 {} 即可。
# 输入 payload 关键字段：session_id / turn_id / cwd / hook_event_name / tool_name /
# tool_input（apply_patch 为 {"command": "<patch 文本>"}）/ tool_response /
# last_assistant_message（Stop）/ prompt（UserPromptSubmit）。

# 读取 stdin 全部内容（显式 UTF-8；与 mark-pm-gate/mark-changelog-write 同健壮模式，
# 避免超大 payload 时 PS5.1 Console.In.ReadToEnd 解析失败），并去掉可能的前导 BOM。
function Read-HookStdin {
    # 2026-08-06 合并入口（pre-*-gate.ps1）：同一事件多门禁改为单进程内依次执行，
    # stdin 只读一次并缓存到全局，后续子脚本共享同一 payload（子脚本点源本文件后
    # 仍会走此缓存，避免第二个门禁读到已耗尽的流）。
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

function Get-Property {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

# 从 apply_patch 的 tool_input.command 文本里提取目标路径（Add/Update/Delete File + Move to）。
function Get-PatchPaths {
    param([string]$CommandText)
    $paths = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return @($paths) }
    $filePat = '(?m)^\*\*\*\s+(?:Add|Update|Delete)\s+File:\s*(.+?)\s*$'
    foreach ($m in [Regex]::Matches($CommandText, $filePat)) {
        $p = $m.Groups[1].Value.Trim()
        if ($p) { $paths.Add($p) }
    }
    $movePat = '(?m)^\*\*\*\s+Move\s+to:\s*(.+?)\s*$'
    foreach ($m in [Regex]::Matches($CommandText, $movePat)) {
        $p = $m.Groups[1].Value.Trim()
        if ($p) { $paths.Add($p) }
    }
    return @($paths)
}

# 取工具调用目标路径：优先结构化字段（Cursor 兼容），否则解析 apply_patch 命令文本。
function Get-TargetPaths {
    param($ToolInput, [string]$Raw)
    $paths = New-Object System.Collections.Generic.List[string]
    if ($ToolInput) {
        foreach ($f in @('file_path', 'path', 'target_notebook')) {
            $v = Get-Property $ToolInput $f
            if ($v -and -not [string]::IsNullOrWhiteSpace([string]$v)) {
                $paths.Add([string]$v)
                return @($paths)
            }
        }
        $cmd = Get-Property $ToolInput 'command'
        if ($cmd) {
            foreach ($p in (Get-PatchPaths -CommandText ([string]$cmd))) { $paths.Add($p) }
        }
    }
    if ($paths.Count -eq 0 -and $Raw) {
        foreach ($pat in @(
                '"file_path"\s*:\s*"((?:\\.|[^"\\])*)"',
                '"path"\s*:\s*"((?:\\.|[^"\\])*)"'
            )) {
            $m = [Regex]::Match($Raw, $pat)
            if ($m.Success) {
                $paths.Add(($m.Groups[1].Value -replace '\\/', '/' -replace '\\\\', '\'))
                break
            }
        }
    }
    return @($paths)
}

# 会话 id：Codex 用 session_id（Cursor 用 conversation_id）。parse 失败兜底正则。
function Get-SessionId {
    param($Json, [string]$Raw)
    if ($Json) {
        $v = Get-Property $Json 'session_id'
        if ($v -and -not [string]::IsNullOrWhiteSpace([string]$v)) { return [string]$v }
    }
    if ($Raw) {
        $m = [Regex]::Match($Raw, '"session_id"\s*:\s*"((?:\\.|[^"\\])*)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return "unknown"
}

# 运行时日志目录：恒为 <仓库根>/.ai-gates/hooks-log。
# 2026-08-04 软连接改造：脚本可经 .cursor/hooks/codex/（junction）或 .ai-gates/hooks/codex/
# （真实路径）两种方式被调用，$PSScriptRoot 两种情况下上三级都收敛到仓库根。
function Get-LogDir {
    param([string]$ScriptRoot)
    $repoRoot = Split-Path (Split-Path (Split-Path $ScriptRoot -Parent) -Parent) -Parent
    $logDir = Join-Path $repoRoot '.ai-gates/hooks-log'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    return $logDir
}

function Write-HookAudit {
    param([string]$LogDir, [string]$FileName, [string]$Line)
    try {
        $file = Join-Path $LogDir $FileName
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $file -Value ("$ts | $Line") -Encoding UTF8
    } catch {
        # 审计失败不阻塞 hook 主流程
    }
}

# 原子写（同目录 temp + Replace），供 pm-gate.json / changelog-writes.json 复用。
function Write-JsonAtomic {
    param([string]$Path, [string]$Content)
    $dir = Split-Path $Path -Parent
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    $leaf = Split-Path $Path -Leaf
    $tempPath = Join-Path $dir ("{0}.tmp.{1}" -f $leaf, [Guid]::NewGuid().ToString('N'))
    $bakPath = Join-Path $dir ("{0}.bak.{1}" -f $leaf, [Guid]::NewGuid().ToString('N'))
    try {
        [System.IO.File]::WriteAllText($tempPath, $Content, $utf8Bom)
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($tempPath, $Path, $bakPath)
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::Move($tempPath, $Path)
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

# ---- Codex hook 输出（契约见文件头注释） ----
# 2026-08-06 语义调整：Emit-* 只返回 JSON 字符串，不再 Write-Output/exit。
#   - 终态分支：把 Emit-X 作为脚本最后一条语句（返回值自动进成功流，进程自然 exit 0）。
#   - 早退分支：调用方必须写 `Write-Output (Emit-X); exit 0`，保持与旧行为一致——
#     exit 会终止整个进程，合并入口（pre-*-gate.ps1）正依赖此语义做 deny 短路。

function Emit-PreToolUseAllow {
    return '{"hookSpecificOutput":{"hookEventName":"PreToolUse"}}'
}

function Emit-PreToolUseDeny {
    param([string]$Reason)
    $reasonSafe = (($Reason -replace '[\r\n]+', ' ').Trim())
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName           = 'PreToolUse'
            permissionDecision      = 'deny'
            permissionDecisionReason = $reasonSafe
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-PreToolUseContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'PreToolUse'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-PostToolUseEmpty {
    return '{"hookSpecificOutput":{"hookEventName":"PostToolUse"}}'
}

function Emit-PostToolUseContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'PostToolUse'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-SessionStartEmpty {
    return '{"hookSpecificOutput":{"hookEventName":"SessionStart"}}'
}

function Emit-SessionStartContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'SessionStart'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-StopEmpty {
    return '{}'
}
