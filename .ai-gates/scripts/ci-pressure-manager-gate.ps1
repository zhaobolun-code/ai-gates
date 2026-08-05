<#
.SYNOPSIS
  PressureManager diff 禁合门禁：触及 PM 代码则跑黄金验窗 -All；无 UNITY_EXE 则 exit 2（禁止伪绿）。

.DESCRIPTION
  - 检测 working tree / staged /（可选）相对 BaseRef 的 diff 是否触及 …/PressureManager/（含 LabSDK 路径）。
  - 仅文档（.md / .md.meta）变更视为未触及，避免纯文档误拦。
  - 触及 → 调用同仓 run-unity-verify-golden.ps1 -All；透传其 exit。
  - 未触及 → exit 0（不要求 UNITY_EXE）。
  - 触及且无 UNITY_EXE（或路径不存在）→ exit 2（红灯，禁止 skip 变绿）。
  - -Advisory：只打印建议命令，始终 exit 0（供 pre-commit 提示；硬拦仅 CI / 显式本地无 -Advisory）。

.EXAMPLE
  # CI / 本地硬拦
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/ci-pressure-manager-gate.ps1

.EXAMPLE
  # 相对 PR base
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/ci-pressure-manager-gate.ps1 -BaseRef origin/main

.EXAMPLE
  # pre-commit advisory
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/ci-pressure-manager-gate.ps1 -Advisory
#>

[CmdletBinding()]
param(
    [string]$BaseRef = "",
    [switch]$Advisory,
    [string]$UnityExe = $env:UNITY_EXE,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = git -C $scriptDir rev-parse --show-toplevel 2>$null
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
    }
}

$verifyScript = Join-Path $scriptDir "run-unity-verify-golden.ps1"
$docOnlyPattern = '(?i)\.md(\.meta)?$'

function Write-Gate {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host "[ci-pressure-manager-gate] $Msg" -ForegroundColor $Color
}

function Test-IsPressureManagerPath {
    param([string]$NormPath)
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    # …/PressureManager/… 或路径段恰为 PressureManager（含 LabSDK 子树）
    return ($NormPath -match '(^|/)PressureManager(/|$)')
}

function Test-IsDocOnlyPath {
    param([string]$NormPath)
    return ($NormPath -match $docOnlyPattern)
}

function Invoke-GitNameOnly {
    param(
        [string]$WorkDir = "",
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs
    )
    # git 可能把 CRLF 提示打到 stderr；在 Stop 模式下会变成 terminating — 用 cmd 吞 stderr
    $argLine = ($GitArgs | ForEach-Object {
        if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
    $prefix = ""
    if (-not [string]::IsNullOrWhiteSpace($WorkDir)) {
        $prefix = "git -C `"$WorkDir`" "
    } else {
        $prefix = "git "
    }
    $out = cmd /c "$prefix$argLine 2>nul"
    if ($LASTEXITCODE -ne 0) { return @() }
    if (-not $out) { return @() }
    return @($out)
}

function Test-IsGitSubmodulePath {
    param([string]$Root, [string]$RelNorm)
    $full = Join-Path $Root ($RelNorm -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $full)) { return $false }
    $gitMarker = Join-Path $full ".git"
    return (Test-Path -LiteralPath $gitMarker)
}

function Get-SubmoduleShaAt {
    param([string]$Root, [string]$RelNorm, [string]$Rev)
    # ls-tree: <mode> commit <sha>\t<path>
    $lines = @(Invoke-GitNameOnly -WorkDir $Root ls-tree $Rev -- $RelNorm)
    foreach ($line in $lines) {
        if ($line -match '^\S+\s+commit\s+([0-9a-f]{7,40})\s+') {
            return $Matches[1]
        }
    }
    return ""
}

function Add-SubmoduleInnerPaths {
    param(
        [string]$Root,
        [string]$SubRelNorm,
        [string]$Base,
        [System.Collections.Generic.HashSet[string]]$Set
    )
    $subFull = Join-Path $Root ($SubRelNorm -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-IsGitSubmodulePath -Root $Root -RelNorm $SubRelNorm)) { return }

    $inner = @()
    # 子模块工作区 / index（本地未推指针时也能看见 PM 脏文件）
    $inner += @(Invoke-GitNameOnly -WorkDir $subFull diff --name-only)
    $inner += @(Invoke-GitNameOnly -WorkDir $subFull diff --cached --name-only)

    # 父仓 Base...HEAD 指针变化 → 子模块两 SHA 之间的文件 diff
    if (-not [string]::IsNullOrWhiteSpace($Base)) {
        $oldSha = Get-SubmoduleShaAt -Root $Root -RelNorm $SubRelNorm -Rev $Base
        $newSha = Get-SubmoduleShaAt -Root $Root -RelNorm $SubRelNorm -Rev "HEAD"
        if ($oldSha -and $newSha -and ($oldSha -ne $newSha)) {
            $inner += @(Invoke-GitNameOnly -WorkDir $subFull diff --name-only "$oldSha" "$newSha")
        }
    }

    foreach ($p in $inner) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $norm = ($SubRelNorm.TrimEnd('/') + '/' + ($p -replace '\\', '/').Trim()).Trim()
        [void]$Set.Add($norm)
    }
}

function Get-ChangedPaths {
    param([string]$Root, [string]$Base)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    Push-Location $Root
    try {
        $chunks = @()
        if (-not [string]::IsNullOrWhiteSpace($Base)) {
            # triple-dot：相对 merge-base；失败则退回双点
            $triple = @(Invoke-GitNameOnly -WorkDir $Root diff --name-only "$Base...HEAD")
            if ($triple.Count -gt 0) {
                $chunks += $triple
            } else {
                $double = @(Invoke-GitNameOnly -WorkDir $Root diff --name-only "$Base" HEAD)
                if ($double.Count -gt 0) { $chunks += $double }
            }
        }

        # 本地未提交变更（staged + unstaged）始终纳入，避免漏拦
        $chunks += @(Invoke-GitNameOnly -WorkDir $Root diff --name-only)
        $chunks += @(Invoke-GitNameOnly -WorkDir $Root diff --cached --name-only)

        # 脏子模块在 `git status --porcelain` 里是 " M path"，name-only diff 也常只给子模块根路径
        $statusLines = @(cmd /c "git -C `"$Root`" status --porcelain 2>nul")
        foreach ($line in $statusLines) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
            $rel = $line.Substring(3).Trim().Trim('"') -replace '\\', '/'
            if ($rel -match ' -> ') { $rel = ($rel -split ' -> ')[-1] }
            if ($rel) { $chunks += $rel }
        }

        foreach ($p in $chunks) {
            if ([string]::IsNullOrWhiteSpace($p)) { continue }
            $norm = ($p -replace '\\', '/').Trim()
            [void]$set.Add($norm)
        }

        # 展开已出现在变更集中的子模块内部路径（父仓只见 Assets/LabSDK 时必须下钻）
        $subCandidates = @($set | Where-Object { Test-IsGitSubmodulePath -Root $Root -RelNorm $_ })
        foreach ($sub in $subCandidates) {
            Add-SubmoduleInnerPaths -Root $Root -SubRelNorm $sub -Base $Base -Set $set
        }
    } finally {
        Pop-Location
    }

    return @($set)
}

# 解析 BaseRef：显式参数 > 环境（GHA）> 空
if ([string]::IsNullOrWhiteSpace($BaseRef)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GATE_BASE_REF)) {
        $BaseRef = $env:GATE_BASE_REF
    } elseif (-not [string]::IsNullOrWhiteSpace($env:GITHUB_BASE_SHA)) {
        $BaseRef = $env:GITHUB_BASE_SHA
    } elseif (-not [string]::IsNullOrWhiteSpace($env:GITHUB_EVENT_BEFORE) -and $env:GITHUB_EVENT_BEFORE -notmatch '^0+$') {
        $BaseRef = $env:GITHUB_EVENT_BEFORE
    }
}

