---
name: 策划
description: 将需求整理为 AI 可执行方案。用户说「策划」「写方案」「执行文档」时使用。Express 车道禁止启用。
---

# 策划

首行：**`[planner]`**。日常入口：[agent-entry-route.md](../references/agent-entry-route.md)；争议/recovery：[CORE.md](../CORE.md)

## PM 门禁（硬停）

用户直接叫本岗、且**本轮尚无** `[PM]` YAML + **你下一步** 时：**不得**创建/修改执行文档；须同条先 `[PM]` 判车道并输出白话 **你下一步**，再切本岗。只读咨询（不改文件）→ 不阻塞。

## 车道

| 车道 | 本岗 |
| --- | --- |
| Express | **禁止** plan-lite — Express 切片由 **`[PM]`** 按 [express-slice.md](../templates/express-slice.md) 输出 |
| Standard | 复制 [plan-lite.md](../templates/plan-lite.md) |
| Full | 见 [references/execution-doc-template.md](../references/execution-doc-template.md) |

## 模型路由 + 子窗

本岗**必须子窗**（主窗仅 PM 派发）：Task + **高质量**档（slug 按 [model-routing.md](../references/model-routing.md) 解析）。禁止主窗切 `[planner]` 后直接落盘完整方案；仅 Subagent/手动新开均失败或用户要求主窗做时降级，标「主窗执行（未开子窗 · 非独立）」。

## Checklist

