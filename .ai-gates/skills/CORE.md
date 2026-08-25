# AI 开发流水线 CORE（当前版本见 [VERSION](./VERSION)）

> **日常默认入口** → [agent-entry-route.md](references/agent-entry-route.md)。本文件**全文** = 争议 / recovery / `按 CORE 重来` 再查。
> Full/L3/状态机/反模式细则 → [references/](references/)。**使用说明** → [USER-GUIDE.md](../USER-GUIDE.md)（只记「项目经理 + 需求」）

## 入口

用户：`项目经理` / `PM` + 需求 → **`[PM]`** 结构化判定 + 白话 **你下一步** 并派岗；无 project-context → §冷启动。  
口令等价（强制）：**`项目经理` = `PM`**，**`初始化` = `init`**，**`准` = `approve`**，
**`升级` = `upgrade`**，**`检查健康` = `doctor`**。  
`升级 ai-gates`（可带 GitHub 地址）= **联网更新**：先比对官方源最新 tag 与本地版本（install-info 优先，否则读 `skills/VERSION`），有新版才下载替换本地库（项目状态文件保留），随后跑 link-platform 校验/补齐传送门；网络不可用或无新版时回退「本地已解压包重接传送门」。替换前 PM 白话说明来源与版本（口令本身即授权）。Skill 回传下发 = 本口令拉技能包真源仓 `zhaobolun-code/ai-gates`（不是 collect 仓）；收集仓合并 ≠ 已下发。
**特例** 二者相加即接入流程（不判车道；任选语种组合，效果相同）→ Read [pm-init.md](references/pm-init.md)。例：`项目经理 初始化`、`PM init`。同义：`流水线初始化`。  

## PM 内部结构化判定（强制）

每轮 `[PM]` 在回复用户前**必须**完成下列 YAML 字段判定；回复**必须含**字面 `[PM]` YAML 块供 hooks 打点。YAML **不对团队讲解字段名**（如 `review_tier`）。用户可见内容按 §用户可见输出；TL / 维护模式或用户追问时可展开内部字段。

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

**全部**满足 → 用户可见只输出白话 **你下一步**（**不要**摘要表）。回复仍须含字面 `[PM]` YAML（给机器，不向用户讲解）：

- `lane: Express`
- `blockers: []`
- `project_context: loaded`
- 非 recovery / `按 CORE 重来` 恢复轮
- 本轮**无**车道升级（`lane_rules_hit` 不含 `→`）

**你下一步**（可 1～2 句，禁只写「等待」）：车道理由 · 下一岗 · 五态 · 用户动作（确认切片 / 等改完 / Unity 测 / 回是否通过）。二选一/多选一另加 **推荐 + 为什么**（≤3 句）→ [demand-clarification.md](references/demand-clarification.md)。缺任一项或推荐 → **缺 PM 结构化判定**。Express 判定**必须**附一句**风险复述 + 升道出口**：「我判定为机械微改（仅 1 个文件），走快车道；若你认为涉及行为变化，请回『直通道』；超过 3 个文件或涉及 API / 存档 / 跨模块，请回『走标准道』。」

**Verify / Unity 失败**：「你下一步」走 [diagnosis-gates.md](references/diagnosis-gates.md) §0（含有意义评审）；禁默认开 Step N+1、静默代选、「新切片」清零止损。

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

**主窗仅 PM + 流水线岗子窗（优先 · 不硬拦）**：主窗**只**做 `[PM]`；策划 / 方案审 / 程序员 / CR / 文档 **一律优先 Subagent 子窗**（有能力时禁止主窗兼岗写改）。**周报例外**：用户单独调用，不要求子窗。模型：策划/方案审=高质量；实现/文档=便宜快速；CR 相对实现优先高质量；**具体 slug 以 project-context §模型路由为准**（无则 Skill 默认表）。细则 → [model-routing.md](references/model-routing.md)。

Express 简略轮**禁止**摘要表。L1.5 程序员完成后 PM **须**附 [cr-dispatch-l1.5.md](./templates/cr-dispatch-l1.5.md)（Subagent 派发或手动粘贴）。
**禁止**未完成内部结构化判定就仅凭白话判车道。

### 用户可见输出（强制）

**机器层**（hooks / Stop 打点）：回复**必须含**字面 `[PM]` YAML 块。不对团队讲解 `review_tier` 等字段名。YAML 出现在回复里 **不是**「本条已完成结构化判定」的用户可读证明。

**用户可见**：

