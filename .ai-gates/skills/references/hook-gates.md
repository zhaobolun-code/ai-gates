# 机器门禁短表

登记日 2026-10-22。这一天把每道钩子防的失误写在一处。`hooks-log` 里有审计行，没有按门禁统计响了几次、拦到的是不是真问题。

零日志不得当拆除理由。没量过不等于没事。本表不自动把拒绝降成只记录，也不自动加新门禁。

拆或改一道门禁之前，先改这一行的「防什么」。上次看过 = 最近一次对着脚本核对这行仍属实的日期，不是文件随便改过的时间。

Claude / Codex 的同名脚本跟下面同一条假设，不另开行。`cursor-hooks-common.ps1` 是共用函数，不是一道门。

| 钩子 | 决定 | 防什么 | 上次看过 |
| --- | --- | --- | --- |
| `pre-write-gate.ps1` → `pm-gate-check.ps1` | 不因打点拒绝 | 业务路径不再查 `[PM]`。改技能设施仍要先有变更日志打点。审核戳记和派发文件仍只有子窗能写。 | 2026-11-11 |
| `git-safety-check.ps1` | 拒绝 | 强推（`--force` / `-f` / `+` 引用）、`reset --hard`、`clean` 带 d/f/x、`checkout -f` 或丢掉路径上的改动、`branch -D`。`--force-with-lease` 不拒绝，只记一笔。规则在 `gate-decision.ps1`。 | 2026-10-23 |
| `bash-write-gate.ps1` | 拒绝 | Shell 里 `Set-Content` / `Out-File` / `Clear-Content` / `[IO.File]::WriteAll*` / 重定向写文件。业务路径不查 `[PM]`，设施路径要新鲜变更日志。生成目录放行。提不到路径则放行。规则在 `gate-decision.ps1`。 | 2026-11-11 |
| `task-model-gate.ps1` | 拒绝 | 流水线岗位子窗没写 `model` 或写成 `inherit`，从而抄主窗模型。探索类子窗不拦。 | 2026-10-22 |
| `gate-decision.ps1` | 不拒绝 | 待测只记在回复里，不挡下一行业务 `.cs` / `.lua`。同一现象热修满 2 次仍拒绝。 | 2026-11-10 |
| `gate-decision.ps1` | 拒绝 | 同一窗、同一 A#、同一句现象，热修已有 2 次后再写业务代码。三个字段对不上，或车道已经升了，就放行。 | 2026-10-23 |
| `post-write-gate.ps1` → `check-unity-compile.ps1` | 只提示 | 刚写过 `.cs` / `.lua`，Editor.log 里出现 `error CS`。不拦这次写入，也不跑 Unity。 | 2026-10-22 |
| `check-hooks-drift.ps1` | 只提示 | `hooks.json` 和门禁脚本的声明对不上。 | 2026-10-22 |
| `relight-after-compact.ps1` | 只提示 | 对话被收成摘要之前，把入口指针塞回去，避免把摘要当成约定。 | 2026-10-22 |

只记录、不拦截：

- `audit-write.ps1`：每次写入留下审计。
- `mark-changelog-write.ps1`：变更日志写过之后打点，设施改动才放得过。
- `mark-pm-gate.ps1`：脚本只退出。不再写 `pm-gate.json`，也不往下一轮塞 token 行。不拒绝工具。
- `hooks/copilot/mark-pm-gate.ps1`：同样只退出，stdout 是 `{}`。把 `hooks/copilot/hooks.json` 复制到 `.github/hooks/pm-gate.json` 才生效；安装脚本不自动创建。
- `inject-turn-tokens.ps1`：已从 `beforeSubmitPrompt` 卸下。旧 token 文件还在也不注入。

## 每端会不会响

判定在 `hooks/gate-decision.ps1` 一份。下面是接线，不是第二套规则。`failClosed` 仍是 false：脚本自己失败就放行。

| 判定 | Cursor | Claude | Codex CLI | Codex 桌面 | Trae | 无 pwsh |
| --- | --- | --- | --- | --- | --- | --- |
| 写工具 | 拒绝 | 拒绝 | 拒绝 | 未证实 | 未接线 | 未接线 |
| Shell 显式写文件 | 拒绝 | 拒绝 | 拒绝 | 未证实 | 未接线 | 未接线 |
| 高危 Git | 拒绝 | 拒绝 | 拒绝 | 未证实 | 未接线 | 未接线 |
| 派子窗没写 model | 拒绝 | 未接线 | 未接线 | 未接线 | 未接线 | 未接线 |
| 压缩前点亮 | 只提示 | 未接线 | 未接线 | 未接线 | 未接线 | 未接线 |
| 回复打点 | 只记录 | 只记录 | 只记录 | 未证实 | 未接线 | 未接线 |
| 读文件 | 未接线 | 未接线 | 未接线 | 未接线 | 未接线 | 未接线 |

Cursor 的 Shell 入口是 `pre-shell-gate.ps1`（先 Git，再写文件）。允许时的 JSON 按端不同：Cursor 写 `permission`，Claude 写 `permissionDecision: allow`，Codex 必须省略该字段。
