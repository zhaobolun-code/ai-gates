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

function Test-PortalHealth {
    param([string]$RepoRoot)
    $issues = New-Object System.Collections.Generic.List[string]
    $central = Join-Path $RepoRoot '.ai-gates'
    foreach ($d in @('skills', 'hooks', 'scripts', 'rules')) {
        $link = Join-Path $RepoRoot (".cursor\$d")
        if (-not (Test-Path -LiteralPath $link)) {
            $issues.Add("portal missing: .cursor/$d (run link-platform.ps1)") | Out-Null
        } else {
            $it = Get-Item -LiteralPath $link -Force
            if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($it.Target -notmatch [regex]::Escape((Join-Path $central $d))) {
                    $issues.Add("portal target mismatch: .cursor/$d -> $($it.Target)") | Out-Null
                }
            } else {
                $issues.Add("portal occupied by real dir: .cursor/$d (migrate then run link-platform.ps1)") | Out-Null
            }
        }
    }
    $hooksLink = Join-Path $RepoRoot '.cursor\hooks.json'
    $centralHooks = Join-Path $central 'hooks.json'
    if (-not (Test-Path -LiteralPath $hooksLink)) {
        $issues.Add("portal missing: .cursor/hooks.json (run link-platform.ps1)") | Out-Null
    } else {
        $it = Get-Item -LiteralPath $hooksLink -Force
        if (-not $it.LinkType) {
            $h1 = (Get-FileHash -LiteralPath $hooksLink -Algorithm SHA256).Hash
            $h2 = (Get-FileHash -LiteralPath $centralHooks -Algorithm SHA256).Hash
            if ($h1 -ne $h2) {
                $issues.Add("stale real file: .cursor/hooks.json differs from .ai-gates/hooks.json (delete it, then run link-platform.ps1)") | Out-Null
            }
        }
    }
    $codex = Join-Path $RepoRoot '.codex'
    if (-not (Test-Path -LiteralPath $codex)) {
        $issues.Add("portal missing: .codex (run link-platform.ps1)") | Out-Null
    } else {
        $it = Get-Item -LiteralPath $codex -Force
        if (-not ($it.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            $issues.Add(".codex is a real dir (run link-platform.ps1 to auto-migrate)") | Out-Null
        }
    }
    return @($issues)
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
    $portalIssues = @(Test-PortalHealth -RepoRoot $repoRoot)
    $allIssues = @($report.Issues) + @($portalIssues)
    $utf8 = New-Object System.Text.UTF8Encoding $false

    if ($report.Ok -and $portalIssues.Count -eq 0) {
        if (Test-Path -LiteralPath $driftFile) {
            Remove-Item -LiteralPath $driftFile -Force -ErrorAction SilentlyContinue
        }
        Write-Audit "OK no_drift"
        Emit-Empty
    }

    $issueText = ($allIssues -join "; ")
    $hint = "MAINTAINER hooks declaration drifted from hooks.json / pm-gate-check.ps1. Align to deny + failClosed:false (Cursor 2.2+ ask no-op), or update MAINTAINER if policy intentionally changed. Run: powershell -File .cursor/scripts/check-hooks-policy.ps1"
    if ($portalIssues.Count -gt 0) {
        $hint += " Portal issues: run: powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1 (idempotent)."
    }
    $payload = [ordered]@{
        ok         = $false
        checkedAt  = $report.CheckedAt
        issues     = @($allIssues)
        hint       = $hint
    }
    [System.IO.File]::WriteAllText($driftFile, ($payload | ConvertTo-Json -Depth 6), $utf8)
    Write-Audit ("DRIFT issues={0}" -f $issueText)

    $ctx = @"
[hooks-policy-drift] SessionStart detected drift:
- $($allIssues -join "`n- ")
Side channel: .ai-gates/hooks-log/hooks-policy-drift.json
Do not silently ignore: fix hooks / update MAINTAINER / re-run link-platform.ps1 as hinted.
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
