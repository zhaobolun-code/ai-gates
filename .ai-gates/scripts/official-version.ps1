# 正式版本整串必须是 x.y.z。允许最前面一个 v 或 V。5.1.0garbage 不是正式版本。

function Test-OfficialVersion {
    param([string]$Version)
    $v = ([string]$Version).Trim() -replace '^[vV](?=\d)', ''
    return [bool]($v -match '^\d+\.\d+\.\d+$')
}

function Get-OfficialSemver {
    param([string]$Version)
    if (-not (Test-OfficialVersion -Version $Version)) { return $null }
    $v = ([string]$Version).Trim() -replace '^[vV](?=\d)', ''
    $m = [regex]::Match($v, '^(\d+)\.(\d+)\.(\d+)$')
    return [pscustomobject]@{
        Major = [int]$m.Groups[1].Value
        Minor = [int]$m.Groups[2].Value
        Patch = [int]$m.Groups[3].Value
        Raw   = $v
    }
}
