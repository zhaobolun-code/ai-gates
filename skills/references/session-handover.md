# 会话交接（Session Handover）

> 权威：跨 Chat / 换模型续跑同一方案时的**八段摘要**。  
> 接线：[handoff-automation.md](./handoff-automation.md) §J。可粘贴空表 → [templates/session-handover.md](../templates/session-handover.md)。  
> 与岗位内交接块 [handoff-template.md](./handoff-template.md) **互补**（本文件专治跨会话；后者专治同会话转岗）。

## 目标

少交接翻车：下一会话只靠本摘要 + `未完成.md` 即可续，无需重读主对话。

## 八段字段（钉死 · 缺一不可）

| # | 字段名 | 写什么（白话、短） |
| --- | --- | --- |
| 1 | **当前状态** | 文档状态 + Step + Auto 步数/`stop_reason`（若有） |
| 2 | **已做** | 本窗已落地/已签收要点（≤5 行） |
| 3 | **下一步** | 下一刀具体动作（做 Step N / 等测 / 结案） |
| 4 | **禁区** | 明确不改什么（文件/范围/口令旁路） |
| 5 | **依赖** | 前置：已「准」、revision、Unity、外部材料 |
| 6 | **风险** | 已知坑 / soft risk / 行数债（可无则写「无」） |
| 7 | **证据路径** | 方案夹、点名派发、夹具路径（禁灌全文） |
| 8 | **下一口令** | 用户下一句该回什么（如「本窗 Auto」「测试通过」） |

## 触发（须输出或落盘）

任一条命中 → 主 Agent **必须**按上表生成摘要（聊天可贴全文；推荐另存 `证据/_handover.md`，`未完成.md` 首段只留一行指针）：

1. Auto `await_human reason=max_auto_steps`（预算用尽）
2. 方案将迁 `completed` / 已结案交接
3. 用户说「交接」/「换 Chat」/「handover」

**不算触发**：普通 `reason=unity_test` 待测（可用更短「你下一步」）；上下文长度「触顶」≠本触发。

## 禁止

- 粘贴 `已完成/**` 全文、长 Console、整份主对话
- 自造第九段替代上表字段名
- 用 handover 静默改码或跳过「准」
