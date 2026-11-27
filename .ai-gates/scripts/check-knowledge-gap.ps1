# 知识缺口三要素。分歧来源再要洞种三行。不扫全仓，只查传入文本。
param(
    [string]$Text = "",
    [string]$Path = ""
)
$ErrorActionPreference = "Stop"
if (-not $Text -and $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "missing $Path" }
    $Text = [System.IO.File]::ReadAllText($Path)
}
$issues = New-Object System.Collections.Generic.List[string]
if ($Text -notmatch '上下文位置：\s*\S') { $issues.Add("missing-context") | Out-Null }
if ($Text -notmatch '已尝试：\s*\S') { $issues.Add("missing-tried") | Out-Null }
if ($Text -match '来源：分歧标注') {
    foreach ($key in @("hole_signature", "hole_trigger", "hole_next")) {
        if ($Text -notmatch ($key + ':\s*\S')) { $issues.Add("missing-$key") | Out-Null }
    }
}
if ($issues.Count -gt 0) {
    Write-Output ($issues -join ",")
    exit 1
}
Write-Output "OK"
exit 0
