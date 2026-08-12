# AI 开发流水线 — 维护者手册

> 面向修改 `.cursor/skills/` 的维护者。
> **团队用户** → [USER-GUIDE.md](../USER-GUIDE.md) · **Agent/TL 日常** → [agent-entry-route.md](./references/agent-entry-route.md)

## 稳定版本（LTS）

- **当前版本值**：[VERSION](./VERSION)（唯一来源）；发布状态与历史见 [CHANGELOG.md](../CHANGELOG.md)
- **争议/recovery/按 CORE 重来 权威**：[CORE.md](./CORE.md)（≤200 行；四车道 + PM 输出 + 硬门禁 + 冷启动 + 恢复）；**日常入口**：[agent-entry-route.md](./references/agent-entry-route.md)
- **Skill 母本**：本仓库 `.cursor/skills/`（Trae 经 `.trae/skills/` 联接；**建议纳入 Git**）
- **版本历史**：[CHANGELOG.md](../CHANGELOG.md)

### RC 转正条件（v3.1.3 → 已关闭）

v3.1.3 观察期已于 **2026-07-16** 由 TL「bump / 转正」关闭；当前 LTS 为 **v3.1.4 定版**（v3.1.4 为 2026-07 历史定版，当前 LTS 以 [CHANGELOG.md](../CHANGELOG.md) 顶行为准）。历史勾选状态：

- [x] 1 个真实 **Express** 需求走完整闭环（切片 → 改代码 → 自检 → Unity 测试）— 证据：`Assets/Doc/_examples/express-closed-loop-console-log-mirror/`（Console Log Mirror · 2026-07-17 runtime-validated）
- [x] 1 个真实 **Standard + L1.5** 需求走完整闭环（plan-lite → 方案审核 → 程序员 → CR → README）— 证据：`Assets/Doc/_examples/standard-l15-closed-loop-console-log-mirror-toolbar/`（去顶部工具栏 · 2026-07-17 runtime-validated）
- [ ] 期间无需触发 `按 CORE 重来`，或触发后已按 §Agent 失败模式与恢复 收口
- [ ] 上述过程中未发现 CORE / SKILL 规则冲突
- [ ] 2026-07-08 审计新增规则在真实闭环中至少各触发验证一次
- [x] 跑 [skill-eval-checklist.md](./references/skill-eval-checklist.md) §A~D 剧本，Pass 率 ≥90%（**21/21 真演**，见 `Assets/Doc/_examples/skill-eval-ad/_评分表.md`）

**2026-07-09 审计进度（历史）**：Full 车道 L3 多轮纠错已有真实证据。
**2026-07-17**：真实 **Express** 与 **Standard+L1.5** 闭环均已补（见上勾选项）。
**2026-07-17（同日）**：P1.5（Delta Spec / 微循环 / 经验提议）规则+评测落地，见 CHANGELOG「未发布 · P1.5」；不 bump。

### LTS 定版说明（v3.1.4）

