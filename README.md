中文文档链接：[https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/README.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/README.md)

**AI can ship bad code in seconds. ai-gates is a complete development pipeline: you just state the need, it runs the whole chain (judge → slice → plan → implement → review → accept) and hands you a test plan — you test it, and only then is it done.**

### Why download it (30-second read)

- **Real gates, not prompt suggestions.** Writes without a fresh PM go-ahead, and dangerous git commands (e.g. `push --force`), are denied by hooks (verified on Codex CLI).
- **Past failures raise the bar.** Modules that already broke are tracked; touching them again auto-escalates the lane and review tier (minimum Standard + L1.5).
- **3-minute setup, cross-platform.** One `.ai-gates/` library shared by Cursor / Codex / Trae / Claude Code; new users can paste one prompt to install and start using — no need to learn lane concepts for daily use.
- **Free (MIT), not a silver bullet — acceptance is yours.** AI can change code, but it cannot see whether the software actually behaves correctly — a log keyword ≠ fixed; every step passes your hands-on acceptance — it removes busywork, not human judgment.
- **A full pipeline, not a gatekeeper.** planner writes the plan → developer writes the code → code-reviewer reviews → you accept — the pipeline produces the code, it does not just block you.

### Positioning: the project manager for AI coding

Most tools focus on the code itself; ai-gates adds one more layer — the order of the whole development process (requirement alignment → plan approval → execution → acceptance → retrospective → stop-loss), with past failures auto-escalating into smart rules. Why it is designed this way, plus real usage data: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md).

### What it treats (why it works)

Typical failure modes when AI edits complex systems directly, and the mechanism for each:

| Failure mode | Mechanism |
| --- | --- |
| Editing without reading the actual code, following habits from other projects — APIs don't line up | Hard gate #1: no changes without reading the real code |
| Reasons live only in chat; next round re-guesses with old judgments | One-round confirmation + windowed docs (reasons persist to disk) |
| A log keyword appears, so it counts as "fixed" | Acceptance A# (falsifiable criteria) |
| The same issue patched over and over, getting messier | Stop-loss chain (forced re-scoping, no same path again) |
| Special-casing to pass the current demo | Physical constraints (no special-casing for specific scenarios) |

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

**The whole setup cost**: a short project note (stack, careful paths, a few must-test cases) — not an ongoing maintenance config; first-time setup / install & update / blocked-by-a-gate quick-ref: [USER-GUIDE.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) (sectioned). Health check? Say `PM doctor`.
What this is / why it is designed this way: [METHODOLOGY.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md); version and changes (current version per skills/VERSION): [CHANGELOG.md](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md).

### Workflow: how one request goes through

ai-gates governs process order: judge → slice → plan → implement → review → accept — every round is traceable, stoppable/reversible, and finishes with a close-out. Every request follows one main line; the lane only decides how heavy each step is. You only state what you need — the pipeline carries the rest through by role:

**Request → `[PM]` judges the lane → slice (what changes / what counts as done) → one-round confirmation (`approve`) → implement → isolated code review → acceptance → retrospective (failures go to the lessons book) → close-out**

| Lane | Shape in the workflow |
| --- | --- |
| **Express** (one-line comment/text/constant) | one-sentence slice → confirm → edit → one-line self-check; no isolated CR |
| **Direct** (small change with behavior change) | in-chat A#/slice (no written window) → confirm → edit → isolated CR |
| **Standard** (cross-module / API / unclear) | plan-lite first → plan review → confirm → edit → isolated CR |
| **Full** (stop-loss / heat big change / "full process") | execution doc → plan review → confirm → edit → two-round escalated-model review |

