# plugin/invoke.ps1 — Cursor 市场插件门禁入口（薄包装）。
# 两套 hooks 都可声明；本进程有 CURSOR_PLUGIN_ROOT 且项目 .cursor/hooks 已落地时
# 立刻 allow，不跑门禁本体（避免与项目 hooks 跑两遍）。
# sessionStart 种库不走本入口，见 scripts/ensure-plugin-seed.ps1。
#
# Usage (plugin-hooks.json):
#   powershell -NoProfile -ExecutionPolicy Bypass -File "${CURSOR_PLUGIN_ROOT}/.ai-gates/hooks/plugin/invoke.ps1" -Target pre-write-gate

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('git-safety-check', 'pre-write-gate', 'post-write-gate', 'mark-pm-gate')]
    [string]$Target
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$hooksDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $hooksDir 'cursor-hooks-common.ps1')

if (-not (Test-AiGatesShouldRunHook)) {
    Write-Output '{"permission":"allow"}'
    exit 0
}

$targetPath = Join-Path $hooksDir ($Target + '.ps1')
if (-not (Test-Path -LiteralPath $targetPath)) {
    Write-Output '{"permission":"allow"}'
    exit 0
}

& $targetPath
exit $LASTEXITCODE
