# Loop Engineering / Auto 执行模式

> **权威外环规范**（Skill）。Unity 业务物理无关。
> 连跑模型（**方案 A**）：Auto 连跑「实现 → CR → step-completed」；**每个 Step 仍须验收**（人测或命中时 AI 验收子窗；原则：能 AI 测则子窗，不能再人测）后才可续跑下一 Step。禁止多 Step 攒批再验。
> **用户停点（Auto 启用）**：待验（`unity_test` / AI 验收）+ [diagnosis-gates.md](./diagnosis-gates.md) **硬停白名单**；中间选型与测挂「可自动跟」推荐**不**等人。测挂分流 → diagnosis §0（1A）。
> CORE / USER-GUIDE 仅薄指针；本文件承载细则。相关：`handoff-automation.md` §H（接线后）、`state-machine.md`、`anti-patterns.md`。

## 1. 定位

| 术语 | 含义 |
| --- | --- |
| **Harness** | 单次会话内规则与岗位（CORE / skills） |
| **Loop Engineering** | 外环：何时连跑、如何独立验证、何时整圈停止 |
| **Agent loop（内环）** | Cursor/模型 tool 循环；**不改**产品内环 |
| **Auto 执行模式** | Standard/Full 在「准」之后，允许在停机条件前连续推进**当前 Step 的实现与 CR**；**不是**第四条需求判定车道；**Express 不启用 Auto** |

**启动前仍须「准」**（一轮确认包）。Standard/Full：「准」**默认** Auto；显式「准, 不 Auto」则单步。`lane: Full` ≠ `execution_mode: Auto`（正交）。

## 1.5 状态外置（支柱 B · 可选）

本节以下 `stop_reason`/`auto_steps_done`/`repair_rounds`/止损计数等字段，默认仍写在 `未完成.md` 文档状态段落（叙述性，人读）。有 `scripts/update-doc-state.ps1` 时**可选**把这些字段搬进方案夹的 `.state.json`（机器事实来源，非法迁移脚本直接拒绝，退出码非 0）：

```powershell
powershell -File .cursor/scripts/update-doc-state.ps1 -DocFolder "{方案夹}" -Init   # 新方案夹
powershell -File .cursor/scripts/update-doc-state.ps1 -DocFolder "{方案夹}" -Transition step-completed -Note "Step2 CR 无 blocker"
```

- 合法迁移表＝本文件 §3 主链（`draft→review-pending→implementation-ready→in-progress→step-completed→runtime-validated→completed`，含 `blocked` 分支）；跳级/倒退默认被拒绝
- `-IncrementAutoSteps`/`-IncrementRepairRounds` 按 §4 预算（3/2）自动派生 `reason=max_auto_steps`/`fuse reason=max_repair_rounds`；`-ResetAutoSteps` 对应「本窗 Auto」（不重置已触顶 `repairRounds`）
- 止损计数用 `-SetStopLoss "标签=当前/上限"`
- 人工越权用 `-Force -ForceReason "..."`（写入 `.state-history.jsonl`，标 `forced:true`，不建议常规使用）
- 两者不同步时以 `.state.json` 为准；`未完成.md` 仍是给人看的叙述，脚本文件是给 Hook/CR 复核用的事实——**未落地为强制**，本 Step 只提供工具，不要求所有方案夹立即迁移

## 1.6 范围化预授权（可选 · 有额度 · 不免验）

**动机**：§1「准」默认已把确认压到每个决策点 1 次；本节只解决一种更窄的场景——同一方案/同一物理口径下，接下来几个 Step **性质相同、都是参数级微调**（不新增/删除状态、不改判定逻辑），逐个再发确认包属于空转。

**口令**：确认包里可选带一行【若要预授权同类 Step】，用户回 **「预授权 N」**（N ≤ `max_auto_steps`，默认 3）。

**适用前提（全部满足才可发起，否则 PM 不得提供该选项）**：

