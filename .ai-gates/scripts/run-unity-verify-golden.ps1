<#
.SYNOPSIS
  Unity 无头黄金验窗包装：batchmode VerifySceneRunner → 复用 verify-runtime-evidence.ps1 → 汇总 exit。

.DESCRIPTION
  - 需要环境变量 UNITY_EXE（或 -UnityExe）。未设置时清晰 exit 2，禁止伪绿。
  - -SceneId G1|G2|G3|G4|G5 或 -All（以 yaml 为准；未知 id 失败）。
  - 默认黄金路径：不向 Unity 传入 Keywords、不启用 stub 自注入；断言依赖真实 Play/夹具日志。
  - -AllowStubPass：仅接线烟测（会自注入 Keywords）；脚本在证据之后强制 exit≠0，不得用于 A1 签收。
  - 默认证据目录：优先执行中/golden-ml-gate-g3g4-play/证据；否则回退 golden-playmode-g2-r；中文段用码点/目录发现。
  - 取证对专用 unity-verify- logFile 传 -TailLines 0（全文件），避免早期 LiquidIngress 被裁假红。
  - JSON 可附加 sceneId / framesWaited 字段。
  - 硬提醒：黄金绿 ≠ 业务手测签收（业务 A# 仍须人工 Play / 索引行手测）。
  - **须关本机 Unity Editor**：batchmode 与 Editor 争用同一项目目录（独占）；跑本脚本前请关闭已打开的 Unity Editor，否则易卡死/假红。
  - A5：黄金签收以逐景 -SceneId G1/G2/G3/G4/G5 为准（真 PlayMode）；-All 总 exit 保持脚本现状，不得为绿改 Stub 自注入。

.EXAMPLE
  # 先关闭本机已打开的 Unity Editor，再设 UNITY_EXE 跑黄金
  $env:UNITY_EXE = "C:\...\Unity.exe"
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/run-unity-verify-golden.ps1 -SceneId G1

.EXAMPLE
  # 接线烟测（不得用于 A1 签收；总 exit≠0）
  powershell -ExecutionPolicy Bypass -File .cursor/scripts/run-unity-verify-golden.ps1 -SceneId G1 -AllowStubPass
#>

[CmdletBinding()]
param(
    [string]$SceneId,
    [switch]$All,
    [switch]$AllowStubPass,
    [string]$UnityExe = $env:UNITY_EXE,
    [string]$ProjectPath,
    [string]$GoldenYaml,
    [string]$OutputDir,
    [int]$SinceMinutes = 30,
    # TailLines: 0 or negative = scan entire log file (default 0)
    [int]$TailLines = 0
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    Write-Error "scriptDir is null; refuse to continue"
    exit 2
}
$repoRoot = (& git -C $scriptDir rev-parse --show-toplevel 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$repoRoot)) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")).Path
} else {
    $repoRoot = ([string]$repoRoot).Trim()
}
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    Write-Error "repoRoot is null; refuse to continue"
    exit 2
}

