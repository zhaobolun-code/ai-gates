# test-ensure-project-context-sections.ps1
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "ensure-project-context-sections.ps1"
$template = Join-Path $PSScriptRoot "..\skills\project-context.template.md"
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("ensure-pc-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path (Join-Path $root ".cursor") | Out-Null
$ctx = Join-Path $root ".cursor\project-context.md"
$failed = 0

function Assert-Case([string]$Name, [bool]$Ok, [string]$Detail) {
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

$old = @"
# 项目上下文

## 技术栈

- 引擎：Unity

## 模型路由（必填）

| 岗位 | Task ``model`` |
| --- | --- |
| 程序员 | ``keep-this`` |
"@
[System.IO.File]::WriteAllText($ctx, $old.Replace("`n", "`r`n"), (New-Object System.Text.UTF8Encoding $true))
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoRoot $root -ContextPath $ctx -TemplatePath $template
$text = [System.IO.File]::ReadAllText($ctx)
Assert-Case "old file gains three sections" ($text.Contains("## 常用命令") -and $text.Contains("## 仓库分仓") -and $text.Contains("## 客户端事实")) $text
Assert-Case "old file gains index" ($text.Contains("## 先读哪一节") -and $text.Contains("| 常用命令 |")) ""
Assert-Case "model row kept" ($text.Contains("keep-this")) ""
$once = $text
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoRoot $root -ContextPath $ctx -TemplatePath $template
$twice = [System.IO.File]::ReadAllText($ctx)
Assert-Case "second run does not duplicate" ($once -eq $twice) ""

$partial = @"
# 项目上下文

## 先读哪一节

| 这一轮在做 | 读 |
| --- | --- |
| 派子窗，要写 model= | 模型路由 |
| 对上了别的标题 | 只读那一节 |

## 常用命令

已有命令，不要换成模板。

## 模型路由

保持。
"@
[System.IO.File]::WriteAllText($ctx, $partial, (New-Object System.Text.UTF8Encoding $false))
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoRoot $root -ContextPath $ctx -TemplatePath $template
$text = [System.IO.File]::ReadAllText($ctx)
Assert-Case "keeps filled command section" ($text.Contains("已有命令，不要换成模板。") -and ([regex]::Matches($text, "## 常用命令")).Count -eq 1) ""
Assert-Case "adds missing sections only" ($text.Contains("## 仓库分仓") -and $text.Contains("## 客户端事实")) ""
Assert-Case "index rows land before the catch-all" (($text.IndexOf("| 仓库分仓 |") -ge 0) -and ($text.IndexOf("| 仓库分仓 |") -lt $text.IndexOf("对上了别的标题")) -and ($text.IndexOf("| 常用命令 |") -lt $text.IndexOf("对上了别的标题"))) ""

$named = @"
# 项目上下文

## 先读哪一节

| 这一轮在做 | 读 |
| --- | --- |
| 改 Claude 钩子或核对接线 | Claude 侧事实 |
| 编译、跑测试、黄金回归、同步回归索引 | 常用命令 |
| 要看仓库怎么分仓 | 仓库分仓 |

## 常用命令

本仓命令。

## 仓库分仓

本仓分仓。

## Claude 侧事实

本仓客户端。
"@
[System.IO.File]::WriteAllText($ctx, $named, (New-Object System.Text.UTF8Encoding $false))
$before = [System.IO.File]::ReadAllText($ctx)
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -RepoRoot $root -ContextPath $ctx -TemplatePath $template
$after = [System.IO.File]::ReadAllText($ctx)
Assert-Case "claude section counts as client facts" ($before -eq $after -and -not $after.Contains("## 客户端事实")) ""

Remove-Item -LiteralPath $root -Recurse -Force
if ($failed -gt 0) { exit 1 }
Write-Host "ensure-project-context-sections: all passed"
exit 0
