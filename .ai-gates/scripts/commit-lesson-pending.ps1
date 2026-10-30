<#
.SYNOPSIS
  Commit lesson pending row into .ai-gates/lessons-learned.md after user approval.

.DESCRIPTION
  Spec: .cursor/skills/references/lessons-learned.md (quasi-auto).
  Default dry-run. Use -Apply only after user said "准".

.PARAMETER PendingPath
  Path to 证据/_lesson-pending.md

.PARAMETER LessonsPath
  Default: <repo>/.ai-gates/lessons-learned.md

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

function Test-PlaceholderCauseFix([string]$cause, [string]$fix) {
    # keep in sync with test-publish-reject.ps1 Test-PlaceholderCauseFix
    $needles = @(
        "原因待人写",
        "原因待确认",
        "Fix the failing check",
        "keep cause and fix non-empty"
    )
    foreach ($n in $needles) {
        if ($cause.IndexOf($n) -ge 0 -or $fix.IndexOf($n) -ge 0) {
            throw "placeholder cause/fix refused: $n"
        }
    }
}

function Test-HoleLines($map) {
    # keep in sync with test-publish-reject.ps1 Test-HoleLines
    $origin = ""
    if ($map.ContainsKey("origin")) {
        $origin = ([string]$map["origin"]).Trim().Trim([char]34).Trim([char]39).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($origin)) { return }
    if (@("逆链", "思考碰撞") -notcontains $origin) { return }

    $sig = ""
    $trig = ""
    $nxt = ""
    if ($map.ContainsKey("hole_signature")) { $sig = ([string]$map["hole_signature"]).Trim().Trim([char]34).Trim([char]39).Trim() }
    if ($map.ContainsKey("hole_trigger")) { $trig = ([string]$map["hole_trigger"]).Trim().Trim([char]34).Trim([char]39).Trim() }
    if ($map.ContainsKey("hole_next")) { $nxt = ([string]$map["hole_next"]).Trim().Trim([char]34).Trim([char]39).Trim() }

    if ([string]::IsNullOrWhiteSpace($sig) -or [string]::IsNullOrWhiteSpace($trig) -or [string]::IsNullOrWhiteSpace($nxt)) {
        throw "origin=$origin requires hole_signature/hole_trigger/hole_next"
    }

    if ($sig -notmatch '^([^/|]{2,16})/(A#|Mandatory|机器现象|失败标准|冻结表|不选的)$') {
        throw "hole_signature must match 洞种/锚类型"
    }
    $kind = $Matches[1]
    foreach ($w in @("类似", "大概", "可能", "应该")) {
        if ($kind.IndexOf($w) -ge 0) {
            throw "hole_signature forbidden word: $w"
        }
    }
    $holeFields = @{ hole_trigger = $trig; hole_next = $nxt }
    foreach ($fname in @("hole_trigger", "hole_next")) {
        $val = [string]$holeFields[$fname]
        $compact = [regex]::Replace($val, '\s', '')
        if ($compact.Length -lt 4) {
            throw "$fname too short"
        }
        foreach ($p in @("后续处理", "待确认", "下次注意", "后续再看")) {
            if ($val.IndexOf($p) -ge 0) {
                throw "$fname placeholder: $p"
            }
        }
    }
}

$repo = Get-RepoRoot
if (-not $LessonsPath) {
    $LessonsPath = Join-Path $repo ".ai-gates\lessons-learned.md"
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
# keep in sync with test-publish-reject.ps1; before publish gate
Test-PlaceholderCauseFix $cause $fix
Test-HoleLines $map

$rejectScript = Join-Path $PSScriptRoot "test-publish-reject.ps1"
if (-not (Test-Path -LiteralPath $rejectScript)) {
    throw "missing test-publish-reject.ps1"
}
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$rejectScript`" -PendingPath `"$PendingPath`""
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$rp = [System.Diagnostics.Process]::Start($psi)
$rout = $rp.StandardOutput.ReadToEnd()
$rerr = $rp.StandardError.ReadToEnd()
$rp.WaitForExit()
if ($rout) { Write-Host $rout.TrimEnd() }
if ($rp.ExitCode -ne 0) {
    if ($rerr) { Write-Host $rerr.TrimEnd() }
    throw "publish-reject 无证据/空话/缺字段 exit=$($rp.ExitCode)"
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

# keep in sync with test-publish-reject.ps1; before writing main table
Test-PlaceholderCauseFix $cause $fix

$lessonsText = Read-Utf8 $LessonsPath
$dupPrefix = "| $date | $module | $lesson | $source | $doc |"
if ($lessonsText.IndexOf($dupPrefix) -ge 0) {
    $existMark = [string]([char]0x5DF2) + [string]([char]0x5B58) + [string]([char]0x5728)
    Write-Host $existMark
    [Console]::Out.WriteLine($existMark)
    $pendingNew = [regex]::Replace($pendingText, '(?m)^(\s*status\s*:\s*)pending\b', '${1}committed', 1)
    Write-Utf8Bom $PendingPath $pendingNew
    Write-Host "OK: row already in lessons table; pending marked committed."
    exit 0
}
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