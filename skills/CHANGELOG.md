# AI 开发流水线 — 变更日志

本文件记录 `.cursor/skills/` 流水线 Skill 的版本变更。

**当前 LTS**：v3.2.0（2026-07-21 · **定版**）

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 思路；版本号遵循语义化：**patch** 为措辞/文档/反模式补充，**minor** 为新增规则或岗位（向后兼容），**major** 为破坏性规则变更。

---

## [3.2.0] - 2026-07-21（流程收敛与正式发布；含同日机械化 Harness A/B/C/D 追加）

### Included changes — 2026-08-03（hooks 漂移对齐 + CHANGELOG 随包 · 不 bump）

#### Fixed

- `pm-gate-check.ps1` / `hooks.json`：与 MAINTAINER observe/ask 对齐——缺标记 → `permission: ask`（非 deny）；解析异常 fail-open `allow`；`pm-gate-check` 条目 `failClosed: false`（四 hook 全 false）。
- `test-hooks.ps1` A5/A6 期望同步为 ask / fail-open / 全 `failClosed=false`。

#### Added

- `validate-pipeline.ps1`：**hooks policy** 校验（MAINTAINER 声明 ↔ `hooks.json` / `pm-gate-check.ps1`）。
- MAINTAINER §发布检查清单：hooks 对齐与 CHANGELOG 随包勾选项。

#### Changed

- `package-release.ps1`：**纳入** `CHANGELOG.md`（仍排除 `MAINTAINER.md`）；`PACKAGE-INFO` 文案同步。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-29（结案迁夹硬项 · 不 bump）

#### Added

- `handoff-automation` §E：**结案检查单硬项**——终态须同条 `migrate-pipeline-window.ps1`（或同等）；未迁夹=未结案。
- `plan-reviewer` §3.7.3：终态仍停 `执行中/` → **blocker**。
- `anti-patterns` +1：终态未 migrate。
- `skill-eval-checklist` **C5e**：终态未迁夹 → Fail / `结案未搬家`。

#### Changed

- `doc-windowing` §迁移动作、`diagnosis-gates` §4、`developer` 状态分类夹、handoff §F 结案行：与 §E 硬项对齐。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（TEAM-GUIDE 补丁 · 不 bump）

#### Changed

- `TEAM-GUIDE.md`：修 README pre-commit 断链→MAINTAINER；方案夹路径改以 Agent/`project-context` 为准（去掉过时 `化学文档/压力系统`）；五态/三步补 Skill/Doc **AI 验收**；半页备忘缩为指针；coldstart FAQ 链 README §首次接入。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（README 冷启动重写 · 不 bump）

#### Changed

- `README.md`：按首次接入重写为冷启动索引（谁读什么 / TL 三步 / 3.2 要点指针：窗口化·Auto·AI 验·diagnosis / 精简模板与脚本表）；仍 ≤100 行；不复述 CORE/CHANGELOG。
- `MAINTAINER.md` / `anti-patterns.md` / `tl-onboarding.md` / `.cursor/rules/ai-dev-pipeline.mdc` / `.trae/rules/ai-dev-pipeline.md`：运行前指针统一为 README §首次接入。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（golden-scenes-from-project-context · 不 bump）

#### Added

- `project-context.template.md` / Chemical `project-context.md`：**§热路径批量回归**（路径 glob → 场景 ID；Chemical 填 `PressureManager/**` → `G1,G2,G5`）。
- `project-local-config.md`：标明该节属项目专属、禁止 Skill 正文写死场景 ID。

#### Changed

- `developer` / `handoff-automation` / `anti-patterns` / `diagnosis-gates`：结案义务改为「读 project-context §热路径批量回归」；去掉 Skill 正文硬编码 G1+G2+G5 / PressureManager 路径。
- `check-pm-step-golden-evidence.ps1`：说明默认 ID 可被 `-RequireSceneIds` / 项目表覆盖。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step5 · 不 bump）

#### Added

- `skill-eval-checklist.md` 节 **J**：J1–J5（预扫 blocker / 0→1 反思 major / 关系表 blocker·major / 档位未决 major / 空壳枢纽 major）。

#### Changed

- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step4 · 不 bump）

#### Added

- `planner` checklist **§2.7**：物理口径落盘前自检（硬句≥1、负面≥1、失败标准≥1；硬句可观察/点名；热修「与上游差异」句）。
- `plan-reviewer` checklist **§3.9.2**：缺项或硬句纯口号 → **major**。

#### Changed

- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step3b · 不 bump）

#### Added

- `plan-lite.md` / `execution-doc-template.md`：**方案审核档位**须单选（禁未决串）；Skill 改动默认 L1.5。
- `planner` checklist **§2.5**：空壳勿开/长期停执行中；档位单选；Skill 默认 L1.5。
- `plan-reviewer` checklist **§3.7.2**：档位未决串 → **major**；占位空壳停执行中 → **major**。
- `doc-windowing.md`：空闲枢纽「策划/方案审可机械引用」指针一句。

#### Changed

- 模板档位占位：未决 OR 串 → 单选说明 + 默认示例值。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step3a · 不 bump）

#### Added

- `plan-lite.md` / `execution-doc-template.md`：**## 窗口关系摘要** 四列表（主题短名 + Beads 枚举 + 状态 + 关键结论）；migrate/repair 搬家说明；示例 1 行（本步不改档位字段）。
- `plan-reviewer` checklist **§3.7.1**：缺关系表 → **major**；散文替代表 → **blocker**。

#### Changed

- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step2 · 不 bump）

#### Added

- `diagnosis-gates.md` **§1.4**：止损 0→1 后下一刀须点名「为什么上一轮不是最后一门」；空话（未点名门闸/调用边）→ major。
- `plan-reviewer` checklist **§3.8.1**：缺 §1.4 反思句或空话 → **major**。
- `anti-patterns.md` **+1 行**（本窗满 2 行）：0→1 后缺点名反思就再改码。

#### Changed

- `diagnosis-gates` §5 策划/方案审接线补 §1.4 检项。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（discover-path-prescan-window-rel · Step1 · 不 bump）

#### Added

- `diagnosis-gates.md` **§0.8**：Discover 全路径预扫——「跳」= 门闸/调用边（≠ CG 条数）；信号枚举最低集 + 正文扩写点名 `ShouldBypass*` / `force*`·`suppress*` / `TryAdvance*` 改道；CG ≥2 跳 → 读码 ≥1 跳；覆盖范围；≥2 挡点一次策略；BMAD 自包含；禁只开第一道门。
- `planner` checklist **§2.1.1**：挂 §0.8 指针（含最低集、扩写点名、「跳」定义、读码回退链）。
- `anti-patterns.md` **+1 行**：只开第一道门等失败再开第二道。

#### Changed

- `diagnosis-gates` §0.2 Discover 旁路 → §0.8；§5 策划/方案审接线补 §0.8 检项。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（hit-rate-hard-gates-p0 · Step2 · 不 bump）

#### Added

- `plan-lite` / `execution-doc-template`：每 Step 强制 `**DO NOT TOUCH（冻结表）**`（README 版本段+点名 API/文件；空=「无（已扫）」）。
- `plan-reviewer`：缺 DO NOT TOUCH 节 → **major**（窗级「不要动什么」≠ Step 冻结表）。
- `planner` checklist：写 Step 时强制该字段一句指针。

#### Changed

- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（hit-rate-hard-gates-p0 · Step1 · 不 bump）

#### Added

- CR/派发：交审须错题本必读 + 黑板证据路径；集成维强制扫冻结表/禁项（缺句/未扫=major；复现禁项/碰冻结=major/blocker）。
- developer：改码前/交 CR 证据自检；Mandatory 触及 PressureManager → 结案前 G1+G2+G5（关 Editor）；禁 G* 冒充 A#。
- `check-pm-step-golden-evidence.ps1`：静态核对 G1/G2/G5 证据 JSON pass（不替代跑黄金）。
- anti-patterns ≤2 行：交 CR 无证据路径；PM 刀未跑 G1+G2+G5 却标过。

#### Changed

- `handoff-automation` §C/Exit：PM 刀 `step-completed`/`runtime-validated` 前黄金义务一句。
- `diagnosis-gates` §0.2.1 / `loop-engineering`：薄指针 G*≠有意义≠A#。
- `run-unity-verify-golden.ps1`：补强「须关 Unity Editor」注释（不改断言）。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-28（repair-meaning-review-revert · 不 bump）

#### Added

- `diagnosis-gates.md` §0.2.1：**有意义评审**（有|无|部分有；再改码前写黑板；无/测偏 → 定向撤 + 禁同 A# 热修）。
- `repair-blackboard.md` 条目字段：`有意义评审`、`保留原因 / 已撤`。
- `anti-patterns.md` ≤2 行：禁验挂红 `git reset --hard`；禁 G1/G2/G5 绿冒充有意义。

#### Changed

- `diagnosis-gates` §0.1/§0.1.1/§0.2/§0.6：硬停「止损将到 2/3」停 Auto；评审后再进 §0.3 热修行。
- 薄指针：`loop-engineering` / `handoff-automation` / `reference-routing` / `CORE` / `README` 各一句挂有意义评审。
- **不 bump** `VERSION`（仍 3.2.0）。

### Included changes — 2026-07-27（golden-ml-gate · 不 bump）

#### Added

- `verify-runtime-evidence.ps1`：可选 `-MinVolumeMl` / `-MinSumVolumeMl`；Keywords 命中行解析 `volume=…ml`；默认 **Or** 门禁；JSON 附加 `volumeMax`/`volumeSum`/`volumeSampleCount`/`volumeGate`/`volumeGatePass`。
- 假绿复放：`golden-ml-gate-g3g4-play/证据/_replay-tiny-volume-fake-green.log`（仅 ~0.001ml LiquidEgress；双阈须红）。

#### Changed

- `golden-scenes.yaml`：G1/G2/G5 写入 `minVolumeMl: 0.05` + `minSumVolumeMl: 0.5`（G3/G4 本步不加体积阈）。
- `run-unity-verify-golden.ps1`：解析并传递体积阈；默认 `OutputDir` 优先发现 `golden-ml-gate-g3g4-play/证据`（回退 g2-r）；注释声明黄金绿≠业务手测签收；PS1 UTF-8 BOM + 中文路径码点发现。

### Included changes — 2026-07-27（hygiene-force-wire-entry · 不 bump）

#### Added

- `detect-empty-pipeline-windows.ps1 -FailOnCandidates`：dry-run 且空壳候选>0 → exit 1（默认仍 exit 0）。
- `pre-commit-pipeline-advisory.ps1`：**Gate B**（空壳 FailOnCandidates）+ **Gate A**（Runtime `.cs` 变更且声明源全部 `editable=no`；无声明不拦）；**`-BaseRef`** 供 CI 用 `base...HEAD`（与 pre-commit staged 分流）；LabSDK **submodule tip** 变化时下钻 `Runtime/**/*.cs`。 CI workflow `submodules: recursive`；tip 变但 drill 失败/空 → Strict 非零。
- 薄 CI：`.github/workflows/pipeline-hygiene-gate.yml`（windows，`fetch-depth:0`）同调 advisory `-Strict -BaseRef`；缺脚本 exit 2（禁伪绿）；与 Unity/PressureManager gate 解耦。
- anti-patterns：状态分类搬家不跑 migrate（手挪漏改链）。

#### Changed

- `doc-windowing` §迁移动作第 6 步：「推荐」→**必须**调用 `migrate-pipeline-window.ps1`；禁手挪后只改状态/漏改链。
- README 辅助脚本表 + MAINTAINER optional pre-commit：migrate 必调、空壳/editable 门禁已进 Strict；CI 用 `-BaseRef`。
- Strict 下缺 `check-pipeline-doc` / `detect-empty` → 非零（禁 skip 伪绿）。
- **入口一致性收尾**：MAINTAINER / reference-routing / 各岗 SKILL / anti-patterns / execution-discipline 去掉「日常必读/通读 CORE 全文」「日常唯一权威=CORE」「基线三件套含 CORE」残留；日常入口只留 `agent-entry-route`；争议/recovery 仍可指 CORE（不 bump；「准」硬律不变）。

### Included changes — 2026-07-27（skill-hygiene-thin-route · 不 bump）

#### Added

- **日常入口**：`references/agent-entry-route.md`（默认必读本页 + project-context + 岗 checklist；CORE 全文仅争议/recovery/`按 CORE 重来`；第二跳仍按 `reference-routing` 点名 ≤2）。

#### Changed

- CORE / README「谁读什么」：Agent 日常入口改指 `agent-entry-route`；`demand-clarification` + CORE §Express 再砍确认话术（一轮确认硬律与拍板口令「准」不变；禁多轮空转含义不变）。
- **alwaysApply 闭环**：`.cursor/rules/ai-dev-pipeline.mdc` 入口改为先读 `agent-entry-route.md`（CORE 全文仅争议/recovery/`按 CORE 重来`）。

### Included changes — 2026-07-27（CRG 审核岗分流 · 不 bump）

#### Changed