if (-not $ProjectPath) { $ProjectPath = $repoRoot }
if (-not $GoldenYaml) { $GoldenYaml = Join-Path $repoRoot ".ai-gates\verify\golden-scenes.yaml" }
if (-not $OutputDir) {
    # ASCII-safe discovery: Chinese path segments built from codepoints (PS5 GBK misreads UTF8-no-BOM literals)
    # 黄金绿 ≠ 业务手测签收
    $zhEvidence = [string]([char]0x8BC1) + [char]0x636E          # evidence
    $zhExecuting = [string]([char]0x6267) + [char]0x884C + [char]0x4E2D  # in-progress
    $docRoot = Join-Path $repoRoot "Assets\Doc"
    $mlCands = @(Get-ChildItem -LiteralPath $docRoot -Recurse -Directory -Filter "golden-ml-gate-g3g4-play" -ErrorAction SilentlyContinue)
    $win = $mlCands | Where-Object { $_.FullName -like ("*{0}*" -f $zhExecuting) } | Select-Object -First 1
    if (-not $win) { $win = $mlCands | Select-Object -First 1 }
    if (-not $win) {
        $cands = @(Get-ChildItem -LiteralPath $docRoot -Recurse -Directory -Filter "golden-playmode-g2-r" -ErrorAction SilentlyContinue)
        $win = $cands | Where-Object { $_.FullName -like ("*{0}*" -f $zhExecuting) } | Select-Object -First 1
        if (-not $win) { $win = $cands | Select-Object -First 1 }
    }
    if ($win) {
        $OutputDir = Join-Path $win.FullName $zhEvidence
    } else {
        $OutputDir = Join-Path $repoRoot ("Assets\Doc\_verify-out\golden-ml-gate-g3g4-play\" + $zhEvidence)
        Write-Host "[run-unity-verify-golden] WARN golden window missing; OutputDir=$OutputDir" -ForegroundColor Yellow
    }
    Write-Host "[run-unity-verify-golden] OutputDir=$OutputDir" -ForegroundColor Cyan
}

$evidenceScript = Join-Path $scriptDir "verify-runtime-evidence.ps1"
if (-not (Test-Path -LiteralPath $evidenceScript)) {
    Write-Error "missing evidence script: $evidenceScript"
    exit 2
}

function Write-FailAndExit {
    param([string]$Reason, [int]$Code = 2)
    Write-Host "[run-unity-verify-golden] FAIL reason=$Reason exit=$Code" -ForegroundColor Red
    exit $Code
}

if (-not $All -and [string]::IsNullOrWhiteSpace($SceneId)) {
    Write-FailAndExit -Reason "require -SceneId or -All" -Code 2
}
if ($All -and -not [string]::IsNullOrWhiteSpace($SceneId)) {
    Write-FailAndExit -Reason "use either -SceneId or -All, not both" -Code 2
}

if ([string]::IsNullOrWhiteSpace($UnityExe)) {
    Write-FailAndExit -Reason "UNITY_EXE not set (and -UnityExe not provided); refuse fake-green" -Code 2
}
if (-not (Test-Path -LiteralPath $UnityExe)) {
    Write-FailAndExit -Reason "UNITY_EXE path not found: $UnityExe" -Code 2
}
if (-not (Test-Path -LiteralPath $GoldenYaml)) {
    Write-FailAndExit -Reason "golden yaml missing: $GoldenYaml" -Code 2
}

if ($AllowStubPass) {
    Write-Host "[run-unity-verify-golden] WARN AllowStubPass=wiring_smoke_only NOT_FOR_A1_ACCEPTANCE (will force exit!=0)" -ForegroundColor Yellow
}

function Get-GoldenScenes {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $scenes = @()
    $cur = $null
    $listMode = $null
    foreach ($raw in $lines) {
        $line = $raw
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*-\s+id:\s*(\S+)\s*$') {
            if ($cur) { $scenes += $cur }
            $cur = [ordered]@{
                id            = $Matches[1]
                framesWait    = 30
                keywordMode   = "All"
                keywords      = New-Object System.Collections.Generic.List[string]
                expectAbsent  = New-Object System.Collections.Generic.List[string]
                scenePath     = ""
                minVolumeMl   = $null
                minSumVolumeMl = $null
            }
            $listMode = $null
            continue
        }
        if ($null -eq $cur) { continue }
        if ($line -match '^\s+framesWait:\s*(\d+)\s*$') {
            $cur.framesWait = [int]$Matches[1]
            $listMode = $null
            continue
        }
        if ($line -match '^\s+keywordMode:\s*(\S+)\s*$') {
            $cur.keywordMode = $Matches[1]
            $listMode = $null
            continue
        }
        if ($line -match '^\s+minVolumeMl:\s*([0-9]*\.?[0-9]+)\s*$') {
            $cur.minVolumeMl = [double]$Matches[1]
            $listMode = $null
            continue
        }
        if ($line -match '^\s+minSumVolumeMl:\s*([0-9]*\.?[0-9]+)\s*$') {
            $cur.minSumVolumeMl = [double]$Matches[1]
            $listMode = $null
            continue
        }
        if ($line -match '^\s+scenePath:\s*"(.*)"\s*$' -or $line -match '^\s+scenePath:\s*(.*)\s*$') {
            $cur.scenePath = $Matches[1].Trim().Trim('"')
            $listMode = $null
            continue
        }
        if ($line -match '^\s+keywords:\s*$') { $listMode = "keywords"; continue }
        if ($line -match '^\s+expectAbsent:\s*$') { $listMode = "expectAbsent"; continue }
        if ($line -match '^\s+expectAbsent:\s*\[\s*\]\s*$') {
            $listMode = $null
            continue
        }
        if ($line -match '^\s+-\s+(.+?)\s*$' -and $listMode) {
            $val = $Matches[1].Trim().Trim('"').Trim("'")
            if ($listMode -eq "keywords") { [void]$cur.keywords.Add($val) }
            elseif ($listMode -eq "expectAbsent") { [void]$cur.expectAbsent.Add($val) }
            continue
        }
        if ($line -match '^\s+\w+:') { $listMode = $null }
    }
    if ($cur) { $scenes += $cur }
    return $scenes
}

