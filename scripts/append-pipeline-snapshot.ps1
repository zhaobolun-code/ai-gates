# append-pipeline-snapshot.ps1 — 追加 PM/恢复 机器可读快照（JSONL）
# Usage:
#   .\append-pipeline-snapshot.ps1 -Lane Express -ReviewTier skip -NextRole developer -UserState 进行中 -LaneRulesHit "4/4" -DiffHint Express -ProjectContext loaded
#   .\append-pipeline-snapshot.ps1 -Event recovery -DeviationType "缺 PM 结构化输出" -Lane Express -Note "用户触发重来"
param(
    [ValidateSet('pm', 'recovery', 'milestone')]
    [string]$Event = 'pm',
    [string]$Lane = '',
    [string]$ReviewTier = '',
    [string]$NextRole = '',
    [string]$UserState = '',
    [string]$LaneRulesHit = '',
    [string]$DiffHint = '',
    [string]$ProjectContext = '',
    [string]$DeviationType = '',
    [string]$Note = ''
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
}

$logPath = Join-Path $repoRoot ".cursor/pipeline-snapshot.log"
New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null

if (-not (Test-Path -LiteralPath $logPath)) {
    @(
        "# pipeline-snapshot.log — JSONL, one JSON object per line"
        "# Template: .cursor/skills/templates/pipeline-snapshot-log.md"
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8
}

$row = [ordered]@{
    ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    event = $Event
}
if ($Lane) { $row.lane = $Lane }
if ($ReviewTier) { $row.review_tier = $ReviewTier }
if ($NextRole) { $row.next_role = $NextRole }
if ($UserState) { $row.user_state = $UserState }
if ($LaneRulesHit) { $row.lane_rules_hit = $LaneRulesHit }
if ($DiffHint) { $row.diff_hint = $DiffHint }
if ($ProjectContext) { $row.project_context = $ProjectContext }
if ($DeviationType) { $row.deviation_type = $DeviationType }
if ($Note) { $row.note = $Note }

$line = ($row | ConvertTo-Json -Compress)
Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
Write-Host "appended to $logPath" -ForegroundColor Green
Write-Host $line -ForegroundColor DarkGray
