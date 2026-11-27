# 验收证据默认结论，以及运行日志按行时间戳计新鲜度。
$ErrorActionPreference = 'Stop'
$failed = 0
function Assert-Case {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) { Write-Host "PASS $Name" }
    else { Write-Host "FAIL $Name $Detail"; $script:failed++ }
}

$root = Join-Path $env:TEMP ("evidence-gates-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
    $collect = Join-Path $PSScriptRoot 'collect-acceptance-evidence.ps1'
    $emptyDir = Join-Path $root 'empty'
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File $collect -DocFolder $emptyDir | Out-Null
    $evidence = Get-Content -LiteralPath (Join-Path $emptyDir '证据\evidence.md') -Raw -Encoding UTF8
    Assert-Case 'empty evidence is not pass' ($evidence -match '未采集' -and $evidence -notmatch '\| 通过 \|') $evidence

    $verify = Join-Path $PSScriptRoot 'verify-runtime-evidence.ps1'
    $old = (Get-Date).AddHours(-3).ToString('yyyy-MM-dd HH:mm:ss')
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $staleLog = Join-Path $root 'stale.log'
    @(
        $old
        'OLD_KEYWORD_HIT'
        $now
        'unrelated append'
    ) | Set-Content -LiteralPath $staleLog -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verify -Keywords 'OLD_KEYWORD_HIT' -EditorLogPath $staleLog -SinceMinutes 30 -TailLines 0 | Out-Null
    Assert-Case 'old keyword line stays outside the window' ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"

    $freshLog = Join-Path $root 'fresh.log'
    @(
        $now
        'NEW_KEYWORD_HIT'
    ) | Set-Content -LiteralPath $freshLog -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verify -Keywords 'NEW_KEYWORD_HIT' -EditorLogPath $freshLog -SinceMinutes 30 -TailLines 0 | Out-Null
    Assert-Case 'fresh keyword line counts' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 1 }
exit 0
