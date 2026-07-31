<#
.SYNOPSIS
  方案夹状态外置（支柱 B · 最小实现）：把 `未完成.md` 文档状态段落里那些靠 Agent 自己
  解析/自己改的字段（文档状态、止损计数、auto_steps_done、repair_rounds…）搬进一个
  脚本管理的 sidecar `.state.json`，非法迁移由脚本拒绝，而不是靠 Agent 记住 CORE 里
  "禁止 XX" 这句话。

.DESCRIPTION
  权威：.cursor/skills/references/loop-engineering.md §3（状态迁移表）+ 各岗 SKILL 里
  draft → review-pending → implementation-ready → in-progress → step-completed →
  runtime-validated → completed 这条主链 + blocked 分支。

  本脚本不替代 `未完成.md`——`未完成.md` 仍是给人/Agent 读的叙述性文档；`.state.json`
  是给脚本/Hook 读的机器事实来源。两者不同步时，以 `.state.json` 为准（因为它只能通过
  本脚本按合法迁移表修改，`未完成.md` 里的状态段落理论上可以被随手改错）。

  非法迁移（比如 step-completed 时想直接 -Transition in-progress，等价于"未测进下一
  Step"）会被拒绝，退出码非 0，不静默放行；需要人工越权时用 -Force + -ForceReason
  显式记录，而不是让 Agent 假装这是合法路径。

.PARAMETER DocFolder
  方案夹路径（含 `未完成.md` 的那个目录）。状态文件落在 `{DocFolder}/.state.json`，
  迁移历史落在 `{DocFolder}/.state-history.jsonl`。

.PARAMETER Init
  初始化一个新方案夹的状态文件（doc_status=draft）；已存在则报错退出，不覆盖。

.PARAMETER Transition
  目标 doc_status。合法迁移表见脚本内 $LegalTransitions；非法迁移退出码 3。

.PARAMETER SetLane
  Express|Standard|Full。

.PARAMETER SetCurrentStep
  记录当前 Step 名称/编号（自由文本）。

.PARAMETER IncrementAutoSteps
  auto_steps_done += 1；超出 MaxAutoSteps 时自动把 reason 置为 max_auto_steps。

.PARAMETER IncrementRepairRounds
  repair_rounds += 1；达到 MaxRepairRounds 时 stopReason 自动置为 fuse。

.PARAMETER ResetAutoSteps
  「本窗 Auto」口令对应动作：auto_steps_done 归零；**不会**重置已触顶的 repair_rounds
  （loop-engineering.md §7：「本窗 Auto」不得重置触顶 repair_rounds）。

.PARAMETER SetStopReason
  completed|blocked|fuse|await_human|none。

.PARAMETER SetReason
  await_human 下的子原因（自由文本，例如 unity_test / max_auto_steps / discover）。

.PARAMETER SetStopLoss
  格式 "标签=当前/上限"，例如 "降温回流=0/3"。用于替代文档里手写的止损计数字符串。

.PARAMETER Force
  越过合法迁移表强制写入（须同时给 -ForceReason）；历史记录会标记 forced=true。

.PARAMETER ForceReason
  配合 -Force 的越权理由，写入历史记录，不允许留空。

.PARAMETER Note
  本次变更的一句话备注，写入 .state-history.jsonl。

.EXAMPLE
  powershell -File .cursor/scripts/update-doc-state.ps1 -DocFolder "Assets/.../封闭侧加热液升降温不回落" -Init

.EXAMPLE
  powershell -File .cursor/scripts/update-doc-state.ps1 -DocFolder "..." -Transition step-completed -Note "Step2 实现+CR无blocker"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DocFolder,

    [switch]$Init,

    [ValidateSet("draft", "review-pending", "implementation-ready", "in-progress", "step-completed", "runtime-validated", "completed", "blocked")]
    [string]$Transition,

    [ValidateSet("Express", "Standard", "Full")]
    [string]$SetLane,

    [string]$SetCurrentStep,

    [switch]$IncrementAutoSteps,

    [switch]$IncrementRepairRounds,

    [switch]$ResetAutoSteps,

    [ValidateSet("completed", "blocked", "fuse", "await_human", "none")]
    [string]$SetStopReason,

    [string]$SetReason,

    [string]$SetStopLoss,

    [switch]$Force,

    [string]$ForceReason,

    [string]$Note
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$StatePath = Join-Path $DocFolder ".state.json"
$HistoryPath = Join-Path $DocFolder ".state-history.jsonl"

