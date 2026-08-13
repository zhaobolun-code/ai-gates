# 文档状态机

本文件定义 ai-dev-pipeline 执行文档「文档状态」的状态、迁移和修改权限。

## 状态

| 状态 | 含义 |
| --- | --- |
| `draft(草稿)` | 策划初稿或修订中，尚未交审 |
| `review-pending(待审核)` | 已交 `方案审核`，未定版 |
| `implementation-ready(可实现)` | 多轮方案审核无 blocker(阻塞问题)，且用户已确认需求 |
| `in-progress(实现中)` | `程序员` 正在按 Step(步骤) 实现 |
| `blocked(已阻塞)` | 存在方案级或实现级 blocker(阻塞问题)，需先解除 |
| `step-completed(步骤完成)` | 当前 Step(步骤) 代码层面完成，代码审核无 blocker(阻塞问题)，但尚未运行环境验证 |
| `runtime-validated(运行已验证)` | 已在运行环境中验证，或用户提供了运行时证据 |
| `completed(已归档)` | 终态：全部 Step(步骤) 完成、运行环境回归通过、文档可归档（不再迁移） |
| `archived(已封存-失败/放弃)` | 终态（仅限热修短窗/切片）：因命中止损或用户/PM 决定放弃而收口，**非**成功完成；须括号写明失败原因 + 去向（见 [doc-windowing.md](./doc-windowing.md) §热修/切片失败或回退即封存） |

## Express / Direct 车道例外

Express 车道**不迁移**执行文档状态机。Agent 与用户口头确认运行结果时，不得自行将执行文档标为 `runtime-validated(运行已验证)` 或 `completed(已归档)`。

Direct 车道**不落盘、不迁移**执行文档状态机（对话内 A#/切片，无执行文档）；跨会话 / 改不完自动升 Standard 后按正常状态机迁移。

## 允许迁移

```text
draft(草稿)
  → review-pending(待审核)
  → implementation-ready(可实现)
  → in-progress(实现中)
  → blocked(已阻塞) / step-completed(步骤完成)
  → runtime-validated(运行已验证)
  → completed(已归档)
```

`blocked(已阻塞)` 解除后回到：

- 方案缺陷解除 → `review-pending(待审核)`
- 实现阻塞解除 → `in-progress(实现中)`
- 代码审核 blocker(阻塞问题) 修复后 → `in-progress(实现中)`，并重新交 `代码审核`

## 修改权限

| 迁移 | 允许岗位 |
| --- | --- |
| `draft(草稿) → review-pending(待审核)` | `策划` |
| `review-pending(待审核) → implementation-ready(可实现)` | 方案审无 blocker → 发一轮确认包（§A）；「准」同条 ready 并开始改码（[handoff-automation.md](./handoff-automation.md) §0/§F） |
| `implementation-ready(可实现) → in-progress(实现中)` | `程序员`（一轮确认「准」；§B 仅中断恢复） |
| `runtime-validated → 续链下一窗` | 发续链合并包；「准」同条建窗并开始改码（§G；禁拆两轮） |
| `in-progress(实现中) → blocked(已阻塞)` | `程序员` / `代码审核` / `方案审核` |
| `blocked(已阻塞) → review-pending(待审核)` | `方案审核` / `策划` |
| `blocked(已阻塞) → in-progress(实现中)` | `程序员`（阻塞已解除并记录证据；重新进入后须**重新交 `代码审核`**） |
| `in-progress(实现中) → step-completed(步骤完成)` | `程序员` + `代码审核` 无 blocker（CR 收口同条建议/执行，见 handoff-automation §C；**Auto 时须叠加** stop_reason，见 §Auto） |
| `step-completed(步骤完成) → runtime-validated(运行已验证)` | `程序员` / `项目经理`（用户已提供运行环境证据或明确验证记录时执行；须同步更新证据等级为 `runtime-validated(运行已验证)`；AI 不得无证据自行迁移） |
| `runtime-validated(运行已验证) → in-progress(下一已批准 Step)` | `项目经理` / `程序员`（**Auto**：仍有已批准 Step；文档**已是** `runtime-validated`；普通待测用「继续 Auto」/同条「测试通过」；预算用尽须「本窗 Auto」清 `reason=max_auto_steps` 后再迁） |
| `runtime-validated(运行已验证) → completed(已归档)` | 全部 Step(步骤) 实现、README/版本记录已收口、运行环境回归通过后，由 `项目经理` 标记为终态；`程序员` 只可提出可归档建议 |
| `任意态 → archived(已封存-失败/放弃)`（仅热修短窗/切片） | `项目经理` 判定命中止损（diagnosis-gates.md §1/§2.1）或用户明确放弃当前短窗后，同条标记；`程序员`/`方案审核` 只可提出封存建议 |

## Auto 与 stop_reason（Loop Engineering）

> 细则：[loop-engineering.md](./loop-engineering.md)、[handoff-automation.md](./handoff-automation.md) §H。`stop_reason` **不是**文档状态字段，二者必须同时合法、不得互相替代。

### 强制映射（摘要）

| stop_reason / reason | 文档状态 |
| --- | --- |
| `completed` | `completed` |
| `blocked` / `fuse` | `blocked` |
| `await_human reason=unity_test` | `step-completed` |
| `await_human reason=max_auto_steps`（签收前） | `step-completed` |
| `await_human reason=max_auto_steps`（签收后仍有已批准 Step） | `runtime-validated`（**保留** stop_reason） |
| `await_human reason=discover/replan/scope_change/lane_upgrade` | `blocked` |