- **图谱分岗**：日常（策划/程序员/Discover）仍 **CodeGraph**；**方案审 / 代码审优先 CRG**；需原文再窄补 CodeGraph；禁两套完整双跑。
- 接线：`codegraph-probe.md` 优先级表；`plan-reviewer` / `code-reviewer` / `cr-dispatch-l1.5`；项目 `project-context`「代码审核图谱工具」（LabSDK 子模块须单独 `build`）。

### Included changes — 2026-07-27（错题大纲 + 错因/改正 · 不 bump）

#### Added

- **错题大纲**：模板 `templates/lessons-outline.md`；项目 `.cursor/lessons-outline.md`（按桶分类；每条强制 **错因** + **改正** + 主表锚点）。
- 方案强制节 **`## 错题本必读（给程序员）`**：策划指大纲桶 + 主表锚点；程序员改码前只读点名行；方案审缺节/假「无」→ major。

#### Changed

- L1 主表与 pending/脚本增加 `cause`/`fix`（错因/改正）；新行必填；`lessons-learned` 检索改为大纲优先；planner/plan-reviewer/developer/CR/anti-patterns/CORE 接线。

### Included changes — 2026-07-27（证据黑板 + 触顶 A# 复议 · 不 bump）

#### Added

- **证据黑板**：方案夹 `证据/_repair-blackboard.md`（模板 `templates/repair-blackboard.md`）；测挂/交审失败同条追加「改了什么→为何失败→禁止再做」；派修注入最近 ≤3 条；doc-windowing 点名可读例外。
- **触顶强制 A#/口径复议**：止损线或 `fuse reason=max_repair_rounds`（及热修已强制止损重定界）→【推荐】必须复议且 `auto_follow: no`；确认包改 A#/口径后再开刀；禁同 A# 续烧、禁 Express 免审伪装。

#### Changed

- `diagnosis-gates` §0.2/§0.3/§1.2 + 新 §0.6/§0.7；`loop-engineering` fuse 恢复链；`handoff` 失败路径；developer/CR/anti-patterns/reference-routing/CORE 薄指针。

### Included changes — 2026-07-24（Auto 仅停人工测 · 1A+2A · 不 bump）

#### Changed

- **Auto 用户停点收成**：启用后只停待验（`unity_test` / AI 验收）、`max_auto_steps`、与 diagnosis **硬停白名单**；实现↔CR 与可自动跟的测挂推荐**不再**发选型确认包。
- **测挂 1A**：`auto_follow: yes`（只读 Discover / 范围内热修或同窗下一刀）→ 同条采纳【推荐】并留据 `Auto采纳推荐：…`；硬停（止损/fuse/异现象/规格漂移开码前/范围外扩/改 Mandatory 外边界）与「请你补测」仍等人。
- **2A 不变**：每 Step 必验；禁止多 Step 攒批再验；自动跟≠免验。
- 接线：`loop-engineering` §2/§7/§8；`handoff-automation` §D/§H；`diagnosis-gates` §0（矩阵增 `auto_follow`）；`demand-clarification` 多选/确认包文案；`anti-patterns`；CORE / TEAM-GUIDE 薄指针。

### Included changes — 2026-07-22（Skill/Doc AI 静态验收 · 不 bump）

#### Added

- **原则：能 AI 测则高规格子窗验，不能再人测。** Skill/Doc-only Step（无业务 C# 且 Unity∈{无,N/A,Skill/Doc-only}）在 CR 无 blocker 后默认派 `mode=verify` 验收子窗；通过≡「测试通过」可抬升 `runtime-validated` 并 Auto 续。
- `mode=verify` 派发齐套：`review-dispatch-lifecycle` + `templates/verify-dispatch.md` + 模型表「验收/verify」高质量行；Exit Gate / handoff 机械接线（`await_verify` / `ai_static`）。
- CORE 硬门禁 #5 **一句**例外：Skill/Doc AI 验收通过可抬升（结构冻结，无新 `##`/`###`；非可不测）。
- anti-patterns ≤2 行：主窗代验冒充隔离；验收缺 `model=`/用实现档或验收子窗改仓库交付物。
- `code-reviewer` Checklist §C 收口：命中则提示派验收子窗，禁自动 `runtime-validated`。

#### Changed

- 硬门禁 #5 主句保留；业务 C# / 非免测集合仍只走 `await_human unity_test`；用户「测试通过」/「你直接测」覆盖权不变。

### Included changes — 2026-07-22（窗齐套 kit / 校验 / 路径纠错 · 不 bump）

#### Added

- `templates/phys-spec.md`：物理口径骨架模板。
- `scripts/new-pipeline-window.ps1`：一次生成执行中窗五件套（含根 `.kit-v1`）。
- `scripts/repair-doc-crosslinks.ps1`：短名分类夹链接只读扫描；`-Path … -Apply` 仅改唯一命中的 Markdown 链接；反引号 REPORT-ONLY；无 `-Path` 的 `-Apply` 拒绝。
- `check-pipeline-doc.ps1`：执行中 150 行门禁、`.kit-v1` 强制物理口径、`-CheckLinks`（三类独立分支）。
- `doc-windowing.md` §新窗齐套标记（kit）；anti-patterns / reference-routing 短接线；README/MAINTAINER 指针。

#### Changed

- `plan-lite.md` 链接节：物理口径区分新窗强制 / 历史不强制。

### Included changes — 2026-07-22（空闲枢纽迁签收 · 不 bump）

#### Fixed

