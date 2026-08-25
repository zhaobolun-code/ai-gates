# 车道决策树（TL 一页 · 四车道）

> **何时 Read**：CORE §四车道判定步骤 4 存疑、用户说「完整流程」、或 Standard 范围持续膨胀时。
> **默认**：PM **默认直通道**。团队日常 **不主动 Full**。止损两段：快/直通第一次止损 → Standard；**已在 Standard 再止损**才 Full。

## 决策树

```text
开始：有代码改动需求
  │
  ├─ 用户/TL 明确说「完整流程」「Full」「要 L2/L3」？ ──是──→ Full
  │
  ├─ 当前已是 Standard，且再次命中止损（A#/口径复议、repair_rounds 触顶后仍改动）？
  │     ──是──→ Full
  │
  ├─ 机械微改（恰好 1 个业务源文件；仅字符串/注释/日志文本、编译错误修复、
  │     数字/常量/阈值 ≤3 行；无 API/持久/跨模块/生成文件；一句话说清）？
  │     ──是──→ Express（有行为即使 1 文件 → Direct。回归索引/热度/路径前缀不否决）
  │
  ├─ 有行为变化，或机械但已是 2～3 个文件；≤3 文件；无 API/持久/跨模块？
  │     ──是──→ Direct（PM 默认；对话内 A#/切片，不落盘；跨会话/改不完升 Standard）
  │
  ├─ Express/Direct 第一次命中止损？ ──是──→ Standard
  │
  ├─ >3 文件 / 跨模块 / public API / 持久或序列化 / 说不清？ ──是──→ Standard
  │     （跨 2 模块 → Standard + L2；已判 Standard 且回归/热度 → 加强审，不改车道）
  │
  └─ 否 ──→ Standard（plan-lite + L1/L1.5/L2）
```

## 强制 Full（任一即 Full）

| 条件 | 示例 |
| --- | --- |
| 用户/TL 显式 Full | 「走完整流程」「要 L3 方案审核」 |
| **已在 Standard 上再次止损** | A#/口径复议（diagnosis-gates §0.6/§0.7）、repair_rounds 触顶后仍改同一 A#，且当前车道已是 Standard |

禁止仅因路径前缀、回归索引、>3 文件、存档、跨模块、或 Express/Direct 第一次止损就 Full（这些走 Standard）。

## 不升 Full（常见误判）

| 情况 | 应走 |
| --- | --- |
| 只改 Debug 日志字符串（恰好 1 个 `.cs`） | **Express**（机械微改。回归索引不否决） |
| 机械微改但已是 2～3 个文件 | **Direct** |
| 有行为变化即使 1 个文件（无 API/持久/跨模块） | **Direct**（快车道无代码审） |
| 行为小改（≤3 文件、无 API/持久/跨模块），含回归索引模块 | **Direct**（默认直通道，不落盘；PM 可改判 Standard） |
| 热度命中但仍属机械/行为小改 | **维持 Express / Direct**；PM 可改判 Standard |
| >3 文件 / 跨模块 / API / 存档 | **Standard**（跨 2 模块另加 L2） |
| Express/Direct 第一次止损 | **Standard**（不是 Full） |
| 已有 plan-lite、2～3 Step，且未在 Standard 上再止损 | **Standard**（不必 Full） |
| prefab 微调、无脚本、恰好 1 个资源文件 | **Express**（见 [lane-glossary.md](./lane-glossary.md)） |

## Full 车道附加要求（相对 Standard）

| 项 | Full | Standard |
| --- | --- | --- |
| 执行文档 | [execution-doc-template.md](./execution-doc-template.md) 全文 | [plan-lite.md](../templates/plan-lite.md) |
| 方案审核 | L2 / L3（PM 提示新开 Chat） | L1 / L1.5 / L2 |
| 代码审核 | L1.5 时 PM **提示**新开 Chat | L1.5 同 Chat 可继续（标非独立 CR） |
| CodeGraph | 无图谱 = **hard blocker** | 无图谱 = soft（须声明） |
| Step | 严格串行 + 交接块 | 建议串行 |

## TL 快速口令

- **判 Express**：「机械微改，仅 1 个文件，走快车道。」（附一句话 A# + 升道出口）
- **判 Direct**：「默认直通道。」（对话内 A#/切片，不落盘）
- **维持 Standard**：「走标准道，不用 Full，plan-lite 即可。」
- **跨 2 模块加强**：「Standard + L2，新开 Chat 方案审核可选。」
- **升 Full**：「走 Full，用 execution-doc-template。」（仅用户点名，或标准上再止损）
- **仅加强 CR**：「Standard + L1.5，新开 Chat CR。」（≠ Full；仅已判 Standard）

## 相关

- 日常路由：[CORE.md](../CORE.md) §四车道判定
- 方案档位：[plan-review-tiers.md](./plan-review-tiers.md)
- git 辅助（不定 lane）：`.cursor/scripts/suggest-pipeline-lane.ps1`（有 plan-lite 时用 `-DocPath`）