### 按原因恢复（禁止统一直迁 `in-progress`）

- 普通待测签收 + 有下一已批准 Step：`step-completed → runtime-validated → in-progress`（清当前 stop_reason）
- 预算用尽签收 + 仍有 Step：`step-completed → runtime-validated` 保留 `reason=max_auto_steps`；仅「本窗 Auto」后清 reason → `in-progress(下一 Step)`
- 方案级 / `max_repair_rounds`：`blocked → review-pending → 按**当前车道**重审无 blocker（**Standard 不升 Full**；Full 才 L3 两轮）→ 重新「准」→ `implementation-ready → in-progress`
- 实现级：`blocked → in-progress(原 Step)`；修后重做隔离主 CR
- 测试失败：`step-completed → blocked` → diagnosis-gates §0

### Auto 旁路禁止（非法迁移）

当文档为 `step-completed`（待测）或 `runtime-validated` 且仍带 `reason=max_auto_steps` 时：**禁止**因「做 Step N」、直接派 `developer`、§B 口令或「CR 通过即可」迁入下一 Step 的 `in-progress`。Auto 下串行规则改读为：前一步须**测签收至 `runtime-validated`**（不仅是 CR 通过）后才可开始下一步。

## 状态与证据等级

状态表示流程阶段，证据等级表示验证强度。二者不可互相替代。

示例：

- `step-completed(步骤完成)` + `static-checked(静态核对)`：代码与审查静态通过，但未运行。
- `step-completed(步骤完成)` + `locally-validated(本地已验证)`：本地构建或诊断通过，但未运行环境验证。
- `runtime-validated(运行已验证)` + `runtime-validated(运行已验证)`：运行环境证据已确认。

不得把 `step-completed(步骤完成)` 写成 `runtime-validated(运行已验证)`，除非有真实运行时证据。
[long-task.md](./long-task.md) 调度层不得把状态迁到 `runtime-validated`；卡住停点保持当前态 + 确认包。

### 禁止自造状态名

文档「状态」字段 **只能**使用上表枚举（可附中文括号）。  
**禁止**把 `verify-failed` / `awaiting-unity` / `verify-passed-partial` 等写成状态值。

| 口语想表达 | 应写状态 |
| --- | --- |
| Unity 未过、等决策 | `blocked` |
| 代码+CR 完、待用户测 | `step-completed` |
| 热修目标过、主现象未过 | `step-completed` 或主窗 `blocked`；在 Discover 一行说明部分签收 |

### `completed` 互斥（强制）

- 不得与 `implementation-ready` / `in-progress` 同时出现。  
- `completed` 时 `可交给程序员` 必须为否。  
- 升 `completed` 条件见 [handoff-automation.md](./handoff-automation.md) §E。

### `archived` 与 `completed` 的区分（强制）

- `completed`：**成功**收口的终态；`archived`：**失败/放弃**收口的终态（仅热修短窗/切片）。二者不可混用或互相顶替。
- `archived` 同样与 `implementation-ready` / `in-progress` 互斥；标记后该短窗视为不可再改码，需要继续时须新开短窗，不得解封复用。

## 并发与协作（v1.5 / v1.5.1）

当多个 Agent / 新会话**同时操作同一执行文档**时，以下规则防止竞态破坏状态一致性。

### 原则

- **单文档串行化**：同一执行文档的 `文档状态` 同时只允许一个 Agent 迁移。
- **项目经理为调度中枢**：所有需迁移文档状态的 Agent 须先由 `项目经理` 派发；并行 Agent 各自处理不同执行文档，禁止交叉写。

### 并行隔离规则

| 场景 | 允许 | 禁止 |
| --- | --- | --- |
| 两个 `程序员` 同时实现不同执行文档的 Step | 是 | — |
| 两个 `程序员` 同时实现同一执行文档的不同 Step | 否 | 每个 Step 必须串行；非 Auto：前一步 CR 通过后才可开始下一步；**Auto**：前一步须测签收至 `runtime-validated` 后才可开始下一步（见上节旁路禁止） |
| `代码审核` 与 `文档` 同时操作同一模块 | 否 | 必须等 CR 完成且无 blocker 后才可写 README |
| `方案审核`（L3 多轮）并行各开新 Chat | 是 | 各 Chat **只读不写**（仅输出结论）；定稿由 `项目经理`/`策划` 单 Agent 写入；冲突结论在单 Agent 内收口 |

### 项目经理的并发检查清单

派发并行 Agent 前，逐项确认：

- [ ] 各 Agent 操作的是**不同执行文档**，或同一文档的**只读副本**
- [ ] 当前无其他 Agent 持有同一执行文档的 **写权限**（即前序 Agent 已交回交接块）
- [ ] 若多个 `方案审核` Chat 并行，结论收口后由 `项目经理` 在**单 Agent 内**统一写入执行文档
- [ ] L3 多轮间不并行 —— 一轮结束后再启动下一轮

### 冲突恢复

若意外出现两个 Agent 同时写同一执行文档（如状态被后写入覆盖）：

1. 以**交接块「交接时间」最新**的为准（见 `handoff-template.md`）。
2. 被覆盖方在 `项目经理` 统筹下重新读取最新状态后继续。
3. 若状态出现非法迁移（如 `in-progress(实现中)` 被跳回 `draft(草稿)`），回退到最近合法状态并记录原因。
