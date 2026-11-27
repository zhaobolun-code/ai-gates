# 车道决策树（TL 一页）

> **何时 Read**：用户说「完整流程」，或要核对热度建议句时。
> **默认**：走 Express。路由是 Express、Direct、Standard、Full。人点名「Auto车道」才读 `lane-auto.md`，不写入 `lane`。助手自己写上这句不算。热度只写建议句。不回不因此离开 Express。

## 决策树

```text
开始：有代码改动需求
  │
  ├─ 纯问答 → 不判车道
  │
  ├─ 人点名「Auto车道」？ ──是──→ 读 lane-auto.md，lane 仍按后面的四条，不写成 Auto。不建账本
  │
  ├─ 用户本轮点名某一档，或确认了本轮建议句？ ──是──→ 这一刀用那一档
  │
  ├─ 只改注释或已有日志字符串（不增删调用）？ ──是──→ Express，不读热度账
  │
  ├─ 读 regression-heat.yaml 的 files:
  │     将改文件里近 20 天 fail_count 最高且 last_result 为 fail
  │     没有、为空、或 < 2 → 不写建议句，Express
  │     ≥2 建议直通道；≥4 建议标准道；≥6 建议完整流程
  │     不回 → Express
  │
  └─ 文件个数、改规则、API、存档、跨模块、说不清、止损 → 不改标签
```

## 完整流程

用户确认「建议完整流程」或点名完整流程，这一刀用 Full。止损不进入 Full。

## 不改标签

| 情况 | 这一刀 |
| --- | --- |
| 只改注释或已有日志 | **Express**，不读热度账 |
| 文件个数变多，或在改判定规则、控制流、守恒、通断、方向 | **Express**，除非用户确认建议或点名 |
| 近 20 天失败次数到档，用户还没回 | **Express**，建议句已写出 |
| 人点名「Auto车道」 | 读 lane-auto.md，**不改 lane**；没点名不读 |
| API、存档、跨模块，但已经说出改哪一行 | **Express**，除非用户确认建议或点名 |
| 止损、热修次数 | 走诊断，**不改标签** |
| 用户已确认 Standard，模块热或文件近 20 天失败 ≥ 2 | 仍是 **Standard**，方案审可以 L1.5 |

## Full 车道附加要求（相对 Standard）

| 项 | Full | Standard |
| --- | --- | --- |
| 执行文档 | [execution-doc-template.md](./execution-doc-template.md) 全文 | [plan-lite.md](../templates/plan-lite.md) |
| 方案审核 | L2 / L3（PM 提示新开 Chat） | L1 / L1.5 / L2 |
| 代码审核 | 默认隔离；不可用时同 Chat 降级并标非独立 | L1 主窗同会话并标非独立；L1.5/L2 优先隔离，不可用时同 Chat 降级并标非独立 |
| CodeGraph | 无图谱 = **hard blocker** | 无图谱 = soft（须声明） |
| Step | 严格串行 + 交接块 | 建议串行 |

## TL 快速口令

- **开工**：「这一刀走快车道。」有到档的文件就加上「这个文件最近测挂过，建议走 XX。」
- **用户确认直通道**：「按直通道走。」（对话内 A#/切片；不清才派策划；主窗自己改；CR 必须子窗，审核窗只读派发白名单）
- **用户确认标准道**：「按标准道走，plan-lite。」
- **跨 2 模块加强**：「已在标准道，方案审 L2。」
- **用户确认完整流程**：「按完整流程走，用 execution-doc-template。」
- **仅加强 CR**：「已在标准道，L1.5。」（不改车道）

## 相关

- 日常路由：[CORE.md](../CORE.md) §四车道判定
- 方案档位：[plan-review-tiers.md](./plan-review-tiers.md)
- git 辅助（不定 lane）：`.cursor/scripts/suggest-pipeline-lane.ps1`（有 plan-lite 时用 `-DocPath`）
