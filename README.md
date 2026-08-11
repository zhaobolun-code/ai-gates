# ai-gates

**AI 几秒就能改出一堆坏代码。这套东西不是又一个补全插件，而是一套在代码落地前强制把关的质量门禁。**

## 为什么值得下载（30 秒看懂）

- **真门禁，不是建议稿**：无本轮 PM 判定的写入、高危 git（push --force 等）会被 hooks 直接 deny（CLI 已实测），门禁真的拦。
- **失败过的地方自动加严**：回归热度 + 错题本命中 → 车道与审核档位自动升级（最低 Standard + L1.5），不靠人记。
- **3 分钟接入、跨平台**：Cursor / Codex / Trae / Claude Code 共用同一份 `.ai-gates/` 库；新用户贴一段提示词即可装好。
- **免费（MIT）、非银弹**：每步仍要你验收——省的是空转，不是人的判断。

## 定位：AI 编码的项目经理

ai-gates 不是又一个代码补全 / 质检插件：多数工具聚焦「代码本身」，它多管一层——整个开发流程的秩序（需求对齐 → 方案确认 → 执行 → 验收 → 复盘 → 止损），并把失败过的地方自动升档成规则。为什么这样设计、真实效果数据见 [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)。

## 快速开始（3 分钟）

**方式 A（推荐 · 零手动）**：把下面这段**整段**粘贴给任一能改文件的 Agent 窗口（Cursor Agent / Codex / Trae / Claude Code），Agent 会联网获取最新版、安装库、建好传送门并引导初始化：

```text
请把 ai-gates（AI 开发流水线技能包）从 https://github.com/zhaobolun-code/ai-gates 安装到当前项目，替代手动下载、解压和初始化：
- 取最新 release tag，克隆/下载到临时目录；校验根目录有 .ai-gates/ 且 skills/VERSION 是合法 x.y.z 并等于该 tag，不符就停下。
- 把临时 .ai-gates/ 的 skills/hooks/scripts/rules/codex、根文档、hooks.json、link-platform.*、LICENSE 复制到项目根 .ai-gates/；若已装过，先比对版本，仅更新时替换，保留 project-context、mcp.json、hooks-log、tmp、verify、regression-*、pipeline-* 等项目状态。
- 运行 link-platform.ps1（Unix 用 .sh）建传送门，写 install-info.json。
- 运行 pm-init.ps1 引导我填项目说明（技术栈、要小心的目录、必测场景），生成 .cursor/project-context.md。
- 完成后报告版本与传送门状态，并告诉我以后用「项目经理 + 需求」入口。
动手前先列计划等我确认；失败或网络问题不要改文件，给出手动下载方案。
```

