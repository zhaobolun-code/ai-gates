# check-hooks-drift.ps1
# sessionStart hook — 模板/声明漂移检测（对齐 Bulwark check-template-drift 思路的最小切口）。
#
# 比对 MAINTAINER observe/ask 声明 ↔ hooks.json / pm-gate-check.ps1 / 本 hook 是否齐套。
# 漂移时：
#   1) 写 .ai-gates/hooks-log/hooks-policy-drift.json（侧写，防 additional_context 偶发未注入）
#   2) stdout 返回 additional_context（+ additionalContext 兼容）提示 Agent/用户
# 无漂移：清掉 drift 文件，返回 {}。
# failClosed 须为 false；任何异常 fail-open 返回 {}。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Write-Audit {
    param([string]$Line)
    try {
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $auditFile = Join-Path $logDir "hooks-policy-drift.log"
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
    }
}

function Emit-Empty {
    Write-Output "{}"
    exit 0
}

try {
    # drain stdin (sessionStart may send JSON; ignore content)
    $null = [Console]::In.ReadToEnd()

    $cursorRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $repoRoot = (Resolve-Path (Join-Path $cursorRoot "..")).Path
    $logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $driftFile = Join-Path $logDir "hooks-policy-drift.json"
    $policyScript = Join-Path $cursorRoot "scripts\check-hooks-policy.ps1"

    if (-not (Test-Path -LiteralPath $policyScript)) {
        Write-Audit "WARN policy_script_missing"
        Emit-Empty
    }

    . $policyScript
    $report = Get-HooksPolicyReport -RepoRoot $repoRoot
    $utf8 = New-Object System.Text.UTF8Encoding $false

    if ($report.Ok) {
        if (Test-Path -LiteralPath $driftFile) {
            Remove-Item -LiteralPath $driftFile -Force -ErrorAction SilentlyContinue
        }
        Write-Audit "OK no_drift"
        Emit-Empty
    }

    $issueText = ($report.Issues -join "; ")
    $payload = [ordered]@{
        ok         = $false
        checkedAt  = $report.CheckedAt
        issues     = @($report.Issues)
        hint       = "MAINTAINER hooks declaration drifted from hooks.json / pm-gate-check.ps1. Align to deny + failClosed:false (Cursor 2.2+ ask no-op), or update MAINTAINER if policy intentionally changed. Run: powershell -File .cursor/scripts/check-hooks-policy.ps1"
    }
    [System.IO.File]::WriteAllText($driftFile, ($payload | ConvertTo-Json -Depth 6), $utf8)
    Write-Audit ("DRIFT issues={0}" -f $issueText)

    $ctx = @"
[hooks-policy-drift] SessionStart detected drift between MAINTAINER and hooks implementation:
- $($report.Issues -join "`n- ")
Side channel: .ai-gates/hooks-log/hooks-policy-drift.json
Do not silently ignore: fix hooks or update MAINTAINER, then re-run check-hooks-policy.ps1.
"@
    $result = [ordered]@{
        additional_context = $ctx
        additionalContext  = $ctx
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
} catch {
    Write-Audit ("ERROR fail_open msg=$($_.Exception.Message)")
    Emit-Empty
}
