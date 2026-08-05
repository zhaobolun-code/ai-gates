# Link .trae/skills -> .cursor/skills (same files for Cursor and Trae)
# Run from repo root: powershell -ExecutionPolicy Bypass -File .ai-gates/scripts/link-trae-skills.ps1
# (also covered by .ai-gates/link-platform.ps1; kept standalone for Trae-only setups)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$centralSkills = Join-Path $root ".ai-gates\skills"
$cursorSkills = Join-Path $root ".cursor\skills"
$traeSkills = Join-Path $root ".trae\skills"

if (-not (Test-Path $centralSkills)) {
    throw "Missing central skills dir: $centralSkills"
}

$traeDir = Split-Path $traeSkills -Parent
if (-not (Test-Path $traeDir)) {
    New-Item -ItemType Directory -Path $traeDir -Force | Out-Null
}

if (Test-Path $traeSkills) {
    $item = Get-Item $traeSkills -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -eq $centralSkills -or $target -like "*\.ai-gates\skills" -or $target -eq $cursorSkills -or $target -like "*\.cursor\skills") {
            Write-Host "OK: .trae/skills already linked (target: $target)"
            exit 0
        }
        throw ".trae/skills points elsewhere: $target. Remove it first."
    }
    Write-Host "Removing old .trae/skills copy..."
    Remove-Item $traeSkills -Recurse -Force
}

Write-Host "Creating junction..."
cmd /c "mklink /J `"$traeSkills`" `"$centralSkills`""
Write-Host "Done: .trae/skills -> .ai-gates/skills"

# 2026-08-05：规则目录同步（.trae/rules -> .ai-gates/rules）
$centralRules = Join-Path $root ".ai-gates\rules"
$traeRules = Join-Path $root ".trae\rules"
if (-not (Test-Path $centralRules)) {
    Write-Host "WARN: central rules dir missing (skip .trae/rules): $centralRules"
} else {
    if (Test-Path $traeRules) {
        $item = Get-Item $traeRules -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "OK: .trae/rules already linked (target: $($item.Target))"
        } else {
            throw ".trae/rules occupied by a real directory: $traeRules. Remove it first."
        }
    } else {
        cmd /c "mklink /J `"$traeRules`" `"$centralRules`""
        Write-Host "Done: .trae/rules -> .ai-gates/rules"
    }
}
