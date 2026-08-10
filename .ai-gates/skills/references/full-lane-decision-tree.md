# 车道决策树（TL 一页 · 四车道）

> **何时 Read**：CORE §四车道判定步骤 4 存疑、用户说「完整流程」、或 Standard 范围持续膨胀时。
> **默认**：团队日常 **不主动 Full**；TL 显式启用或命中下列 **强制 Full** 时升档。

## 决策树

```text
开始：有代码改动需求
  │
  ├─ 用户/TL 明确说「完整流程」「Full」「要 L2/L3」？ ──是──→ Full
  │
  ├─ 止损链（A#/口径复议、repair_rounds 触顶后仍改动）？ ──是──→ Full
  │
  ├─ 热度（lessons 近 6 个月 / heat≥medium / last_fail_ts）且大改
  │     （>3 文件 / 净增删 >~150 行 / 跨模块·API·持久）？ ──是──→ Full
  │
  ├─ 回归索引模块（或 §车道升级 禁入路径）且大改？ ──是──→ Full；
  │     小规模功能改动 → Standard + L1.5
  │
  ├─ 跨 3+ 独立业务模块，或预计 >8 个业务文件？ ──是──→ Full
  │
  ├─ 状态机涉及持久化 / 序列化 / 存档格式？ ──是──→ Full
  │
  ├─ 机械微改（Express 机械清单：仅字符串/注释/日志文本、编译错误修复（缺符号/类型不匹配，不重设计）、
  │     数字/常量/阈值 ≤3 行；≤2 业务源文件；无 API/持久/跨模块/生成文件；一句话说清；未命中热度/回归索引/止损链）？
  │     ──是──→ Express（一句话 A# + 升道出口）
  │
  ├─ 行为小改（≤3 文件、无 API/持久/跨模块）？ ──是──→ Direct（默认；对话内 A#/切片，不落盘）
  │
  ├─ 跨 2+ 业务模块 / public API / 裸状态机（无持久化/序列化）？ ──是──→ Standard + L2（若继续膨胀再 Full）
  │
  └─ 否 ──→ Standard（plan-lite + L1/L1.5/L2）
```

## 强制 Full（任一即 Full）

| 条件 | 示例 |
| --- | --- |
| 止损链 | A#/口径复议（diagnosis-gates §0.6/§0.7）、repair_rounds 触顶后仍改同一 A# |
| 热度（lessons 近 6 个月 / heat≥medium / last_fail_ts）且大改（>3 文件 / 净增删 >~150 行 / 跨模块·API·持久） | 热文件反复修复 + 整体重写 |
| 回归索引模块（或 §车道升级 禁入路径）且规模较大（>3 文件 / 净增删 >~150 行 / 跨模块·API·持久） | 改核心业务传递逻辑、影响多处联动的状态字段 |
| 跨 3+ 独立业务模块或 >8 业务文件 | `[ModuleA]` + `[ModuleB]` + `[ModuleC]` + 配置/存档大联动 |
| 状态机涉及持久化 / 序列化 | 实验进度存档、设备状态跨场景 |
| 用户/TL 显式 Full | 「走完整流程」「要 L3 方案审核」 |

## 不升 Full（常见误判）

| 情况 | 应走 |
| --- | --- |
| 只改 Debug 日志字符串 | **Express**（机械微改，未命中热度/回归索引/止损链） |
| 单模块 ≤2 文件、机械微改 | **Express**（未命中升级/热度） |
| 行为小改（≤3 文件、无 API/持久/跨模块） | **Direct**（默认直通道，不落盘） |
| 回归索引模块内小规模功能改动（≤3 文件、无 API/持久/跨模块） | **Standard + L1.5**（不取较高档；与文件/机器热度双命中 → 按热度入口取较高档：方案审 L3 / 双轮 CR） |
| 热度命中的 Standard 规模小改 | **Standard + 方案审 L3 / 双轮 CR**（热度命中取较高档，不整条升 Full） |
| 跨 2 模块但无状态机/持久/核心回归 | **Standard + L2** |
| 已有 plan-lite、2～3 Step，且未命中步骤 4 Full 强制 | **Standard**（不必 Full） |
| prefab 微调、无脚本 | **Express**（见 [lane-glossary.md](./lane-glossary.md)） |

## Full 车道附加要求（相对 Standard）

| 项 | Full | Standard |
| --- | --- | --- |
| 执行文档 | [execution-doc-template.md](./execution-doc-template.md) 全文 | [plan-lite.md](../templates/plan-lite.md) |
| 方案审核 | L2 / L3（PM 提示新开 Chat） | L1 / L1.5 / L2 |
| 代码审核 | L1.5 时 PM **提示**新开 Chat | L1.5 同 Chat 可继续（标非独立 CR） |
| CodeGraph | 无图谱 = **hard blocker** | 无图谱 = soft（须声明） |
| Step | 严格串行 + 交接块 | 建议串行 |

## TL 快速口令

- **判 Express**：「机械微改，走快车道。」（附一句话 A# + 升道出口）
- **判 Direct**：「行为小改，走直通道。」（对话内 A#/切片，不落盘）
- **维持 Standard**：「走标准道，不用 Full，plan-lite 即可。」
- **跨 2 模块加强**：「Standard + L2，新开 Chat 方案审核可选。」
- **升 Full**：「走 Full，用 execution-doc-template。」
- **仅加强 CR**：「Standard + L1.5，新开 Chat CR。」（≠ Full）

## 相关

- 日常路由：[CORE.md](../CORE.md) §四车道判定
- 方案档位：[plan-review-tiers.md](./plan-review-tiers.md)
- git 辅助（不定 lane）：`.cursor/scripts/suggest-pipeline-lane.ps1`（有 plan-lite 时用 `-DocPath`）
