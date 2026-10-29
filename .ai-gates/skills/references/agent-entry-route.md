# Agent 日常入口路由（≤1 屏）

常驻只读 [resident.md](./resident.md)。判定之后只读当前车道那一张卡，不把四张一起装进来。

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

1. **[resident.md](./resident.md)**
2. **当前这一张车道卡**（`skills/references/` 下的 `lane-express.md` / `lane-direct.md` / `lane-standard.md` / `lane-full.md`）
3. 用到才打开那一份，不把三份全文装进每轮：**[read-evidence](../read-evidence/SKILL.md)**、**[run-evidence](../run-evidence/SKILL.md)**、**[log-evidence](../log-evidence/SKILL.md)**。主窗不自己读代码和长文档、不自己搜索、不自己跑终端、不自己看日志。

派子窗前再读 `.cursor/project-context.md` 的模型路由那一节。回归索引和物理口径派查正文去读，主窗不自己读。不把整份项目说明装进每轮。派发只写岗位、轮次、派发文件路径。不贴哈希算法、预期哈希、blocker 原文、岗位卡。子窗交回只留三行。岗位卡由子窗自己读。

## 任务白名单（非 reference 预算 · 不得为省 Token 跳过）

- 当前任务夹这一份 `未完成.md` 主窗可以直接读。`物理口径.md`、点名 `Mandatory-Step*.md`、模块 README、真实源码和 diff 派查正文，主窗不自己读。其它窗的未完成不读、不贴
- 方案点名的 lessons / 错题大纲行
- Express：`express-slice` / `express-self-check`
- 点名「模式沉淀」→ 加载 [pattern-harvest.md](./pattern-harvest.md)
- 点名「电路子窗」→ 加载 [circuit-windows.md](./circuit-windows.md)
- 点名「外仓对照」→ 加载 [external-compare.md](./external-compare.md)
- 主窗要看日志原文（Unity `Editor.log`、编译/测试输出、`hooks-log` 长日志）或用户说「查日志」→ 加载 [log-evidence/SKILL.md](../log-evidence/SKILL.md)。主窗不读原文
- 主窗要看代码或长文档，或用户说「查正文」→ 加载 [read-evidence/SKILL.md](../read-evidence/SKILL.md)。主窗不自己调 CodeGraph，不自己读长文。当前 `未完成.md`、本页、模型路由仍可由主窗直接读
- 主窗要跑编译、测试、脚本或其它命令，或用户说「跑命令」→ 加载 [run-evidence/SKILL.md](../run-evidence/SKILL.md)。主窗不自己跑终端
- 开窗 / 改邻接 / 签收须读迷雾卡片 + 一度边（加载 [fog-map-structure.md](./fog-map-structure.md)；邻格各 ≤1 行、下一站 ≤1 行）。未读邻边不得自称已按 5.0.0 合规。写方案复用四问「已有吗」/ 问下一窗或文档怎么连 → 同样加载。Express 机械改 / 纯代码热修 / 战役中刀只实现 / 闲聊 → 不读。禁止把 `fog-map.json` 列入默认必读
- 点名「代码认知地图」或 project-context 有「热路径认知卡片 / 代码认知卡片」节且本步分析/改热路径代码 → 加载 [code-cognition-map.md](./code-cognition-map.md)，**本会话整节一次**（与迷雾一张卡相反；本 Step 按点名对象走 R）。无该节不强制。压缩后禁止用摘要冒充 FRAS。Express 机械改不读。禁止把 CodeGraph 冒充已装载全图

## CORE 全文何时读

仅：规则争议 · recovery · 用户口令 **`按 CORE 重来`**（及同义）。其余日常不默认通读。

## Reference 第二跳

按 [reference-routing.md](./reference-routing.md) 触发点名，**每阶段 ≤2 份**。

## 各岗 checklist 子弹（示意，岗 SKILL 为准）

