---
name: plan-reviewer
description: 审核执行文档可执行性。用户说「方案审核」「审方案」时使用。Express 跳过。
---

# 方案审核

首行：**`[plan-reviewer]`**。日常入口：[agent-entry-route.md](../references/agent-entry-route.md)；争议/recovery：[CORE.md](../CORE.md)

## PM 门禁（硬停）

用户直接叫本岗、且**本轮尚无** `[PM]` YAML + **你下一步** 时：**不得**修改执行文档状态；须同条先 `[PM]` 判车道并输出白话 **你下一步**，再切本岗。只读咨询（不改文件）→ 不阻塞。

## 车道

| 车道 | 本岗 |
| --- | --- |
| Express | **跳过** |
| Direct | 跳过（无方案审；CR 隔离见 [code-reviewer/SKILL.md](../code-reviewer/SKILL.md)） |
| Standard | L1 须子窗（同会话即可，不强制新 Chat 隔离）；L1.5 回归索引模块；**跨 2+ 业务模块 → L2**（CORE §Standard 交叉审核）；L1.5 与 L2 取较高档 |
| Full | L2/L3 → [references/plan-review-tiers.md](../references/plan-review-tiers.md)；本岗**必须子窗** + **高质量**档（[model-routing.md](../references/model-routing.md)）；隔离见 [isolated-review.md](../references/isolated-review.md) |

## 模型路由 + 子窗

本岗**必须子窗**（含 Standard L1）：Task + **高质量**档（slug 按 [model-routing.md](../references/model-routing.md) 解析）。禁止主窗切 `[plan-reviewer]` 后直接出 findings。

## Checklist

