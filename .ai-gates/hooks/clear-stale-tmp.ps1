# clear-stale-tmp.ps1
# 会话开始时由 check-hooks-drift 点源。只删 .ai-gates/tmp/ 里超过 1 天的文件，
# 再去掉因此变空的子目录。目录本身留下。失败不抛出，不写 stdout。

function Clear-StaleAiGatesTmp {
    param([string]$TmpRoot)
    try {
        if ([string]::IsNullOrWhiteSpace($TmpRoot)) { return }
        if (-not (Test-Path -LiteralPath $TmpRoot)) { return }
        $cutoff = (Get-Date).AddDays(-1)
        $files = @(Get-ChildItem -LiteralPath $TmpRoot -Recurse -File -Force -ErrorAction SilentlyContinue)
        foreach ($f in $files) {
            if ($f.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
            if ($f.LastWriteTime -lt $cutoff) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        $dirs = @(Get-ChildItem -LiteralPath $TmpRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue)
        $dirs = @($dirs | Sort-Object { $_.FullName.Length } -Descending)
        foreach ($d in $dirs) {
            if ($d.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
            $left = @(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue)
            if ($left.Count -eq 0) {
                Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
    }
}