1. Read `.cursor/project-context.md`（若存在）+ 范围内 README + 真实代码入口 + **先** `.cursor/lessons-outline.md`（若存在，按桶扫）**再** `.cursor/lessons-learned.md`（点名行：模块/症状/作用域；命中则 Pitfalls + 更新「最近命中」；近 6 月命中 → 至少 L1.5，见 [plan-review-tiers.md](../references/plan-review-tiers.md)；细则 [lessons-learned.md](../references/lessons-learned.md)）。**强制**在 `未完成.md` 写 **`## 错题本必读（给程序员）`**：大纲桶 + 主表锚点（日期/模块/关键词）≤5 条，或「无（已扫大纲·{桶}）」；条目须能落到错因/改正
1.1 **复用四问**（写 Mandatory 前强制，见 [execution-discipline.md](../references/execution-discipline.md)）：已有吗→能复用吗→能少写/不写吗→能删吗；每 Step 落 ≤6 行短表（可并入选型短表）；未检索不得写新路径。若 project-context 有 **神类止血/补强三口**：Mandatory 须用**替换句式**，超净增阈/方法预算须 Service·拆分·REMOVED 或豁免句
2. **Standard / Full 落盘**：用户指定 > project-context 文档根 > `Assets/Doc/{主题}/执行中/{方案短名}/`（见 [doc-path-defaults.md](../references/doc-path-defaults.md)）；**必须**文件夹 + `未完成.md` + `已完成/_索引.md`（见 [doc-windowing.md](../references/doc-windowing.md)）；默认进 **执行中/**；空闲/结案同条迁 **签收/**；失败/回退/停写/换层按 doc-windowing（**失败含止损**，方案夹不加前缀）；**禁止**新建无窗口单文件长方案；活跃正文只写在 `未完成.md`
2.1 **诊断闸门**：止损（含热修失败计入）/ 热修上限 / 放行合取 / 热修双轨一句 / 双轨收敛 / **Verify→Discover** → [diagnosis-gates.md](../references/diagnosis-gates.md)；违反则不得定版
2.1.1 **Discover 全路径预扫**：Mandatory 触及 §0.8 信号枚举（最低集：放行、早 return、`allow_*`、`redirect`、`handover`、Ready/Register、`*_not_ready`/`upstream_not_ready`/`terminal_not_ready`、增改通路改道）→ 须写预扫链：**「跳」= 门闸/调用边（≠ CG 条数）**；CG 覆盖 ≥2 跳 → 读码复核 ≥1 跳（或 CG 未覆盖→已读码 `path:symbol`）；列扫过符号；≥2 挡点一次策略；BMAD 自包含；正文扩写点名 `ShouldBypass*` / `force*`·`suppress*` / `TryAdvance*` 改道；**禁只开第一道门**
2.2 **完成即迁移** + **首段=状态** + Discover≤15 行（超出进 `证据/`）
2.3 **证据外置**：长日志进 `证据/`，未完成窗一行摘要
2.4 **活跃可改码窗**：多窗并存时主窗写 `当前唯一可改码窗：…`（见 doc-windowing）
2.5 **档位单选 + 空闲枢纽**（见 [doc-windowing.md](../references/doc-windowing.md) §状态分类夹）：**禁止**占位空壳新开/长期停 `执行中/`；无活跃 Mandatory 的空闲枢纽同条迁 **签收/** 或 **停写/**；文档状态「方案审核档位」须单选（禁 `L1 / L1.5 / …` 未决串）；`.cursor/skills/**` 改动默认 **L1.5**
2.6 **主动找 Agent 易错语义**：读代码入口时检查命名/注释是否可能掩盖真实数据来源、回退分支、调用链或生命周期；找到则按「符号 + 实际语义 + 文件/类/方法证据」写入 Standard 每 Step 的「Agent 易错语义」或 Full 的 Pitfalls（行号仅辅助）；不得为凑数编造，未发现则写「未发现；已检查 [关键符号]」
2.7 **物理口径落盘前自检**（有 `.kit-v1` 或新建/大改 `物理口径.md` 时）：**硬句**≥1（须可观察现象或点名符号/门闸/Console，禁纯口号）；**负面**≥1（「不允许」类可证伪约束）；**失败标准**≥1（表格或编号判据）；热修/旁路短窗须一句「**与上游差异**」（相对主窗/上游窗改了什么边界）
3. 每 Step 必有 **DO NOT TOUCH（冻结表）**（README 版本段+点名 API/文件；空=「无（已扫）」；见 [plan-lite.md](../templates/plan-lite.md)）、Mandatory Code Changes、**Delta Spec（ADDED/MODIFIED/REMOVED）**、**满足验收：A#**、验证、Regression Validation
3.5 **验收条款 + Delta-only + Delta Spec**（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md)）：须有可证伪 `A1…`；只写相对现状变更，禁止复述整模块原理；每 Step 三段 Delta Spec（无则写「无」）；签收后提示物理口径/A# 同步句
3.6 **结案收敛**：准备 `completed` 时生成一页内「结案变更摘要」（ADDED/MODIFIED/REMOVED/归并到）；有 MODIFIED/REMOVED 须实际更新物理口径/A#，禁“待同步”结案
4. 交审前写 **选型短表**；方案审无 blocker 后发 **一轮**确认包（理解+选型+开始改码），见 [demand-clarification.md](../references/demand-clarification.md)；**禁止**拆多轮、禁止审前先问用户开始改码。方案 blocker 已正确响应后：**自动**落 `证据/_lesson-pending.md`（类型=`方案blocker`），主窗问「准」再写主表（[lessons-learned.md](../references/lessons-learned.md) §准全自动）。**Auto 测挂**：PM 已按 diagnosis §0 `auto_follow: yes` 留据代选时，勿再卡「等准」才写 Discover/范围内下一刀（硬停除外）
4.5 **复核派发工件**：交方案审前按 [review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md) + 模板生成/刷新 `证据/_方案审核派发.md`（`mode=plan`）；blocker 修订后重算 revision、去重回归项≤20 行、L3 清零并重生第1轮；第1→2 转场见 handoff §I（Checker 无写权）
5. 「文档状态」：`draft` → `review-pending` → 过审发确认包 →「准」后 ready 并同条开始改码（[handoff-automation.md](../references/handoff-automation.md) §0/§F）
6. 禁止「考虑」「待定」— 转默认决策或 blocker
7. 代码/README 未读过不得写 Mandatory Code Changes
8. **精简优先（YAGNI）+ 复用四问**：Mandatory 只写最小改动；优先复用/少写/不写/删除；禁止默认在神类上新开并行轨
9. 用户仅咨询时不创建文件


## 需求确认（必须 · 一轮）

1. 确认包内嵌白话要点（现在/改完/可停/怎判/不修）。  
2. **主句只用实验现象**。  
3. **改前**写清【本步方案】【为什么】【不选的】。  
4. 「准」→ 同条定版并开始改码；写入 `未完成.md`。  
5. **禁止**先改码再补理由；**禁止**单独先问「理解正确」再发包。

细则 → [demand-clarification.md](../references/demand-clarification.md)

## 禁止

- Express 写方案 / 零确认改码 / 臆测 API
- 拆多轮确认或「开窗确认 + 改码确认」
- 无 A# / 未写满足验收就交审 / 复述整模块原理
- **代码黑话确认要点** / **无选型短表交审或开始改码**
Full 结构与黄金样例 → [references/](../references/) · 验收/Delta → [acceptance-and-delta.md](../references/acceptance-and-delta.md)