1. 当前方案已 `implementation-ready`，且未来 N 个 Step 已在方案里逐条列出（不是"以后随便有类似的都算"）。
2. 每个被预授权的 Step 都是**同一物理口径下的参数/阈值微调**；新增状态、改判定逻辑、跨模块改动 **禁止**预授权。
3. Full 车道 L3 已通过（预授权不豁免方案审，只豁免"逐 Step 再发确认包"这一层）。

**边界（不豁免的部分，与 §2 完全一致）**：

- **不免验**：每个 Step 仍须验收才能 `runtime-validated`（人测或命中时 AI 验收二选一按触发；能 AI 测则子窗，不能再人测）；预授权只免"改码前的确认包"，不免"改码后的验收"。
- **不加预算**：仍受 `max_auto_steps`/`max_repair_rounds` 现有预算约束，预授权额度 ≤ 剩余预算，不能叠加。
- **立即失效条件**：出现 `discover`/`replan`/`scope_change`/`lane_upgrade`、或某个 Step 验收发现口径漂移 → 剩余预授权额度清零，回到逐 Step 确认；不得用「本窗 Auto」恢复预授权（那是另一个口令，管的是 Auto 步数预算，不管预授权）。
- **额度用尽或超出已列 Step 范围** → 必须新发确认包，不得默认继续。

**记录**：`未完成.md` 文档状态段落新增一行 `预授权：{已用}/{N}`；接入支柱 B 时对应 `.state.json` 的 `preAuthQuota`/`preAuthUsed` 字段（脚本层暂不强制）。

## 2. 边界

1. Auto **不**取消首轮「准」与验收（人测或 AI 验收二选一按触发；能 AI 测则子窗，不能再人测）。**不**因自动跟推荐而免验。
2. Auto **不**静默写 lessons 主表、不标 `runtime-validated`（主窗自验冒充隔离禁止）。规格漂移改口径/A#：可落草稿，**开码前**属硬停（须「准」）——见 diagnosis §0.5 / 硬停表。
3. 每个 Step 在 CR 无 blocker 收口后 → **必须**待验：命中 AI 验收则派验收子窗（可瞬态 `await_verify reason=ai_static`；**禁止**只写 `unity_test` 干等）；未命中/不确定 → `await_human reason=unity_test`；禁止连开下一 Step 改码；**禁止多 Step 攒批再验**。
3.1 **用户可见停点（Auto 启用）**：仅 (a) 待验 / AI 验收结果；(b) `max_auto_steps`；(c) diagnosis **硬停白名单**。中间选型包、测挂后对 `auto_follow: yes` 推荐的「准」→ **不发、不等**（同条执行并留据）。
3.2 **测挂**：走 [diagnosis-gates.md](./diagnosis-gates.md) §0（再改码前须 **有意义评审** §0.2.1；G*≠有意义≠A#）；`auto_follow: yes` 且未硬停 → 同条采纳【推荐】连跑至再次待验；硬停（含止损将到 2/3）→ 确认包等人。自动跟**不是**旁路 Exit Gate。
4. Maker/Checker 分离：不得「自写自审通过」冒充隔离 CR；**Auto 不得降档**；验收子窗禁改任何仓库交付物。
4.1 模型路由：Auto 改码 / CR / 方案审 / **验收/verify** 按 [model-routing.md](./model-routing.md)（project-context §模型路由优先；须显式传 `model=`；验收=高质量档）。
5. CORE 结构冻结：禁止为 Auto 新增 CORE `##`/`###`；落地后 CORE ≤200 行。
6. TL 选择不测 → 保持 Exit Gate 唯一 reason + `step-completed`；不得迁 `runtime-validated` / `completed`。

## 3. stop_reason

