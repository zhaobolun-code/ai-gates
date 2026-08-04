# Full 车道决策树（TL 一页）

> **何时 Read**：CORE §三车道判定第 2 步存疑、用户说「完整流程」、或 Standard 范围持续膨胀时。
> **默认**：团队日常 **不主动 Full**；TL 显式启用或命中下列 **强制 Full** 时升档。

## 决策树

```text
开始：有代码改动需求
  │
  ├─ 用户/TL 明确说「完整流程」「Full」「要 L2/L3」？ ──是──→ Full
  │
  ├─ 跨 3+ 独立业务模块，或预计 >8 个业务文件？ ──是──→ Full
  │
  ├─ 涉及状态机 / 持久化 / 序列化 / 存档格式？ ──是──→ Full
  │
  ├─ 功能性改动 且 路径命中 project-context §Express 升级
  │     或 回归索引模块？ ──是──→ 非日志/注释类 → Full；仅日志/注释 → Standard + L1.5
  │
  ├─ 跨 2 个业务模块或涉及 public API？ ──是──→ Standard + L2（若继续膨胀再 Full）
  │
  └─ 否 ──→ Standard（plan-lite + L1/L1.5）或 Express（见 CORE §4）
```

## 强制 Full（任一即 Full）

| 条件 | 示例 |
| --- | --- |
| 跨 3+ 独立业务模块或 >8 业务文件 | `[ModuleA]` + `[ModuleB]` + `[ModuleC]` + 配置/存档大联动 |
| 状态机 / 持久 / 序列化 | 实验进度存档、设备状态跨场景 |
| 用户/TL 显式 Full | 「走完整流程」「要 L3 方案审核」 |
| 功能性 + 回归核心模块（非纯日志） | 改核心业务传递逻辑、影响多处联动的状态字段 |

## 不升 Full（常见误判）

| 情况 | 应走 |
| --- | --- |
| 只改 Debug 日志字符串 | Standard + **L1.5**（回归模块） |
| 单模块 ≤3 文件、无 API | **Express**（未命中升级表） |
| 跨 2 模块但无状态机/持久/核心回归 | **Standard + L2** |
| 已有 plan-lite、2～3 Step，且未命中第 2 步 Full 强制（含第 4 条功能性+回归模块） | **Standard**（不必 Full） |
| prefab 微调、无脚本 | **Express**（见 [lane-glossary.md](./lane-glossary.md)） |

## Full 车道附加要求（相对 Standard）

| 项 | Full | Standard |
| --- | --- | --- |
| 执行文档 | [execution-doc-template.md](./execution-doc-template.md) 全文 | [plan-lite.md](../templates/plan-lite.md) |
| 方案审核 | L2 / L3（PM 提示新开 Chat） | L1 / L1.5 |
| 代码审核 | L1.5 时 PM **提示**新开 Chat | L1.5 同 Chat 可继续（标非独立 CR） |
| CodeGraph | 无图谱 = **hard blocker** | 无图谱 = soft（须声明） |
| Step | 严格串行 + 交接块 | 建议串行 |

## TL 快速口令

- **维持 Standard**：「不用 Full，plan-lite 即可。」
- **跨 2 模块加强**：「Standard + L2，新开 Chat 方案审核可选。」
- **升 Full**：「走 Full，用 execution-doc-template。」
- **仅加强 CR**：「Standard + L1.5，新开 Chat CR。」（≠ Full）

## 相关

- 日常路由：[CORE.md](../CORE.md) §三车道判定
- 方案档位：[plan-review-tiers.md](./plan-review-tiers.md)
- git 辅助（不定 lane）：`.cursor/scripts/suggest-pipeline-lane.ps1`（有 plan-lite 时用 `-DocPath`）
