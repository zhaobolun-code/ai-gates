# 反模式 / 常见误用

> 翻车短索引见 [CORE.md](../CORE.md)；完整表见本文件；日常入口仍 [agent-entry-route.md](./agent-entry-route.md)。

## 如何使用

- **项目经理 / 各岗位**：CORE 翻车索引优先；派岗或交接前扫本表是否命中其他反模式。
- **与 hard blocker 关系**：命中反模式通常对应 **hard blocker** 或须立即 **升级模式**；详见 [evidence-levels.md](./evidence-levels.md)。
- **复盘写回（P2）**：连续同类 blocker，或错题主表行满足升级资格（**近 90 天 ≥2 次命中 且 最近命中 ≤30 天**；机器候选见 `scripts/compute-evolution-candidates.ps1`，另须人工确认留痕——同族错误不重复计数、机器候选≠已确认）→ CR / 方案审 提议补写本表或 lessons；**用户「准」后才改 Skill**（改前 CHANGELOG）；静默改规则 = **major**（评测 E2）。

## CORE 翻车索引（v3.1.3 · 命中驱动维护）

> **索引维护规则**：只列**近 90 天有真实命中**的反模式；上限 **15 条**。新增条目须带命中证据（lessons/窗口/发布闸记录）并在完整表留反模式行；超上限时最低命中条目降级回完整表（CORE 引用仅留指针）；**近 90 天无命中 = 低触发 → 降级回完整表**（索引层窗口按既有 90 天，与错题/典故三态同判据）——防索引无限膨胀（2026-08-03 机制减负）。

| # | 反模式 | 近90天命中证据 | 见本文件章节 |
| --- | --- | --- | --- |
| 1 | 没读代码就改 | ✓（lessons 多点名真调用链/边界） | §漂移与臆测 |
| 2 | 无 implementation-ready 仍派程序员 | ✓ | §方案与文档状态 |
| 3 | 一次实现多 Step | ✓ | §实现与代码审核 |
| 4 | 未测/伪验标 runtime-validated | ✓（lessons 满管泄窗 2026-07-22） | §方案与文档状态 / §文档、回归与归档 |
| 5 | L1.5 同 Chat 自审 | ✓（隔离子窗机制由来） | §实现与代码审核 — **提示**新开 Chat，不校验 |
| 6 | Express 简略「你下一步」过薄 | ✓ | §PM 输出 — 缺车道/下一岗/五态/动作任一项 |
| 7 | PM 内部字段泄露给团队用户 | ✓ | §PM 输出 — 内部字段仅 Agent 使用；用户只看白话「你下一步」 |
| 8 | 跳过 PM 直接叫「程序员/策划」 | ✓（硬门禁 #7 由来） | §团队使用 — 硬门禁 #7 + 各岗 §PM 门禁 |
| 9 | 无 PM 结构化判定仍改代码/文档/README | ✓（2026-08-03） | §团队使用 — 须先 `[PM]` 判车道并输出 **你下一步** |
| 10 | Full 强制未白话提示完整流程 | ✓ | §PM 输出 — 须含「建议启用完整流程（Full）」 |
| 11 | 过度设计/残留死代码/类文件无限膨胀 | ✓（神类止血 2026-07-29） | §实现与代码审核 — 精简优先（YAGNI），见 execution-discipline.md |
| 12 | 连续多次 static-checked 修复堆积无 Unity 验证 | ✓（lessons 2026-07-22） | §实现与代码审核 — 达到阈值（≥3 次）须停下先测一次 |
| 13 | 热修/切片失败后长期挂「未完成」不封存 | ✓（doc-windowing） | §方案与文档状态 — [doc-windowing.md](./doc-windowing.md) §热修/切片失败或回退即封存 |
| 14 | 根因改判后不先改物理口径就直接开码 | ✓（diagnosis §0.5） | §漂移与臆测 — [diagnosis-gates.md](./diagnosis-gates.md) §0.5 规格漂移闸门 |
| 15 | 走读/假需求验证冒充「已真演」（hook 真实环境故障漏检） | ✓（2026-08-03 真演两连教训） | §方案与文档状态 — 发布闸须真实会话真演证据（2026-08-03 ask bug / 大 payload 解析失败两连教训） |