- **空闲停执行中**：纠正 07-17「枢纽空闲进执行中」误规则。`doc-windowing.md` / `doc-path-defaults.md`：`执行中/` 仅活跃（开窗/改码/待测/诊断）；无活跃 Mandatory、无可改码窗的空闲枢纽同条迁 **签收/**；续作迁回执行中或新开短窗；临时停笔未结案用 **停写/**。
- `anti-patterns.md` + 评测 **C5d**：空闲长期停 `执行中/` → Fail（`拖延归档`）。
- `planner/SKILL.md`：落盘说明同步「空闲/结案→签收」。

#### Changed

- **模型路由项目化**：`model-routing.md` 改为通用框架（档位 + 默认表示例 + 解析顺序）；**具体 slug/回退链**进 `.cursor/project-context.md` §模型路由（Chemical：实现 Grok→Composer；策划/方案审/CR Sonnet→Grok）。模板 / `project-local-config` / 各岗 SKILL / CORE / TEAM-GUIDE / rules 去业务硬编码；派 Task 仍须显式 `model=`。
- **高风险隔离审核优先异模型**：`isolated-review.md` 新增 §高风险审核异模型——L1.5 CR / L2 / L3 / 对抗 / Full 业务 C# 派发 Subagent 时优先与主窗不同模型；**首选 Sonnet 5**（Task `model: claude-sonnet-5-thinking-medium`）；主窗已是 Sonnet 5 则改选另一族；不可用则回退 `inherit` 并标「同模型隔离」，**不硬拦**。CORE / TEAM-GUIDE 同步一句。仍不得夸大为「多模型真人交叉审」。
- **模型路由（初版 · 已被同日「模型路由项目化」覆盖）**：新增 `references/model-routing.md` 时，Skill **默认表示例**曾为策划/L3=Sonnet、实现=`composer-2.5-fast`（回退 terra/grok/`inherit`）。**勿再当现行约定**；现行=档位框架 + `project-context` §模型路由（见上条）。
- **策划/实现优先子窗**：`model-routing.md` 升级为「模型路由 + 子窗派发」——主窗默认只做 PM 枢纽；写方案与改码与审核一样**优先 Task/Subagent**（最短派发包）；失败再手动新开 Chat 或标「主窗执行」。Auto 禁止主窗静默连改多 Step。TEAM-GUIDE / planner / developer / CORE 同步。
- **主窗仅 PM（流水线岗子窗）**：钉死主窗不得兼 `[planner]`/`[developer]`/`[CR]`/`[plan-reviewer]`/`[docs]` 写改；有 Subagent 时上述岗**必须**子窗；降级须标「主窗执行（未开子窗 · 非独立）」。**周报例外**：用户单独调用，不要求子窗。只读咨询仍可由主窗 PM 代答。各岗 SKILL + TEAM-GUIDE + CORE 同步。
- **错题本准全自动**：`lessons-learned.md` 升级——测挂**强制自动 L0**；可晋升时**强制自动** `证据/_lesson-pending.md`；主窗只问「准/不准/改」；用户「准」后 `scripts/commit-lesson-pending.ps1 -Apply` 写入主表（仍禁止静默写主表、不做默认准）。模板 `templates/lesson-pending.md`；developer/CR/planner/diagnosis-gates/TEAM-GUIDE/MAINTAINER/anti-patterns 接线。
- **效果轻量版**：签收/结案自动追加 `.cursor/pipeline-outcome.log` 一行（`verify_fails` / `rounds_to_pass` / `first_pass` / `why_multi` / `repair_rounds`）；`summarize-pipeline-outcome.ps1` 月末汇总一次通过率与平均轮数。模板 `pipeline-outcome-log.md`；接线 handoff §F、retrospective-metrics、pm-tooling、TEAM-GUIDE；日志 gitignore。
- **每窗兑现清单 + 数据改规则表**：`retrospective-metrics.md` 钉 1–6 勾选与 `why_multi`→单条规则映射；handoff §F 结案同条勾选。
- **异现象闸门（`why_multi=scope`）**：`diagnosis-gates.md` §0.1/§0.2/§0.3——Discover 钉死可见症状≠本窗 A#/目标时，默认推荐「挂起本窗 + 另开短窗」；禁并修、禁误烧止损 3/3。
- **commit-lesson-pending**：引号内保留 `A#` 等字面量，不再当 YAML 注释截断。
- **复用四问（精简门禁）**：`execution-discipline.md` 强制写文档/方案/改码前答「已有→复用→少写/不写→能删」；plan-lite 每 Step 字段；planner/developer/docs/plan-reviewer/CR/anti-patterns 接线；缺表或可复用却新开轨 → 方案审 blocker。
- **项目硬阈指针**：`execution-discipline` 指向 `.cursor/project-context.md` 可配 Mandatory 替换句式 / 新方法行数 / 交审瘦身一拍（Chemical 已落 §神类止血·补强三口）。
- **派发 revision Ordinal + L3 转场纪律**：`review-dispatch-lifecycle.md` §3 钉路径排序须 `StringComparer.Ordinal`（禁文化 Sort）；§5 转场仅可改排除三节，改正文须清零重生第1轮——消 `stale_dispatch` 假阳性。
- **Skill 查漏接线**：TEAM-GUIDE 版本对齐 3.2.0 + 防膨胀 FAQ；`reference-routing` 增加复用四问/派发 Ordinal 触发；planner/developer/plan-reviewer/CR 接线 project-context 补强三口。
- **每窗兑现半页模板**：TEAM-GUIDE §半页备忘 + `templates/window-fulfillment-halfpage.md`；handoff / retrospective-metrics 指针。

### Added

- VERSION 单一当前版本源、版本/流程 Strict 校验、v3.2 H1～H6 发布前评测。
- 严格非功能微改 Express 旁路、业务 C# 最小验证与连续两轮静态停车。
- 结案变更摘要、150行活跃窗软上限、references 按需读取路由。
- Loop/Auto、派发 revision、错题本、会话交接与 CR 集成维。
- 机械化 Harness 支柱 A～D（同日追加，见下方「Included changes — 机械化 Harness」小节）：运行时证据取证脚本、方案状态外置脚本、hook 行为回归测试、PM 门禁检查 hook；`loop-engineering.md` 范围化预授权。

### Release validation

- Strict 校验、v3.2 发布前 H1～H6a 及保留能力映射均通过；H6 最终版本单源闸在本次原子 bump 后复核。

### Included changes — 机械化 Harness 支柱 A/B/C/D + 范围化预授权（同日追加）

#### Added

- `scripts/verify-runtime-evidence.ps1`：运行时证据机械化取证（支柱 A）。读 Editor.log 关键词命中/新鲜度/编译错误扫描，产出带时间戳 JSON 证据文件，取代 Agent 纯口头转述"查过日志"；后续加厚 `-ExpectAbsentKeywords`——不该出现的关键词/审计标签命中即 `anyAbsentHit=true` 判失败，补齐"预期事件发生了"证不了的另一半"不该发生的没发生"。`unity-editor-log.md` §0 把该脚本列为取证优先手段，§A/§B 手工流程保留为无脚本环境退回路径。脚本本身**只产出事实，不判定** `static-checked`/`runtime-validated`；证据等级仍按现有规则由人/Agent 决定——不新增硬门禁，不改车道判定。
- `scripts/update-doc-state.ps1`：方案夹状态外置（支柱 B，可选接入）。`.state.json` 机器管理 `doc_status`/`lane`/`stop_reason`/`auto_steps_done`/`repair_rounds`/止损计数；非法状态迁移（跳级/倒退）脚本直接拒绝退出，人工越权须 `-Force -ForceReason` 显式记录进 `.state-history.jsonl`。`loop-engineering.md` §1.5 说明**可选**接入方式；`未完成.md` 叙述性状态段落不变，`.state.json` 不同步时以其为准——**未强制**已有方案夹迁移。
- `.cursor/hooks/pm-gate-check.ps1` + `mark-pm-gate.ps1`（preToolUse + afterAgentResponse，支柱 D）+ `scripts/test-hooks.ps1`（支柱 C，机械化行为回归覆盖 6 个 hook 脚本）。`.gitignore` 补 `**/.state.json`/`**/.state-history.jsonl`（方案夹机器状态本地缓存，不进版本库）。`MAINTAINER.md` 收录支柱 A/B/D 脚本与 hook 索引。
- `loop-engineering.md` §1.6：范围化预授权（可选 · 有额度 · 不免测）——同一方案/同一物理口径下、方案里已逐条列出的参数级微调 Step，可用「预授权 N」一次性免去逐 Step 确认包；仍受现有 Auto 预算约束、仍逐 Step Unity 签收，出现 scope 漂移立即失效。`handoff-automation.md` 一次确认包模板同步接一行可选提示。`anti-patterns.md` 补对应滥用反模式一条。
- `skill-eval-checklist.md` §I：机械化 Harness 支柱 A/B/D + 范围化预授权评测剧本（I1～I4，新增失败标签 `机械门禁自绕过`）。首轮本会话内走读 7/8 Pass——**I2b Fail 如实入账**：本会话诊断阶段 Agent 曾手动重放 `mark-pm-gate.ps1`（全程向用户公开，非隐瞒绕过），仍按 I2b 字面标准判 Fail，不因动机豁免评分。I1/I1b/I1c 尚缺真实 Full 车道项目案例，留待补真演。

#### Changed

- `.cursor/hooks/pm-gate-check.ps1`：`permission` 由 `deny` 降级为 `ask`（不再是硬拒绝）。原因：真实会话验证发现 `mark-pm-gate.ps1` 落盘时机不可靠（`afterAgentResponse` 确认触发过，但同一会话连续 3 次完整回复里出现 `[PM]` 都没能写出标记文件），`deny` 在标记缺失时会把人逼进死路；改 `ask` 后转人工确认，不产生死路，仍保留"提示未检测到 PM 标记"的机械层。根因未定位，待坐实后再评估是否恢复 `deny`。
- `anti-patterns.md` §实现与代码审核：新增反模式条目——在已被序列化/持久化引用的枚举（`[SerializeField]`/配置资产/存档/网络协议）中间插入新成员且不显式赋值，会导致底层 int 集体错位、旧数据静默对应到别的枚举名；正确做法为只在末尾追加或每个成员显式 `= N`。

### Included changes — Auto 默认开启（原未发布）

### Changed

- Standard/Full 确认包「准」**默认启用 Auto**；退出口令「准, 不 Auto」；须提示「不 Auto 会怎样」
- `handoff-automation` §H/§F、`demand-clarification` 确认包/续链、`loop-engineering` 口令表、`anti-patterns`、CORE 散文、TEAM-GUIDE §Auto
- Express **仍不**启用 Auto；不取消每 Step 待测；不 bump

### Included changes — 2026-07-20（会话交接 + CR 集成维 · 不 bump）

### Added

- `references/session-handover.md` + `templates/session-handover.md`：跨 Chat 八段摘要（当前状态/已做/下一步/禁区/依赖/风险/证据路径/下一口令）
- `handoff-automation.md` §J：预算用尽/结案/用户交接触发
- CR **集成维（必扫）** + 派发 `dimensions: quality+integration`（安全按需）；findings 须含集成维一句

### Changed

- `code-reviewer/SKILL.md`：审查重点收为「质量/集成/安全」维；复审再勾集成维
- `templates/cr-dispatch-l1.5.md`、`isolated-review.md`：dimensions 接线
- `MAINTAINER.md`：索引一行；不 bump；**未**改 CORE

### Included changes — 2026-07-20（错题本 Lessons Errorbook · 不 bump）

### Added

- `references/lessons-learned.md` + `templates/lessons-learned.md`：L0/L1 列与触发；测失败仅 L0；「准」≠根因
- 评测 E5/E5b/E6 + 夹具 `Assets/Doc/_examples/skill-eval-errorbook/`（短窗 + meta + `_评分表` 6/6 Pass）
- 四岗位 / handoff 经验提议节 / MAINTAINER：L0 草稿与 Skill 流程薄指针

### Changed

- `review-dispatch-lifecycle.md`：排除视图统一 LF（阶段 B，Step1 签收后）
- `.cursor/lessons-learned.md` 表头对齐新列；`anti-patterns` 静默写 / 全表灌补强
- CORE：**未**加新指针（已满 ≤200）；本条仅 CHANGELOG

### Included changes — 2026-07-20（Loop Engineering / Auto · 不 bump）

### Added

- `references/loop-engineering.md`：Auto 外环（停机/恢复/预算/双计数/口令/Skill-Doc soft risk）
- `handoff-automation.md` §H / §I；`state-machine` Auto 映射；anti-patterns Auto/派发行
- CORE 派岗后散文薄指针；TEAM-GUIDE Auto 薄段（≤15 行）
- `references/review-dispatch-lifecycle.md` + `templates/review-dispatch.md`；评测 F1～F1m / G1～G1f 与夹具

### Changed

- `developer/SKILL.md`：Auto 下仍一次一 Step；交 CR 前生成代码派发工件
- 四岗位 + plan/code-reviewer：点名派发优先；Skill/Doc 无 CodeGraph = soft risk
- `CORE.md`：压缩至 ≤200 行（无新标题）
- `anti-patterns.md`：Full 无 CodeGraph hard blocker 限定为业务 C#；Skill/Doc-only 并列 soft risk

### Included changes — 2026-07-17（文档状态分类夹 · 不 bump）

### Added

- **状态分类夹**：`doc-windowing.md` / `doc-path-defaults.md` — 文档根下 `执行中|签收|失败|回退|停写|换层`；状态变更同条搬家；方案夹不加前缀；**失败与止损合并为「失败」**；策划新建默认 `执行中/`

### Changed

- `planner/SKILL.md` 落盘路径默认含 `执行中/`
- **枢纽空闲进执行中**：主题枢纽（含空闲）不再留根；legacy 完成→签收、未完成→窗口化进执行中

---

### Included changes — 2026-07-17（P1.5 落地 · 不 bump）

### Added

- **Delta Spec 形式化**：`acceptance-and-delta.md` §Delta Spec；`plan-lite` / `express-slice` / `execution-doc-template` 每 Step ADDED/MODIFIED/REMOVED；签收后口径收敛；评测 C7/C7b/C7c

- **Developer Reflexion 微循环**：`developer/SKILL.md` §4.5；与 §7 计数边界；评测 D5 启用 ≥50%

- **成功路径经验提议**：`developer` §8.5、`code-reviewer` §1.5、`handoff-automation` §F、`lessons-learned`；须「准」写入；评测 E4

### Changed

- `planner` / `plan-reviewer`：缺 Delta Spec → blocker

- `anti-patterns.md`：Delta / 微循环 / 经验相关反模式

- 分析文档 P1.5 标完成；夹具 `Assets/Doc/_examples/skill-eval-p15/`

---

### Included changes — 2026-07-17（真实 Express / Standard+L1.5 闭环证据入账 · 不 bump）

### Changed

- **`MAINTAINER.md` §RC 转正条件**：勾选「真实 Express」— 证据 `Assets/Doc/_examples/express-closed-loop-console-log-mirror/`（Console Log Mirror · Editor 签收 runtime-validated）

- **`MAINTAINER.md` §RC 转正条件**：勾选「真实 Standard + L1.5」— 证据 `Assets/Doc/_examples/standard-l15-closed-loop-console-log-mirror-toolbar/`（去顶部工具栏 · Editor 签收 runtime-validated）

- **分析文档**：Express / Standard+L1.5 闭环均标 ✅

---

## [3.1.4] - 2026-07-16（A～D 真演 Pass + RC 转正 · patch）

> TL 确认「bump / 转正」。收口 2026-07-16 全部「未发布」项；Skill 评测 A～D **21/21** 真演 Pass（≥90%）。观察期「候选定版 RC」结束，标 **定版**。  

> 说明：定版时以评测 Harness Pass + TL 书面转正为准；真实 Express 闭环证据于 **2026-07-17** 补齐（见上条「未发布」）；Standard+L1.5 仍建议后续补记。

### Added

- **`diagnosis-gates.md` §0.5 规格漂移闸门**：Discover 根因改判后须先更新 `物理口径.md`/A#，再开下一 Step/热修 Mandatory

- **`doc-windowing.md` §热修/切片失败或回退即封存**：含防过度归档 / 拖延归档

- **`state-machine.md`**：`archived(已封存-失败/放弃)` 终态

- **`references/skill-eval-checklist.md`**：评测清单迁入 skills；剧本 C5b/C5c/C6；失败标签 `拖延归档`、`口径滞后`

- **`anti-patterns.md`**：Archive / 口径滞后相关反模式

- **`unity-editor-log.md` §B**：Discover/Verify 优先关键词查 Editor.log

### Changed

- **RC → 定版**：README / CORE / MAINTAINER / TEAM-GUIDE / CHANGELOG / `.mdc` / `.trae/rules` / 校验脚本头去「候选定版 RC」

- **`skill-eval-checklist.md` §评测记录**：有效 **21/21 = 100%**（真演）；明细 `Assets/Doc/_examples/skill-eval-ad/_评分表.md`

- **MAINTAINER**：§RC 转正条件勾选评测项；LTS 改为 v3.1.4 定版

---

## [3.1.3] - 2026-07-15（一轮确认硬律 · patch）

### Changed

- **一轮确认硬律**（`handoff-automation.md` §0）：每个决策点只 1 条确认包；「准」后同条自动定版 / 开窗 / 开始改码

- **确认口令**：默认只教 **「准」**；确认包正文禁止「开干」「做吧」「听你的」（旧口语仅兼容识别）

- **续链合并包**：开窗 + 本步方案 + 开始改码合成一轮；禁止「请说开 γ」与开窗/改码两轮确认

- **`demand-clarification.md` / CORE / 策划 / 方案审 / 程序员 / TEAM-GUIDE / anti-patterns / doc-windowing / diagnosis-gates / state-machine**：对齐上述；流程用语「开干」改为「开始改码」；§B 降为中断恢复口令

### Notes

- 仍为候选定版 RC；不因本 patch 自动满足 RC 转正条件

- Unity 实测与根因拍板仍须人工；自动化只砍手续空转

---

## [3.1.2] - 2026-07-15（窗口化 / 诊断闸门 / 转场自动化 · patch）

> 汇总 **2026-07-14～07-15** 原「未发布 · 不 bump」条目；向后兼容增强。RC 观察期继续（仍缺 Express / Standard+L1.5 完整闭环证据）。

### Added

- **`references/doc-windowing.md`**：一方案一文件夹（`未完成` / `已完成` / `物理口径` / `证据`）；审核禁读归档；Mandatory 外置；Discover≤15 行；首段=状态；新案必须文件夹；活跃可改码窗登记

- **`references/diagnosis-gates.md`**：Verify→Discover 矩阵；止损线；热修旁路；双轨收敛；结案封存

- **`references/handoff-automation.md`**：定版手续 / 开干同条派程序员 / CR 收口 / Verify→blocked / completed 证据门

- **`references/hooks-advisory.md`**：硬 Hooks 观察期（暂不启用）

- **`templates/doc-folder-已完成-索引.md`**

### Changed

- **止损（07-15）**：热修失败计入同一白话现象；连败≥2 禁再开热修；累计≥3=止损；禁「新切片」清零；放行须合取；热修改执行面须双轨一句

- **决策与确认（07-14）**：多选必写【推荐】【为什么】；禁止静默代选；确认要点强制白话现象

- **CodeGraph（07-14）**：禁「额度用尽」弃用；流水线优先于 CRG

- **状态机**：禁自造状态名；禁 ready+completed 双写

- **岗位 / CORE / TEAM-GUIDE / anti-patterns / validate-pipeline / project-context.template**：同步上述规则

### Notes

- 不强制迁移既有业务文档；下一轮 Verify 起按新闸门执行

- RC 转正条件未因本 patch 自动满足

---

### Included changes — 2026-07-13（隔离审核优先 Subagent · 不 bump 版本号）

> 来源：Cursor Agent（GPT-5.6）可自行拉起独立 Agent/Chat 标签页做 L3/CR；将「提示用户手动新开 Chat」升级为「优先 Subagent 隔离会话」。

### Added

- **`references/isolated-review.md`**：隔离审核权威——优先级 Subagent → 手动新开 Chat → 同 Chat（须标非独立）；标注三分法：隔离复核（Subagent）/ 独立复核（新 Chat）/ 非独立复核

- **CORE / plan-review-tiers / plan-reviewer / code-reviewer / cr-dispatch-l1.5**：L1.5 CR、L2、L3、对抗模式改为优先主 Agent 拉起隔离会话；派发块可同时用于 Subagent 与手动新 Chat

- **边界保留**：仍不硬校验用户是否接受隔离；不得把同 Chat 岗位切换伪装成独立审；Unity 定版仍由用户决定

---

### Included changes — 2026-07-13（PM 初始化半自动接入 · 不 bump 版本号）

> 来源：降低新项目冷启动摩擦——把 TL 三步起步收成对话口令 `PM 初始化`，脚本做探测与安全创建，CodeGraph 安装仍需明确同意。

### Added

- **口令** `PM 初始化`（同义：`项目经理 初始化` / `流水线初始化`）：`[PM]` 不判车道派岗，按 [references/pm-init.md](./references/pm-init.md) 半自动接入

- **`.cursor/scripts/pm-init.ps1`**：默认探测 project-context / 文档根 / CodeGraph；`-Apply` 创建缺失的 context（调用 `init-project-context.ps1`）与文档目录（默认 `Assets/Doc/` + `Weekly/`）；`-InstallCodeGraph` 仅在用户同意后尝试 CLI 安装/init

- **文档入口**：`CORE.md` 特例口令 + 冷启动改指向初始化；`TEAM-GUIDE.md` / `README.md` / `tl-onboarding.md` / `.mdc` / `.trae/rules` 同步；`validate-pipeline.ps1` 将 `pm-init.md` 纳入必选 references

### Notes

- 不覆盖已有 `project-context.md`（无 `-Force`）；非默认文档根时 Agent 须改写 project-context「执行文档存放约定」

- 技术栈与回归索引仍须人工填写，脚本不编造业务场景

---

### Included changes — 2026-07-13（高风险代码审核对抗模式 · 不 bump 版本号）

> 来源：将 L3 已验证有效的“换角度攻击”下沉到代码审核层，但不新增岗位、不强制独立 Chat，保留用户对“是否已经足够好”的最终判断权。

### Added

- **`code-reviewer/SKILL.md` 对抗模式**：普通 CR 无 blocker 后，Full 车道、Standard 热文件反复修复/运行仍异常、或用户主动要求时，PM 提示可新开 Chat 执行 `[CR-对抗]`；假设程序员与普通 CR 共享错误前提，优先攻击语义理解、数据来源/回退、调用顺序/生命周期、边界反例和验证盲区

- **证据与措辞边界**：对抗审查只读；怀疑点须附代码证据或可执行验证方法，证据不足不得制造 blocker；未推翻时只能写“暂未推翻普通 CR 结论”，不得宣称实现绝对正确

- **普通 CR 语义审查维度**：检查变量名/方法名/注释呈现含义是否与真实行为一致；严重度按实际影响判定，不因“有嫌疑”或进入对抗模式自动升级

- **`CORE.md` PM 路由提示**：将高风险对抗 CR 纳入“提示新 Chat、不校验”的用户自主选择边界；Express 明确不启用

- **策划侧语义陷阱前置**：`planner/SKILL.md` 要求读取真实代码时主动寻找 Agent 易错语义；Standard 的 `plan-lite.md` 每 Step、Full 模板的 Pitfalls 增加固定落点，记录「符号 + 实际语义 + 文件/类/方法证据」；允许“未发现”，但须列出已检查的关键符号，避免为完成 checklist 编造陷阱

- **方案审核门禁**：`plan-reviewer/SKILL.md` 核对每 Step 的 Agent 易错语义字段及证据；缺字段、空泛无证据或明显凑数视为 blocker

- **程序员自我质疑三问**：`developer/SKILL.md` 在交自检/CR 前强制反查命名推断、真实数据来源/回退/调用链/生命周期及“若理解相反会破坏什么”；无法证实时停下交 PM，交接增加精简的「语义自检」结果

---

### Included changes — 2026-07-10（借鉴 Spec Kit 验收硬度 + OpenSpec delta-only · 不 bump 版本号）

> 来源：对照 Spec Kit（可证伪验收）与 OpenSpec（只写相对现状变更）的可借鉴点；**不**引入多命令入口或自动编排，保持唯一入口「项目经理」与人工闸门。

### Added

- **`references/acceptance-and-delta.md`**：验收条款（A1…可证伪）+ Delta-only（禁止复述整模块原理）共用细则；CORE 增强制摘要 + lazy 指针

- **plan-lite / express-slice / Full 执行文档模板**：新增 `## 验收条款`、Step/切片 **满足验收：A#**、delta-only 提示

