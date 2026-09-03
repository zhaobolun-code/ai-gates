# ai-gates

中文 → [中文版 README](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/README.md)

**AI can dump a pile of bad code in seconds. That is why you need gates: you state the demand in your native language; the pipeline carries the process and lowers cognitive load. At key nodes, a person must test and pass.**

This skill pack changes AI-assisted coding on three layers: vibe coding keeps the feel and still finishes; self-evolution turns failures into rules and turns verified approaches into reusable allusions; exogenous metacognition is an exploration of the unknown. Two foundations sit under all three: **one authoritative source shared by Cursor / Codex / Trae / Claude Code**, and **nothing that hasn’t been run may be marked as passed**. To see how it differs from similar packs, jump to [How it differs](#how-it-differs-from-similar-skill-packs).

You just vibe; ai-gates does the coding.

## Vibe coding

Flow: skip syntax, skip the docs, skip a complete architecture up front, and build the code by feel, like drawing. Guardrails you barely notice let you move forward; vibe coding goes from a toy to a tool.

- **One entry**: you only talk to the PM—state the need, reply `approve`, accept against the prompts. Planning, coding, review, and docs are dispatched to their own roles, usually in separate conversations—the reviewer doesn’t see how the code was written, so it can actually review. You don’t need to remember role names.
- **Delivery loop**: one folder per demand; when it ends, it moves from In Progress to Signed off. Reply `approve` = understand + plan + start, one confirmation. You can still change the plan at each node. Finish means close out.
- **Stop-loss loop**: the same approach failing repeatedly is stopped and rerouted; “this path is closed” goes into the lesson book. Later edits to that fragile area get a stricter review (heat).
- **Four lanes + task routing**: the flow is chosen by size of the change—small edits take a few steps, large ones write a plan then review, and more files or a cross-module change tighten on the spot. You do not pick the lane. Planning and coding use a normal model; review and acceptance get the stronger one. Each stage names only the one or two rules it actually needs, so the expensive model is spent only where it counts.
- **Guardrails are not just self-discipline**: after install there is a machine-enforced layer—editing files out of process is denied on the spot, changing the pipeline itself requires a changelog entry first, and dangerous commands like `push --force` are blocked. When blocked, you are told why and how to proceed.
- **Not tested is not passed**: what can run automatically (compile, the regressions you registered in this project) it runs and keeps evidence; what can’t be run is marked “not run”, never “fixed”. The final “passed” is always yours to say.

Classic vibe coding offloads cognitive load, and with it quality, debt, and dependencies; a small change becomes an avalanche. Gates keep pass criteria, stop points, and human tests at key nodes in the flow.

## Gray box

You don’t need to read the process manual every day, but you are not flying blind either. Usually the assistant only tells you what to do next; you agree, it acts, and when it is your turn to test, you test—saving effort, not skipping sense. When you want to see how these tasks connect and what no one has done yet, open the fog map. Very small changes may skip a folder, so they don’t add a tile to the map.

- **Why the fog map exists**: with many tasks, both people and the assistant get lost. People clicking folders one by one can’t see “what is related to what, what to do next”; the assistant also tends to stare at only the one folder in front of it, unaware of who else is around or which things were only named but never got a folder. The map draws existing work folders as tiles: a folder exists → it gets a tile; the relation is strong enough → it gets a link. Things only mentioned by name, with no folder yet, are drawn as fog. Empty space itself says work is still missing.
- **Why it works**:
  - **For people**: links and empty space are visible at a glance—no need to open dozens of folders one by one. The map is drawn automatically from existing documents, so you don’t maintain another spec. It is only drawn when you say yes; folders never get a map drawn behind your back. For details, go back to the original documents; the map is just an overview.
  - **For the assistant**: when editing one window, it reads the neighboring windows along the links, so it doesn’t miss neighbors or mistake a folder that was only named (but never created) for something already done. The map only points to whom to read; the content is still read inside the folders—the map never teaches it what the code looks like.
- **Opening**: after document state changes, the assistant asks “create the fog map?” or “update the fog map?”. You agree, then it generates the map; double-click `.ai-gates/verify/fog-map.html`. Open this file directly—no local web server needed. If an older copy exists in another directory, that one does not count.

## Self-evolution

**Two books**: failures go into the **lesson book**, successes into **allusions**. Both are read before writing a plan—“the more you use it, the better it gets” relies on these two books and nothing else.

- **Lesson book (pitfalls)**: a failed test is noted first; after a fix, you are asked whether to write it into this project’s lesson book; the next plan reads it; a similar miss later gets a stricter review. The point is not to make the same mistake twice.
- **Allusions (verified approaches)**: when something works and is verified, give it one short name and keep it—a library of proven approaches. From then on, you or the assistant only needs that name and the whole agreement returns with its boundaries; no re-explaining, and it isn’t lost when the model changes. For example, “one error, no repeat” recalls the whole “pitfalls and structures are recorded separately” convention. The lesson book stops you stepping in the same hole; allusions save you re-explaining. Both are needed.
- **Both need your nod, and both can be shared**: lessons and allusions are only written into this project when you reply `approve`; approving is not uploading. Say “upload” to hand them to the public collect repo, where a maintainer still has to merge them; your window IDs and paths don’t travel with them. Conversely, what others have already grown comes back when you say `PM upgrade ai-gates`.

## Metacognition (advanced attempt)

A few extra checks exist; they run only if you ask: two assistants look for holes in each other, walk backward from “what counts as fail” to see if the design breaks, or write two views in the same round and compare. These have been tried a few times (they can find issues and breaks; they also cost more time and money). Everyday work still uses ordinary review. This is the skill exploring the unknown—not something that starts reflecting by itself after install.

## How it differs from similar skill packs

Similar packs come in two rough kinds. **Toolbox type**: a pile of independent skills you trigger manually when you remember—handy, but you must know a skill exists and when to use it. **Heavy-process type**: one fixed flow forced to the end, the AI runs from start to finish—rigorous, but you can’t step in while it runs, and a small change also walks the big process.

ai-gates instead: **the flow is chosen by it, the stop points are yours**. These are the points that decide whether it stays good long-term, yet are the easiest to overlook:

| Compare on | Typical alternatives | ai-gates |
| --- | --- | --- |
| **Switching editors** | Bound to one specific client | One authoritative source `.ai-gates/` shared by Cursor / Codex / Trae / Claude Code, same gate scripts. Switch tools or machines—the rules don’t need reinstalling |
| **Saying “done”** | The AI says done, that’s done | Three tiers of evidence: not run / statically checked only / run and verified. Two rounds of static-only checks without testing force a stop and a real run first |
| **Process granularity** | Either fully automated takeover, or everything manual | Four lanes auto-chosen: a one-line change starts with one sentence; cross-module or save-touching work writes and reviews a plan first. You don’t judge which flow |
| **Long-term use** | The pack is what it was at install; it never changes | **Two books**: failures into the lesson book—the same area gets stricter review later; successes get a short name in “allusions”—one mention returns the whole agreement. Both can upload to the public collect repo and be pulled back into other projects |
| **Rule bloat** | Rules pile up; more rules, more fed into context | At most 1–2 rules are named per stage; whole-directory injection is forbidden; the normal model writes plans and code, the expensive model only reviews |
| **Project-wide view** | You keep project state in your head | Fog map: done work is drawn as land, things only named are fog—people watch progress, the assistant follows links to see which folders to read |

In one line: **it doesn’t decide for you, but it blocks what shouldn’t pass**—and this blocking still works after you switch clients, and in the next project.

## 30-second install, 3-minute fluency

After install, daily work is three things: state the need, reply `approve`, and test key nodes yourself as prompted.

### Path A (recommended · zero manual · same paste on every platform)

Paste the **whole** block to the Agent. It will fetch the latest release, install the library, set up connections, and walk init:

```text
Install ai-gates (the AI development pipeline skill pack) from https://github.com/zhaobolun-code/ai-gates into this project, replacing manual download, unzip, and init:
- Take the latest release tag; clone/download to a temp dir; require a root .ai-gates/ whose skills/VERSION is a legal x.y.z equal to that tag, or stop.
- Copy temp .ai-gates/ skills/hooks/scripts/rules/codex, root docs, hooks.json, link-platform.*, LICENSE into project-root .ai-gates/; if already installed, compare versions and replace only on update; keep project-context, mcp.json, hooks-log, tmp, verify, regression-*, pipeline-* and other project state.
- Run link-platform.ps1 (Unix: .sh) to create portals; write install-info.json.
- Run pm-init.ps1; saying `PM init` is enough to start (regression index can come later) and generate .cursor/project-context.md.
- Then report version and portal status, and tell me the later entry is `PM + request`.
List a plan and wait for my confirm before touching files; on failure or network issues do not change files—give a manual download path.
```

### Path B / C (alternatives)

- **One command** (Windows PowerShell, good for batch installs): `powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/zhaobolun-code/ai-gates/main/scripts/install-ai-gates.ps1 | iex"`
- **Manual download**: take the archive from [Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest), extract it into the project root (the archive contains `.ai-gates/`), then say `PM doctor`.

After installing or upgrading, say `PM doctor`—it checks the portals and the version itself. To upgrade an existing install, say `PM upgrade ai-gates`.

[Getting started](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) · [Why this design](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md) · [Changelog](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md)

## Platform

Supports Cursor / Codex / Trae / Claude Code. The machine-enforced gates above are PowerShell scripts; on macOS / Linux you need PowerShell 7 (`pwsh`) installed—without it only the rule layer remains, nothing blocks manual edits. Platform differences and “what to do when blocked”: see [USER-GUIDE](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md).
