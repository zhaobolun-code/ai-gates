# inject-turn-tokens.ps1
# Cursor beforeSubmitPrompt：用户下一条消息发出、模型还没写字时，
# 按本会话 id 注入上一轮实测 token 行。不读 latest，不读其他会话。
# failClosed 须为 false；任何异常 fail-open 输出 {} 退出 0。

param(
    [string]$TokenFile = ""
)

[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'cursor-hooks-common.ps1')
. (Join-Path $PSScriptRoot 'gate-decision.ps1')

function Emit-Empty {
    Write-Output "{}"
    exit 0
}

function Get-StdinConversationId {
    param($Json)
    if ($null -eq $Json) { return "" }
    foreach ($name in @('conversation_id', 'conversationId')) {
        $prop = $Json.PSObject.Properties[$name]
        if (-not $prop) { continue }
        $s = [string]$prop.Value
        if (-not [string]::IsNullOrWhiteSpace($s)) { return $s }
    }
    return ""
}

function Get-ConversationTokenLine {
    param($Map, [string]$ConversationId)
    if ($null -eq $Map) { return "" }
    if ([string]::IsNullOrWhiteSpace($ConversationId)) { return "" }
    $prop = $Map.PSObject.Properties[$ConversationId]
    if (-not $prop) { return "" }
    $entry = $prop.Value
    if ($null -eq $entry) { return "" }
    $lineProp = $entry.PSObject.Properties['line']
    if (-not $lineProp) { return "" }
    return [string]$lineProp.Value
}

try {
    $raw = Read-HookStdin
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    $conversationId = Get-StdinConversationId -Json $json
    if ([string]::IsNullOrWhiteSpace($conversationId)) { Emit-Empty }

    if ([string]::IsNullOrWhiteSpace($TokenFile)) {
        $repoRoot = Get-AiGatesProjectRoot
        $TokenFile = Join-Path $repoRoot ".ai-gates\hooks-log\pm-turn-tokens.json"
    }
    if (-not (Test-Path -LiteralPath $TokenFile)) { Emit-Empty }

    $map = $null
    try {
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        $map = [System.IO.File]::ReadAllText($TokenFile, $utf8Bom) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Emit-Empty
    }
    $line = Get-ConversationTokenLine -Map $map -ConversationId $conversationId
    if ([string]::IsNullOrWhiteSpace($line)) { Emit-Empty }

    $hint = Get-TurnTokenHint -TokenLine $line
    if ([string]::IsNullOrWhiteSpace($hint)) { Emit-Empty }

    $result = [ordered]@{
        additional_context = $hint
        additionalContext  = $hint
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
} catch {
    Emit-Empty
}