| 项 | 说明 |
| --- | --- |
| **适用范围** | Unity + Cursor / Codex / Trae；唯一入口「项目经理 + 需求」；Express / Standard / Full |
| **运行前** | [USER-GUIDE.md](../USER-GUIDE.md) §第一次接入 — project-context、回归索引双写、§热路径批量回归（可选）、**推荐 CodeGraph** |
| **用户可见** | PM 内部字段仅 Agent 使用；面向用户只输出白话「你下一步」（CORE §用户可见输出）；Full 强制须白话提示完整流程 |
| **人工验收** | Unity 测试、新开 Chat / 换模型审查 — **设计为人工选择**，Agent 只提示，不自动化、不校验、不阻断 Standard 闭环 |
| **PM 门禁** | 硬门禁 #7 + 各岗 SKILL §PM 门禁 — 无本轮 PM 结构化判定不得改交付物（仍依赖 Agent 执行） |
| **恢复口令** | 主口令 **`按 CORE 重来`**（同义：`流水线重来`、`没按流程来`） |
| **已知限制** | 合规依赖 Agent 自觉执行硬门禁；PM 脚本 / Git **可选**；冷启动无 project-context 时保守 Standard；L1 同 Chat 为「非独立复核」（多 Step 时 PM **提示**可选新开 Chat，不校验） |
| **发布前抽测** | Express 单文件小改；Standard+回归模块；**绕过 PM 直叫岗位**（应硬停引导）；Full 强制须见完整流程白话 |
| **archive/** | **若存在**该目录，须含 [archive/README.md](./archive/README.md)「勿读」哨兵；当前仓库无 `archive/`，此项不适用；Agent 日常不 Read |

- **维护策略**：
  - **v3.1+ LTS**：**CORE 结构冻结**（仅 patch 措辞微调）；新规则优先进 `references/`；破坏性变更 → v4.0
  - **v3.0.x**：已归档（见 CHANGELOG）；Full/L3/状态机 → `references/` lazy load
  - **v2.x / v1.x**：已删除（CHANGELOG 保留历史）
- **Skill 放置**：通用 Skill 可随 Git 放在 `.ai-gates/skills/`（Cursor 经 `.cursor/skills/` 传送门；Trae 经 `.trae/skills/` 联接），或复制到个人 `~/.cursor/skills/`；`.cursor/project-context.md` 等项目专属文件须每仓库独立维护

## 文档分工（v3）

| 文件 | 读者 | 行数目标 |
| --- | --- | --- |
| [USER-GUIDE.md](../USER-GUIDE.md) | **新手指南 / 团队用户（首选）** | ≤130 |
| [METHODOLOGY.md](../METHODOLOGY.md) | **叙事简介**（老板/新 TL/对外；非 Agent 默认必读） | ≤120 |
| [CORE.md](./CORE.md) | **争议/recovery/按 CORE 重来**（日常入口见 agent-entry-route） | ≤200 |
| 本文件 | 维护者 / Full 车道 | 不限 |
| 各 `*/SKILL.md` | 岗位 Agent | ≤60 |
| [templates/](./templates/) | plan-lite、L1.5 CR 派发、恢复记录 | — |
| [references/](./references/) | Full/L3/状态机等按需规则 | 按主题 |

改 CORE 后检查 `.mdc` / `.trae/rules` 与各岗 SKILL 指针。

## 目录与同步策略

| 内容 | 权威位置 | 说明 |
| --- | --- | --- |
| 中央技能库（Skill + 说明文档 + LICENSE） | `.ai-gates/skills/`（规则/角色/CHANGELOG/VERSION）、`.ai-gates/`（SKILLS/METHODOLOGY/USER-GUIDE 说明文档）、`.ai-gates/README.md` | Git 跟踪（**通用**，可复制到其他项目）；**唯一真源** |
| Cursor Hooks 配置 + 脚本 | `.ai-gates/hooks.json`、`.ai-gates/hooks/` | Git 跟踪（**通用**，随包分发）；运行时日志 `.ai-gates/hooks-log/` 不提交 |
| Codex 接线 | `.ai-gates/codex/hooks.json` + `config.toml` | Git 跟踪；`.codex/` 为传送门 |
| 传送门（软连接） | `.cursor/skills\|hooks\|scripts\|rules`、`.cursor/hooks.json`、`.codex`、`.trae/skills` | **不入库**；`link-platform.ps1` / `link-platform.sh` 一键创建（Windows 用 Junction，无需管理员） |
| 平台脚本 | `.ai-gates/scripts/` | Git 跟踪（**通用**）；`.cursor/scripts/` 为传送门 |
| `.cursor/project-context.md` | 仓库根 `.cursor/` | **每项目一份**；`init-project-context.ps1` 或复制 template |
| `.ai-gates/regression-index.yaml` | 仓库根 `.cursor/` | **每项目一份**（可选）；模板见 [regression-index.template.yaml](./references/regression-index.template.yaml) |
| `.ai-gates/pipeline-recovery-log.md` | 仓库根 `.cursor/` | **每项目一份**（可选）；模板见 [pipeline-recovery-log.md](./templates/pipeline-recovery-log.md) |
| `.ai-gates/pipeline-snapshot.log` | 仓库根 `.cursor/` | **每项目一份**（可选 JSONL）；模板见 [pipeline-snapshot-log.md](./templates/pipeline-snapshot-log.md) |
| 中间产物暂存区 | `.ai-gates/tmp/` | **不入库**；一次性脚本/中间输出只放这里（revision/hash 计算、压力测试、批量迁移等），环节收尾整目录清空；**不要混入 `.ai-gates/hooks-log/`（运行时证据）或 `.ai-gates/skills|scripts|hooks|rules`（中央库内容）** |
| `.trae/skills/` | 联接 → `.ai-gates/skills/` | 克隆后运行联接脚本 |
| `.trae/rules/ai-dev-pipeline.md` | Trae 入口 | 与 `.cursor/rules/ai-dev-pipeline.mdc` 对齐 |

**clone 后一次性创建所有传送门**（Cursor / Trae / Codex 读同一份 Skill）

```powershell
powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1
```

```bash
bash .ai-gates/link-platform.sh
```

只补 Trae 联接（已有其他传送门时）：`link-trae-skills.ps1` / `.sh`（`.ai-gates/scripts/`）。
传送门是 Junction/符号链接，**内容只存一份在 `.ai-gates/`**；改任何一边即改中央库。
**`.cursor/` 是历史遗留的运行层目录名**（gitignored：hooks-log/tmp/verify/项目状态 + 未使用的
Cursor/Trae 传送门），**不表示要求安装 Cursor**；Codex-only 团队只需 `.ai-gates/` + `.codex`
传送门 + `AGENTS.md`（Codex 接线直接指 `.ai-gates/hooks/codex/*.ps1` 真实路径，不依赖
`.cursor/` 传送门）。

## 流程稳定性规则（references 索引）

| 规则 | 文件 |
| --- | --- |
| 证据等级 + hard blocker / soft risk | [evidence-levels.md](./references/evidence-levels.md) |
| 图谱探测 | [codegraph-probe.md](./references/codegraph-probe.md) |
| 方案审核档位 | [plan-review-tiers.md](./references/plan-review-tiers.md) |
| 文档状态机 + 并发 | [state-machine.md](./references/state-machine.md) |
| 统一交接块 | [handoff-template.md](./references/handoff-template.md) |
| 跨会话交接（八段） | [session-handover.md](./references/session-handover.md) |
| 执行文档模板 | [execution-doc-template.md](./references/execution-doc-template.md) |
| 物理口径模板（新窗） | [phys-spec.md](./templates/phys-spec.md) |
| 执行文档黄金样例 | [执行文档黄金样例.md](./references/执行文档黄金样例.md) |
| 文档默认路径 | [doc-path-defaults.md](./references/doc-path-defaults.md) |
| 回归索引 YAML 模板 | [regression-index.template.yaml](./references/regression-index.template.yaml) |
| 项目专属边界 | [project-local-config.md](./references/project-local-config.md) |
| 反模式全文 | [anti-patterns.md](./references/anti-patterns.md) |
| 执行纪律（不漂移、不臆测） | [execution-discipline.md](./references/execution-discipline.md) |
| 团队五态映射 | [user-visible-states.md](./references/user-visible-states.md) |
| 复盘与恢复度量 | [retrospective-metrics.md](./references/retrospective-metrics.md)（含效果轻量版 outcome） |
| 效果轻量日志 | [pipeline-outcome-log.md](./templates/pipeline-outcome-log.md) + `append-pipeline-outcome.ps1` / `summarize-pipeline-outcome.ps1` |
| 共享语言 / 活词汇表 | [shared-language.md](./references/shared-language.md) |
| CR 双轴模式（规范轴 + 规格轴） | [dual-axis-review.md](./references/dual-axis-review.md) |
| test-first 切片（含可机械验证项时默认启用） | [test-first.md](./references/test-first.md) |
| 架构体检（CRG 支撑） | [architecture-health-check.md](./references/architecture-health-check.md) |
| 外部调研子代理任务（可选） | [research-task.md](./references/research-task.md) |
| 人机交互向导（可选） | [human-wizard.md](./references/human-wizard.md) |
| 决策点地图 / wayfinder（可选） | [decision-map.md](./references/decision-map.md) |
| Full 车道决策树（TL） | [full-lane-decision-tree.md](./references/full-lane-decision-tree.md) |
| PM 工具脚本 | [pm-tooling.md](./references/pm-tooling.md) |
| README 派岗 | [readme-dispatch.md](./references/readme-dispatch.md) |
| 端到端样例（lazy load） | [examples.md](./references/examples.md) |
| TL 项目接入完整步骤 | [tl-onboarding.md](./references/tl-onboarding.md) |
| Skill 改动自评测清单（迷你 Harness） | [skill-eval-checklist.md](./references/skill-eval-checklist.md) |
| Loop Engineering / Auto 外环 | [loop-engineering.md](./references/loop-engineering.md) |
| 复核派发工件生命周期 | [review-dispatch-lifecycle.md](./references/review-dispatch-lifecycle.md) |
| 经验沉淀 / 错题本（准全自动） | [lessons-learned.md](./references/lessons-learned.md)；模板 [lesson-pending.md](./templates/lesson-pending.md)；落表脚本 `.cursor/scripts/commit-lesson-pending.ps1` |
| 被拒需求归档 / 去重（out-of-scope） | [out-of-scope.md](./references/out-of-scope.md) |
| 深模块设计语言（codebase-design） | [codebase-design.md](./references/codebase-design.md) |
| 并行接口设计（design-it-twice） | [design-it-twice.md](./references/design-it-twice.md) |
| 需求澄清与确认（一轮确认 / 三问 / 异步问卷 / grill 访谈） | [demand-clarification.md](./references/demand-clarification.md) |
修改 reference 后：检查 CORE 翻车表、anti-patterns、`.mdc` / `.trae/rules` 引用是否需同步。

## 技能元数据规范

- 每个岗位 SKILL 目录（`skills/<岗>/`）必须带 `agents/openai.yaml`：`interface.display_name` 与 `interface.short_description` 非空（中文，short_description 与 SKILL.md frontmatter description 一致，不新增触发词），`policy.allow_implicit_invocation: false`；新增/修改后须用真实解析器做 YAML 解析校验，解析失败视为设施缺陷。
- **双轨调用**（调用权限维度；与 [dual-axis-review.md](./references/dual-axis-review.md) 的 CR「双轴（规范轴/规格轴）」是不同维度，术语登记见 [shared-language.md](./references/shared-language.md)）：
  - 岗位 SKILL = **user-invoked**：口令触发（「策划」「程序员」等），模型**不得**自动以岗位身份执行；`allow_implicit_invocation: false` 即此语义的机器可读声明。
  - references = **model-invoked**：按 [reference-routing.md](./references/reference-routing.md)「模型自动触发」小表的触发语义由模型自动加载，无需用户点名。
- 典故 / 术语被点名（提词即唤起既定共识）同样按 [reference-routing.md](./references/reference-routing.md)「模型自动触发」小表由模型自动加载 shared-language.md（model-invoked）；触发表新增行的同步义务遵循本节既有「不同步 = 设施漂移」句，不重复其校验内容。
- 不同步 = **设施漂移**：新增/修改岗位 SKILL、触发表行或元数据字段时，须同步 openai.yaml + 触发表 + 本规范，并运行 `.cursor/scripts/validate-pipeline.ps1 -Strict`。

### 错题本落表（用户「准」后）

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/commit-lesson-pending.ps1 `
  -PendingPath "{方案夹}/证据/_lesson-pending.md" -Apply
```

## 维护约定

1. 文件夹名英文；岗位调用名中文。
2. 新规则写「原则 + 例外 + 输出要求」，少堆 checklist。
3. 改岗位 Skill 后更新 CHANGELOG；若 bump，只原子修改 `VERSION` + CHANGELOG。
4. 项目专属内容只进 **`.cursor/project-context.md`** 与 **`.ai-gates/regression-index.yaml`**；不写进 `.cursor/skills/`（见 [project-local-config.md](./references/project-local-config.md)）。
5. README/CORE/本文件/`.mdc`/Trae/校验与打包脚本只指向或读取 `VERSION`，禁止复制当前版本值。
6. 更新 **`.cursor/project-context.md`** 回归索引表后，运行 `sync-regression-index.ps1 -Apply` **自动重新生成** `.ai-gates/regression-index.yaml`（v2.1.0 起不再手工双写；`-Strict` 仍可用于纯校验/CI）。

## 排版约定（当前）

- **章节之间**：最多 **1 行**空行（`##` 标题前保留 1 行即可）。
- **块内部**：列表项、表格行、连续 `>` 引用、编号规则之间 **不插空行**。
- **代码围栏内**：样例可读性需要的空行可保留（附录样例等）。
- **禁止**：装饰性 `---` 分隔线（YAML frontmatter 的 `---` 除外）。
- **目标行数**：CORE ≤200；岗位 SKILL ≤60；改完后用 `Measure-Object -Line` 自检。

## 一键校验脚本

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/validate-pipeline.ps1 -Strict
powershell -ExecutionPolicy Bypass -File .cursor/scripts/validate-pipeline.ps1 -DocPath "Assets/.../方案.md" -Strict
```

`validate-pipeline -Strict` 的 hooks policy 段内含 **BOM 扫描**（`check-hooks-policy.ps1`：hooks/ + scripts/ 下 *.ps1 首 3 字节须为 `EF BB BF`，非 BOM → fail；2026-08-03 机械化）。

## 执行文档校验脚本

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/check-pipeline-doc.ps1 -DocPath "Assets/.../方案.md" -Strict
```

`check-pipeline-doc.ps1` 须 **UTF-8 BOM** 保存（Windows PowerShell 5.1）。

## 运行时证据 / 方案状态脚本（支柱 A/B · 可选）

权威：[unity-editor-log.md](./references/unity-editor-log.md) §0（支柱 A）、[loop-engineering.md](./references/loop-engineering.md) §1.5（支柱 B）。均只产出/管理事实，不判定证据等级或车道；未接入不影响现有流程。

```powershell
# 支柱 A：机械化查 Editor.log 关键词命中/新鲜度/编译错误，产出带时间戳 JSON 证据
powershell -ExecutionPolicy Bypass -File .cursor/scripts/verify-runtime-evidence.ps1 -Keywords "kw1,kw2" -OutputPath "{方案夹}/证据/{日期}-verify.json"

# 支柱 B：方案夹状态外置到 .state.json（非法迁移拒绝，退出码非 0；不进 Git，见 .gitignore）
powershell -ExecutionPolicy Bypass -File .cursor/scripts/update-doc-state.ps1 -DocFolder "{方案夹}" -Init
powershell -ExecutionPolicy Bypass -File .cursor/scripts/update-doc-state.ps1 -DocFolder "{方案夹}" -Transition step-completed -Note "..."
```

## 发布打包脚本

`.cursor/package-release.ps1`（注意：不在 `.cursor/scripts/` 下，单独放在 `.cursor/` 根）——把要分发给其他项目的文件打包成 7z：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/package-release.ps1
powershell -ExecutionPolicy Bypass -File .cursor/package-release.ps1 -Version "v$((Get-Content .cursor/skills/VERSION -Raw).Trim())"
```

输出 `.ai-gates/releases/ai_dev_<版本号>.7z`，打包范围来自**中央技能库 `.ai-gates/`**，**包顶层 = 中央技能库内容**（解压到目标项目根即得 `.ai-gates/`）：`skills/`（**排除** `MAINTAINER.md`）+ `scripts/*.ps1|*.sh` + `rules/ai-dev-pipeline.mdc` + `hooks.json`/`hooks/*.ps1` + `hooks/codex/*.ps1` + `codex/hooks.json` + `codex/config.toml`（Codex 接线）+ `METHODOLOGY.md`/`USER-GUIDE.md`（新人说明文档）+ 根 `CHANGELOG.md`（供公开增信）+ `link-platform.ps1/.sh` + `README.md` + `LICENSE`；**不含** `.trae/`、脚本自身（`package-release.ps1`）、`project-context.md`、`regression-index.yaml`、`hooks-log/`（运行时日志）、`AGENTS.md`（项目相关，Codex 用户按 §Codex Hooks 自建）等。**新项目接入三步**：解压到项目根 → 跑 `link-platform.ps1`（建 `.cursor/*`、`.codex`、`.trae/skills` 传送门）→ 按需建 `AGENTS.md`。若目标项目用 Trae，`.trae/rules/ai-dev-pipeline.md` 与 `.trae/skills/` 联接需按 [MAINTAINER §目录与同步策略](#目录与同步策略) 单独处理（`link-trae-skills.ps1`/`.sh` 已随包）。依赖本机已安装 7-Zip（`7z.exe` 在 PATH 或默认安装目录）。**打包前默认强制 `validate-pipeline.ps1 -Strict`**（2026-08-03 Step 3）：红 → `Write-Error` 拒绝句「已拒绝打包」+ `exit 1`；`-SkipValidate` 为显式逃生（打印醒目警告后跳过，维护者签字级），`-ValidateScriptPath` 可注入替代校验脚本（测试用）。

## Cursor Hooks（机器强制层 · observe/ask 模式）

`.cursor/hooks.json` + `.cursor/hooks/*.ps1`，克隆仓库后 Cursor 自动加载，**不需要用户手动安装**（跟 pre-commit 不同，pre-commit 需要 TL 手动跑安装命令）。当前落地七个 hook，**均遵循"先观察/问询，不做硬 deny"的设计**（`pm-gate-check.ps1` 2026-07-21 前曾短暂是 `deny`，因下文「已知限制」第 1 条降级为 `ask`，详见 CHANGELOG 2026-07-09 P2 / 2026-07-21 记录；2026-08-03 再改为对 `.cursor/**` 分级豁免的轻门禁）：

| Hook | 事件 | 行为 | 文件 |
| --- | --- | --- | --- |
| Hooks 声明漂移检测 | `sessionStart` | 比对 MAINTAINER observe/ask 声明 ↔ `hooks.json` / `pm-gate-check.ps1` / 本 hook 齐套；漂移 → 写 `.ai-gates/hooks-log/hooks-policy-drift.json` 并注入 `additional_context`（不拦截会话）；共享逻辑 `.cursor/scripts/check-hooks-policy.ps1` | `check-hooks-drift.ps1` |
| Git 高危命令确认 | `beforeShellExecution` | 命中 `git push --force`/`reset --hard`/`clean -f*`/`checkout --`/`branch -D` 等 → `permission: deny` + user_message 逃生提示（2026-08-03 由 ask 改：Cursor 2.2+ hook `ask` 无效是官方确认 bug）；其余命令 `allow` | `git-safety-check.ps1` |
| 交付物改动审计 | `preToolUse`（matcher: `Write\|StrReplace\|EditNotebook`） | 记录 `时间戳 \| tool \| session \| path` 一行到 `.ai-gates/hooks-log/write-audit.log`（不提交 Git）；**始终 `allow`，不拦截** | `pre-write-gate.ps1` |
| PM 判定标记打点 | `afterAgentResponse`（matcher: `AgentResponse`） | 回复文本命中 `[PM]` → 把 `{conversation_id: {lastPmAtUtc, snippet}}` 写入 `.ai-gates/hooks-log/pm-gate.json`；纯观测，无 `permission` 语义 | `mark-pm-gate.ps1` |
| PM 门禁机械检查（支柱 D） | `preToolUse`（matcher: `Write\|StrReplace\|EditNotebook`） | 业务路径按 `conversation_id` 查 `pm-gate.json` 里最近 120 分钟内有无 `[PM]` 标记；`.cursor/**` **分级豁免**——**Level 0 全豁免** `allow`（kill switch / `CHANGELOG.md` 自身 / `hooks-log/**` 运行时 / 项目专属文件 project-context.md、regression-index.yaml、lessons-* 等）；**Level 1 轻门禁**（`.cursor/skills\|hooks\|scripts\|rules\|hooks.json` 写操作：会话内最近 120 分钟有 CHANGELOG 写记录 → `allow`，无 → `permission: deny` + user_message 逃生提示——先写 CHANGELOG / kill switch / 手动编辑；2026-08-03 由 ask 改，Cursor 2.2+ hook `ask` 无效是官方确认 bug；打点文件缺失 → 同 `deny`（初始状态 = 无任何会话有流水）；损坏/时间戳不可解析 → fail-open `allow`）；**其余 `.cursor/**` 兜底 `allow`**（package-release.ps1、README.md、mcp.json、ai_dev_*.7z、`_release_staging/` 等）；标记缺失/过期 → `permission: deny`（逃生：发 `[PM]` / kill switch / 手动编辑）；解析异常 fail-open 为 `allow` | `pre-write-gate.ps1` |
| 写后编译错误提示（写后质量门） | `postToolUse`（matcher: `Write\|StrReplace\|EditNotebook`） | 命中 `.cs`/`.lua` 路径 → 扫最近 Unity `Editor.log` 的 `error CS\d{4}` 编译错误；命中 → 注入 `additional_context`（+ `additionalContext` 兼容）+ 审计一行 `.ai-gates/hooks-log/unity-compile-check.log`；**恒 `allow` 不拦截**；日志缺失/解析异常/非代码路径 → 静默放行；不做 batchmode / 业务断言（归黄金验窗） | `post-write-gate.ps1` |
| CHANGELOG 写打点（轻门禁数据源） | `postToolUse`（matcher: `Write\|StrReplace\|EditNotebook`） | 写 `.ai-gates/CHANGELOG.md`（路径以 `changelog.md` 结尾即可，大小写不敏感）时把 `{conversation_id: {lastChangelogWriteAtUtc}}` 原子写入 `.ai-gates/hooks-log/changelog-writes.json`（复用 mark-pm-gate 的 Write-GateAtomic 原子写模式）；非 CHANGELOG 路径仅审计；纯观测恒 `allow`，一切异常 exit 0（fail-open）；供 pm-gate-check Level 1 轻门禁读取 | `post-write-gate.ps1` |

**合并入口（2026-08-06 · 性能优化，语义不变）**：同一事件多门禁已合成单入口脚本——
`pre-write-gate.ps1`（audit-write + pm-gate-check）、`post-write-gate.ps1`
（mark-changelog-write + check-unity-compile）——单进程内依次执行原门禁脚本，stdin 预读共享；
deny 短路语义与分开挂载一致，进程 spawn 减半（Write/StrReplace/EditNotebook 事件
preToolUse 2→1、postToolUse 2→1）。原单门禁脚本保留（供测试与单独排查）。

**已知限制 / 后续升级路径**：

1. **`pm-gate-check.ps1` 的落地经验（2026-07-21）**：先做过 `permission: deny` 的"硬门禁 7 机械版"，真实会话验证时发现 `mark-pm-gate.ps1` 落盘时机不可靠——`afterAgentResponse` 用 Cursor **Execution Log** 面板能看到确实触发过（真实 payload 含 `conversation_id`/`generation_id`/`model` 等字段），但同一会话连续 3 次完整回复里出现 `[PM]`，标记文件都没能按预期写出；`deny` 在这种情况下会把人逼进死路（只能靠 kill switch 或手动重放脚本）。**已降级为 `ask`**：标记缺失/过期时转人工确认而不是硬拒绝，既保留"提示未检测到标记"的机械层，又不产生死路。**2026-08-03 再反转**：Cursor 2.2+ 的 hook `permission: ask` 是官方确认的 bug——不弹窗、命令/工具直接放行（forum.cursor.com/t/hooks-ask-permission-broken-in-2-4-21 / t/hook-return-value-ask-has-no-practical-effect），ask 在真实环境形同 allow；真演「没弹 ask 窗口」即此根因（脚本侧字节级验证 stdout 为干净 `{"permission":"ask"}`，是 Cursor 吞掉）。**改回 `permission: deny` + user_message 逃生路径**（业务：发 `[PM]` / kill switch / 手动编辑；Level 1：先写 CHANGELOG / kill switch / 手动编辑）——逃生通道兜底，不逼死路。根因（真实 `text` 字段的落地时机/内容）尚未定位；有余力时应优先在 Cursor **设置 → Hooks** 面板核对 `afterAgentResponse` 的完整 payload，而不是继续靠猜测修。
2. 全部 hook 脚本都用 PowerShell 写（Windows 环境），且**手动验证过 UTF-8 BOM 编码**——本机控制台代码页是 GBK(936)，脚本文件若不带 BOM，PowerShell 5.1 会按系统代码页误读中文字符串导致语法错误（历史踩坑同 `check-pipeline-doc.ps1`）；新增/修改 hook 脚本后务必用 `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($true)))` 方式重存，并在脚本内显式设置 `[Console]::InputEncoding`/`[Console]::OutputEncoding` 为 UTF8。**已机械化（2026-08-03）**：`check-hooks-policy.ps1` 的 BOM 扫描段遍历 hooks/ + scripts/ 下 *.ps1 首 3 字节，非 `EF BB BF` → issue "UTF-8 BOM missing"，`validate-pipeline -Strict` 自动受益（本文件自身也在扫描范围，须保持 BOM）
3. 全部 hook `hooks.json` 均设 `failClosed: false`——脚本报错/超时时默认放行，不会因为 hook 本身出 bug 而误拦正在进行的工作
4. `test-hooks.ps1`（支柱 C）是**注入式**（构造小 JSON 直接喂给脚本），覆盖不到真实 Cursor 协议形态——第 1 条那次误判就是踩了这个盲区。**2026-08-03 已补协议级仿真**：`simulate-cursor-session.ps1` 按 Cursor 2.2 schema 构造完整会话序列 + 大 payload（≥80KB、中文/特殊字符），机械化验证打点链路与门禁流转（发布闸「真演证据」自动化，见发布检查清单）；但仿真仍无法覆盖 Cursor 侧「事件是否触发、`additional_context` 注入竞态」——首次发布或重大 hook 变更后，仍应到 Cursor **设置 → Hooks** 面板或 **Execution Log** 确认实际生效，不能只看 `test-hooks.ps1` / `simulate-cursor-session.ps1` 通过就当作已生效
5. **`sessionStart` 的 `additional_context`**：部分 Cursor 版本存在注入竞态（日志显示 merged 但 Agent 窗未吃到）。本仓以 `.ai-gates/hooks-log/hooks-policy-drift.json` 为权威侧写；Agent 若未见注入上下文，仍应以该文件 / `check-hooks-policy.ps1` 为准
6. **`postToolUse` 写后质量门为轻量提示、非硬拦**：`check-unity-compile.ps1` 只注入 `additional_context`（无 `permission` 语义，恒 `allow`），且不做 batchmode / 业务断言——真实 golden 验窗仍由 `run-unity-verify-golden.ps1` 验收驱动，职责分离；`test-hooks.ps1` A8 只能验证脚本内部逻辑（构造 stdin + `-EditorLogPath` fixture），验证不了 Cursor 真实 `postToolUse` 事件的 payload 与注入效果，修改后仍应在 Cursor **设置 → Hooks** 面板触发一次真实写入核验
7. **`.cursor/**` 分级轻门禁（2026-08-03）**：`pm-gate-check.ps1` 对 `.cursor/skills\|hooks\|scripts\|rules\|hooks.json` 设施写操作查会话内 CHANGELOG 流水（数据源 = `mark-changelog-write.ps1` 打点的 `changelog-writes.json`），无流水 → `permission: deny` + user_message 逃生提示（先写 CHANGELOG / kill switch / 手动编辑）；**打点文件缺失 = 初始状态（无任何会话有流水）→ 同样 `deny`**；打点损坏/时间戳不可解析时 `pm-gate-check` 仍 fallback `fail-open allow`，不逼死路；2026-08-03 由 ask 改 deny：Cursor 2.2+ hook `ask` 无效是官方确认 bug（真演「没弹 ask」验证）；Level 0（CHANGELOG 自身 / `hooks-log/**` 运行时 / 项目专属 `.cursor` 文件）与 Level 2 兜底（其余 `.cursor/**`：package-release.ps1、README.md、mcp.json、`_release_staging/` 产物等）全豁免；`test-hooks.ps1` A1.x 只能验证脚本内部逻辑，验证不了真实 `postToolUse` 触发与落盘可靠性，须一次真演（Cursor 会话写 `.cursor/skills/` 下非 CHANGELOG 文件确认出现 deny 拦截提示）记入证据

## Codex Hooks（机器强制层 · 2026-08-04 实测接线）

Codex 侧机械层是 **Cursor 七个 hook 的等价映射**：技能单源在中央库 `.ai-gates/`，
`hooks/codex/*.ps1` 随包分发；薄接线 `.ai-gates/codex/hooks.json` + `config.toml`
（git 跟踪，已随 7z 分发）经 `.codex/` 传送门暴露给 Codex。安装到新项目：解压 7z 到项目根
（得 `.ai-gates/`）→ 跑 `link-platform.ps1`（建 `.cursor/*` 与 `.codex` 传送门）→ 按源仓库
示例创建根级 `AGENTS.md`（入口路由，项目相关，不在包内）。**注意 `.codex/` 是传送门、
已被 gitignore**——不要直接往里塞文件；接线改 `.ai-gates/codex/`。

| Codex hook | Codex 事件 / matcher | 行为（等价映射自 Cursor 版） | 文件 |
| --- | --- | --- | --- |
| 接线漂移检测 | `SessionStart` | 校验 `.codex/hooks.json` / `.codex/config.toml` / `hooks/codex/*.ps1` 齐套 + BOM；漂移 → 写 `.ai-gates/hooks-log/codex-hooks-drift.json` + 注入 `additionalContext`（端到端实测可达模型） | `check-hooks-drift.ps1` |
| Git 高危命令确认 | `PreToolUse`（matcher `^Bash$`） | `tool_input.command` 命中 `git push --force`/`reset --hard`/`clean -f*`/`checkout --`/`branch -D` → `permissionDecision=deny` + reason（引擎呈现为 "Command blocked by PreToolUse hook: ..."，工具硬拦截） | `pre-bash-gate.ps1` |
| 交付物改动审计 | `PreToolUse`（matcher `^apply_patch$`） | 从 patch 文本提取路径 → `write-audit.log` 一行；恒 allow | `pre-apply-patch-gate.ps1` |
| PM 判定标记打点 | `Stop`（等价 Cursor `afterAgentResponse`） | `last_assistant_message` 命中 `[PM]` → 写 `pm-gate.json`（按 `session_id`） | `mark-pm-gate.ps1` |
| PM 门禁机械检查（支柱 D） | `PreToolUse`（matcher `^apply_patch$`） | 业务路径无新鲜（120 分钟）`[PM]`（按 `session_id` 查 `pm-gate.json`）→ deny + 逃生提示；`.cursor/**` 分级豁免与 Cursor 版完全一致（Level 0 全豁免 / Level 1 查 changelog-writes.json / Level 2 兜底）；kill switch / parse fail-open 保留 | `pre-apply-patch-gate.ps1` |
| 写后编译错误提示 | `PostToolUse`（matcher `^apply_patch$`） | 命中 `.cs`/`.lua` → 扫新鲜 Unity `Editor.log` 的 `error CS\d{4}` → 注入 `additionalContext`；恒 allow | `post-apply-patch-gate.ps1` |
| CHANGELOG 写打点 | `PostToolUse`（matcher `^apply_patch$`） | patch 命中 `CHANGELOG.md` → `changelog-writes.json`（按 `session_id`） | `post-apply-patch-gate.ps1` |

**合并入口（2026-08-06 · 性能优化，语义不变）**：同事件多门禁已合成单入口脚本——
`pre-bash-gate.ps1`（git-safety-check + bash-write-gate）、`pre-apply-patch-gate.ps1`
（audit-write + pm-gate-check）、`post-apply-patch-gate.ps1`（mark-changelog-write +
check-unity-compile）——单进程内依次执行原门禁脚本，stdin 预读共享；deny 短路语义与
分开挂载一致，进程 spawn 减半（apply_patch 从 4 次降到 2 次，Bash 从 2 次降到 1 次）。
原单门禁脚本保留（供测试与单独排查）。

**Codex 契约与 Cursor 的差异（2026-08-04 在 codex-cli 0.146.0-alpha.9.2 实测，勿凭习惯猜）**：

1. **PreToolUse 显式 `allow` 不受支持**——省略 `permissionDecision` 即 allow（显式
   `permissionDecision:"allow"` 会被引擎判 unsupported → hook Failed → fail-open 放行，日志难排查）；
   `ask` 不受支持；deny 必须带**非空 `permissionDecisionReason`**（该 reason 原样回显给 Agent）。
2. **写工具是 `apply_patch`**（非 Cursor 的 Write/StrReplace），目标路径在
   `tool_input.command` 的 patch 文本里（`*** Add|Update|Delete File:` / `*** Move to:`），
   脚本用正则提取；结构化 `file_path` 字段保留兼容分支。
3. **会话键是 `session_id`**（Cursor 用 `conversation_id`），`pm-gate.json` /
   `changelog-writes.json` 里两类键可共存互不冲突。
4. **`afterAgentResponse` 无等价事件** → 打点映射到 `Stop`（payload 含
   `last_assistant_message` / `session_id`）；与 Cursor 版同局限：只能证明"之前某轮完整
   回复出现过 [PM]"，不能证明"同一条回复先 [PM] 后写"。
5. **启用与信任**：`.codex/config.toml` 须含 `[features] hooks = true`（0.146 起正名
   `hooks`，`codex_hooks` 为废弃别名）；hooks 需信任才运行——桌面端首次会话提示批准，
   CLI 一次性验证用 `codex exec --enable hooks --dangerously-bypass-hook-trust`。
6. **门禁覆盖边界**：`apply_patch`（Codex 标准文件写入工具）；经 `Bash` 的写入（如
   `Set-Content`）不在 PreToolUse 门禁覆盖内（与 Cursor 版只覆盖 Write 工具同类）。
   **2026-08-05 实测补充**：Codex **桌面应用会话**对 `apply_patch` 钩子可能不触发（信任已批准
   `[projects."D:/Work/Chemical"]` = trusted 仍零打点）；**CLI 侧**（0.147.0-alpha.1.2，
   `--enable hooks --dangerously-bypass-hook-trust`）SessionStart/PreToolUse/PostToolUse 全链路
   触发并落盘（write-audit / pm-gate ALLOW|DENY / mark-changelog / drift OK）。桌面端机械强制按
   「模型自觉 + 逃生通道」降级：关键写操作后自查 `.ai-gates/hooks-log/`，或按需用 CLI 真演补证据。
7. **输出编码**：hook 脚本（含 `codex-hooks-common.ps1`）必须 UTF-8 BOM——无 BOM 时
   PowerShell 5.1 按 GBK 误读中文，`additionalContext` 会输出非法 UTF-8 导致 hook
   "Failed"（2026-08-04 实测踩坑）；`check-hooks-policy.ps1` BOM 扫描已扩展到
   `hooks/codex/`。

**验证（发布闸证据，2026-08-04）**：
- 注入式回归 `scripts/test-codex-hooks.ps1` 全绿（A1-A3 / B1 / C1-C9 / D1-D2 / E1-E2 /
  F1-F2 / G1，覆盖 deny/allow/分级豁免/kill switch/打点/漂移）。
- 真实 `codex exec` 端到端（D:\Work\Chemical 真实接线）：无标记 apply_patch 被拦截
  （`Command blocked by PreToolUse hook: PM gate deny ...`）；回复 `[PM]` 后 `Stop` 打点
  → resume 同会话写文件放行（`ALLOW fresh_pm_marker_age=0.4min`）；`git push --force`
  被 git-safety-check 拦截；`SessionStart` 漂移 hook 无漂移。
- 仿真/注入仍覆盖不了桌面端"事件是否触发 + 信任批准"，首次接 Codex 仍需真实会话核验一次。

## optional pre-commit（推荐 TL 默认安装 `-Strict`）

对 staged 的执行文档与回归索引做校验。**默认推荐 `-Strict`**——硬门禁（无 PM 判定不改交付物、回归索引双写一致等）若只停留在 CORE 文字约束，缺机器强制时容易被跳过；`-Strict` 把发现的问题变成 exit 1 直接阻断提交。另：**迁夹必须**跑 `migrate-pipeline-window.ps1`（禁手挪漏改链）；Strict 已接线 **Gate B**（`detect-empty -FailOnCandidates`）与 **Gate A**（变更集含 `Assets/LabSDK/Runtime/**/*.cs` 且唯一可改码声明源全部 `editable=no`；无声明源不拦）。薄 CI：`.github/workflows/pipeline-hygiene-gate.yml` 同调 `-Strict -BaseRef`（`base...HEAD`，勿靠空 cached）；缺 `.cursor/scripts` 门禁脚本 exit 2（本仓 `.gitignore` 含 `.cursor/` 时须 force-track 或约定 checkout，禁伪绿）。

```powershell
# 手动试跑
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pre-commit-pipeline-advisory.ps1 -Strict

