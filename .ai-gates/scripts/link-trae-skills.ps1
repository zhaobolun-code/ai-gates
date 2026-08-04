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
