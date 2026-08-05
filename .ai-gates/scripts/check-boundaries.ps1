# check-boundaries.ps1 — 架构边界检查（可选 · advisory）
# 规则配置：.cursor/project-context.md 增加「## 架构边界」小节，每行一条：
#   - `Assets/**/UI/**` 禁引用 `Assets/**/Backend/**`
#   - `Assets/**/UI/**` 禁引用 `Backend.**`（C# using Backend.B 用命名空间式）
# 通配：`**` = 任意（含点与斜杠）、`*` = 单段内任意；目标 glob 按引用形态写
# （路径式 `Backend/**` 配 JS/Lua，命名空间式 `Backend.**` 配 C# using）。
# 扫描 git 变更文件的 using/require/import/#include 行，命中目标模式 → WARN。
# 默认 exit 0（advisory）；-Strict → 命中 exit 1（供 validate-pipeline -Strict 用）。
# 设计取舍（2026-08-05）：不做 pre-tool-use DENY——跨语言正则误报成本高，
# 以 advisory / CR 升档为主；Chemical(Unity/C#) 边界在 asmdef/命名空间，规则按项目自配。
param(
    [switch]$Strict
)
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { Write-Error 'Not a git repository.'; exit 1 }

function Get-GitOutput {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $out = & git @GitArgs 2>$null
    $ErrorActionPreference = $prev
    return @($out | Where-Object { $_ })
}

$rules = @()
$pcPath = Join-Path $repoRoot '.cursor\project-context.md'
if (Test-Path -LiteralPath $pcPath) {
    $pc = Get-Content -LiteralPath $pcPath -Raw -Encoding UTF8
    if ($pc -match '(?s)##\s*架构边界[^\r\n]*\r?\n(.*?)(?=\r?\n##\s|\z)') {
        $block = $Matches[1]
        foreach ($ln in ($block -split "`r?`n")) {
            if ($ln -match '^\s*-\s*`([^`]+)`\s*禁引用\s*`([^`]+)`') {
                $rules += ,@($Matches[1].Trim(), $Matches[2].Trim())
            }
        }
    }
}
if ($rules.Count -eq 0) {
    Write-Host 'check-boundaries: 未配置架构边界规则（project-context §架构边界 为空）→ 跳过' -ForegroundColor DarkGray
    exit 0
}

function Convert-GlobToRegex {
    param([string]$Glob)
    $esc = [regex]::Escape($Glob)
    $esc = $esc.Replace('\*\*', '.*').Replace('\*', '[^/]*')
    return '^' + $esc + '$'
}

$files = @()
$hasHead = @(Get-GitOutput rev-parse --verify HEAD).Count -gt 0
if ($hasHead) { $files += Get-GitOutput diff --name-only HEAD }
$files += Get-GitOutput diff --cached --name-only
$files += Get-GitOutput ls-files --others --exclude-standard
$files = $files | Where-Object { $_ } | Select-Object -Unique

$violations = @()
foreach ($f in $files) {
    $fn = $f -replace '\\','/'
    foreach ($rule in $rules) {
        $srcRe = Convert-GlobToRegex -Glob $rule[0]
        $dstRe = Convert-GlobToRegex -Glob $rule[1]
        if ($fn -notmatch $srcRe) { continue }
        $abs = Join-Path $repoRoot $f
        if (-not (Test-Path -LiteralPath $abs)) { continue }
        $raw = Get-Content -LiteralPath $abs -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $raw) { continue }
        $refs = @()
        if ($f -match '\.cs$') {
            [regex]::Matches($raw, '(?im)^\s*using\s+([\w\.]+)') | ForEach-Object { $refs += $_.Groups[1].Value }
        } elseif ($f -match '\.lua$') {
            [regex]::Matches($raw, '(?im)require\s*\(\s*[''"]\s*([^''"]+)') | ForEach-Object { $refs += $_.Groups[1].Value }
        } elseif ($f -match '\.(ts|js|tsx|jsx|mjs)$') {
            [regex]::Matches($raw, '(?im)(?:import\s+[^''"]*from\s*[''"]|require\s*\(\s*[''"])([^''"]+)') | ForEach-Object { $refs += $_.Groups[1].Value }
        } elseif ($f -match '\.(h|hpp|cpp|c)$') {
            [regex]::Matches($raw, '(?im)^\s*#include\s*[<"]([^>"]+)') | ForEach-Object { $refs += $_.Groups[1].Value }
        }
        foreach ($r in $refs) {
            $rn = $r -replace '\\','/'
            if ($rn -match $dstRe) {
                $violations += "边界违规：$fn 引用 $rn（源 $($rule[0]) → 禁引用 $($rule[1])）"
            }
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host 'check-boundaries: OK（无边界违规）' -ForegroundColor Green
    exit 0
}
$violations | ForEach-Object { Write-Host "WARN $_" -ForegroundColor Yellow }
if ($Strict) {
    Write-Host "check-boundaries: -Strict → exit 1（$($violations.Count) 处违规）" -ForegroundColor Red
    exit 1
}
Write-Host "check-boundaries: advisory（$($violations.Count) 处违规，未阻断；CR/升档处理）" -ForegroundColor Yellow
exit 0