- Express 简略（上节全部满足）：只输出白话 **你下一步**（不要摘要表）。YAML 仍写在回复里给机器，不解释给用户。
- 非 Express：白话摘要表（车道/下一岗/README/进度）+ **你下一步**。
- 白话与落盘正文跟本会话用户语言（中文可夹英文专名；文件名仍为机器锚）→ [user-visible-states.md](references/user-visible-states.md) §用户语言。
- 用户追问进度/TL 模式/维护场景时，可展开内部字段；**禁止**无翻译地抛 `review_tier`、`implementation-ready` 等术语。细则 → [user-visible-states.md](references/user-visible-states.md)。

### Full 强制 — 用户可见（强制）

命中 §四车道判定 步骤 4 Full 强制（`lane: Full` 或 `lane_rules_hit` 含 `4→Full` / 步骤4）时，**你下一步**须含一句白话：
「此项改动涉及 [简述理由]，建议启用**完整流程（Full）**；请 TL 确认，或回复「完整流程」继续。」缺此句 → 视为 **缺 PM 结构化判定**。

**非 `[PM]` 岗位**（策划/程序员/CR 等）：**不展开 PM 内部字段**；交接用各岗 SKILL 格式 + 白话下一步。

**PM 脚本与 Git**（advisory）→ [references/pm-tooling.md](references/pm-tooling.md)。`readme` 判定 → [references/readme-dispatch.md](references/readme-dispatch.md)。

## 四车道判定（顺序固定）

**判定前**：需求存在 ≥2 种合理解释且影响车道/范围（如"改顺畅点"无验收标准）→ 先追问 ≤3 个关键问题（最多 1 轮，答不全按默认决策继续），细则 → [demand-clarification.md](references/demand-clarification.md)。

**判定实现顺序（单一优先级，M1）**：**先查步骤 4 Full 强制条**——命中任一即 `lane: Full`；**未命中再按步骤 1 → 步骤 2 → 步骤 3 判定**（等效「取最高命中车道」）；升级链 `Express → Direct → Standard → Full`，过程中命中升级立即改判。**PM 默认直通道**（步骤 2），不要无理由抬到标准。决策树 → [references/full-lane-decision-tree.md](references/full-lane-decision-tree.md)。

```
0. 纯问答 / 只读咨询（不涉及落盘改动——「怎么改」「能不能改」「解释现象」「查代码/文档/接口」）→ **主窗直接答**：不判车道、不建窗、不生成文档、不派岗、不写快照（`snapshot: n/a`）。仅当用户要求或隐含要**落盘改动**（改代码/文档/配置）才进入车道判定。
1. Express（快捷道 · 机械清单，准入条件**全部**满足）→ Express
   · 仅字符串/注释/日志文本、编译错误修复（缺符号/类型不匹配，不重设计）、数字/常量/阈值 ≤3 行
   · **恰好 1 个**业务源文件（如 `.cs`）；`.meta`、同批 prefab 配套资源**不计入**。有行为变化即使 1 个文件 → 步骤 2 Direct（快车道无代码审）
   · 无 API/持久/跨模块/生成文件；一句话说清；一句话 A# 可证伪
   · 未命中止损链。**回归索引 / 文件热度 / project-context 路径前缀不单独否决 Express**
   · PM 认为风险高可改判 Direct/Standard（须在「你下一步」写一句为什么）；用户点名标准/完整从其点名
   · 判定须含一句话 A# + 风险复述/升道出口（见 §Express 简略）；过程中命中升级立即改判
1.5 严格非功能微改旁路（步骤 1 的子集）：用户未要求 Full；**1 个**已跟踪文本业务文件；无 API/持久/跨模块/生成文件；只改注释或既有日志字符串（不增删调用）；slice 预计且改后 `git diff --numstat HEAD -- <path>` 新增+删除≤20、恰一行整数且 name-status 非R/C → Express；不满足 → 按步骤 2/3，不因回归/热度单独改判 Standard
2. Direct（直通道 · **PM 默认**）→ Direct
   · 有**行为变化**（即使 1 个文件），**或**机械改但已是 2～3 个业务源文件
   · ≤3 业务源文件；**无 API / 无持久（存档/序列化）/ 无跨模块**
   · **回归索引 / §车道升级路径 / 文件热度不单独升 Standard**
   · 策划子窗对话内出 A#/切片，**不落盘**；默认单会话完成，跨会话/改不完自动升 Standard
   · 当前为 Express 或 Direct 时命中止损 → **升 Standard**（不是 Full）
   · PM 可改判 Standard（须写一句风险）；用户点名标准/完整从其点名
   · 判定须含一句话 A# + 升道出口（默认「直通道」；架构/API/存档/跨模块/超 3 文件→「走标准道」）
3. Standard（难任务）→ Standard
   · **>3** 业务源文件 / 跨模块 / public API / 持久或序列化 / 说不清
   · Express/Direct **第一次**命中止损（升上来）
   · PM 书面改判（用户未点名完整流程）
   · **已判 Standard** 且命中回归索引模块 → 方案审 **L1.5**（加强审，不回头改车道）
   · **已判 Standard** 且文件/机器热度命中 → 方案审加强（L1.5 或更高档，不整条升 Full）。热度**不**单独决定进哪条车道
4. Full（完整道）→ Full
   · 用户说「完整流程」
   · **已经在 Standard 上再次命中止损**（止损两段：先标准，标准上再止损才完整）
   · 禁止仅因路径前缀、回归索引、>3 文件、存档、跨模块就 Full（这些走步骤 3）
```

