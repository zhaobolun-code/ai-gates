# claude-hooks-common.ps1
# Claude Code 版 hooks 共享库（被 .ai-gates/hooks/claude/ 下各脚本点源加载；本文件无 param() 块）。
#
# 2026-08-10 依据 Claude Code 官方 hooks 文档写的输出契约（与 Codex 版 codex-hooks-common.ps1
# 同源；字段名差异与真机验证点见下，勿凭 Codex/Cursor 习惯猜测）：
#   - PreToolUse 允许 = permissionDecision:"allow"（显式 allow 受支持；省略即默认 allow，
#     与 Codex 的"显式 allow 报 unsupported"相反）。
#   - PreToolUse 拒绝 = permissionDecision:"deny" + 非空 permissionDecisionReason，引擎把
#     reason 作为 "Blocked by PreToolUse hook: <reason>" 呈现给 Agent，工具调用被硬拦截。
#   - PreToolUse 支持 permissionDecision:"ask"（须带 reason，引擎转交用户确认）；本套门禁不用。
#   - 输出字段名 = hook_event_name（snake_case）；Codex 版是 hookEventName（camelCase）。
#     真机验证点 #1：官方文档字段为 snake_case，待实机确认（字段错则 hook 输出被忽略/报错）。
#   - PostToolUse / SessionStart 可带 additionalContext 注入上下文。
#   - Stop 输出无 hookSpecificOutput，返回 {} 即可。
#   - exit 0 = 引擎解析 stdout JSON；exit 2 = 阻塞错误（本套脚本恒 exit 0，fail-open）。
# 输入 payload 关键字段（Claude Code）：session_id / transcript_path / hook_event_name /
# tool_name / tool_input（Write=file_path+content；Edit=file_path+old_string+new_string；
# MultiEdit=file_path+edits[]；NotebookEdit=notebook_path+...；Bash=command）/
# tool_use_id / stop_hook_active（Stop）。
# 真机验证点 #2：PreToolUse 输入含 session_id（pm-gate.json 按它分桶）；官方文档如此，待实机确认。
# 真机验证点 #3：Stop 输入无 last_assistant_message（与 Codex 不同），mark-pm-gate 改为读
# transcript_path 的会话 JSONL 取最后一条助手文本（见 mark-pm-gate.ps1 头注释）。

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

# 从 Bash 工具的 tool_input.command 文本里提取 apply_patch 风格目标路径（兼容保留；
# Claude Code 无 apply_patch 工具，MultiEdit/Edit 路径走结构化字段）。
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

# 取工具调用目标路径：优先结构化字段（Write/Edit=file_path，MultiEdit=file_path，
# NotebookEdit=notebook_path），否则回退 raw 正则。Claude Code 各写工具输入都是结构化字段。
function Get-TargetPaths {
    param($ToolInput, [string]$Raw)
    $paths = New-Object System.Collections.Generic.List[string]
    if ($ToolInput) {
        foreach ($f in @('file_path', 'notebook_path', 'path', 'target_notebook')) {
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
                '"path"\s*:\s*"((?:\\.|[^"\\])*)"',
                '"notebook_path"\s*:\s*"((?:\\.|[^"\\])*)"'
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

# 会话 id：Claude Code 用 session_id。parse 失败兜底正则。
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
# 2026-08-10 Claude 版：脚本位于 .ai-gates/hooks/claude/（真实路径），$PSScriptRoot
# 上三级收敛到仓库根（与 Codex 版同算；Claude 侧不经 junction 调用脚本本身）。
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

# ---- Claude Code hook 输出（契约见文件头注释） ----
# 2026-08-10 语义：Emit-* 只返回 JSON 字符串，不再 Write-Output/exit。
#   - 终态分支：把 Emit-X 作为脚本最后一条语句（返回值自动进成功流，进程自然 exit 0）。
#   - 早退分支：调用方必须写 `Write-Output (Emit-X); exit 0`，保持与旧行为一致——
#     exit 会终止整个进程，合并入口（pre-*-gate.ps1）正依赖此语义做 deny 短路。
#   - 与 Codex 版的唯一结构性差异：字段名 hook_event_name（snake_case）+ 显式 allow 受支持。

function Emit-PreToolUseAllow {
    return '{"hookSpecificOutput":{"hook_event_name":"PreToolUse","permissionDecision":"allow"}}'
}

function Emit-PreToolUseDeny {
    param([string]$Reason)
    $reasonSafe = (($Reason -replace '[\r\n]+', ' ').Trim())
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hook_event_name          = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reasonSafe
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-PreToolUseContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hook_event_name   = 'PreToolUse'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-PostToolUseEmpty {
    return '{"hookSpecificOutput":{"hook_event_name":"PostToolUse"}}'
}

function Emit-PostToolUseContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hook_event_name   = 'PostToolUse'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-SessionStartEmpty {
    return '{"hookSpecificOutput":{"hook_event_name":"SessionStart"}}'
}

function Emit-SessionStartContext {
    param([string]$Context)
    $obj = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hook_event_name   = 'SessionStart'
            additionalContext = $Context
        }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 6)
}

function Emit-StopEmpty {
    return '{}'
}
