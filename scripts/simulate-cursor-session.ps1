# simulate-cursor-session.ps1 — 协议级 hook 仿真台（发布闸「真演证据」自动化）
#
# 定位：test-hooks.ps1 是注入式（拼小 JSON 喂 stdin），覆盖不到真实 Cursor 2.2 协议形态；
# 本脚本完整模拟一次真实会话的 hook 调用序列（sessionStart → preToolUse →
# postToolUse → afterAgentResponse），payload 用真实级：
#   - 大 payload：tool_input.content 塞 ≥80KB（复现 2026-08-03 真演 81KB `Console.In.ReadToEnd`+
#     `ConvertFrom-Json` 解析失败断打点、门禁误拦的场景）；
#   - 内容含中文 / 双引号 / 反斜杠 / 制表符 / 换行 / unicode 转义（真实大文件全文形态）；
#   - stdin 以 UTF-8 无 BOM 字节流写入子进程（与 Cursor 实际下发一致）。
#
# 断言（一次完整会话真演）：
#   P1  payload 字节数 ≥ 80000（确保复现大 payload 路径）
#   P2  sessionStart 漂移检测 exit 0 且无 drift
#   P3  preToolUse 写 CHANGELOG.md（Level 0 豁免）→ allow
#   P4  大 payload 下 postToolUse mark-changelog-write 打点落盘（主路径或 fallback 皆可，链路不断）
#   P5  大 payload 下 afterAgentResponse mark-pm-gate 仍检出 [PM] 并落盘
#   P6  同会话随后写 .cursor/skills 设施（有 CHANGELOG 流水）→ allow
#   P7  无流水会话写 .cursor/skills 设施 → deny（Level 1 轻门禁）
#   P8  业务路径无 [PM] 标记 → deny
#   P9  大 payload 打点未产生「打点丢失」：changelog-writes.json 含本会话新鲜记录
#
# 隔离：本脚本会话号一律 `__sim__` 前缀；跑完在 finally 精确清理打点文件中的
# `__sim__*` 条目（保留真实会话数据）。
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/simulate-cursor-session.ps1
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/simulate-cursor-session.ps1 -VerboseOutput
#   powershell -ExecutionPolicy Bypass -File .cursor/scripts/simulate-cursor-session.ps1 -PayloadBytes 120000
#
# 退出码：0 = 全部通过（≈ 一次真实会话 hook 链路真演通过）；1 = 有断言失败。

param(
    [switch]$VerboseOutput,
    [int]$PayloadBytes = 80000
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path }
$hooksDir = Join-Path $repoRoot ".cursor\hooks"
$logDir = Join-Path $repoRoot ".cursor\hooks-log"
$gateFile = Join-Path $logDir "pm-gate.json"
$changelogWritesFile = Join-Path $logDir "changelog-writes.json"

$script:total = 0
$script:failed = 0
$script:results = @()

function Assert-Sim {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    $script:total++
    if ($Condition) {
        $script:results += "PASS | $Name"
        if ($VerboseOutput) { Write-Host "PASS: $Name" -ForegroundColor Green }
    } else {
        $script:failed++
        $script:results += "FAIL | $Name | $Detail"
        Write-Host "FAIL: $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "      $Detail" -ForegroundColor DarkYellow }
    }
}

function Invoke-HookScript {
    param([string]$ScriptName, [string]$StdinJson)
    $path = Join-Path $hooksDir $ScriptName
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $scriptDir $ScriptName }
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $path)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join " "
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -ne $StdinJson) {
        # 以 UTF-8 无 BOM 字节流写 stdin（与 Cursor 实际下发一致）
        $bytes = $utf8NoBom.GetBytes($StdinJson)
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    }
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [ordered]@{
        ExitCode = $proc.ExitCode
        Stdout   = $stdout
        Stderr   = $stderr
    }
}

