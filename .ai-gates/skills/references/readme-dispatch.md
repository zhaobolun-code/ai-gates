# README 派岗（Standard / Full）

> **何时 Read**：PM 填 YAML `readme` 字段、派 `[developer]` / `[docs]` 前。
> 权威路由：[CORE.md](../CORE.md) §PM 结构化输出。

PM 在 YAML 填 `readme`，按**实际改动**（有 git 用 diff，无 git 用 Mandatory / express-slice / 程序员交接文件列表）：

| 值 | 条件（满足**全部**） | 谁做 |
| --- | --- | --- |
| **skip** | Express 车道 | 可选：程序员一行版本；通常 skip |
| **dev-one-liner** | Standard/Full；**仅 1 个**业务 `.cs`（或 1 prefab/asset）；无新 public API；无新增回归场景；README 无需改结构/调试节 | `[developer]` 追加版本行 |
| **docs** | 任一：**≥2** 业务文件；新/改 public API；新增回归场景；须改 README 结构或「调试与回归」节 | `[docs]` |

边界模糊 → 默认 **docs**（宁可多写 README，不少写）。
