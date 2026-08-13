# 流水线复盘指标（可选）

> 非门禁文件。团队可按 sprint 或里程碑填写，用于改进 Skill 与执行文档质量。

## 效果轻量版（推荐默认）

> **目标**：结案/签收自动记一行；月末看一次通过率与平均几次才过——**不**做完整看板。  
> 日志：`.ai-gates/pipeline-outcome.log`（gitignore）· 模板 [pipeline-outcome-log.md](../templates/pipeline-outcome-log.md)

### 每窗兑现清单（主窗 PM 必勾 · 缺项=未兑现）

| # | 机制 | 命中标准 |
| --- | --- | --- |
| 1 | 主窗仅 PM | 策划/方案审/实现/CR/文档均子窗；否则标「主窗执行（未开子窗 · 非独立）」 |
| 2 | 模型路由 | 档位：策划/审核≈高质量、实现≈便宜快速；slug 以 project-context 为准（失败 `inherit` 须标注） |
| 3 | 测挂 → L0 | `未完成.md` 有 `## 错题 L0`；未偷写主表 |
| 4 | 可晋升 → pending | 有 `证据/_lesson-pending.md`，或写明「根因未证暂不升」 |
| 5 | 签收/挂起 → outcome | `pipeline-outcome.log` 本窗有一行 |
| 6 | 审核隔离 | L1.5/L3/CR 标注隔离复核；`stale_dispatch` 须重生派发 |

挂起/结案/`你下一步` 交接时可附一行：`兑现：1✅ 2✅ …`（缺则写 ❌+原因）。  
半页可复制模板 → [USER-GUIDE.md](../../USER-GUIDE.md) §半页备忘 · [window-fulfillment-halfpage.md](../templates/window-fulfillment-halfpage.md)。

### outcome 命令

| 动作 | 命令 |
| --- | --- |
| 签收一次过 | `append-pipeline-outcome.ps1 -Event step_pass -Doc "…" -Lane Full -RoundsToPass 1 -WhyMulti none` |
| 多次才过 | 同上加 `-MultiAttempt -RoundsToPass N -VerifyFails (N-1) -WhyMulti dual_track`（或 spec_drift/semantic/scope/…） |
| 月末/「效果汇总」 | `summarize-pipeline-outcome.ps1 -LastDays 30` |

触发接线 → [handoff-automation.md](./handoff-automation.md) §F。脚本失败不阻塞签收。

### 用数据改规则（每次只改一条）

跑 summarize 后看 `why_multi` Top1 → 按下表改**一条**（改完下窗验证，禁止顺手堆 checklist）：

| Top `why_multi` | 优先改 |
| --- | --- |
| `dual_track` | 并行实现一句 / 方案审必检 |
| `semantic` | 易错语义 + CR 反推 |
| `spec_drift` | diagnosis §0.5 先改口径 |
| `scope` | `diagnosis-gates` §0.3 异现象行（已落地）：挂起+另开短窗，禁并修/误烧止损 |
| `test_method` | 验证步骤/关键词写清 |
| `first_pass` 低且 CR 常 0 blocker | 再考虑业务审严一档（另议） |

质量趋势停点见 [long-task.md](./long-task.md) §感知；以 `summarize-pipeline-outcome.ps1` 输出为准，禁止模型自报覆盖本脚本。

## 何时填写（完整复盘模板，仍可选）

- 一个执行文档进入 `completed(已归档)` 后
- 或用户说「流水线复盘」时由 `项目经理` 引导
- sprint 末汇总 **`.ai-gates/pipeline-recovery-log.md`**（若存在）与 **outcome** 汇总

## 流水线恢复度量（v3.1.3）

用户触发 `按 CORE 重来` / `流水线重来` 时，Agent 在 CORE §Agent 失败模式 第 7 步追加 **recovery 表** + **`append-pipeline-snapshot.ps1 -Event recovery`**。

**记录位置**：

- `.ai-gates/pipeline-recovery-log.md`（人类可读）— 模板 [pipeline-recovery-log.md](../templates/pipeline-recovery-log.md)
- `.ai-gates/pipeline-snapshot.log`（JSONL 全量 PM 轨迹）— 模板 [pipeline-snapshot-log.md](../templates/pipeline-snapshot-log.md)
- TL 汇总：`.cursor/scripts/summarize-pipeline-metrics.ps1`

### 恢复偏差类型（枚举）

| 类型 | 说明 |
| --- | --- |
| `缺 PM 结构化输出` | 无 YAML 或 lane 未声明；Express 简略轮缺 **你下一步** 亦算 |
| `跳过 L1/L1.5` | Standard 未方案审核即开发 |
| `同 Chat L1.5 CR` | （可选记录）L1.5 未提示新开 Chat，或同 Chat 未标「非独立 CR」 |
| `Express 你下一步过薄` | Express 简略轮缺车道/下一岗/五态/动作任一项 |
| `缺 Express 切片` | Express 无 express-slice 即 developer |
| `缺 Express 自检` | Express 完成无 express-self-check |
| `夸大证据等级` | 未 Unity 测却标已通过/runtime-validated |
| `Express 应升级` | 命中升级表仍维持 Express |
| `缺 project-context` | 冷启动下误走 Express 或臆测路径 |
| `一次多 Step` | 超出当前 Step/切片范围 |
| `PM 替岗` | PM 直接写代码或替 CR 宣布无 blocker |
| `其他` | 备注栏说明 |

### Sprint 汇总模板（TL 可选）

```markdown
## 流水线恢复汇总 — [sprint/日期区间]

- 恢复触发次数：
- 高频偏差（Top 3）：
  1.
  2.
  3.
- 拟修订项（CORE / SKILL / project-context）：
```

将汇总 append 到执行文档「实施记录」、团队 wiki，或 CHANGELOG Notes。

## 记录模板

```markdown
## 流水线复盘 — [执行文档主题] — [日期]

### 概况
- 车道：
- Step 总数 / 已完成：
- 总耗时（可选，小时）：
- 派岗轮次（PM → 各岗合计，可选）：

### 打回与 blocker
| 阶段 | blocker 次数 | 打回次数 | 典型类型（对齐/边界/验证缺口/方案缺陷） |
| --- | --- | --- | --- |
| 方案审核 | | | |
| 代码审核 | | | |

**量化汇总（v1.6.0 可选）**

- blocker 合计：
- 打回合计：
- 从 `implementation-ready` 到 `runtime-validated` 的 Step 数：
- 是否触发模式升级（标准→完整等）：是 / 否

### 证据等级轨迹
- 最高到达等级：claimed / static-checked / locally-validated / runtime-validated
- 未验证项是否收口：是 / 否

### 回归索引同步（可选人工跟踪，v1.5.1）

- 本周期内「新增回归场景」是否均已写入 `project-context.md`：是 / 否 — 遗漏项：

### 改进项（最多 3 条）
1.
2.
3.
```

## 用法

- 将填写结果 append 到执行文档「实施记录」末尾，或团队 wiki；**不修改**各 SKILL 正文。
- `策划` 修订模板时参考高频 blocker 类型，补 Pitfalls 与 Regression Validation。
