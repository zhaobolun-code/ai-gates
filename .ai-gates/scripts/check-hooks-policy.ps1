# check-hooks-policy.ps1
# 共享：MAINTAINER observe/ask 声明 ↔ hooks.json / pm-gate-check.ps1 一致性。
# 供 validate-pipeline.ps1 与 sessionStart hook（check-hooks-drift.ps1）复用。
#
# Usage:
#   . .cursor/scripts/check-hooks-policy.ps1
#   $r = Get-HooksPolicyReport -RepoRoot (git rev-parse --show-toplevel)
#   powershell -File .cursor/scripts/check-hooks-policy.ps1
#   powershell -File .cursor/scripts/check-hooks-policy.ps1 -AsJson
#   powershell -File .cursor/scripts/check-hooks-policy.ps1 -RepoRoot D:\path
#
# 注意：本文件故意不用 param() 块，避免被 . 点源时因 PowerShell 大小写不敏感
# 覆盖调用方的 $repoRoot。

function Get-HooksRuntimeStatus {
    # Interpreter availability ≠ this client has machine hooks (Trae = soft layer).
    # Override for tests / Unix doctor from a machine that can run ps1:
    #   $env:AI_GATES_HOOKS_RUNTIME = 'hooks_not_wired_no_pwsh'
    $forced = [string]$env:AI_GATES_HOOKS_RUNTIME
    if (-not [string]::IsNullOrWhiteSpace($forced)) {
        $code = $forced.Trim()
        $ok = ($code -ne 'hooks_not_wired_no_pwsh')
        return [ordered]@{ Interpreter = $ok; Wired = $ok; Code = $code }
    }
    $onWindows = $false
    if ($env:OS -eq 'Windows_NT') { $onWindows = $true }
    elseif ($PSVersionTable.PSEdition -eq 'Desktop') { $onWindows = $true }
    elseif ($PSVersionTable.Platform -eq 'Win32NT') { $onWindows = $true }
    if ($onWindows) {
        return [ordered]@{ Interpreter = $true; Wired = $true; Code = 'windows_powershell' }
    }
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return [ordered]@{ Interpreter = $true; Wired = $true; Code = 'unix_pwsh' }
    }
    return [ordered]@{ Interpreter = $false; Wired = $false; Code = 'hooks_not_wired_no_pwsh' }
}

