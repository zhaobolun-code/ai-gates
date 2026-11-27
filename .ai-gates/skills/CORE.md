# AI 开发流水线 CORE（当前版本见 [VERSION](./VERSION)）

> **日常默认入口** → [agent-entry-route.md](references/agent-entry-route.md)。本文件**全文** = 争议 / recovery / `按 CORE 重来` 再查。
> Full/L3/状态机/反模式细则 → [references/](references/)。**使用说明** → [USER-GUIDE.md](../USER-GUIDE.md)（直接说要做的事，不必先说「项目经理」）

## 入口

仓库有 [resident.md](references/resident.md) 时先读它，再按常驻卡做这一刀，并给白话 **你下一步**。不必先说「项目经理」或「PM」。无 project-context → §冷启动。
口令：**`初始化` = `init`**，**`准` = `approve`**，**`检查健康` = `doctor`**。前面不必加「项目经理」或「PM」。
`升级 ai-gates`（可带 GitHub 地址）= **联网更新**：先比对官方源最新 tag 与本地版本（install-info 优先，否则读 `skills/VERSION`），有新版才下载替换本地库（项目状态文件保留；本地项目说明若缺常用命令、仓库分仓、客户端事实，补上模板空节，已有同名节不覆盖），随后跑 link-platform 校验/补齐传送门；网络不可用或无新版时回退「本地已解压包重接传送门」。替换前用白话说明来源与版本（这句口令本身即授权）。Skill 回传下发 = 本口令拉技能包真源仓 `zhaobolun-code/ai-gates`（不是 collect 仓）；收集仓合并 ≠ 已下发。
**特例** `初始化` / `init` / `流水线初始化` 不判车道 → Read [pm-init.md](references/pm-init.md)。

## PM 内部结构化判定（强制）

选车道仍按下面的字段在内部做完。回复**不必**为写文件带字面 `[PM]`，hooks 也不再查打点。YAML **不对团队讲解字段名**（如 `review_tier`）。用户可见内容按 §用户可见输出；TL / 维护模式或用户追问时可展开内部字段。

```yaml
pm:
  lane: Express | Direct | Standard | Full
  lane_rules_hit: "步骤N"          # 如 "4/4"、"2→Direct"、"3→Standard"、"4→Full"
  review_tier: skip | L1 | L1.5 | L2 | L3
  next_role: planner | plan-reviewer | developer | CR | docs | none
  readme: skip | dev-one-liner | docs   # 见 readme-dispatch.md
  user_state: 进行中 | 待你确认 | 待 Unity 测试 | 已定版 | 已阻塞
  blockers: []                     # 有则列字符串，无写 []
  project_context: loaded | missing-coldstart
  diff_hint: Express | Direct | Standard | Full | unknown
  snapshot: ok | manual | n/a      # 见 pm-tooling.md；不得伪造 ok
```

### Express 简略（用户可见）

**全部**满足 → 用户可见只输出白话 **你下一步**（**不要**摘要表）。不必另附 `[PM]`：

- `lane: Express`
- `blockers: []`
- `project_context: loaded`
- 非 recovery / `按 CORE 重来` 恢复轮
- 本轮**无**车道升级（`lane_rules_hit` 不含 `→`）

**你下一步**（可 1～2 句，禁只写「等待」）：车道理由 · 下一岗 · 五态 · 用户动作（确认切片 / 等改完 / Unity 测 / 回是否通过）。二选一/多选一另加 **推荐 + 为什么**（≤3 句）→ [demand-clarification.md](references/demand-clarification.md)。缺任一项或推荐 → **缺 PM 结构化判定**。Express 判定**必须**附一句：「这一刀走快车道。」有建议句时把「这个文件最近测挂过，建议走 XX。」写在同一条里。不回就停在 Express。点名某一档，这一刀才改。

**Verify / Unity 失败**：「你下一步」走 [diagnosis-gates.md](references/diagnosis-gates.md) §0（含有意义评审；同 A# **第一次**且有意义=有、根因钉死 → 同条热修，第二次才菜单）；禁默认开 Step N+1、「新切片」清零止损。

### 完整输出（用户可见摘要 + 你下一步）

不满足 §Express 简略 任一条时，用户可见内容**必须**含白话摘要表：

| 字段 | 用户可见摘要（一行白话） |
| --- | --- |
| 车道 | [Express/Direct/Standard/Full] — [命中理由] |
| 下一岗 | [岗位名] 或「等你确认」/「等你 Unity 测试」/「隔离审核进行中」 |
| README | [skip / 程序员一行 / 文档岗] — [理由] |
| 进度 | [五态] |

