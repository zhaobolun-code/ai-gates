# check-unity-compile.ps1
# postToolUse hook (matcher: Write|StrReplace|EditNotebook) — 写后质量门。
#
# 目的：Agent 写完 .cs/.lua 后，扫最近 Unity Editor.log 的编译错误（error CS\d{4}），
# 命中 → 注入 additional_context（+ additionalContext 兼容）提示 + 写审计行
# .cursor/hooks-log/unity-compile-check.log；无错误 / 日志缺失 / 非代码路径 /
# 解析异常 → 恒 allow（stdout 输出 {}），不拦截任何写操作。
#
# 职责边界（与黄金验窗分离）：本 hook 不做 batchmode、不启动 Unity、不做业务
# keywords 断言——那是 run-unity-verify-golden.ps1（验收驱动黄金验窗）与
# verify-runtime-evidence.ps1（运行时取证）的职责。本 hook 仅轻量提示编译错误。
#
# failClosed 须为 false；任何异常 fail-open 输出 {} 退出 0（MAINTAINER 已知限制 #3）。

param(
    [string]$EditorLogPath = "$env:LOCALAPPDATA\Unity\Editor\Editor.log"
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# 新鲜度窗口：复用 verify-runtime-evidence 的新鲜度思路（日志最后写入距今 ≤ 该分钟数
# 才视为"最近写入"，避免把几天前的旧编译错误误报成当前写入导致的问题）。
$SinceMinutes = 30

function Write-Audit {
    param([string]$Line)
    try {
        $hooksDir = Join-Path $PSScriptRoot ".."
        $logDir = Join-Path $hooksDir "hooks-log"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $auditFile = Join-Path $logDir "unity-compile-check.log"
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
    }
}

function Emit-Empty {
    Write-Output "{}"
    exit 0
}

$raw = ""
$json = $null
try {
    $raw = [Console]::In.ReadToEnd()
    $raw = $raw.TrimStart([char]0xFEFF)
    $json = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    # 解析异常 fail-open：不拦写操作（与 pm-gate-check.ps1 一致）
    Emit-Empty
}

$filePath = $null
if ($json.tool_input) {
    if ($json.tool_input.file_path) { $filePath = [string]$json.tool_input.file_path }
    elseif ($json.tool_input.path) { $filePath = [string]$json.tool_input.path }
    elseif ($json.tool_input.target_notebook) { $filePath = [string]$json.tool_input.target_notebook }
}

# matcher 是工具名过滤，路径过滤必须在脚本内做：仅 .cs/.lua 代码路径继续
if (-not $filePath -or $filePath -notmatch '\.(cs|lua)$') {
    Emit-Empty
}

# 日志缺失 → 静默 allow（不阻塞写操作）
if (-not (Test-Path -LiteralPath $EditorLogPath)) {
    Emit-Empty
}

$compileErrorLines = @()
try {
    # 新鲜度：日志最后写入距今超过窗口 → 视为过期，不误报
    $logFile = Get-Item -LiteralPath $EditorLogPath
    $ageMinutes = [Math]::Round(([DateTime]::UtcNow - $logFile.LastWriteTimeUtc).TotalMinutes, 1)
    if ($ageMinutes -le $SinceMinutes) {
        $lines = @(Get-Content -LiteralPath $EditorLogPath -Encoding UTF8 -ErrorAction SilentlyContinue |
            ForEach-Object { [string]$_ })
        $compileErrorLines = @($lines | Where-Object { $_ -match "error CS\d{4}" } | Select-Object -Last 20)
    }
} catch {
    # 读取/解析异常 fail-open
    Emit-Empty
}

if ($compileErrorLines.Count -eq 0) {
    Write-Audit "OK no_compile_error path=$filePath"
    Emit-Empty
}

Write-Audit ("HIT compile_error count={0} path={1} first={2}" -f $compileErrorLines.Count, $filePath, $compileErrorLines[0])

$ctx = @"
[unity-compile-check] PostToolUse 检测到最近 Unity Editor.log 含编译错误（$($compileErrorLines.Count) 条），写后质量门提示请先修复：
- $($compileErrorLines -join "`n- ")
改动文件：$filePath
轻量提示、不拦截写入；golden 验窗仍由 run-unity-verify-golden.ps1 验收驱动。
"@
$result = [ordered]@{
    additional_context = $ctx
    additionalContext  = $ctx
}
Write-Output ($result | ConvertTo-Json -Compress)
exit 0