# doc_status 合法迁移表（loop-engineering.md §3 + 各岗 SKILL 主链）
$LegalTransitions = @{
    "draft"                = @("review-pending")
    "review-pending"        = @("implementation-ready", "draft", "blocked")
    "implementation-ready"  = @("in-progress")
    "in-progress"           = @("step-completed", "blocked")
    "step-completed"        = @("runtime-validated", "blocked")
    "runtime-validated"     = @("in-progress", "completed")
    "blocked"               = @("review-pending", "in-progress")
    "completed"             = @()
}

function Write-Utf8Bom {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

function Append-Utf8 {
    param([string]$Path, [string]$Line)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, $utf8NoBom)
}

function Write-ErrAndExit {
    param([string]$Message, [int]$ExitCode)
    # $ErrorActionPreference = "Stop" 会把 Write-Error 变成终止性错误，导致它后面的
    # `exit $ExitCode` 永远执行不到、进程改用 PowerShell.exe 自己的错误退出码（通常是 1）。
    # 这里改用 stderr 直写，保证调用方（比如 test-hooks.ps1/hook）拿到的是脚本自己定义的退出码，
    # 而不是被 PowerShell 运行时截胡的 1。
    [Console]::Error.WriteLine($Message)
    exit $ExitCode
}

function New-DefaultState {
    [ordered]@{
        schema           = "doc-state/v1"
        docFolder        = $DocFolder
        docStatus        = "draft"
        lane             = $null
        currentStep      = $null
        stopReason       = $null
        reason           = $null
        autoStepsDone    = 0
        repairRounds     = 0
        maxAutoSteps     = 3
        maxRepairRounds  = 2
        stopLossCounters = [ordered]@{}
        createdUtc       = [DateTime]::UtcNow.ToString("o")
        lastUpdatedUtc   = [DateTime]::UtcNow.ToString("o")
        lastTransition   = $null
    }
}

function Load-State {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        throw "找不到状态文件：$StatePath 。新方案夹先用 -Init 初始化。"
    }
    $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Save-State {
    param($state)
    $state.lastUpdatedUtc = [DateTime]::UtcNow.ToString("o")
    $json = $state | ConvertTo-Json -Depth 8
    Write-Utf8Bom -Path $StatePath -Content $json
}

function Add-History {
    param($fromStatus, $toStatus, $forced, $forceReason, $note)
    $entry = [ordered]@{
        atUtc       = [DateTime]::UtcNow.ToString("o")
        from        = $fromStatus
        to          = $toStatus
        forced      = [bool]$forced
        forceReason = if ([string]::IsNullOrEmpty($forceReason)) { $null } else { $forceReason }
        note        = if ([string]::IsNullOrEmpty($note)) { $null } else { $note }
    }
    Append-Utf8 -Path $HistoryPath -Line ($entry | ConvertTo-Json -Compress -Depth 6)
}

function Emit {
    param($state, [int]$exitCode)
    Write-Output ($state | ConvertTo-Json -Depth 8)
    exit $exitCode
}

# --- Init ---
if ($Init) {
    if (Test-Path -LiteralPath $StatePath) {
        Write-ErrAndExit -Message "已存在状态文件，拒绝覆盖：$StatePath" -ExitCode 1
    }
    $state = New-DefaultState
    Save-State -state $state
    Add-History -fromStatus $null -toStatus $state.docStatus -forced $false -forceReason $null -note "init"
    Emit -state $state -exitCode 0
}

$state = Load-State