---

## 方案与文档状态

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 未 `implementation-ready(可实现)` 或「可交给程序员」≠ 是，仍派 `程序员` 开工 | Step 与方案脱节、scope 漂移、CR 无法对齐 Mandatory Code Changes | 先 `策划` 补方案或 `方案审核` 定版 |
| 只有想法、无执行文档，直接让程序员做大功能 | 一次改太多、漏回归、无法复盘 | `策划` 写执行文档 → 方案审核 → 再程序员 |
| 把 `static-checked` 或 `claimed` 写成 `runtime-validated` | 误以为已 Unity 验证，漏跑场景 | 无运行证据则标 `not run` 或 `static-checked`；用户验证后再迁状态 |
| 跳过一轮确认直接改码 | 做错方向 | 方案审后发确认包；「准」同条开始改码（handoff §0） |
| 拆多轮确认（理解/定版/开始改码，或开窗+开始改码） | 空转 | 每个决策点只 1 包；续链用合并包 |
| 结案后只写「请说开 γ」 | 口令门 | 续链合并包 +「准」（§G） |
| 发布前仅走读/假需求验证 hook 链路（ask 权限 bug、大 payload 解析失败等真实环境故障漏检） | 机制形同虚设仍当已生效；门禁实际拦不住 | 发布闸要求**真实 Cursor 会话**真演证据（`.ai-gates/hooks-log/` 真实 DENY/ALLOW + 打点落盘）；走读仅线索（2026-08-03 ask bug / parse 失败两连教训，见 [skill-eval-checklist.md](./skill-eval-checklist.md) §I 真演记录） |
| 方案审后再问「可以开始改码吗」 | 第二轮确认 | 审过即发包；「准」后直接改 |
| 先改码再补「为什么」 | 事后作文 | 改前选型短表 |
| 「待你确认」满是 API | 误确认 | 白话现象；钉死留 Mandatory |
| 交审/开始改码无选型短表 | 无法对照 | 缺选型 → major |
| 二选一不写推荐+为什么 | 裸猜 | demand-clarification §多选 |
| Verify 失败后默认「再开 Step」且不推荐排查 | Step 堆叠、假收敛 | diagnosis-gates §0：先 Discover；未钉死根因推荐只读排查 |
| 写了【推荐】却未等用户回复就开写/改码（非 Auto 例外） | 静默代选，偷减拍板 | 须用户回复选项或「准」；**例外**见下「Auto 可跟」 |
| Auto 启用且推荐 `auto_follow: yes`、未硬停，仍发选型等人 | 空转确认，违背仅停待验 | 同条跟推荐 + 留据 `Auto采纳推荐`（diagnosis §0 / handoff §D） |
| Auto 下对硬停项（止损/fuse/异现象/规格漂移开码前/范围外扩）静默跟 | 掏空硬停 | 硬停须确认包；未「准」不得开热修/改码 |
| Auto 代选可跟推荐但交接无 `Auto采纳推荐` 留据 | 无法审计的代选 | 同条留据一行 |
| 热修失败多次仍开热修 N+1、主窗止损永远 2/3 | 热修豁免掏空止损 | 热修失败计入同一白话现象；≥2 连败须止损（[diagnosis-gates.md](./diagnosis-gates.md) §2.1） |
| 用「新切片/新 H#」清零止损 | 步骤爆炸换皮 | 按用户白话目标计数，仅 α→β 换层可清零 |
| 放行热修无合取条件（任意 fill / tube==C 一律放行） | 打穿物理口径 | Mandatory 须合取可证伪条件 |
| 首段仍 in-progress、状态已 blocked/测挂 | 下一 AI 误改码 | 首段=状态（[doc-windowing.md](./doc-windowing.md)） |
| 热修/切片已被主窗放弃引用，短窗仍留「未完成」不封存 | 下一 Agent 误以为仍可改码；「永远未完成」误解 | 命中止损/用户放弃后同条归档或标 `archived`（doc-windowing.md §热修/切片失败或回退即封存） |
| 无活跃 Mandatory / 无可改码窗的空闲枢纽长期停 `执行中/` | `执行中` 假活跃；下一 Agent 误开刀 | 空闲同条迁 **签收/**（续作再迁回执行中）；见 doc-windowing §状态分类夹 |
| 状态分类搬家手挪方案夹、不跑 `migrate-pipeline-window.ps1` | 漏改「方案文件夹」/跨链相对路径；下一窗读到假路径 | **必须** migrate；禁止手挪后只改状态字段（doc-windowing §迁移动作） |
| 文档已 `completed`/签收/失败/回退（或空闲须离执行中），夹子仍停 `执行中/` 未 migrate | `执行中` 假活跃；可迁残留堆积 | **结案检查单硬项**：终态同条 migrate（或同等）；未迁夹=未结案（handoff §E） |
| 诊断中、根因未钉死就抢先标 `archived` | 过度归档，掩盖仍在排查的问题 | 只有触发止损或用户/PM 明确放弃才归档（滥用反例 C5b） |
| 同时写 implementation-ready 与 completed | 状态撒谎 | [handoff-automation.md](./handoff-automation.md) §E |
| Discover 堆成迷你历史全文 | token 回涨 | ≤15 行，其余进 `证据/` |
| 文档已 ready、用户未「准」就改码 | 把定版当已开始改码 | handoff §0/§F |
| 方案审通过后仍拆「定版/开始改码」两轮 | 违反一轮硬律 | 过审发确认包；「准」后直接改 |
| CR 无 blocker 后不提示 README/Unity、或直接标 runtime-validated | 漏收口或夸大证据 | §C：迁 step-completed + README 一行 + 请用户测 |
| 同一 Chat 内连续多轮 **L3 方案审核** | 独立性弱 | **提示**用户新开 Chat；L3 **只读不写** |
| L3 Chat **直接修改**执行文档 | 多 Chat 结论冲突、状态被覆盖 | L3 只输出审查结论；定稿由项目经理/策划 **单 Agent** 写入 |
| 未「准」就连跑 / 把 Auto 当第五车道 / Express / Direct 开 Auto | 绕过确认或打乱 PM 判定 | Standard/Full「准」默认 Auto；Express / Direct 禁；见 [loop-engineering.md](./loop-engineering.md) |
| 用户已「准, 不 Auto」仍按 Auto 连跑后续 Step | 无视退出 | 单步模式：测签后须「做 Step N」等口令 |
| 测挂后绕过 diagnosis-gates 乱开热修/Step（或硬停仍自动跟） | 假收敛、止损被掏空 | 「测试不通过」→ diagnosis §0；仅 `auto_follow: yes` 可同条跟；硬停须「准」 |
| 验挂红无脑 `git reset --hard` / 整库硬回滚 | 毁掉诊断现场与无关改动 | 有意义评审后**定向撤**本 Step Mandatory 业务 diff（diagnosis §0.2.1） |
| 用批量回归/黄金场景绿（含项目配置场景 ID）当「本刀有意义」 | 假绿保留废刀、同 A# 死磕 | 对照 A#/可见现象/本刀假设写黑板；禁假绿冒充有意义 |
| 测挂/交审失败不写 `证据/_repair-blackboard.md` 或派修不带最近≤3 条 | 失忆式重复试错 | diagnosis §0.6；模板 repair-blackboard |
| 黑板已写「禁止再做」仍换皮重试同一手法 | 原地转圈 | CR major/blocker；先换假设或走 Discover |
| 止损或 `max_repair_rounds` 触顶后仍同 A# 推改码/热修 | 不可达目标死磕 | 【推荐】A#/口径复议（§0.7）；确认包改边界后再开刀 |
| 方案无「错题本必读」或新 lessons 行无错因/改正 | 检索不到 / 只会复述教训不会改 | 大纲+必读节；pending 填 cause/fix（lessons-learned §错题大纲） |
| 程序员未读点名错因/改正仍换皮重犯 | 大纲失效 | 必读节点名行；CR major |
| 未测进下一 Step / 未测标 `completed` | 假收敛 | 每 Step `await_human`；全部测签收才 `completed` |
| `step-completed` 待测时「本窗 Auto」清 reason 或开下一 Step | 跳过签收 | 仅 `runtime-validated` 后「本窗 Auto」可推进（预算用尽可仍带 reason） |
| 待测或预算用尽态用「做 Step N」/直接派 developer /「CR 通过即可」旁路 | 架空 Auto 门禁 | 仅合法「继续 Auto」或「本窗 Auto」；见 handoff §H |
| 预算用尽仅用「继续 Auto」推进；用「本窗 Auto」刷新 `max_repair_rounds` | 刷预算/绕熔断 | 预算用尽须「本窗 Auto」；repair 仅方案级重审+重新「准」归零 |
| 新范围仅说「本窗 Auto」就开始 | 越权扩 scope | 重新 PM +「准」 |
| TL 跳过测试却迁 `runtime-validated` / `completed` | 伪造成功 | 全局：可不测，停在 `step-completed`（handoff §E） |
| Auto 下只走 §C 不写 stop_reason/步数 | Exit Gate 失效 | §C 须叠加 Exit Gate；§H 优先 |
| stop_reason 与文档状态错配；恢复统一直迁 `in-progress` | 状态撒谎/跳过重审 | 按 loop-engineering 映射与按原因恢复 |
| 熔断重审把 Standard 误升 Full | 车道漂移 | 按**当前车道**重审 |
| Auto 跳过 Delta Spec；静默写 lessons；自动标 runtime-validated | 削弱 P1.5/证据 | 每 Step 保留 Delta/E4/人工签收；错题亦须「准」写主表 |
| 把 lessons 全表灌进派发提示词 / CORE / 每轮 system | token 膨胀、偏置审查 | 只引用命中行；见 lessons-learned §检索 |
| 自写自审冒充隔离主 CR；Auto 降 CR 档 | Maker/Checker 失效 | 非 Maker 隔离主 CR；Auto 不降档 |
| 主窗 PM 自跑验收剧本并冒充「隔离子窗已验」后抬升 `runtime-validated` | 假隔离、伪签收 | 须 Task 高规格 `mode=verify` 验收子窗；主窗不得代验抬升 |
| 验收子窗缺 `model=` / 用实现档，或验收子窗改任何仓库交付物 | 验收不可信 / 控制面漂移 | 须显式高质量 `model=`；验收只读+临时目录剧本（见 verify-dispatch） |
| Checker 自改派发工件 / 扫 `证据/**` / 用陈旧 revision 继续审 | 控制面漂移、伪独立 | 只读点名 `_…派发.md`；不符 → stale_dispatch；见 review-dispatch-lifecycle / handoff §I |
| L3 第2轮携带第1轮结论；代码复审绑定旧 diff | 复核偏置 | 第2轮独立骨架；复审绑最新 diff + blocker≤20 |
| 用方案 L3 / 同 Chat CR / 对抗 CR 替代隔离主 CR | Exit Gate 假通过 | 见共同 Exit Gate |

---

## 实现与代码审核

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 一次实现多个 Step 或超出当前 Step 范围 | CR 无法通过、回归面不可控 | 一次只做一个 Step；见执行文档 Mandatory Code Changes |
| Step N 未完成 CR，已开始 Step N+1 | 前序缺陷带入后续 Step | **同文档 Step 串行**（见 CORE §硬门禁） |
| 代码审核有 **blocker** 仍更新 README 为「最终完成」 | 文档与代码不一致，后人误信已验证 | `程序员` 修复 → 重新 CR → 再 `文档` |
| 无代码审核结论，直接写最终 README | 未审风险隐藏进版本记录 | README 标「待代码审核」或「代码审核未运行」 |
| 实现者自审并宣布「无 blocker」 | 实现偏差未被发现 | 交 `代码审核`（高风险另开 Agent） |
| Full 车道改**业务 C#**（Runtime/Editor）无 CodeGraph/CRG 仍宣布 CR 通过 | 影响面未知、回归遗漏 | **hard blocker**；安装图谱或降级车道并声明范围。**Skill/Doc-only**（无业务 C#）无图谱 → soft risk，不挡无-blocker 收口（见 [loop-engineering.md](./loop-engineering.md)） |
| 为「以后可能用到」预先加抽象层/配置项/通用化参数，本次需求不需要 | 理解成本上升、无人验证的代码路径堆积 | **YAGNI**：只实现当前需求；真正复用场景出现再重构 |
| 未检索 README/代码/同主题方案就写 Mandatory 或新开并行实现 | 重复造轮、并行实现、神类只增不减 | **复用四问**（已有→复用→少写/不写→能删）；方案审缺表/可复用却并行实现 → blocker；见 [execution-discipline.md](./execution-discipline.md) |
| 派发 `review_input_revision` 用文化敏感路径排序（如 PS `Sort-Object` 默认）或 L3 转场改了非排除节却不重生 | 假 `stale_dispatch`、审不进内容 | 路径 **Ordinal** 升序；转场只改排除三节；见 [review-dispatch-lifecycle.md](./review-dispatch-lifecycle.md) §3/§5 |
| 改动路径遗留废弃方法/字段/`using`/注释掉的死代码未清理 | 类文件越滚越大，可读性与合并冲突风险上升 | 顺手清理；不确定则在交接说明「未清理原因」 |
| 单个类/文件长期只增不减、职责混杂无人评估拆分 | 最终形成数千行"神类"，改动与审查成本集中失控 | CR 发现明显膨胀信号时标记 `major`，建议策划评估拆分方案 |
| 在已被序列化/持久化引用的枚举（`[SerializeField]`、ScriptableObject 配置、存档、网络协议）中间插入新成员且不显式赋值 | C#/Unity 枚举默认按声明顺序编号；序列化数据存的是底层 int 不是名字，插队会让所有后续成员集体错位到别的名字，编译不报错，运行时才发现旧 prefab/存档"变成了别的枚举值" | 先确认该枚举是否被 `[SerializeField]`/配置资产/存档/网络协议引用：有则只在末尾追加，或每个成员显式写 `= N`（新增可插任意位置）；纯运行时枚举（无持久化引用）不受此限制 |
| 同一 Step 内连续多次 static-checked 修复仍未做 Unity 验证，继续无限期叠加 | 无法定位具体哪次改动引入新问题，一次性测试出错后回归/排查成本指数级上升 | 达到阈值（建议 ≥3 次）须停下，交接中提示用户先测一次，确认现象后再继续叠加修复 |
| 拿「预授权 N」豁免改判定逻辑/新增状态/跨模块的 Step；或方案外新 Step 也算已预授权 | 越权改动跳过确认包，等同零确认改码 | 预授权仅限方案里已逐条列出的同物理口径参数级微调；出现漂移/新 Step 立即失效，回到逐 Step 确认（见 [loop-engineering.md](./loop-engineering.md) §1.6） |
| 交 CR 无错题本必读/黑板证据路径（或缺「无黑板（已查路径）」） | 失忆式重犯；CR 无法核对证据硬挡 | 派发/自检摘要须引用路径；缺路径 → CR **major** |
| Mandatory 触及 project-context §热路径批量回归之路径 glob，却未跑表内场景 ID（或红）仍标 `step-completed`/`runtime-validated` | 假绿结案、回归面裸奔 | 结案前按表跑批量回归 exit 0 + JSON；禁场景绿冒充 A#；无该节则本行不适用 |
| 子代理越权直落（缺 plan-lite/方案审/确认包/CR 即落盘，或超授权范围改设施） | 跳过确认包改码，等同零确认交付；授权边界失守 | 策划只出方案；落盘必经 方案审 → 确认包「准」→ 程序员 → CR；子代理派发失败回退主窗补审（标非独立）或提示手动新开 Chat；越权内容由 PM 处置（降级/撤销）并记 recovery |

## 文档、回归与归档

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 交接含「新增回归场景」但未同步 `.cursor/project-context.md` 索引 | 下一人不知最低验证步骤；误标 `runtime-validated` | 派 `文档` 追加索引表，或用户确认暂跳过并记录 |
| 改完 `.cursor/project-context.md` 回归表未运行 `sync-regression-index.ps1 -Apply` | 脚本/pre-commit 读到旧 YAML；双写漂移 | v2.1.0 起 YAML 由脚本从 MD **自动生成**，改表后跑一次 `-Apply` 即可，不再手工誊抄 |
| 无运行证据（业务 C#）或无合法 AI 验收通过（Skill/Doc）仍迁 `runtime-validated` | 功能未验即归档 | 业务 C#：用户场景证据；Skill/Doc：高规格 `mode=verify` 通过亦可 |
| 程序员小改 README 含新回归场景，却未同步索引 | 索引与 README 分叉 | 同步 `.cursor/project-context.md` 或交 `文档` |
| 用户已指定文档路径，或 project-context 已覆盖文档根，策划/周报仍擅自改到通用 `.ai-gates/Doc/` | 文档散落、用户找不到产出 | **用户指定 > project-context > 默认**（见 [doc-path-defaults.md](./doc-path-defaults.md)） |
| 未填 **交接时间** 的多 Agent 写同一执行文档 | 冲突无法裁决 | 每份交接块必填时间（见 [handoff-template.md](./handoff-template.md)） |
| 一次性中间产物（revision/hash 计算、压力测试、批量迁移脚本等）散落在 `.cursor/` 根或 `hooks-log/` | 工作区被垃圾淹没；运行时证据与中间产物混淆，发布闸证据不可信；清理需逐文件甄别 | 只放 **`.ai-gates/tmp/`**（不入库）；环节收尾整目录清空；hooks-log/ 只留运行时证据（2026-08-04 实证：98 个散落中间产物约 260 KB 需逐文件甄别；见 [execution-discipline.md](./execution-discipline.md) §工作区卫生） |
| 新建执行中窗无 `.kit-v1` / `物理口径.md` 仍定版 | 齐套门禁失效，历史豁免被误用 | 有 kit 必须同目录物理口径；缺则方案审 **blocker**（见 [doc-windowing.md](./doc-windowing.md) §新窗齐套标记） |
| 短名链接指向错误分类夹且长期未纠错 | 邻窗/收口指针漂移，下一 Agent 读错窗 | 跑 `repair-doc-crosslinks.ps1`（默认只读；`-Apply` 仅唯一命中改写；歧义只报告）→ **major** |

## 模式与 token

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 向团队用户首段直接抛 `implementation-ready`、L3、hard blocker | 非技术同事不敢用、误以为流程很复杂 | 用 **五态语义** + 用户下一步白话；内部术语仅追问时展开（见 [execution-discipline.md](./execution-discipline.md)） |
| 强制团队用户回复/阅读固定 Markdown 小节 | 新手要先学版式，违背快速上手 | **约束行为、不锁格式**；自然语言传达进度与下一步即可 |
| 团队日常主动启用 L3 多 Chat | 操作 friction，违背团队默认路径 | **TL + Full 车道** 才启用；团队默认 Standard L1/L1.5 |
| Standard L1 多 Step 未提示可选独立方案审核 | 用户不知可新开 Chat 加强方案审核 | PM 在 **你下一步** 追加可选提示（CORE §Standard 可选独立方案审核） |
| 明显 Standard+ 需求仍维持 Express | 绕过方案与 CR | PM 改判 Standard；见 CORE §Express 升级 |
| 为省事长期维持 Express 做大 refactor | 方案与 CR 缺口累积 | 命中 CORE 车道升级表则立即升级 |
| 有 `未完成.md` 仍 Read 历史全文 / 整份旧长方案 | token 暴涨，窗口化失效 | 只读未完成窗 + Mandatory-Step + 物理口径（见 [doc-windowing.md](./doc-windowing.md)） |
| Mandatory 只活在历史全文，实现时「临时翻归档」 | 顺带读入 1000+ 行 | 抽出 `Mandatory-Step{NN}.md` 后封死历史全文 |
| 向 Subagent 塞主对话长讨论或第二份长方案 | 隔离名存实亡 | 最短派发包（见 [isolated-review.md](./isolated-review.md)） |
| 诊断连续 3 次推翻仍堆 Step N+1 | 步骤爆炸 | [diagnosis-gates.md](./diagnosis-gates.md) 止损线（含热修累计） |
| 热修并入 10+ Step 主 Full 窗 | 主窗永不收敛 | 热修旁路短窗；失败仍计入止损 |
| 热修改执行面不写与另一路径关系 | 并行实现补丁永续 | §2.3 并行实现一句 |
| 并行实现并存却无「删哪条」完成定义 | 补丁循环 | 并行实现收敛闸门 |
| 为谨慎全目录 Read PressureManager | 源码 token 暴涨 | 日常先 `codegraph_explore`；审核岗先 CRG（LabSDK 子模块图） |
| 交接默认贴大段代码/Console | 对话上下文膨胀 | 短表 + 证据外置 |
| 把 CodeGraph soft budget 说成「额度已用尽」并整轮弃用 | 误导用户；退回全量 Read/Grep | 本地无付费额度；收窄 query 继续 explore（见 [codegraph-probe.md](./codegraph-probe.md)） |

## 团队使用

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 用户跳过「项目经理」直接说「程序员」「策划」 | 绕过车道判定；无 express-slice / plan-lite 即改代码 | Agent **硬门禁 #7**：同条先 `[PM]` 判车道 + **你下一步**；无 PM 结构化判定**不得**改交付物 |
| 各岗在无 PM 结构化判定时仍创建/修改交付物 | 跳过车道与审核门禁 | 各岗 SKILL §PM 门禁 硬停；只读咨询除外 |
| 主窗兼策划/程序员/CR/方案审/文档写改（有 Subagent 仍不派子窗） | 上下文共谋、模型路由失效、非独立冒充独立 | 主窗仅 PM；流水线非 PM 岗必须子窗（[model-routing.md](./model-routing.md)；**周报除外**）；降级须标「主窗执行（未开子窗 · 非独立）」 |
| 实现/审核 Task 省略 `model` 或无视 project-context §模型路由 | 落到平台默认快模型、绕过项目偏好 | 按 [model-routing.md](./model-routing.md) 解析后显式传 `model=`；换模型须新开 Task |
| 把项目专属模型 slug 写进通用 Skill | Skill 不可复用 | 偏好只进 `.cursor/project-context.md` §模型路由（[project-local-config.md](./project-local-config.md)） |
| 用户未初始化 project-context 仍期望 Express 小改核心模块 | 误判车道、漏回归 | 冷启动保守 Standard；提示 TL 按 [USER-GUIDE.md](../../USER-GUIDE.md) §第一次接入 初始化 |

## 并发与协作

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 两个 Agent 同时写**同一**执行文档状态 | 状态被覆盖、非法迁移 | 单文档串行；并行仅 **不同执行文档** |
| `代码审核` 与 `文档` 同时改同一模块 README | README 基于未审代码 | CR 无 blocker 后再 `文档` |
| 多个 L3 Chat 各自写入执行文档 | 审查记录互相覆盖 | 各 Chat 只读；项目经理单 Agent 收口写入 |

## 漂移与臆测（执行纪律）

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 未读真实代码/API 就按执行文档或记忆实现 | 调用不存在符号、改错文件、行为全偏 | 先读仓库事实；冲突则停，见 [execution-discipline.md](./execution-discipline.md) |
| 缺用户确认 / README / 代码仍「猜着做」 | silent default、返工整段 Step | **不确定则停** — 列出缺口、提问或标 **已阻塞** |
| 对话推断优先于 git / 真实文件 | 对着过期描述或幻觉 API 改代码 | 事实优先级：代码 > README > 执行文档 > 对话 |
| 方案与代码冲突时擅自选边 | 实现与仓库真相脱节 | 报差异 → `策划`/`方案审核` 或 blocked，不猜 |
| Discover 根因改判后只口头提一句就直接写代码补丁，物理口径未同步更新 | 下一个 Agent 读到的口径仍是旧判断，重复踩坑 | 先改 `物理口径.md`/A#，再开码（[diagnosis-gates.md](./diagnosis-gates.md) §0.5 规格漂移闸门） |
| 范围悄悄扩大仍维持 Express | 绕过 CR 与方案门禁 | 命中 CORE §Express 升级 立即升级并告知用户 |
| Express 简略轮 **你下一步** 只写「等待」 | 用户不知测什么、确认什么 | 须含车道理由、下一岗、五态、具体动作（CORE §Express 简略） |
| 无验收条款 A# 或 Step 未引用就定版 | 实现按「感觉」改、无法证伪 | 补可证伪 A# + `满足验收`；见 [acceptance-and-delta.md](./acceptance-and-delta.md) |
| plan-lite / 切片复述整模块原理 | Token 膨胀、与 README 双源漂移 | **delta-only**：只写相对现状变更，原理链到 README |
| Step 缺 ADDED/MODIFIED/REMOVED 仍定版 | 口径差不可审，后续 Discover 易漂 | 补 Delta Spec 三段；方案审记 blocker |
| 有 MODIFIED/REMOVED 却标 completed 不改口径 | 下一刀对着旧规格改 | 签收后先同步物理口径/A#（acceptance-and-delta §Delta Spec） |
| 整 Step 攒完才第一次编译/语义自检 | 回滚面大、CR 噪声多 | 微循环：改一段→自检→继续（developer §4.5） |
| 把微循环自检算进 §7「连续 3 次 static-checked」 | 过早逼停正当改码 | 中间自检不计；仅交审/交自检整轮累计 |
| Unity 通过后不自动落 `_lesson-pending.md` / 或未「准」静默写 lessons 主表 | 成功路径不沉淀；或污染经验库 | 准全自动：自动 pending + 问「准」；`commit-lesson-pending.ps1 -Apply`（[lessons-learned.md](./lessons-learned.md)） |
| 测挂不写 L0 却直接写 pending/主表 | 噪声进主表；根因未证 | 测挂只自动 L0；根因验证后再自动 pending |
| Discover/Mandatory 只开第一道门，等失败再开第二道 | 漏扫 ≥2 跳；R6/R8 类双门闸只改一处 | diagnosis §0.8：CG ≥2 跳 + 读码 ≥1 跳；≥2 门闸一次策略；禁只开第一道门 |
| 止损 0→1 后缺点名反思就再改码 | 重复只开第一道门；下一刀未证伪「为何上一轮不是最后一门」 | diagnosis §1.4：Mandatory/Discover 须点名门闸/调用边；空话 → major |
| **门卫≠完成**：凭「入口检查点/第一道 guard 未命中（或命中）」断言「整段兜底逻辑已/未执行」——第一道门的状态被冒充为函数整体执行状态 | 后续 guard 未遍历也被写成「已执行」证据；验收/判定/回归断言失真 | 断言「X 已/未执行」须逐道 guard 确认到出口并点名完整路径；入口拦截点命中与否 ≠ 整段执行状态；多 guard 函数整体断言不得只凭单点（单门函数除外）（见 [lessons-learned.md](./lessons-learned.md)） |


## PM 输出

| 反模式 | 典型后果 | 正确做法 |
| --- | --- | --- |
| 向团队用户展示 PM 内部字段 / `[PM]` / 摘要表 | 初级用户困惑、Token 浪费 | 内部字段 **仅 Agent 使用**；用户只看白话「你下一步」（CORE §用户可见输出） |
| Full 强制未白话提示完整流程 | 用户不知须启用 Full、误走 Standard | **你下一步** 须含「建议启用完整流程（Full）」（CORE §Full 强制 — 用户可见） |
| 策划/程序员/CR 展开 PM 内部字段 | 格式混乱、重复 Token | 仅 `[PM]` 轮完成内部结构化判定；其他岗用各岗 SKILL 格式 |

## 相关链接

- 路由与门禁：[CORE.md](../CORE.md)
- hard blocker / soft risk：[evidence-levels.md](./evidence-levels.md)
- 状态迁移：[state-machine.md](./state-machine.md)
- 执行纪律：[execution-discipline.md](./execution-discipline.md)