### Express 升级（过程中立即改判）

| 触发 | 升级至 |
| --- | --- |
| 实际改动变成 2～3 个业务源文件（仍无 API/持久/跨模块） | Direct |
| 实际改动 > 3 业务源文件 | Standard |
| 出现行为变化（仍 1 个文件、无 API/持久/跨模块） | Direct |
| 跨模块 / public API / 持久 | Standard |
| 当前 Express 或 Direct 命中止损 | Standard |
| 当前已是 Standard 再命中止损 | Full |
| 用户说「完整流程」 | Full |
| 文件/机器热度或回归索引 / §车道升级提示路径 | **不单独升道**。PM 可改判 Standard（须写一句为什么） |

## 四车道 → 派岗

| 车道 | 流程 | 文档 |
| --- | --- | --- |
| **Express** | 一句话切片 → **一轮确认** → 子窗程序员 → 一行自检 → Unity 测；无 CR；默认不落盘、不建窗；**一旦已建分类夹** → [doc-windowing.md](references/doc-windowing.md) §与 Express（最小两文件 + 终态须 migrate；不强制 `未完成.md`） | Chat 一句话切片；须含 PM 判定 + 一句话 A# |
| **Direct** | PM → 子窗策划（对话内 A#/切片，不落盘）→ **一轮确认** → 子窗程序员 → 隔离 CR（普通档）→ 文档一行版本 → 用户接收；单会话 | 对话内 A#/切片（不落盘）；「文档一行版本」= README `dev-one-liner`，非落盘执行文档 |
| **Standard** | plan-lite → L1/L1.5/L2 → **一轮确认** → `[developer]` → `[CR]` → README | plan-lite；A# + delta-only |
| **Full** | TL 显式启用；见 [references/](references/) | 执行文档；须含验收 A# |

文档须含可证伪 **验收条款 A1…** 且 Step/切片写 **满足验收：A#**；只写相对现状变更（**delta-only**）。缺则方案审核 blocker。细则 → [acceptance-and-delta.md](references/acceptance-and-delta.md)。回归索引模块相关 Step 验收时：优先用 `scripts/verify-regression-smoke.ps1` 跑冒烟（命中 golden 且 UNITY_EXE 可用则自动跑，否则生成人工 Play 清单），并用 `scripts/collect-acceptance-evidence.ps1` 把日志尾部/截图/测试报告归入窗口 `证据/`（evidence.md）；**自动验证 ≠ 业务手测签收**，A# 仍以你亲眼看为准。

Express 完成后 **不得**再派独立「代码审核」。Standard：方案审无 blocker → 发一次确认包；「准」同条开始改码。普通 CR 无 blocker 后，Full 或热文件反复修复/运行仍异常 → PM **优先**可选 Subagent `代码审核 模式：对抗`；失败再提示手动新开；用户可跳过。细则 → [isolated-review.md](references/isolated-review.md)。

**一轮确认硬律** → [handoff-automation.md](references/handoff-automation.md) §0；白话包 → [demand-clarification.md](references/demand-clarification.md)。每决策点 1 条确认包；「准」同条定版/开窗/改码；续链用**合并包**。禁口令门、先改再补理由、零用户句改码。Standard/Full「准」**默认 Auto**（非车道；Express / Direct 不启用；退出「准, 不 Auto」）→ [loop-engineering.md](references/loop-engineering.md) + handoff §H：连跑实现→CR→待测；测挂默认同条跟可自动跟推荐（硬停除外，见 diagnosis §0）；用户停点=待测/AI 验/硬停；每 Step 仍要测（禁攒批）；口令「本窗 Auto」「继续 Auto」。Auto 链受 [loop-engineering.md](references/loop-engineering.md) §4 预算护栏约束（max_auto_steps / max_repair_rounds / 停滞 fuse / 超时硬停 / 可选 token 预算）。

