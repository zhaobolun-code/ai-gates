# 低风险转场自动化（一轮确认 · 强自动）

> 权威：本文件。砍机械转场与**多余确认轮次**，**不**砍用户拍板与 Unity。
> 与 [demand-clarification.md](./demand-clarification.md)、[diagnosis-gates.md](./diagnosis-gates.md) §0 同时生效。
> **用户拍板口令**：默认只教 **「准」**（英文：`approve`；同义：`按推荐`；旧口语「听你的/开干/做吧」仍可识别，但确认包正文禁止再写这些口语）。口令等价：**`准` = `approve`**。

## 0. 一轮确认硬律（强制 · 最高优先）

**每个决策点**对用户最多发 **1 条确认包**；用户一句「准」/`approve`（或同义）后，**同条回复内**自动做完该决策点的全部手续。

| 决策点 | 唯一确认包 | 「准」/`approve` 后同条自动 |
| --- | --- | --- |
| 开始改码（含 Express / Direct） | §一次确认包（理解+选型+开始改码） | ready → in-progress → `[developer]` 改码 |
| 续链开下一窗 | §续链合并包（开窗+本步方案+开始改码） | 建窗 → 写 Mandatory → 方案审（若需）无 blocker → 改码 |
| Verify 失败选型 | §0 多选（推荐+为什么） | 按推荐派 Discover/热修/止损/开窗 |
| 需求歧义澄清 | ≤3 条追问（条件触发） | 按答或「你决定」判车道 |
| 知识缺口 open 条目（窗内 `证据/_knowledge-gap.md`） | **并入**当轮确认包批量追问（不另开一轮） | 用户答后标 `answered` 归档；阻塞级仍须停（入队不豁免） |

**确认包发出前（强制 · PM）**：Read 当前窗 `证据/_knowledge-gap.md` 的 **open** 条目；有则**随确认包正文批量**列出待澄清项（三要素齐全才有效），**禁止**另开第二轮只问缺口；细则 → [knowledge-gap.md](./knowledge-gap.md)（硬律：阻塞级停 + 入队；禁「已入队」冒充闭环）。

**禁止**（同决策点内）：

- 拆成「理解正确 → 定版 → 开始改码」或「开窗确认 → 再改码确认」
- 「请说开 γ」或「请再说开干/做吧」等口令门（确认包只写「准」/`approve`）
- 「准」/`approve` 后再追问同一意图
- 零用户句静默改码 / 静默开下一窗改码

**不算「确认轮」**（须保留）：Unity 实测、方案审/CR（Agent 内部岗）、只读排查写草稿。

**方案审与用户确认的顺序（钉死）**：

```text
写 Mandatory + 选型短表 → 方案审（Agent）→ 无 blocker → 发一次确认包 → 用户「准」→ 同条改码
```

禁止：先问用户理解/开始改码，再交方案审；禁止方案审通过后再拆第二轮用户确认。
一次「准」后无 blocker 的实现交回接线见 **§H**（立即派 CR；禁止再发用户确认包）。

## F. 一次确认包 → 定版并开始改码

**前置**：Express 已有一句话切片（PM 判定 + 一句话 A#）；或 Direct 已有对话内 A#/切片；或 Standard/Full 方案审无 blocker + 选型短表已写；**且**已 Read 窗内 `证据/_knowledge-gap.md` open 条目（有则写入确认包批量追问，见 §0）；且已发出一次确认包。

**用户本轮（默认教）**：`准` / `按推荐`
**退出 Auto（Standard/Full）**：`准, 不 Auto` / `不要 Auto` / `单步`（须显式；禁止把沉默当退出；兼容旧写「准但不 Auto」）
**兼容识别（不写入确认包正文）**：旧口语「听你的」「开干」「做吧」；以及中断恢复时的 `做 Step N`

**同条自动**：

1. `implementation-ready`，`可交给程序员`=是
2. `in-progress`
3. Standard/Full：默认启用 Auto（§H；`auto_steps_done=0`），除非用户用了退出句；Express / Direct：**不**启用 Auto
4. `[developer]` 立即改码（仅当前 Step / 登记窗）：**必须** Task 子窗，并按 [model-routing.md](./model-routing.md) 解析后的首选 slug **显式**传 `model=`（project-context §模型路由优先）

## G. 续链合并包 → 开窗并开始改码（禁止拆两轮）