**接入成本**：填一份短项目说明（技术栈、要小心的目录、几条必测）——不是长期运维配置；详细三步见 [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §第一次接入。体检：`项目经理 检查健康` / `PM doctor`。

**其他安装与维护**（开发者一条命令 / 手动 7z / 已装升级 / 下载报错处理）→ [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §怎么安装、更新、查版本；被门禁拦了 → [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §被拦了怎么办（速查）。

上手（约 3 分钟）：[USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md)。  
这是什么、好不好用：[METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)。  
版本迭代与变更历史（当前 v4.0.0 · 四车道重构）：[CHANGELOG.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md)。

## 工作流：一个需求怎么走完

需求进来只有一条主线，车道只决定每步的粗细：

**需求 → `[PM]` 判定车道 → 切片（改什么 / 怎样算通过）→ 一轮确认（回「准」）→ 实现 → 隔离代码审查 → 验收 → 复盘（失败入错题本）→ 收尾**

| 车道 | 流程中的样子 |
| --- | --- |
| **Express**（一行注释/文案/常量） | 一句话切片 → 确认 → 改 → 一行自检；不派独立 CR |
| **Direct**（有行为变化的小改） | 对话内 A#/切片（不落盘）→ 确认 → 改 → 隔离 CR |
| **Standard**（跨模块 / API / 说不清） | 先写 plan-lite 方案 → 方案审 → 确认 → 改 → 隔离 CR |
| **Full**（止损链 / 热度大改 / 「完整流程」） | 执行文档 → 方案审 → 确认 → 改 → 双轮升模型审核 |

每步都要验收——A# 事先写清「怎样算通过」，以你亲眼所见为准。过程中命中升级（改动超范围、碰热度、跨模块）立即改判车道，不硬撑。

## 方法论：为什么这样设计

它不提供编码技巧，也不替你判断业务——它保证流程秩序：每一轮改动有据可查、可停可撤、做完能收尾。四个核心设计（深挖见 [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)）：

1. **管流程，不替写码**：多数工具聚焦代码本身（补全/审查/扫描）；ai-gates 多管一层——需求对齐 → 方案确认 → 执行 → 验收 → 复盘 → 止损，串成可重复、可度量的闭环
2. **失败驱动升档**：失败热度自动把过程数据变成规则——同一手法反复失败就停、换思路、记下此路不通（止损链），不做无限小补丁；不靠人记
3. **一轮确认防静默**：回「准」= 理解 + 方案 + 开工一次确认，不反复问「你理解了吗」；禁止静默开工/静默交审——原因不只留在聊天里，下一轮按旧判断改
4. **可停可撤、做完能收尾**：每个需求一个文件夹，结束时必须离开「进行中」；验收不过先看上一轮有用进展，再决定保留或撤掉——不是装上就自动变强的万能药

## 里面有什么（机制表）

这些不是功能清单，是护栏——每一条都对应真实改码里已经踩过的失败模式。**日常使用不必背这张表。**

| 机制 | 做什么 |
| --- | --- |
| **回归索引 + 热度** | 上次挂过的模块/文件再次改动 → 自动升档（最低 Standard + L1.5；命中热度取较高档：方案审 L3 / 双轮 CR）；过去的失败自动抬高审核线，不靠人记 |
| **机器强制层** | 高危 git（push --force 等）与无本轮 PM 判定的写入被 hooks 直接 deny——不是提示词（Codex CLI 与 Claude Code 已实测；Codex 桌面有已知缺口，自查 hooks-log） |
| **四车道** | Express / Direct / Standard / Full 按任务自动判定（Direct 直通不落盘；仍可用「完整流程」强制 Full）；过程中命中升级立即改判，不硬撑 |
| **止损链** | 同一手法反复失败 → 强制重定界 / A# 复议，不无限小补丁 |
| **切片先行** | 小改也先写切片（改什么 / 怎样算通过），一次一切片；超范围即停 |
| **审查门禁（分档）** | 车道要求时：方案审不过不能开工；CR 有 blocker 不算定版（Express/Direct 可跳过方案审，Direct 须隔离 CR）。审核随风险升档：回归模块 L1.5、跨模块 L2、Full L3、热度命中方案审 L3 / 双轮 CR、高危可对抗审 |
| **一轮确认** | 每个决策点一轮确认包（回「准」）；禁止静默开工改码/交审 |
| **Harness + Auto** | 会话内门禁约束 Agent；Standard/Full 在「准」之后可连跑实现↔CR，硬停/待验才打断（Express/Direct 不启用 Auto） |
| **恢复口令** | 乱改/没按流程 →「按 CORE 重来」一键回流程；改错代码 →「方案推翻」走确认后撤销 |
| **岗位** | 项目经理派策划 / 程序员 / CR / 文档；主对话尽量只当项目经理 |
| **子窗** | 实现与审核优先独立子会话，主对话保持项目经理——少堆成一条超长线程 |
| **切模型审核** | 审核可用比实现更强的模型（项目可配）——别实现和审核共用一个便宜模型糊弄 |
| **文档窗** | 一任务一文件夹（方案/物理口径/证据/已完成），按状态分类 |
| **物理口径** | 硬约束 + 负面约束 + 失败标准（Standard/Full 任务窗） |
| **黑板** | 本窗修挂日志：改了什么 → 为何失败 → 禁止再做 |
| **错题本** | 跨窗教训；自动起草，**须你回「准」**才写入项目主表 |
| **Delta Spec** | 每步跟踪 ADDED / MODIFIED / REMOVED，防无声扩大范围 |
| **验收 A#** | 每步可证伪验收条款。「日志出了关键词」≠ 修好了。命中回归模块时自动跑冒烟 + 归集日志/截图/测试报告入证据——自动验证 ≠ 手测签收 |

## 平台

- **全平台可用（规则 / 技能 / 传送门）**：规则是纯 Markdown，其他 Agent 也可自行适配；传送门脚本**双份**——Windows 用 `link-platform.ps1`，macOS/Linux 用 `link-platform.sh`（Trae 另备 `link-trae-skills.sh`），都建 `.cursor/*`、`.codex`、`.claude`、`.trae/skills`、`.trae/rules`。
- **Cursor / Codex / Trae / Claude Code 共用同一份库**：跑一次 `link-platform` 即建好全部传送门。
- **Windows：完整支持**。机器强制 hooks（PM 写门禁 / 高危 git deny / Unity 编译提示，全部 `.ps1`）在 Codex CLI 0.146/0.147 与 Claude Code（2026-08-10 全链路真机确证）已实测 deny 拦截；一键安装见「快速开始」。已知缺口：Codex 桌面应用对 `apply_patch` 钩子可能不触发（信任已批准仍零打点）——关键写操作后请自查 `.ai-gates/hooks-log/`。
- **macOS / Linux**：安装、规则、技能、传送门全支持；机器强制 hooks 暂为 PowerShell（`.ps1`）实现，需 pwsh 运行或暂以规则层生效（如实标注）。
- **Trae 为软层**：规则 + 技能传送门齐全，但无机器 hooks——门禁以规则生效，机器强制暂不覆盖。
- **单仓库边界**：门禁以当前仓库为界——跨仓库（多仓 / 微服务）改动不在机器强制覆盖内，跨仓部分仍靠团队约定。

## 前提

- Cursor Agent / Codex / Trae / Claude Code 任一能改文件的会话
- 支持 **Windows / macOS / Linux**（规则与传送门全平台；机器强制 hooks 目前以 Windows 为主）
- 一次初始化 + 短 `project-context` / 测试清单（包**不含**别人的业务窗与 CHANGELOG）

## 日常怎么用（不用背机制表）

- 开口：`项目经理` + 需求；确认回「准」。
- 机制表是**护栏说明**，不是开工前必背清单。
- 门禁由助手执行；你负责确认、验收、回是否通过。
- 被拦了？deny 提示自带逃生路径；完整速查见 [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §被拦了怎么办。

---

## English

**AI can ship bad code in seconds. This is not another autocomplete—it is an enforceable gate system that checks every change before you accept it.**

### Why download it (30-second read)

- **Real gates, not prompt suggestions.** Writes without a fresh PM go-ahead, and dangerous git commands (e.g. `push --force`), are denied by hooks (verified on Codex CLI).
- **Past failures raise the bar.** Modules that already broke are tracked; touching them again auto-escalates the lane and review tier (minimum Standard + L1.5).
- **3-minute setup, cross-platform.** One `.ai-gates/` library shared by Cursor / Codex / Trae / Claude Code; new users can paste one prompt to install.
- **Free (MIT), not a silver bullet.** Every step still needs your acceptance — it removes busywork, not human judgment.

### Positioning: the project manager for AI coding

ai-gates is not another autocomplete or quality-check plugin: most tools focus on the code itself, ai-gates adds one more layer — the order of the whole development process (requirement alignment → plan approval → execution → acceptance → retrospective → stop-loss), and places that already failed auto-escalate into smart rules. Why it is designed this way, plus real usage data: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md).

### Get it (3 minutes)

**Option A (recommended, zero manual steps):** paste the whole block below into any file-editing agent window (Cursor **Agent** / Codex / Trae / Claude Code):

```text
Install the ai-gates skill pack (AI development pipeline) into this project from https://github.com/zhaobolun-code/ai-gates, replacing manual download, extraction, and initialization:
- Take the latest release tag, clone/download it to a temp dir; validate that the root contains `.ai-gates/` and `skills/VERSION` is a valid x.y.z equal to that tag — otherwise stop.
- Copy `.ai-gates/` contents (skills/hooks/scripts/rules/codex, root docs, hooks.json, link-platform.*, LICENSE) into the project root `.ai-gates/`; if already installed, compare versions and replace only when newer, preserving project state (project-context, mcp.json, hooks-log, tmp, verify, regression-*, pipeline-* etc.).
- Run link-platform.ps1 (Unix: .sh) to create the portals; write install-info.json.
- Run pm-init.ps1 to walk me through the project note (stack, careful paths, must-test scenarios) and generate `.cursor/project-context.md`.
- Finally report the version and portal status, and tell me the entry phrase for future requests — `PM + request`.
Before doing anything, present the plan and wait for my confirmation; on any failure or network outage, do not modify files — explain and give the manual download path.
```

**The whole setup cost**: a short project note (stack, careful paths, a few must-test cases) — not an ongoing maintenance config; detailed first-time steps: [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §第一次接入. Health check? Say `PM doctor`.

**Other install & maintenance** (one-command install, manual 7z, upgrade, "access denied" download errors) → [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §怎么安装、更新、查版本; blocked by a gate? → USER-GUIDE §被拦了怎么办（速查）.

Quick start (3 min): [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md).  
What this is / isn’t: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md).  
Version history (current v4.0.0 · four-lane): [CHANGELOG.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md).

### Workflow: how one request goes through

Every request follows one main line; the lane only decides how heavy each step is:

**Request → `[PM]` judges the lane → slice (what changes / what counts as done) → one-round confirmation (`approve`) → implement → isolated code review → acceptance → retrospective (failures go to the lessons book) → close-out**

| Lane | Shape in the workflow |
| --- | --- |
| **Express** (one-line comment/text/constant) | one-sentence slice → confirm → edit → one-line self-check; no isolated CR |
| **Direct** (small change with behavior change) | in-chat A#/slice (no written window) → confirm → edit → isolated CR |
| **Standard** (cross-module / API / unclear) | plan-lite first → plan review → confirm → edit → isolated CR |
| **Full** (stop-loss / heat big change / "full process") | execution doc → plan review → confirm → edit → two-round escalated-model review |

Every step needs acceptance — A# states "what counts as done" up front, judged by what you actually see. If scope grows mid-task (over-scope, heat hit, cross-module), the lane re-judges immediately — no forcing through.

### Methodology: why it is designed this way

It offers no coding tricks and does not judge your business — it enforces process order: every round of changes is traceable, stoppable/reversible, and finishes with a close-out. Four core design choices (deep dive: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)):

1. **Manage process, not code for you**: most tools focus on the code itself (autocomplete/review/scan); ai-gates adds one more layer — requirement alignment → plan confirmation → execution → acceptance → retrospective → stop-loss, as a repeatable, measurable loop
2. **Failures raise the bar**: failure heat auto-converts process data into rules — the same approach failing repeatedly stops, switches path, and records the dead end (stop-loss chain), no endless micro-patches; not relying on memory
3. **One-round confirmation, no silent moves**: one `approve` = understanding + plan + go in a single confirmation, no repeated "did you understand?" loops; no silent start of implementation/review — reasons do not stay only in chat to be re-guessed next round
4. **Stoppable, reversible, closeable**: one folder per request; it must leave "in progress" when done; failed acceptance first reuses any useful progress from the last round before deciding keep/revert — not a magic pill that makes AI strong on install

### What's inside

These are not feature checkboxes. They are guardrails—each one exists because that failure mode showed up in real development. **You do not need to memorize this table.**

| Mechanism | What it does |
| --- | --- |
| **Regression index + heat** | Modules/files that already failed are tracked; touching them again auto-escalates (minimum Standard + L1.5; heat hit takes the higher tier: L3 plan review / double CR)—past failures raise the bar, not your memory |
| **Machine-enforced gates** | Dangerous git (e.g. `push --force`) and writes without a fresh PM go-ahead are denied by hooks, not just discouraged (verified on Codex CLI and Claude Code; desktop Codex has a known gap—self-check `.ai-gates/hooks-log/`) |
| **Four-lane routing** | Express / Direct / Standard / Full auto-picked from the task (Direct: straight through, no written plan window; you can still force Full); escalates mid-task if the scope grows beyond the lane |
| **Stop-loss chain** | Repeated same-approach fails → forced reassessment / A# reopen—not endless micro-patches |
| **Slice-first** | Even small edits start as a slice—what changes, what counts as passing; one slice at a time, over-scope stops |
| **Mandatory review, tiered** | Where the lane requires it: no plan-review pass → no coding; CR blocker → not “done” (Express/Direct may skip plan review; Direct still requires isolated CR). Tiers escalate with risk: L1.5 for modules with past failures, L2 cross-module, Full L3, heat hit → L3 plan review / double CR, adversarial CR for high-risk |
| **Round confirmation** | One confirm package per decision (`approve`); no silent start of implement/CR |
| **Harness + Auto** | In-session gates constrain the agent; after `approve`, Standard/Full may run implement↔CR until hard-stop or await-verify (Express/Direct: no Auto) |
| **Recovery phrases** | A reset phrase snaps a derailed session back into process; a rollback phrase reverts code through a confirmed `git checkout` |
| **Roles** | PM dispatches planner / developer / CR / docs; main chat stays PM when possible |
| **Subagents** | Prefer isolated sub-sessions for implement/review so the main chat stays PM-only—not one mega-thread |
| **Model routing** | Reviews can use a stronger model than implementation (project-configurable)—not the same cheap model for both |
| **Windowed docs** | One task = one folder (plan / physical spec / evidence / done); status-classified |
| **Physical spec** | Hard constraints + negative constraints + failure criteria (Standard/Full windows) |
| **Blackboard** | Per-window repair log: what changed → why failed → do not repeat |
| **Lessons** | Cross-window error book; drafts auto, **your `approve`** required before the project table |
| **Delta Spec** | ADDED / MODIFIED / REMOVED tracked per step; no silent scope creep |
| **Acceptance (A#)** | Testable, falsifiable criteria per step. “Log keyword appeared” ≠ done. Hot-path regression modules auto-run a smoke check and collect logs/screenshots/test reports as evidence — auto-verification ≠ manual acceptance |

### Platform

- **Cross-platform (rules / skills / portals)**: rules are plain Markdown, other agents can adapt them; portal scripts ship in pairs — `link-platform.ps1` on Windows, `link-platform.sh` on macOS/Linux (plus `link-trae-skills.sh` for Trae) — all create `.cursor/*`, `.codex`, `.claude`, `.trae/skills`, `.trae/rules`.
- **One `.ai-gates/` library for Cursor / Codex / Trae / Claude Code**; one `link-platform` run creates all the portals.
- **Windows: full support.** The machine-enforced hooks (PM write gate, high-risk git deny, Unity compile hints — all PowerShell) are verified on codex-cli 0.146/0.147 and Claude Code (end-to-end machine-verified 2026-08-10); one-command install = Quick Start. Known gap: Codex **desktop** sessions may not fire the `apply_patch` hooks (zero hits even with trust approved) — after critical writes, check `.ai-gates/hooks-log/`.
- **macOS / Linux**: install, rules, skills, and portals fully supported; the machine hooks are currently PowerShell (`.ps1`) — run via pwsh or rely on the rule layer for now (stated honestly).
- **Trae runs soft-layer only** (rules + skills portals, no machine hooks) — the gates still apply as instructions there, but enforcement is not machine-backed.
- **Single-repo boundary**: gates are scoped to the current repository — cross-repo (multi-repo / microservices) changes are not covered by the machine layer; rely on team discipline there.

### Requirements

- Cursor **Agent**, Codex desktop/CLI, Trae, or Claude Code — any session that can edit files
- Supports **Windows / macOS / Linux** (rules and portals everywhere; machine hooks currently Windows-first)
- One-time `PM init` + short `project-context.md` / test list (the pack does **not** ship another team’s business windows or CHANGELOG)

### Daily use (you do not memorize the table above)

- Start with `PM` + need; confirm decisions with `approve`.
- The mechanism list is **guardrail documentation**, not a checklist you must learn before coding.
- The agent follows the gates; you accept / reject / retest.
- Blocked? The deny message itself carries escape steps; full quick-reference: USER-GUIDE (troubleshooting quick-ref section).

---

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