- **岗位同步**：`planner` / `plan-reviewer` / `developer` / `code-reviewer` / `express-self-check` 对照 A#；缺条款或未引用 → 方案审核 blocker

- **`check-pipeline-doc.ps1`**：缺验收条款或 Step 无「满足验收」→ advisory 警告（`-Strict` 升 error）

- **样例** `Assets/Doc/_examples/plan-lite-pressure-debug-log.md` 补 A1/A2 与满足验收

- **`anti-patterns.md`**：无 A# 定版、方案复述整模块原理

### Notes

- 不 bump 版本号（向后兼容增强；旧文档无 A# 时校验警告，人工补条款即可）

- `validate-pipeline.ps1` `requiredRefs` 纳入 `acceptance-and-delta.md`

---

### Included changes — 2026-07-09（借鉴 Superpowers 分析：补 Express 热文件漏洞 + CR 反推同类隐患 · 不 bump 版本号）

> 来源：核对社区对比分析（`obra/superpowers`，24.9 万 star，Anthropic 官方插件市场收录，已核实非虚构项目）提出的两点，确认与本仓库现状对照后属于真实缺口/低成本高确定性改进，其余条目（Git Worktree、多方案竞争等）因 Unity 二进制资产不友好或团队规模不匹配暂不采纳。

### Fixed

- **Express 车道漏判"历史踩坑文件"**：此前 `.cursor/lessons-learned.md` 的"文件热度"只在 Standard 车道内部触发 L1.5，不参与 Express 准入判定——一个近 6 个月内真出过 blocker 的文件，只要本次改动≤3 文件、看起来"一句话说清"，仍可直接从 Express 进场、不经方案确认就改代码。`CORE.md` §三车道判定 第 3 步、§Express 升级表 补上"命中 lessons-learned 文件热度 → 最低 Standard（随即升 L1.5）"，与"project-context §Express 升级"合并为一行，CORE.md 仍收在 200 行内

### Added

- **`code-reviewer/SKILL.md` Checklist 新增 1.2 "命中文件热度时反推同类隐患"**：diff 涉及文件命中 `lessons-learned.md` 时，CR 不再只核对"该条教训是否原样复现"，还要用教训的根因反问一遍当前 diff 有无同类风险（借用 `单导管链高压顶牛卡死收敛方案.md` L3 八轮复核"换角度攻击"已验证有效的思路，下沉到 CR 层）；无同类风险须在 findings 里写明"已按 [教训一句话] 反推，未发现同类隐患"，避免"扫过表就算做了"

---

### Included changes — 2026-07-09（P2：Cursor Hooks 机器强制层 + PM 同义简写 · 不 bump 版本号）

> 来源：优化方向排序里价值最高但侵入性也最高的一项——把硬门禁从"文字约束"落地成"机器层观察/问询"，先做 observe/ask 版本，不做硬 deny（呼应此前对 opcflow「默认 observe」设计的评估）。

### Added

- **`.cursor/hooks.json` + `.cursor/hooks/git-safety-check.ps1`**：`beforeShellExecution` hook，命中高危 Git 命令（`push --force`/`-f`、`reset --hard`、`clean -f*`、`checkout --`、`branch -D`）时返回 `permission: ask`，交用户在 Cursor 里手动确认，机械化 `references/rollback.md`「任何回退前必须显式征得用户确认」这条规则；其余命令 `allow`，脚本异常时因 `failClosed:false` 默认放行，不影响正在进行的工作

- **`.cursor/hooks/audit-write.ps1`**：`preToolUse`（matcher `Write|StrReplace|EditNotebook`）hook，纯审计——记录时间戳/工具/session/路径到 `.cursor/hooks-log/write-audit.log`（已加入 `.gitignore`，不提交），始终 `allow`，为硬门禁 7 后续升级成机械拦截积累真实数据，本版本不做拦截判断

- **CORE.md §入口 / TEAM-GUIDE.md / `.mdc` / `.trae/rules`**：`项目经理` 新增同义简写 **`PM`**，两者触发效果一致；未替换主触发词（保留中文，符合 MAINTAINER §维护约定「岗位调用名中文」），避免与「产品经理」等常见含义混淆

### Fixed（本轮开发过程中的真实踩坑，记录供参考）

- **Hook 脚本 UTF-8 BOM 缺失导致 PowerShell 5.1 解析报错**：本机控制台代码页为 GBK(936)，脚本文件若不带 BOM 头，PowerShell 会按系统代码页误读脚本内的中文字符串，导致看似无关的语法错误（如把中文字符串里的某个字节序列误判成孤立的引号/括号）；用 `[System.IO.File]::WriteAllText` + `UTF8Encoding($true)` 重存后解决，MAINTAINER §Cursor Hooks 已记录该坑供后续维护者参考

- **审计钩子首版把整份文件内容都写进日志**：第一版直接把 stdin 原始 JSON（含 Write 工具的完整 `content` 字段）整行写入日志，大文件会让日志迅速膨胀且泄漏完整文件内容；改为只解析并记录 `tool_name`/`session_id`/`file_path` 三个字段的精简摘要行

### 观察到的真实数据（开发过程中意外验证）

开发过程中 `preToolUse` hook 被真实触发并写入日志，证实了：① hooks 配置在这个环境下确实自动生效，不需要额外注册步骤；②拿到了 Cursor `preToolUse` 事件的真实 JSON 字段名（`tool_name`、`tool_input.file_path`、`session_id` 等），比此前纯靠官方 skill 文档示例猜测的字段名更可靠，为后续升级审计钩子提供了依据。

---

### Included changes — 2026-07-09（GitHub 发布前机密清理 · 不 bump 版本号）

> 来源：评估通用 Skill 包能否公开发布到 GitHub 时，全量扫描确认 `references/examples.md`、`project-local-config.md`、`doc-path-defaults.md` 仍残留本项目专属信息（对照 [project-local-config.md](./references/project-local-config.md) 自身规则）。

### Fixed

- **`references/examples.md`**：两处"（Chemical 项目）"及点名 `PressureManager`/`导管动态相段推进方案.md` 的真实案例引用 → 改为不点名具体项目/模块的通用表述

- **`references/project-local-config.md`**：反例说明里的具体模块名 `PressureManager` → 改为「某业务系统的真实类名」通用占位表述

- **`references/doc-path-defaults.md`**：举例路径 `Assets/Doc/压力系统/...` → 改为 `Assets/Doc/{主题}/...` 占位符，与文件内其余占位风格统一

- 确认 `CHANGELOG.md`/`MAINTAINER.md` 内的历史 Chemical/PressureManager 引用**无需处理**——两文件本就在 `package-release.ps1` 打包范围之外，不随通用 Skill 包分发

---

### Included changes — 2026-07-09（P1 收尾 + MAINTAINER 措辞修正 · 不 bump 版本号）

> 来源：核对真实执行文档 `单导管链高压顶牛卡死收敛方案.md` 时发现 MAINTAINER 审计记录把两份文档的证据等级混写；顺带落地上一轮排序中的 P1（教训时效标记、文件热度触发 L1.5）。

### Added

- **`references/lessons-learned.md` / `templates/lessons-learned.md` / `.cursor/lessons-learned.md`**：表格新增「最近命中」列——新增条目填当天日期，之后被策划/CR 实际引用命中时更新为当轮日期；新增 §时效归档，「最近命中」距今 > 6 个月且非本轮命中可判定低活跃，整理时移表尾加 `[低活跃]` 前缀（人工判断，不做自动清理）

- **`references/plan-review-tiers.md`**：L1.5 触发条件新增「文件热度」——Mandatory Code Changes 命中 `.cursor/lessons-learned.md` 近 6 个月内有记录的模块/文件，即使未正式收录进回归索引表也同样触发 L1.5，复用已有教训数据而非新增独立风险评分脚本；CORE §Standard 加强审核（L1.5）、`planner/SKILL.md`、`code-reviewer/SKILL.md` Checklist 同步补一句指针

### Fixed

- **MAINTAINER §RC 转正条件 2026-07-09 审计记录措辞不准确**：原文把 `导管动态相段推进方案.md`（Step 0~1 真实 `runtime-validated ✅`）与 `单导管链高压顶牛卡死收敛方案.md`（Step 1 实际仍为 `static-checked`，未跑 Unity）的证据等级混写成一句话，读者容易误以为两份文档都已 `runtime-validated`；改为分文档列出真实证据等级，避免高估 RC 转正证据的充分性

---

### Included changes — 2026-07-09（六项高价值优化落地 · 不 bump 版本号）

> 来源：对"AI 工作流水线"Skill 的外部评审（风险路由/经验沉淀/需求反混淆/渐进披露/Unity 感知/回滚），按 成本×价值 重排后落地"价值高/中高"条目。

### Added

- **`references/demand-clarification.md`**：需求歧义检测——PM 判车道前，需求存在 ≥2 种合理解释且影响车道/范围时先追问 ≤3 个关键问题（最多 1 轮，答不全按默认决策继续）；CORE §三车道判定 前补一节指针

