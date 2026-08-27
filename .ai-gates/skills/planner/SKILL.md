---
name: planner
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
| Direct | 策划子窗在主窗对话内出 A#/切片，**不保存文档**（对话内切片 ≠ plan-lite 落盘，tmp 也不落）；跨会话/换窗/改不完自动升 Standard（落盘） |
| Standard | 复制 [plan-lite.md](../templates/plan-lite.md) |
| Full | 见 [references/execution-doc-template.md](../references/execution-doc-template.md) |

## 模型路由 + 子窗

本岗**必须子窗**（主窗仅 PM 派发）：Task + **高质量**档（slug 按 [model-routing.md](../references/model-routing.md) 解析）。禁止主窗切 `[planner]` 后直接落盘完整方案；仅 Subagent/手动新开均失败或用户要求主窗做时降级，标「主窗执行（未开子窗 · 非独立）」。

## Checklist

1. Read `.cursor/project-context.md`（若存在）+ 范围内 README + 真实代码入口 + **先** `.ai-gates/lessons-outline.md`（若存在，按桶扫）**再** `.ai-gates/lessons-learned.md`（点名行：模块/症状/作用域；命中则 Pitfalls + 更新「最近命中」；近 6 月命中 → 至少 L1.5，见 [plan-review-tiers.md](../references/plan-review-tiers.md)；细则 [lessons-learned.md](../references/lessons-learned.md)）。**强制**在 `未完成.md` 写 **`## 错题本必读（给程序员）`**：大纲桶 + 主表锚点（日期/模块/关键词）≤5 条，或「无（已扫大纲·{桶}）」；条目须能落到错因/改正
1.1 **复用四问**（写 Mandatory 前强制，见 [execution-discipline.md](../references/execution-discipline.md)）：已有吗→能复用吗→能少写/不写吗→能删吗；每 Step 落 ≤6 行短表（可并入选型短表）；未检索不得写新路径。若 project-context 有 **神类止血/补强三口**：Mandatory 须用**替换句式**，超净增阈/方法预算须 Service·拆分·REMOVED 或豁免句
1.2 **设计模式一问（扫症状）**：写 Mandatory 前扫 [design-patterns.md](../references/design-patterns.md) 词条表「触发症状」列。命中 → 强制选型句（有成熟实例复用 / 无则人类模式配方 / State·Policy·Seam 无锚点不采用）；禁止因无化学仓路径写成不采用。未命中 → 字面 `本步不采用 design-patterns 词条`。显式采用或不采用；禁止优先套用；无症状不得新抽象（YAGNI）。主窗派发不得预填采用/不采用结论；扫症状由本岗完成。细则 [execution-discipline.md](../references/execution-discipline.md) §设计模式一问
2. **Standard / Full 落盘（Direct 除外：对话内 A#/切片，不落盘）**：用户指定 > project-context 文档根 > `.ai-gates/Doc/{主题}/执行中/{方案短名}/`（见 [doc-path-defaults.md](../references/doc-path-defaults.md)）；**必须**文件夹 + `未完成.md` + `已完成/_索引.md`（见 [doc-windowing.md](../references/doc-windowing.md)）；默认进 **执行中/**；空闲/结案同条迁 **签收/**；失败/回退/停写/换层按 doc-windowing（**失败含止损**，方案夹不加前缀）；**禁止**新建无窗口单文件长方案；活跃正文只写在 `未完成.md`
2.1 **诊断闸门**：止损（含热修失败计入）/ 热修上限 / 放行合取 / 热修并行实现一句 / 并行实现收敛 / **Verify→Discover** → [diagnosis-gates.md](../references/diagnosis-gates.md)；违反则不得定版
2.1.1 **Discover 全路径预扫**：Mandatory 触及 §0.8 信号枚举（最低集：放行、早 return、`allow_*`、`redirect`、`handover`、Ready/Register、`*_not_ready`/`upstream_not_ready`/`terminal_not_ready`、增改通路改道）→ 须写预扫链：**「跳」= 门闸/调用边（≠ CG 条数）**；CG 覆盖 ≥2 跳 → 读码复核 ≥1 跳（或 CG 未覆盖→已读码 `path:symbol`）；列扫过符号；≥2 门闸一次策略；BMAD 自包含；正文扩写点名 `ShouldBypass*` / `force*`·`suppress*` / `TryAdvance*` 改道；**禁只开第一道门**
2.2 **完成即迁移** + **首段=状态** + Discover≤15 行（超出进 `证据/`）
2.3 **证据外置**：长日志进 `证据/`，未完成窗一行摘要
2.4 **活跃可改码窗**：多窗并存时主窗写 `当前唯一可改码窗：…`（见 doc-windowing）
2.5 **档位单选 + 空闲枢纽**（见 [doc-windowing.md](../references/doc-windowing.md) §状态分类夹）：**禁止**占位空壳新开/长期停 `执行中/`；无活跃 Mandatory 的空闲枢纽同条迁 **签收/** 或 **停写/**；文档状态「方案审核档位」须单选（禁 `L1 / L1.5 / …` 未决串）；`.cursor/skills/**` 改动默认 **L1.5**
2.6 **主动找 Agent 易错语义**：读代码入口时检查命名/注释是否可能掩盖真实数据来源、回退分支、调用链或生命周期；找到则按「符号 + 实际语义 + 文件/类/方法证据」写入 Standard 每 Step 的「Agent 易错语义」或 Full 的 Pitfalls（行号仅辅助）；不得为凑数编造，未发现则写「未发现；已检查 [关键符号]」
2.7 **物理口径落盘前自检**（有 `.kit-v1` 或新建/大改 `物理口径.md` 时）：**硬句**≥1（须可观察现象或点名符号/门闸/Console，禁纯口号）；**负面**≥1（「不允许」类可证伪约束）；**失败标准**≥1（表格或编号判据）；热修/旁路短窗须一句「**与上游差异**」（相对主窗/上游窗改了什么边界）
2.8 **共享语言 + 架构体检（可选）**：方案内术语歧义/同义异名 → 按 [shared-language.md](../references/shared-language.md) 登记或改判，禁止两套叫法并行；Full 策划前可选跑 [architecture-health-check.md](../references/architecture-health-check.md)（CRG 只读概览）并入方案
2.9 **先原型后定案（可选）**：设计问题纸上难定案时，可「先原型后定案」（引用 [references/prototype.md](../references/prototype.md)），不改变策划主流程
3. 每 Step 必有 **DO NOT TOUCH（冻结表）**（README 版本段+点名 API/文件；空=「无（已扫）」；见 [plan-lite.md](../templates/plan-lite.md)）、Mandatory Code Changes、**Delta Spec（ADDED/MODIFIED/REMOVED）**、**满足验收：A#**、验证、Regression Validation
3.5 **验收条款 + Delta-only + Delta Spec**（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md)）：须有可证伪 `A1…`；只写相对现状变更，禁止复述整模块原理；每 Step 三段 Delta Spec（无则写「无」）；签收后提示物理口径/A# 同步句
3.6 **结案收敛**：准备 `completed` 时生成一页内「结案变更摘要」（ADDED/MODIFIED/REMOVED/归并到）；有 MODIFIED/REMOVED 须实际更新物理口径/A#，禁“待同步”结案
4. 交审前写 **选型短表**；方案审无 blocker 后发 **一轮**确认包（理解+选型+开始改码），见 [demand-clarification.md](../references/demand-clarification.md)；**禁止**拆多轮、禁止审前先问用户开始改码。方案 blocker 已正确响应后：**自动**落 `证据/_lesson-pending.md`（类型=`方案blocker`），主窗问「准」再写主表（[lessons-learned.md](../references/lessons-learned.md) §准全自动）。**Auto 测挂**：PM 已按 diagnosis §0 `auto_follow: yes` 留据代选时，勿再卡「等准」才写 Discover/范围内下一刀（硬停除外）
4.01 **跨项目出口**：收集仓已开通（[collect-queue.md](../references/collect-queue.md)）；未登录时默认本地队列。未验证 `gh auth status` 成功时禁止方案写「本机已登录/已开 PR」。允许写「收集仓已开通」。
4.05 **分歧标注（默认不启用）**：跨模块/高危/止损/用户点名分歧实验时，方案 `未完成.md` 或 Mandatory 须声明是否启用分歧标注；启用则按 [divergence-annotation.md](../references/divergence-annotation.md) 派两个隔离槽，对照由派发方写；默认 **不启用**
4.06 **完整碰撞（默认不启用）**：完整碰撞默认不启用；启用须点名 [collision-review.md](../references/collision-review.md)（异模型三轮；轮0 产出可引用共识地基三句；轮1 Grok 构建者×Sonnet 红队且开头引用地基；短清单主窗机械拼装；轮2/3 引用原文只投票；禁止同模型双链）。不得把 diverge 填成碰撞。止损触顶/将到 2/3 或热度爆炸时由 PM 在确认包**提示**可选碰撞，策划不得自行开跑。
4.07 **跨会话续作**：续作前按 [long-task.md](../references/long-task.md) 核感知/卡住；命中停点先确认包，禁止静默续改码。
4.08 **覆盖度**：若引用覆盖度，必须来自 `.ai-gates/coverage-map.yaml` 或刚跑的 `compute-coverage-map.ps1` 输出；禁止自报百分比。
4.09 **逆链（默认不启用）**：高危 / 止损 / 用户点名「逆链」时，方案 `未完成.md` 或 Mandatory **须声明是否启用**逆链；默认 **不启用**；节点=选型短表**行**；禁止第四张逻辑节点表。点名 [reverse-chain.md](../references/reverse-chain.md)。三格【本步方案】【为什么】【不选的】=判断当时的连接（依据→判断→不选），禁止交审散文补 why。
4.10 **归档总结（逆向总结典故）**：归档总结默认**不在执行中跑**；仅结案归档（`completed`/失败封存+migrate）且有改前选型三格才触发；无三格跳过；空闲枢纽迁签收不跑；**禁止与 4.09 逆链混称**。点名 [reverse-allusion.md](../references/reverse-allusion.md)。
4.11 **模式沉淀**（生产侧）。可晋升时（签收/`runtime-validated` 抽出可复用结构且对仓三档=有真锚点；CR 发现未入表真锚点；用户点名「模式沉淀」；归档逆向总结卡已有本仓锚点）**自动**落 `证据/_pattern-pending.md`；主窗只问「准否」；禁止静默入表；禁止塞进 `_lesson-pending.md`。Express / 空闲枢纽默认不跑。不是岗。点名 [pattern-harvest.md](../references/pattern-harvest.md)。
4.12 **电路子窗**。写 ≥2 Step 契约前答电路一问；能并则并；阻塞边必填「串联 / 并联」+ 路径集。单 Step / Express / Direct 对话内切片：字面 `无（单步·不跑电路）`。不是岗。点名 [circuit-windows.md](../references/circuit-windows.md)。
4.13 **本地自进化环**。项目格已「准」→ 去上下文化 → collect-queue `shareable` → 抽象 → 须「准」才入通用格。禁止静默入通用格。未验证 `gh auth status` 成功时禁止方案写「本机已登录/已开 PR/技能包已下发」。不是岗。点名 [pattern-harvest.md](../references/pattern-harvest.md) §Skill 自进化。
4.14 **GitHub 收集仓**。收集仓已开通（[collect-queue.md](../references/collect-queue.md) §gh）；公开仓 `zhaobolun-code/ai-gates-collect`；上传 = 开分支 + **PR**（不需要合并权限）；合并须维护者权限。「准」不触发 `gh pr create` / `gh issue create`。本机 `gh auth status` exit 0 且独立口令「上传」才开 PR。未探测成功禁止方案写「本机已登录/已开 PR/已下发」；允许写「收集仓已开通」。不是岗。回传手续见 4.15。
4.15 **Skill 回传**。点名 [pattern-harvest.md](../references/pattern-harvest.md) §Skill 自进化：下发=「项目经理 升级 ai-gates」或 `PM upgrade ai-gates` 拉 `zhaobolun-code/ai-gates`，不是拉 collect 仓、不是再开 PR；收集仓合并 ≠ 已下发；入通用格须另「准」。不是岗。本窗不执行升级、不执行 gh create。
4.5 **复核派发工件**：交方案审前按 [review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md) + 模板生成/刷新 `证据/_方案审核派发.md`（`mode=plan`）；blocker 修订后重算 revision、去重回归项≤20 行、L3 清零并重生第1轮；第1→2 转场见 handoff §I（Checker 无写权）
5. 「文档状态」：`draft` → `review-pending` → 过审发确认包 →「准」后 ready 并同条开始改码（[handoff-automation.md](../references/handoff-automation.md) §0/§F）；给程序员当前 Step 必须抄文档状态 **当前 Step**（`check-pipeline-doc` 交叉核对，不一致只 warn）
6. 禁止「考虑」「待定」— 转默认决策或 blocker
7. 代码/README 未读过不得写 Mandatory Code Changes
8. **精简优先（YAGNI）+ 复用四问**：Mandatory 只写最小改动；优先复用/少写/不写/删除；禁止默认在神类上新开并行实现
9. 用户仅咨询时不创建文件


## 需求确认（必须 · 一轮）

1. 确认包内嵌白话要点（现在/改完/可停/怎判/不修）。  
2. **主句只用实验现象**。  
3. **改前**写清【本步方案】【为什么】【不选的】。  
4. 「准」→ 同条定版并开始改码；写入 `未完成.md`。  
5. **禁止**先改码再补理由；**禁止**单独先问「理解正确」再发包。

细则 → [demand-clarification.md](../references/demand-clarification.md)；需求未定 / 大需求 / 多次澄清仍分歧 → 先按其中 **grill 访谈** 节一次一问澄清，分支穷尽再写切片；「准」确认仍只 1 轮

## 禁止

- Express 写方案 / 零确认改码 / 臆测 API
- 拆多轮确认或「开窗确认 + 改码确认」
- 无 A# / 未写满足验收就交审 / 复述整模块原理
- **代码黑话确认要点** / **无选型短表交审或开始改码**
Full 结构与黄金样例 → [references/](../references/) · 验收/Delta → [acceptance-and-delta.md](../references/acceptance-and-delta.md)