Every step needs acceptance — A# states "what counts as done" up front, judged by what you actually see. If scope grows mid-task (over-scope, heat hit, cross-module), the lane re-judges immediately — no forcing through. Simple/urgent small edits take the Express / Direct fast lane (one-sentence slice, no written window, no redundant steps) — gates scale with risk, not a hurdle for small changes.

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
| **grill clarification** | Requirements undecided (vague / large / still split after repeated clarification)? One question at a time until the decision tree is exhausted before writing anything; each question carries a recommended answer; approval stays a single round (`approve`) |
| **Harness + Auto** | In-session gates constrain the agent; after `approve`, Standard/Full may run implement↔CR until hard-stop or await-verify (Express/Direct: no Auto) |
| **Recovery phrases** | A reset phrase snaps a derailed session back into process; a rollback phrase reverts code through a confirmed `git checkout` |
| **Roles** | PM dispatches planner / developer / CR / docs; main chat stays PM when possible |
| **Subagents** | Prefer isolated sub-sessions for implement/review so the main chat stays PM-only—not one mega-thread |
| **Model routing** | Reviews can use a stronger model than implementation (project-configurable)—not the same cheap model for both |
| **Windowed docs** | One task = one folder (plan / physical spec / evidence / done); status-classified |
| **Physical spec** | Hard constraints + negative constraints + failure criteria (Standard/Full windows) |
| **Blackboard** | Per-window repair log: what changed → why failed → do not repeat |
| **Lessons** | Cross-window error book; drafts auto, **your `approve`** required before the project table |
| **Allusion guardrails** | An agreed allusion term instantly recalls a whole shared consensus (registered in the shared-language allusion dictionary; silent redefinition forbidden); survives model or person switches |
| **Delta Spec** | ADDED / MODIFIED / REMOVED tracked per step; no silent scope creep |
| **Acceptance (A#)** | Testable, falsifiable criteria per step. “Log keyword appeared” ≠ done. Hot-path regression modules auto-run a smoke check and collect logs/screenshots/test reports as evidence — auto-verification ≠ manual acceptance |
| **Repeatable assertions (TDD)** | An external dotnet NUnit test project at the repo root (e.g. `Tests/EditMode/`) is a repeatable regression guard: run it after business changes, green trx required (total≥70, failed=0); assertions green ≠ business accepted — manual testing still applies. Steps with mechanically verifiable acceptance default to writing assertions first (test-first on by default; forced when the plan/PM names it) |
| **File portals** | One `.ai-gates/` library shared via link-platform portals by Cursor/Codex/Trae/Claude Code — one edit applies everywhere, no four drifting copies |

### Platform

- **Cross-platform (rules / skills / portals)**: rules are plain Markdown, other agents can adapt them; portal scripts ship in pairs — `link-platform.ps1` on Windows, `link-platform.sh` on macOS/Linux (plus `link-trae-skills.sh` for Trae) — all create `.cursor/*`, `.codex`, `.claude`, `.trae/skills`, `.trae/rules`.
- **One `.ai-gates/` library for Cursor / Codex / Trae / Claude Code**; one `link-platform` run creates all the portals.
- **Windows: full support.** The machine-enforced hooks (PM write gate, high-risk git deny, Unity compile hints — all PowerShell) are verified on codex-cli 0.146/0.147 and Claude Code (end-to-end machine-verified 2026-08-10); one-command install = Quick Start. Known gap: Codex **desktop** sessions may not fire the `apply_patch` hooks (zero hits even with trust approved) — after critical writes, check `.ai-gates/hooks-log/`.
- **macOS / Linux**: install, rules, skills, and portals fully supported; the machine hooks are currently PowerShell (`.ps1`) — run via pwsh or rely on the rule layer for now (stated honestly).
- **Trae runs soft-layer only** (rules + skills portals, no machine hooks) — the gates still apply as instructions there, but enforcement is not machine-backed.
- **Single-repo boundary**: gates are scoped to the current repository — cross-repo (multi-repo / microservices) changes are not covered by the machine layer; rely on team discipline there.

### Requirements

- Any agent session that can edit files (agent and platform coverage: see "Platform" above)
- One-time `PM init` + short `project-context.md` / test list (the pack does **not** ship another team's business windows or CHANGELOG)

### You only do three things

1. **Request**: say `PM` + your need (`PM` = project manager)
2. **Confirm**: read "your next step", reply `approve`
3. **Accept**: test as prompted, reply pass/fail

Everything else runs through the pipeline by role. What it does inside vs. what you see:

| Inside the pipeline | What you see |
| --- | --- |
| Judges the change scope, picks a lane | one line: "your next step" |
| Writes plan / execution doc (planner) | a confirmation note — reply "approve" |
| Implements code per the plan (developer) | progress notes |
| Isolated code review (code-reviewer) | review summary |
| Auto-verification + evidence collection | a test plan |
| Retrospective, failures into the error book | draft auto; reply "approve" when asked |
| Close-out: sign off, move the folder | you say "pass" and it is done |

The mechanism table is **guardrail reference**, not a checklist to memorize before coding; the assistant runs the gates. Blocked? The deny message carries its own escape steps; full quick-reference: the USER-GUIDE link in "Get it" above.

---

MIT · Proven in production on a physics-simulation codebase (many real tasks closed or deliberately stopped before spinning). Not a silver bullet: every step still needs human acceptance.