- **`references/rollback.md`**：新增口令「方案推翻」——确认改动文件清单 → 用户确认 → `git checkout -- <文件>` 回退 → 记录进 `pipeline-recovery-log.md`（偏差类型 `方案推翻`）；CORE §Agent 失败模式与恢复 补一句指针

- **`references/unity-editor-log.md` + `developer/SKILL.md` Checklist 7.5**：改完代码后若能读到 Unity `Editor.log`，先自检一次 `CS\d{4}` 编译错误关键字，命中直接自修再交出；明确边界——只拦编译期错误，不能替代 Unity 人工运行验收，不得据此标 `runtime-validated`

- **`references/lessons-learned.md` + `templates/lessons-learned.md` + 项目专属 `.cursor/lessons-learned.md`**：经验沉淀机制——CR/方案审核发现 blocker 修复确认后，人工确认一句话根因追加到项目表（**不做 AI 自动总结**，避免幻觉教训）；`planner/SKILL.md`、`code-reviewer/SKILL.md` Checklist 补"写方案/审查前扫一遍"；已用真实审核记录（`单导管链高压顶牛卡死收敛方案.md` L3 三轮 blocker）种入 3 条初始教训

- **CORE §三车道判定 第 2 步例外**：新增"回归模块内纯数值/阈值微调（≤3 行+书面依据）→ 降级 Standard+L1.5，不强制 Full"，降低团队因"一刀切 Full"绕过 PM 的反向激励

### Changed

- **`sync-regression-index.ps1` v2.0.1 → v2.1.0**：新增 `-Apply` 模式，从 `project-context.md` MD 表**自动生成** `regression-index.yaml`，消除人工双写漂移风险（原 warn/`-Strict` 校验模式保留，供 CI/pre-commit 场景纯校验用）；`project-context.md`、`MAINTAINER.md`、`anti-patterns.md` 对应措辞同步

- **pre-commit 提醒默认建议改为 `-Strict`**（`README.md`、`MAINTAINER.md`）：硬门禁缺机器强制易被跳过，改为默认推荐阻断模式，团队摩擦大时可退回 warn-only

- **MAINTAINER §RC 转正条件**：补 2026-07-09 审计记录——核对真实执行文档确认 **Full 车道**闭环已有实证（Step 0~1 `runtime-validated ✅`），但 **Express / Standard+L1.5** 闭环证据仍缺，checklist 前两项未打勾，继续观察期不转正

### Not Adopted（外部评审中评估后不采纳的部分）

- "风险系数算法"中的"改动作者历史 Bug 率"维度——涉及对人画像追责，团队治理风险大于收益，未采纳；改用更简单的"文件热度+回归模块"维度（见 P2，本轮暂未实现，留待下一轮）

- "AI 自动提炼错误模式存数据库"——改为人工确认后追加 Markdown 表（`lessons-learned.md`），避免自动总结幻觉

- "Unity 自愈闭环 L4.5→L5"的完整表述——本轮 Editor.log 自检明确限定为"仅拦编译错误"，不替代人工运行验收，避免过度自信标 `runtime-validated`

---

### Included changes — 2026-07-08（v3.1.1 定版前审计修复 · 不 bump 版本号）

### Fixed

- **`references/full-lane-decision-tree.md`**：强制 Full 示例硬编码 `PressureManager + Reaction + UI` 与「离子的反应路径」→ 改为通用占位符，消除通用 Skill 中的本项目硬编码（对照 [project-local-config.md](./references/project-local-config.md)）

- **`templates/cr-dispatch-l1.5.md`**：一键生成示例命令硬编码 `-RegressionModule PressureManager` → 改为 `[ModuleName]` 占位符

- **死链「CORE 附录 B」**：`project-context.template.md`、`.cursor/project-context.md` 中残留的「见 CORE 附录 B」指针（附录 A/B 早已迁至 `references/examples.md`，见本文件历史 [3.0.13]）→ 改为指向 `references/examples.md` §Standard + L1.5 / §Full 强制

- **CORE §三车道判定 第 2 步排版消歧**：原嵌套 `·` 列表容易误读为「功能性改动+回归模块」需同时命中其他 Full 条件才算 Full；改为明确「4 条各自独立触发」+ 例外仅对应第 4 条。**不改变判定结果**——经查真实执行文档 `Assets/Doc/压力系统/导管动态相段推进方案.md`，PressureManager 功能性 Step 全程标注「完整模式」，与现行严格判定一致，故未采纳外部审计建议的「默认降级 Standard」方案

- **`references/full-lane-decision-tree.md` §不升 Full**：「已有 plan-lite、2～3 Step → Standard」补充限定「且未命中第 2 步 Full 强制」，避免与第 2 步第 4 条（功能性+回归模块单独触发 Full）冲突

- **`.cursor/project-context.md`**：「功能性改动仍按 CORE 第 2 步判 Full/Standard」读作二选一 → 改为明确「命中第 4 条→Full；否则按其余条判 Standard」

- **`references/examples.md`**：补充「Full 强制（回归索引模块 · 功能性改动）」样例，引用上述真实案例

- **LTS/RC 标签八处不一致**：`.cursor/rules/ai-dev-pipeline.mdc`、`.trae/rules/ai-dev-pipeline.md` 原写「v3.1.1 LTS」（未标 RC，与 README/MAINTAINER/CHANGELOG/TEAM-GUIDE 的「候选定版 RC」不一致）→ 统一改为「v3.1.1 候选定版 RC」；`validate-pipeline.ps1` 输出头、`check-pipeline-doc.ps1` 注释同步

- **`validate-pipeline.ps1` 硬编码本项目模块名**：parse probe 原断言回归行须含字面 `PressureManager`/`PressureDebug`；改为泛化断言——校验解析出的 `hint.Module` 非空且回归行确实引用该动态解析出的模块名，不再绑定具体项目模块

- **`tl-onboarding.md` 未纳入 `validate-pipeline.ps1` 必填 references**：`$requiredRefs` 补入该文件，防止后续误删无告警

- **MAINTAINER §发布检查清单 与 §LTS 定版说明 archive/ 措辞不同步**：两处均原写「`archive/` 须有 `archive/README.md`」读作强制存在；统一改为「若存在 `archive/` 目录才需要哨兵」，与 `validate-pipeline.ps1` 脚本内已有的条件判断逻辑对齐（脚本本就只在 `archive/` 存在时才检查）

- **`weekly-report/SKILL.md`**：补一句边界说明——用户借「周报」顺带提代码/README 改动需求时不在本岗处理，须另起一条先 `[PM]` 判车道

### Verified（外部审计中确认无需修改的项）

- RC checklist 未打勾前不摘 RC 标签 — 已正确保持现状

- `pm-tooling.md` 与 CORE YAML 的 `snapshot` 字段（`ok|manual|n/a`）— 当前文档一致；审计提到的 `skipped` 仅出现在 CHANGELOG 历史记录中，属正常保留，无需改

### Added（发布打包脚本）

- **`.cursor/package-release.ps1`**：把要分发给其他项目的文件打包成 `.cursor/ai_dev_<版本号>.7z`（排除 `MAINTAINER.md`/`CHANGELOG.md`/project-context 等项目专属文件）；`MAINTAINER.md` 新增 §发布打包脚本 说明

- **`.gitignore`**：补 `.cursor/ai_dev_*.7z`、`.cursor/_release_staging/`，避免构建产物/暂存目录误提交

- **踩坑记录（供后续维护者参考）**：初版曾用 `.bat` 启动器 + 中文输出文件名"ai工作流水线_"，在本机 GBK(936) 控制台代码页下连续踩两个坑——① `.bat` 文件里的中文注释被 cmd.exe 误解析、拦腰截断成多条命令；② 中文文件名作为参数直接传给 `7z.exe`（原生控制台程序）会被代码页转译乱码。改为纯 PowerShell 脚本 + 用户要求的 ASCII 文件名 `ai_dev_` 前缀后两个坑均规避；已用 7z 解压验证归档内容与文件名（含中文文件名 `执行文档黄金样例.md`）在真正落盘时均正确

- **调整**：脚本移至 `.cursor/package-release.ps1`（原 `.cursor/scripts/` 下，另配 `.bat` 启动器，已废弃）；打包范围收窄为**仅 `.cursor/` 下的文件**——不再含 `.trae/rules/ai-dev-pipeline.md`、脚本自身

- **调整**：压缩包内去掉 `.cursor` 外层目录，`skills/`、`scripts/`、`rules/` 直接是包顶层——用户解压目标改为选目标项目的 `.cursor/` 目录本身（而非仓库根），文件直接落位不再多一层嵌套

### Changed

- **LTS 标注**：v3.1.1「定版」降级为「**候选定版 RC**」（README / MAINTAINER / CHANGELOG 头 / TEAM-GUIDE）；MAINTAINER 新增 §RC 转正条件（1 个 Express + 1 个 Standard+L1.5 真实闭环验证后转正，不 bump 版本号）

- **CORE.md 瘦身**：206 行 → 199 行（合并冗余空行/短句，内容不变），符合 MAINTAINER §排版约定「CORE ≤200」目标

- **TEAM-GUIDE FAQ**：「Agent 没按流程来？」补充识别信号——AI 未先给「你下一步」就直接改代码/文档时，即可触发 `按 CORE 重来`

- **CORE §三车道判定 / §Express 升级**：补「单文件改动规模过大（整体重写/新增删改 >~150 行）」不算「一句话说清」、须升 Standard——堵住"文件数达标但单文件大重写"绕过 Express 门槛的漏洞

- **express-self-check.md**：新增自检项「本 Chat 内此前未对同一模块做过 Express 改动」，防止拆分多轮小改累积绕过车道升级

- **`sync-regression-index.ps1`**：仓库根路径解析统一改为 `git rev-parse --show-toplevel`（失败回退相对路径），与其余脚本一致，避免非标准执行路径下算错仓库根

- **README.md §pre-commit 提醒**：补充 `-Strict` 阻断模式安装示例，供需要更强约束的团队直接复制

- **README.md 瘦身**：164 行 → 89 行，达到 MAINTAINER §文档分工「README ≤90」目标——TL 详细接入步骤（完整命令、双写纪律、CodeGraph 探测、冷启动细则）外迁至新建 [references/tl-onboarding.md](./references/tl-onboarding.md)；pre-commit 完整安装命令（含 `-Strict`）外迁至 MAINTAINER §optional pre-commit；README 保留精简三步起步 + 各处指针；删除与「TL 必做」重复的「TL 一分钟 onboarding」表与「新项目」快捷段落

- **MAINTAINER §流程稳定性规则**：references 索引表补 `tl-onboarding.md` 一行

### Added（精简优先 / 不过度设计）

- **`references/execution-discipline.md`**：设计初衷表新增「精简优先」第 5 条；新增 §精简优先（不过度设计）——YAGNI、不留残留代码、类文件膨胀信号、三岗各自的对应动作

- **`references/anti-patterns.md`**：CORE 翻车索引补第 11 条「过度设计/残留死代码/类文件无限膨胀」；§实现与代码审核 新增 3 行反模式（预先抽象未用、残留废弃代码未清理、单类无限膨胀无人评估拆分）

- **`planner/SKILL.md`** Checklist：新增「Mandatory Code Changes 只写最小改动范围，不预先设计扩展点」

- **`developer/SKILL.md`** Checklist：新增「精简优先（YAGNI），改动路径废弃代码顺手清理或交接说明」

- **`code-reviewer/SKILL.md`** §审查重点：新增「过度设计/残留死代码/类文件膨胀」检查项，命中记 `major`

### Added（连续未验证改动上限）

- **`references/execution-discipline.md`** §漂移即纠偏：新增「同一 Step/切片内连续 ≥3 次 static-checked 修复仍无 Unity 验证」信号，动作为停下提示用户先测一次

- **`references/anti-patterns.md`**：CORE 翻车索引补第 12 条；§实现与代码审核 新增对应反模式行

- **`developer/SKILL.md`** Checklist：第 7 项扩展，达到阈值须在交接中提示用户先测一次，不再继续叠加修复

- **背景**：源于对真实执行文档 `导管动态相段推进方案.md` 的审查——发现同一 Step 内连续 19 个版本号均标注「Unity 回归待跑」、中间无一次真实验证，虽未违反证据等级如实标注纪律，但存在未验证变更持续堆积的风险

---

## [3.1.1] - 2026-07-08（LTS patch · 规则冲突修复）

### Changed

- **CORE §PM 内部结构化判定**：修正“必须输出 YAML”与“用户只看白话下一步”的冲突；PM 字段默认仅 Agent 内部使用。

- **Full / L2 边界**：跨 2 模块默认进入 Standard + L2；跨 3+ 独立业务模块、>8 业务文件、状态机/持久/序列化等再触 Full。

- **CodeGraph 降级**：Standard 无图谱由 soft blocker 调整为 soft risk，可闭环但须声明影响面未图谱验证。

- **人工审查选择**：新开 Chat / 换模型统一为用户选择，Agent 只提示、不校验、不阻断 Standard 闭环。

