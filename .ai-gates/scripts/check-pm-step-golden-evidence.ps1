<#
.SYNOPSIS
  核对「热路径批量回归」结案前各场景 *-verify.json 是否均为 pass（不替代跑黄金）。

.DESCRIPTION
  - 场景 ID **默认** G1,G2,G5（本仓库 Chemical 习惯）；其他项目请显式传 -RequireSceneIds，
    或与 `.cursor/project-context.md` §热路径批量回归「场景 ID」列一致。
  - 在指定证据目录查找 `{SceneId}-*-verify.json`。
  - 每景须：文件存在 + JSON.ok=true + overallHit=true + （若有 volumeGate 字段则 volumeGatePass≠false）。
  - 本脚本**不**启动 Unity、不改断言；仅静态核对已有 JSON。缺文件/非 pass → exit 1；用法错误 → exit 2。
  - 跑黄金前仍须关闭本机 Unity Editor（见 run-unity-verify-golden.ps1）。

.PARAMETER EvidenceDir
  含 `{SceneId}-*-verify.json` 的目录。

.PARAMETER RequireSceneIds
  逗号分隔场景 ID。默认 G1,G2,G5；应以 project-context §热路径批量回归为准覆盖。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/check-pm-step-golden-evidence.ps1 `
    -EvidenceDir ".ai-gates/Doc/.../证据" -RequireSceneIds "G1,G2,G5"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidenceDir,
    [string]$RequireSceneIds = "G1,G2,G5"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Write-Check {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host "[check-pm-step-golden-evidence] $Msg" -ForegroundColor $Color
}

if ([string]::IsNullOrWhiteSpace($EvidenceDir) -or -not (Test-Path -LiteralPath $EvidenceDir)) {
    Write-Check "FAIL reason=evidence_dir_missing path=$EvidenceDir" "Red"
    exit 2
}

$ids = @($RequireSceneIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($ids.Count -eq 0) {
    Write-Check "FAIL reason=empty_RequireSceneIds" "Red"
    exit 2
}

$fail = $false
foreach ($id in $ids) {
    $cands = @(Get-ChildItem -LiteralPath $EvidenceDir -File -Filter ("{0}-*-verify.json" -f $id) -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($cands.Count -eq 0) {
        Write-Check "FAIL scene=$id reason=no_verify_json" "Red"
        $fail = $true
        continue
    }
    $jsonPath = $cands[0].FullName
    try {
        $raw = [System.IO.File]::ReadAllText($jsonPath, (New-Object System.Text.UTF8Encoding $true))
        $obj = $raw | ConvertFrom-Json
    } catch {
        Write-Check "FAIL scene=$id reason=json_parse path=$jsonPath err=$_" "Red"
        $fail = $true
        continue
    }
    $ok = $false
    if ($null -ne $obj.ok) { $ok = [bool]$obj.ok }
    $hit = $false
    if ($null -ne $obj.overallHit) { $hit = [bool]$obj.overallHit }
    $volOk = $true
    if ($null -ne $obj.PSObject.Properties['volumeGatePass'] -and $null -ne $obj.volumeGatePass) {
        $volOk = [bool]$obj.volumeGatePass
    }
    if (-not $ok -or -not $hit -or -not $volOk) {
        Write-Check ("FAIL scene=$id reason=not_pass ok={0} overallHit={1} volumeGatePass={2} path={3}" -f $ok, $hit, $volOk, $jsonPath) "Red"
        $fail = $true
    } else {
        Write-Check ("PASS scene=$id path=$jsonPath") "Green"
    }
}

if ($fail) {
    Write-Check "DONE result=fail (does_not_replace_running_golden)" "Red"
    exit 1
}
Write-Check "DONE result=all_pass scenes=$($ids -join ',')" "Green"
exit 0
