# 流水线端到端样例（按需 lazy load）

> 权威路由见 [CORE.md](../CORE.md)。本文件仅作 Agent/TL 对照，非日常必读。

## Express 端到端样例

> 样例路径**不在** project-context §Express 车道升级 禁入列表内。

**用户：**

```text
项目经理
把 Interaction 模块 DeviceDragGesture.cs 里 Debug 日志前缀统一成 [Interaction][Drag]，只改这一个 .cs
```

**Agent（摘要）：**

```text
[PM]

pm:
  lane: Express
  lane_rules_hit: "4/4"
  review_tier: skip
  next_role: developer
  readme: skip
  user_state: 进行中
  blockers: []
  project_context: loaded
  diff_hint: Express
  snapshot: n/a

**你下一步**：Express 单文件改日志。我先写切片，你回复「可以」后开始改。

[PM] express-slice：…

[developer] …
[Express 自检 — 视同代码审核] …

[PM]
pm:
  lane: Express
  …
  user_state: 待 Unity 测试
  …

**你下一步**：去 Unity 按切片步骤测，回复通过或不通过。
```

**用户：** `测试通过。` → `user_state: 已定版`。

## Standard + L1.5（回归索引模块 · 非功能性改动）

**用户：**

```text
项目经理
改 [回归索引模块] 里某 Debug 类的日志格式，只改一个 .cs
```

**Agent（摘要）：**

```text
[PM]

pm:
  lane: Standard
  lane_rules_hit: "3→Standard"
  review_tier: L1.5
  next_role: planner
  readme: dev-one-liner
  user_state: 进行中
  blockers: []
  project_context: loaded
  diff_hint: Standard
  snapshot: n/a

| 车道 | Standard + L1.5 — 命中 §Express 升级，非功能性日志不升 Full |
| 下一岗 | planner（plan-lite） |
| README | 程序员一行 — 仅 1 文件、无新 API |
| 进度 | 进行中 |

**你下一步**：等待 Agent 写 plan-lite，确认理解是否正确。

（后续：plan-lite → 用户确认 → plan-reviewer L1.5 → developer → 新开 Chat 粘贴 CR 派发块 …）
```

填表示例可参考本项目 `Assets/Doc/_examples/` 目录下的示例文档（项目专属，各项目自建，不随通用 Skill 包分发）

## Full 强制（回归索引模块 · 功能性改动 · 规模较大）

**用户：**

```text
项目经理
[回归索引模块] 需要新增一个功能性行为：xxx
```

**判定要点**：功能性改动（非仅日志/注释）+ 命中 project-context「运行回归索引」模块 + **规模较大**（>3 个业务源文件 / 单文件净增删 >~150 行 / 跨模块·API·持久）→ **CORE §三车道判定 第 2 步第 4 条触发 Full**。小规模（≤3 文件、≤~150 行、无跨模块·API·持久）→ 最低 Standard+L1.5，不强制 Full。

```text
[PM]

pm:
  lane: Full
  lane_rules_hit: "2→Full"
  ...

**你下一步**：此项改动涉及 [回归索引核心模块] 的功能性行为，建议启用完整流程（Full）；请 TL 确认，或回复「完整流程」继续。
```

真实案例参考：命中回归索引模块的功能性 Step 推进，全程应标注「流水线模式：完整模式」——本项目已有真实执行文档验证该判定（见 `Assets/Doc/` 下项目专属执行文档历史，不随通用 Skill 包分发）。
