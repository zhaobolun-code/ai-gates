# 知识缺口上报/待澄清队列

> 生效规则（2026-08-12 落地，evolution-02 方向二）。扩展覆盖点 = `skills/developer/SKILL.md` §5.5 三问句后第一处「仍无法证实时停下交 PM」（§5.5 置信标注段同句不重复接线）；§8 交接短表。
> 载体模板 [knowledge-gap.md](../templates/knowledge-gap.md)。

## 定位

「不确定则停」（developer §5.5）的平行通道：阻塞级不确定照旧**停**（入队不豁免）；非阻塞级不确定**入队继续**。补「实现侧在动作进行中无自我声明通道」的盲区——方案审/CR 核验是交审后被动触发，本机制在动作进行中主动上报「我不知道」。

## 分级判据（§5.5 三问后分流）

| 级 | 判据 | 动作 |
| --- | --- | --- |
| **阻塞级** | 物理口径 / 范围 / A# 语义 | **停**（维持「不确定则停」）；同时问题入队供 PM 汇总——停 ≠ 不问 |
| **非阻塞级** | 第三方库 API 细节 / 历史文档口径 | 入队继续当前 Step，不阻塞 |
| 无法归类 | — | 保守按阻塞级 |

## 载体

`证据/_knowledge-gap.md`：**每窗一个**（窗名同执行文档夹），doc-windowing 合法读写例外（见 [doc-windowing.md](./doc-windowing.md)「知识缺口例外」；同 `_lesson-pending.md` 先例，见 [lessons-learned.md](./lessons-learned.md) §L0/L1/pending）。

## 三要素必填（防懒问 / 防垃圾场）

① 问题一句话　② 上下文位置（文件 / 行号 / Step）　③ 已尝试（读过什么、查过什么）。
缺任一**拒收**；「已尝试」空 = 懒问，拒收。不满足三要素不得入队。

## 分歧来源

经 [divergence-annotation.md](./divergence-annotation.md) 入队的条目，须在问题句或上下文位置标注 `来源：分歧标注` + `DA-{nn}`；仍须满足三要素；缺 DA 对照 → 拒收。对照须由派发方写，条目不得由 A/B 自写对照冒充。收敛/升级规则不变（确认包清队、同族跨窗 ≥2 → 机制 A）。

## 碰撞来源

经 [collision-review.md](./collision-review.md) 入队的条目，须在问题句或上下文位置标注 `来源：思考碰撞`；仍须满足三要素；缺三要素 → 拒收。高价值异议先入 `_lesson-pending.md`（待确认、不生效），门槛见 collision-review；用户「准」后才进错题本主表 `.ai-gates/lessons-learned.md`。**不**与 KG 混表；禁止自动迁反模式库、禁止超时进主表。收敛/升级规则不变（确认包清队、同族跨窗 ≥2 → 机制 A）。禁止平行队列、禁止把 `compute-evolution-candidates.ps1` 当自动晋升。

## 收敛（防队列变垃圾场）

- 主窗 PM 生成确认包**前**先读 open 条目，随确认包**批量**问用户（不打断主流程；指路 [handoff-automation.md](./handoff-automation.md) §0 / [demand-clarification.md](./demand-clarification.md)）；
- 回答后标 `answered` 归档，条目回答即弃不留陈账；
- 同族问题**跨窗**重入队 ≥2 次（不同执行窗出现同族问题即计数）→ 走机制 A 活跃度判定升级为正式条目/文档（指路 [evolution-01-self-evolution.md](../../Doc/AI流水线/签收/evolution/evolution-01-self-evolution.md) 机制 A，不重复实现）。

## 硬律

- 阻塞级入队**不豁免**「停」：停 + 入队二动作都做；禁「已入队」冒充「已闭环」（同族：[lessons-learned.md](../../lessons-learned.md) 2026-07-09 suppressStreak 行 → [anti-patterns.md](./anti-patterns.md) §漂移与臆测「门卫≠完成」行）；
- 禁懒问：「已尝试」空拒收；
- 队列非错题本：禁止把「不知道」当「错」写 lessons pending / 主表（`commit-lesson-pending.ps1` 按教训字段 cause/fix 解析，知识缺口条目混入必 throw）。
- 跨项目可传条目走 [collect-queue.md](./collect-queue.md)，**禁止**把收集仓条目写入 `_knowledge-gap.md` 或 lessons pending。

## 接线

- developer §5.5 三问句后分级（阻塞停不豁免 / 非阻塞入队 / 三要素必填）；§8 交接短表有 open 条目时列出；
- [reference-routing.md](./reference-routing.md)「模型自动触发」表：仍无法证实时 / 不确定则停时 / 确认包·转场前读 open 条目 → 本文件（model-invoked，无需用户点名）；
- 升级链路走机制 A（evolution-01），本机制不实现。