| 值 | 含义 |
| --- | --- |
| `completed` | 范围内**全部 Step 已验签收**且剩余=0；**无**口令/结案例外；最后 Step 未验不得 `completed` |
| `blocked` | blocker / 方案与代码冲突 / 缺 Mandatory·A#·Delta Spec |
| `fuse` | 热修止损、Developer §7、`max_repair_rounds`、停滞等 |
| `await_verify` | 派 AI 验收前瞬态；`reason=ai_static`；子窗返回后消（**≠**长期干等） |
| `await_human` | 待验/人工；`reason=unity_test` 或 `reason=max_auto_steps`（预算用尽，**≠** `completed`） |

### 3.1 ↔ 文档状态

| stop_reason / reason | 强制文档状态 |
| --- | --- |
| `completed` | `completed` |
| `blocked` / `fuse` | `blocked`（fuse 只写 stop_reason） |
| `await_verify reason=ai_static` | `step-completed`（瞬态） |
| `await_human reason=unity_test` | `step-completed` |
| `await_human reason=max_auto_steps`，尚未验签收 | `step-completed` |
| `await_human reason=max_auto_steps`，已验签收且仍有已批准 Step | `runtime-validated`（**保留** stop_reason） |
| `await_human reason=discover/replan/scope_change/lane_upgrade` | `blocked` |

### 3.2 按原因恢复（禁止统一直迁 `in-progress`）

| 情形 | 路径 |
| --- | --- |
| 普通待验通过（人测或 AI 验收），预算未用尽，仍有已批准 Step | `step-completed → runtime-validated → in-progress(下一 Step)`；清当前 stop_reason |
| 预算用尽，验通过，仍有 Step | `step-completed → runtime-validated`；保留 `reason=max_auto_steps`；「本窗 Auto」后重置步数、清 reason → `in-progress(下一 Step)` |
| 验通过，无剩余 Step | `→ runtime-validated → completed` |
| `fuse reason=max_repair_rounds` | `blocked` → diagnosis §0.7 **A#/口径复议**确认包 →「准」后改口径/A#（若需）→ `review-pending → 按**当前车道**重审无 blocker`（**Standard 保持 Standard，禁止误升 Full/L3**；**仅 Full** 要最新版 L3 两轮）→ 重新「准」→ `repair_rounds=0`（同条留据）→ `implementation-ready → in-progress`（原 Step 或复议后新 Step）。「本窗 Auto」/新会话/口头解除**不得**重置，**不得**跳过 A# 复议直接再修 |
| `blocker_kind=implementation` | 解除后 `blocked → in-progress(原 Step)`；修后重做隔离主 CR |
| `blocker_kind=plan` 或 discover/replan/scope/lane | `blocked → review-pending → 按车道重审（Standard 不升 Full）→ 重新「准」→ implementation-ready → in-progress` |
| 测试不通过 / AI 验收不通过 | `step-completed → blocked` → diagnosis-gates §0 |

合法迁移：`runtime-validated → in-progress(下一已批准 Step)` 前提为文档**已是** `runtime-validated` 且仍有已批准 Step。

## 4. 默认预算

- `max_auto_steps`：**3**（单次预算内最多推进至待验的 Step 数）
- `max_repair_rounds`：**2**（交审级修复；微循环不计）
- 停滞：同一失败标签 / 同一 Mandatory 无实质 diff 连续 **2** 轮 → `fuse`

计数：每完成一个 Step 的实现+CR 收口（进入待验）→ `auto_steps_done +1`；然后**唯一** reason：命中 AI 验收 → 可瞬态 `await_verify reason=ai_static` 并派子窗；未命中且 `< max` → `unity_test`；`≥ max` → `max_auto_steps`。禁止双写；命中时**禁止**只写 `unity_test` 干等。

## 5. P1.5 衔接

### 5.1 微循环 & Developer Checklist 7 & repair_rounds

