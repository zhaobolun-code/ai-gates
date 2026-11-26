# collect-instability-prompt.ps1
# Cursor beforeSubmitPrompt。只追加独立整行治理信号。不注入 token，不挡这次提交。

param(
    [string]$LedgerDir = ''
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$ErrorActionPreference = 'Stop'

function Write-InstabilityAllow {
    Write-Output '{"continue":true,"permission":"allow"}'
}

try {
    . (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
    . (Join-Path $PSScriptRoot 'instability-ledger.ps1')
    $raw = ''
    try { $raw = Read-HookStdin } catch { $raw = '' }
    $fields = Get-InstabilityPromptFields -RawJson $raw
    $root = Get-AiGatesProjectRoot
    $live = Join-Path $root '.ai-gates\hooks-log'
    $target = $live
    if (-not [string]::IsNullOrWhiteSpace($LedgerDir)) {
        if (Test-InstabilityTempLedger -LedgerDir $LedgerDir) { $target = $LedgerDir }
        else { $target = '' }
    }
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-InstabilityAllow
        exit 0
    }
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    $lines = Get-InstabilitySignalLines -Prompt $fields.Prompt
    if ($null -eq $lines -or $lines.Count -eq 0) {
        Write-InstabilityAllow
        exit 0
    }
    $enc = New-Object System.Text.UTF8Encoding $false
    $port = Join-Path $target 'instability-port.log'
    if ((-not $fields.Readable) -or [string]::IsNullOrWhiteSpace($fields.ConversationId) -or [string]::IsNullOrWhiteSpace($fields.SourceId)) {
        $keys = (@($fields.KeyNames) -join ',')
        [System.IO.File]::AppendAllText($port, (([DateTime]::UtcNow.ToString('o')) + " missing-id keys=$keys`r`n"), $enc)
        Write-InstabilityAllow
        exit 0
    }
    $result = Add-InstabilityPromptEvents -LedgerDir $target -ConversationId $fields.ConversationId -SourceId $fields.SourceId -Prompt $fields.Prompt -Writer 'hook'
    if ($result.Refused) {
        [System.IO.File]::AppendAllText($port, (([DateTime]::UtcNow.ToString('o')) + " writer-refused`r`n"), $enc)
        Write-InstabilityAllow
        exit 0
    }
    if ($result.EchoIssueIds -and @($result.EchoIssueIds).Count -gt 0) {
        $echoPath = Join-Path $target 'instability-echo.log'
        foreach ($id in @($result.EchoIssueIds)) {
            [System.IO.File]::AppendAllText($echoPath, (([DateTime]::UtcNow.ToString('o')) + " issue_id=$id`r`n"), $enc)
        }
    }
    [System.IO.File]::AppendAllText($port, (([DateTime]::UtcNow.ToString('o')) + " recorded=$(@($result.Appended).Count)`r`n"), $enc)
    Write-InstabilityAllow
    exit 0
} catch {
    Write-InstabilityAllow
    exit 0
}