$allScenes = @(Get-GoldenScenes -Path $GoldenYaml)
if ($allScenes.Count -eq 0) {
    Write-FailAndExit -Reason "no scenes parsed from yaml" -Code 2
}

$targets = @()
if ($All) {
    $targets = $allScenes
} else {
    $hit = $allScenes | Where-Object { $_.id -eq $SceneId }
    if (-not $hit) {
        Write-FailAndExit -Reason "unknown SceneId=$SceneId (yaml has: $(($allScenes | ForEach-Object { $_.id }) -join ','))" -Code 2
    }
    $targets = @($hit)
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$overallFail = $false
$sawStubSmoke = $false
$results = @()

foreach ($scene in $targets) {
    $id = $scene.id
    $frames = [int]$scene.framesWait
    $mode = $scene.keywordMode
    if ($mode -ne "Any" -and $mode -ne "All") { $mode = "All" }
    $kw = ($scene.keywords -join ",")
    $absent = ($scene.expectAbsent -join ",")
    if ([string]::IsNullOrWhiteSpace($kw)) {
        Write-Host "[run-unity-verify-golden] scene=$id FAIL reason=empty_keywords" -ForegroundColor Red
        $overallFail = $true
        $results += [ordered]@{ sceneId = $id; unityExit = -1; evidenceExit = -1; reason = "empty_keywords" }
        continue
    }

    $logFile = Join-Path $OutputDir ("unity-verify-{0}-{1}.log" -f $id, $stamp)
    $jsonOut = Join-Path $OutputDir ("{0}-{1}-verify.json" -f $id, $stamp)

    Write-Host "[run-unity-verify-golden] scene=$id unity start frames=$frames allowStubPass=$AllowStubPass" -ForegroundColor Cyan

    # 默认黄金：不向 Unity 传 Keywords（避免 cmdline/日志自注入伪绿）
    $unityArgs = @(
        "-batchmode",
        "-nographics",
        "-projectPath", $ProjectPath,
        "-executeMethod", "LabSDK.Editor.Chemical.Verify.VerifySceneRunner.RunCli",
        "-verifySceneId", $id,
        "-verifyFrames", "$frames",
        "-logFile", $logFile
    )
    if (-not [string]::IsNullOrWhiteSpace($scene.scenePath)) {
        $unityArgs += @("-verifyScenePath", $scene.scenePath)
    }
    if ($AllowStubPass) {
        $sawStubSmoke = $true
        $unityArgs += @("-AllowStubPass", "-verifyKeywords", $kw)
    }

    $unityExit = 1
    try {
        $p = Start-Process -FilePath $UnityExe -ArgumentList $unityArgs -Wait -PassThru -NoNewWindow
        $unityExit = $p.ExitCode
    } catch {
        Write-Host "[run-unity-verify-golden] scene=$id Unity launch error: $_" -ForegroundColor Red
        $unityExit = 9
    }

    if ($unityExit -ne 0) {
        Write-Host "[run-unity-verify-golden] scene=$id Unity exit=$unityExit (skip evidence / fail)" -ForegroundColor Red
        $overallFail = $true
        $results += [ordered]@{ sceneId = $id; unityExit = $unityExit; evidenceExit = -1; reason = "unity_nonzero" }
        continue
    }

    $evArgs = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", $evidenceScript,
        "-Keywords", $kw,
        "-Mode", $mode,
        "-SinceMinutes", "$SinceMinutes",
        "-EditorLogPath", $logFile,
        "-OutputPath", $jsonOut,
        "-TailLines", "$TailLines"
    )
    if (-not [string]::IsNullOrWhiteSpace($absent)) {
        $evArgs += @("-ExpectAbsentKeywords", $absent)
    }
    if ($null -ne $scene.minVolumeMl) {
        $evArgs += @("-MinVolumeMl", ([string]$scene.minVolumeMl))
    }
    if ($null -ne $scene.minSumVolumeMl) {
        $evArgs += @("-MinSumVolumeMl", ([string]$scene.minSumVolumeMl))
    }

    $ev = Start-Process -FilePath "powershell" -ArgumentList $evArgs -Wait -PassThru -NoNewWindow
    $evExit = $ev.ExitCode

    if ((Test-Path -LiteralPath $jsonOut)) {
        try {
            $raw = [System.IO.File]::ReadAllText($jsonOut, (New-Object System.Text.UTF8Encoding $true))
            $obj = $raw | ConvertFrom-Json
            $obj | Add-Member -NotePropertyName sceneId -NotePropertyValue $id -Force
            $obj | Add-Member -NotePropertyName framesWaited -NotePropertyValue $frames -Force
            $obj | Add-Member -NotePropertyName allowStubPass -NotePropertyValue ([bool]$AllowStubPass) -Force
            $enriched = $obj | ConvertTo-Json -Depth 8
            [System.IO.File]::WriteAllText($jsonOut, $enriched, (New-Object System.Text.UTF8Encoding $true))
        } catch {
            Write-Host "[run-unity-verify-golden] scene=$id warn=enrich_json_failed $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[run-unity-verify-golden] scene=$id FAIL reason=no_verify_json" -ForegroundColor Red
        $overallFail = $true
        $results += [ordered]@{ sceneId = $id; unityExit = $unityExit; evidenceExit = $evExit; reason = "no_verify_json" }
        continue
    }

    if ($evExit -ne 0) {
        Write-Host "[run-unity-verify-golden] scene=$id evidence exit=$evExit" -ForegroundColor Red
        $overallFail = $true
        $results += [ordered]@{ sceneId = $id; unityExit = $unityExit; evidenceExit = $evExit; reason = "evidence_fail"; json = $jsonOut }
    } else {
        Write-Host "[run-unity-verify-golden] scene=$id evidence_ok json=$jsonOut" -ForegroundColor Green
        $results += [ordered]@{ sceneId = $id; unityExit = $unityExit; evidenceExit = $evExit; reason = "evidence_ok"; json = $jsonOut }
    }
}

Write-Host "[run-unity-verify-golden] summary:" -ForegroundColor Cyan
$results | ForEach-Object { Write-Host ("  " + ($_ | ConvertTo-Json -Compress)) }

# 烟测路径：即使 evidence 全绿也强制非 0，禁止冒充 A1 签收
if ($AllowStubPass -or $sawStubSmoke) {
    Write-FailAndExit -Reason "stub_smoke_only_not_a1_acceptance" -Code 3
}

if ($overallFail) {
    Write-FailAndExit -Reason "one_or_more_scenes_failed" -Code 1
}

Write-Host "[run-unity-verify-golden] ALL OK" -ForegroundColor Green
exit 0
