# 执行文档模板（AI 可执行）

> **用法**：`策划` 新建时先建方案文件夹，将本模板写入 **`未完成.md`**（见 [doc-windowing.md](./doc-windowing.md)）。
> **路径**：用户指定 > 默认 **`.ai-gates/Doc/{主题}/{方案短名}/未完成.md`**（见 [doc-path-defaults.md](./doc-path-defaults.md)）。
> **结构参考**：[执行文档黄金样例.md](./执行文档黄金样例.md)（v1.7.7，Skill 通用）。
> 章节不可删；标题可微调，内容类别必须保留。状态迁移见 [state-machine.md](./state-machine.md)。已完成 Step 迁入同目录 `已完成/`，禁止在本文件堆积历史长文。
> **活跃窗软上限**：`未完成.md` ≤150行；超限写原因/压缩时点并外置历史、证据或当前 Mandatory，禁止删除 A#/Mandatory 压行。

---

# [主题] 执行方案（AI 可执行）

## 给下一个 AI 的第一条指令

请从 **Step(步骤) 1** 开始实现；一次只做一个 Step。若无法继续，用 blocker 格式写清阻塞点，不要猜测。

## 文档状态

> **方案审核档位**：须**单选**其一（`L1` | `L1.5` | `L2` | `L3` | `跳过`），定稿时删未选项；**禁止**未决串 `L1 / L1.5 / L2 / L3 / 跳过`。`.cursor/skills/**` 改动默认 **L1.5**。

- **状态**：draft(草稿)
- **当前 Step(步骤)**：N/A
- **车道**：Standard
- **方案审核档位**：L1
- **独立复核轮次**：0
- **最后方案审核**：N/A
- **最后统筹**：N/A
- **需求确认**：待确认
- **证据等级**：claimed(已声称)
- **可交给程序员**：否

## AI 无歧义执行规则

- 下一个 AI 应实现代码，而非止于讨论。
- 范围大时完成当前 Step 的**最小可运行切片**。
- 入口缺失时先搜索等价入口，禁止平行 bypass。
- 旧行为与新文档冲突时，仅在公开接口/持久数据/用户明确约束处保留兼容。
- 无法继续时使用 blocker 格式：

```text
blocker(阻塞问题):
- 缺失条件：
- 阻塞位置（文件或方法）：
- 已完成层级：
- 所需证据或场景：
- 下一继续点（文件、函数、章节）：
```

## 必读材料

- `.cursor/project-context.md`（**若存在**；新项目：`init-project-context.ps1`）
- [模块 README 路径，如 `path/to/module/README.md`]
- [相关执行文档 / 设计文档]

## 窗口关系摘要

> 跨窗/续作/旁路时**必填**；纯单窗无邻窗可写「无（单窗）」一行。窗路径列写**主题短名**（文件夹 basename），不写完整分类夹路径。

| 窗路径（主题短名） | 关系（Beads 枚举） | 状态 | 关键结论（一句） |
| --- | --- | --- | --- |
| `[方案短名或邻窗短名]` | `upstream` / `downstream` / `related` / `evidence-from` / `blocks` / `depends-on` | [draft / 执行中 / 签收 / 停写 / runtime-validated 等] | [一句可检索结论] |

> **搬家/断链**：分类夹可变（`执行中/`→`签收/` 等）；搬家后**必须**跑 `migrate-pipeline-window.ps1`；跨链相对路径用 `repair-doc-crosslinks.ps1`（见 [doc-windowing.md](./doc-windowing.md) §迁移动作）。**禁止**手挪文件夹后只改状态字段。

## 硬约束

- [不可违反的项目/模块约束，引用 README 硬约束条目 — 只列本次相关]
- [涉及多语言层时注明语言层；见 `.cursor/project-context.md` 技术栈，若存在]

## Delta-only（强制）

本文只写相对当前仓库的变更；模块原理以 README 为准，禁止重写系统说明。细则 → [acceptance-and-delta.md](./acceptance-and-delta.md)。
每 Step 须含 **Delta Spec**（ADDED / MODIFIED / REMOVED）；签收后按该三段收敛物理口径/A#。