表格后**必须**：**你下一步**：……（完整输出同样须满足 §Express 简略 四条最低内容，可写在表后一句里）。YAML 在回复里给机器，不向用户讲解字段。

**隔离审核**：L1.5 CR / L2 / L3 / 高风险对抗 CR → **优先**主 Agent 拉起 Subagent 隔离会话；高风险**优先异模型**（首选高质量档，失败回退同模型，不硬拦）；失败再提示手动新开 Chat；同 Chat 续审须标非独立。细则 → [isolated-review.md](references/isolated-review.md)。**不校验**用户是否接受隔离/是否换模型。

**主窗改码与审核分窗**：方案审 / 文档结构优先 Subagent。Express 和 Direct 主窗直接改业务 `.cs`/`.lua`，不派程序员；Standard 和 Full 的业务改码仍派程序员子窗（低级档）。CR 按车道和档位分流：Direct 必须隔离；普通 Standard L1 可由主窗同会话复核并标「非独立 CR」，不要求子窗戳记；Standard L1.5/L2、Full 和高风险优先隔离，降级须诚实标非独立。隔离审核窗只读派发白名单。范围不清的 Direct 仍派策划子窗。钩子不因主窗身份拒绝业务代码。**周报例外**：用户单独调用，不要求子窗。模型：策划/方案审=高质量；实现/文档=便宜快速；需隔离的 CR 相对实现优先高质量；**具体 slug 只读 project-context §模型路由**（没有该节则标「未按模型路由」，技能不另造默认表）。细则 → [model-routing.md](references/model-routing.md)。

Express 简略轮**禁止**摘要表。L1.5 程序员完成后 PM **须**附 [cr-dispatch-l1.5.md](./templates/cr-dispatch-l1.5.md)（Subagent 派发或手动粘贴）。
**禁止**未完成内部结构化判定就仅凭白话判车道。

### 用户可见输出（强制）

**机器层**：业务写入不再查 `[PM]`。形状、人话、语言与五态 → [user-visible-states.md](references/user-visible-states.md) §对人说话、§用户语言。

### Full 强制 — 用户可见（强制）

近 20 天失败次数到 6 时，**你下一步**写「这个文件最近测挂过，建议走完整流程。」车道仍是 Express，直到用户确认或点名。用户本轮已经点名完整流程，这一刀写 Full，不再追问。缺建议句却把 `lane` 写成 Full → **缺 PM 结构化判定**。

**非 `[PM]` 岗位**（策划/程序员/CR 等）：**不展开 PM 内部字段**；交接用各岗 SKILL 格式 + 白话下一步。

**PM 脚本与 Git**（advisory）→ [references/pm-tooling.md](references/pm-tooling.md)。`readme` 判定 → [references/readme-dispatch.md](references/readme-dispatch.md)。

## 四车道判定（顺序固定）

**判定前**：需求存在 ≥2 种合理解释且影响范围（如「改顺畅点」无验收标准）→ 先追问 ≤3 个关键问题（最多 1 轮，答不全按默认决策继续），细则 → [demand-clarification.md](references/demand-clarification.md)。改代码需求：列出将改业务源文件，用来查热度账，不按文件个数选车道。

**判定**：已经说出改哪一行、改成什么，开工 `lane: Express`。路由只有 Express、Direct、Standard、Full。人在本条消息点名「Auto车道」才读 [lane-auto.md](references/lane-auto.md)，`lane` 不写成 Auto。助手自己写上这句不算。没点名不读那张卡。用户点名某一档，或确认了本轮建议句，这一刀改成那一档。下一刀重新从入口看。人还在回答这个环，或这环没跑完，仍读 `lane-auto.md`，路由标签不动。文件个数、是不是在改规则、API、存档、跨模块、说不清、止损都不改标签。决策树 → [references/full-lane-decision-tree.md](references/full-lane-decision-tree.md)。

