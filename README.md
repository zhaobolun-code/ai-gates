# ai-gates

**AI can ship bad code in seconds. This inserts real gates before you accept the change—not another autocomplete.**

A set of enforceable development gates for AI-assisted coding—read your project before edit, clear the lane’s review gates before you accept the change, verify before done, stop-and-reassess when stuck. Distributed as a Cursor skill pack; the rules themselves are plain Markdown.

---

## Get it

1. From this repo’s **Releases**, download **`ai_dev_v3.2.0.7z`**
   (create a release first; then you can pin
   `https://github.com/zhaobolun-code/ai-gates/releases/latest`).
2. Extract **into** the target project’s `.cursor/` folder
   (archive root is `skills/`, `scripts/`, … — do **not** unzip into a nested `.cursor/.cursor/`).
3. In Cursor **Agent** mode:

```
PM
[what you need / what's broken]
```

First time on a project? Say `PM init` (scaffolds `project-context`).

Quick start (3 min): [skills/TEAM-GUIDE.md](skills/TEAM-GUIDE.md).  
What this is / isn’t, and usage notes: [skills/METHODOLOGY.md](skills/METHODOLOGY.md).

### Requirements

- Cursor with **Agent** (file-edit) mode  
- Scripts are primarily **Windows PowerShell** (`.ps1`)  
- You fill **project-local** config after install (`project-context.md`, your own test list). The pack does **not** ship another team’s business windows or CHANGELOG.

### What's inside

These are not feature checkboxes. They are guardrails—each one exists because that failure mode showed up in real development.

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

## 中文

**AI 几秒就能改出一堆坏代码。这套东西在你点头接受之前插入真门禁——不是又一个补全插件。**

一套可执行的质量门禁，用于 AI 辅助开发——不看本项目不能改、按车道走方案/审查、CR 有 blocker 不能收口、反复改不好有止损链叫停换路（不是拦 `git commit`）。以 Cursor Skill 形式分发，规则本身是纯 Markdown。

1. 从本仓库 **Releases** 下载 **`ai_dev_v3.2.0.7z`**  
2. **解压进**目标项目的 `.cursor/`（包内直接是 `skills/` 等，不要解成 `.cursor/.cursor/`）  
3. Cursor **Agent** 模式里粘贴：`项目经理` + 需求  

首次：`项目经理 初始化`。上手见 [skills/TEAM-GUIDE.md](skills/TEAM-GUIDE.md)；预期与边界见 [skills/METHODOLOGY.md](skills/METHODOLOGY.md)。

**前提**：Agent 可改文件；脚本以 Windows PowerShell 为主。包**不含**业务方案窗、源项目的 `project-context` / CHANGELOG——须自填项目说明后再提需求。

### 里面有什么

这些不是功能清单，是护栏——每一条都对应真实改码里已经踩过的失败模式。

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

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