---

## [3.1] - 2026-07-08（LTS 定版 · 体验优化）

### Added

- **CORE §Full 强制 — 用户可见**：命中 Full 强制条时 **你下一步** 须白话提示「建议启用完整流程（Full）」

- **MAINTAINER §维护策略**：v3.1+ **CORE 结构冻结**；新规则优先进 `references/`；破坏性变更 → v4.0

- **TEAM-GUIDE 首屏**：TL 首次初始化约 5 分钟提示（链至 README §运行前规则）

- **恢复口令统一**：主口令 **`按 CORE 重来`**；`流水线重来` / `没按流程来` 为同义别名

### Changed

- **anti-patterns**：翻车索引 #10「Full 强制未白话提示完整流程」

- 版本号八处同步 → v3.1

---

## [3.0.22] - 2026-07-08（LTS 定版 · 体验小修）

### Added

- **TEAM-GUIDE**：「自动派岗」白话说明（Agent 内部切换，关键步骤仍须用户确认/操作）

- **TEAM-GUIDE FAQ**：冷启动附 TL 一键 `init-project-context.ps1` 命令；恢复口令增 **`流水线重来`** / **`没按流程来`**

- **project-context.template.md**：Express 升级表示例行（Core/Save），降低 TL 填表门槛

### Changed

- **CORE §冷启动**：`missing-coldstart` 时 **你下一步** 须含一键初始化命令（与 TEAM-GUIDE 对齐）

- **README §三车道**：「PM 自动判」→「PM 内部判车道」，并注明非脚本自动化

- 版本号八处同步 → v3.0.22

---

## [3.0.21] - 2026-07-08（LTS 定版）

### Added

- **CORE §Standard 可选独立方案审核**：L1 + ≥2 Step 或改动面较广时，PM **须提示**可新开 Chat 做独立方案审核（不校验）

- **TEAM-GUIDE §快速对照**：Cursor Agent 模式与 Unity Play/Console 验收步骤（零基础）

### Changed

- **`.mdc` / `.trae/rules` 瘦身**：移除与 CORE 重复的三车道/七职责表，仅保留入口指针 + 硬门禁 #7（降 Token）

- **README / init 脚本**：强调 `init-project-context.ps1` 同时生成 `regression-index.yaml` 及后续 sync 步骤

- **TEAM-GUIDE FAQ**：对齐 Standard 多 Step 时 Agent 主动提示可选独立审核

- **MAINTAINER §已知限制**：L1 多 Step 可选提示说明

- 版本号八处同步 → v3.0.21

---

## [3.0.20] - 2026-07-08（LTS 定版）

### Added

- **硬门禁 #7**：无 PM YAML 不得改交付物；各岗 SKILL 增 **§PM 门禁（硬停）**（策划/程序员/方案审核/CR/文档）

- **README §TL 一分钟 onboarding**：四步 checklist

- **TEAM-GUIDE FAQ**：核心模块可主动要求独立方案/代码审核（不强制）

- **anti-patterns**：翻车索引 #9「无 PM YAML 仍改交付物」

### Changed

- **MAINTAINER §已知限制**：「无机械拦截」→「PM 门禁硬停（仍依赖 Agent 执行）」

- 版本号八处同步 → v3.0.20

---

## [3.0.19] - 2026-07-08（LTS 定版）

### Added

- **TEAM-GUIDE §唯一入口**：明确禁止跳过「项目经理」直接叫「程序员/策划」

- **anti-patterns**：增补「跳过 PM 直接叫岗位」；翻车索引表扩至 8 条

### Changed

- **版本号八处同步**：`CHANGELOG`、`validate-pipeline.ps1` 等与 CORE v3.0.19 对齐（修复 3.0.18 漂移）

- **anti-patterns**：「CORE Top 5 索引」更名为 **「CORE 翻车索引」**（与条目数一致）

- **MAINTAINER §已知限制**：补充冷启动保守 Standard、L1 非独立复核、无机械拦截 PM 入口

- **CORE §常见翻车**：措辞对齐「翻车索引」

---

## [3.0.18] - 2026-07-07（LTS 定版）

### Added

- **`references/readme-dispatch.md`**：README 派岗表自 CORE 外迁

- **`archive/README.md`**：归档目录「勿读」哨兵

### Changed

- **CORE 瘦身**（≈120 行）：五态/文档路径/Top5 表 lazy load；**Express 简略「你下一步」四条最低内容**（缺任一项 = 缺 PM 输出）

- **P1**：硬门禁与「你下一步」最低内容；recovery 须完整表

- **P2**：`planner` 注明 express-slice 由 PM 写；`validate-pipeline` 检 `express-slice` / `readme-dispatch` / `examples`；`archive/` 允许（须 README 哨兵）

- **MAINTAINER**：LTS 定版说明 + 已知限制 + 发布前抽测

- 版本号八处 → v3.0.18

---

## [3.0.17] - 2026-07-07

### Changed

- **Express 简略 PM 输出**：满足条件时 **仅 YAML + 你下一步**，省略摘要表（降 Token）；Standard/Full/升级/阻塞/coldstart/recovery 仍须完整表

- **examples.md** Express 样例对齐简略格式

---

## [3.0.16] - 2026-07-07

### Changed

- **P1 硬门禁**：Express **无 express-slice 不得 `[developer]`**（硬门禁 #2）；冷启动 PM **须向用户白话**提示 init-project-context

- **新开 Chat / 换模型**：改为 **用户提示、不校验**；L1.5/L2/L3 同 Chat 可继续，须标「非独立 CR」

- **cr-dispatch-l1.5.md**：重写为派发模板 + 用户提示（移除「合规定义/一律无效」）

- **TEAM-GUIDE**：coldstart FAQ；独立审查统一为 Agent 提示、不拦用户

- **developer / code-reviewer / plan-review-tiers / anti-patterns / retrospective / full-lane-decision-tree**：对齐

---

## [3.0.15] - 2026-07-07

### Changed

- **换模型**：从 CORE / 各岗 SKILL / references 规则中移除；**仅** TEAM-GUIDE FAQ 一句用户提示（非必须）

- **state-machine.md**：`implementation-ready` 迁移条件改为 L1/L1.5 无 blocker（去掉「多模型」旧措辞）

---

## [3.0.14] - 2026-07-07

### Added

- **`templates/express-slice.md`**：Express 小改切片（PM 派 developer 前必输出；Chat 内或 `.cursor/express-slices/`）

- **CORE §README 派岗**：PM YAML 增 `readme: skip | dev-one-liner | docs`，明确判定表

- **TEAM-GUIDE §Cursor 基本操作**：新开 Chat、Agent 模式、独立审查换模型可选

### Changed

- **Git 可选**：无 Git 不阻塞；审查用变更文件列表，diff 仅辅助

- **PM 快照**：`snapshot: ok | manual | n/a` 替代 `skipped`；脚本失败时 Agent Write JSONL → `manual`

- **独立审查**：L1.5 CR / L2 / L3 — **新开 Chat 即可**，换模型改为可选

- **Express 流程**：PM express-slice → developer → 自检（不再「无执行文档」）

- **TEAM-GUIDE**：去掉「给谁看」；改为用户使用说明；补无 Git FAQ

- **developer / module-readme / express-self-check / pm-tooling / plan-review-tiers / cr-dispatch / execution-discipline**：对齐上述规则

- **`.mdc` / Trae rule**：v3.0.14 摘要同步

---

## [3.0.13] - 2026-07-07

### Added

- **`references/examples.md`**：Express / Standard+L1.5 端到端样例（自 CORE 附录外迁）

### Changed

- **Skill 放置**：README / `.mdc` / Trae / `doc-path-defaults` 统一——推荐项目内 `.cursor/skills/`，亦可用全局；删除「项目优先于全局」强制表述

- **CORE §PM 结构化输出**：YAML 增 `snapshot: ok|skipped`；表格后强制 **你下一步** 白话；L1.5 派发块说明「新开 Chat 粘贴」

- **CORE §三车道**：Express 第 4 步补 prefab/asset；Standard 流程 CR 无 blocker 后**须**更新 README

- **pm-tooling.md**：Agent 无法执行脚本时标 `snapshot: skipped`，不得伪造

- **developer / module-readme SKILL**：对齐 Standard README 必经规则

- **TEAM-GUIDE**：新开 Chat 与提需求同等操作；L1.5 FAQ 精简

### Removed

- **CORE 附录 A/B**：迁至 `references/examples.md`（减 Token）

---

## [3.0.12] - 2026-07-07

### Added

- **`references/lane-glossary.md`**：v3 车道（Express / Standard / Full）权威术语；v1 旧称对照表

### Changed

- **活跃 `references/`、`templates/`、`express-self-check.md`**：统一用 **车道** 字段，移除 v1「微型/轻量/完整模式/流水线模式」主路由表述

- **`check-pipeline-doc.ps1`**：必填 **车道**；**流水线模式** 降为 deprecated 警告

- **`validate-pipeline.ps1`**：`lane-glossary.md` 纳入 required refs（17 文件）

- **`CORE.md`**：进阶指针增 lane-glossary 链接

- **`Assets/Doc/_examples/plan-lite-pressure-debug-log.md`**：对齐 v3 文档状态字段

### Fixed

- **P0 术语混用**：Agent 读 references 时不再遇到 v1/v3 双轨车道名（CHANGELOG 历史条目保留 v1 措辞）

---

## [3.0.11] - 2026-07-07

### Added

- **`pipeline-doc-parse.ps1`**：plan-lite Mandatory / Regression Validation / regression-index scenario 匹配（suggest + dispatch 共用）

- **`validate-pipeline.ps1 -CheckScripts`**（默认启用；`-SkipScripts` 跳过）：检查 5 个 PM 脚本 + 样例 doc 解析探针

### Changed

- **`dispatch-l1.5-cr.ps1`**：共用解析库；`-RegressionScenario` 精确/模糊匹配 YAML；可从 plan-lite 自动读模块/场景

- **`cr-dispatch-l1.5.md` + CORE §L1.5**：**L1.5 合规定义**（新 Chat 或新 readonly Agent；开发 Chat 内 `[CR]` 无效）

- **`suggest-pipeline-lane.ps1`**：`Test-PipelinePathHitsPrefix` 修复 Express 升级路径命中

### Fixed

- **`pipeline-doc-parse.ps1`**：PS 5.1 在无 BOM 的 `.ps1` 中误读中文正则字面量，导致 Express 升级前缀与 plan-lite 回归 hint 解析为空；改为 ASCII-only 正则（Express 小节截断 + `` `Assets/...` `` 提取）

---

## [3.0.10] - 2026-07-07

### Added

- **`suggest-pipeline-lane.ps1 -DocPath`** / `-Step`：仅统计 plan-lite Mandatory 路径，避免脏工作区误判

- **`references/pm-tooling.md`**：PM diff 辅助 + 快照 + L1.5 派发脚本细则（CORE 瘦身外移）

### Changed

- **CORE.md**：§PM 脚本改为 lazy load `pm-tooling.md`（行数回落 ≤200 目标）

- **`.cursor/project-context.md`**：PressureManager/Reaction 仅日志改动统一为 **Standard + L1.5**，删除 TL Express 例外

- **`.gitignore`**：忽略 `pipeline-snapshot.log`、`pipeline-recovery-log.md`

- **`suggest-pipeline-lane.ps1`**：Express 升级表仅解析 `## Express 车道升级` 小节

---

## [3.0.9] - 2026-07-07

### Added

- **可观测性**：`append-pipeline-snapshot.ps1`、`summarize-pipeline-metrics.ps1`、`templates/pipeline-snapshot-log.md`；CORE §PM 可观测性 + YAML `diff_hint`

- **Express diff 辅助**：`suggest-pipeline-lane.ps1`（advisory，不自动定 lane）

- **L1.5 一键派发**：`dispatch-l1.5-cr.ps1 -CopyToClipboard`；`cr-dispatch-l1.5.md` 增 Bugbot/新 Chat 三方式

- **Full 决策树**：`references/full-lane-decision-tree.md`（TL 一页）

### Changed

- **CORE / TEAM-GUIDE / developer / retrospective-metrics / init-project-context**：接入上述脚本与字段

- **validate-pipeline**：`references/` 增至 15 文件（含 full-lane-decision-tree）

---

## [3.0.8] - 2026-07-07

### Fixed

- **v2 残留清理落地**：确认 `.cursor/skills/` 无 `archive/`、`QUICKSTART.md`、`project-manager/` 及 v2-only `references/*`；`code-reviewer/SKILL.md` 死链「见 archive」→ `references/codegraph-probe.md`

### Added

- **validate-pipeline.ps1 §skills layout**：检测 v2 残留路径 + `references/` 14 文件完整性

### Removed

- **全局旧副本**：删除 `~/.cursor/skills/ai-dev-pipeline/`（v1 岗位包，与仓库 v3 CORE 冲突；权威见本仓库 `.cursor/skills/`）

---

## [3.0.7] - 2026-07-07

### Changed

- **排版统一**：章节间最多 1 空行；列表/表格/引用块内不插空行；去掉装饰性 `---` 分隔线

