# dispatch-l1.5-cr.ps1 - Generate L1.5 independent CR first message for NEW Chat
param(
    [Parameter(Mandatory = $true)]
    [string]$DocPath,
    [string]$Step = "Step 1",
    [string]$StepName = "",
    [string[]]$MandatoryFiles = @(),
    [string]$RegressionModule = "",
    [string]$RegressionScenario = "",
    [switch]$CopyToClipboard
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "pipeline-doc-parse.ps1")

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$docContent = Read-PipelineDocContent -RepoRoot $repoRoot -DocPath $DocPath
if (-not $docContent) {
    Write-Warning "Doc not found: $DocPath"
}

if ($MandatoryFiles.Count -eq 0 -and $docContent) {
    $MandatoryFiles = @(Get-PipelineMandatoryPathsFromDoc -Content $docContent -StepFilter $Step)
}

if (-not $RegressionModule -and $docContent) {
    $hint = Get-PipelineRegressionHintFromDoc -Content $docContent -StepFilter $Step
    if ($hint) {
        if (-not $RegressionModule) { $RegressionModule = $hint.Module }
        if (-not $RegressionScenario) { $RegressionScenario = $hint.Scenario }
    }
}

$regressionLine = "[from project-context regression index]"
if ($RegressionModule) {
    $yamlPath = Join-Path $repoRoot ".ai-gates\regression-index.yaml"
    $regressionLine = Get-PipelineRegressionLineFromYaml -YamlPath $yamlPath -Module $RegressionModule -Scenario $RegressionScenario
}

$stepLabel = $Step
if ($StepName) { $stepLabel = "$Step - $StepName" }

$fileLines = if ($MandatoryFiles.Count -gt 0) {
    ($MandatoryFiles | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
    "- [from plan-lite Mandatory Code Changes]"
}

$nl = [Environment]::NewLine
$message = "代码审核${nl}${nl}【L1.5 独立 CR - 须独立审查线程】${nl}${nl}车道：Standard + L1.5${nl}执行文档：$DocPath${nl}当前 Step：$stepLabel${nl}Mandatory Code Changes：${nl}$fileLines${nl}回归索引：$regressionLine${nl}${nl}请对照 git diff 仅审查上述 Step 范围，首行标注「L1.5 独立 CR」。${nl}输出 findings（blocker/major/minor）与验证缺口；无 blocker 方可建议更新 README。"

Write-Host "=== L1.5 CR dispatch (copy to NEW Chat or new Agent thread) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host $message
Write-Host ""
Write-Host "L1.5 compliance: NEW Chat OR new readonly Agent (Bugbot); NOT [CR] in dev Chat" -ForegroundColor DarkGray

if ($CopyToClipboard) {
    try {
        Set-Clipboard -Value $message
        Write-Host "(copied to clipboard)" -ForegroundColor Green
    } catch {
        Write-Host "(clipboard unavailable)" -ForegroundColor Yellow
    }
}
