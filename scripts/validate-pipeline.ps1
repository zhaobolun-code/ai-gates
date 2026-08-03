# validate-pipeline.ps1 — 流水线一键校验（执行文档 + 回归索引 + PM 脚本）
# Usage:
#   .\validate-pipeline.ps1                          # 回归索引 sync + CheckScripts
#   .\validate-pipeline.ps1 -DocPath "path/to/方案.md"
#   .\validate-pipeline.ps1 -CheckScripts -Strict
#   .\validate-pipeline.ps1 -SkipScripts             # 跳过 PM 脚本探测
param(
    [string]$DocPath,
    [switch]$CheckGit,
    [switch]$Strict,
    [switch]$SkipRegression,
    [switch]$SkipScripts
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$runScripts = (-not $SkipScripts) -or $Strict

Push-Location $repoRoot
try {
    $exitCode = 0
    $skillsRoot = Join-Path $repoRoot ".cursor/skills"
    $versionPath = Join-Path $skillsRoot "VERSION"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        Write-Host "missing version source: .cursor/skills/VERSION" -ForegroundColor Red
        exit 1
    }
    $pipelineVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
    if ($pipelineVersion -notmatch '^\d+\.\d+\.\d+$') {
        Write-Host "invalid VERSION: $pipelineVersion" -ForegroundColor Red
        exit 1
    }

    Write-Host "=== validate-pipeline (v$pipelineVersion) ===" -ForegroundColor Cyan
    Write-Host "repo: $repoRoot"

    function Read-Utf8Text {
        param([string]$Path)
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    }

    Write-Host "`n--- skills layout (v2 residue) ---" -ForegroundColor Cyan
    $forbiddenRel = @(
        "QUICKSTART.md",
        "project-manager",
        "references/lanes.md",
        "references/workflow-modes.md",
        "references/pm-one-pager.md",
        "references/role-tags.md",
        "references/cursor-native-tools.md",
        "references/express-self-check.md"
    )
    $foundForbidden = @()
    foreach ($rel in $forbiddenRel) {
        $p = Join-Path $skillsRoot $rel
        if (Test-Path $p) { $foundForbidden += $rel }
    }
    $archiveReadme = Join-Path $skillsRoot "archive/README.md"
    if ((Test-Path (Join-Path $skillsRoot "archive")) -and -not (Test-Path $archiveReadme)) {
        $foundForbidden += "archive/ (missing archive/README.md sentinel)"
    }
    if ($foundForbidden.Count -gt 0) {
        Write-Host "v2 residue found under .cursor/skills/:" -ForegroundColor Red
        $foundForbidden | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        $exitCode = 1
    } else {
        Write-Host "skills layout: OK (no v2 residue)" -ForegroundColor Green
    }

    $requiredRefs = @(
        "anti-patterns.md",
        "codegraph-probe.md",
        "doc-path-defaults.md",
        "evidence-levels.md",
        "execution-discipline.md",
        "execution-doc-template.md",
        "handoff-template.md",
        "plan-review-tiers.md",
        "project-local-config.md",
        "regression-index.template.yaml",
        "retrospective-metrics.md",
        "state-machine.md",
        "user-visible-states.md",
        "full-lane-decision-tree.md",
        "lane-glossary.md",
        "pm-tooling.md",
        "readme-dispatch.md",
        "examples.md",
        "tl-onboarding.md",
        "demand-clarification.md",
        "rollback.md",
        "unity-editor-log.md",
        "lessons-learned.md",
        "acceptance-and-delta.md",
        "pm-init.md",
        "isolated-review.md",
        "doc-windowing.md",
        "diagnosis-gates.md",
        "hooks-advisory.md",
        "reference-routing.md"
    )
    $refsDir = Join-Path $skillsRoot "references"
    $missingRefs = @()
    foreach ($name in $requiredRefs) {
        if (-not (Test-Path (Join-Path $refsDir $name))) { $missingRefs += $name }
    }
    $goldSample = Get-ChildItem -Path $refsDir -Filter "*黄金样例*" -File -ErrorAction SilentlyContinue
    if (-not $goldSample) { $missingRefs += "执行文档黄金样例.md" }
    if ($missingRefs.Count -gt 0) {
        Write-Host "missing references/ files:" -ForegroundColor Red
        $missingRefs | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        $exitCode = 1
    } else {
        Write-Host "references/: OK ($($requiredRefs.Count) files)" -ForegroundColor Green
    }

    Write-Host "`n--- workflow / version consistency ---" -ForegroundColor Cyan
    $readmeRaw = Read-Utf8Text (Join-Path $skillsRoot "README.md")
    $evalRaw = Read-Utf8Text (Join-Path $skillsRoot "references/skill-eval-checklist.md")
    $maintainerRaw = Read-Utf8Text (Join-Path $skillsRoot "MAINTAINER.md")
    $workflowOk = $true
    if ($readmeRaw -notmatch 'plan-lite\s*→\s*L1/L1\.5/L2 方案审核\s*→\s*确认' -or
        $readmeRaw -match 'plan-lite\s*→\s*确认\s*→\s*L1/L1\.5/L2') {
        Write-Host "workflow consistency: FAILED (README Standard order)" -ForegroundColor Red
        $workflowOk = $false
    }
    if ($evalRaw -notmatch 'F1b.*未「准」就连跑.*准, 不 Auto') {
        Write-Host "workflow consistency: FAILED (F1b Auto default/exit regression)" -ForegroundColor Red
        $workflowOk = $false
    }
    if ($maintainerRaw -match 'CORE\.md.*≈120|TEAM-GUIDE\.md.*≤120|README\.md.*≤90') {
        Write-Host "workflow consistency: FAILED (stale line targets)" -ForegroundColor Red
        $workflowOk = $false
    }
    if ($workflowOk) {
        Write-Host "workflow consistency: OK" -ForegroundColor Green
    } else {
        $exitCode = 1
    }

    function Get-EntryModeFromText {
        param([string]$Raw, [string]$VersionPattern)
        $raw = $Raw
        $head = (($raw -split "`r?`n") | Select-Object -First 12) -join "`n"
        if ($head -match '\bVERSION\b') { return @{ Mode = "pointer"; Version = $null } }
        if ($raw -match $VersionPattern) { return @{ Mode = "hardcoded"; Version = $Matches["v"] } }
        return @{ Mode = "invalid"; Version = $null }
    }

    function Get-CurrentEntryMode {
        param([string]$Path, [string]$VersionPattern)
        return Get-EntryModeFromText -Raw (Read-Utf8Text $Path) -VersionPattern $VersionPattern
    }

    $entrySpecs = @(
        @{ Name = "CORE"; Path = (Join-Path $skillsRoot "CORE.md"); Pattern = '(?m)^# AI 开发流水线 CORE（v(?<v>\d+\.\d+\.\d+)' },
        @{ Name = "README"; Path = (Join-Path $skillsRoot "README.md"); Pattern = '(?m)^> \*\*当前 LTS：v(?<v>\d+\.\d+\.\d+)' },
        @{ Name = "MAINTAINER"; Path = (Join-Path $skillsRoot "MAINTAINER.md"); Pattern = '(?m)^- \*\*当前 LTS\*\*：\*\*v(?<v>\d+\.\d+\.\d+)' },
        @{ Name = "Cursor rule"; Path = (Join-Path $repoRoot ".cursor/rules/ai-dev-pipeline.mdc"); Pattern = '(?m)^description: .*v(?<v>\d+\.\d+\.\d+)' },
        @{ Name = "Trae rule"; Path = (Join-Path $repoRoot ".trae/rules/ai-dev-pipeline.md"); Pattern = '(?m)^description: .*v(?<v>\d+\.\d+\.\d+)' }
    )
    $entryModes = @()
    foreach ($spec in $entrySpecs) {
        $result = Get-CurrentEntryMode -Path $spec.Path -VersionPattern $spec.Pattern
        $entryModes += $result.Mode
        if ($result.Mode -eq "invalid" -or ($result.Mode -eq "hardcoded" -and $result.Version -ne $pipelineVersion)) {
            Write-Host "version consistency: FAILED ($($spec.Name))" -ForegroundColor Red
            $exitCode = 1
        }
    }
    $pointerCount = @($entryModes | Where-Object { $_ -eq "pointer" }).Count
    if ($pointerCount -gt 0 -and $pointerCount -lt $entrySpecs.Count) {
        Write-Host "version consistency: FAILED (mixed hardcoded/pointer current entries)" -ForegroundColor Red
        $exitCode = 1
    }
    $changelogRaw = Read-Utf8Text (Join-Path $skillsRoot "CHANGELOG.md")
    if ($changelogRaw -notmatch "(?m)^\*\*当前 LTS\*\*：v$([regex]::Escape($pipelineVersion))\b") {
        Write-Host "version consistency: FAILED (CHANGELOG current LTS)" -ForegroundColor Red
        $exitCode = 1
    }
    foreach ($scriptName in @("validate-pipeline.ps1", "check-pipeline-doc.ps1")) {
        $scriptHead = (Get-Content -LiteralPath (Join-Path $scriptDir $scriptName) -TotalCount 20) -join "`n"
        if ($scriptHead -match 'v\d+\.\d+\.\d+') {
            Write-Host "version consistency: FAILED ($scriptName hardcodes current version)" -ForegroundColor Red
            $exitCode = 1
        }
    }
    $packagePath = Join-Path $repoRoot ".cursor/package-release.ps1"
    $packageRaw = Read-Utf8Text $packagePath
    if ($packageRaw -notmatch 'Join-Path \$skillsDir "VERSION"' -or
        $packageRaw -match 'Get-Content -LiteralPath \(Join-Path \$skillsDir "CORE\.md"\).*TotalCount 1' -or
        $packageRaw -match 'v\d+\.\d+\.\d+') {
        Write-Host "version consistency: FAILED (package-release VERSION source)" -ForegroundColor Red
        $exitCode = 1
    }
    $syntheticPattern = '(?m)^Current: v(?<v>\d+\.\d+\.\d+)'
    $syntheticPointer = Get-EntryModeFromText -Raw "Current: VERSION" -VersionPattern $syntheticPattern
    $syntheticMismatch = Get-EntryModeFromText -Raw "Current: v9.9.9" -VersionPattern $syntheticPattern
    $syntheticModes = @($syntheticPointer.Mode, $syntheticMismatch.Mode)
    $syntheticMixedDetected = (@($syntheticModes | Where-Object { $_ -eq "pointer" }).Count -gt 0 -and
        @($syntheticModes | Where-Object { $_ -eq "pointer" }).Count -lt $syntheticModes.Count)
    $syntheticMismatchDetected = ($syntheticMismatch.Mode -eq "hardcoded" -and $syntheticMismatch.Version -ne $pipelineVersion)
    if (-not $syntheticMixedDetected -or -not $syntheticMismatchDetected) {
        Write-Host "version self-test: FAILED" -ForegroundColor Red
        $exitCode = 1
    } else {
        Write-Host "version self-test: OK" -ForegroundColor Green
    }
    if ($exitCode -eq 0) { Write-Host "version consistency: OK ($pipelineVersion)" -ForegroundColor Green }

    Write-Host "`n--- templates ---" -ForegroundColor Cyan
    $requiredTemplates = @(
        "express-slice.md",
        "plan-lite.md",
        "cr-dispatch-l1.5.md",
        "doc-folder-已完成-索引.md"
    )
    $templatesDir = Join-Path $skillsRoot "templates"
    $missingTemplates = @()
    foreach ($name in $requiredTemplates) {
        if (-not (Test-Path (Join-Path $templatesDir $name))) { $missingTemplates += $name }
    }
    if ($missingTemplates.Count -gt 0) {
        Write-Host "missing templates/ files:" -ForegroundColor Red
        $missingTemplates | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        $exitCode = 1
    } else {
        Write-Host "templates/: OK ($($requiredTemplates.Count) files)" -ForegroundColor Green
    }

    if ($runScripts) {
        Write-Host "`n--- hooks policy (MAINTAINER ↔ hooks.json / pm-gate-check) ---" -ForegroundColor Cyan
        $policyScript = Join-Path $scriptDir "check-hooks-policy.ps1"
        if (-not (Test-Path -LiteralPath $policyScript)) {
            Write-Host "hooks policy: FAILED (check-hooks-policy.ps1 missing)" -ForegroundColor Red
            $exitCode = 1
        } else {
            . $policyScript
            $policyReport = Get-HooksPolicyReport -RepoRoot $repoRoot
            if ($policyReport.Ok) {
                Write-Host "hooks policy: OK (ask + all failClosed=false + sessionStart drift)" -ForegroundColor Green
            } else {
                Write-Host "hooks policy: FAILED (drift):" -ForegroundColor Red
                $policyReport.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
                $exitCode = 1
            }
        }

        Write-Host "`n--- hooks 行为回归 (支柱 C) ---" -ForegroundColor Cyan
        $testHooksPath = Join-Path $scriptDir "test-hooks.ps1"
        if (Test-Path -LiteralPath $testHooksPath) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $testHooksPath
            if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
        } else {
            Write-Host "test-hooks.ps1 missing" -ForegroundColor Red
            $exitCode = 1
        }

        Write-Host "`n--- PM scripts (CheckScripts) ---" -ForegroundColor Cyan
        $requiredScripts = @(
            "pipeline-doc-parse.ps1",
            "suggest-pipeline-lane.ps1",
            "append-pipeline-snapshot.ps1",
            "dispatch-l1.5-cr.ps1",
            "summarize-pipeline-metrics.ps1"
        )
        $missingScripts = @()
        foreach ($name in $requiredScripts) {
            $sp = Join-Path $scriptDir $name
            if (-not (Test-Path -LiteralPath $sp)) { $missingScripts += $name }
        }
        if ($missingScripts.Count -gt 0) {
            Write-Host "missing scripts:" -ForegroundColor Red
            $missingScripts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            $exitCode = 1
        } else {
            Write-Host "scripts: OK ($($requiredScripts.Count) files)" -ForegroundColor Green
        }

        $parsePath = Join-Path $scriptDir "pipeline-doc-parse.ps1"
        try {
            . $parsePath
            $sampleDoc = "Assets/Doc/_examples/plan-lite-pressure-debug-log.md"
            $content = Read-PipelineDocContent -RepoRoot $repoRoot -DocPath $sampleDoc
            if (-not $content) {
                Write-Host "parse probe: skip (sample doc missing)" -ForegroundColor DarkYellow
            } else {
                $paths = @(Get-PipelineMandatoryPathsFromDoc -Content $content -StepFilter "Step 1")
                if ($paths.Count -lt 1) {
                    Write-Host "parse probe: FAILED (no Mandatory paths in sample doc)" -ForegroundColor Red
                    $exitCode = 1
                } else {
                    $hint = Get-PipelineRegressionHintFromDoc -Content $content -StepFilter "Step 1"
                    $yamlPath = Join-Path $repoRoot ".cursor\regression-index.yaml"
                    $line = Get-PipelineRegressionLineFromYaml -YamlPath $yamlPath -Module $hint.Module -Scenario $hint.Scenario
                    # generic assertion (no project-specific module names): hint must resolve a Module,
                    # and the returned regression line must actually reference that same Module.
                    if (-not $hint -or -not $hint.Module -or ($line -notmatch [regex]::Escape($hint.Module))) {
                        Write-Host "parse probe: WARN (scenario match may be wrong)" -ForegroundColor DarkYellow
                        if ($Strict) { $exitCode = 1 }
                    } else {
                        Write-Host "parse probe: OK (Mandatory + scenario regression line)" -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "parse probe: FAILED ($($_.Exception.Message))" -ForegroundColor Red
            $exitCode = 1
        }
    }

    if (-not $SkipRegression) {
        Write-Host "`n--- regression index ---" -ForegroundColor Cyan
        $syncArgs = @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $scriptDir "sync-regression-index.ps1"))
        if ($Strict) { $syncArgs += "-Strict" }
        & powershell @syncArgs
        if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
    }

    if ($DocPath) {
        Write-Host "`n--- execution doc ---" -ForegroundColor Cyan
        $docArgs = @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $scriptDir "check-pipeline-doc.ps1"), "-DocPath", $DocPath)
        if ($CheckGit) { $docArgs += "-CheckGit" }
        if ($Strict) { $docArgs += "-Strict" }
        & powershell @docArgs
        if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
    } elseif (-not $SkipRegression) {
        Write-Host "`nTip: pass -DocPath to validate an execution doc." -ForegroundColor DarkGray
    }

    # Advisory: windowed scheme folders under Chemical doc root
    Write-Host "`n--- doc windowing (advisory) ---" -ForegroundColor Cyan
    $chemDocRoot = Join-Path $repoRoot "Assets\LabSDK\Runtime\Pennon\ExplorationLab\化学文档\压力系统"
    if (Test-Path -LiteralPath $chemDocRoot) {
        $schemeDirs = Get-ChildItem -LiteralPath $chemDocRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^\.' }
        $winWarn = 0
        foreach ($d in $schemeDirs) {
            $hasDone = Test-Path -LiteralPath (Join-Path $d.FullName "已完成")
            $hasOpen = Test-Path -LiteralPath (Join-Path $d.FullName "未完成.md")
            if ($hasDone -and -not $hasOpen) {
                Write-Host "WARN: $($d.Name) has 已完成/ but missing 未完成.md" -ForegroundColor DarkYellow
                $winWarn++
                if ($Strict) { $exitCode = 1 }
            }
            if ($hasOpen -and -not (Test-Path -LiteralPath (Join-Path $d.FullName "已完成\_索引.md"))) {
                Write-Host "WARN: $($d.Name) missing 已完成/_索引.md" -ForegroundColor DarkYellow
                $winWarn++
                if ($Strict) { $exitCode = 1 }
            }
        }
        if ($winWarn -eq 0) {
            Write-Host "windowed schemes: OK (advisory scan)" -ForegroundColor Green
        }
    } else {
        Write-Host "windowing scan: skip (chem doc root missing)" -ForegroundColor DarkGray
    }

    if ($exitCode -eq 0) {
        Write-Host "`nvalidate-pipeline: OK" -ForegroundColor Green
    } else {
        Write-Host "`nvalidate-pipeline: FAILED (use -Strict in CI)" -ForegroundColor Red
    }
    exit $exitCode
} finally {
    Pop-Location
}
