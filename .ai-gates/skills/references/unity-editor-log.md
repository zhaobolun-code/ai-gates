# Unity Editor.log（编译自检 + Discover 取证）

> 目的：少让用户粘贴长 Console；Agent **优先自己查**本机 `Editor.log`。  
> **编译错误**可自修；**运行时日志**只作 Discover 证据，**不能**代替 Unity 人工验收（CORE §硬门禁 5）。

## §0 机械化取证（优先）

**优先用脚本，不要肉眼判断关键词命中/日志新鲜度**：Agent 自己读 Editor.log 再口头转述"命中了"这件事，无法被 CR/PM 复核证伪；改用脚本产出的带时间戳 JSON 更可信、更省 token。

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/verify-runtime-evidence.ps1 `
  -Keywords "kw1,kw2" -ExpectAbsentKeywords "known_bad_event" `
  -OutputPath "{方案夹}/证据/{日期}-step{NN}-verify.json"
```

- `-Keywords`：逗号分隔字符串（当前窗验收 A# / Mandatory 预期 Console 关键词），不是数组参数
- `-ExpectAbsentKeywords`（可选）：不该出现的关键词/审计标签（比如物理口径明确禁止的现象），命中即 `anyAbsentHit=true` 且判失败——补上"预期事件发生了"证不了的另一半："不该发生的没发生"
- 输出字段：`overallHit`（命中）、`anyAbsentHit`（命中了不该出现的关键词）、`fresh`（日志新鲜度，默认 30 分钟窗口）、`compileErrors`（`error CS\d{4}` 命中行）、每关键词 `count`/`samples`（≤5 行）
- `exit code`：0 = 新鲜 + 命中（按 Mode）+ 无编译错误；非 0 = 至少一项不满足，**不代表自动 blocker**，仍按下文 §A/§B 由 Agent/CR 解读
- 找不到 Editor.log（`ok:false, reason:editor_log_not_found`）→ 按下文「读不到 / 不存在」处理，不阻塞
- 该 JSON 就是可外置的「证据」，写进 `证据/` 后未完成窗只需一行摘要 + 路径引用，不必贴长日志
- 本脚本只产出事实，**不判定** `static-checked`/`runtime-validated`；证据等级仍按 CORE/developer SKILL 规则由人/Agent 决定
- 无脚本环境（非 Windows/PowerShell 不可用）→ 退回下文 §A/§B 手工流程

## 典型路径

- Windows：`$env:LOCALAPPDATA\Unity\Editor\Editor.log`
- 备选：项目内 `Logs/AssetImportWorker*.log`（视版本）
- 读不到 / 不存在 → **跳过，不阻塞**；再请用户补测或贴**短摘录**（≤40 行）

## A. 改码后 · 编译自检（强制尝试）

1. 改完后读上述路径，搜最近段是否有 `error CS\d{4}`  
2. **命中** → 自行修到无新增 CS 错误再交出  
3. **未命中或读不到** → 标 `static-checked` / `not run`；**不得**因「无 CS 报错」升 `runtime-validated`

## B. Discover / Verify 失败 · 运行日志取证（强制优先）

触发：用户报测挂、A# 失败、缺审计关键词钉因、或「你下一步」本会写「请贴 Console」。

**顺序（钉死）**：

```text
1. 用 Shell/rg 查 Editor.log（勿整文件 Read 灌进上下文）
2. 关键词来自：当前窗验收 A# / Mandatory 预期 Console / 用户白话现象对应审计标签
   （例：ValveFSM、SerialPendingAdvance、IngressBlocked、HandoverBlocked、CollectionDrainAudit）
3. 只摘 ≤15 行相关 + 一行结论写入 Discover / 证据/ 摘要。贴命令/日志/产物前，密钥与 token 写成 `<REDACTED>`；只引信号行。禁止整段贴未脱敏 log。
4. 仍不够 → 再请用户：补测一次，或贴短摘录 / 说明「刚 Play 过、日志已刷新」
```

| 要 | 不要 |
| --- | --- |
| 先查 Editor.log，再问用户贴 log | 默认让用户整段粘贴 Console |
| 关键词检索 + 短摘录外置 | 把整份 Editor.log 贴进 Chat / `未完成.md` |
| 时间戳明显早于本次 Play → 说明「日志可能不是本局」 | 把陈旧日志当成 runtime-validated |
| 查到钉因关键词 → Discover 结论可引用路径+关键词 | 仅凭无报错就说「修好了」 |

## 边界

- 查 log **不等于**已 Unity 验收；行为对错仍须用户测并回话  
- Editor 未开 / 未 Play / 多开实例 → 日志可能空、旧、或不是本项目；如实说明  
- 敏感：不要把完整本机路径以外的无关日志大段外泄进业务 README