# 安装到 .git/hooks/pre-commit（会覆盖已有 hook，请先备份）
@'
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pre-commit-pipeline-advisory.ps1 -Strict
exit $LASTEXITCODE
'@ | Set-Content -Encoding UTF8 .git/hooks/pre-commit
```

**团队协作摩擦大、或刚接入尚在适应期**：可退回 warn-only（仅提示不阻断），去掉 `-Strict` 即可：

```powershell
@'
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pre-commit-pipeline-advisory.ps1
exit $LASTEXITCODE
'@ | Set-Content -Encoding UTF8 .git/hooks/pre-commit
```

## 发布检查清单

- [ ] CHANGELOG 新条目
- [ ] `VERSION` 与 CHANGELOG 当前 LTS 一致；README/CORE/MAINTAINER/规则/校验/打包入口只指向或读取 VERSION
- [ ] 通用 Skill 无本项目硬编码（对照 [project-local-config.md](./references/project-local-config.md)）
- [ ] 运行 `validate-pipeline.ps1 -Strict`（须含 **hooks policy** / `check-hooks-policy.ps1`：MAINTAINER `deny`（Cursor 2.2+ ask 无效）+ 全 hook `failClosed:false` + `sessionStart` 漂移 hook 齐套 + **hooks/、hooks/codex/、scripts 下 *.ps1 全 UTF-8 BOM**；并跑通 `test-hooks.ps1`）
- [ ] 目视核对：`pm-gate-check` 缺标记为 `permission: deny` + user_message 逃生提示（2026-08-03 起，Cursor 2.2+ ask 无效）；解析异常 fail-open `allow`；含 `sessionStart` 在内全部 hook `failClosed: false`
- [ ] 目视核对（轻门禁）：`pm-gate-check` 对 `.cursor/skills|hooks|scripts|rules|hooks.json` 与根文档 `README/SKILLS/USER-GUIDE/METHODOLOGY`（2026-08-05 起 Level 1）无会话内 CHANGELOG 流水 → `deny`（逃生：先写 CHANGELOG / kill switch / 手动编辑）；CHANGELOG 自身 / `hooks-log/**` / 项目专属 `.cursor` 文件 Level 0 豁免；其余 `.cursor/**`（package-release.ps1、mcp.json、`_release_staging/` 产物等）兜底 `allow`；`postToolUse` 含 `mark-changelog-write` 条目（`failClosed:false`）
- [ ] 目视核对：PostToolUse 写后质量门（`check-unity-compile.ps1`，matcher `Write|StrReplace|EditNotebook`）在客户端勾选启用，写代码路径文件即触发
- [ ] 协议级真演：跑 `scripts/simulate-cursor-session.ps1` 全绿（大 payload ≥80KB 下打点链路不断 + 门禁随会话流转；2026-08-03 起发布闸「真演证据」自动化，替代人工开真实会话）；`scripts/pipeline-health.ps1` 无 CRIT 退化信号（数据闭环体检）
- [ ] Codex 版注入式回归：跑 `scripts/test-codex-hooks.ps1` 全绿（A-G 组：git-safety deny/allow、audit、pm-gate 分级豁免/kill switch/parse fail-open、[PM] 打点、CHANGELOG 打点、unity-compile 注入、接线漂移）
- [ ] Codex 真实会话真演证据（发布闸证据级，2026-08-04 已在本仓留档）：`codex exec`（`--enable hooks --dangerously-bypass-hook-trust`）下——无标记 apply_patch 被 `pm-gate-check` deny 拦截、回复 `[PM]` 后 `Stop` 打点、resume 同会话写文件放行、`git push --force` 被 `git-safety-check` deny；`.ai-gates/hooks-log/pm-gate-check.log` / `git-safety-check.log` / `mark-pm-gate.log` 有对应 DENY/ALLOW 行
- [ ] 传送门验收：`link-platform.ps1`（Windows Junction）幂等重跑 OK；`.cursor/skills|hooks|scripts|rules`、`.cursor/hooks.json`、`.codex`、`.trae/skills` 全部指向 `.ai-gates/`；`git status` 无 `.cursor/`、`.codex/`、`.trae/` 泄漏；`package-release.ps1` 打包成功且 7z 内含 `link-platform.*` + `codex/` 接线、不含 `MAINTAINER.md`
- [ ] 机制减负：CORE 翻车索引 ≤15 条且命中驱动（新增条目带近 90 天命中证据；超限最低命中降级回 anti-patterns 完整表）
- [ ] 打包：`package-release.ps1` 纳入 `CHANGELOG.md`、仍排除 `MAINTAINER.md`；公开仓/Release 建议挂 CHANGELOG
- [ ] 打包前 `validate-pipeline.ps1 -Strict` 全绿（`package-release` 默认强制，红 → 拒绝打包 `exit 1`；`-SkipValidate` 仅显式逃生，维护者签字级）
- [ ] 无 `QUICKSTART.md`、`project-manager/` 等 v2 残留；**若存在** `archive/` 目录，须含 `archive/README.md`「勿读」哨兵（当前仓库无 `archive/`，此项不适用）
- [ ] 跑 [skill-eval-checklist.md](./references/skill-eval-checklist.md) §A~D 剧本，Pass 率 ≥90%（否则先修 Skill 再 bump）
- [ ] 发布前有**真实 Cursor 会话** hook 链路真演证据（`.ai-gates/hooks-log/` 下真实 DENY/ALLOW 与打点落盘记录；2026-08-03 ask bug / 大 payload 解析失败两连教训——走读/假需求发现不了，走读记录 ≠ 发布闸证据）