| 岗 | 子弹 |
| --- | --- |
| PM | 1. 内部 YAML 须含字面 `[PM]`（120 分钟窗口≠本条已判定）；Express 用户可见只「你下一步」和下面这一行 token；非 Express=白话摘要表+你下一步。YAML 结束后另起一行：`token：上一轮 输入 N / 输出 N / 缓存读 N / 缓存写 N`。满 5 位的 N 写成万，保留一位小数，整万不写小数。N 只抄本轮注入。没有本轮注入就写「上一轮未记到」，禁止抄别的对话。这是上一轮回复结束后的实测，禁止估算本轮。注入里若有换窗行，必须换行再写「已满足换窗条件, 请执行换窗逻辑减少token消耗」，禁止用空格接在 token 同一行。换窗行只在本对话首次记账后又增加至少 20 万输入时出现<br>2. 车道步骤不在本表复述。Express → [lane-express.md](./lane-express.md)；Direct → [lane-direct.md](./lane-direct.md)；Standard → [lane-standard.md](./lane-standard.md)；Full → [lane-full.md](./lane-full.md)<br>3. 主窗仅 PM（Express 与 Direct 的业务改码必须子窗）；子窗显式 `model=`；派策划禁点名典故 → [execution-discipline.md](./execution-discipline.md) §设计模式一问<br>4. 一轮确认「准」；查得到的不问（文件、接口、已写明的数值和口径先读进确认包，只问必须拍板的事）；确认包可含【重构候选】；「准」≠ 准抽离 → [demand-clarification.md](./demand-clarification.md)。错题大纲有命中时，「你下一步」点名那一行的日期或关键词，最多 1 行；没命中写「已扫，无命中」。禁止只写「看过错题」<br>5. 迷雾仅开窗/改邻接/签收；出图门问是否创建/更新；卡住/压缩/换窗 → [fog-map-structure.md](./fog-map-structure.md) / [long-task.md](./long-task.md) / [session-handover.md](./session-handover.md)。阶段结束换新对话，只吐四格短交接。主窗不贴 diff。工具输出用完只留路径和决定 → [execution-discipline.md](./execution-discipline.md) §上下文只留指针。主窗要看日志时先读 [log-evidence/SKILL.md](../log-evidence/SKILL.md)，派低级子窗，不自己读原文。主窗要看代码或长文档时先读 [read-evidence/SKILL.md](../read-evidence/SKILL.md)，派低级子窗调 CodeGraph 或读点名文档。主窗要跑终端时先读 [run-evidence/SKILL.md](../run-evidence/SKILL.md)，派低级子窗，只收回退出码和一句结论 |
| planner | **Express=PM 一句话切片；Direct=PM 已写清则本岗不派，否则对话内 A#/切片不落盘；Standard/Full 落盘**；同窗同口径战役则口径未变不重做方案；复用四问（第4问须升级触发）+选型；错题本必读节；A#+Delta；一轮确认包「准」；确认包填【重构候选】；无症状则无或一行无；写热路径 Mandatory 先装载认知全图 |
| plan-reviewer | 只读派发白名单；查 A#/Delta/选型/错题节；第4问无触发=填空 blocker；有 blocker 不定版；禁再要一轮确认；战役中刀口径/选型/A# 契约未变 → 不派本岗；默认抽检四类洞（失败句/字段钉死/条款与清单同句/机器绿≠人看见的现象）；碰撞仍点名才开；图谱不得冒充认知全图 |
| developer | 有「准」/恢复口令才改；只改本 Step A#（**Direct=对话内切片**）；Express 与 Direct 的业务改码**必须子窗**；复用四问；微循环自检；**Direct 完成交隔离 CR（必须子窗）**；Step 收口迁 `已完成/_索引`（战役可批到签收；迁签收≠归档）；分析热路径：①本会话认知全图一次 ②本 Step 点名对象的 R ③CodeGraph ④源码 |
| CR | 只读派发+白名单+diff；优先 CRG；短表 findings；禁扫证据夹；**Direct=高级档隔离复核（必须子窗）**；Skill/Doc 可提示 verify；未装载认知全图却自称理解 / 用图谱冒充 → major |
| docs | 无 blocker 才写；能一行不扩章；不夸大验证等级；新回归同步索引 |
| weekly | 只出汇报正文；禁路径/黑话；不改代码；固定 `# 工作周报` 骨架 |
| log | 主窗要看日志时派低级子窗；只收回三行；主窗不读原文 |
| read | 主窗要看代码或长文档时派低级子窗；代码走 CodeGraph；只收回三行 |
| run | 主窗要跑终端时派低级子窗；只收回退出码和一句结论 |