$changed = @(Get-ChangedPaths -Root $RepoRoot -Base $BaseRef)
$pmAll = @($changed | Where-Object { Test-IsPressureManagerPath $_ })
$pmCode = @($pmAll | Where-Object { -not (Test-IsDocOnlyPath $_) })

Write-Gate "baseRef=$(if ($BaseRef) { $BaseRef } else { '(local-staged/unstaged)' }) changed=$($changed.Count) pmPaths=$($pmAll.Count) pmCode=$($pmCode.Count)"

if ($pmCode.Count -eq 0) {
    if ($pmAll.Count -gt 0) {
        Write-Gate "PressureManager paths are docs-only; skip verify (exit 0)" "Green"
    } else {
        Write-Gate "no PressureManager code touch; skip verify (exit 0)" "Green"
    }
    exit 0
}

Write-Gate "PressureManager code touched:" "Yellow"
$pmCode | ForEach-Object { Write-Host "  $_" }

$cmdHint = "powershell -ExecutionPolicy Bypass -File .cursor/scripts/ci-pressure-manager-gate.ps1"
if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
    $cmdHint += " -BaseRef $BaseRef"
}

if ($Advisory) {
    Write-Gate "ADVISORY only (pre-commit): hard gate is CI + explicit local run" "Yellow"
    Write-Host "  suggested: $cmdHint"
    Write-Host "  (requires UNITY_EXE; missing Unity => exit 2, not fake-green)"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($UnityExe)) {
    Write-Gate "UNITY_EXE not set; refuse fake-green (exit 2)" "Red"
    exit 2
}
if (-not (Test-Path -LiteralPath $UnityExe)) {
    Write-Gate "UNITY_EXE path not found: $UnityExe (exit 2)" "Red"
    exit 2
}
if (-not (Test-Path -LiteralPath $verifyScript)) {
    Write-Gate "missing verify script: $verifyScript (exit 2)" "Red"
    exit 2
}

Write-Gate "running run-unity-verify-golden.ps1 -All" "Cyan"
$verifyArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $verifyScript,
    "-All",
    "-UnityExe", $UnityExe
)
$p = Start-Process -FilePath "powershell" -ArgumentList $verifyArgs -Wait -PassThru -NoNewWindow
$code = $p.ExitCode
if ($null -eq $code) { $code = 1 }

if ($code -eq 0) {
    Write-Gate "verify ALL OK (exit 0)" "Green"
} else {
    Write-Gate "verify failed (exit $code)" "Red"
}
exit $code
