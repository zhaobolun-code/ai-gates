# 轻量交接（handoff-lite）

> 触发：一次性 / 临时中间交接（prototype 往返、子代理间传话、跨窗小任务）时自动加载。
> 出处：mattpocock/skills handoff（2026-08-07 对照落地）；字段表=session-handover 八段压缩 + 上游「建议技能」。
> 区分：正式岗位交接用 [handoff-template.md](./handoff-template.md)；跨会话交接用 [session-handover.md](./session-handover.md) 八段；[agent-brief.md](./agent-brief.md) 是 AFK 子代理委托书（任务契约）。本文件只补「一次性 / 临时中间交接」缺口，不替代以上任何一种。

## 9 字段一页纸（≤30 行）

| 字段 | 内容 |
| --- | --- |
| 当前状态 | 一句现状 |
| 已做 | ≤5 行要点 |
| 下一步 | 接手者接下来做什么 |
| 禁区 | 边界 / 别碰什么 |
| 依赖 | 前置条件 / 外部依赖 |
| 风险 | 已知风险 |
| 证据路径 | 指向已有产物（路径 / URL） |
| 下一口令 | 接手者下一条口令 |
| 建议技能 | 建议加载的 reference / 技能 |

## 规则

1. **不重复已有产物**：specs / plans / ADR / issue / commit / diff 已记录的内容按路径或 URL 引用，不复制。
2. **redact 敏感信息**：API key、密码、PII 一律脱敏。
3. **临时性交接存 `.ai-gates/tmp/` 或 OS tmp**，不入正式窗口。
