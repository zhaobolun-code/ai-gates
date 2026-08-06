# ai-gates

**AI 几秒就能改出一堆坏代码。这套东西不是又一个补全插件，而是一套在代码落地前强制把关的质量门禁。**

## 为什么值得下载（30 秒看懂）

- **真门禁，不是建议稿**：无本轮 PM 判定的写入、高危 git（push --force 等）会被 hooks 直接 deny（CLI 已实测），门禁真的拦。
- **失败过的地方自动加严**：回归热度 + 错题本命中 → 车道与审核档位自动升级（最低 Standard + L1.5），不靠人记。
- **3 分钟接入、跨平台**：Cursor / Codex / Trae 共用同一份 `.ai-gates/` 库；新用户贴一段提示词即可装好。
- **免费（MIT）、非银弹**：每步仍要你验收——省的是空转，不是人的判断。

## 定位：AI 编码的项目经理

ai-gates 不是又一个代码补全 / 质检插件：多数工具聚焦「代码本身」，它多管一层——整个开发流程的秩序（需求对齐 → 方案确认 → 执行 → 验收 → 复盘 → 止损），并把失败过的地方自动升档成规则。为什么这样设计、真实效果数据见 [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)。

## 快速开始（3 分钟）

**方式 A（推荐 · 零手动）**：把下面这段**整段**粘贴给任一能改文件的 Agent 窗口（Cursor Agent / Codex / Trae），Agent 会联网获取最新版、安装库、建好传送门并引导初始化：

```text
请把 ai-gates（AI 开发流水线技能包）从 https://github.com/zhaobolun-code/ai-gates 安装到当前项目，替代手动下载、解压和初始化：
- 取最新 release tag，克隆/下载到临时目录；校验根目录有 .ai-gates/ 且 skills/VERSION 是合法 x.y.z 并等于该 tag，不符就停下。
- 把临时 .ai-gates/ 的 skills/hooks/scripts/rules/codex、根文档、hooks.json、link-platform.*、LICENSE 复制到项目根 .ai-gates/；若已装过，先比对版本，仅更新时替换，保留 project-context、mcp.json、hooks-log、tmp、verify、regression-*、pipeline-* 等项目状态。
- 运行 link-platform.ps1（Unix 用 .sh）建传送门，写 install-info.json。
- 运行 pm-init.ps1 引导我填项目说明（技术栈、要小心的目录、必测场景），生成 .cursor/project-context.md。
- 完成后报告版本与传送门状态，并告诉我以后用「项目经理 + 需求」入口。
动手前先列计划等我确认；失败或网络问题不要改文件，给出手动下载方案。
```

