# ensure-project-context-sections.ps1
# 升级或再次初始化时，给已有 .cursor/project-context.md 补上模板里的三节。
# 不覆盖已有同名节。已有「Claude 侧事实」时不再补「客户端事实」。
# 没有 project-context.md 时什么都不做（新建走 init-project-context.ps1）。

param(
    [string]$RepoRoot = "",
    [string]$ContextPath = "",
    [string]$TemplatePath = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

if (-not $RepoRoot) {
    $RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    }
}
if (-not $ContextPath) { $ContextPath = Join-Path $RepoRoot ".cursor/project-context.md" }
if (-not $TemplatePath) {
    $candidates = @(
        (Join-Path $RepoRoot ".ai-gates/skills/project-context.template.md"),
        (Join-Path $RepoRoot ".cursor/skills/project-context.template.md")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $TemplatePath = $c; break }
    }
}

if (-not (Test-Path -LiteralPath $ContextPath)) {
    Write-Host "project-context sections: no file, skip"
    exit 0
}
if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "project-context template missing: $TemplatePath"
}

function Read-TextFile {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $enc = New-Object System.Text.UTF8Encoding $bom
    $text = $enc.GetString($bytes)
    if ($bom) { $text = $text.TrimStart([char]0xFEFF) }
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    return @{ Text = $text; Bom = $bom; NewLine = $nl }
}

function Split-Lines {
    param([string]$Text)
    return @($Text -split "`r?`n", -1)
}

function Get-SectionSpan {
    param([string[]]$Lines, [string]$Title)
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ("^##\s+" + [regex]::Escape($Title) + "\s*$")) { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $end = $Lines.Count - 1
    for ($j = $start + 1; $j -lt $Lines.Count; $j++) {
        if ($Lines[$j] -match '^##\s+') { $end = $j - 1; break }
    }
    while ($end -gt $start -and [string]::IsNullOrWhiteSpace($Lines[$end])) { $end-- }
    return @{ Start = $start; End = $end }
}

function Get-SectionText {
    param([string[]]$Lines, [string]$Title, [string]$NewLine)
    $span = Get-SectionSpan -Lines $Lines -Title $Title
    if ($null -eq $span) { return $null }
    return ($Lines[$span.Start..$span.End] -join $NewLine)
}

function Get-IndexTargets {
    param([string[]]$Lines)
    $span = Get-SectionSpan -Lines $Lines -Title "先读哪一节"
    if ($null -eq $span) { return @() }
    $found = @()
    for ($i = $span.Start; $i -le $span.End; $i++) {
        if ($Lines[$i] -notmatch '^\|') { continue }
        $cells = @($Lines[$i].Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
        if ($cells.Count -ge 2) { $found += $cells[$cells.Count - 1] }
    }
    return $found
}

function Test-HasTarget {
    param([string[]]$Targets, [string]$Name)
    if ($Name -eq "客户端事实") {
        return ($Targets -contains "客户端事实" -or $Targets -contains "Claude 侧事实")
    }
    return ($Targets -contains $Name)
}

$wanted = @("常用命令", "仓库分仓", "客户端事实")
$src = Read-TextFile -Path $TemplatePath
$dst = Read-TextFile -Path $ContextPath
$srcLines = Split-Lines -Text $src.Text
$lines = [System.Collections.Generic.List[string]]@(Split-Lines -Text $dst.Text)
$nl = $dst.NewLine
$added = New-Object System.Collections.Generic.List[string]

$templateRows = @()
$srcSpan = Get-SectionSpan -Lines $srcLines -Title "先读哪一节"
if ($null -ne $srcSpan) {
    for ($i = $srcSpan.Start; $i -le $srcSpan.End; $i++) {
        if ($srcLines[$i] -notmatch '^\|') { continue }
        $cells = @($srcLines[$i].Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
        if ($cells.Count -ge 2 -and ($wanted -contains $cells[$cells.Count - 1])) {
            $templateRows += $srcLines[$i].TrimEnd()
        }
    }
}

$haveIndex = $null -ne (Get-SectionSpan -Lines $lines.ToArray() -Title "先读哪一节")
if (-not $haveIndex) {
    $block = @(
        "## 先读哪一节",
        "",
        "先读本表，再只读这一轮点到的节。没点到的不读。",
        "",
        "| 这一轮在做 | 读 |",
        "| --- | --- |"
    ) + @($templateRows) + @("| 对上了别的标题 | 只读那一节 |", "")
    $insertAt = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+') { $insertAt = $i; break }
        $insertAt = $i + 1
    }
    for ($k = $block.Count - 1; $k -ge 0; $k--) {
        $lines.Insert($insertAt, $block[$k])
    }
    $added.Add("先读哪一节") | Out-Null
} else {
    $targets = @(Get-IndexTargets -Lines $lines.ToArray())
    $missingRows = @()
    foreach ($row in $templateRows) {
        $cells = @($row.Split('|') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
        $name = $cells[$cells.Count - 1]
        if (-not (Test-HasTarget -Targets $targets -Name $name)) { $missingRows += $row }
    }
    if ($missingRows.Count -gt 0) {
        $span = Get-SectionSpan -Lines $lines.ToArray() -Title "先读哪一节"
        $at = -1
        $lastTable = -1
        for ($i = $span.Start; $i -le $span.End; $i++) {
            if ($lines[$i] -match '对上了别的标题') { $at = $i; break }
            if ($lines[$i] -match '^\|') { $lastTable = $i }
        }
        if ($at -lt 0) { $at = $lastTable + 1 }
        if ($at -lt 0) { $at = $span.End + 1 }
        for ($k = $missingRows.Count - 1; $k -ge 0; $k--) {
            $lines.Insert($at, $missingRows[$k])
        }
        $added.Add("索引行") | Out-Null
    }
}

$sectionBlocks = @()
foreach ($name in $wanted) {
    $exists = $null -ne (Get-SectionSpan -Lines $lines.ToArray() -Title $name)
    if ($name -eq "客户端事实" -and ($null -ne (Get-SectionSpan -Lines $lines.ToArray() -Title "Claude 侧事实"))) {
        $exists = $true
    }
    if ($exists) { continue }
    $block = Get-SectionText -Lines $srcLines -Title $name -NewLine $nl
    if ([string]::IsNullOrWhiteSpace($block)) { throw "template missing section: $name" }
    $sectionBlocks += $block
    $added.Add($name) | Out-Null
}

if ($sectionBlocks.Count -gt 0) {
    $chunk = ($sectionBlocks -join ($nl + $nl))
    $anchor = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+模型路由') { $anchor = $i; break }
    }
    $chunkLines = @(Split-Lines -Text ($chunk + $nl))
    if ($anchor -ge 0) {
        for ($k = $chunkLines.Count - 1; $k -ge 0; $k--) {
            $lines.Insert($anchor, $chunkLines[$k])
        }
    } else {
        if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines.Add("")
        }
        foreach ($cl in $chunkLines) { $lines.Add($cl) }
    }
}

if ($added.Count -eq 0) {
    Write-Host "project-context sections: unchanged"
    exit 0
}

$out = ($lines -join $nl)
if (-not $out.EndsWith($nl)) { $out += $nl }
$enc = New-Object System.Text.UTF8Encoding $dst.Bom
[System.IO.File]::WriteAllText($ContextPath, $out, $enc)
Write-Host ("project-context sections: added " + ($added -join ", "))
exit 0
