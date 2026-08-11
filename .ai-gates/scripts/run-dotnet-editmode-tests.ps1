# run-dotnet-editmode-tests.ps1
# TDD Step 1（M3）：外部 dotnet NUnit 测试跑批（替代原 run-unity-editmode-tests.ps1）。
# 语义：dotnet restore + dotnet test（trx 落到 .ai-gates/verify/），解析 <ResultSummary>：
#   outcome=Passed|Completed && failed=0 && total>=70 → exit 0（绿灯）
#   其余（含 no-match 空跑 total=0 / 真实失败 / trx 缺失 / restore 失败）→ exit 1/2（红灯）
# 注意：dotnet test 自身对「过滤器无匹配」返回 0（VSTest 视为通过），故以 trx 为准、
# 并强制 total>=70 守卫，防假绿。
# 可选 -Filter <VSTest 表达式>：仅用于反假绿验证（A7），默认不带过滤器跑全量。

param(
    [string]$Filter = ''
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path -Parent (Split-Path -Parent $scriptDir)   # .ai-gates/scripts -> 仓库根
$verifyDir = Join-Path $repoRoot '.ai-gates\verify'
$csproj    = Join-Path $repoRoot 'Tests\EditMode\EditMode.Tests.csproj'
$trxName   = 'editmode-tests.trx'
$trxPath   = Join-Path $verifyDir $trxName

if (-not (Test-Path $csproj)) {
    Write-Error "csproj 不存在: $csproj"
    exit 1
}
New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null

# ── restore ──
& dotnet restore $csproj
if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet restore 失败 (exit=$LASTEXITCODE)"
    exit 1
}

# ── test（trx 定向输出到 verify 目录）──
Remove-Item $trxPath -ErrorAction SilentlyContinue
if ($Filter -ne '') {
    & dotnet test $csproj --filter $Filter --results-directory $verifyDir --logger "trx;LogFileName=$trxName"
} else {
    & dotnet test $csproj --results-directory $verifyDir --logger "trx;LogFileName=$trxName"
}
# 不信任 dotnet test 自身退出码（无匹配过滤器时 VSTest 返回 0），以 trx 解析为准

# ── 解析 trx <ResultSummary> ──
if (-not (Test-Path $trxPath)) {
    Write-Error "trx 未生成: $trxPath"
    exit 1
}
try {
    [xml]$trx = Get-Content $trxPath -Raw
} catch {
    Write-Error "trx 解析失败: $($_.Exception.Message)"
    exit 1
}
$summary = $trx.TestRun.ResultSummary
$outcome = $summary.outcome
$counters = $summary.Counters
$total  = [int]$counters.total
$passed = [int]$counters.passed
$failed = [int]$counters.failed
$skipped = [int]$counters.skipped

Write-Host ("EditMode tests: outcome={0} total={1} passed={2} failed={3} skipped={4} (trx: {5})" -f $outcome, $total, $passed, $failed, $skipped, $trxPath)

# VSTest trx 实录：干净运行 outcome="Completed"（Passed 仅在部分适配器出现），以 failed=0 为准
if (($outcome -eq 'Passed' -or $outcome -eq 'Completed') -and $failed -eq 0 -and $total -ge 70) {
    exit 0
}
if ($failed -gt 0) {
    Write-Error "存在失败用例 (failed=$failed)"
    exit 2
}
if ($total -lt 70) {
    Write-Error "用例总数不足 (total=$total < 70)，疑似空跑/假绿"
    exit 2
}
Write-Error "trx outcome 非 Passed/Completed (outcome=$outcome)"
exit 1