**触发**：本窗已签收，且仍有明确下一刀（β→γ 等）。

**同条必须**：发 **续链合并包**（见 demand-clarification §续链合并包）——开窗目标 + 本步方案选型 +「准→开窗并改码」。
**禁止**只写「请说开 γ」；**禁止**先开窗确认、再另发改码确认。

**用户「准」后同条自动**：

1. 建下一窗 / 写 Mandatory（含选型短表）
2. 需方案审 → **同条**过审；无 blocker → 直接 §F 步骤 1～3（**不再**问用户）
3. 有 blocker → 只修文档；若选型**实质变更**才再发 **1** 条新确认包；纯措辞修复 → 修完直接改码，不重问

## A. 方案审通过 → 自动发一次确认包

**触发**：方案审无 blocker + 选型短表已写。
**自动**：Read 窗内 `证据/_knowledge-gap.md` open 条目 → 发出一次确认包（open 条目随包批量问用户，不另开一轮）。
**不要**：只迁 ready 干等「请再回准」。
**不自动**：改码、runtime-validated。

## B. 中断恢复口令（仅恢复用 · 非默认）

仅当文档已 `implementation-ready`、**上轮确认包已确认过**但中断未改码时：`准` / `做 Step N` → 同条 `[developer]`。
**默认路径禁止**依赖本口令；禁止把 §B 当成第二轮确认。

## C. CR 无 blocker → 自动收口

**原则**：能 AI 测则高规格子窗验，不能再人测。

1. 迁 `step-completed`（未验不得 runtime-validated）
2. 首段改为「禁止再改码；待验」
3. README 一行或派 docs
4. **Exit 分支（机械）**：
   - **热路径批量回归义务（叠加）**：若 `.cursor/project-context.md` 有 **§热路径批量回归**，且 Mandatory 触及表内路径 glob → 标 `step-completed` / `runtime-validated` **前**须表内场景 ID exit 0（JSON；跑前关 Unity Editor）；不跑/红不得标过；**禁**批量回归绿冒充业务 A#（≠有意义评审）。无该节则本条不触发。
   - **命中 AI 验收**：Mandatory **无**业务 C#（路径规则见方案物理口径#0：仅看将改路径，文档提及 `.cs` 名不算）**且**「Unity 验证」trim 后大小写不敏感精确∈{`无`,`N/A`,`Skill/Doc-only`}，**且** verify 派发齐套已存在（lifecycle `mode=verify` + `templates/verify-dispatch.md` + 模型表「验收/verify」行）→ 主窗 PM **必须**落 `证据/_Step{NN}-验收派发.md` 并派高规格验收子窗（`mode=verify`，显式 `model=` 高质量档；剧本=本 Step Unity 验证+Regression；子窗禁改任何仓库交付物）。**禁止**只写 `await_human reason=unity_test` 干等。派发前可瞬态 `stop_reason=await_verify reason=ai_static`（子窗返回后消）。通过≡「测试通过」走 §E 同条抬升+Auto 续；不通过≡测失败（diagnosis/L0）。
   - **失败可证伪（Skill/Doc-only）**：Skill/Doc-only 已命中 AI 验收 → **必须派 verify**；只写 `await_human reason=unity_test` 干等=失败。禁止把 AI 静态验收扩到业务 C# 冒充 Play。业务 C# 机械项走 [test-first.md](./test-first.md) + 本条命令，禁止「等人看见 / 口头过」顶替机械项绿。
   - **未命中 / 不确定是否业务 C# / Unity 字段缺失·未知·非免测集合 / 齐套不存在** → `await_human reason=unity_test`（**你下一步**：请 Unity 测；此为验证，非方案确认轮）；**禁止**派 AI 验收抬升。

**Auto 启用时（强制叠加）**：除上列外，必须同时执行共同 Exit Gate / [loop-engineering.md](./loop-engineering.md)：**`auto_steps_done +1`** 后只写**一个** `stop_reason`——命中且派验收前可瞬态 `await_verify reason=ai_static`；人测路径未耗尽预算 → `await_human reason=unity_test`；已耗尽 → `await_human reason=max_auto_steps`。文档状态均为 `step-completed`（含瞬态 `await_verify`）。禁止只走本节简化收口而不写 stop_reason/步数。**优先级**：Exit Gate / §H **优先于**本节省略路径。

