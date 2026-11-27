# 知识缺口三要素：缺上下文或已尝试则拒绝；分歧来源缺洞种三行则拒绝。
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "check-knowledge-gap.ps1"
$failed = 0
function Assert-Gap {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}
$good = @"
### KG-1 阀门方向不确定
- 上下文位置：Valve.cs / 12 / Step 1
- 已尝试：读过 Valve.cs 的方向字段
"@
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Text $good | Out-Null
Assert-Gap "three fields pass" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
$bad = @"
### KG-2 只写了问题
- 已尝试：
"@
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Text $bad | Out-Null
Assert-Gap "empty tried fails" ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
$div = @"
### KG-3 来源：分歧标注
- 上下文位置：DA-01
- 已尝试：对照了两条链
"@
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Text $div | Out-Null
Assert-Gap "divergence without hole lines fails" ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
if ($failed -gt 0) { exit 1 }
exit 0
