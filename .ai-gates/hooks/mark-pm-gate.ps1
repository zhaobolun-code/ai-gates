# mark-pm-gate.ps1
# 2026-11-11：打点已撤。不再写 pm-gate.json。
# 回复正文里出现 [FAIL] token :: 明细 时，起草 tmp 下的 pending，不写错题主表。
$ErrorActionPreference = "Continue"
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
try {
    $stdin = [Console]::In.ReadToEnd()
    if ($stdin -match '\[FAIL\]\s+\S+\s*::') {
        $hooksDir = $PSScriptRoot
        $repo = $hooksDir
        for ($i = 0; $i -lt 6; $i++) {
            if (Test-Path -LiteralPath (Join-Path $repo ".ai-gates\skills\VERSION")) { break }
            $parent = Split-Path -Parent $repo
            if (-not $parent -or $parent -eq $repo) { break }
            $repo = $parent
        }
        $draft = Join-Path $repo ".ai-gates\scripts\draft-lesson-pending.ps1"
        $out = Join-Path $repo ".ai-gates\tmp\lesson-pending-from-hook.md"
        if (Test-Path -LiteralPath $draft) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $draft -FailText $stdin -OutPath $out | Out-Null
        }
    }
} catch { }
exit 0
