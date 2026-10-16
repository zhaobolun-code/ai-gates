# Agent 日常入口路由（≤1 屏）

> **默认入口**。日常勿通读 CORE 全文；争议 / recovery / `按 CORE 重来` 再查 [CORE.md](../CORE.md)。  
> 第二跳：按 [reference-routing.md](./reference-routing.md) 点名 ≤2 份 reference（禁整目录灌入）。

## 对人说话（每轮 · 团队用户）

面向人的正文（不含 `[PM]` YAML；各岗都算）：

1. 首行就是动作。
2. 可见列表每组最多 5 条。
3. 每轮一句：现在到哪 / 刚做成什么 / 还剩什么。
4. 用人话。黑话默认不说；可留口令与典故词，典故词不展开压缩包。
5. 同一症状连败三轮仍坏 → 先点名哪条假设错了，再给选项。触发才加载 [diagnosis-gates.md](./diagnosis-gates.md) §0.2.3。

细则 → [user-visible-states.md](./user-visible-states.md) §对人说话。

## 压缩之后

对话若已被收成摘要，或钩子写了「摘要不是约定」：下一步先读本页、`.cursor/project-context.md` 的模型路由、当前任务夹的 `未完成.md`（没有任务夹则只读项目说明）。读完之前不要改代码。摘要里的「继续修」不是过关标准，也不能把「此路不通」当成已经作废。这不是换窗交接。

## 默认必读

1. **本页**
2. **`.cursor/project-context.md`**（若有）
3. **当前岗 `SKILL.md` checklist**（按条执行；禁粘贴 SKILL 全文进上下文）

## 任务白名单（非 reference 预算 · 不得为省 Token 跳过）

- 当前任务夹这一份 `未完成.md` / `物理口径.md` / 点名 `Mandatory-Step*.md`。其它窗的未完成不读、不贴
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
| PM | 1. 内部 YAML 须含字面 `[PM]`（120 分钟窗口≠本条已判定）；Express 用户可见只「你下一步」和下面这一行 token；非 Express=白话摘要表+你下一步。YAML 结束后另起一行：`token：上一轮 输入 N / 输出 N / 缓存读 N / 缓存写 N`。N 只抄本轮注入句，或 `.ai-gates/hooks-log/pm-turn-tokens.json` 的 `latest`（`atUtc` 在 30 分钟内）。没有就写 `token：上一轮未记到`。这是上一轮回复结束后的实测，禁止估算本轮<br>2. Direct：PM 写对话内 A#/切片，不清才派策划；判车道前一次窄图谱或 diff 估将改文件数<br>3. 主窗仅 PM（Express/简单 Direct 实现可主窗）；子窗显式 `model=`；派策划禁点名典故 → [execution-discipline.md](./execution-discipline.md) §设计模式一问<br>4. 一轮确认「准」；确认包可含【重构候选】；「准」≠ 准抽离 → [demand-clarification.md](./demand-clarification.md)<br>5. 迷雾仅开窗/改邻接/签收；出图门问是否创建/更新；卡住/压缩/换窗 → [fog-map-structure.md](./fog-map-structure.md) / [long-task.md](./long-task.md) / [session-handover.md](./session-handover.md)。阶段结束换新对话，只吐四格短交接。主窗不贴 diff。工具输出用完只留路径和决定 → [execution-discipline.md](./execution-discipline.md) §上下文只留指针 |
| planner | **Express=PM 一句话切片；Direct=PM 已写清则本岗不派，否则对话内 A#/切片不落盘；Standard/Full 落盘**；同窗同口径战役则口径未变不重做方案；复用四问（第4问须升级触发）+选型；错题本必读节；A#+Delta；一轮确认包「准」；确认包填【重构候选】；无症状则无或一行无；写热路径 Mandatory 先装载认知全图 |
| plan-reviewer | 只读派发白名单；查 A#/Delta/选型/错题节；第4问无触发=填空 blocker；有 blocker 不定版；禁再要一轮确认；战役中刀口径/选型/A# 契约未变 → 不派本岗；默认抽检四类洞（失败句/字段钉死/条款与清单同句/机器绿≠人看见的现象）；碰撞仍点名才开；图谱不得冒充认知全图 |
| developer | 有「准」/恢复口令才改；只改本 Step A#（**Direct=对话内切片**）；Express/简单 Direct **可主窗**；复用四问；微循环自检；**Direct 完成交隔离 CR（必须子窗）**；Step 收口迁 `已完成/_索引`（战役可批到签收；迁签收≠归档）；分析热路径：①本会话认知全图一次 ②本 Step 点名对象的 R ③CodeGraph ④源码 |
| CR | 只读派发+白名单+diff；优先 CRG；短表 findings；禁扫证据夹；**Direct=高级档隔离复核（必须子窗）**；Skill/Doc 可提示 verify；未装载认知全图却自称理解 / 用图谱冒充 → major |
| docs | 无 blocker 才写；能一行不扩章；不夸大验证等级；新回归同步索引 |
| weekly | 只出汇报正文；禁路径/黑话；不改代码；固定 `# 工作周报` 骨架 |