## Standard 加强审核（L1.5）

**仅当已判 Standard**（步骤 4 **未**触 Full）。回归索引 / 热度**不得**把 Express/Direct 拉进 Standard。已判 Standard 且 Mandatory Code Changes 命中 project-context 回归索引**模块** → L1.5；或命中 `.ai-gates/lessons-learned.md` 近 6 个月记录（文件热度），或 `.ai-gates/regression-heat.yaml` 该模块 heat≥medium（机器热度）→ L1.5；**文件/机器热度命中取较高档：L1.5 之上 → 方案审 L3 / 双轮 CR（不整条升 Full）**（热度细则 → [plan-review-tiers.md](references/plan-review-tiers.md)）。

- **方案审核**：须子窗（同会话即可，不强制新 Chat 隔离）；plan-lite 档位 **L1.5**；Regression Validation **须引用**索引行
- **代码审核**：**优先** Subagent 隔离 + [cr-dispatch-l1.5.md](./templates/cr-dispatch-l1.5.md)；失败再提示手动新开；同 Chat 须标 **「非独立 CR」**
未触发 L1.5：CR 可同 Chat。

## Standard 交叉审核（L2）

步骤 4 **未**触 Full，且 Mandatory Code Changes **跨 2 个及以上业务模块** → 方案审核档位 **L2**（与 L1.5 可叠加，取较高档）。

- **方案审核**：**优先** Subagent 隔离；失败再提示手动新开；同 Chat 须标 **「L2 非独立复核」**
- **代码审核**：默认同 Chat；可升隔离
- plan-lite「方案审核档位」记 **L2**

## Standard 可选独立方案审核

`lane: Standard` 且 `review_tier: L1`（**未**触 L1.5/L2/L3）时，若 plan-lite **≥2 Step** 或改动面较广，PM **须**提示：可选用隔离审核（Subagent 或新开 Chat，可选）。已触发 L1.5/L2/L3 的规则不变。

## 硬门禁（7 条）

1. **没读真实代码不改** — 代码与仓库文件（有 git 时辅以 diff）> README > 文档/Express 切片 > 对话推断
2. **Express 先有一句话切片（PM 判定+一句话 A#）、Direct 先有对话内 A#/切片再改** — 无切片不得 `[developer]`；一次一切片；实改超范围立即升道
3. **Standard 须方案审；Direct 无方案审但须隔离 CR** — 未过方案审 / 未隔离 CR，不得 `implementation-ready` / 派程序员
4. **CR 有 blocker 不写最终 README**
5. **Unity 未测不得标「已通过」** — 例外：Skill/Doc AI 验收通过可抬升（见 [handoff-automation.md](references/handoff-automation.md) / [loop-engineering.md](references/loop-engineering.md)；非可不测）
6. **PM 不替岗** — 不写 Step 规格、不改代码、不替 CR 宣布无 blocker
7. **无 PM 门禁不改交付物** — 用户直接叫岗位名时，须同条先 `[PM]` 判车道并输出 **你下一步**；**本轮尚无 PM 结构化判定时不得**创建/修改代码、执行文档、README（只读咨询除外）

**反合理化（借口对照）**：无 `[PM]` 就写 / 日志关键词冒充 A# / 伪称隔离 CR → [anti-patterns.md](references/anti-patterns.md) §反合理化；评测 §K。

**非门禁**：隔离审核是否成功 / 用户是否手动新开 Chat / 换模型 — 只要求诚实标注，不硬阻断。缺 PM 结构化判定或 **你下一步**（含 Express 简略四条）→ **已阻塞**。

**机器强制层（如实）**：Codex CLI / Cursor 侧 hooks 可 deny 拦截；Codex 桌面应用对 `apply_patch` 钩子可能不触发（信任已批准仍零打点，关键写后自查 `.ai-gates/hooks-log/`）；Trae 为软层（规则 + 技能传送门，无机器 hooks）。`[PM]` **120 分钟窗口是近似门禁**（Stop 打点后一段时间内放行写入），**不是**「本条消息已完成结构化判定」。`failClosed: false`：hook 脚本失败则放行。kill switch `.ai-gates/hooks-log/pm-gate-disabled` 可整条关掉。硬门禁 #7 仍须自觉。本句不改 hook 行为。