# 生成 ≥ PayloadBytes 的真实级文件内容（中文 + 引号/反斜杠/制表符/换行 + unicode 转义文本）
function New-BigFileContent {
    param([int]$MinBytes)
    $base = @'
# 化学实验记录（中文大文件全文）
压力系统 handover：导管 A → 导管 B 液封路径。特殊字符："双引号" \反斜杠\ 制表符	换行下一行。
嵌套 JSON 引用：{"pressure": 101.3, "status": "ready"}，unicode 转义示例 \u534e \u6587 \u00e9。
<note key="value">物理大前提：贴近真实物理现象，禁止为过单测引入非物理行为。</note>
'@
    $sb = New-Object System.Text.StringBuilder
    $sb.Append($base) | Out-Null
    $i = 0
    while ([System.Text.Encoding]::UTF8.GetByteCount($sb.ToString()) -lt $MinBytes) {
        $null = $sb.AppendLine("[段落 $i] 重复混合中英文：chemical experiment, 压强 P=$i Pa, 导管状态 = ready, " + 'quote" backslash\ tab	 unicode:\u4e2d\u6587')
        $i++
    }
    return $sb.ToString()
}

# 按 Cursor 2.2 hook schema 构造事件 payload（深度完整 JSON，真实形态）
function New-HookPayload {
    param([string]$Event, [string]$ConversationId, [string]$SessionId, [string]$FilePath, [string]$Content, [string]$Text)
    switch ($Event) {
        "sessionStart" {
            return @{ session_id = $SessionId; source = "agent" } | ConvertTo-Json -Depth 8 -Compress
        }
        "preToolUse" {
            return @{
                tool_name = "Write"
                tool_input = @{ file_path = $FilePath; content = $Content }
                conversation_id = $ConversationId
                session_id = $SessionId
            } | ConvertTo-Json -Depth 8 -Compress
        }
        "postToolUse" {
            return @{
                tool_name = "Write"
                tool_input = @{ file_path = $FilePath; content = $Content }
                conversation_id = $ConversationId
                session_id = $SessionId
            } | ConvertTo-Json -Depth 8 -Compress
        }
        "afterAgentResponse" {
            return @{
                text = $Text
                conversation_id = $ConversationId
                session_id = $SessionId
            } | ConvertTo-Json -Depth 8 -Compress
        }
        default { throw "未知事件: $Event" }
    }
}

