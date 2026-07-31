<#
.SYNOPSIS
  Commit lesson pending row into .cursor/lessons-learned.md after user approval.

.DESCRIPTION
  Spec: .cursor/skills/references/lessons-learned.md (quasi-auto).
  Default dry-run. Use -Apply only after user said "准".

.PARAMETER PendingPath
  Path to 证据/_lesson-pending.md

.PARAMETER LessonsPath
  Default: <repo>/.cursor/lessons-learned.md

.PARAMETER Apply
  Actually append the row.

.PARAMETER MarkL0Promoted
  Also mark L0 section in 未完成.md when l0_section is true.
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $PendingPath,

    [string] $LessonsPath = "",

    [switch] $Apply,

    [switch] $MarkL0Promoted
)

$ErrorActionPreference = "Stop"
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RepoRoot {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Resolve-Path (Join-Path $here "..\..")).Path
}

function Read-Utf8([string]$path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Bom([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, $utf8Bom)
}

function Get-YamlBlock([string]$text) {
    if ($text -match '(?s)```yaml\s*(.*?)\s*```') {
        return $Matches[1]
    }
    throw "pending file missing yaml fenced block: $PendingPath"
}

function Get-YamlMap([string]$yaml) {
    $map = @{}
    foreach ($line in ($yaml -split "`r?`n")) {
        if ($line -match '^\s*#' -or $line.Trim() -eq "") { continue }
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)$') {
            $k = $Matches[1]
            $v = $Matches[2].Trim()
            $quoted = $false
            if ($v -match '^"(.*)"$') { $v = $Matches[1]; $quoted = $true }
            elseif ($v -match "^'(.*)'$") { $v = $Matches[1]; $quoted = $true }
            # Unquoted only: strip YAML trailing comments. Keep A# / #id inside quotes.
            if (-not $quoted -and $v -match '^([^#]+)') { $v = $Matches[1].Trim() }
            $map[$k] = $v
        }
    }
    return $map
}

$repo = Get-RepoRoot
if (-not $LessonsPath) {
    $LessonsPath = Join-Path $repo ".cursor\lessons-learned.md"
}
$PendingPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PendingPath)
$LessonsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LessonsPath)

if (-not (Test-Path -LiteralPath $PendingPath)) { throw "pending not found: $PendingPath" }
if (-not (Test-Path -LiteralPath $LessonsPath)) { throw "lessons table not found: $LessonsPath" }

$pendingText = Read-Utf8 $PendingPath
$map = Get-YamlMap (Get-YamlBlock $pendingText)

$required = @("status", "date", "module", "lesson", "source", "doc", "type")
foreach ($r in $required) {
    if (-not $map.ContainsKey($r) -or [string]::IsNullOrWhiteSpace([string]$map[$r])) {
        throw "pending.yaml missing field: $r"
    }
}

$status = ([string]$map["status"]).Trim().ToLowerInvariant()
if ($status -ne "pending") {
    throw "status=$status; only pending can -Apply"
}

$lesson = ([string]$map["lesson"]).Trim()
if ($lesson.Length -lt 8 -or $lesson -match "无特别经验|本次无") {
    throw "lesson too short or empty boilerplate"
}

$hit = [string]$map["date"]
$keywords = if ($map.ContainsKey("keywords")) { [string]$map["keywords"] } else { "" }
$cause = if ($map.ContainsKey("cause")) { [string]$map["cause"] } else { "" }
$fix = if ($map.ContainsKey("fix")) { [string]$map["fix"] } else { "" }
$prevent = if ($map.ContainsKey("prevent")) { [string]$map["prevent"] } else { "" }
$scope = if ($map.ContainsKey("scope")) { [string]$map["scope"] } else { "" }

if ([string]::IsNullOrWhiteSpace($cause) -or [string]::IsNullOrWhiteSpace($fix)) {
    throw "pending.yaml requires non-empty cause and fix (错因/改正)"
}
if ($cause.Trim().Length -lt 4 -or $fix.Trim().Length -lt 4) {
    throw "cause/fix too short"
}

$date = [string]$map["date"]
$module = [string]$map["module"]
$source = [string]$map["source"]
$doc = [string]$map["doc"]
$type = [string]$map["type"]
# columns: 日期|模块|教训|来源|关联文档|最近命中|类型|症状关键词|错因|改正|防再发|作用域|晋升
$row = "| $date | $module | $lesson | $source | $doc | $hit | $type | $keywords | $cause | $fix | $prevent | $scope | |"

Write-Host "=== commit-lesson-pending ==="
Write-Host "pending: $PendingPath"
Write-Host "lessons: $LessonsPath"
Write-Host "row:"
Write-Host $row

if (-not $Apply) {
    Write-Host "dry-run (no -Apply). After user approval, re-run with -Apply."
    exit 0
}

$lessonsText = Read-Utf8 $LessonsPath
if ($lessonsText -notmatch '(?m)^\|\s*---\s*\|') {
    throw "lessons table header separator not found"
}
$lessonsNew = [regex]::Replace($lessonsText, '(?m)^(\|\s*---\s*\|[^\r\n]*\r?\n)', "`$1$row`r`n", 1)
if ($lessonsNew -eq $lessonsText) {
    throw "failed to insert lessons row"
}
Write-Utf8Bom $LessonsPath $lessonsNew

$pendingNew = [regex]::Replace($pendingText, '(?m)^(\s*status\s*:\s*)pending\b', '${1}committed', 1)
Write-Utf8Bom $PendingPath $pendingNew

$l0Flag = $false
if ($map.ContainsKey("l0_section")) {
    $l0Flag = ([string]$map["l0_section"]).Trim().ToLowerInvariant() -in @("true", "yes", "1")
}
if ($MarkL0Promoted -or $l0Flag) {
    $evidenceDir = Split-Path -Parent $PendingPath
    $docFolder = if ((Split-Path -Leaf $evidenceDir) -eq "证据") { Split-Path -Parent $evidenceDir } else { Split-Path -Parent $evidenceDir }
    $wip = Join-Path $docFolder "未完成.md"
    if (Test-Path -LiteralPath $wip) {
        $wipText = Read-Utf8 $wip
        if ($wipText -match '##\s*错题\s*L0' -and $wipText -notmatch '已晋升L1') {
            $wipNew = [regex]::Replace($wipText, '(##\s*错题\s*L0[^\r\n]*)', "`$1`r`n`r`n- **状态**：已晋升L1", 1)
            Write-Utf8Bom $wip $wipNew
            Write-Host "L0 marked promoted in $wip"
        }
    }
}

Write-Host "OK: committed 1 lesson row."
exit 0