**方式 B（一条命令 · 开发者/批量）**：在项目根打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/zhaobolun-code/ai-gates/main/scripts/install-ai-gates.ps1 | iex"
```

装完回到 Agent 窗口说 `项目经理 初始化` 填项目说明即可。**macOS/Linux**：暂无对应一键命令，用方式 A 提示词，或手动安装（下方方式 C）后运行 `bash .ai-gates/link-platform.sh`（无 git 时本命令会自动走 zip 下载）。

**方式 C（手动 · 备选）**：

1. 从本仓库 **[Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest)** 下载 **`ai_dev_v3.3.1.7z`**
2. **解压到目标项目根**（包内是 `.ai-gates/`，不要解进 `.cursor/`）
3. 在任一 AI 会话粘贴 **`项目经理 升级 ai-gates`**（=`PM upgrade ai-gates`），由 Agent 建好传送门（手动运行 `link-platform.ps1` / `.sh` 亦可，非必需）
4. 装好后，在任一能改文件的 AI 会话粘贴：`项目经理` + 需求

首次：`项目经理 初始化`，再填一份短项目说明（技术栈、要小心的目录、几条必测）。**这就是接入成本**——不是长期运维配置；详细三步见 [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) §第一次接入。体检：`项目经理 检查健康` / `PM doctor`。

**已装用户升级**：直接说 **`项目经理 升级 ai-gates`**——Agent 默认联网比对官方源最新版本与本地版本，**有新版才下载并替换**库内容（项目状态文件保留），随后校验/补齐传送门；网络不可用时回退本地已解压包流程。

若下载后 Windows 提示「无法运行，拒绝访问」：把报错原文粘贴给项目经理处理即可（Agent 会解除下载文件的网络标记并重新接线）。

上手（约 3 分钟）：[USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md)。  
这是什么、好不好用：[METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md)。  
版本迭代与变更历史：[CHANGELOG.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md)。

## 里面有什么（机制表）

这些不是功能清单，是护栏——每一条都对应真实改码里已经踩过的失败模式。**日常使用不必背这张表。**

| 机制 | 做什么 |
| --- | --- |
| **回归索引 + 热度** | 上次挂过的模块/文件再次改动 → 自动升档（最低 Standard + L1.5）；过去的失败自动抬高审核线，不靠人记 |
| **机器强制层** | 高危 git（push --force 等）与无本轮 PM 判定的写入被 hooks 直接 deny——不是提示词（CLI 已实测；桌面端有已知缺口，自查 hooks-log） |
| **三车道** | Express / Standard / Full 按任务自动判定（仍可用「完整流程」强制 Full）；过程中命中升级立即改判，不硬撑 |
| **止损链** | 同一手法反复失败 → 强制重定界 / A# 复议，不无限小补丁 |
| **切片先行** | 小改也先写切片（改什么 / 怎样算通过），一次一切片；超范围即停 |
| **审查门禁（分档）** | 车道要求时：方案审不过不能开工；CR 有 blocker 不算定版（Express 可跳过方案审）。审核随风险升档：热文件/回归 L1.5、跨模块 L2、Full L3、高危可对抗审 |
| **一轮确认** | 每个决策点一轮确认包（回「准」）；禁止静默开工改码/交审 |
| **Harness + Auto** | 会话内门禁约束 Agent；Standard/Full 在「准」之后可连跑实现↔CR，硬停/待验才打断（Express 不启用 Auto） |
| **恢复口令** | 乱改/没按流程 →「按 CORE 重来」一键回流程；改错代码 →「方案推翻」走确认后撤销 |
| **岗位** | 项目经理派策划 / 程序员 / CR / 文档；主对话尽量只当项目经理 |
| **子窗** | 实现与审核优先独立子会话，主对话保持项目经理——少堆成一条超长线程 |
| **切模型审核** | 审核可用比实现更强的模型（项目可配）——别实现和审核共用一个便宜模型糊弄 |
| **文档窗** | 一任务一文件夹（方案/物理口径/证据/已完成），按状态分类 |
| **物理口径** | 硬约束 + 负面约束 + 失败标准（Standard/Full 任务窗） |
| **黑板** | 本窗修挂日志：改了什么 → 为何失败 → 禁止再做 |
| **错题本** | 跨窗教训；自动起草，**须你回「准」**才写入项目主表 |
| **Delta Spec** | 每步跟踪 ADDED / MODIFIED / REMOVED，防无声扩大范围 |
| **验收 A#** | 每步可证伪验收条款。「日志出了关键词」≠ 修好了 |

## 平台

- **全平台可用（规则 / 技能 / 传送门）**：规则是纯 Markdown，其他 Agent 也可自行适配；传送门脚本**双份**——Windows 用 `link-platform.ps1`，macOS/Linux 用 `link-platform.sh`（Trae 另备 `link-trae-skills.sh`），都建 `.cursor/*`、`.codex`、`.trae/skills`、`.trae/rules`。
- **Cursor / Codex / Trae 共用同一份库**：跑一次 `link-platform` 即建好全部传送门。
- **Windows：完整支持**。机器强制 hooks（PM 写门禁 / 高危 git deny / Unity 编译提示，全部 `.ps1`）在 Codex CLI 0.146/0.147 已实测 deny 拦截；一键安装见「快速开始」方式 C。已知缺口：Codex 桌面应用对 `apply_patch` 钩子可能不触发（信任已批准仍零打点）——关键写操作后请自查 `.ai-gates/hooks-log/`。
- **macOS / Linux**：安装、规则、技能、传送门全支持；机器强制 hooks 暂为 PowerShell（`.ps1`）实现，需 pwsh 运行或暂以规则层生效（如实标注）。
- **Trae 为软层**：规则 + 技能传送门齐全，但无机器 hooks——门禁以规则生效，机器强制暂不覆盖。
- **单仓库边界**：门禁以当前仓库为界——跨仓库（多仓 / 微服务）改动不在机器强制覆盖内，跨仓部分仍靠团队约定。

## 前提

- Cursor Agent / Codex / Trae 任一能改文件的会话
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
- **3-minute setup, cross-platform.** One `.ai-gates/` library shared by Cursor / Codex / Trae; new users can paste one prompt to install.
- **Free (MIT), not a silver bullet.** Every step still needs your acceptance — it removes busywork, not human judgment.

### Positioning: the project manager for AI coding

ai-gates is not another autocomplete or quality-check plugin: most tools focus on the code itself, ai-gates adds one more layer — the order of the whole development process (requirement alignment → plan approval → execution → acceptance → retrospective → stop-loss), and places that already failed auto-escalate into smart rules. Why it is designed this way, plus real usage data: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md).

### Get it (3 minutes)

**Option A (recommended, zero manual steps):** paste the whole block below into any file-editing agent window (Cursor **Agent** / Codex / Trae):

```text
Install the ai-gates skill pack (AI development pipeline) into this project from https://github.com/zhaobolun-code/ai-gates, replacing manual download, extraction, and initialization:
- Take the latest release tag, clone/download it to a temp dir; validate that the root contains `.ai-gates/` and `skills/VERSION` is a valid x.y.z equal to that tag — otherwise stop.
- Copy `.ai-gates/` contents (skills/hooks/scripts/rules/codex, root docs, hooks.json, link-platform.*, LICENSE) into the project root `.ai-gates/`; if already installed, compare versions and replace only when newer, preserving project state (project-context, mcp.json, hooks-log, tmp, verify, regression-*, pipeline-* etc.).
- Run link-platform.ps1 (Unix: .sh) to create the portals; write install-info.json.
- Run pm-init.ps1 to walk me through the project note (stack, careful paths, must-test scenarios) and generate `.cursor/project-context.md`.
- Finally report the version and portal status, and tell me the entry phrase for future requests — `PM + request`.
Before doing anything, present the plan and wait for my confirmation; on any failure or network outage, do not modify files — explain and give the manual download path.
```

**Option B (one command · developers/scripting):** at the project root, open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/zhaobolun-code/ai-gates/main/scripts/install-ai-gates.ps1 | iex"
```

When it finishes, say `PM init` in an agent window to fill the project note. **macOS/Linux**: no one-command equivalent yet — use Option A (prompt) or manual install (Option C below, then `bash .ai-gates/link-platform.sh`); a git-less machine falls back to downloading the tag zip automatically.

**Option C (manual · fallback):**

1. Download **`ai_dev_v3.3.1.7z`** from this repo’s **[Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest)**.
2. Extract **at** the target project’s root — the archive contains `.ai-gates/` (do **not** unzip into `.cursor/`).
3. Paste **`PM upgrade ai-gates`** in any AI session (the agent runs `link-platform.ps1` / `.sh` for you; manual run is optional).
4. In any file-editing AI session (Cursor **Agent**, Codex desktop/CLI, Trae): `PM` + request.

First time on a project? Say `PM init`, then fill a short project note (stack, careful paths, a few must-test cases). Detailed first-time steps: USER-GUIDE. Health check? Say `PM doctor`.

**Already installed?** Say `PM upgrade ai-gates` — the agent compares the official GitHub source's latest tag with your installed version, downloads and replaces the library only when a newer version exists (project files are preserved), then re-checks/creates the portals. No manual download needed. If the network is unavailable, extract the new pack at the project root and say the same phrase — the agent falls back to rewiring the portals from the local pack.

If Windows refuses to run the downloaded script ("access denied"), paste the error back into the same AI session — the agent unblocks the downloaded files and re-wires it for you.

Quick start (3 min): [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md).  
What this is / isn’t: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md).  
Version history: [CHANGELOG.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md).

### What's inside

These are not feature checkboxes. They are guardrails—each one exists because that failure mode showed up in real development. **You do not need to memorize this table.**

| Mechanism | What it does |
| --- | --- |
| **Regression index + heat** | Modules/files that already failed are tracked; touching them again auto-escalates (minimum Standard + L1.5)—past failures raise the bar, not your memory |
| **Machine-enforced gates** | Dangerous git (e.g. `push --force`) and writes without a fresh PM go-ahead are denied by hooks, not just discouraged (verified on Codex CLI; desktop Codex has a known gap—self-check `.ai-gates/hooks-log/`) |
| **Three-lane routing** | Express / Standard / Full auto-picked from the task (you can still force Full); escalates mid-task if the scope grows beyond the lane |
| **Stop-loss chain** | Repeated same-approach fails → forced reassessment / A# reopen—not endless micro-patches |
| **Slice-first** | Even small edits start as a slice—what changes, what counts as passing; one slice at a time, over-scope stops |
| **Mandatory review, tiered** | Where the lane requires it: no plan-review pass → no coding; CR blocker → not “done” (Express may skip plan review). Tiers escalate with risk: L1.5 for modules with past failures, L2 cross-module, L3 Full, adversarial CR for high-risk |
| **Round confirmation** | One confirm package per decision (`approve`); no silent start of implement/CR |
| **Harness + Auto** | In-session gates constrain the agent; after `approve`, Standard/Full may run implement↔CR until hard-stop or await-verify (Express: no Auto) |
| **Recovery phrases** | A reset phrase snaps a derailed session back into process; a rollback phrase reverts code through a confirmed `git checkout` |
| **Roles** | PM dispatches planner / developer / CR / docs; main chat stays PM when possible |
| **Subagents** | Prefer isolated sub-sessions for implement/review so the main chat stays PM-only—not one mega-thread |
| **Model routing** | Reviews can use a stronger model than implementation (project-configurable)—not the same cheap model for both |
| **Windowed docs** | One task = one folder (plan / physical spec / evidence / done); status-classified |
| **Physical spec** | Hard constraints + negative constraints + failure criteria (Standard/Full windows) |
| **Blackboard** | Per-window repair log: what changed → why failed → do not repeat |
| **Lessons** | Cross-window error book; drafts auto, **your `approve`** required before the project table |
| **Delta Spec** | ADDED / MODIFIED / REMOVED tracked per step; no silent scope creep |
| **Acceptance (A#)** | Testable, falsifiable criteria per step. “Log keyword appeared” ≠ done |

### Platform

- **Cross-platform (rules / skills / portals)**: rules are plain Markdown, other agents can adapt them; portal scripts ship in pairs — `link-platform.ps1` on Windows, `link-platform.sh` on macOS/Linux (plus `link-trae-skills.sh` for Trae) — all create `.cursor/*`, `.codex`, `.trae/skills`, `.trae/rules`.
- **One `.ai-gates/` library for Cursor / Codex / Trae**; one `link-platform` run creates all the portals.
- **Windows: full support.** The machine-enforced hooks (PM write gate, high-risk git deny, Unity compile hints — all PowerShell) are verified on codex-cli 0.146/0.147; one-command install = Option C. Known gap: Codex **desktop** sessions may not fire the `apply_patch` hooks (zero hits even with trust approved) — after critical writes, check `.ai-gates/hooks-log/`.
- **macOS / Linux**: install, rules, skills, and portals fully supported; the machine hooks are currently PowerShell (`.ps1`) — run via pwsh or rely on the rule layer for now (stated honestly).
- **Trae runs soft-layer only** (rules + skills portals, no machine hooks) — the gates still apply as instructions there, but enforcement is not machine-backed.
- **Single-repo boundary**: gates are scoped to the current repository — cross-repo (multi-repo / microservices) changes are not covered by the machine layer; rely on team discipline there.

### Requirements

- Cursor **Agent**, Codex desktop/CLI, or Trae — any session that can edit files
- Supports **Windows / macOS / Linux** (rules and portals everywhere; machine hooks currently Windows-first)
- One-time `PM init` + short `project-context.md` / test list (the pack does **not** ship another team’s business windows or CHANGELOG)

### Daily use (you do not memorize the table above)

- Start with `PM` + need; confirm decisions with `approve`.
- The mechanism list is **guardrail documentation**, not a checklist you must learn before coding.
- The agent follows the gates; you accept / reject / retest.
- Blocked? The deny message itself carries escape steps; full quick-reference: USER-GUIDE (troubleshooting quick-ref section).

---

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