```
0. 纯问答 / 只读咨询（不涉及落盘改动——「怎么改」「能不能改」「解释现象」「查代码/文档/接口」）→ **主窗直接答**：不判车道、不建窗、不生成文档、不派岗、不写快照（`snapshot: n/a`）。仅当用户要求或隐含要**落盘改动**（改代码/文档/配置）才进入车道判定。
1. 已经说出改哪一行、改成什么 → Express
   · 只改注释或已有日志字符串（不增删调用）时不读热度账，也不写建议句
   · 其余读 `.ai-gates/regression-heat.yaml` 的 `files:`。取将改业务文件里近 20 天 `fail_count` 最高、且 `last_result` 为 `fail` 的一个。次数读本刀入账之前的账。模型不改这份 yaml
   · 没有这条、`files:` 为空、或次数 < 2：不写建议句
   · ≥2 建议直通道；≥4 建议标准道；≥6 建议完整流程。句：「这个文件最近测挂过，建议走 XX。」写出该路径。放在确认包末尾，不设停点，Auto 不等
   · 不回就停在 Express。确认或点名，这一刀才改标签
   · 改了现象仍同条写规则和不点名。Express 仍不派代码审核
   · 回归索引 / 路径前缀不否决 Express。文件次数不改标签
1.5 人点名「Auto车道」→ 读 lane-auto.md，不改 `lane`
   · 先问技术细节；人回「准」才写文档，再按 UnitySkills 先测、写代码、再测
   · 通过只认 `editor_run_scenario` 的断言。审完后人再回一次「准」才提交
   · 不建 Step 账本，不启用「准」之后的 Auto 执行模式
2. 用户确认「建议直通道」或点名直通道 → Direct
   · **PM 本轮写**对话内 A#/切片（不落盘）；范围说不清才派策划子窗
   · 不因文件个数、API、存档、跨模块、止损改来
3. 用户确认「建议标准道」或点名标准道 → Standard
   · **已确认 Standard** 且命中回归索引模块 → 方案审 **L1.5**（加强审，不回头改车道）
   · **已确认 Standard** 且模块 heat≥medium，或将改文件近 20 天 `fail_count` ≥ 2 而模块还冷 → 方案审 L1.5 或更高档。这不改车道
4. 用户确认「建议完整流程」或点名完整流程 → Full
   · 止损不进入这一档
```

### 什么不改标签

| 情况 | 车道 |
| --- | --- |
| 文件个数变多，或这刀在改判定规则、控制流、守恒、通断真源、方向 | 仍是 Express，除非用户确认建议或点名 |
| 人没点名「Auto车道」 | 不读 lane-auto.md。`lane` 仍是四条之一 |
| API、存档、跨模块，但已经说出改哪一行 | 仍是 Express，除非用户确认建议或点名 |
| 止损、热修次数 | 走诊断和热修上限，不改标签 |
| 用户不回建议句 | 停在这一刀已经选的车道 |

## 车道 → 派岗

| 车道 | 流程 | 文档 |
| --- | --- | --- |
| **Express** | 一句话切片 → 用户已说出改法就同条改，否则一次「准」→ 主窗直接改 → 一行自检 → Unity 测；无 CR、无待测锁、不补 README；默认不落盘、不建窗；**一旦已建分类夹** → [doc-windowing.md](references/doc-windowing.md) §与 Express（最小两文件 + 终态须 migrate；不强制 `未完成.md`） | Chat 一句话切片；须含 PM 判定 + 一句话 A# |
| **Direct** | **PM 写**对话内 A#/切片（不清才派策划）→ **一轮确认** → 实现（**主窗自己改**）→ 隔离 CR（**必须子窗**，高级档，只读派发白名单）→ 文档一行版本 → 用户接收；单会话 | 对话内 A#/切片（不落盘）；「文档一行版本」= README `dev-one-liner`，非落盘执行文档 |
| **Standard** | plan-lite → L1/L1.5/L2 → **一轮确认** → `[developer]` → `[CR]`（普通 L1 可主窗同会话复核，标「非独立 CR」；更高档按隔离规则）→ README。同窗同口径连续刀 → [circuit-windows.md](references/circuit-windows.md) **战役模式**（方案审不每刀重做；每刀仍 CR） | plan-lite；A# + delta-only |
| **Full** | TL 显式启用；见 [references/](references/) | 执行文档；须含验收 A# |

文档须含可证伪 **验收条款 A1…** 且 Step/切片写 **满足验收：A#**；只写相对现状变更（**delta-only**）。缺则方案审核 blocker。细则 → [acceptance-and-delta.md](references/acceptance-and-delta.md)。回归索引模块相关 Step 验收时：优先用 `scripts/verify-regression-smoke.ps1` 跑冒烟（命中 golden 且 UNITY_EXE 可用则自动跑，否则生成人工 Play 清单），并用 `scripts/collect-acceptance-evidence.ps1` 把日志尾部/截图/测试报告归入窗口 `证据/`（evidence.md）；**自动验证 ≠ 业务手测签收**，A# 仍以你亲眼看为准。