## D. Verify 失败 → 选型或 Auto 跟推荐

迁 `blocked`、改首段；按 [diagnosis-gates.md](./diagnosis-gates.md) §0（含再改码前 **有意义评审** §0.2.1）选出【推荐】并标注 `auto_follow`：

1. **Auto 启用**且推荐 `auto_follow: yes`（未命中硬停）→ **同条**采纳【推荐】执行（Discover / 范围内热修或下一刀）；交接留据 `Auto采纳推荐：{项}（未等人确认 · 未命中硬停）`；**禁止**再发选型确认包等人。该刀仍走 Exit Gate（待验），自动跟≠免验。
2. **非 Auto**，或推荐 `auto_follow: no` / 命中硬停白名单 → 发 **1** 条多选（推荐+为什么）；「准」= 采纳推荐。禁止未选就开始改码/热修 N+1。
3. 【推荐】请你补测 → 一律 `await_human`（人测停点），不「跟过」补测。

## E. `completed` 证据门

须用户签收 + 证据等级合规。**全局**：TL/用户选择不测 → 可停在 `step-completed`（保持已选 `stop_reason` 若有），**任何车道**不得据此迁 `runtime-validated` / `completed`（与 MAINTAINER「Unity 人工选择」对齐：可不测，不伪造成功签收）。禁 ready+completed 双写。
若本步 Delta Spec 含 MODIFIED/REMOVED：口径/A# 未同步前**不得**标方案 `completed`（可保持 `step-completed`）。

