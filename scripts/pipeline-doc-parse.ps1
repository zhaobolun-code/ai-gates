# pipeline-doc-parse.ps1 - shared plan-lite / regression-index parsers (dot-source)
# Usage: . (Join-Path $scriptDir "pipeline-doc-parse.ps1")

function Get-PipelineStepNumber {
    param([string]$Step)
    if ($Step -match '(\d+)') { return $Matches[1] }
    return $Step
}

function Get-PipelineMandatoryPathsFromDoc {
    param(
        [string]$Content,
        [string]$StepFilter = ""
    )
    $found = New-Object System.Collections.Generic.HashSet[string]
    if ($StepFilter) {
        $stepNum = Get-PipelineStepNumber -Step $StepFilter
        $directPattern = '(?s)###\s*Step\s*' + [regex]::Escape($stepNum) + '.*?\*\*Mandatory Code Changes\*\*[^`\r\n]*`([^`]+)`'
        if ($Content -match $directPattern) {
            [void]$found.Add($Matches[1].Trim())
        }
        if ($found.Count -eq 0) {
            $sectionPattern = '(?s)###\s*Step\s*' + [regex]::Escape($stepNum) + '.*?(?=\r?\n###\s*Step\s*\d+|\z)'
            if ($Content -match $sectionPattern) {
                [regex]::Matches($Matches[0], '-\s*`([^`]+)`') | ForEach-Object {
                    [void]$found.Add($_.Groups[1].Value.Trim())
                }
            }
        }
    } else {
        [regex]::Matches($Content, '\*\*Mandatory Code Changes\*\*[^`\r\n]*`([^`]+)`') | ForEach-Object {
            [void]$found.Add($_.Groups[1].Value.Trim())
        }
    }
    return @($found | Sort-Object)
}

function Get-PipelineRegressionHintFromDoc {
    param(
        [string]$Content,
        [string]$StepFilter = ""
    )
    $search = $Content
    if ($StepFilter) {
        $stepNum = Get-PipelineStepNumber -Step $StepFilter
        $sectionPattern = '(?s)###\s*Step\s*' + [regex]::Escape($stepNum) + '.*?(?=\r?\n###\s*Step\s*\d+|\z)'
        if ($Content -match $sectionPattern) { $search = $Matches[0] }
    }
    # ASCII-only patterns (PS 5.1 mis-parses UTF-8 regex literals without BOM)
    if ($search -match '(?m)-\s+\S+\s+\*\*([^*]+)\*\*\s*/\s*\S+\s+\*\*([^*]+)\*\*') {
        return @{
            Module = $Matches[1].Trim()
            Scenario = $Matches[2].Trim()
        }
    }
    if ($search -match '(?m)\S+\s+\*\*([^*]+)\*\*\s*/\s*\S+\s+\*\*([^*]+)\*\*') {
        return @{
            Module = $Matches[1].Trim()
            Scenario = $Matches[2].Trim()
        }
    }
    return $null
}

function Get-PipelineRegressionEntriesFromYaml {
    param([string]$YamlPath)
    if (-not (Test-Path -LiteralPath $YamlPath)) { return @() }
    $yaml = Get-Content -LiteralPath $YamlPath -Raw -Encoding UTF8
    $entries = @()
    $parts = $yaml -split '(?m)^\s*-\s*module:\s*'
    foreach ($part in $parts) {
        if ($part -notmatch '^(\S+)\s*\r?\n') { continue }
        $module = $Matches[1].Trim()
        $scenario = if ($part -match '(?m)^\s*scenario:\s*(.+)\r?\n') { $Matches[1].Trim() } else { '' }
        $steps = if ($part -match '(?m)^\s*steps:\s*(.+)\r?\n') { $Matches[1].Trim() } else { '' }
        $kw = @()
        if ($part -match '(?s)console_keywords:\s*\r?\n((?:\s+-\s+.+\r?\n)+)') {
            [regex]::Matches($Matches[1], '(?m)^\s+-\s+(.+)\r?\n') | ForEach-Object {
                $kw += $_.Groups[1].Value.Trim()
            }
        }
        $entries += [pscustomobject]@{
            Module = $module
            Scenario = $scenario
            Steps = $steps
            ConsoleKeywords = $kw
        }
    }
    return $entries
}

function Get-PipelineRegressionLineFromYaml {
    param(
        [string]$YamlPath,
        [string]$Module,
        [string]$Scenario = ""
    )
    $entries = @(Get-PipelineRegressionEntriesFromYaml -YamlPath $YamlPath | Where-Object { $_.Module -eq $Module })
    if ($entries.Count -eq 0) {
        return "$Module / $Scenario - see project-context regression index"
    }
    $pick = $null
    if ($Scenario) {
        $pick = $entries | Where-Object { $_.Scenario -eq $Scenario } | Select-Object -First 1
        if (-not $pick) {
            $pick = $entries | Where-Object { $_.Scenario -like "*$Scenario*" -or $Scenario -like "*$($_.Scenario)*" } | Select-Object -First 1
        }
    }
    if (-not $pick) { $pick = $entries | Select-Object -First 1 }
    $kw = ($pick.ConsoleKeywords -join ', ')
    return "$($pick.Module) / $($pick.Scenario) - $($pick.Steps) - Console: $kw"
}

function Get-PipelineExpressUpgradePrefixes {
    param([string]$ProjectContextPath)
    if (-not (Test-Path -LiteralPath $ProjectContextPath)) { return @() }
    $pc = Get-Content -LiteralPath $ProjectContextPath -Raw -Encoding UTF8
    if ($pc -notmatch '(?s)##\s*Express[^\r\n]*\r?\n(.*?)(?=\r?\n##\s|\z)') { return @() }
    $block = $Matches[1]
    $prefixes = @()
    [regex]::Matches($block, '`(Assets/[^`]+)/?`') | ForEach-Object {
        $p = ($_.Groups[1].Value.Trim()) -replace '/$',''
        if ($p) { $prefixes += $p }
    }
    return @($prefixes | Select-Object -Unique)
}

function Get-PipelineRegressionModulesFromYaml {
    param([string]$YamlPath)
    return @(Get-PipelineRegressionEntriesFromYaml -YamlPath $YamlPath | ForEach-Object { $_.Module } | Select-Object -Unique)
}

function Test-PipelinePathHitsPrefix {
    param([string]$Path, [string[]]$Prefixes)
    $norm = ($Path -replace '\\','/').TrimEnd('/')
    foreach ($prefix in $Prefixes) {
        $pre = (($prefix -replace '\\','/') -replace '/$','').TrimEnd('/')
        if ($norm -eq $pre -or $norm -like "$pre/*" -or $norm -like "*$pre/*") { return $true }
    }
    return $false
}

function Read-PipelineDocContent {
    param([string]$RepoRoot, [string]$DocPath)
    $fullDoc = Join-Path $RepoRoot ($DocPath -replace '/','\')
    if (-not (Test-Path -LiteralPath $fullDoc)) { return $null }
    return Get-Content -LiteralPath $fullDoc -Raw -Encoding UTF8
}
