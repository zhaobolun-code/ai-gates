---
name: 方案审核
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
| Standard | L1 同 Chat；L1.5 回归索引模块；**跨 2+ 业务模块 → L2**（CORE §Standard 交叉审核）；L1.5 与 L2 取较高档 |
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
3.5 **验收条款 + Delta-only + Delta Spec**（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md)）：无 `A1…`、条款不可证伪、Step 未引用 A#、文档复述整模块原理、或缺 Delta Spec 三段 → **blocker**，不得定版
3.6 **Agent 易错语义**：每 Step 须有该字段（Full 在 Pitfalls）；有记录则核对符号、实际语义及代码证据，写「未发现」时须列已检查的关键符号；缺字段、无证据或为凑数编造 → **blocker**
3.7 **窗口化**：新建 Standard/Full 须文件夹 + `未完成.md`；已完成长文仍留活跃窗或 Mandatory 仅在历史全文 → **blocker**；首段与状态矛盾 → **major/blocker**；Discover＞15行未外置 → **major**；`未完成.md`＞150行且无超限原因/压缩时点 → **major**；为压行删A#/当前Mandatory/状态真相 → **blocker**
3.7.1 **窗口关系摘要**（跨窗 plan-lite / Full）：须有 `## 窗口关系摘要` **四列表**（主题短名 + Beads 关系枚举 + 状态 + 关键结论一句）；缺表 → **major**；用散文段落替代四列表 → **blocker**
3.7.2 **档位单选 + 空闲枢纽**：「方案审核档位」保留未决串（如 `L1 / L1.5 / L2 / L3 / 跳过`）→ **major**；无活跃 Mandatory 的占位空壳长期停 `执行中/` → **major**（指针 [doc-windowing.md](../references/doc-windowing.md) §状态分类夹）
3.7.3 **终态须迁夹**：文档状态已是 `completed`/签收结案/失败·止损放弃/回退，或空闲须离执行中，但方案夹仍在 `执行中/`（未 `migrate-pipeline-window.ps1` 或同等）→ **blocker**（handoff §E 结案检查单硬项；未迁夹=未结案）
3.8 **诊断闸门**（见 [diagnosis-gates.md](../references/diagnosis-gates.md)）：命中止损（含热修累计）未停车 / 热修超上限仍定版 / 放行无合取 / 热修无双轨一句 / 双轨无收敛 / Verify 后无 Discover → **blocker**
3.8.1 **止损 0→1 反思句**（§1.4）：同一主现象止损计数 **0→1** 后，下一刀 Mandatory/Discover 须含「**为什么上一轮不是最后一门**」点名反思（至少 1 个门闸/调用边 `path:symbol`）；缺句或空话（如「已考虑路径」未点名挡点）→ **major**
3.9 **改前选型短表**：交审/定版前须有「本步方案 + 为什么选 + 不选的缺点」；缺 → **major**；先改码后补理由 → **blocker**
3.9.1 **错题本必读**（[lessons-learned.md](../references/lessons-learned.md) §错题大纲）：缺 `## 错题本必读（给程序员）` → **major**（纯咨询窗除外）；热模块/压力窗写「无」但大纲同桶有明显命中 → **major**；只列锚点无错因/改正可追溯（大纲或主表）→ **major**
3.9.2 **物理口径三件套**：`物理口径.md` 缺**硬句**≥1 / **负面**≥1 / **失败标准**≥1 任一项，或硬句为纯口号（无可观察信号/点名对象/可证伪判据）→ **major**
3.10 **复用四问**（[execution-discipline.md](../references/execution-discipline.md)）：每 Step 缺「已有/复用/少写或不写/能删」短表 → **blocker**；明显可复用既有 helper/Service/门闸却新开并行轨或新抽象 → **blocker**；REMOVED 恒为「无」且 Mandatory 只往神类堆逻辑、无抽离说明 → **major**
3.11 **项目神类止血/补强三口**（若 `.cursor/project-context.md` 有该节）：Mandatory 仅「追加」口吻无下沉/REMOVED → **major**；超净增阈无 Service/REMOVED/用户确认收敛债 → **blocker**；新方法体超预算无豁免句 → **major**
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