function Get-HooksPolicyReport {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # Step 2（2026-08-03）BOM 扫描注入点：只进函数签名，不进脚本 param() 块——
        # 本文件刻意无 param() 块，避免 . 点源覆盖调用方 $repoRoot。
        [string]$HooksDir,
        [string]$ScriptsDir
    )

    $issues = New-Object System.Collections.Generic.List[string]
    $hooksJsonPath = Join-Path $RepoRoot ".cursor/hooks.json"
    $pmGateCheckPath = Join-Path $RepoRoot ".cursor/hooks/pm-gate-check.ps1"
    $driftHookPath = Join-Path $RepoRoot ".cursor/hooks/check-hooks-drift.ps1"
    $maintainerPath = Join-Path $RepoRoot ".cursor/skills/MAINTAINER.md"

    if (-not (Test-Path -LiteralPath $hooksJsonPath)) {
        $issues.Add("hooks.json missing") | Out-Null
    } else {
        try {
            $hooksRaw = [System.IO.File]::ReadAllText($hooksJsonPath, [System.Text.Encoding]::UTF8)
            $hooksCfg = $hooksRaw | ConvertFrom-Json -ErrorAction Stop
            $hasSessionDrift = $false
            foreach ($ev in $hooksCfg.hooks.PSObject.Properties) {
                foreach ($entry in @($ev.Value)) {
                    $cmd = [string]$entry.command
                    if ([bool]$entry.failClosed) {
                        $issues.Add(("failClosed=true not allowed ({0}: {1})" -f $ev.Name, $cmd)) | Out-Null
                    }
                    if ($ev.Name -eq "sessionStart" -and $cmd -match 'check-hooks-drift\.ps1') {
                        $hasSessionDrift = $true
                    }
                }
            }
            if (-not $hasSessionDrift) {
                $issues.Add("hooks.json missing sessionStart → check-hooks-drift.ps1") | Out-Null
            }
        } catch {
            $issues.Add("hooks.json unreadable/invalid JSON") | Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath $pmGateCheckPath)) {
        $issues.Add("pm-gate-check.ps1 missing") | Out-Null
    } else {
        $pmGateRaw = [System.IO.File]::ReadAllText($pmGateCheckPath, [System.Text.Encoding]::UTF8)
        # 2026-08-03：Cursor 2.2+ hook `permission: ask` 是官方确认 bug（不弹窗直接放行），
        # pm-gate-check 改 deny + user_message 逃生提示；门禁类 hook 必须有 deny 硬拦能力，
        # 且 parse 失败仍 fail-open allow（逃生通道不逼死路）。
        if ($pmGateRaw -notmatch 'function\s+Emit-Deny\b' -or $pmGateRaw -notmatch 'permission\s*=\s*"deny"') {
            $issues.Add("pm-gate-check must Emit-Deny / permission=deny (Cursor 2.2+ ask no-op)") | Out-Null
        }
        if ($pmGateRaw -match 'permission\s*=\s*"ask"') {
            $issues.Add("pm-gate-check must not use permission=ask (Cursor 2.2+ ask no-op)") | Out-Null
        }
        if ($pmGateRaw -notmatch 'parse_failed_fail_open' -and $pmGateRaw -notmatch 'fail-open') {
            $issues.Add("pm-gate-check must fail-open on parse errors") | Out-Null
        }
        if ($pmGateRaw -notmatch 'window_pm_not_this_turn') {
            $issues.Add("pm-gate-check must name window_pm_not_this_turn (120-min window is not this_turn_pm)") | Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath $driftHookPath)) {
        $issues.Add("check-hooks-drift.ps1 missing") | Out-Null
    }

    if (-not (Test-Path -LiteralPath $maintainerPath)) {
        $issues.Add("MAINTAINER.md missing") | Out-Null
    } else {
        $maintainerRaw = [System.IO.File]::ReadAllText($maintainerPath, [System.Text.Encoding]::UTF8)
        if ($maintainerRaw -notmatch 'permission:\s*deny') {
            $issues.Add("MAINTAINER must declare permission: deny for pm-gate-check (Cursor 2.2+ ask bug)") | Out-Null
        }
        if ($maintainerRaw -notmatch 'failClosed:\s*false') {
            $issues.Add("MAINTAINER must declare failClosed: false") | Out-Null
        }
        if ($maintainerRaw -notmatch 'sessionStart' -or $maintainerRaw -notmatch 'check-hooks-drift') {
            $issues.Add("MAINTAINER must document sessionStart / check-hooks-drift") | Out-Null
        }
    }

    # BOM 扫描段（2026-08-03 自我治理 Step 2）：hooks/ + scripts/ 下 *.ps1 首 3 字节须为 EF BB BF。
    # 判 BOM 必须用 ReadAllBytes（Get-Content 会按默认编码解码并吞掉 BOM，无法判定）；
    # 本文件自身也在扫描范围（自举：改动后须保持 BOM）。
    if (-not $HooksDir) { $HooksDir = Join-Path $RepoRoot ".cursor/hooks" }
    if (-not $ScriptsDir) { $ScriptsDir = Join-Path $RepoRoot ".cursor/scripts" }
    foreach ($dir in @($HooksDir, (Join-Path $HooksDir "codex"), $ScriptsDir)) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($psFile in (Get-ChildItem -LiteralPath $dir -Filter *.ps1 -File)) {
            $bytes = [System.IO.File]::ReadAllBytes($psFile.FullName)
            if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
                $rel = $psFile.FullName
                try { $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $psFile.FullName) } catch { }
                $issues.Add(("UTF-8 BOM missing: {0}" -f $rel)) | Out-Null
            }
        }
    }

    $runtime = Get-HooksRuntimeStatus
    if (-not $runtime.Wired) {
        $issues.Add("hooks_not_wired_no_pwsh: macOS/Linux machine hooks need PowerShell 7+ (pwsh); do not report hooks wired") | Out-Null
    }

    return [ordered]@{
        Ok        = ($issues.Count -eq 0)
        Issues    = @($issues)
        Runtime   = $runtime
        CheckedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
}

# Direct invocation (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    $asJson = $false
    $cliRoot = $null
    for ($i = 0; $i -lt $args.Count; $i++) {
        $a = [string]$args[$i]
        if ($a -eq '-AsJson') { $asJson = $true }
        elseif ($a -eq '-RepoRoot' -and ($i + 1) -lt $args.Count) {
            $cliRoot = [string]$args[$i + 1]
            $i++
        }
    }
    if (-not $cliRoot) {
        $cliRoot = git rev-parse --show-toplevel 2>$null
        if (-not $cliRoot) {
            $cliRoot = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "../..")).Path
        }
    }
    $report = Get-HooksPolicyReport -RepoRoot $cliRoot
    $rtCode = if ($report.Runtime) { [string]$report.Runtime.Code } else { "unknown" }
    Write-Host ("machine-hooks: {0}" -f $rtCode)
    if ($asJson) {
        $report | ConvertTo-Json -Compress -Depth 5
    } else {
        if ($report.Ok) {
            Write-Host "hooks policy: OK" -ForegroundColor Green
        } else {
            Write-Host "hooks policy: DRIFT" -ForegroundColor Red
            $report.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
    }
    exit $(if ($report.Ok) { 0 } else { 1 })
}
