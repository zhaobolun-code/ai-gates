# 正式版本整串必须是 x.y.z。允许最前面一个 v 或 V。5.1.0garbage 不是正式版本。

function Test-OfficialVersion {
    param([string]$Version)
    $v = ([string]$Version).Trim() -replace '^[vV](?=\d)', ''
    return [bool]($v -match '^\d+\.\d+\.\d+$')
}

function Test-TestPackVersion {
    param([string]$Version)
    $v = ([string]$Version).Trim() -replace '^[vV](?=\d)', ''
    return [bool]($v -match '^\d+\.\d+\.\d+A$')
}

function Test-AcceptedPackVersion {
    param([string]$Version)
    return (Test-OfficialVersion -Version $Version) -or (Test-TestPackVersion -Version $Version)
}

function Get-PackSemver {
    param([string]$Version)
    $official = Get-OfficialSemver -Version $Version
    if ($null -ne $official) { return $official }
    if (-not (Test-TestPackVersion -Version $Version)) { return $null }
    $v = ([string]$Version).Trim() -replace '^[vV](?=\d)', ''
    return Get-OfficialSemver -Version $v.Substring(0, $v.Length - 1)
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

function Test-TagMatchesPackVersion {
    param([string]$Tag, [string]$PackVersion)
    $tagVer = Get-OfficialSemver -Version $Tag
    $packVer = Get-OfficialSemver -Version $PackVersion
    if ($null -eq $tagVer -or $null -eq $packVer) { return $false }
    return ($tagVer.Major -eq $packVer.Major -and $tagVer.Minor -eq $packVer.Minor -and $tagVer.Patch -eq $packVer.Patch)
}
