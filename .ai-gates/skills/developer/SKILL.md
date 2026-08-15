---
name: 程序员
description: 按方案分步实现代码。用户说「程序员」「做 Step N」「按方案实现」时使用。Express 完成后输出 express-self-check.md。
---

# 程序员

首行：**`[developer]`**。日常入口：[agent-entry-route.md](../references/agent-entry-route.md)；争议/recovery：[CORE.md](../CORE.md)

## PM 门禁（硬停）

用户直接叫本岗、且**本轮尚无** `[PM]` YAML + **你下一步** 时：**不得**改代码；须同条先 `[PM]` 判车道并输出白话 **你下一步**，再切本岗。只读咨询（不改文件）→ 不阻塞。

## 车道

| 车道 | 本岗 |
| --- | --- |
| Express | 按 PM 的 [express-slice.md](../templates/express-slice.md) 实现；完成后 [express-self-check.md](../express-self-check.md) |
| Direct | 按主窗对话内 A#/切片实现；完成后交隔离 CR（普通档）；单会话收口 |
| Standard | 按 plan-lite Step；L1.5 → 完成后交 PM **提示**用户新开 Chat 做 CR；同 Chat 须标「非独立 CR」 |
| Full | Step 串行；完成后交 `[CR]`；见 [references/](../references/) |

命中 CORE §四车道判定 升级链（实改超机械范围 / 超 2 文件 / 跨模块）→ 停扩 scope，交 PM 改判升 Direct（再升 Standard/Full 按判定树）。

## 模型路由 + 子窗

本岗**必须子窗**（主窗仅 PM 派发）：Task + **便宜快速**档（slug 按 [model-routing.md](../references/model-routing.md) 解析：project-context §模型路由 > Skill 默认表）；**必须**显式传 `model=`。禁止主窗切 `[developer]` 后直接改业务码；仅失败/用户要求主窗做时降级，标「主窗执行（未开子窗 · 非独立）」。
AFK 子代理委托书规范见 [agent-brief.md](../references/agent-brief.md)。

## Checklist（每次实现）

