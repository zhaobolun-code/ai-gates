# Link .trae/skills -> .cursor/skills (same files for Cursor and Trae)
# Run from repo root: powershell -ExecutionPolicy Bypass -File .cursor/scripts/link-trae-skills.ps1

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$cursorSkills = Join-Path $root ".cursor\skills"
$traeSkills = Join-Path $root ".trae\skills"

if (-not (Test-Path $cursorSkills)) {
    throw "Missing canonical skills dir: $cursorSkills"
}

$traeDir = Split-Path $traeSkills -Parent
if (-not (Test-Path $traeDir)) {
    New-Item -ItemType Directory -Path $traeDir -Force | Out-Null
}

if (Test-Path $traeSkills) {
    $item = Get-Item $traeSkills -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -eq $cursorSkills -or $target -like "*\.cursor\skills") {
            Write-Host "OK: .trae/skills already linked to .cursor/skills"
            exit 0
        }
        throw ".trae/skills points elsewhere: $target. Remove it first."
    }
    Write-Host "Removing old .trae/skills copy..."
    Remove-Item $traeSkills -Recurse -Force
}

Write-Host "Creating junction..."
cmd /c "mklink /J `"$traeSkills`" `"$cursorSkills`""
Write-Host "Done: .trae/skills -> .cursor/skills"