Express 完成后 **不得**再派独立「代码审核」。Standard：方案审无 blocker → 发一次确认包；「准」同条开始改码。普通 CR 无 blocker 后，Full 或热文件反复修复/运行仍异常 → PM **优先**可选 Subagent `代码审核 模式：对抗`；失败再提示手动新开；用户可跳过。细则 → [isolated-review.md](references/isolated-review.md)。

**一轮确认硬律** → [handoff-automation.md](references/handoff-automation.md) §0；白话包 → [demand-clarification.md](references/demand-clarification.md)。每决策点 1 条确认包；「准」同条定版/开窗/改当前这一步；续链用**合并包**。禁口令门、先改再补理由、零用户句改码。标准道、完整流程回「准」不连跑后续 Step。不默认启用 Auto 执行模式。每 Step 仍要测。确认包末尾的加审建议见 handoff §0：反复失败建议逆链，推理对不上建议分歧标注，止损到顶建议碰撞。不点名就不跑。错题主表仍须「准」。

## Standard 审核升档（L1.5 / L2）

**仅当用户已确认 Standard**。回归索引和热度不改车道标签。已确认 Standard 且 Mandatory 命中 project-context 回归索引**模块** → L1.5；或命中 `.ai-gates/lessons-learned.md` 近 6 个月，或 `.ai-gates/regression-heat.yaml` 该模块 heat≥medium，或将改文件近 20 天 `fail_count` ≥ 2 而模块还冷 → L1.5；热度取较高档：L1.5 之上 → 方案审 L3 / 双轮 CR。Mandatory 跨 ≥2 业务模块 → 方案审 **L2**（与 L1.5 取高）。`review_tier: L1` 且 plan-lite **≥2 Step** 或改动面较广 → PM **须**提示可选隔离。派发与档位细则 → [plan-review-tiers.md](references/plan-review-tiers.md) / [isolated-review.md](references/isolated-review.md)。

## 硬门禁（7 条）

1. **没读真实代码不改** — 代码与仓库文件（有 git 时辅以 diff）> README > 文档/Express 切片 > 对话推断
2. **Express 先有一句话切片（PM 判定+一句话 A#）、Direct 先有对话内 A#/切片再改** — 无切片不得改；一次一切片；实改超出切片就停下来说明，不因此改车道标签
3. **Standard 须方案审**（战役中刀口径/选型/A# 契约未变则免本刀重审，见 circuit-windows）；**Direct 无方案审，主窗改完须隔离 CR** — 未过方案审不得派 Standard 程序员；Direct 未隔离 CR 不得当审完
4. **CR 有 blocker 不写最终 README**
5. **Unity 未测不得标「已通过」** — 例外：Skill/Doc AI 验收通过可抬升（见 [handoff-automation.md](references/handoff-automation.md) / [loop-engineering.md](references/loop-engineering.md)；非可不测）
6. **PM 不替岗** — 不写 Step 规格、不替 CR 宣布无 blocker；普通 Standard L1 可由主窗同会话只读复核并标「非独立 CR」。Direct、Standard L1.5/L2、Full 与高风险按隔离规则复核。Express 和 Direct 的业务改码由主窗做。标准道和完整道仍派程序员，主窗不改业务代码
7. **问句不改文件** — 问句先答。Express 里用户已经说出改哪一行、改成什么，同条就改。标准道和完整道仍先有方案再改代码。直叫岗位名时先选车道。

**反合理化（借口对照）**：问句就改文件 / 日志关键词冒充 A# / 伪称隔离 CR → [anti-patterns.md](references/anti-patterns.md) §反合理化；评测 §K。

**非门禁**：普通 Standard L1 的主窗同会话 CR 是正常的非独立路径；Standard 高档 / Full 的隔离审核是否成功、用户是否手动新开 Chat、换模型，只要求诚实标注，不硬阻断，也不得冒称隔离完成。Direct 的 CR 须子窗或新开 Chat，标注「隔离复核」；同 Chat 只标非独立不算完成。标准道还没有方案就改代码 → **已阻塞**。