- 微循环自检行为不变，**不计入** Checklist 7。
- Checklist 7（权威见 `developer/SKILL.md`，勿钉行号）：**仅业务 C#** 的交审/交自检整轮累计；微循环、Skill/纯文档假需求不计；同一 Step 连续第 **2** 次 `static-checked` 修复仍未 Unity → 停，提示先测。
- `repair_rounds`：进 Step 时为 0；**初次实现与初次隔离主 CR 不计**；CR 有 blocker 后、开始下一轮交审级修复前 `+=1`；`== max_repair_rounds` 且仍有 blocker → `fuse`，禁止第 3 轮修复。
- **`repair_rounds` 与 Checklist 7 同一 Step 内独立、互不合并/重置，谁先触达谁生效**；新 Step 各自初始化为 0。
- `max_repair_rounds` 触顶后，不因「本窗 Auto」/新会话重置；仅方案级恢复链 + 重新「准」后显式归零。
- **触顶 → A# 复议**：`fuse reason=max_repair_rounds` 后【推荐】必须走 [diagnosis-gates.md](./diagnosis-gates.md) §0.7（A#/口径复议），**禁止**同 A# 再开交审修复；恢复链须含复议「准」与口径/A# 更新。
- **证据黑板**：交审级修复前 Read `证据/_repair-blackboard.md` 最近 ≤3 条；失败追加一条（diagnosis §0.6）。

### 5.2 经验提议（E4）

- 该 Step「测试通过」或 AI 验收通过后起草 1 句候选经验（须「准」写入 lessons）。
- 未验 / fuse / blocked / 测不通过 / AI 验收不通过 → 不触发。
- **预算用尽签收**：E4 仍可起草，但**禁止**清除 `reason=max_auto_steps`，**禁止**等价「继续 Auto」续跑。

### 5.3 Delta Spec

不得因 Auto 跳过每 Step 的 ADDED/MODIFIED/REMOVED；有 MODIFIED/REMOVED 未改口径不得方案 `completed`。

## 6. Maker/Checker 与 CR

- 方案 L3 ≠ Step CR；互不替代。
- 每个实现 Step：**至少 1 轮**非 Maker 的隔离主 CR，且针对**最新版 diff**无 blocker（优先 Subagent）；同 Chat / 普通文档审 / 方案 L3 / 可选对抗 CR **均不得替代**。
- CR 有 blocker → 修复后重新隔离 CR；交审级修复受 `max_repair_rounds=2` 约束。
- **Skill/Doc-only 图谱例外**：本 Step Mandatory **仅**改 `.cursor/skills/**`、`Assets/Doc/**` 等、**无**业务 Runtime/Editor C# 时，无 CodeGraph（或探测失败）→ **soft risk / 验证缺口**，不得单独据此 blocker，不得阻止无业务 blocker 收口。覆盖现行 Full「无图谱=hard blocker」对本类 Step 的适用；业务 C# Step 仍按原规则。
  - **实现期默认决策（至 `code-reviewer/SKILL.md` 接线前）**：本方案 Step 的隔离主 CR 以本文件 + 执行文档共同 Exit Gate 为准；与 CR 车道表冲突时，**Skill/Doc-only 取 soft risk**。

## 7. 口令

| 口令/动作 | 效果 |
| --- | --- |
| 确认包「准」（Standard/Full 默认 Auto） | 启动；`auto_steps_done=0`；进当前待实现 Step |
| 「准, 不 Auto」/「不要 Auto」/「单步」 | 定版改码但**不**启 Auto；每步后须再开口令 |
| **「本窗 Auto」** | 仅已批准范围启动/重启；步数重置为 0；**不得**新范围、**不得**重置触顶 `repair_rounds`。推进下一 Step **硬前置**：已是 `runtime-validated`（预算用尽可仍带 `reason=max_auto_steps`）。**禁止**在 `step-completed` 待验时清 reason/开下一 Step |
| **「继续 Auto」** | 仅普通待验（非 `max_auto_steps`）签收后、已 `runtime-validated`；**不重置**计数；预算用尽时无效 |
| 「测试通过」同条 / AI 验收通过 | 非预算用尽可续跑下一 Step；预算用尽则保留 reason，须「本窗 Auto」 |
| 新范围 | 重新 PM +「准」；单独「本窗 Auto」无效 |
| 「测试不通过」/ AI 验收不通过 | diagnosis-gates §0：硬停 → 确认包；可自动跟 → 同条跟推荐（留据），连跑至再次待验（**仍须**该刀 Exit Gate 验收，非免验） |
| **旁路禁止（Auto 启用时）** | `step-completed` 待验，或 `runtime-validated + reason=max_auto_steps` 时：禁止「做 Step N」/直接派 developer /「CR 通过即可开下一 Step」/§B 类口令。推进仅允许合法「继续 Auto」或「本窗 Auto」。Auto 下「前一步 CR 通过即可开下一步」**改读为**「前一步验签收至 `runtime-validated`」 |

