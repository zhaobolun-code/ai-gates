# ensure-plugin-seed.ps1 — Cursor 市场插件 sessionStart。
# 把插件仓里的 .ai-gates/ 种进当前项目（复用 install-ai-gates.ps1）。
# 已有 skills/CORE.md 则不覆盖库文件；可提示 PM 升级。
# 种库后写 .cursor/ai-gates-runtime.json（本机通道锁，不进 Git）。
# fail-open：任何异常 stdout {} 且 exit 0。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Emit-Empty {
    Write-Output '{}'
    exit 0
}

function Write-SeedAudit {
    param([string]$Line, [string]$Root)
    try {
        if ([string]::IsNullOrWhiteSpace($Root)) { $Root = [string]$env:CURSOR_PROJECT_DIR }
        if ([string]::IsNullOrWhiteSpace($Root)) { return }
        $logDir = Join-Path $Root '.ai-gates\hooks-log'
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath (Join-Path $logDir 'plugin-seed.log') -Value "$ts | $Line" -Encoding UTF8
    } catch { }
}

function Get-SemverObj {
    param([string]$Version)
    $v = ([string]$Version).Trim() -replace '^[vV]', ''
    $m = [regex]::Match($v, '^(\d+)\.(\d+)\.(\d+)')
    if (-not $m.Success) { return $null }
    return [pscustomobject]@{
        Major = [int]$m.Groups[1].Value
        Minor = [int]$m.Groups[2].Value
        Patch = [int]$m.Groups[3].Value
        Raw   = $v
    }
}

function Compare-SemverObj {
    param($A, $B)
    if ($null -eq $A -and $null -eq $B) { return 0 }
    if ($null -eq $A) { return -1 }
    if ($null -eq $B) { return 1 }
    if ($A.Major -ne $B.Major) { return [Math]::Sign($A.Major - $B.Major) }
    if ($A.Minor -ne $B.Minor) { return [Math]::Sign($A.Minor - $B.Minor) }
    return [Math]::Sign($A.Patch - $B.Patch)
}

try {
    $null = [Console]::In.ReadToEnd()

    $pluginRoot = [string]$env:CURSOR_PLUGIN_ROOT
    $projectRoot = [string]$env:CURSOR_PROJECT_DIR
    if ([string]::IsNullOrWhiteSpace($projectRoot)) {
        $git = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        if ($git) { $projectRoot = ([string]$git).Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($projectRoot) -or -not (Test-Path -LiteralPath $projectRoot)) {
        Write-SeedAudit 'skip no_project_root'
        Emit-Empty
    }

    $srcLib = $null
    $sourceArg = $null
    if (-not [string]::IsNullOrWhiteSpace($pluginRoot)) {
        $nested = Join-Path $pluginRoot '.ai-gates'
        if (Test-Path -LiteralPath (Join-Path $nested 'skills\CORE.md')) {
            $srcLib = $nested
            $sourceArg = $pluginRoot
        }
    }

    $targetCore = Join-Path $projectRoot '.ai-gates\skills\CORE.md'
    $installScript = $null
    if ($srcLib) {
        $cand = Join-Path $srcLib 'scripts\install-ai-gates.ps1'
        if (Test-Path -LiteralPath $cand) { $installScript = $cand }
    }
    if (-not $installScript) {
        $cand2 = Join-Path $projectRoot '.ai-gates\scripts\install-ai-gates.ps1'
        if (Test-Path -LiteralPath $cand2) { $installScript = $cand2 }
    }

    $hint = $null
    if (-not (Test-Path -LiteralPath $targetCore)) {
        if ($installScript -and $sourceArg) {
            Write-SeedAudit -Root $projectRoot -Line ("install source={0}" -f $sourceArg)
            $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $installScript -Source $sourceArg -TargetRoot $projectRoot 2>&1
        } else {
            Write-SeedAudit -Root $projectRoot -Line 'skip no_install_script'
        }
    } else {
        $projVerPath = Join-Path $projectRoot '.ai-gates\skills\VERSION'
        $plugVerPath = $null
        if ($srcLib) { $plugVerPath = Join-Path $srcLib 'skills\VERSION' }
        if ((Test-Path -LiteralPath $projVerPath) -and $plugVerPath -and (Test-Path -LiteralPath $plugVerPath)) {
            $pv = Get-SemverObj (Get-Content -LiteralPath $projVerPath -Raw -Encoding UTF8)
            $gv = Get-SemverObj (Get-Content -LiteralPath $plugVerPath -Raw -Encoding UTF8)
            if ($null -ne $pv -and $null -ne $gv -and (Compare-SemverObj $gv $pv) -gt 0) {
                $hint = "ai-gates: project VERSION $($pv.Raw), plugin $($gv.Raw). Say PM upgrade ai-gates to update the project library."
            }
        }
        Write-SeedAudit -Root $projectRoot -Line 'present skip_copy'
    }

    $cursorDir = Join-Path $projectRoot '.cursor'
    if (-not (Test-Path -LiteralPath $cursorDir)) {
        New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    }
    $runtime = [ordered]@{
        owner         = 'project'
        pluginPresent  = $true
        writtenAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText((Join-Path $cursorDir 'ai-gates-runtime.json'), ($runtime | ConvertTo-Json -Compress), $utf8Bom)
    Write-SeedAudit -Root $projectRoot -Line 'runtime_lock_written'
    if ($hint) {
        $ctx = "[ai-gates] $hint"
        Write-Output (@{ additional_context = $ctx; additionalContext = $ctx } | ConvertTo-Json -Compress)
        exit 0
    }
    Emit-Empty
} catch {
    Write-SeedAudit ("ERROR fail_open msg=$($_.Exception.Message)")
    Emit-Empty
}
