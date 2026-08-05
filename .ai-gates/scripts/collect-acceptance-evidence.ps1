<#
.SYNOPSIS
  验收证据采集：把 A# 通过证据（控制台日志尾部 / 截图 / 测试报告）归集到窗口证据目录，
  生成 evidence.md，让"日志出关键词 ≠ 修好"有机器可查的证据链。

.DESCRIPTION
  - -DocFolder：方案夹路径（证据写入 <DocFolder>/证据/）
  - -Aids："A1,A2" 或 "A1 A2"；-Status 默认「通过」
  - -LogFile：控制台/Editor.log 路径（写入证据/evidence-console.md 尾部 200 行）
  - -Screenshots："a.png,b.png"；-TestReport：测试报告文件（拷入证据目录）
  - 输出 evidence.md（A# 表 + 证据文件清单）；退出码 0 = 采集成功

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/collect-acceptance-evidence.ps1 `
    -DocFolder "Assets/Doc/xxx/执行中/方案" -Aids "A1,A2" -LogFile "C:/logs/Editor.log"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DocFolder,
    [string]$Aids = '',
    [string]$Status = '通过',
    [string]$LogFile = '',
    [string]$Screenshots = '',
    [string]$TestReport = '',
    [string]$Note = '',
    [int]$LogTailLines = 200
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path -LiteralPath $DocFolder)) {
    Write-Error "DocFolder not found: $DocFolder"
    exit 2
}

$zhEvidence = [string]([char]0x8BC1) + [char]0x636E  # 证据
$evDir = Join-Path $DocFolder $zhEvidence
New-Item -ItemType Directory -Force -Path $evDir | Out-Null

$copied = New-Object System.Collections.Generic.List[string]

if ($LogFile -and (Test-Path -LiteralPath $LogFile)) {
    $tail = Get-Content -LiteralPath $LogFile -Tail $LogTailLines -Encoding UTF8
    $logOut = Join-Path $evDir "evidence-console.md"
    [System.IO.File]::WriteAllLines($logOut, @("# 控制台/日志尾部（来源：$LogFile）", '') + $tail, (New-Object System.Text.UTF8Encoding($true)))
    $copied.Add("evidence-console.md") | Out-Null
}

foreach ($s in @($Screenshots -split ',')) {
    $s = $s.Trim()
    if (-not $s) { continue }
    if (Test-Path -LiteralPath $s) {
        Copy-Item -LiteralPath $s -Destination $evDir -Force
        $copied.Add((Split-Path $s -Leaf)) | Out-Null
    } else {
        Write-Warning "screenshot not found: $s"
    }
}

if ($TestReport -and (Test-Path -LiteralPath $TestReport)) {
    Copy-Item -LiteralPath $TestReport -Destination $evDir -Force
    $copied.Add((Split-Path $TestReport -Leaf)) | Out-Null
}

$aidList = @($Aids -split '[,\s]+' | Where-Object { $_ })
$aidRows = if ($aidList.Count -gt 0) {
    ($aidList | ForEach-Object { "| $_ | $Status | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |" }) -join "`n"
} else {
    "| （未列 A#） | $Status | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |"
}

$md = @(
    "# 验收证据（$(Get-Date -Format 'yyyy-MM-dd HH:mm')）"
    ''
    "> 窗口：$DocFolder"
    if ($Note) { "> 备注：$Note" }
    ''
    '## A# 验收'
    ''
    '| A# | 结论 | 时间 |'
    '| --- | --- | --- |'
    $aidRows
    ''
    '## 证据文件'
    ''
    if ($copied.Count -gt 0) {
        ($copied | ForEach-Object { "- $_" }) -join "`n"
    } else {
        '- （无自动采集文件）'
    }
    ''
    '> 诚实约定：证据只说明"按步骤核对了这些点"；业务是否可接受仍以你亲眼看为准。'
) -join "`n"

$outFile = Join-Path $evDir "evidence.md"
[System.IO.File]::WriteAllText($outFile, $md, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "evidence written: $outFile"
Write-Host ("copied files: {0}" -f ($copied -join ', '))
exit 0
