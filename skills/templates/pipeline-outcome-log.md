# 流水线效果日志（轻量 · 项目专属）

> **位置**：`.cursor/pipeline-outcome.log`（JSONL；已 `.gitignore`，勿提交）  
> **追加**：`.cursor/scripts/append-pipeline-outcome.ps1`  
> **汇总**：`.cursor/scripts/summarize-pipeline-outcome.ps1`  
> **权威说明**：[references/retrospective-metrics.md](../references/retrospective-metrics.md) §效果轻量版

## 何时追加（一行一事）

| 时机 | 谁 |
| --- | --- |
| 用户「测试通过」且本窗/本 Step 迁 `runtime-validated` | 主窗 PM **同条自动** append |
| 方案夹迁 `completed` / 签收结案 | 主窗 PM **同条自动** append（若本窗尚未因签收写过，补一行；可 `event=close`） |
| 止损封存进失败夹 | 主窗 PM append，`first_pass=false`，`why_multi` 填主因 |

失败则手工 Write 一行 JSON（勿阻塞签收）。

## 字段（尽量少）

| 字段 | 说明 |
| --- | --- |
| `ts` | ISO 时间 |
| `event` | `step_pass` / `close` / `stop_fail` |
| `doc` | 方案夹相对路径或短名 |
| `lane` | Express / Standard / Full |
| `steps` | 本窗 Step 数（整数） |
| `repair_rounds` | 交审修复轮次（整数，无则 0） |
| `verify_fails` | 本窗累计测挂次数（整数） |
| `rounds_to_pass` | 几次 Verify 才过（含最后一次成功；一次过=1） |
| `first_pass` | 是否一次 Verify 即过（bool；脚本默认 true，多次用 `-MultiAttempt`） |
| `why_multi` | `none` / `spec_drift` / `dual_track` / `semantic` / `test_method` / `scope` / `other` |
| `stop_count` | 止损原文如 `2/3`（可选字符串） |
| `note` | ≤80 字（可选） |

`why_multi`：仅当 `first_pass=false` 时必填；一次过填 `none`。
