# 架构体检（可选 · CRG 支撑）

> 触发：Full 车道策划前 / 大模块重构前 / TL 要求时，做一次只读架构概览，为方案落点与 Step 切分提供证据。
> 出处：mattpocock/skills improve-codebase-architecture，2026-08-07 对照落地；工具用既有 CRG（code-review-graph），不新增依赖。

## 命令（只读 · MCP code-review-graph）

| 目的 | 工具 |
| --- | --- |
| 模块边界总览 + 社区耦合告警 | `get_architecture_overview`（detail_level=minimal 先） |
| 架构热点（改动波及面大） | `get_hub_nodes` / `get_bridge_nodes` |
| 结构弱点（孤立 / 薄社区 / 未测热点） | `get_knowledge_gaps` |
| 意外耦合（跨社区 / 跨语言边） | `get_surprising_connections` |

业务 C# 在子模块时对子模块根查图（repo_root），细则 → [codegraph-probe.md](./codegraph-probe.md)。

## 产物

- 一页「架构体检」小节（≤30 行）：热点节点、薄弱点、候选深化点 → 写进方案「窗口关系摘要」或独立 `证据/架构体检.md`。
- 体检结论不直接定车道 / 方案，只供策划与方案审引用；「图谱宽判」按 codegraph-probe 过滤（partial / MonoBehaviour 偏宽、XLua 推断边）。
- 禁止把体检当验收：架构体检通过 ≠ 业务 A# 通过。

## 与流程的关系

- Full：体检结果并入执行文档（策划前可选跑）；无图谱时按 codegraph-probe 降级，不硬拦。
- Standard：仅在策划主动要求时跑；CR / 方案审不因未跑体检降级。