## 8. 反模式（摘要；全文见 anti-patterns）

- 未「准」声明 Auto / 零确认改码
- 未验进下一 Step；未验标 `completed`；命中 AI 验收却只写 `unity_test` 干等；多 Step 攒批再验
- Auto 下对 `auto_follow: yes` 仍发选型等人；硬停项静默跟；自动跟未留据
- 待验时「本窗 Auto」或「做 Step N」/直接派 developer 旁路
- 预算用尽仅用「继续 Auto」推进；用「本窗 Auto」刷新 `max_repair_rounds`
- TL 跳过测试却迁 `runtime-validated` / `completed`；主窗代验冒充隔离子窗抬升
- 自写自审冒充隔离主 CR；Auto 降 CR 档；验收用实现档/缺 `model=`
- Auto 跳过 Delta Spec；静默写 lessons；自动标 runtime-validated
- 熔断重审把 Standard 误升 Full
- 恢复路径统一直迁 `in-progress`；方案级跳过重新「准」

## 9. 复核派发工件（摘要）

完整生命周期与机械 `target_revision` / `review_input_revision` 算法见方案夹物理口径；Skill 落地拆出 `review-dispatch-lifecycle.md`（独立 Step）。要点：

- 工件：`证据/_方案审核派发.md`、`_Step{NN}-代码审核派发.md`、可选对抗派发、命中时 `_Step{NN}-验收派发.md`（`mode=verify`）
- `证据/**` 默认禁读；**仅**派发时点名的一个 `_...派发.md` 为精确例外
- `target_files ⊆ whitelist`；权威 ≡ 白名单；不匹配 → `blocked reason=stale_dispatch`
- L3 第1→2：仅 PM/planner 验 revision、切轮、派新 Checker；第2轮不带第1轮结论

## 10. Exit Gate（实现 Step 收口）

**原则**：能 AI 测则高规格子窗验，不能再人测。接线细则 → [handoff-automation.md](./handoff-automation.md) §C。

1. 非 Maker 隔离主 CR，最新版 diff 无 blocker（Skill/Doc soft risk 见 §6）
2. `auto_steps_done +1` 后按机械触发写**唯一** reason → 文档 `step-completed`：
   - **命中 AI 验收**（Mandatory 无业务 C# **且** Unity 验证精确∈{`无`,`N/A`,`Skill/Doc-only`}，**且** verify 齐套已存在）→ 派高规格验收子窗（`mode=verify`，显式 `model=`）；可瞬态 `await_verify reason=ai_static`；**禁止**只写 `await_human reason=unity_test` 干等
   - **未命中 / 不确定 / Unity 字段缺失·未知·非免测集合 / 齐套不存在** → `unity_test` 或预算尽时 `max_auto_steps`；禁止派 AI 验收抬升
3. 验收通过（人测「测试通过」或 AI 验收子窗通过）→ `runtime-validated` 后才可下一 Step（或预算用尽后「本窗 Auto」）；不通过≡测失败，不抬升
4. 全部 Step 验签收且剩余 0 → 才可 `completed`
