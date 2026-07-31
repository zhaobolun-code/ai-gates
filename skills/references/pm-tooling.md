# PM 工具脚本（diff 辅助 + 可观测性）

> **何时 Read**：`[PM]` 判车道、完成内部结构化判定、L1.5 派发 CR、TL 复盘时。
> 权威路由仍见 [CORE.md](../CORE.md) §PM 内部结构化判定。

## Git（可选）

- **有 Git**：`suggest-pipeline-lane.ps1` 可统计 diff；`diff_hint` 写入 PM 内部字段（**不得**仅凭 diff_hint 定 `lane`）。
- **无 Git**：不阻塞流水线；`diff_hint` 按 Mandatory / express-slice 文件数 + CORE §三车道手工填，无法确认则 `unknown`。
- 审查派发块写「变更文件列表」；有 git 时可附加 diff，**非必须**。

## diff 辅助（advisory）

有 plan-lite 时**优先**带 `-DocPath`（不依赖 git）：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/suggest-pipeline-lane.ps1 -DocPath "Assets/Doc/.../方案.md"
powershell -ExecutionPolicy Bypass -File .cursor/scripts/suggest-pipeline-lane.ps1 -DocPath "..." -Step "Step 1"
```

有 git 且无 DocPath 时（易误判脏工作区）：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/suggest-pipeline-lane.ps1
```

## 快照（三级 fallback）

PM 内部字段 **`snapshot`**：

| 值 | 含义 |
| --- | --- |
| **ok** | `append-pipeline-snapshot.ps1` 执行成功 |
| **manual** | 脚本失败，Agent 已 **Write** 追加 JSONL 一行到 `.cursor/pipeline-snapshot.log` |
| **n/a** | 首轮简单咨询 / 无车道变更且非 milestone（可省略快照） |

**禁止**伪造 `ok`。

### 1. 优先：脚本

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/append-pipeline-snapshot.ps1 -Event pm `
  -Lane Standard -ReviewTier L1.5 -NextRole planner -UserState 进行中 `
  -LaneRulesHit "3→Standard" -DiffHint Standard -ProjectContext loaded
```

| event | 触发 |
| --- | --- |
| `pm` | 每轮 PM 结构化输出后 |
| `recovery` | `按 CORE 重来` / `流水线重来` |
| `milestone` | 已定版 / 车道升级 / L1.5 CR 已派发 |

### 2. 脚本失败：手工 JSONL

用 Write **追加**一行（勿覆盖），格式见 [pipeline-snapshot-log.md](../templates/pipeline-snapshot-log.md)：

```json
{"ts":"2026-07-07T12:00:00+08:00","event":"pm","lane":"Standard","review_tier":"L1","next_role":"planner","user_state":"进行中","lane_rules_hit":"5","diff_hint":"Standard","project_context":"loaded","snapshot_source":"manual"}
```

YAML 标 **`snapshot: manual`**。

### 3. 可省略

纯问答、未派岗、无状态变化 → **`snapshot: n/a`**。

- 日志：`.cursor/pipeline-snapshot.log`（JSONL，本地可选；**勿提交**）
- TL 汇总（可选）：`.cursor/scripts/summarize-pipeline-metrics.ps1`
- **效果轻量版**（签收/结案一行）：`.cursor/pipeline-outcome.log` ← `append-pipeline-outcome.ps1`；汇总 `summarize-pipeline-outcome.ps1`（见 [retrospective-metrics.md](./retrospective-metrics.md) §效果轻量版）

## L1.5 CR 派发

见 [cr-dispatch-l1.5.md](../templates/cr-dispatch-l1.5.md) — PM **提示**用户新开 Chat，**不校验**。

## 用户提示（摘要）

独立审查（L1.5 CR / L2 / L3）：PM 在「你下一步」提示新开 Chat + 派发块；**不校验**是否新开或换模型。同 Chat 继续须标 **「非独立 CR」**。

## PM 自检（脚本相关）

- [ ] 有 plan-lite → `suggest-pipeline-lane.ps1 -DocPath`；无 git 仍可用 DocPath
- [ ] YAML 含 `diff_hint`、`readme`；`lane` 按 CORE §三车道判定
- [ ] 快照：`ok` → 或 Write JSONL → `manual` → 或 `n/a`（不得伪造 `ok`）
- [ ] L1.5 程序员完成 → 派发块 + **提示**用户新开 Chat
