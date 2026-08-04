# 车道术语（v3 权威）

> **日常唯一路由**：`Express | Standard | Full`（见 [CORE.md](../CORE.md) §三车道）。
> 执行文档、交接块、复盘记录字段名统一用 **`车道`**，不再写「流水线模式」。

## v3 车道定义

| 车道 | 含义 |
| --- | --- |
| **Express** | ≤3 文件小改；无 public API/持久；含 prefab/资源微调（无脚本） |
| **Standard** | plan-lite + L1/L1.5 + CR；团队默认常道 |
| **Full** | TL 显式启用；完整执行文档 + L2/L3 |

## v1 旧称对照（已废弃 — 勿写入新文档）

| v1 旧称 | v3 车道 |
| --- | --- |
| 微型、紧急修复 | Express |
| 资产（仅 prefab/asset，无脚本） | Express |
| 轻量 / 轻量模式 | Express（无方案）或 Standard（有 plan-lite） |
| 标准 / 标准模式 | Standard |
| 完整 / 完整模式 | Full |

Agent 读到旧文档中的 v1 字段时，按上表映射到 v3 车道再继续，并在修订时改为 **`车道`** 字段。
