# cursor-hooks-common.ps1
# Cursor 版 hooks 共享库（被 .ai-gates/hooks/ 下各脚本点源加载；本文件无 param() 块）。
#
# 2026-08-06 合并入口（pre-write-gate.ps1 / post-write-gate.ps1）：同一事件多门禁改为
# 单进程内依次执行，stdin 只读一次并缓存到全局，后续子脚本共享同一 payload
# （子脚本点源本文件后仍会走此缓存，避免第二个门禁读到已耗尽的流）。
# 读取实现与 mark-changelog-write 的健壮模式一致（OpenStandardInput + StreamReader 显式
# UTF-8），避免超大 payload 时 PS5.1 Console.In.ReadToEnd 解析失败。

function Read-HookStdin {
    if ($null -ne $global:AI_GATES_HOOK_STDIN_CACHE) { return $global:AI_GATES_HOOK_STDIN_CACHE }
    $stream = [Console]::OpenStandardInput()
    try {
        $reader = New-Object System.IO.StreamReader($stream, (New-Object System.Text.UTF8Encoding($false)))
        $raw = $reader.ReadToEnd()
        $reader.Close()
    } finally {
        $stream.Dispose()
    }
    if ($null -eq $raw) { $raw = "" }
    $global:AI_GATES_HOOK_STDIN_CACHE = $raw.TrimStart([char]0xFEFF)
    return $global:AI_GATES_HOOK_STDIN_CACHE
}
