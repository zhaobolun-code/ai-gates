# scan-session-errors.ps1 — session-end pattern scan -> draft-lesson-pending (no -Apply).
# 固定模式：DONE 无退出码；把「收集仓已开通」写成「已下发」；把「准」写成上传；空话 pending。
# Max N=5; Pattern-Key 去重。自身 exit 0。禁止传 -Apply。
param(
    [string]$LogDir = "",
    [string]$TextFile = "",
    [string]$Text = ""
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8

function Resolve-RepoRoot {
    $p = $PSScriptRoot
    for ($i = 0; $i -lt 12; $i++) {
        $ver = Join-Path $p ".ai-gates\skills\VERSION"
        if (Test-Path -LiteralPath $ver) { return $p }
        $p = Split-Path -Parent $p
        if (-not $p) { break }
    }
    throw "cannot resolve repo root from " + $PSScriptRoot
}

function Read-Utf8([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Read-TailRaw([string]$path, [int]$maxBytes) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    $fi = Get-Item -LiteralPath $path
    $take = [int64]$maxBytes
    if ($fi.Length -lt $take) { $take = $fi.Length }
    if ($take -le 0) { return "" }
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        [void]$fs.Seek(-$take, [System.IO.SeekOrigin]::End)
        $buf = New-Object byte[] $take
        $read = $fs.Read($buf, 0, [int]$take)
        return $utf8.GetString($buf, 0, $read)
    } finally { $fs.Close() }
}

function Get-Blob {
    if (-not [string]::IsNullOrWhiteSpace($Text)) { return $Text }
    if (-not [string]::IsNullOrWhiteSpace($TextFile)) {
        $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TextFile)
        return Read-Utf8 $p
    }
    $parts = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($LogDir)) {
        $ld = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogDir)
        $parts.Add((Read-TailRaw (Join-Path $ld "write-audit.log") 262144))
        $parts.Add((Read-TailRaw (Join-Path $ld "mark-pm-gate.log") 262144))
    }
    return ($parts -join "`n")
}

function Get-OutDir([string]$repo) {
    if (-not [string]::IsNullOrWhiteSpace($env:AI_GATES_WINDOW)) {
        $w = $env:AI_GATES_WINDOW
        $ev = Join-Path $w "证据"
        if (-not (Test-Path -LiteralPath $ev)) { New-Item -ItemType Directory -Path $ev -Force | Out-Null }
        return $ev
    }
    $exec = Join-Path $repo ".ai-gates\Doc\AI流水线\执行中"
    $wips = @()
    if (Test-Path -LiteralPath $exec) {
        $wips = @(Get-ChildItem -LiteralPath $exec -Recurse -Filter "未完成.md" -ErrorAction SilentlyContinue)
    }
    if ($wips.Count -eq 1) {
        $ev = Join-Path (Split-Path -Parent $wips[0].FullName) "证据"
        if (-not (Test-Path -LiteralPath $ev)) { New-Item -ItemType Directory -Path $ev -Force | Out-Null }
        return $ev
    }
    $tmp = Join-Path $repo ".ai-gates\tmp\session-scan"
    if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }
    return $tmp
}

function Get-KnownKeys([string]$lessonsPath, [string]$outDir) {
    $set = @{}
    if (Test-Path -LiteralPath $lessonsPath) {
        foreach ($line in [System.IO.File]::ReadAllLines($lessonsPath, $utf8)) {
            if ($line -notmatch '^\|') { continue }
            $low = $line.ToLowerInvariant()
            foreach ($k in @("done_no_exit", "collect_as_shipped", "approve_as_upload", "empty_pending")) {
                if ($low.IndexOf($k) -ge 0) { $set[$k] = $true }
            }
        }
    }
    if (Test-Path -LiteralPath $outDir) {
        foreach ($f in @(Get-ChildItem -LiteralPath $outDir -Filter "_lesson-pending-*.md" -ErrorAction SilentlyContinue)) {
            $t = Read-Utf8 $f.FullName
            if ($t -match '(?m)^\s*keywords\s*:\s*"?([^"\r\n]+)"?') {
                $kw = $Matches[1].Trim().ToLowerInvariant()
                $set[$kw] = $true
            }
            $leaf = $f.BaseName.ToLowerInvariant()
            if ($leaf.StartsWith("_lesson-pending-")) {
                $set[$leaf.Substring(16)] = $true
            }
        }
    }
    return $set
}

function Invoke-Draft([string]$repo, [string]$outPath, [string]$key, [string]$detail) {
    $draft = Join-Path $repo ".ai-gates\scripts\draft-lesson-pending.ps1"
    $fail = "[FAIL] $key :: $detail"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    # 禁止传 -Apply（draft-lesson-pending 默认不把 Apply 传给 commit）
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$draft`" -FailText `"$fail`" -OutPath `"$outPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $null = $p.StandardOutput.ReadToEnd()
    $null = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [int]$p.ExitCode
}

try {
    $repo = Resolve-RepoRoot
    $blob = Get-Blob
    $outDir = Get-OutDir $repo
    $lessonsPath = Join-Path $repo ".ai-gates\lessons-learned.md"
    $known = Get-KnownKeys $lessonsPath $outDir

    $hits = New-Object System.Collections.Generic.List[object]
    $hasDone = ($blob -match '(?i)\bDONE\b' -or $blob -match '(?i)locally-validated')
    $hasExit = ($blob -match '(?i)exit\s*=?\s*\d' -or $blob -match '(?i)LASTEXITCODE' -or $blob.IndexOf("退出码") -ge 0)
    if ($hasDone -and -not $hasExit) {
        [void]$hits.Add(@{ Key = "DONE_NO_EXIT"; Detail = "DONE/locally-validated without exit code" })
    }
    if ($blob.IndexOf("收集仓已开通") -ge 0 -and $blob.IndexOf("已下发") -ge 0) {
        [void]$hits.Add(@{ Key = "COLLECT_AS_SHIPPED"; Detail = "wrote collect-open as already-shipped" })
    }
    if ($blob.IndexOf("准") -ge 0 -and ($blob.IndexOf("上传") -ge 0 -or $blob -match '(?i)gh pr create')) {
        [void]$hits.Add(@{ Key = "APPROVE_AS_UPLOAD"; Detail = "wrote 准 as upload/gh pr create" })
    }
    if ($blob.IndexOf("无特别经验") -ge 0 -or $blob.IndexOf("本次无") -ge 0) {
        [void]$hits.Add(@{ Key = "EMPTY_PENDING"; Detail = "empty-talk pending boilerplate" })
    }

    $written = 0
    foreach ($h in $hits) {
        if ($written -ge 5) { break }
        $k = [string]$h.Key
        $kl = $k.ToLowerInvariant()
        if ($known.ContainsKey($kl)) {
            Write-Host ("skip dup Pattern-Key " + $k)
            continue
        }
        $outPath = Join-Path $outDir ("_lesson-pending-" + $k + ".md")
        $code = Invoke-Draft $repo $outPath $k ([string]$h.Detail)
        Write-Host ("draft " + $k + " exit=" + $code + " path=" + $outPath)
        $known[$kl] = $true
        $written++
    }
    Write-Host ("scan hits=" + $hits.Count + " pending_written=" + $written + " outDir=" + $outDir)
} catch {
    Write-Host ("scan swallow: " + $_.Exception.Message)
}
exit 0
