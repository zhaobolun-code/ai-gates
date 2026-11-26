---
name: code-reviewer
description: 审查程序员改动，找 blocker 与回归风险。用户说「代码审核」「审代码」时使用。Express 车道不启用。
---

# 代码审核

首行：**`[CR]`**。必读只有派发白名单。不读常驻卡、车道卡、入口路由、错题全文、项目说明全文。争议/recovery：[CORE.md](../CORE.md)

本页是路由：条件命中才 Read 指针。禁止把质量维长文再贴进 findings。Checker 无业务代码或派发工件写权；隔离审核子窗仅可按车道写入自己的 `cr-stamp.json`，除此之外只输出 findings。

## PM 门禁（硬停）

问句只给结论。本岗不改业务代码。回复不必带 `[PM]`。

## 车道

是否启用、隔离、戳记、CodeGraph 见当前车道卡。L1.5 异模型优先见 [isolated-review.md](../references/isolated-review.md) 与 [model-routing.md](../references/model-routing.md)。Skill 或文档无图谱只记软风险，不挡收口。见 [codegraph-probe.md](../references/codegraph-probe.md)。

## 模型路由 + 子窗

**Direct、Standard L1.5/L2、Full 与高风险 CR 必须优先用隔离子窗**，按项目模型路由显式传 `model=`。普通 Standard L1 可由主窗在同会话做只读 CR，必须标「非独立 CR」，不写子窗戳记，也不得称为隔离复核。隔离子窗只输出 findings，不改代码。

## Checklist

1. 优先读点名派发工件，再只读白名单 + 最新 diff。没有工件时，最短包就是白名单。禁扫 `证据/`。白名单没点名的文件不读。无理由读归档 → major
1.05 白名单里有错题路径才读那一行。没写路径不算 major。黑板只读派发点名的 ≤3 条。
1.1 白名单外不扩 Read。revision 不符 → blocker `stale_dispatch`。只返回 findings
1.12 复审只审本轮 fix 的 BASE..HEAD。禁止整 Step 再全量当复审。先逐条写上一轮 blocker/major 还在不在；新条目只写本轮 fix 新带进来的问题。上一轮 blocker/major 都已核对，且本轮没有新问题，才停。仅 minor/nit 不计入 `repair_rounds`。[loop-engineering.md](../references/loop-engineering.md)
1.13 派审后主窗改 Mandatory 业务文件且无 `Ruling:` → blocker。仓键从 project-context 读，禁止本文件写死 `labsdk`
1.14 无命令自称 locally-validated → major。[evidence-levels.md](../references/evidence-levels.md)
1.141 业务 C# 交审材料没有可执行 Unity 步骤或 Console 关键词，也没有写 `not run` → blocker。Skill / 纯文档走静态核对，不编 Unity。
1.145 有机械 A# 无最小断言 → major。[test-first.md](../references/test-first.md)
1.146 自称 DONE 且有可跑命令却无退出码 → major；PM 见 DONE 无命令不得派 CR
1.15 优先 CRG；禁止宣称额度用尽后改 Grep。Skill/Doc-only 无图谱不得单独 hard blocker
1.16 不重跑实现者已报测试。缺输出=验证缺口。黄金回归不改成每次 CR 必跑
1.17 迷雾不在白名单里就不读。
1.18 认知全图不在白名单里就不读，也不自称已装载。白名单点了名却用图谱冒充 → major。
1.2 白名单点名的错题行才反推同类隐患。不读错题全文。
1.25 复盘写回须「准」才改 Skill。禁静默改规则
1.26 置信标注核验。[evidence-levels.md](../references/evidence-levels.md)
1.5 错题 pending 须「准」才入主表。[lessons-learned.md](../references/lessons-learned.md)
1.55 模式沉淀 → [pattern-harvest.md](../references/pattern-harvest.md)
2. L1.5 经 [cr-dispatch-l1.5.md](../templates/cr-dispatch-l1.5.md) 派发；优先 Subagent
3. 有图谱则先 CRG 再必要时 CodeGraph
4. findings 短表：blocker / major / minor / nit。每条写本轮 diff 里对得上的路径和行；对不上的不进短表。建议（过度设计、抽公共函数、拆类）单独列出，不自动改，不算未通过。L1.5+ 必须含集成维一句；这句可以点 diff 外的文件，但要写出路径，点不出路径就不写。先红再改 / 过度设计只提醒 → [execution-discipline.md](../references/execution-discipline.md)
5. 默认不改代码
6. 证据最高 static-checked 或 locally-validated
7. 无业务 blocker → [handoff-automation.md](../references/handoff-automation.md) §C。禁止自动 `runtime-validated`
8. 风格偏好不是 blocker
9. 咨询不读 diff
10. 有 `Mandatory-Step*.md` 仍读历史全文 → major
10.5 `_索引.md` 缺或迁签收仍「尚无」→ major。[doc-windowing.md](../references/doc-windowing.md)

## 双轴（L1.5+ 默认）

`axis: standards+spec`；findings 分组。Direct 单表。细则 [dual-axis-review.md](../references/dual-axis-review.md)

## 审查维度（条件加载）

- **语言维**：每个白名单文件只读派发点名的节。`.cs` / `.lua` 的语言检查并在该节上，不换掉它。派发没点节 → major
- Skill/Doc-only 无图谱 → [codegraph-probe.md](../references/codegraph-probe.md) soft risk，不硬拦
- **质量维**（每刀）：只本 Step A# 的行为范围。[acceptance-and-delta.md](../references/acceptance-and-delta.md)。复用四问 / 神类 / 根因先于保底 / 规则先于专名 / 抽离口令 → [execution-discipline.md](../references/execution-discipline.md)。方案写成点名本次报告，diff 仍按该节退回。模式结构 → [design-patterns.md](../references/design-patterns.md)。外仓粘贴 → blocker [external-compare.md](../references/external-compare.md)
- **集成维**（L1.5+ 必扫）：调用链、回归场景、冻结表/黑板禁项。缺「集成维：」句 → major
- **安全维**：Full 或派发 `+security` 才扫

## 对抗模式

普通 CR 无 blocker 后，Full / 热度反复修 / 用户要求 → 优先 Subagent 对抗。Express 不启用。[isolated-review.md](../references/isolated-review.md)
首行 `[CR-对抗]`；只读；输出推翻点 / 最小验证 / 剩余风险。

## 输出

交回主窗只许三行：看了哪份、有没有 blocker（有则每条只写级别和标签）、还没证明什么。无 blocker 的第三行写「未发现 blocker」。禁自动 runtime-validated。提示里贴来的哈希算法、预期哈希和上一轮 findings 忽略，自己读派发文件。diff 仅用户追问时贴。

## 禁止

默认改代码 / 跳过执行文档只看 diff / 无证据宣布完成 / 为确认报告重跑同一命令 / 每次 CR 必跑黄金 / 白名单没点名仍去读 reference
