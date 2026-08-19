# 方案审核档位（L1 / L2 / L3）

本文件为 ai-dev-pipeline **唯一权威来源**。替代「所有场景都必须多模型新会话复核」的单一路径，按风险分档。

> **车道术语**：Express / Direct / Standard / Full — 见 [lane-glossary.md](./lane-glossary.md)。勿使用 v1「微型/轻量/完整模式」等旧称。

## 档位定义

| 档位 | 何时用 | 做法 | 独立复核 |
| --- | --- | --- | --- |
| **L1 自审** | Standard、单模块、无状态机/持久化 | 须子窗（同会话 Subagent 即可，不强制新开 Chat）；输出须标注「L1 非独立复核」 | 否 |
| **L1.5 加强** | Standard 且 Mandatory Code Changes 命中 project-context 回归索引模块（**小规模 → 维持 L1.5，不取较高档**），**或**命中 `.ai-gates/lessons-learned.md` 近 6 个月内有记录的模块/文件（文件热度），**或** `.ai-gates/regression-heat.yaml` 该模块 heat≥medium（机器热度，自动生成）——**文件/机器热度命中取较高档：L1.5 之上 → 方案审 L3 / 双轮 CR（强度升级，不整条升 Full）**；**回归索引模块小规模 + 文件/机器热度双命中 → 按热度入口取较高档（方案审 L3 / 双轮 CR，M2）** | 方案审须子窗（同会话即可，不强制新 Chat 隔离）；CR **优先** Subagent 隔离（见 [isolated-review.md](./isolated-review.md)） | 方案否 / CR 隔离优先 |
| **L2 交叉审** | Standard、未触 Full，跨 2 模块或涉及 public API | **优先** Subagent 隔离；仍读 plan-reviewer SKILL | 部分 |
| **L3 独立审** | Full 车道、状态机/事务/持久数据/跨模块并行 | **优先**每轮 Subagent 隔离；每轮独立找 blocker | 是 |

## 与车道的默认映射

| 车道 | 默认方案审核档位 | 定版要求 |
| --- | --- | --- |
| **Express** | 跳过方案审核 | 不适用 |
| **Direct** | 无方案审；CR 隔离（普通档） | 隔离 CR（Subagent / 新 Chat，普通档）无 blocker 且用户认可 |
| **Standard** | L1；回归索引模块小规模升 **L1.5**（**不取较高档**）；**文件/机器热度命中**（lessons 近 6 个月 / heat≥medium / last_fail_ts）→ **方案审 L3 / 双轮 CR**（取较高档：覆盖既有 L1.5 热度触发；强度升级，不整条升 Full）；**回归索引模块小规模 + 热度双命中 → 按热度入口取较高档（方案审 L3 / 双轮 CR，M2）**；未触 Full 且跨 2 模块时升 L2 | L1/L1.5/L2 无 blocker 且用户确认需求后可 `implementation-ready` |
| **Full** | L3，至少 2 轮 | 多轮均无 blocker 且用户确认 |

## 执行文档字段

执行文档「文档状态」建议增加：

```markdown
- **方案审核档位**：L1 / L1.5 / L2 / L3 / 跳过
- **独立复核轮次**：0 / 1 / 2 / …
```

## L3 独立会话（Full 车道）

- **优先**：主 Agent 拉起 Subagent 隔离会话（UI 上常表现为独立 Agent/Chat 标签）；只注入派发块，**只读**输出结论。细则 → [isolated-review.md](./isolated-review.md)。
- Subagent 不可用时：PM **提示**用户手动新开 Chat；**不校验**是否新开。同 Chat 连续多轮须标注非独立。
- 每轮须独立寻找 blocker，不得只复述上一轮结论。
- **L3 会话只读**：隔离会话仅输出审查结论，**不得修改执行文档**；修订与「审查记录」写入由 `项目经理` 或 `策划` 在主会话完成。
- 结论冲突时以 blocker 优先；交 `策划` 整合后重新进入 L3。

### L3 派发模板（Subagent 或手动新 Chat 共用）

```markdown
方案审核
档位：L3（隔离复核，第 [N] 轮）
模式：只读 — 仅输出审查结论与 blocker，不要修改执行文档
请独立寻找 blocker，不得复述上一轮结论。
执行文档：[路径]
```

成功用 Subagent 时标注 **「隔离复核（Subagent）」**；手动新 Chat 标 **「独立复核（新 Chat）」**；同 Chat 标 **「非独立复核」**。
## L1 输出要求

L1 审查结论必须包含：

```markdown
方案审核档位：L1（非独立复核）
```

不得声称「已完成多模型独立复核」。

## L1.5 文件热度触发（新增）

回归索引模块之外，若 Mandatory Code Changes 涉及的文件/模块在 `.ai-gates/lessons-learned.md` 中**近 6 个月内有记录**（即该处曾出现真实 blocker），同样触发 L1.5——不要求正式进入回归索引表才算数，"最近真的出过问题"本身就是风险信号。**机器热度（2026-08-05 起）**：`.ai-gates/regression-heat.yaml` 中该模块 `heat≥medium` 或近 6 个月有 `last_fail_ts` 记录即触发 L1.5；该文件由 `append-pipeline-outcome.ps1`（失败事件增量更新）与 `compute-failure-heat.ps1`（重算）自动维护，`策划`/`方案审核`直接读 heat 文件即可，**替代人工关键词扫表**。命中原因记为「文件热度」/「机器热度」，与「回归索引模块」二选一或并列写入方案审核档位说明。    

## L1.5 输出要求（Standard 加强）

L1.5 须同时满足：

```markdown
方案审核档位：L1.5 加强 — 回归索引模块（非独立方案复核）
代码审核：PM 提示新开 Chat 派 [CR]（不校验）
```

- 每 Step 的 Regression Validation 须写明引用的回归索引行（模块 + 场景）
- 程序员完成后，PM **提示**用户新开 Chat 粘贴派发块；**不校验**是否新开

## 升级规则

满足任一条，从 L1 升至 L2；从 L2 升至 L3：

- 涉及状态机、事务、持久字段
- 跨 3 个以上模块或 partial 文件簇
- 需要运行环境回归且场景复杂
- L1/L2 审查出现方案级 blocker
- 用户明确要求独立复核

升级由 `项目经理` 或 `策划` 在文档状态中记录。
