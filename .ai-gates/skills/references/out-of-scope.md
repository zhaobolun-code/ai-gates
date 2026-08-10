# OUT-OF-SCOPE 被拒需求归档

> 触发：PM 判「不做」的 enhancement 类需求归档与反查去重。来源：mattpocock/skills `triage/OUT-OF-SCOPE.md`（2026-08-07 对照落地）；本地化不引入 GitHub issue tracker 语义（本仓无 tracker 依赖）。

## 一概念一文件

被拒需求按**概念**归档：一个概念一个文件（`# 概念名` + 决策 + durable 理由 + Prior requests 列表），文件名 kebab-case（如 `dark-mode.md`）。多条同类请求归同一文件，按概念去重，不按请求数膨胀。

```markdown
# 概念名

**Decision:** 不做（一句话）。
**Reason:** durable——项目范围 / 技术约束 / 战略决策。
**Prior requests:**
- 2026-08-07 — "请求摘要/来源"
```

## 理由要求

- 理由须 durable：项目范围 / 技术约束 / 战略决策。
- 禁止临时借口（「太忙 / 没时间」）——那是 **deferral（延后）**，不是 **rejection（拒绝）**，不归档。

## 反查去重流程

新需求评估时按**概念相似性**扫 `.ai-gates/out-of-scope/`（按概念而非关键词；「夜间主题」命中 `dark-mode.md`）。命中后交维护者三选一：

- **确认**：同类被拒 → 追加 prior request，继续归档。
- **重议**：改变主意 → 删除或更新归档文件，新需求照常评估。
- **区分**：概念不同 → 照常评估，不归档。

## 写入时机

- 仅 **enhancement 类被拒需求**归档。
- **「已实现」不算被拒、不归档**——那是已建成功能，归档会污染去重（伪拒绝）。
- bug 修复不归档。

## 落盘约定

- 目录：`.ai-gates/out-of-scope/`（不入 git；与 `.ai-gates/lessons-learned.md`、`pipeline-*` 并列；说明见 CORE §工作区卫生 + AGENTS.md §工作区卫生）。
- 归档文件不记录敏感内容；涉敏感信息提示放项目外。

## PM 流程句

PM 判「不做」时，在「你下一步」提示「已记入 out-of-scope/<概念>」。