- **CORE.md**：252 行 → 161 行（内容不变，压缩空行与 L1.5 段间距）

- **MAINTAINER** 增 §排版约定；29 个 Skill 文档批量整理

---

## [3.0.6] - 2026-07-07

### Removed

- **v2 残留全部删除**：`archive/`、`QUICKSTART.md`、`project-manager/`、重复 `references/`、v2-only 参考（lanes、workflow-modes、pm-one-pager、role-tags、cursor-native-tools 等）

- **archive/** 目录整体移除；v3 所需规则统一至根级 `references/`（14 个文件）

### Changed

- **MAINTAINER.md** 回迁根目录并重写；发布检查清单增「无 v2 残留」

- **全局链接**：`archive/references/` → `references/`；`archive/MAINTAINER` → `MAINTAINER`

- **references/** 内死链修复：QUICKSTART/lanes/workflow-modes 指向 CORE

- **脚本 / project-context / regression-index.yaml**：模板路径更新

- **版本号**同步八处

---

## [3.0.5] - 2026-07-07

### Added

- **CORE §PM 结构化输出**：每轮 `[PM]` 强制 YAML + 用户可见摘要表（车道、下一岗、五态、blockers）

- **CORE §无 project-context 冷启动**：`missing-coldstart` 最小默认，无法确认核心模块时默认 Standard

- **templates/cr-dispatch-l1.5.md**：L1.5 新开 Chat 可复制派发块

- **templates/pipeline-recovery-log.md** + **retrospective-metrics §流水线恢复度量**：`按 CORE 重来` 偏差类型枚举与 sprint 汇总

- **init-project-context.ps1**：可选创建 `.cursor/pipeline-recovery-log.md`；提示冷启动规则

### Changed

- **CORE 翻车表**：11 条 → Top 5；其余链 archive anti-patterns（含 Top 5 索引）

- **CORE**：去冗余空行，正文约 200 行量级

- **developer / code-reviewer / TEAM-GUIDE**：指向 L1.5 派发模板

- **版本号**同步：CORE、README、TEAM-GUIDE、express-self-check、`.mdc`、`.trae/rules`、脚本、MAINTAINER

---

## [3.0.4] - 2026-07-07

### Fixed

- **CORE §三车道判定 第 2 步**：功能性改动 +（§Express 升级 或 回归索引模块）→ Full；非功能性（仅日志/注释）不触发 Full，与 L1.5 对齐

- **CORE 内部一致**：派岗表 / 硬门禁 / 翻车表标题 / Agent 失败模式（含 L1.5 同 Chat CR 恢复）

### Added

- **check-pipeline-doc.ps1**：校验「方案审核档位」枚举；Standard + 回归索引路径未标 L1.5 → warn

- **pre-commit**：跳过 `Assets/Doc/_examples/` 样例文档

- **README**：全局 `~/.cursor/skills/` 旧副本提醒

- **archive**：anti-patterns / execution-discipline supersede 指向 CORE

### Changed

- **developer/SKILL.md**：L1.5 须交 PM 新开 Chat CR，不得同 Chat 自审

- **plan-review-tiers.md**：移除 L1.5「30 天内二次大改」触发

- **版本号**同步：CORE、README、TEAM-GUIDE、express-self-check、`.mdc`、`.trae/rules`、脚本

---

## [3.0.3] - 2026-07-07

### Added

- **CORE §Standard 加强审核（L1.5）**：回归索引模块 → 方案 L1.5 标注 + CR 新开 Chat

- **CORE §Agent 失败模式与恢复**：用户「按 CORE 重来」/「流水线重来」标准恢复流程 + PM 自检清单

- **Assets/Doc/_examples/plan-lite-pressure-debug-log.md**：Standard + L1.5 plan-lite 填表示例

- **README / TEAM-GUIDE**：pre-commit advisory 安装说明（TL 推荐）

### Changed

- **plan-reviewer / code-reviewer / plan-lite 模板**：L1.5 触发条件与输出要求

- **references/plan-review-tiers.md**：增 L1.5 档位定义

- **MAINTAINER.md**：LTS 升至 v3.0.3；日常权威改为 CORE；修复 ../ 相对链接

- **版本号**同步：CORE、README、TEAM-GUIDE、`.mdc`、`.trae/rules`、`validate-pipeline.ps1`

### Notes

- v3.0.0 计划移除的根目录 `references/`、`QUICKSTART.md` 等重复物**已不在仓库**；权威 references 仅 `references/`

---

## [3.0.2] - 2026-07-07

### Added

- **CORE §进阶指针**：soft blocker（CodeGraph）、状态迁移（state-machine）、交接块（handoff-template）三行 lazy load 入口

- **express-self-check**：自检项「未命中 project-context §Express 车道升级」

### Changed

- **archive/README.md**：加粗 supersede 声明；v2 条目标为历史对照

- **references/pm-one-pager.md、lanes.md**：权威指针改为 `CORE.md`

- **CORE.md**：整理空行；Agent 必读顺序增第 5 条（archive 触发条件）

- **版本号**同步：README、TEAM-GUIDE、`.mdc`、`.trae/rules`、`validate-pipeline.ps1`

---

## [3.0.1] - 2026-07-07

### Fixed

- **CORE.md**：Standard 流程补上 `[plan-reviewer]` L1；硬门禁增第 3 条；翻车表增「跳过 L1」

- **CORE 样例**：Express 样例改为非禁入路径；新增附录 B（PressureManager → Standard）

- **Full 强制条**：明确「回归索引模块 + §Express 升级路径」判定语义

- **plan-lite.md**：`## 文档状态` 正式 8 态字段 + Step 用 Mandatory Code Changes / Regression Validation

- **Assets/Doc/README.md**、**regression-index.yaml** 头注释：修复 v3 后死链

---

## [3.0.0] - 2026-07-07

### Added

- **[CORE.md](./CORE.md)**：v3 日常唯一权威（三车道 + 硬门禁 + 五态 + 8 条翻车 + Express 样例）

- **[express-self-check.md](./express-self-check.md)**：Express 自检清单（从 references 提升到根目录）

- **[archive/](./archive/README.md)**：v2.x 完整文档归档（QUICKSTART、MAINTAINER、project-manager、references/*）

### Changed

- **入口**：`.mdc` / `.trae/rules` 改为 Read `CORE.md`（不再先读 pm-one-pager + project-manager）

- **各岗 SKILL.md**：压缩为 checklist 版（developer/planner/code-reviewer/plan-reviewer/module-readme/weekly-report）

- **README.md / TEAM-GUIDE.md**：精简；团队仍只记「项目经理 + 需求」

- **project-context.md / scripts**：`references/` 路径 → `references/`

- **validate-pipeline.ps1**：LTS 标记 v3.0.0

### Removed（从日常路径）

- 根目录 `references/`、`QUICKSTART.md`、`MAINTAINER.md`、`project-manager/` → 迁入 `archive/`（未删除内容）

---

## [2.0.2] - 2026-07-07

### Added

- **[references/pm-one-pager.md](./references/pm-one-pager.md)**：项目经理一页速查（判定 + 派岗 + 门禁 + lazy load 索引）

- **[references/role-tags.md](./references/role-tags.md)**：各岗会话首行标记（`[PM]`、`[developer]`、`[CR]` 等）

- **project-context §Express 车道升级**：通用机制（[lanes.md](./references/lanes.md)）；Chemical 已填 PressureManager / Reaction 路径

- **[project-context.template.md](./project-context.template.md)**：可选 §Express 车道升级 占位

### Changed

- **project-manager/SKILL.md**：首次统筹先 Read one-pager；「必读材料」改为「按需 lazy load」表

- **各岗 SKILL.md**：增 §角色标记

- **QUICKSTART / README / .mdc / .trae/rules**：入口改为 pm-one-pager；§角色标记、§PM一页

- **TEAM-GUIDE / user-visible-states / execution-discipline**：v1「微型/资产」用户表述 → Express 车道

- **check-pipeline-doc.ps1**：v2 车道名、状态枚举校验、推荐字段「当前 Step」「车道」；Git 提示改用 Express 术语

- **express-self-check.md**：输出须首行 `[developer]`

---

## [2.0.1] - 2026-07-07

### Changed

- **`project-context.md` 迁出 Skill 包**：项目专属文件改为 **`.cursor/project-context.md`**（每仓库单独维护）

- **删除** `.cursor/skills/project-context.md`（Chemical 数据已迁至 `.cursor/project-context.md`）

- **[project-context.template.md](./project-context.template.md)**：用法改为复制到 `.cursor/project-context.md`

- **脚本**：`sync-regression-index.ps1`、`pre-commit-pipeline-advisory.ps1` 路径更新；缺失 project-context 时 sync **跳过**而非 fail

- **[init-project-context.ps1](../scripts/init-project-context.ps1)**：新项目一键从模板生成

- **[project-local-config.md](./references/project-local-config.md)**、各岗 Skill、QUICKSTART、`.mdc`：统一「若存在 `.cursor/project-context.md` 则读取」

---

### Added

- **三车道自适应路由**：Express / Standard / Full（[references/lanes.md](./references/lanes.md)）

- **[templates/plan-lite.md](./templates/plan-lite.md)**：Standard 半页方案模板

- **[references/express-self-check.md](./references/express-self-check.md)**：Express 自检清单（**视同代码审核完成**）

- 各岗位 Skill **§车道启用条件**（v2.0）

### Changed

- **project-manager/SKILL.md**：§三车道判定置顶；Express 不派策划/方案审核/独立 CR

- **QUICKSTART.md**：§三车道为主路由；v1 模式降为对照表

- **README.md**、**.cursor/rules/ai-dev-pipeline.mdc**：v2.0 入口与车道表

- **程序员 Express**：须 Read developer SKILL + 输出自检清单

- **策划 Standard**：默认 plan-lite 而非 141 行模板

### Deprecated

- v1.x「微型/资产/轻量/标准/完整」作为**用户-facing 主路由**（仍可在 Full 车道与 [workflow-modes.md](./references/workflow-modes.md) 中对照）

---

## [1.7.7] - 2026-07-07

### Added

- **[execution-discipline.md](./references/execution-discipline.md)**：设计初衷验收表、事实优先级、不确定则停、假设须显式、团队输出不锁格式

- **README §设计初衷**：四条目标与无差错定义（不漂移、不臆测）

- **QUICKSTART §执行纪律**：速查表 + § 索引条目

- **anti-patterns**：「漂移与臆测」对照表

### Changed

- **user-visible-states**：团队输出改为「须传达语义、不锁 Markdown 版式」

- **project-manager**：checklist 增执行纪律；团队输出模板改为参考版式（非强制）

- **developer / planner**：checklist 增执行纪律交叉引用

- **TEAM-GUIDE**：非程序用户 = 会用 Unity、不懂代码；五态标明语义标签；FAQ 补充

- **QUICKSTART §团队入口**：与 execution-discipline 对齐，弱化固定首段格式

- **版本号**统一为 v1.7.7（六处 LTS 同步）

---

## [1.7.6] - 2026-07-07

### Fixed

- **project-manager**：团队用户输出模板嵌套 fence 修正（外层四反引号，内层 `text` 块可正确渲染）

### Changed

- **anti-patterns**：补「用户指定路径仍擅自改到 Assets/Doc/」反模式行

- **MAINTAINER**：一键校验脚本节标题与 LTS 对齐

- **版本号**统一为 v1.7.6（六处 LTS 同步）

---

## [1.7.5] - 2026-07-07

### Added

- **[doc-path-defaults.md](./references/doc-path-defaults.md)**：文档默认路径规则 — 用户指定路径 > 默认 **`Assets/Doc/`**

- **`Assets/Doc/README.md`**：默认文档根说明（Unity 项目）

### Changed

- **project-context / template**：默认执行文档根改为 `Assets/Doc/`；Chemical 旧路径 `化学文档/` 标为历史只读

- **QUICKSTART §文档路径、TEAM-GUIDE、planner、project-manager、weekly-report、execution-doc-template**：同步默认路径规则

- **project-context.template.md**：压缩格式、修复 Markdown 表格空行

- **pre-commit-pipeline-advisory.ps1 / sync-regression-index.ps1**：文件头版本号与 LTS 对齐

- **版本号**统一为 v1.7.5（六处 LTS 同步）

---

## [1.7.4] - 2026-07-07

### Added

- **[project-context.template.md](./project-context.template.md)**：换项目时的项目上下文模板

- **[references/regression-index.template.yaml](./references/regression-index.template.yaml)**：回归索引 YAML 模板（无项目数据）

- **[references/project-local-config.md](./references/project-local-config.md)**：项目专属 vs 通用 Skill 边界说明

### Changed

- **回归索引 YAML** 从 `references/regression-index.yaml` 迁至仓库根 **`.cursor/regression-index.yaml`**（Chemical 数据）；Skill 包内仅保留模板

- **project-context.md**：标明 Chemical 专属；YAML 链接指向 `.cursor/regression-index.yaml`

- **pre-commit-pipeline-advisory.ps1**：执行文档路径从 `project-context.md` 动态解析；索引 stage 监视 `.cursor/regression-index.yaml`

- **通用化**：`TEAM-GUIDE`、`weekly-report`、`execution-doc-template`、`codegraph-probe`、`developer`、`planner`、`module-readme`、`anti-patterns` 移除/泛化本项目硬编码

- **版本号**统一为 v1.7.4（六处 LTS 同步）

---

## [1.7.3] - 2026-07-07

### Added

- **[TEAM-GUIDE.md](./TEAM-GUIDE.md)**：团队 3 分钟上手（唯一入口「项目经理 + 需求」、三步流程、五态、FAQ）

- **[references/user-visible-states.md](./references/user-visible-states.md)**：用户可见五态 ↔ 内部状态映射与 Agent 输出规则

### Changed

- **README**：顶部改为团队简明入口；岗位/术语/避坑折叠为进阶

- **QUICKSTART**：新增 §团队入口、§用户可见状态；L3 重命名为 **§TL-L3**（团队默认不走）；标准模式标为团队默认

- **project-manager**：团队用户默认输出模板；不主动 L3；新需求不要求用户自派策划

- **`.mdc` / `.trae/rules` / MAINTAINER**：团队路径与 v1.7.3 六处 LTS 同步

---

## [1.7.2] - 2026-07-07

### Changed

- **执行文档黄金样例**迁至 `.cursor/skills/references/执行文档黄金样例.md`（Skill 通用，不再放在项目 `化学文档/_模板/`）

- 样例内容泛化：占位路径 `[path/to/module]`、多技术栈 `{cs|ts|py|go}`，适用于简单/复杂项目

- **project-context**：执行文档存放约定与 Skill 结构参考分离

- **QUICKSTART / planner / README / execution-doc-template / MAINTAINER**：链接与说明同步

- **版本号**统一为 v1.7.2（六处 LTS 同步）

---

## [1.7.1] - 2026-07-07

### Fixed

- **项目经理**：8 处「微型模式除外」统一为「微型/资产模式除外」；派发模板与文档状态枚举补「资产」

- **handoff-template**：流水线模式枚举补「资产」

- **evidence-levels**：补资产模式输出规则专节

- **README**：黄金样例相对路径 `../Assets` → `../../Assets`；合并 LTS/定版首行

- **执行文档黄金样例**：`execution-doc-template` / `project-context` 相对路径修正（7 层至仓库根）

### Changed

- **Trae 规则**：§微型升级 与 `.mdc` 对齐（补 public API/行为变化）

- **cursor-native-tools / code-reviewer**：资产模式跳过 CR 与 diff 降级说明

- **state-machine**：补微型/资产不迁状态机例外

- **check-pipeline-doc**：`-CheckGit` 对纯 prefab/asset 改动提示可考虑资产模式

- **MAINTAINER**：冒烟清单补链接可达检查

- **版本号**统一为 v1.7.1（六处 LTS 同步）

---

## [1.7.0] - 2026-07-07

### Added

- **资产模式**：prefab/asset/ProjectSettings-only 改动路由（QUICKSTART §资产模式、workflow-modes、`.mdc`）

- **微型/资产升级启发式**：改代码前扫描文件数、扩展名、diff 行数、模块目录（QUICKSTART §微型升级）

- **[validate-pipeline.ps1](../scripts/validate-pipeline.ps1)**：一键校验回归索引 sync + 执行文档（`-Strict` 供 CI）

- **[执行文档黄金样例](../../Assets/LabSDK/Runtime/Pennon/ExplorationLab/化学文档/_模板/执行文档黄金样例.md)**：策划结构参考

### Changed

- **check-pipeline-doc.ps1**：流水线模式枚举、证据等级与状态一致性校验

- **岗位 SKILL 瘦身**：developer/planner/code-reviewer/project-manager 共性段落收敛至 QUICKSTART

- **anti-patterns**：资产模式与 §微型升级误用行

- **project-context / execution-doc-template**：链接黄金样例

- **版本号**统一为 v1.7.0（六处 LTS 同步）

---

## [1.6.1] - 2026-07-07

### Added

- **[sync-regression-index.ps1](../scripts/sync-regression-index.ps1)**：比对 `project-context.md` 回归表 ↔ `regression-index.yaml`（默认 warn；`-Strict` 可 fail）

### Fixed

- **pre-commit-pipeline-advisory.ps1**：路径匹配改为 `化学文档/.../*.md`（修复 v1.6.0 `$` 锚点导致永不命中化学执行文档）

- **pre-commit**：stage `project-context.md` 或 `regression-index.yaml` 时自动跑 sync 校验

### Changed

- **anti-patterns**：补「只改 MD 未同步 YAML」反模式行

- **MAINTAINER**：补 sync 脚本说明与发布清单项

- **版本号**统一为 v1.6.1（六处 LTS 同步）

---

## [1.6.0] - 2026-07-07

**1.5.x 稳定线收官；本 minor 纳入文档分工、校验工具链与 Trae 对齐。**

### Added

- **[regression-index.yaml](./references/regression-index.yaml)**：`project-context.md` 回归索引的脚本可读副本（**MD 表仍为权威**）

- **[pre-commit-pipeline-advisory.ps1](../scripts/pre-commit-pipeline-advisory.ps1)**：可选 pre-commit **advisory**（默认 warn；`-Strict` 可 fail）

- **retrospective-metrics**：复盘模板增加 blocker/打回合计、Step 数、模式升级等**可选量化字段**

### Changed

- **Trae 规则**与 **`.mdc`** 公共 references 列举对齐（含校验脚本、anti-patterns、execution-doc-template 等）

- **MAINTAINER**：LTS **v1.6.0**；`1.6.x` patch 策略；补 optional pre-commit 安装说明

- **project-context**：回归索引维护须同步 YAML（v1.6.0）

- **文档**：checklist 补 regression-index.yaml 同步

- **版本号**统一为 v1.6.0（六处 LTS 同步）

---

## [1.5.8] - 2026-07-07

### Fixed

- **weekly-report/SKILL.md**：checklist 断链 `README#周报使用模式` → 本 Skill §输入模式与材料范围（README 瘦身后权威在本 Skill）

- **check-pipeline-doc.ps1**：支持 **legacy** 行内 `**文档状态**` / `**可交给程序员**`（化学文档现有格式）；保留 template `## 文档状态` 块校验

- **项目经理**：禁止行为补「微型直接改不算切换岗位」

### Changed

- **MAINTAINER**：发布清单改为 **六处** LTS 同步；脚本说明区分 template / legacy

- **CHANGELOG** 维护说明：LTS 同步位置与 v1.5.7 后文档分工对齐

- **`.mdc` / Trae 规则**：补执行文档校验脚本说明

- **版本号**统一为 v1.5.8

---

## [1.5.7] - 2026-07-07

### Added

- **[MAINTAINER.md](./MAINTAINER.md)**：维护者手册（LTS 策略、Trae 联接、references 索引、发布清单）

- **[check-pipeline-doc.ps1](../scripts/check-pipeline-doc.ps1)**：执行文档「文档状态」轻量校验（默认 warn；`-Strict` 可 fail）

### Fixed

- **项目经理**：「用途」段补充 **微型模式除外**（与 checklist / `.mdc` 一致）

### Changed

- **README 瘦身**：用户手册 ≤400 行；周报详情、维护约定、LTS 长文、references 表迁入 MAINTAINER

- **版本号**统一为 v1.5.7（检查通过后维护者可 bump **v1.6.0**）

---

## [1.5.6] - 2026-07-07

### Added

- **QUICKSTART § 索引**：交叉引用简称表，防 § 引用漂移

- **anti-patterns**：「微型已命中仍因 PM 禁止改代码拒绝执行」反模式行

### Fixed

- **项目经理**：checklist / 硬门禁 / 禁止行为三处统一 **微型模式改代码例外**，与 `.mdc` 微型路由一致

- **项目经理**：§ 引用统一为 `§30 秒选岗`（与 QUICKSTART 标题空格一致）

- **项目经理 / 派发模板**：流水线模式枚举补充 **微型**（注明通常不迁状态机）

### Changed

- **cursor-native-tools**：微型模式说明补「主 Agent 直接改代码」

- **README**：反模式表去版本号绑定；LTS 版本号统一为 v1.5.6

---

## [1.5.5] - 2026-07-07

### Fixed

- **交叉引用**：`§护栏` 统一为 `§并发与回归护栏`（与 QUICKSTART 标题一致）；`§hard-soft` 改为 `§hard-soft-blocker`

- **项目经理**：「与其他 Skill 的关系」补充微型模式改代码例外，与 `.mdc` 微型路由一致

### Changed

- **QUICKSTART**：模式表增加 CR 释义；标准/完整模式行展开为「代码审核（CR）」

- **README / QUICKSTART / 规则文件**：LTS 版本号统一为 v1.5.5

---

## [1.5.4] - 2026-07-07

### Added

- **CHANGELOG.md**：独立版本历史（本文件）

- **README LTS 声明**：`1.5.x` 稳定基线、维护策略、全局 Skill 优先级说明

### Changed

- **QUICKSTART**：「v1.5.1 护栏」改为「并发与回归护栏」（去版本号绑定）

- **QUICKSTART**：模式表首次出现 CR 时展开为「代码审核（CR）」

- **README / QUICKSTART / 规则文件**：版本号统一为 v1.5.4

---

## [1.5.3] - 2026-07-07

### Added

- **[references/anti-patterns.md](./references/anti-patterns.md)**：反模式 / 常见误用与后果对照表

### Changed

- **项目经理 checklist 去重**：护栏、hard/soft blocker 以 [QUICKSTART.md](./QUICKSTART.md) 为唯一权威

---

## [1.5.2] - 2026-07-07

### Added

- **微型模式 `.mdc` 默认路由**：`.cursor/rules/ai-dev-pipeline.mdc` 内主 Agent 直接改、不 Read 程序员 SKILL

### Changed

- **QUICKSTART 压缩**：去除多余空行，保持真·一页速查

---

## [1.5.1] - 2026-07-07

### Added

- **交接时间**必填（[handoff-template.md](./references/handoff-template.md)）；冲突恢复与 [state-machine.md](./references/state-machine.md) 对齐

- **回归索引三角**：程序员 → 文档 → 项目经理；写入三岗 checklist

- **同 Step 周期 soft blocker**：替代不可 Agent 判定的 24h 自动计时门禁

- **L3 只读 Chat**：独立审方案不改执行文档；定稿由项目经理/策划单 Agent 写入

- **执行文档路径约定**（[project-context.md](./project-context.md) → `化学文档/`）

### Changed

- **QUICKSTART**：补 v1.5 护栏、hard/soft blocker、微型模式措辞统一

- **README**：并行表述修正；流程稳定性规则表扩展

---

## [1.5.0] - 2026-07-07

### Added

- **项目根语义**：本项目根 = 仓库根

- **回归索引维护规则**（[project-context.md](./project-context.md)）

- **[state-machine.md](./references/state-machine.md) 并发与协作**：同文档 Step 串行、并行隔离、冲突恢复

---

## [1.4.0] - 2026-07-07

### Added

- **[QUICKSTART.md](./QUICKSTART.md)**：一页路由与门禁速查

- **[execution-doc-template.md](./references/execution-doc-template.md)**：执行文档复制模板

- **各岗位 SKILL 文首最小 checklist**

- **[cursor-native-tools.md](./references/cursor-native-tools.md)**：Bugbot / Security Review 与流水线分工

- **[retrospective-metrics.md](./references/retrospective-metrics.md)**：可选归档复盘指标

---

## [1.3.0] - 2026-07-07

### Added

- **公共 references/**：证据等级、图谱探测、方案审核档位、状态机、交接模板、模式规则

- **微型模式**与 [workflow-modes.md](./references/workflow-modes.md) 自动判定表

- **方案审核 L1 / L2 / L3**（[plan-review-tiers.md](./references/plan-review-tiers.md)）

- **CodeGraph soft blocker**：标准模式无图谱可继续审查；完整模式仍为 hard blocker

---

## [1.2.0] - 2026-07-07

### Added

- **文档状态机**（draft → … → completed）

- **统一交接块**（[handoff-template.md](./references/handoff-template.md)）

- **项目经理复盘模式**

- **终态 `completed(已归档)`**

---

## 维护说明

| 变更类型 | 版本 bump | 示例 |

| --- | --- | --- |

| 措辞、反模式、回归索引行、脚本 warn 行为 | patch（1.6.x） | anti-patterns 补充一行 |

| 新 references 文件、新 checklist 项（兼容） | minor（1.7.0） | 新增「测试」岗位 |

| 状态机新态、模式删除、门禁语义变更 | major（2.0.0） | 取消微型模式 |

修改 Skill 后请同步更新本 CHANGELOG，并将 LTS 版本号同步至：**README 头**、**CORE 头**、**CHANGELOG 顶**、**MAINTAINER**、**`.cursor/rules/ai-dev-pipeline.mdc`**、**`.trae/rules/ai-dev-pipeline.md`**、**`validate-pipeline.ps1`**、**`check-pipeline-doc.ps1`**。

