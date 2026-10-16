# task-model-gate.ps1
# preToolUse matcher Task: 流水线岗位未写 model 或写成 inherit 时拒绝。
# Cursor 省略 model 即 inherit，子窗复制主窗模型。探索类子窗放行。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

function Write-Allow {
    Write-Output '{"permission":"allow"}'
    exit 0
}

if (-not (Test-AiGatesShouldRunHook)) { Write-Allow }

$raw = Read-HookStdin
if ([string]::IsNullOrWhiteSpace($raw)) { Write-Allow }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Write-Allow
}

$tool = [string]$payload.tool_name
if ([string]::IsNullOrWhiteSpace($tool) -and $payload.tool) { $tool = [string]$payload.tool }
try {
    $root = Get-AiGatesProjectRoot
    $logDir = Join-Path $root '.ai-gates\hooks-log'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath (Join-Path $logDir 'task-model-gate.log') -Value "$ts | tool=$tool" -Encoding UTF8
} catch { }
if ($tool -ne 'Task' -and $tool -ne 'Agent' -and $tool -ne 'CallDynamicTool') { Write-Allow }

$inputObj = $payload.tool_input
if (-not $inputObj) { $inputObj = $payload.input }
if ($inputObj -is [string]) {
    try { $inputObj = $inputObj | ConvertFrom-Json } catch { $inputObj = $null }
}
if (-not $inputObj -and $payload.arguments) { $inputObj = $payload.arguments }
if (-not $inputObj) { Write-Allow }
if ($tool -eq 'CallDynamicTool') {
    $called = ''
    if ($inputObj.PSObject.Properties['toolName']) { $called = [string]$inputObj.toolName }
    if ($called -ne 'Task') { Write-Allow }
    if ($inputObj.PSObject.Properties['arguments']) { $inputObj = $inputObj.arguments }
}

$model = ''
$type = ''
$blob = ''
if ($inputObj.PSObject.Properties['model']) { $model = [string]$inputObj.model }
if ($inputObj.PSObject.Properties['subagent_type']) { $type = [string]$inputObj.subagent_type }
foreach ($name in @('description', 'prompt')) {
    if ($inputObj.PSObject.Properties[$name]) { $blob += ' ' + [string]$inputObj.$name }
}

$inherit = [string]::IsNullOrWhiteSpace($model) -or ($model.Trim().ToLowerInvariant() -eq 'inherit')
if (-not $inherit) { Write-Allow }

$pipelineType = @('developer', 'code-reviewer', 'planner', 'plan-reviewer', 'module-readme')
$isPipeline = $pipelineType -contains $type.Trim().ToLowerInvariant()
if (-not $isPipeline) {
    $isPipeline = $blob -match '程序员|代码审核|代码审|方案审|策划|验收|\[developer\]|\[CR\]|\[planner\]|\[plan-reviewer\]|\[docs\]'
}
if (-not $isPipeline) { Write-Allow }

$msg = 'Task model is missing or inherit, so the subagent copies the main window. Pass model= from .cursor/project-context.md section 模型路由. Programmer (Standard and above) uses cursor-grok-4.6-high. Planner, plan review, code review, and verify use grok-4.7-high. Do not omit model. Do not pass inherit.'
$result = @{
    permission    = 'deny'
    user_message  = $msg
    agent_message = 'preToolUse Task: pipeline role without explicit model; deny inherit.'
}
Write-Output ($result | ConvertTo-Json -Compress)
exit 0
