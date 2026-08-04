# check-unity-compile.ps1 -- Codex 版
# PostToolUse hook (matcher: ^apply_patch$) — 写后质量门。
#
# Cursor 原版 matcher 是 Write|StrReplace|EditNotebook，路径来自 tool_input.file_path；
# Codex 文件写入工具为 apply_patch，路径从 patch 文本提取。Agent 写完 .cs/.lua 后，扫最近
# Unity Editor.log 的编译错误（error CS\d{4}），命中 → 注入 additionalContext（实测可达模型）
# + 写审计行 .ai-gates/hooks-log/unity-compile-check.log；无错误 / 日志缺失 / 非代码路径 /
# 解析异常 → 恒 allow（stdout 输出 hookEventName 空壳），不拦截任何写操作。
#
# 职责边界（与 Cursor 版一致）：本 hook 不做 batchmode、不启动 Unity、不做业务 keywords
# 断言——那是 run-unity-verify-golden.ps1 与 verify-runtime-evidence.ps1 的职责。
param(
    [string]$EditorLogPath = "$env:LOCALAPPDATA\Unity\Editor\Editor.log",
    [string]$LogDir = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'codex-hooks-common.ps1')

if (-not $LogDir) { $LogDir = Get-LogDir -ScriptRoot $PSScriptRoot }

# 新鲜度窗口：日志最后写入距今 ≤ 该分钟数才视为"最近写入"
$SinceMinutes = 30

$raw = Read-HookStdin
$paths = @()
try {
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
    $paths = @(Get-TargetPaths -ToolInput $json.tool_input -Raw $raw)
} catch {
    # 解析异常 fail-open：不拦写操作
    Emit-PostToolUseEmpty
}

# matcher 是工具名过滤，路径过滤必须在脚本内做：仅 .cs/.lua 代码路径继续
$codePaths = @($paths | Where-Object { $_ -match '\.(cs|lua)$' })
if ($codePaths.Count -eq 0) {
    Emit-PostToolUseEmpty
}

# 日志缺失 → 静默 allow
if (-not (Test-Path -LiteralPath $EditorLogPath)) {
    Emit-PostToolUseEmpty
}

$compileErrorLines = @()
try {
    $logFile = Get-Item -LiteralPath $EditorLogPath
    $ageMinutes = [Math]::Round(([DateTime]::UtcNow - $logFile.LastWriteTimeUtc).TotalMinutes, 1)
    if ($ageMinutes -le $SinceMinutes) {
        $lines = @(Get-Content -LiteralPath $EditorLogPath -Encoding UTF8 -ErrorAction SilentlyContinue |
            ForEach-Object { [string]$_ })
        $compileErrorLines = @($lines | Where-Object { $_ -match "error CS\d{4}" } | Select-Object -Last 20)
    }
} catch {
    # 读取/解析异常 fail-open
    Emit-PostToolUseEmpty
}

if ($compileErrorLines.Count -eq 0) {
    Write-HookAudit -LogDir $LogDir -FileName 'unity-compile-check.log' -Line ("OK no_compile_error paths={0}" -f ($codePaths -join ','))
    Emit-PostToolUseEmpty
}

Write-HookAudit -LogDir $LogDir -FileName 'unity-compile-check.log' -Line ("HIT compile_error count={0} first={1}" -f $compileErrorLines.Count, $compileErrorLines[0])

$ctx = @"
[unity-compile-check] PostToolUse 检测到最近 Unity Editor.log 含编译错误（$($compileErrorLines.Count) 条），写后质量门提示请先修复：
- $($compileErrorLines -join "`n- ")
改动文件：$($codePaths -join ', ')
轻量提示、不拦截写入；golden 验窗仍由 run-unity-verify-golden.ps1 验收驱动。
"@
Emit-PostToolUseContext -Context $ctx
