# ai-gates

**AI can ship bad code in seconds. This inserts real gates before you accept the change—not another autocomplete.**

A set of enforceable development gates for AI-assisted coding—read your project before edit, clear the lane's review gates before you accept the change, verify before done, stop-and-reassess when stuck.

**What's different here:**

- **Past failures raise the bar.** Modules that already broke are tracked; touching them again auto-escalates the lane and review tier (minimum Standard + L1.5)—not something you have to remember.
- **A machine gate, not just prompts.** Writes without a fresh PM go-ahead, and dangerous git commands, are denied by hooks (verified on Codex CLI), so the gates actually block.
- **Auto-routed lanes that re-judge mid-task.** Express / Standard / Full are picked from the task, and escalate on the spot if the scope grows beyond the lane.
- **A stop-loss chain.** Repeated same-approach failures trigger re-scoping and acceptance re-review—not endless micro-patches.

One `.ai-gates/` library is shared across Cursor / Codex / Trae through portals; the rules are plain Markdown, so other agents can adapt them too.

---

## Get it

1. From this repo’s **Releases**, download **`ai_dev_v3.3.0.7z`**
   ([latest release](https://github.com/zhaobolun-code/ai-gates/releases/latest)).
2. Extract **at** the target project’s root — the archive contains `.ai-gates/`
   (do **not** unzip into `.cursor/`).
3. Ask the project manager agent to wire it up — paste this in any AI session (Cursor / Codex / Trae):
   `项目经理 升级 ai-gates` (= `PM upgrade ai-gates`)
   (the agent runs `link-platform.ps1` / `.sh` for you; manual run is optional).
4. In any file-editing AI session (Cursor **Agent**, Codex desktop/CLI, Trae):

```
PM
[what you need / what's broken]
```

First time on a project? Say `PM init` (scaffolds `project-context`), then fill a short project note (stack, careful paths, a few must-test cases). That is the setup—not ongoing ops config. Upgrade the pack? Say `项目经理 升级 ai-gates` / `PM upgrade ai-gates`. Health check? Say `项目经理 检查健康` / `PM doctor`.

Upgrading from an older pack (extracted into `.cursor/`)? Extract the new pack at the project root, then paste `项目经理 升级 ai-gates` (`PM upgrade ai-gates`) in your AI session — the agent removes stale `.cursor` skill dirs, re-wires the portals and verifies. Project files (`project-context.md` etc.) are preserved, no re-init needed; the session-start hook also reminds you if portals are missing or stale.
If Windows refuses to run the downloaded script ("access denied"), just paste the error back into the same AI session — the agent unblocks the downloaded files and re-wires it for you.

Quick start (3 min): [USER-GUIDE.md](USER-GUIDE.md).  
What this is / isn’t: [METHODOLOGY.md](METHODOLOGY.md).  

### Daily use (you do not memorize the table below)

- Start with `PM` + need; confirm decisions with `approve`.
- The mechanism list is **guardrail documentation**, not a checklist you must learn before coding.
- The agent follows the gates; you accept / reject / retest.

### Platform

- **Cursor / Codex / Trae share one `.ai-gates/` library**; one `link-platform` run creates the portals (`.cursor/*`, `.codex`, `.trae/skills`).
- Cursor Hooks live under `.cursor/hooks/` (portal). **Codex is wired through its official hooks mechanism**: `.ai-gates/codex/hooks.json` + `config.toml` → `.ai-gates/hooks/codex/*.ps1` (deny actually blocks; verified on codex-cli 0.146.0-alpha.9.2 / 0.147.0-alpha.1.2). Known gap: Codex **desktop** sessions may not fire the `apply_patch` hooks (zero hits even with trust approved) — after critical writes, check `.ai-gates/hooks-log/`.
- **Machine layer, not prompt-only**: hooks deny high-risk git and unapproved writes, flag Unity compile errors, and re-check portal wiring at session start.
- **Trae runs soft-layer only** (rules + skills portals, no machine hooks) — the gates still apply as instructions there, but enforcement is not machine-backed.
- Rules are plain Markdown—other agents can reuse them with adaptation. Bundled scripts are primarily **Windows PowerShell** (`.ps1`).

### Requirements

- Cursor **Agent**, Codex desktop/CLI, or Trae — any session that can edit files
- One-time `PM init` + short `project-context.md` / test list (the pack does **not** ship another team’s business windows or CHANGELOG)

### What's inside

These are not feature checkboxes. They are guardrails—each one exists because that failure mode showed up in real development. **You do not need to memorize this table to use the pack.**

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
| **Recovery phrases** | `按 CORE 重来` snaps a derailed session back into process; `方案推翻` rolls back code via a confirmed `git checkout` |
| **Roles** | PM dispatches planner / developer / CR / docs; main chat stays PM when possible |
| **Subagents** | Prefer isolated sub-sessions for implement/review so the main chat stays PM-only—not one mega-thread |
| **Model routing** | Reviews can use a stronger model than implementation (project-configurable)—not the same cheap model for both |
| **Windowed docs** | One task = one folder (plan / physical spec / evidence / done); status-classified |
| **Physical spec** | Hard constraints + negative constraints + failure criteria (Standard/Full windows) |
| **Blackboard** | Per-window repair log: what changed → why failed → do not repeat |
| **Lessons** | Cross-window error book; drafts auto, **your `approve`** required before the project table |
| **Delta Spec** | ADDED / MODIFIED / REMOVED tracked per step; no silent scope creep |
| **Acceptance (A#)** | Testable, falsifiable criteria per step. “Log keyword appeared” ≠ done |

---

## 中文

**AI 几秒就能改出一堆坏代码。这套东西在你点头接受之前插入真门禁——不是又一个补全插件。**

一套可执行的质量门禁，用于 AI 辅助开发——不看本项目不能改、按车道走方案/审查、CR 有 blocker 不能收口、反复改不好有止损链叫停换路（不是拦 `git commit`）。

**和别家不一样的地方：**

- **失败过的地方会自动加严。** 挂过的模块/文件被跟踪，再次改动 → 车道与审核档位自动升级（最低 Standard + L1.5），不靠人记。
- **真机器门禁，不是提示词。** 无本轮 PM 判定的写入、高危 git 命令会被 hooks 直接 deny（CLI 已实测），门禁真的拦。
- **车道自动判定，过程中还会改判。** Express / Standard / Full 按任务自动选，超范围当场升级，不硬撑。
- **止损链闭环。** 同一手法反复失败 → 强制重定界 / 验收口径复议，不无限小补丁。

Cursor / Codex / Trae 经传送门共用同一份 `.ai-gates/` 中央库；规则是纯 Markdown，其他 Agent 也可适配。

1. 从本仓库 **[Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest)** 下载 **`ai_dev_v3.3.0.7z`**
2. **解压到目标项目根**（包内是 `.ai-gates/`，不要解进 `.cursor/`）
3. 在任一 AI 会话粘贴 **`项目经理 升级 ai-gates`**（=`PM upgrade ai-gates`），由 Agent 建好传送门（手动运行
   `link-platform.ps1` / `.sh` 亦可，非必需）
4. 在任一能改文件的 AI 会话（Cursor Agent / Codex / Trae）粘贴：`项目经理` + 需求

首次：`项目经理 初始化`，再填一份短项目说明（技术栈、要小心的目录、几条必测）。**这就是接入成本**——不是长期运维配置。升级包：`项目经理 升级 ai-gates` / `PM upgrade ai-gates`；体检：`项目经理 检查健康` / `PM doctor`。

旧版用户升级（此前解压进 `.cursor/`）：解压新包到项目根后，在 Agent 窗口粘贴 **`项目经理 升级 ai-gates`**（=`PM upgrade ai-gates`）即可——Agent 会清理旧 `.cursor` 技能目录并重建传送门；`project-context.md` 等项目文件保留，无需重新初始化；传送门缺失/残留会由会话启动检查自动提示。
若下载后 Windows 提示「无法运行，拒绝访问」：把报错原文粘贴给项目经理处理即可（Agent 会解除下载文件的网络标记并重新接线）。

上手（约 3 分钟）：[USER-GUIDE.md](USER-GUIDE.md)。  
预期与边界：[METHODOLOGY.md](METHODOLOGY.md)。  

### 日常怎么用（不用背下面的表）

- 开口：`项目经理` + 需求；确认回「准」。
- 机制表是**护栏说明**，不是开工前必背清单。
- 门禁由助手执行；你负责确认、验收、回是否通过。

### 平台

- **Cursor / Codex / Trae 共用同一份库**：跑一次 `link-platform` 即建好 `.cursor/*`、`.codex`、`.trae/skills` 传送门。
- Cursor Hooks 在 `.cursor/hooks/`（传送门）；**Codex 经官方 hooks 机制接线**（`.ai-gates/codex/hooks.json` + `config.toml` → `.ai-gates/hooks/codex/*.ps1`；codex-cli 0.146/0.147 已实测 deny 拦截）。已知缺口：**Codex 桌面应用对 `apply_patch` 钩子可能不触发**（信任已批准仍零打点）——关键写操作后请自查 `.ai-gates/hooks-log/`。
- **机器强制层，不是提示词**：高危 git / 无 PM 判定写入直接 deny；Unity 编译错误提示；会话启动自动体检传送门漂移。
- **Trae 为软层**：规则 + 技能传送门齐全，但无机器 hooks——门禁以规则生效，机器强制暂不覆盖。
- 规则是纯 Markdown，其他 Agent 也可自行适配。附带脚本以 **Windows PowerShell**（`.ps1`）为主。

### 前提

- Cursor Agent / Codex / Trae 任一能改文件的会话
- 一次初始化 + 短 `project-context` / 测试清单（包**不含**别人的业务窗与 CHANGELOG）

### 里面有什么

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

---

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
