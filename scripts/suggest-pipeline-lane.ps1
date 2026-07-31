# suggest-pipeline-lane.ps1 - git diff lane hint (advisory; does not set lane)
# Usage:
#   .\suggest-pipeline-lane.ps1
#   .\suggest-pipeline-lane.ps1 -DocPath "Assets/Doc/.../plan.md"
#   .\suggest-pipeline-lane.ps1 -DocPath "..." -Step "Step 1" -JsonOnly
param(
    [string]$DocPath,
    [string]$Step = "",
    [switch]$IncludeUntracked,
    [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "pipeline-doc-parse.ps1")

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not a git repository."
    exit 1
}

function Get-GitOutput {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $out = & git @Args 2>$null
    $ErrorActionPreference = $prev
    return @($out | Where-Object { $_ })
}

function Get-GitChangedPaths {
    param([switch]$IncludeUntracked)
    $files = New-Object System.Collections.Generic.HashSet[string]
    Get-GitOutput diff --name-only | ForEach-Object { [void]$files.Add($_) }
    Get-GitOutput diff --cached --name-only | ForEach-Object { [void]$files.Add($_) }
    if ($IncludeUntracked) {
        Get-GitOutput ls-files --others --exclude-standard | ForEach-Object { [void]$files.Add($_) }
    }
    return @($files | Sort-Object)
}

Push-Location $repoRoot
try {
    $reasons = @()
    $scope = "worktree"
    $gitChanged = Get-GitChangedPaths -IncludeUntracked:$IncludeUntracked
    $fileList = @()

    if ($DocPath) {
        $docContent = Read-PipelineDocContent -RepoRoot $repoRoot -DocPath $DocPath
        if (-not $docContent) {
            Write-Warning "DocPath not found: $DocPath; falling back to worktree scope"
        } else {
            $fileList = @(Get-PipelineMandatoryPathsFromDoc -Content $docContent -StepFilter $Step)
            if ($fileList.Count -eq 0) {
                Write-Warning "No Mandatory Code Changes in doc; falling back to worktree scope"
            } else {
                $scope = "plan-lite"
                $reasons += "scope: plan-lite mandatory ($($fileList.Count) path(s))"
                if ($Step) { $reasons += "step filter: $Step" }
            }
        }
    }

    if ($scope -eq "worktree") {
        $fileList = @($gitChanged)
        $reasons += "scope: worktree (pass -DocPath to ignore unrelated diff)"
        if ($fileList.Count -eq 0) {
            $reasons += "no git diff detected (new task or clean tree)"
        }
    }

    $fileCount = $fileList.Count
    if ($fileCount -gt 3) { $reasons += "files_in_scope=$fileCount (>3 -> at least Standard)" }

    $projectContext = Join-Path $repoRoot ".cursor\project-context.md"
    $expressUpgradePrefixes = @(Get-PipelineExpressUpgradePrefixes -ProjectContextPath $projectContext)
    $yamlPath = Join-Path $repoRoot ".cursor\regression-index.yaml"
    $regressionModules = @(Get-PipelineRegressionModulesFromYaml -YamlPath $yamlPath)

    $hitsExpressUpgrade = $false
    $hitsRegression = $false
    foreach ($f in $fileList) {
        if (Test-PipelinePathHitsPrefix -Path $f -Prefixes $expressUpgradePrefixes) {
            $hitsExpressUpgrade = $true
            $reasons += "path hits Express upgrade: $f"
        }
        $norm = $f -replace '\\','/'
        foreach ($mod in $regressionModules) {
            if ($norm -match [regex]::Escape($mod)) {
                $hitsRegression = $true
                $reasons += "path hits regression module ($mod): $f"
                break
            }
        }
    }

    $diffHint = "unknown"
    if ($fileCount -eq 0) {
        $diffHint = "unknown"
    } elseif ($hitsExpressUpgrade -or $hitsRegression) {
        $diffHint = "Standard"
        if ($fileCount -gt 8) {
            $diffHint = "Full"
            $reasons += "many files in scope + core module -> consider Full (TL)"
        }
    } elseif ($fileCount -le 3) {
        $diffHint = "Express"
    } else {
        $diffHint = "Standard"
    }

    $changedInScope = @()
    if ($scope -eq "plan-lite" -and $gitChanged.Count -gt 0) {
        foreach ($f in $fileList) {
            $fn = $f -replace '\\','/'
            foreach ($g in $gitChanged) {
                $gn = $g -replace '\\','/'
                if ($fn -eq $gn -or $gn -like "$fn*") { $changedInScope += $g; break }
            }
        }
    }

    $uniqueReasons = $reasons | Select-Object -Unique
    $result = [ordered]@{
        ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        scope = $scope
        doc_path = $(if ($DocPath) { $DocPath } else { $null })
        changed_files = $fileCount
        files = $fileList
        git_changed_in_scope = @($changedInScope | Select-Object -Unique)
        hits_express_upgrade = $hitsExpressUpgrade
        hits_regression_module = $hitsRegression
        diff_hint = $diffHint
        reasons = @($uniqueReasons)
        advisory = "PM applies CORE section 3-lane rules; diff_hint does not auto-set lane"
    }

    if ($JsonOnly) {
        $result | ConvertTo-Json -Compress
    } else {
        Write-Host "=== pipeline lane hint (advisory) ===" -ForegroundColor Cyan
        Write-Host "scope: $scope"
        if ($DocPath) { Write-Host "doc_path: $DocPath" }
        Write-Host "files_in_scope: $fileCount"
        if ($fileList.Count -gt 0) {
            Write-Host "files:"
            $fileList | ForEach-Object { Write-Host "  - $_" }
        }
        if ($changedInScope.Count -gt 0) {
            Write-Host "git_changed_in_scope:"
            $changedInScope | Select-Object -Unique | ForEach-Object { Write-Host "  - $_" }
        }
        Write-Host "hits_express_upgrade: $hitsExpressUpgrade"
        Write-Host "hits_regression_module: $hitsRegression"
        Write-Host "diff_hint: $diffHint" -ForegroundColor Yellow
        Write-Host "note: $($result.advisory)" -ForegroundColor DarkGray
        if ($uniqueReasons.Count -gt 0) {
            Write-Host "reasons:"
            $uniqueReasons | ForEach-Object { Write-Host "  - $_" }
        }
        Write-Host ""
        Write-Host "json: $($result | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
    }
} finally {
    Pop-Location
}
