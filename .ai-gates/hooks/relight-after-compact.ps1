# relight-after-compact.ps1
# Cursor preCompact：对话被收成摘要之前，注入三行指针。
# sessionStart 载荷没有「这次是压缩」标记，不在那里塞全文技能。
# 不触发八段交接。失败一律空 JSON 放行。

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')

function Write-RelightAudit {
    param([string]$Line)
    try {
        $repoRoot = Get-AiGatesProjectRoot
        $logDir = Join-Path $repoRoot ".ai-gates\hooks-log"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $auditFile = Join-Path $logDir "relight-after-compact.log"
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $auditFile -Value "$ts | $Line" -Encoding UTF8
    } catch {
    }
}

function Emit-Empty {
    Write-Output "{}"
    exit 0
}

try {
    $raw = Read-HookStdin
    $keys = ""
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            $keys = (@($obj.PSObject.Properties.Name) -join ",")
        } catch {
            $keys = "unparsed"
        }
    }
    Write-RelightAudit ("preCompact keys={0}" -f $keys)

    $ctx = @"
摘要不是约定。
下一步先读 .cursor/skills/references/agent-entry-route.md、.cursor/project-context.md 的模型路由、以及当前任务文件夹里的未完成说明。
读完之前不要改代码。
"@
    $result = [ordered]@{
        additional_context = $ctx
        additionalContext  = $ctx
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
} catch {
    Write-RelightAudit ("ERROR fail_open msg=$($_.Exception.Message)")
    Emit-Empty
}
