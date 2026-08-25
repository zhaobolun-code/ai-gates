# 流水线端到端样例（按需 lazy load）

> 权威路由见 [CORE.md](../CORE.md)。本文件仅作 Agent/TL 对照，非日常必读。

## Express 端到端样例

> 样例路径即使命中回归索引，机械微改仍走 Express（CORE：回归索引不单独否决）。

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

## Express（回归索引模块 · 机械单文件）

**用户：**

```text
项目经理
改 [回归索引模块] 里某 Debug 类的日志格式，只改一个 .cs
```

**判定要点**：恰好 1 个文件 + 机械 → **Express**。回归索引不单独升 Standard。

**你下一步**：机械微改（仅 1 个文件），走快车道；若你认为涉及行为变化，请回「直通道」。

## Standard + L1.5（回归索引模块 · 已超过 3 个文件）

**用户：**

```text
项目经理
[回归索引模块] 要改 4 个业务源文件的行为
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

| 车道 | Standard + L1.5 — 超过 3 个文件；已在标准上，回归索引只加强审 |
| 下一岗 | planner（plan-lite） |
| README | 程序员一行 |
| 进度 | 进行中 |

**你下一步**：超过 3 个文件，走标准道。我先写 plan-lite。

（后续：plan-lite → 用户确认 → plan-reviewer L1.5 → developer → 隔离 CR …）
```

填表示例可参考本项目 `.ai-gates/Doc/_examples/` 目录下的示例文档（项目专属，各项目自建，不随通用 Skill 包分发）

## Standard（回归索引模块 · 功能性改动 · 规模较大）

**用户：**

```text
项目经理
[回归索引模块] 需要新增一个功能性行为：xxx
```

**判定要点**：>3 个业务源文件 / 跨模块 / API / 持久 → **Standard**（已判 Standard 时回归索引 → L1.5）。≤3 文件、无 API/持久/跨模块 → **Direct**。禁止仅因回归索引点名就 Full。禁止仅因存档/跨模块就 Full。用户点名「完整流程」，或已在 Standard 上再止损 → Full。

```text
[PM]

pm:
  lane: Standard
  lane_rules_hit: "3→Standard"
  ...

**你下一步**：规模较大，走标准道（plan-lite）。若你认为要完整流程，回「完整流程」。
```