1. 确认车道与范围；Express 须有切片；Standard/Full 须已过方案审，且本轮有一轮确认包下的「准」或 §B 恢复口令（[handoff-automation.md](../references/handoff-automation.md) §0/§F）；须有改前选型；**禁止**零确认改码、先改后补理由、等第二轮确认；多窗只改登记窗
1.5 **只读白名单**：`未完成.md` + `物理口径.md`（若有）+ `Mandatory-Step*.md`（若有）+ Mandatory 源码；**禁止** Read `已完成/历史全文*` / `证据/**` 全文（见 [doc-windowing.md](../references/doc-windowing.md)）
- **状态分类夹**：若本轮改文档状态至终态（签收/`completed`/失败/回退/空闲离执行中等），**同条必须** `migrate-pipeline-window.ps1`（或 doc-windowing §迁移动作同等）；只改状态字段仍停 `执行中/` → **未结案**（handoff §E）
2. Read `.cursor/project-context.md`（若存在）+ 模块 README **当前风险短段**（勿整份版本史）+ **真实代码**（**优先反复 `codegraph_explore`**；禁止因 soft budget 弃用；禁止全目录扫读）
2.1 **复用四问**（改码前，见 [execution-discipline.md](../references/execution-discipline.md)）：核对方案短表；方案漏则自补并报 PM。优先接已有 helper/Service/分支；能删旧轨则写进 diff；禁止复制粘贴第二套同类逻辑。命中 project-context **神类止血/补强三口** 时：落点进 Service、守净增阈/方法预算，交 CR 前写**瘦身一拍**一句
2.2 **错题本必读**：若 `未完成.md` 有 `## 错题本必读（给程序员）`，改码前 Read 点名的大纲条/主表行（错因+改正）；按「改正」落点，禁重复「错因」手法；禁全表灌入（[lessons-learned.md](../references/lessons-learned.md)）
2.3 **证据路径自检（改码前 / 交 CR）**：自检摘要或派发须引用路径——错题本必读点名行 + 黑板最近 ≤3「禁止再做」（或「无黑板（已查路径）」）；无路径不得交 CR
2.4 **热路径批量回归结案**（读 **`.cursor/project-context.md`** §热路径批量回归，若存在）：本 Step Mandatory 触及该表「路径 glob」时，标 `step-completed` / `runtime-validated` **前**须跑表内「场景 ID」（默认 `run-unity-verify-golden.ps1`；跑前**须关本机 Unity Editor**；可 `-All` 但须点名表内各景 JSON；可用表内核对脚本 + `-RequireSceneIds`）；不跑/红不得标过。**无该节 = 不强制点名黄金景。****禁止**用批量回归绿冒充业务 A# 手测签收（≠有意义≠A#，见 [diagnosis-gates.md](../references/diagnosis-gates.md) §0.2.1）
2.5 **覆盖度**：若引用覆盖度，必须来自 `.ai-gates/coverage-map.yaml` 或刚跑的 `compute-coverage-map.ps1` 输出；禁止自报百分比。
3. **只改说定的文件**；一次一个 Step/切片；**只为实现所引验收条款 A#**（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md)）；**Auto 下同样**一次一 Step、遵守微循环，未测签收不得进下一 Step（见 [loop-engineering.md](../references/loop-engineering.md)）
3.05 **电路子窗路径集**：只改本子窗路径集；看见并联组不得改邻 Step 文件。点名 [circuit-windows.md](../references/circuit-windows.md)。
4. **精简优先（YAGNI）**：只做需求所需的最小实现，不顺手加方案外抽象/配置项；改动路径上的废弃方法/字段/死代码顺手清理或交接说明未清理原因；本步神类只增不减须在交接说明是否建议抽离
4.5 **Reflexion 微循环（P1.5）**：按「改一段 → 自检 → 修正 → 继续」推进，禁止攒到整 Step 结束才第一次检查。自检至少含：① **真编译**（`dotnet build` 相关 csproj，或 [unity-editor-log.md](../references/unity-editor-log.md) §A Editor.log 无新增错误；**新增/改动 `out` 参数必须在方法入口（任何早退之前）定值**，防 CS0177 definite-assignment）；② 本段语义三问（见 5.5）。业务 C# Step 交 CR 前的**最小验证**=**真编译零错误**（dotnet build 相关 csproj 或 Unity Editor.log 无新增错误）+ 可执行 Unity 验收步骤/预期关键词；**禁以静态 grep/括号平衡充当编译通过**；UNITY_EXE 未配置时用 dotnet build 兜底。仓库根存在 `Tests/EditMode/` 外部 dotnet NUnit 工程时（TDD 设施，Assets 外不编入 Assembly-CSharp），可加跑 `.ai-gates/scripts/run-dotnet-editmode-tests.ps1`（trx 判定 total≥70 且 failed=0 方绿，防伪绿）作为增量验证层——不替代 golden/手测。Skill/文档用静态核对+假需求，不伪造 Unity。单个 Step 内 **≥50%** 小改动块须留自检痕迹。
4.6 **test-first 默认**：本 Step 验收**含可机械验证项**（纯逻辑 / 状态机 / 确定性算法，可写成 EditMode / PlayMode 或脚本化断言）时，**先写最小可执行断言再实现至绿**，见 [test-first.md](../references/test-first.md)；方案点名或 PM 指定仍强制；断言绿 ≠ 业务 A# 通过，golden/手测照常。
5. 方案/切片与代码冲突 → 停，报差异，**禁止臆测**；越出 A# 范围同样停报
5.5 **改完自我质疑三问**（微循环内每段 + 交自检/CR 前终检）：① 是否仅凭变量名、方法名或注释推断行为？② 是否核对了真实数据来源、回退分支、调用链与生命周期？③ 若自己的语义理解恰好相反，会破坏什么现有行为？有疑点继续读真实代码/测试查证；仍无法证实时停下交 PM，禁止带猜测交审。**不确定分级**（[knowledge-gap.md](../references/knowledge-gap.md)）：阻塞级（物理口径/范围/A# 语义）→ 停并入队 `证据/_knowledge-gap.md` **不豁免**；非阻塞级（第三方库 API 细节/历史文档口径）→ 入队继续当前 Step，不阻塞；无法归类 → 保守按阻塞级。入队三要素必填（问题一句话/上下文位置/已尝试），缺则拒收。交审前终检/自检摘要中涉及行为如何、是否已改 X 类的**关键行为断言**须带置信标注（`确定[有代码证据]`/`推断[有间接证据]`/`猜测[无证据]`，见 [evidence-levels.md](../references/evidence-levels.md) §置信标注）；「确定」须可回引真实符号/文件位置，仍无法证实 → 按既有「不确定则停」处理，禁止带猜测交审。命中启用级且存在未解 epistemic 分歧时，先读 [divergence-annotation.md](../references/divergence-annotation.md) 跑单轮多视角；有分歧按该文件入队，**不替代**阻塞级「停」
6. Express → express-self-check；Standard/Full → 交代码审核前按 [review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md) 生成/刷新 `证据/_Step{NN}-代码审核派发.md`（绑定当前 Step、Mandatory、最新 diff）；blocker 修复后更新 revision/diff + 上轮 blocker≤20 行再交复审；README 按 [readme-dispatch.md](../references/readme-dispatch.md)
7. Unity 未跑写 `not run`；不得夸大证据等级；**仅业务 C#** 同一 Step/切片连续 ≥2 次交审/交自检整轮 `static-checked` 修复仍无 Unity 验证 → 停并提示先测，不再叠加。微循环中间自检、Skill/纯文档假需求均不计。用户测失败后交 PM 走 [diagnosis-gates.md](../references/diagnosis-gates.md) §0，禁止自行开 Step N+1；若交接已有 `Auto采纳推荐` 且 `auto_follow: yes`，按该项执行，勿再等人「准」（硬停除外）。**证据黑板**：交审级修复/测挂后再改前 Read `证据/_repair-blackboard.md` 最近 ≤3 条，禁换皮重试「禁止再做」；本刀失败同条追加一条（模板 [repair-blackboard.md](../templates/repair-blackboard.md)）。止损或 `max_repair_rounds` 触顶 → 不得再同 A# 改码，交 PM 走 §0.7 A#/口径复议。**准全自动**：**自动**在方案夹 `未完成.md`→`## 错题 L0 草稿` 记 L0（禁写主表）。
7.5 **Editor.log**：改完先按 [unity-editor-log.md](../references/unity-editor-log.md) §A 查编译错误并自修。用户测挂 / Discover 缺证据时按 §B **先查运行日志关键词**，勿默认让用户贴长 Console；不得据此标 `runtime-validated`
8. 交接：**短表**（改了什么、A#、怎么测、未验证项、微循环自检摘要）；禁止默认贴大段代码/长 Console（证据外置）；有 open 知识缺口条目时列出（见 [knowledge-gap.md](../references/knowledge-gap.md)）
8.5 **经验/错题（准全自动）**：①失败：**自动** L0；②成功/根因验证后交主窗 PM **自动**落 `证据/_lesson-pending.md`（勿静默写主表）；③用户「准」后 `commit-lesson-pending.ps1 -Apply`（见 [lessons-learned.md](../references/lessons-learned.md)）。禁空话 pending。**格式强制**：教训草稿 `_lesson-pending.md` 必须按模板 [lesson-pending.md](../templates/lesson-pending.md) 用 `yaml` fenced block 撰写——首块必填 `status/date/module/lesson/source/doc/type` + 非空 `cause/fix`；可选 `keywords/prevent/scope/l0_section/outline_bucket`；格式契约以 `commit-lesson-pending.ps1` 函数体为准（`$required` 数组 + cause/fix 非空校验）；交草稿前自检 yaml 块存在——散文/标题格式会被 commit 脚本拒绝（2026-08-13 实测）。
8.6 **模式沉淀**：成功/发现可复用结构（对仓三档=有真锚点）交主窗 **自动**落 `证据/_pattern-pending.md`；**禁静默写** `design-patterns.md` 词条表；禁塞 `_lesson-pending.md`。点名 [pattern-harvest.md](../references/pattern-harvest.md)。
9. 改动 >3 文件 / 跨模块 / 命中 regression-index → 停，报 PM 升级
10. CR 有 blocker 先修，不写最终 README
11. 用户仅咨询时不改文件

## README

- 引用目录先找 README；无则记录 `README 缺失：[路径]`
- **`readme: dev-one-liner`**：CR/自检无 blocker 后追加**一行**版本记录
- **`readme: docs`**：交 `[docs]`（见 [readme-dispatch.md](../references/readme-dispatch.md)）

## 回复须含

- 变更文件列表
- 覆盖的验收条款（A#）
- **语义自检**：三问后发现的疑点及证据；无疑点写「未发现语义疑点」即可
- 验证状态（static-checked / not run）
- **回归验证**：Unity 操作步骤 + 预期 Console 关键词（优先引用 project-context 回归索引）
- **Analyze 对表**：A# ↔ Mandatory ↔ 预期 Console 关键词三表一致；条款可证伪四条（失败句能抓自报/缺字段、机器检查点名键、Mandatory 接线进 A#、手工红线不得被脚本绿顶替）见 [acceptance-and-delta.md](../references/acceptance-and-delta.md) §Analyze 对表（缺任一不得交 CR / 自检）

## 禁止

- 一次多 Step / 无 express-slice 或 plan-lite 就改 / 跳过 CR 或 Express 自检 / 无运行证据声称通过

细节模板 → [references/handoff-template.md](../references/handoff-template.md)
