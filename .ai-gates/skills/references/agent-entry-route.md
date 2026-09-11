# Agent 日常入口路由（≤1 屏）

> **默认入口**。日常勿通读 CORE 全文；争议 / recovery / `按 CORE 重来` 再查 [CORE.md](../CORE.md)。  
> 第二跳：按 [reference-routing.md](./reference-routing.md) 点名 ≤2 份 reference（禁整目录灌入）。

## 默认必读

1. **本页**
2. **`.cursor/project-context.md`**（若有）
3. **当前岗 `SKILL.md` checklist**（按条执行；禁粘贴 SKILL 全文进上下文）

## 任务白名单（非 reference 预算 · 不得为省 Token 跳过）

- 当前 `未完成.md` / `物理口径.md` / 点名 `Mandatory-Step*.md`
- 模块 README **当前风险短段**（勿整份版本史）
- 真实源码 / diff（优先 `codegraph_explore`）
- 方案点名的 lessons / 错题大纲行
- Express：`express-slice` / `express-self-check`
- 点名「模式沉淀」→ 加载 [pattern-harvest.md](./pattern-harvest.md)
- 点名「电路子窗」→ 加载 [circuit-windows.md](./circuit-windows.md)
- 点名「外仓对照」→ 加载 [external-compare.md](./external-compare.md)
- 开窗 / 改邻接 / 签收须读迷雾卡片 + 一度边（加载 [fog-map-structure.md](./fog-map-structure.md)；邻格各 ≤1 行、下一站 ≤1 行）。未读邻边不得自称已按 5.0.0 合规。写方案复用四问「已有吗」/ 问下一窗或文档怎么连 → 同样加载。Express 机械改 / 纯代码热修 / 战役中刀只实现 / 闲聊 → 不读。禁止把 `fog-map.json` 列入默认必读
- 点名「代码认知地图」或 project-context 有「热路径认知卡片 / 代码认知卡片」节且本步分析/改热路径代码 → 加载 [code-cognition-map.md](./code-cognition-map.md)，**本会话整节一次**（与迷雾一张卡相反；本 Step 按点名对象走 R）。无该节不强制。压缩后禁止用摘要冒充 FRAS。Express 机械改不读。禁止把 CodeGraph 冒充已装载全图

## CORE 全文何时读

仅：规则争议 · recovery · 用户口令 **`按 CORE 重来`**（及同义）。其余日常不默认通读。

## Reference 第二跳

按 [reference-routing.md](./reference-routing.md) 触发点名，**每阶段 ≤2 份**。

## 各岗 checklist 子弹（示意，岗 SKILL 为准）

| 岗 | 子弹 |
| --- | --- |
| PM | 内部 YAML（回复须含字面 `[PM]`；120 分钟窗口≠本条已判定）；Express 用户可见只「你下一步」；非 Express=白话摘要表+你下一步；**Direct 判定（PM 写对话内 A#/切片；不清才派策划）**；判车道前一次窄图谱或 diff 清单估将改文件数；同窗同口径战役见 [circuit-windows.md](./circuit-windows.md)；一轮确认硬律「准」；确认包可含【重构候选】；「准」≠ 准抽离；主窗仅 PM（Express/简单 Direct 实现可主窗）；子窗显式 `model=`；**派策划禁点名典故**（[execution-discipline.md](./execution-discipline.md) §设计模式一问）；本仓无同类可**提示**外仓对照（[external-compare.md](./external-compare.md)；提示≠启用）；卡住 → [long-task.md](./long-task.md)；压缩/跨会话续作先 Read 账本 + git log，并扫落盘 Express（无本会话测令→迁停写，不得用 `not run` 抗辩）；已 complete 禁止重派；Standard/Full 无四态第一行不得派 CR；CONCERNS 须 `Ruling:`；**迷雾仅开窗/改邻接/签收**读卡片 + 一度边；未读邻边不得自称已按 5.0.0 合规；Express 机械改 / 纯代码热修不碰文档窗 / 闲聊 → 不读；**出图门**：开窗或迁签收/停写/失败后看该主题根 `fog-map.html`：无图则判断能否成图，能则问「是否创建迷雾地图」；有图则问「是否更新迷雾地图」。禁止有夹自动出图、禁止未提示未同意就跑 generate；将改系统夹已有 `fog-map.html` 时考虑把结构面给策划/程序员（仍禁灌整 JSON / 读 HTML）；有认知卡片节则新对话/压缩后**整节装载一次**（[code-cognition-map.md](./code-cognition-map.md)；≠迷雾一张卡；本 Step 按点名受管对象走 R）；同 A# 第一次测挂（有意义=有且根因钉死）同条热修，第二次才 Discover 菜单；用户发言≥20 轮→提示回「换窗」（每窗一次；≠执行交接；[session-handover.md](./session-handover.md)） |
| planner | **Express=PM 一句话切片；Direct=PM 已写清则本岗不派，否则对话内 A#/切片不落盘；Standard/Full 落盘**；同窗同口径战役则口径未变不重做方案；复用四问（第4问须升级触发）+选型；错题本必读节；A#+Delta；一轮确认包「准」；确认包填【重构候选】；无症状则无或一行无；写热路径 Mandatory 先装载认知全图 |
| plan-reviewer | 只读派发白名单；查 A#/Delta/选型/错题节；第4问无触发=填空 blocker；有 blocker 不定版；禁再要一轮确认；战役中刀口径/选型/A# 契约未变 → 不派本岗；默认抽检四类洞（失败句/字段钉死/条款与清单同句/机器绿≠人看见的现象）；碰撞仍点名才开；图谱不得冒充认知全图 |
| developer | 有「准」/恢复口令才改；只改本 Step A#（**Direct=对话内切片**）；Express/简单 Direct **可主窗**；复用四问；微循环自检；**Direct 完成交隔离 CR（必须子窗）**；Step 收口迁 `已完成/_索引`（战役可批到签收；迁签收≠归档）；分析热路径：①本会话认知全图一次 ②本 Step 点名对象的 R ③CodeGraph ④源码 |
| CR | 只读派发+白名单+diff；优先 CRG；短表 findings；禁扫证据夹；**Direct=普通档隔离复核（必须子窗）**；Skill/Doc 可提示 verify；未装载认知全图却自称理解 / 用图谱冒充 → major |
| docs | 无 blocker 才写；能一行不扩章；不夸大验证等级；新回归同步索引 |
| weekly | 只出汇报正文；禁路径/黑话；不改代码；固定 `# 工作周报` 骨架 |