1. **优先**读派发时点名的 `证据/_方案审核派发.md`，再**只读**工件白名单；禁扫 `证据/`（见 [doc-windowing.md](../references/doc-windowing.md)、[review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md)）；无点名工件时退回读 `未完成.md`+口径/Mandatory。无理由扩大阅读面 → **major/blocker**
1.1 开始前重算 `review_input_revision`；与工件不符或 `target_files` ⊄ whitelist → **blocker** `stale_dispatch`，旧结论不可复用。**只返回 findings**；禁止改工件。L3 第2轮**不得**读/复述第1轮结论
1.15 **图谱（审核岗）**：Mandatory 点名业务源码时，**优先 CRG**（`detect-changes` / impact / review context；业务在子模块则 `--repo` 点子模块根，见 [codegraph-probe.md](../references/codegraph-probe.md) 与 project-context）；需核对符号语义/原文时再窄用 CodeGraph。禁止两套完整双跑；无图谱按 codegraph-probe 降级（不得伪造「已核对调用链」）
2. **独立找 blocker**；不得只复述上一轮
3. 每 Step 查：Mandatory Code Changes、**DO NOT TOUCH（冻结表）**、**Delta Spec（ADDED/MODIFIED/REMOVED）**、**满足验收：A#**、验证、Prerequisites
3.05 **DO NOT TOUCH（冻结表）**：每 Step 须有该节（README 版本段 + 点名 API/文件，或「无（已扫）」）；缺节 → **major**。窗级「不要动什么」≠ Step 冻结表，不可用窗级替代
3.06 **阻塞边（blocking edges）**：≥2 Step **必填**「串联 / 并联」+ 路径集。缺边 → **major**；假串联 → **major**；路径相交却标并联 → **blocker**。日常单 Step / Express / Direct 对话内切片写「无（单步·不跑电路）」→ 不硬拦。旧句「缺失不硬拦」作废。点名 [circuit-windows.md](../references/circuit-windows.md)。
3.07 **共享语言**：方案两套叫法并存或术语未登记而歧义 → **major**（细则 [shared-language.md](../references/shared-language.md)）
3.5 **验收条款 + Delta-only + Delta Spec**（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md)）：无 `A1…`、条款不可证伪、Step 未引用 A#、文档复述整模块原理、或缺 Delta Spec 三段 → **blocker**，不得定版
3.55 **Analyze 对表（P2）**：交审时核对三表——A# ↔ Mandatory（Code Changes / Delta）↔ 预期 Console 关键词（回归索引 / 验收信号）；缺任一或对不上 → **major**（缺 A# 直接 blocker，见 3.5）。细则 → [acceptance-and-delta.md](../references/acceptance-and-delta.md) §Analyze 对表。**条款可证伪（思考碰撞回灌）**命中任一条 → **major**：①成功句有机器源，失败句只禁某种做法、抓不到「自报 / 不读该源 / 缺字段」；②机器检查只写「计数字段/脚本绿」未点名要比对的字段或行键；③Mandatory 入口接线（某 SKILL +1 行等）未写入对应 A#；④手工红线与脚本证据不同句，脚本绿可单独冒充该红线已过
3.56 **置信标注核验**（见 [evidence-levels.md](../references/evidence-levels.md) §置信标注）：方案/答复中关键行为断言（如「既有 X 流程会…」「状态已是…」「已核对调用链」）缺置信标注（`确定[有代码证据]`/`推断[有间接证据]`/`猜测[无证据]`）→ **major**；「猜测」冒充「确定」（无据称有据）→ **blocker**（伪称执行同族，`.ai-gates/lessons-learned.md` 2026-08-10 行）。核验方法=按标注回引代码位置/依据，回引不实 → 同判
3.6 **Agent 易错语义**：每 Step 须有该字段（Full 在 Pitfalls）；有记录则核对符号、实际语义及代码证据，写「未发现」时须列已检查的关键符号；缺字段、无证据或为凑数编造 → **blocker**
3.7 **窗口化**：新建 Standard/Full 须文件夹 + `未完成.md`；已完成长文仍留活跃窗或 Mandatory 仅在历史全文 → **blocker**；首段与状态矛盾 → **major/blocker**；Discover＞15行未外置 → **major**；`未完成.md`＞150行且无超限原因/压缩时点 → **major**；为压行删A#/当前Mandatory/状态真相 → **blocker**
3.7.1 **窗口关系摘要**（跨窗 plan-lite / Full）：须有 `## 窗口关系摘要` **四列表**（主题短名 + Beads 关系枚举 + 状态 + 关键结论一句）；缺表 → **major**；用散文段落替代四列表 → **blocker**
3.7.2 **档位单选 + 空闲枢纽**：「方案审核档位」保留未决串（如 `L1 / L1.5 / L2 / L3 / 跳过`）→ **major**；无活跃 Mandatory 的占位空壳长期停 `执行中/` → **major**（指针 [doc-windowing.md](../references/doc-windowing.md) §状态分类夹）
3.7.3 **终态须迁夹**：文档状态已是 `completed`/签收结案/失败·止损放弃/回退，或空闲须离执行中，但方案夹仍在 `执行中/`（未 `migrate-pipeline-window.ps1` 或同等）→ **blocker**（handoff §E 结案检查单硬项；未迁夹=未结案）
3.8 **诊断闸门**（见 [diagnosis-gates.md](../references/diagnosis-gates.md)）：命中止损（含热修累计）未停车 / 热修超上限仍定版 / 放行无合取 / 热修无并行实现一句 / 并行实现无收敛 / Verify 后无 Discover → **blocker**
3.8.1 **止损 0→1 反思句**（§1.4）：同一主现象止损计数 **0→1** 后，下一刀 Mandatory/Discover 须含「**为什么上一轮不是最后一门**」点名反思（至少 1 个门闸/调用边 `path:symbol`）；缺句或空话（如「已考虑路径」未点名门闸）→ **major**
3.9 **改前选型短表**：交审/定版前须有「本步方案 + 为什么选 + 不选的缺点」；缺 → **major**；先改码后补理由 → **blocker**
3.9.1 **错题本必读**（[lessons-learned.md](../references/lessons-learned.md) §错题大纲）：缺 `## 错题本必读（给程序员）` → **major**（纯咨询窗除外）；热模块/压力窗写「无」但大纲同桶有明显命中 → **major**；只列锚点无错因/改正可追溯（大纲或主表）→ **major**
3.9.2 **物理口径三件套**：`物理口径.md` 缺**硬句**≥1 / **负面**≥1 / **失败标准**≥1 任一项，或硬句为纯口号（无可观察信号/点名对象/可证伪判据）→ **major**
3.9.3 **逆链（声明启用时）**：方案声明启用逆链时（[reverse-chain.md](../references/reverse-chain.md)）：倒推起点不是失败标准 / 冻结表 / 不选的 → **major**；缺 Why Not Chosen 或负向代价 → **major**；从实现编 why → **blocker**；同模型圆稿标通过 → **major**；只审文档不审实现 → **major**；选型行 >5 无豁免 → **major**；交审后改选型须重开选型+逆链；静默改选型 / 改写用户拍板 → **blocker**。骨架倒走发现断裂却补链圆稿（禁修补）、或倒走产出比正向更完整的 why、或提示「请重构设计思路」→ **major**；缺改前三格或三格明显事后补写仍标该次逆链通过 → **blocker**。
3.10 **复用四问**（[execution-discipline.md](../references/execution-discipline.md)）：每 Step 缺「已有/复用/少写或不写/能删」短表 → **blocker**；明显可复用既有 helper/Service/门闸却新开并行实现或新抽象 → **blocker**；REMOVED 恒为「无」且 Mandatory 只往神类堆逻辑、无抽离说明 → **major**
3.11 **项目神类止血/补强三口**（若 `.cursor/project-context.md` 有该节）：Mandatory 仅「追加」口吻无下沉/REMOVED → **major**；超净增阈无 Service/REMOVED/用户确认收敛债 → **blocker**；新方法体超预算无豁免句 → **major**
3.12 **设计模式外部校验（轻量 · evolution-03 机制 C）**：Step Mandatory 声明采用 [design-patterns.md](../references/design-patterns.md) 词条时，缺**触发症状**描述 → **blocker**；缺**强制选型句**（症状+理由+出处）→ **major**；词条与 shared-language §典故 **同义双挂**（如又登记神类止血）→ **blocker**；无验证实例仍推模式 → **major**（YAGNI）。无采用声明：须有字面 `本步不采用 design-patterns 词条`；缺句 → **major**。需求源未写模式名不得因此 major。
3.13 **分歧标注（轻量）**：Mandatory/方案声明「已启用分歧标注」时，缺两个不同 id、或 B 见了 A 链、或对照/未裁由 A 或 B 写 → **blocker**；缺视角名或缺 DA→KG 指针 → **major**；把 diverge 写成「完整碰撞已做」→ **blocker**（[divergence-annotation.md](../references/divergence-annotation.md)）
3.14 **完整碰撞（轻量）**：方案把碰撞写成默认 5–8x 或直到共识 → **blocker**（[collision-review.md](../references/collision-review.md)）。启用碰撞却同模型双链 / `resume` 同一对冒充异模型轮转 → **blocker**。把止损触顶/热度单独写成已启用碰撞（确认包未选用）→ **major**。轮 1 不引用共识地基、轮 2/3 重写分歧/方案、或把完整方案/Top 3 当短清单 → **major**。把第三条路当震荡不计票写成现行 → **major**。把旧「恰好 2 轮对称全量 + 第三窗再审」写成现行手续 → **major**。声称 diverge 小试点=完整碰撞：保持既有 **3.13 blocker**，禁止降为 major。
3.15 **晋升闸文案（evolution-03-promote）**：晋升方案写「三重闸」却列四条 → **major**；假装 **gh** 已通 / 跨项目可跑 → **blocker**（[design-patterns.md](../references/design-patterns.md) §晋升闸）。
3.16 **逆向总结典故（轻量）**：把归档总结写成「逆链已通过」→ **blocker**；把本机制产出写成自动入典（写入 shared-language / design-patterns 词条表，或热度满自动晋升）→ **blocker**；无改前三格仍补跑逆链（归档触发 `reverse-chain.md` 启用级手续，或新编 why）→ **blocker**（[reverse-allusion.md](../references/reverse-allusion.md)）。
3.17 **模式沉淀（轻量）**（[pattern-harvest.md](../references/pattern-harvest.md)）：日常方案缺「模式沉淀」声明 → **不硬拦**（不因此 blocker / 不因此 major）。审查本机制页 / 本窗（pattern-harvest-flow）方案时，A# 须可证伪（触发表、禁止静默入表、禁止第七岗、须真锚点）；缺可证伪失败句 → **major**。把模式沉淀写成第七岗 / 岗位路由新行 / `knowledge-harvest` 岗 → **blocker**。
3.18 **本地自进化环（轻量）**：假装 gh 已通/已下发 → **blocker**；未「准」写入 `shared-language.md` §典故或 `anti-patterns.md` → **blocker**；写成第七岗 / 平行队列 / 新建通用错题主表 → **blocker**。
3.19 **GitHub 收集仓（轻量）**（[collect-queue.md](../references/collect-queue.md)）：把「准」写成建 issue/开 PR → **blocker**；把 issue 当主通道而仓已是 PR 仓 → **blocker**；`gh repo create` → **blocker**；未探测成功仍写「gh 已接线/已通/已下发」→ **blocker**；写成第七岗 / `github-collect.md` / 第二套队列 → **blocker**。
3.20 **Skill 回传（轻量）**（[pattern-harvest.md](../references/pattern-harvest.md) §Skill 自进化）：把收集仓合并写成已下发 → **blocker**；把下发写成拉 collect 仓 → **blocker**；第七岗 → **blocker**；未升级成功自称已下发 → **blocker**。
3.21 **机械 A# 无最小断言**（[test-first.md](../references/test-first.md)）：本 Step A# 含可机械验证项却无最小断言（`证据/test-first/` 或既有测试路径）→ **major**。不可机械项不启用 test-first，不得因此 major。三条反模式（测私有实现 / 同一套公式 / 先写完全部测试）命中 → 判断/major，不得写成全程 TDD 硬挡。
4. 有 blocker → 不得 `implementation-ready` / 可交给程序员=是；策划正确响应后可提醒提议 lessons 类型=`方案blocker`（须「准」，见 [lessons-learned.md](../references/lessons-learned.md)）
5. **L1.5 触发**（CORE §Standard 加强审核）：每 Step 的 Regression Validation 须引用 project-context 回归索引对应行；plan-lite「方案审核档位」记 **L1.5**
6. **L2 触发**（CORE §Standard 交叉审核）：跨 2+ 业务模块 → 档位 **L2**；**优先** Subagent 隔离（见 [isolated-review.md](../references/isolated-review.md)）；失败再提示手动新开；同 Chat 标 **「L2 非独立复核」**
7. 歧义转默认决策或 blocker；禁止「待定」
8. 定版前确认：过审后发 **一轮**确认包（[demand-clarification.md](../references/demand-clarification.md)）；白话；满是 API → **major**；要求用户再确认一轮才定版 → **major**
9. L3：**优先** Subagent 隔离 + **只读不写** + **最短派发包**；失败再提示手动新开 Chat
10. 用户仅咨询时不改文件
11. findings **短表**输出；禁止默认复述方案长文
L1 输出须标注 **「L1（非独立复核）」**；L1.5 须标注 **「L1.5 加强 — 回归索引模块」**；L2/L3 按实际隔离方式标注 **「隔离复核（Subagent）」** / **「独立复核（新 Chat）」** / **「非独立复核」**。PM 判 L1 且 plan-lite ≥2 Step 时须提示可选隔离审核（CORE §Standard 可选独立方案审核）。

## 输出

- blocker 列表（分级）
- 缺口与建议修改
- 无 blocker → **明确写**：发一轮确认包（理解+选型+准→改码）；禁拆轮、禁再要「请定版/请再确认」（[handoff-automation.md](../references/handoff-automation.md) §0）

Full 档位规则 → [references/plan-review-tiers.md](../references/plan-review-tiers.md) · [execution-doc-template.md](../references/execution-doc-template.md)
