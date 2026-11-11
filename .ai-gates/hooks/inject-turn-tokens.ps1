# inject-turn-tokens.ps1
# 2026-11-11：不再往下一轮注入 token 行。hooks.json 已卸下。
# 保留文件是为了旧调用还能退出。TokenFile 忽略，不读旧账。
param(
    [string]$TokenFile = ""
)
$TokenFile = $TokenFile
Write-Output '{}'
exit 0