# --- 简单字段更新（不涉及状态机合法性） ---
if ($SetLane) { $state.lane = $SetLane }
if ($SetCurrentStep) { $state.currentStep = $SetCurrentStep }

if ($SetStopLoss) {
    if ($SetStopLoss -notmatch '^(?<label>[^=]+)=(?<cur>\d+)/(?<max>\d+)$') {
        Write-ErrAndExit -Message "SetStopLoss 格式须为 '标签=当前/上限'，例如 '降温回流=0/3'；实际收到：$SetStopLoss" -ExitCode 1
    }
    $label = $Matches.label.Trim()
    $counter = [ordered]@{ count = [int]$Matches.cur; max = [int]$Matches.max }
    $state.stopLossCounters | Add-Member -NotePropertyName $label -NotePropertyValue $counter -Force
}

# --- Auto 预算字段（loop-engineering.md §4/§7） ---
if ($ResetAutoSteps) {
    $state.autoStepsDone = 0
    if ($state.reason -eq "max_auto_steps") { $state.reason = $null }
}

if ($IncrementAutoSteps) {
    $state.autoStepsDone = [int]$state.autoStepsDone + 1
    $state.stopReason = "await_human"
    if ($state.autoStepsDone -ge [int]$state.maxAutoSteps) {
        $state.reason = "max_auto_steps"
    } else {
        $state.reason = "unity_test"
    }
}

if ($IncrementRepairRounds) {
    $state.repairRounds = [int]$state.repairRounds + 1
    if ($state.repairRounds -ge [int]$state.maxRepairRounds) {
        $state.stopReason = "fuse"
        $state.reason = "max_repair_rounds"
    }
}

if ($PSBoundParameters.ContainsKey("SetStopReason")) {
    $state.stopReason = if ($SetStopReason -eq "none") { $null } else { $SetStopReason }
}

if ($PSBoundParameters.ContainsKey("SetReason")) {
    $state.reason = $SetReason
}

# --- doc_status 迁移（核心：非法迁移拒绝） ---
if ($Transition) {
    $from = $state.docStatus

    if ($from -eq $Transition) {
        Write-ErrAndExit -Message "无操作：当前已是 $from，未发生迁移。" -ExitCode 1
    }

    $allowed = $LegalTransitions[$from]
    $isLegal = $allowed -contains $Transition

    if (-not $isLegal -and -not $Force) {
        $allowedText = if ($allowed.Count -gt 0) { $allowed -join ", " } else { "（无，$from 是终态）" }
        $msg = (
            "非法迁移：$from -> $Transition。" +
            "$from 合法后继：$allowedText。" +
            "若确认需要人工越权，重跑并加 -Force -ForceReason `"<理由>`"（会写入 .state-history.jsonl，不建议常规使用）。"
        )
        Write-ErrAndExit -Message $msg -ExitCode 3
    }

    if (-not $isLegal -and $Force -and [string]::IsNullOrWhiteSpace($ForceReason)) {
        Write-ErrAndExit -Message "-Force 越权迁移必须同时给出 -ForceReason（不允许无理由强改状态机）。" -ExitCode 1
    }

    # runtime-validated -> completed 前置：不做"剩余 Step=0"校验（脚本不知道方案有几个 Step，
    # 这条仍由 PM/planner 人工确认；本脚本只保证状态机拓扑合法，不重复整套业务语义）。

    $state.docStatus = $Transition
    Add-History -fromStatus $from -toStatus $Transition -forced (-not $isLegal) -forceReason $ForceReason -note $Note
} elseif ($Note -or $SetLane -or $SetCurrentStep -or $SetStopLoss -or $IncrementAutoSteps -or $IncrementRepairRounds -or $ResetAutoSteps -or $PSBoundParameters.ContainsKey("SetStopReason") -or $PSBoundParameters.ContainsKey("SetReason")) {
    Add-History -fromStatus $state.docStatus -toStatus $state.docStatus -forced $false -forceReason $null -note $Note
}

Save-State -state $state
Emit -state $state -exitCode 0