**机器强制层（如实）**：业务路径放行代号 `business_write`，不查 `[PM]` 打点。改技能包仍看 120 分钟内的变更日志。同一现象热修满 2 次仍拒绝。审核戳记和派发文件仍只有子窗能写。Codex **桌面**对 `apply_patch` 钩子可能不触发。Trae 为软层（规则 + 技能传送门，**无**机器 hooks）。macOS / Linux 无 `pwsh` 时机器 hooks **未接线**，体检须报 `hooks_not_wired_no_pwsh`，不得写成已接线。`failClosed: false`：hook 脚本失败则放行。kill switch 须在本机终端（不要经过 Agent）运行 `.ai-gates/scripts/enable-kill-switch.ps1` 并输入 ENABLE KILL SWITCH 才关掉；空文件和 Agent 写入不算。Level 1 放行只证明本会话 120 分钟内写过正式 `.ai-gates/CHANGELOG.md`，不证明条目描述了即将修改的文件或内容。标准道和完整道仍先写方案再改代码，这一条靠流程，不靠打点。

**工作区卫生（非门禁）**：一次性中间产物只放 **`.ai-gates/tmp/`**。细则 → [execution-discipline.md](references/execution-discipline.md) §工作区卫生。

## 无 project-context 冷启动

1. 只读咨询 → **不阻塞**。
2. **改代码** → `missing-coldstart`；**你下一步**须含「未初始化」+ 建议 **`初始化`**；未初始化前同样每一刀 Express，热度建议照上面的表。细则 → [pm-init.md](references/pm-init.md)。

## 岗位切换

| 调用名 | Skill 路径 | 首行标记 |
| --- | --- | --- |
| 项目经理 / PM | 读本 CORE | `[PM]` |
| 策划 / 方案审核 / 程序员 / 代码审核 | `planner` / `plan-reviewer` / `developer` / `code-reviewer` 下 `SKILL.md` | `[planner]` / `[plan-reviewer]` / `[developer]` / `[CR]` |
| 文档 / 周报 | `module-readme` / `weekly-report` 下 `SKILL.md` | `[docs]` / `[weekly]` |
| 查日志 | `log-evidence` 下 `SKILL.md`（主窗要看日志时派低级子窗，主窗不读原文） | `[log]` |
| 查正文 | `read-evidence` 下 `SKILL.md`（主窗要看代码或长文档时派低级子窗） | `[read]` |
| 跑命令 | `run-evidence` 下 `SKILL.md`（主窗要跑终端时派低级子窗） | `[run]` |

切换岗位前 Read 对应 `SKILL.md`。Express 切片写在回复里，**策划不参与**。Direct A# 已写清同样不派策划。直叫岗位仍先选车道；无 slice/plan-lite 且未 ready 不得直接 `[developer]`。一轮确认「准」→ 同条 `[developer]`（[handoff-automation.md](references/handoff-automation.md) §0/§F）。

翻车索引 → [anti-patterns.md](references/anti-patterns.md)（**仅列近 90 天真实命中反模式、上限 15 条**，超限最低命中降级回完整表）。写方案/改码/扩 README 前 → [execution-discipline.md](references/execution-discipline.md) **复用四问**（已有→复用→少写/不写→能删）。测挂修复 → `证据/_repair-blackboard.md`；止损/`repair_rounds` 触顶 → **A#/口径复议**（[diagnosis-gates.md](references/diagnosis-gates.md) §0.6/§0.7），禁同 A# 死磕。错题 → 大纲 `.ai-gates/lessons-outline.md`（错因+改正）+ 方案「错题本必读」指路（[lessons-learned.md](references/lessons-learned.md)）。

## Agent 失败模式与恢复

用户 **主口令 `按 CORE 重来`**（同义：`流水线重来`、`没按流程来`）：

1. Read CORE + **若存在** project-context
2. `[PM]` 内部结构化判定（recovery **须**完整表 + **你下一步**）
3. Express → 补 express-slice + express-self-check（若已改代码）；Standard 缺 L1/L1.5 → 回 plan-lite / plan-reviewer
4. 说明上轮偏差；追加 [pipeline-recovery-log.md](./templates/pipeline-recovery-log.md)；快照见 [pm-tooling.md](references/pm-tooling.md)

**另一口令 `方案推翻`**（撤销已落地代码，非流程纠偏）：确认文件清单→用户确认→**列出** `git checkout -- <文件>` 请用户在终端执行（Agent 禁止经 Shell 跑该命令）→记录原因，细则 → [rollback.md](references/rollback.md)。

**PM 自检**：结构化判定 + **你下一步**；express-slice；A#；L1.5 派发块；子窗首回合核验（空上下文询问 → `fork_turns=all` 重派）；**一轮确认硬律**（handoff §0）；CR/Verify；止损含热修；首段=状态；未夸大 Unity/completed。

日常入口、点名 ≤2 份 reference、外仓对照（点名才启用）→ 文首 + [reference-routing.md](references/reference-routing.md) / [external-compare.md](references/external-compare.md)。
