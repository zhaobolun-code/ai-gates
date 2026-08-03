# ai-gates

**AI can ship bad code in seconds. This inserts real gates before you accept the change—not another autocomplete.**

A set of enforceable development gates for AI-assisted coding—read your project before edit, clear the lane’s review gates before you accept the change, verify before done, stop-and-reassess when stuck. Distributed as a Cursor skill pack; the rules themselves are plain Markdown.

---

## Get it

1. From this repo’s **Releases**, download **`ai_dev_v3.2.0.7z`**  
   ([latest release](https://github.com/zhaobolun-code/ai-gates/releases/latest)).
2. Extract **into** the target project’s `.cursor/` folder  
   (archive root is `skills/`, `scripts/`, … — do **not** unzip into a nested `.cursor/.cursor/`).
3. In Cursor **Agent** mode:

```
PM
[what you need / what's broken]
```

First time on a project? Say `PM init` (scaffolds `project-context`), then fill a short project note (stack, careful paths, a few must-test cases). That is the setup—not ongoing ops config.

Quick start (3 min): [skills/TEAM-GUIDE.md](skills/TEAM-GUIDE.md).  
What this is / isn’t: [skills/METHODOLOGY.md](skills/METHODOLOGY.md).

### Daily use (you do not memorize the table below)

- Start with `PM` + need; confirm decisions with `approve`.  
- The mechanism list is **guardrail documentation**, not a checklist you must learn before coding.  
- The agent follows the gates; you accept / reject / retest.

### Platform

- **Shipped for Cursor Agent** (file-edit mode). Cursor Hooks live under `.cursor/`.  
- Rules are plain Markdown—other agents can reuse them with adaptation; **other platforms are not officially packaged yet**.  
- Bundled scripts are primarily **Windows PowerShell** (`.ps1`).

### Requirements

- Cursor **Agent** mode  
- One-time `PM init` + short `project-context.md` / test list (the pack does **not** ship another team’s business windows or CHANGELOG)

### What's inside

These are not feature checkboxes. They are guardrails—each one exists because that failure mode showed up in real development. **You do not need to memorize this table to use the pack.**

| Mechanism | What it does |
| --- | --- |
| **Three-lane routing** | Express / Standard / Full auto-picked from the task (you can still force Full) |
| **Mandatory review** | Where the lane requires it: no plan-review pass → no coding; CR blocker → not “done” (Express may skip plan review) |
| **Round confirmation** | One confirm package per decision (`approve`); no silent start of implement/CR |
| **Harness + Auto** | In-session gates constrain the agent; after `approve`, Standard/Full may run implement↔CR until hard-stop or await-verify (Express: no Auto) |
| **Stop-loss chain** | Repeated same-approach fails → forced reassessment / A# reopen—not endless micro-patches |
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

The pack also validates itself: before each release, its own hooks are exercised by a protocol-level session simulator (large-payload regressions, including a real 81KB stdin failure), and a health report surfaces degraded gates—so the guardrails don't silently stop working.

## 中文

**AI 几秒就能改出一堆坏代码。这套东西在你点头接受之前插入真门禁——不是又一个补全插件。**

一套可执行的质量门禁，用于 AI 辅助开发——不看本项目不能改、按车道走方案/审查、CR 有 blocker 不能收口、反复改不好有止损链叫停换路（不是拦 `git commit`）。当前以 Cursor Skill 形式发行；规则本身是纯 Markdown。

1. 从本仓库 **[Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest)** 下载 **`ai_dev_v3.2.0.7z`**  
2. **解压进**目标项目的 `.cursor/`（包内直接是 `skills/` 等，不要解成 `.cursor/.cursor/`）  
3. Cursor **Agent** 模式里粘贴：`项目经理` + 需求  

首次：`项目经理 初始化`，再填一份短项目说明（技术栈、要小心的目录、几条必测）。**这就是接入成本**——不是长期运维配置。

上手（约 3 分钟）：[skills/TEAM-GUIDE.md](skills/TEAM-GUIDE.md)。  
预期与边界：[skills/METHODOLOGY.md](skills/METHODOLOGY.md)。

### 日常怎么用（不用背下面的表）

- 开口：`项目经理` + 需求；确认回「准」。  
- 机制表是**护栏说明**，不是开工前必背清单。  
- 门禁由助手执行；你负责确认、验收、回是否通过。

### 平台

- **当前正式发行面向 Cursor Agent**（可改文件）；Hooks 在 `.cursor/` 下。  
- 规则是 Markdown，其他 Agent **可自行适配**；**尚未提供其他平台的官方安装包**。  
- 附带脚本以 **Windows PowerShell**（`.ps1`）为主。

### 前提

- Cursor **Agent** 模式  
- 一次初始化 + 短 `project-context` / 测试清单（包**不含**别人的业务窗与 CHANGELOG）

### 里面有什么

这些不是功能清单，是护栏——每一条都对应真实改码里已经踩过的失败模式。**日常使用不必背这张表。**

| 机制 | 做什么 |
| --- | --- |
| **三车道** | Express / Standard / Full 按任务自动判定（仍可用「完整流程」强制 Full） |
| **审查门禁** | 车道要求时：方案审不过不能开工；CR 有 blocker 不算定版（Express 可跳过方案审） |
| **一轮确认** | 每个决策点一轮确认包（回「准」）；禁止静默开工改码/交审 |
| **Harness + Auto** | 会话内门禁约束 Agent；Standard/Full 在「准」之后可连跑实现↔CR，硬停/待验才打断（Express 不启用 Auto） |
| **止损链** | 同一手法反复失败 → 强制重定界 / A# 复议，不无限小补丁 |
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

这套包连自己也会被验证：每次发布前，hook 链路会跑一遍协议级会话仿真（大 payload 回归，含真实 81KB stdin 解析失败场景），并有健康度报告暴露「门禁形同虚设」这类退化信号——护栏不会悄悄失效。

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