**工作区卫生（非门禁）**：一次性中间产物（revision/hash 计算、压力测试、批量迁移脚本等）只放 **`.ai-gates/tmp/`**（不入库，环节收尾整目录清空）；不得散落在 `.cursor/` 根、`.ai-gates/hooks-log/`（运行时证据）或 `.ai-gates/skills|scripts|hooks|rules`（中央库内容）。细则 → [execution-discipline.md](references/execution-discipline.md) §工作区卫生。

## 无 project-context 冷启动

1. 只读咨询 → **不阻塞**。
2. **改代码** → `missing-coldstart`；**你下一步**须含「未初始化，默认直通道」+ 建议 **`项目经理 初始化`**；未初始化前：Express 仅机械且恰好 1 个业务源文件；行为小改或 2～3 文件默认 Direct（无 API/持久/跨模块）；>3 文件或 API/存档/跨模块 → Standard。细则 → [pm-init.md](references/pm-init.md)。

## 进阶指针（lazy load）

日常入口 → [agent-entry-route.md](references/agent-entry-route.md)（本页+project-context+岗 checklist + 任务白名单）。另按 [reference-routing.md](references/reference-routing.md) 点名≤2份 reference；禁整目录灌入。CORE 全文仅争议/recovery/`按 CORE 重来`。

## 岗位切换

| 调用名 | Skill 路径 | 首行标记 |
| --- | --- | --- |
| 项目经理 / PM | 读本 CORE | `[PM]` |
| 策划 / 方案审核 / 程序员 / 代码审核 | `planner` / `plan-reviewer` / `developer` / `code-reviewer` 下 `SKILL.md` | `[planner]` / `[plan-reviewer]` / `[developer]` / `[CR]` |
| 文档 / 周报 | `module-readme` / `weekly-report` 下 `SKILL.md` | `[docs]` / `[weekly]` |

切换岗位前 Read 对应 `SKILL.md`。Express 切片由 **`[PM]`** 输出，**策划不参与**。直叫岗位名须同条先 `[PM]`（硬门禁 #7）；无 slice/plan-lite 且未 ready 不得直接 `[developer]`。一轮确认「准」→ 同条 `[developer]`（[handoff-automation.md](references/handoff-automation.md) §0/§F）。

翻车索引 → [anti-patterns.md](references/anti-patterns.md)（**仅列近 90 天真实命中反模式、上限 15 条**，超限最低命中降级回完整表）。写方案/改码/扩 README 前 → [execution-discipline.md](references/execution-discipline.md) **复用四问**（已有→复用→少写/不写→能删）。测挂修复 → `证据/_repair-blackboard.md`；止损/`repair_rounds` 触顶 → **A#/口径复议**（[diagnosis-gates.md](references/diagnosis-gates.md) §0.6/§0.7），禁同 A# 死磕。错题 → 大纲 `.ai-gates/lessons-outline.md`（错因+改正）+ 方案「错题本必读」指路（[lessons-learned.md](references/lessons-learned.md)）。

## Agent 失败模式与恢复

用户 **主口令 `按 CORE 重来`**（同义：`流水线重来`、`没按流程来`）：

1. Read CORE + **若存在** project-context
2. `[PM]` 内部结构化判定（recovery **须**完整表 + **你下一步**）
3. Express → 补 express-slice + express-self-check（若已改代码）；Standard 缺 L1/L1.5 → 回 plan-lite / plan-reviewer
4. 说明上轮偏差；追加 [pipeline-recovery-log.md](./templates/pipeline-recovery-log.md)；快照见 [pm-tooling.md](references/pm-tooling.md)

**另一口令 `方案推翻`**（撤销已落地代码，非流程纠偏）：确认文件清单→用户确认→**列出** `git checkout -- <文件>` 请用户在终端执行（Agent 禁止经 Shell 跑该命令）→记录原因，细则 → [rollback.md](references/rollback.md)。

**PM 自检**：结构化判定 + **你下一步**；express-slice；A#；L1.5 派发块；子窗首回合核验（空上下文询问 → `fork_turns=all` 重派）；**一轮确认硬律**（handoff §0）；CR/Verify；止损含热修；首段=状态；未夸大 Unity/completed。

## Agent 必读顺序

1. **[agent-entry-route.md](references/agent-entry-route.md)** → 2. **project-context**（若有）→ 3. 当前岗 `SKILL.md` checklist → 4. 任务白名单（方案/Mandatory/README风险/真实代码）→ 5. 按 [reference-routing.md](references/reference-routing.md) 点名≤2份；Express另读slice/self-check。**CORE 全文**仅争议/recovery/`按 CORE 重来`