# 清理打点文件中的 __sim__* 条目（保留真实会话数据）
function Remove-SimEntries {
    param([string]$JsonFile)
    if (-not (Test-Path -LiteralPath $JsonFile)) { return }
    try {
        $data = [System.IO.File]::ReadAllText($JsonFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $rebuilt = [ordered]@{}
        foreach ($p in $data.PSObject.Properties) {
            if ($p.Name -notlike "__sim__*" -and $p.Name -notlike "__test__*") { $rebuilt[$p.Name] = $p.Value }
        }
        if ($rebuilt.Count -eq 0) {
            Remove-Item -LiteralPath $JsonFile -Force -ErrorAction SilentlyContinue
        } else {
            [System.IO.File]::WriteAllText($JsonFile, ($rebuilt | ConvertTo-Json -Depth 6), $utf8Bom)
        }
    } catch {
        # 文件损坏就不动（fail-open）
    }
}

try {
    Write-Host "=== simulate-cursor-session (协议级 hook 仿真台) ===" -ForegroundColor Cyan
    Write-Host "repo: $repoRoot  payload target: $PayloadBytes bytes`n"

    # 移出残留 kill switch，避免污染 P7/P8 deny 断言
    $killSwitch = Join-Path $logDir "pm-gate-disabled"
    $killSwitchExisted = Test-Path -LiteralPath $killSwitch
    if ($killSwitchExisted) { Remove-Item -LiteralPath $killSwitch -Force -ErrorAction SilentlyContinue }

    $simConv = "__sim__conv-" + [Guid]::NewGuid().ToString("N")
    $simConvNoFlow = "__sim__conv-noflow-" + [Guid]::NewGuid().ToString("N")
    $simSession = "__sim__session-" + [Guid]::NewGuid().ToString("N")

    $bigContent = New-BigFileContent -MinBytes $PayloadBytes
    $bigBytes = $utf8NoBom.GetBytes($bigContent)
    $changelogPath = ".cursor\skills\CHANGELOG.md"
    $skillsPath = ".cursor\skills\foo.md"
    $businessPath = "Assets\Foo.cs"

    # P1：payload 确实够大（复现大 payload 路径的前提）
    Assert-Sim "P1 big payload >= $PayloadBytes bytes" ($bigBytes.Length -ge $PayloadBytes) "actual=$($bigBytes.Length)"

    # P2：sessionStart → 漂移检测
    $r = Invoke-HookScript -ScriptName "check-hooks-drift.ps1" -StdinJson (New-HookPayload -Event "sessionStart" -SessionId $simSession -ConversationId $simConv)
    Assert-Sim "P2 sessionStart drift check exit 0" ($r.ExitCode -eq 0) "exit=$($r.ExitCode) stderr=$($r.Stderr)"

    # P3：preToolUse 写 CHANGELOG.md（Level 0 豁免）→ allow
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (New-HookPayload -Event "preToolUse" -SessionId $simSession -ConversationId $simConv -FilePath $changelogPath -Content $bigContent)
    $perm3 = $null
    try { $perm3 = ($r.Stdout | ConvertFrom-Json).permission } catch { }
    Assert-Sim "P3 preToolUse CHANGELOG.md Level0 exempt -> allow" ($r.ExitCode -eq 0 -and $perm3 -eq "allow") "exit=$($r.ExitCode) perm=$perm3 stdout=$($r.Stdout)"

    # P4：大 payload postToolUse → mark-changelog-write 打点（链路不断）
    $r = Invoke-HookScript -ScriptName "mark-changelog-write.ps1" -StdinJson (New-HookPayload -Event "postToolUse" -SessionId $simSession -ConversationId $simConv -FilePath $changelogPath -Content $bigContent)
    $cwNow = $null
    if (Test-Path -LiteralPath $changelogWritesFile) {
        try { $cwNow = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $cwNow = $null }
    }
    Assert-Sim "P4 big payload postToolUse -> changelog mark written" ($r.ExitCode -eq 0 -and $null -ne $cwNow -and $null -ne $cwNow.$simConv.lastChangelogWriteAtUtc) "exit=$($r.ExitCode) keys=$($cwNow.PSObject.Properties.Name -join ',')"
    $markLog = Join-Path $logDir "mark-changelog-write.log"
    $markLogTail = ""
    if (Test-Path -LiteralPath $markLog) {
        $markLogTail = (Get-Content -LiteralPath $markLog -Encoding UTF8 | Select-Object -Last 10) -join "`n"
    }
    Assert-Sim "P4 audit shows wrote for sim conversation" ($markLogTail -match [Regex]::Escape($simConv) -and $markLogTail -match "wrote=changelog-writes.json") "tail=$markLogTail"

    # P5：大 payload afterAgentResponse → mark-pm-gate 检出 [PM] 并落盘
    $pmText = "[PM] 仿真会话判定：lane Standard / tier L1.5 / role developer。你下一步：执行。"
    $r = Invoke-HookScript -ScriptName "mark-pm-gate.ps1" -StdinJson (New-HookPayload -Event "afterAgentResponse" -SessionId $simSession -ConversationId $simConv -Text $pmText)
    $gateNow = $null
    if (Test-Path -LiteralPath $gateFile) {
        try { $gateNow = [System.IO.File]::ReadAllText($gateFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $gateNow = $null }
    }
    Assert-Sim "P5 big payload afterAgentResponse -> [PM] mark written" ($r.ExitCode -eq 0 -and $null -ne $gateNow -and $null -ne $gateNow.$simConv.lastPmAtUtc) "exit=$($r.ExitCode) keys=$($gateNow.PSObject.Properties.Name -join ',')"

    # P6：同会话（有 CHANGELOG 流水）写 .cursor/skills 设施 → allow（Level 1）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (New-HookPayload -Event "preToolUse" -SessionId $simSession -ConversationId $simConv -FilePath $skillsPath -Content "small")
    $perm6 = $null
    try { $perm6 = ($r.Stdout | ConvertFrom-Json).permission } catch { }
    Assert-Sim "P6 same conv with changelog flow -> Level1 allow" ($r.ExitCode -eq 0 -and $perm6 -eq "allow") "exit=$($r.ExitCode) perm=$perm6 stdout=$($r.Stdout)"

    # P7：无流水会话写 .cursor/skills 设施 → deny（Level 1 轻门禁 + CHANGELOG 逃生提示）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (New-HookPayload -Event "preToolUse" -SessionId $simSession -ConversationId $simConvNoFlow -FilePath $skillsPath -Content "small")
    $perm7 = $null
    try { $perm7 = ($r.Stdout | ConvertFrom-Json).permission } catch { }
    Assert-Sim "P7 no-flow conv -> Level1 deny + CHANGELOG msg" ($r.ExitCode -eq 0 -and $perm7 -eq "deny" -and $r.Stdout -match "CHANGELOG") "exit=$($r.ExitCode) perm=$perm7 stdout=$($r.Stdout)"

    # P8：业务路径无 [PM] 标记 → deny（pm-gate 核心语义回归）
    $r = Invoke-HookScript -ScriptName "pm-gate-check.ps1" -StdinJson (New-HookPayload -Event "preToolUse" -SessionId $simSession -ConversationId $simConvNoFlow -FilePath $businessPath -Content "small")
    $perm8 = $null
    try { $perm8 = ($r.Stdout | ConvertFrom-Json).permission } catch { }
    Assert-Sim "P8 business path no [PM] -> deny" ($r.ExitCode -eq 0 -and $perm8 -eq "deny") "exit=$($r.ExitCode) perm=$perm8 stdout=$($r.Stdout)"

    # P9：会话结束时打点仍可查（链路未被大 payload 打断的最终证据）
    $cwFinal = $null
    if (Test-Path -LiteralPath $changelogWritesFile) {
        try { $cwFinal = [System.IO.File]::ReadAllText($changelogWritesFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $cwFinal = $null }
    }
    $gateFinal = $null
    if (Test-Path -LiteralPath $gateFile) {
        try { $gateFinal = [System.IO.File]::ReadAllText($gateFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $gateFinal = $null }
    }
    Assert-Sim "P9 end-of-session both marks persisted" ($null -ne $cwFinal -and $null -ne $cwFinal.$simConv -and $null -ne $gateFinal -and $null -ne $gateFinal.$simConv) "cw=$($cwFinal.PSObject.Properties.Name -join ',') gate=$($gateFinal.PSObject.Properties.Name -join ',')"

} finally {
    # 清理仿真会话条目（保留真实数据）；kill switch 原样恢复
    Remove-SimEntries -JsonFile $gateFile
    Remove-SimEntries -JsonFile $changelogWritesFile
    if ($killSwitchExisted -and -not (Test-Path -LiteralPath $killSwitch)) {
        "" | Set-Content -LiteralPath $killSwitch -Encoding UTF8
    }
}

Write-Host "`n=== simulate-cursor-session summary ===" -ForegroundColor Cyan
Write-Host "total=$script:total failed=$script:failed"
if ($script:failed -gt 0) {
    Write-Host "simulate-cursor-session: FAILED (真实会话 hook 链路真演未通过)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "simulate-cursor-session: OK (等价一次真实会话 hook 链路真演)" -ForegroundColor Green
    exit 0
}