**结案检查单硬项（迁夹）**：文档状态进入终态（`completed` / 用户签收结案 / 止损·放弃→失败夹 / 回退夹 / 空闲枢纽须离执行中）时，**同条必须**跑 `migrate-pipeline-window.ps1 -DocFolder … -ToCategory …`（或 doc-windowing §迁移动作同等：Move + 改写「方案文件夹」+ 链修复）。**禁止**只改状态字段仍停在 `执行中/`；未迁夹 → 视同**未结案**（PM 不得宣称收口）。
**Express 落盘**：若已建分类夹（不论有无 `未完成.md`），终态 / 放弃 / 空闲离执行中同样适用上款迁夹硬项。未迁夹不得写「Express 已收口」。半截（只有 slice 的执行中窗）→ 同条迁 **停写/** 或删空壳，见 [doc-windowing.md](./doc-windowing.md) §与 Express。

## F. 用户「测试通过」→ 经验提议 + 口径提示 + 效果一行（P1.5）

**触发（成功）**：用户回复「测试通过」（或等价签收）**或** §C 命中路径下 AI 验收子窗通过，且无未解 blocker。通过≡测试通过抬升（Skill/Doc 亦可=`runtime-validated`；不删人测路径）。
**触发（失败 · 并列）**：测失败 / Verify 失败 / AI 验收不通过 → **自动**写方案夹 `未完成.md`→`## 错题 L0 草稿`；**同条追加** `证据/_repair-blackboard.md`（无则按 [repair-blackboard.md](../templates/repair-blackboard.md) 创建；diagnosis §0.6）；根因验证后自动 `_lesson-pending.md`（须「准」写主表）。细则 → [lessons-learned.md](./lessons-learned.md)。止损/`max_repair_rounds` 触顶 → 【推荐】A#/口径复议（§0.7），禁同 A# 续烧。
**自动（成功）**：
1. 抬升证据为 `runtime-validated`（仅本 Step/切片范围）。
2. **自动**落 `证据/_lesson-pending.md`（成功经验）；主窗问「准」；「准」后 `commit-lesson-pending.ps1 -Apply`（禁静默写主表）。
3. **自动**追加效果一行：`append-pipeline-outcome.ps1`（`event=step_pass`；填 `verify_fails` / `rounds_to_pass` / `first_pass` / `why_multi` / `repair_rounds`）。失败则手工 JSONL，**不阻塞签收**。见 [pipeline-outcome-log.md](../templates/pipeline-outcome-log.md)。
4. 按 Delta Spec 提示物理口径/A# 需改句子；有 MODIFIED/REMOVED 则列入待办后再结案。
**结案 / 止损封存**：迁 `completed` 或失败夹时再 append 一行（`close` / `stop_fail`），避免同窗重复瞎记时可只保留最终 `close`。**同条须完成 §E 迁夹硬项**（`migrate-pipeline-window.ps1` 或同等）；未迁夹不得在交接写「已结案」。
**逆向总结典故（归档压缩提名）**：`completed` 或失败封存（含止损）**且**同条已 migrate：若窗内有改前选型三格（【本步方案】【为什么】【不选的】）→ 加载并跑 [reverse-allusion.md](./reverse-allusion.md)；若无三格 → 整段跳过（禁止补跑逆链、禁止补写 why）。空闲枢纽迁签收不跑（本条不挂 §E 空闲迁夹）。禁止每个终态（含空闲）必跑。
**兑现勾选**：同条核对 [retrospective-metrics.md](./retrospective-metrics.md) §每窗兑现清单 1–6；交接可写 `兑现：1✅…`（半页模板 → [window-fulfillment-halfpage.md](../templates/window-fulfillment-halfpage.md) / USER-GUIDE §半页备忘）。
**不自动**：静默改 lessons 主表 / 静默改 Skill；测失败同条写 L1。
**Auto / §H 叠加（预算用尽）**：若当前为 `await_human reason=max_auto_steps` 签收，本节仍触发 E4，但**必须**保留该 `stop_reason` 并迁 `runtime-validated`；**禁止**本节逻辑清除 reason 或等价「继续 Auto」续跑下一 Step。字段冲突时 **§H 优先**。

## H. Auto 连跑（Loop Engineering）

> 权威细则：[loop-engineering.md](./loop-engineering.md)。本节为 handoff 接线；**不**改写 §0 / §G / 一次确认包 / 上节经验提议正文职责。
> Auto =「准」之后的执行模式，**不是**第五车道；Express / Direct **不启用** Auto。

### 启动

Standard/Full：确认包【推荐】「准」→ **默认本窗启用 Auto**（须附一句「不 Auto 会怎样」+ 退出口令）。用户回「准」即启动；回退出句则单步（无 Auto）。**禁止**「准」后再单独问一轮是否 Auto。Express / Direct **不**启用（Direct 默认单会话不落盘、不启用 Auto；需连跑 → 升 Standard 落盘后按 §H，交接载体 = plan-lite `未完成.md` + 八段 handover）。启动时 `auto_steps_done=0`，`repair_rounds=0`。

### 方案 A（每 Step）

实现 + **隔离主 CR** 无 blocker → `auto_steps_done +1` → 按 §C Exit 分支写**唯一** reason：命中 AI 验收 → 派验收子窗（可瞬态 `await_verify reason=ai_static`，**禁止**只写 `unity_test` 干等）；未命中/不确定 → `< max_auto_steps` → `await_human reason=unity_test`；`≥` → `await_human reason=max_auto_steps`；文档均为 `step-completed`。**禁止**未验改下一 Step；**禁止多 Step 攒批再验**。

**用户停点**：待验 / AI 验收 / `max_auto_steps` / diagnosis 硬停。Auto 下**禁止**在实现↔CR 之间或可自动跟的测挂推荐上再发确认包。
**立即派 CR（准后无 blocker）**：一次「准」后无 blocker，实现子窗交回须**立即派 CR**；中间**禁止再发用户确认包**。禁止教「请先测再让我派 CR」。禁止只写口号、禁止第二套 Auto。权威只落本节（§0 可互指一句；禁止写进 §F）。

### 口令

| 口令 | 效果 |
| --- | --- |
| **「本窗 Auto」** | 仅已批准范围启动/重启/预算用尽后推进；步数重置为 0；**硬前置**推进下一 Step 时文档已是 `runtime-validated`（可仍带 `reason=max_auto_steps`）；**禁止**在 `step-completed` 待验时清 reason/开下一 Step；不得新范围、不得重置触顶 `repair_rounds` |
| **「继续 Auto」** | 仅普通待验签收后（已 `runtime-validated`、非 `max_auto_steps`）；**不重置**计数；预算用尽时**无效** |
| 「测试通过」同条 / AI 验收通过 | 非预算用尽可续跑下一 Step；预算用尽保留 reason，须「本窗 Auto」 |
| 新范围 | 重新 PM +「准」 |
| 「测试不通过」/ AI 验收不通过 | §D + diagnosis-gates §0：追加黑板；可自动跟 → 同条跟推荐（留据，须带黑板≤3 条）至再次待验；硬停/触顶 A# 复议 → 确认包等人 |

**旁路禁止**：Auto 启用且处于 `step-completed` 待验，或 `runtime-validated + reason=max_auto_steps` 时，禁止「做 Step N」、直接派 developer、§B 恢复口令、「CR 通过即可开下一 Step」。

### stop_reason ↔ 文档状态

| stop_reason | 文档状态 |
| --- | --- |
| `completed` | `completed`（须全部 Step 已验签收且剩余 0；无结案/TL 跳过例外） |
| `blocked` / `fuse` | `blocked` |
| `await_verify reason=ai_static` | `step-completed`（派验收前瞬态；子窗返回后消） |
| `await_human reason=unity_test` | `step-completed` |
| `await_human reason=max_auto_steps` 签收前 | `step-completed` |
| `await_human reason=max_auto_steps` 签收后仍有 Step | `runtime-validated`（保留 stop_reason） |
| `await_human reason=discover/replan/scope_change/lane_upgrade` | `blocked` |

### 恢复（摘要）

- 普通签收 + 有下一已批准 Step：`step-completed → runtime-validated → in-progress`（清当前 stop_reason）
- 预算用尽签收：`→ runtime-validated` 保留 reason；仅「本窗 Auto」后清 reason 进下一 Step
- `blocker_kind=implementation`：解除 → `in-progress(原 Step)` + 重做隔离 CR
- `blocker_kind=plan` / discover 等：`blocked → review-pending → 按当前车道重审（Standard 不升 Full；Full 才 L3 两轮）→ 重新「准」→ implementation-ready → in-progress`
- `fuse reason=max_repair_rounds`：同上方案级链；同条归零留据；口令不得重置计数
- 修复轮：进 Step=0；初实现/初 CR 不计；CR blocker 后、下一次交审级修复前 +1；第 2 轮后仍 blocker → fuse，禁第 3 轮

### 禁止（Auto）

自动 runtime-validated；自动开热修/新窗；自动改口径；静默 lessons；跳过 Delta Spec；CR 降档；自写自审冒充隔离；待验「本窗 Auto」或旁路口令进下一 Step；用「本窗 Auto」刷 `max_repair_rounds`；命中 AI 验收却只写 `unity_test` 干等。

## I. 复核派发转场（方案 / 代码）

> 算法与权限权威：[review-dispatch-lifecycle.md](./review-dispatch-lifecycle.md)。本节**只**钉岗位谁写/谁读工件；**禁止**削弱或覆盖 §H Auto、§C Exit Gate 叠加、经验提议节预算 reason、§E 全局 TL 规则、旁路禁止。

### 转场（含验收 · 强制）

1. **方案首次交审**：PM/planner 生成并保存 `证据/_方案审核派发.md`（`mode=plan`，`round=1`）后再派 plan-reviewer；Checker **只读** findings，**无写权**。
2. **方案 blocker / 实质修订后**：Maker 修目标 → 重算 `target_revision`/`review_input_revision` → 去重压缩 `blocker_regression`（≤20 行）→ L3 有效轮次清零 → 重生第1轮工件 → 再派新 Checker。排除三节变更与同输入 1→2 切轮不清零。
3. **代码交 CR / 复审**：developer（或 PM）生成/刷新 `证据/_Step{NN}-代码审核派发.md`，绑定当前 Step、Mandatory、最新 diff；blocker 修复后更新 revision/diff + 上轮 blocker≤20 行再开隔离复审。可选对抗使用独立 `mode=adversarial` 工件，**不可替代**隔离主 CR。
4. **验收/verify**：齐套见 [review-dispatch-lifecycle.md](./review-dispatch-lifecycle.md) `mode=verify` + [verify-dispatch.md](../templates/verify-dispatch.md) + 模型表「验收/verify」行；**强制派验收接线**见 §C / Exit Gate（须齐套已存在；能 AI 测则子窗，不能再人测）。

### L3 第1→第2（仅 PM/planner）

第1轮无 blocker → **PM/planner** 重算 `review_input_revision`：不一致则清零重生第1轮；一致才记 1/2、递增 `dispatch_revision`、同工件切 `round=2`（骨架不含第1轮结论）并派**新**独立 Checker。Checker **禁止**自改/自切工件。

### 岗位对照（增补）

| 岗位 | 派发职责 |
| --- | --- |
| planner / PM | 生成/优化方案工件；验 revision；切第2轮；命中时生成验收派发并派 verify 子窗 |
| plan-reviewer | 先读点名方案工件；只返回 findings |
| developer | 生成/刷新代码 CR 工件（含修复后） |
| code-reviewer | 先读点名代码/对抗工件；只返回 findings；Skill/Doc soft risk 见本岗 SKILL |
| 验收子窗（`mode=verify`） | 先读点名验收工件；只读剧本验收；交通过/不通过+退出码；**禁改**任何仓库交付物 |

## 收口模板

**开始改码：**

```text
请一次确认（通过后定版并开始改代码）：
【核心理解】…
【本步方案】… 【为什么】… 【不选的】…
【推荐】「准」→ 定版 + 同条改码，且本窗默认 Auto（实现→CR→待测；每 Step 仍要你测/签收）。
【若不要 Auto】回「准, 不 Auto」→ 只做当前 Step；测签后须再说「做 Step N」。
【不 Auto 会怎样】不会自动连跑后续 Step；多 Step 要多次开口令，节奏更慢。
（Express 切片确认包：无上列 Auto 句；「准」只改本切片。）
（仅当接下来 N 个 Step 都是同一物理口径的参数级微调时才可选带：
【若要预授权同类 Step】回「预授权 N」→ 这 N 个 Step 不再逐个发确认包，仍逐个 Unity 测签收；
出现方案变化/口径漂移立即失效。见 loop-engineering.md §1.6。）
```

**续链（合并 · 禁止拆开）：**

```text
本窗已验收。【续链一次确认 — 开窗+本步方案+开始改码】
【本窗结果】…
【推荐下一步】开 γ：… 【为什么】… 【不选】…
【本步方案】… 【为什么】… 【不选的】…
【推荐】「准」→ 同条开窗并改码，且默认 Auto（不必再说开 γ）。
【若不要 Auto】「准, 不 Auto」→ 只开窗做当前 Step。
【不 Auto 会怎样】后续 Step 须再开口令，不会预算内连跑。
```

## 岗位对照

| 岗位 | 动作 |
| --- | --- |
| 方案审 | 无 blocker → 提示发一次确认包；查选型；禁止要求用户再确认一轮才定版 |
| PM / 策划 | 只发一轮包；**确认包前** Read 窗内 `_knowledge-gap.md` open 并批量问用户（§0）；确认包教「准」；Standard/Full 默认 Auto 并写退出/后果；「准」走 §F/§G；禁口令门、禁拆轮；遵守 §H |
| 程序员 | 仅确认后改码；须有改前选型；Auto 下一次一 Step，待验不进下一 Step |
| CR | §C（Auto 时叠加 Exit Gate / §H；命中则提示派验收，禁只写 unity_test 干等） |
| 验收/verify | §C 命中 → PM 派高规格子窗；通过≡§E 抬升；不通过≡测失败 |
| Auto 连跑 | §H + [loop-engineering.md](./loop-engineering.md) |
| 复核派发 | §I + [review-dispatch-lifecycle.md](./review-dispatch-lifecycle.md) |
| 会话交接 | §J + [session-handover.md](./session-handover.md) |

## J. 会话交接（Session Handover）

> 权威字段：[session-handover.md](./session-handover.md)。**不**削弱 §H Auto / §C Exit Gate。

**触发**（须按八段模板输出或落盘 `证据/_handover.md`）：① Auto `reason=max_auto_steps` ② 方案结案交接 ③ 用户要「交接」/换 Chat。  
**八段钉死**：当前状态 / 已做 / 下一步 / 禁区 / 依赖 / 风险 / 证据路径 / 下一口令。  
**禁止**：灌归档全文；用交接旁路「准」或待测闸。

## 反模式

| 反模式 | 正确 |
| --- | --- |
| 理解 / 定版 / 开始改码 拆三轮 | §F 一轮 |
| 开 γ 一轮 + 改码又一轮 | §G 合并一轮 |
| 请说开 γ / 开干 / 做吧 | 「准」 |
| 方案审后再问「可以开始改码吗」 | 审过即发确认包；「准」后直接改 |
| 确认包正文写「开干」「做吧」 | 只写「准」 |
| 先改码再补为什么 | 改前选型 |
| 零用户句改码 | 等一轮确认 |