## 验收条款（实现不得超出）

- A1：[场景 + 操作 + 预期现象/Console + 失败判据]
- A2：[可选]
- 非目标：[明确不做什么]

## 结案变更摘要（仅准备 completed 时填写；一页内）

- **ADDED**：[全案最终新增；无则写无]
- **MODIFIED**：[旧→新；无则写无]
- **REMOVED**：[全案最终移除；无则写无]
- **归并到**：[已更新的物理口径/A#/README章节；无则写无]

## 当前代码状态与缺口

- **已存在**：[已读到的真实入口、类、方法 — 空着不得定版]
- **缺口**：[缺什么、在哪找]
- **默认决策**：[Ambiguity 时的保守选择及原因]

## 分阶段实现计划

### Step(步骤) 1: [步骤名称]

Goal:
- [可观察结果]

满足验收:
- A1, A2

**DO NOT TOUCH（冻结表）**: [本步冻结的 README 版本段 + 点名 API/文件；空则写「无（已扫）」。窗级硬约束≠本字段，不可省]

Prerequisites:
- 无 / [前置 Step 或条件]

阻塞边（blocking edges，可选）:
- 无 / [本 Step 依赖的 Step/窗口/票（depends-on）；被谁依赖（blocks）——为并行窗口与调度铺路；无或无需并行调度可省略]

Requirements:
- [功能要求]
- [必须保留的约束]

Pitfalls:
- [常见错误]
- [不得回归的现有行为]
- **Agent 易错**：[符号 + 实际语义 + 文件/类/方法证据；未发现则写「未发现；已检查 [关键符号]」]

Delta Spec（相对当前物理口径 / README，必填）:
- ADDED: [无则写「无」]
- MODIFIED: [无则写「无」；写清旧→新]
- REMOVED: [无则写「无」]

口径同步提示（签收后）: [无 / 列出物理口径或 A# 需改句子]

复用四问（写 Mandatory 前 · 见 [execution-discipline.md](./execution-discipline.md)）:
- 已有: [README/符号/同主题窗]
- 复用: [helper/Service/门闸/分支；不能则为什么]
- 少写/不写: [改参/接旧轨/只改口径？须新写才写]
- 能删: [REMOVED 指向 / 无可删 / 建议抽离]

Mandatory Code Changes:
1. 修改 `[path]` / `[class or function]`:
   - [具体变更]
   - [默认决策]
2. 集成验证：
   - 必需测试/日志/信号：
   - 失败处理：

Required Validation Logs Or Signals:

```text
[Subsystem][Stage] action=... result=... source=... target=... amount=... reason=...
```

Regression Validation:
- 场景或测试：[描述]
- 预期结果：[描述]
- 通过标准：[描述]
- 若失败，收集：[日志/对象状态]

新增回归场景（若适用；程序员交接 + 文档同步至 project-context.md）：
- 模块：[ModuleName]
- 场景：[简短名]
- 最低验证步骤：[操作步骤]
- Console 关键词：[关键词列表]

<!-- 复制上方 Step 块增加 Step 2、Step 3 … -->

## 性能与安全约束

- [热路径、分配、跨语言调用等]

## 整体回归检查清单

- [ ] [跨 Step 的全量回归项 1]
- [ ] [项 2 — 可引用 project-context.md 运行回归索引]

## 完成标准

- 全部 Step 实现且代码审核无 blocker
- [模块] README 版本记录已更新
- [列出须 runtime-validated 的场景]

## 强制推进顺序

```text
策划定稿 → 方案审核（按档位）→ implementation-ready → 程序员（逐步）→ 代码审核 → 文档 → 用户运行回归 → completed(已归档)
```

## 实施记录

| 日期 | Step | 岗位 | 摘要 | 证据等级 |
| --- | --- | --- | --- | --- |
| | | | | |

## 审查记录

| 日期 | 档位/轮次 | 岗位 | blocker 摘要 | 结论 |
| --- | --- | --- | --- | --- |
| | | | | |
