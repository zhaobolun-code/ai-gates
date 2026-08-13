# 长期任务感知 + 最小调度

> 一文件两节。感知复用已有 outcome 与止损字面；调度只做入口卡住检测。  
> **不是**：覆盖度表、完整碰撞、收集仓、第二套编排。01-D 定时编排仍搁置。

## 感知

检查时机与 §调度最小相同：PM / 策划入口加载本文件（model-invoked）。

| 信号 | 机器源 | 触发（写死） | 不触发 |
| --- | --- | --- | --- |
| 质量趋势 | `.ai-gates/pipeline-outcome.log` + `summarize-pipeline-outcome.ps1 -LastDays 14` | 脚本打印 `rows`≥4 **且** `first_pass_rate` 低于 50% | 日志缺失（脚本 exit 0 打印 `missing`）；`rows` 少于 4；未打印 `first_pass_rate` |
| 资源·止损将到 2/3 | `diagnosis-gates.md` 硬停字面「止损将到 2/3」 | 命中该字面 | 模型说「做太久了」 |
| 资源·max_repair_rounds | `diagnosis-gates.md` / loop-engineering `max_repair_rounds`（fuse） | 命中该 fuse 字面 | 另造数字或换算公式；把两条斜杠混成一条 |
| 目标漂移 | outcome 已有字段 `doc` 匹配当前窗 **且** `why_multi=spec_drift` | 同窗 `spec_drift` ≥2 | 单次（仍走 diagnosis-gates §0.5）；模型口头「漂了」 |

`repair_rounds` / `stop_count` 可作对照，不是第二套阈值。感知源**不含** heat / `compute-failure-heat.ps1`。以 summarize 打印为准，禁止模型自报覆盖脚本。

停点（感知命中）：停改码 + 确认包（[demand-clarification.md](./demand-clarification.md) 一轮）。**不**自动改 A#。

## 调度最小

- **不做**编排循环、定时器、计划任务、自跑 Agent。
- **卡住**：文档状态 ∈ `implementation-ready` / `in-progress` **且** outcome 已有字段 **`doc`**（路径或短名）匹配当前窗的行，按 `ts` 计 7 天无新行。
- 无匹配 `doc` 行时 **不得**口头判卡住（缺字段 ≠ 卡住）。
- **何时检查**：PM / 策划入口加载本文件（model-invoked），不是定时器。
- **停点**：停改码 + 确认包。Express·Direct 机械前置仍可；方案确认、验收 A#、Unity 未测不标通过 **不可**授权给机器。
- **禁止**把状态迁到 `runtime-validated`；**禁止**把 `event=step_pass` 当成 Unity 通过。

## 禁止

- 模型自报趋势 / 卡住 / 漂了 / 做太久了，而不读 summarize 输出或 outcome 日志
- 对账不用已有字段 `doc`，或发明未列字段
- 把 heat 当本窗感知触发源
- 另造 fuse 数字、止损换算公式，或把「止损将到 2/3」与 `max_repair_rounds` 斜杠混成一条
- 拆成第二份完整编排；新增 cron / schtasks / 自跑脚本
- 用 `validate-pipeline.ps1` / `check-pipeline-doc.ps1` 绿单独冒充「无 cron / 无计划任务」
- 调度层把状态迁到 `runtime-validated` 或把验收/Unity 标通过
- 感知命中或卡住后静默续改码、自动改 A#
