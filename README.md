# ai-gates

中文 → [中文版 README](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/README.md)

**AI can dump a pile of bad code in seconds. That is why you need gates: you state the demand in your native language; the pipeline carries the process and lowers cognitive load. At key nodes, a person must test and pass.**

This skill pack changes AI-assisted coding on three layers: vibe coding keeps the feel and still finishes; self-evolution turns failures into rules; exogenous metacognition is an exploration of the unknown.

You just vibe; ai-gates does the coding.

## Vibe coding

Flow: skip syntax, skip the docs, skip a complete architecture up front, and build the code by feel, like drawing. Guardrails you barely notice let you move forward; vibe coding goes from a toy to a tool.

- **Delivery loop**: one folder per demand; when it ends, it moves from In Progress to Signed off. Reply `approve` = understand + plan + start, one confirmation. You can still change the plan at each node. Finish means close out.
- **Stop-loss loop**: the same approach failing repeatedly is stopped and rerouted; “this path is closed” goes into the lesson book. Later edits to that fragile area get a stricter review (heat).
- **Four lanes + task routing**: the flow is chosen by size of the change—small edits take a few steps, large ones write a plan then review, and more files or a cross-module change tighten on the spot. You do not pick the lane. Planning and coding can use a normal model; review and acceptance can use a stronger one. About 70% less model usage—put the expensive steel on the cutting edge.

Classic vibe coding offloads cognitive load, and with it quality, debt, and dependencies; a small change becomes an avalanche. Gates keep pass criteria, stop points, and human tests at key nodes in the flow.

## Gray box

You don’t need to read the process manual every day, but you are not flying blind either. Usually the assistant only tells you what to do next; you agree, it acts, and when it is your turn to test, you test—saving effort, not skipping sense. When you want to see how these tasks connect and what no one has done yet, open the fog map. Very small changes may skip a folder, so they don’t add a tile to the map.

- **Why the fog map exists**: with many tasks, clicking folders one by one doesn’t show “what is related to what, what to do next”. The assistant also tends to stare at only the one folder in front of it. The map draws existing work folders as tiles: a folder exists → it gets a tile; the relation is strong enough → it gets a link. Things only mentioned by name, with no folder yet, are drawn as fog. Empty space itself says work is still missing.
- **Why it works**: links and empty space are visible at a glance—no need to open dozens of folders one by one. The map is drawn automatically from existing documents, so you don’t maintain another spec. It is only drawn when you say yes; folders never get a map drawn behind your back. For details, go back to the original documents; the map is just an overview.
- **Opening**: the assistant asks first, you agree, then it generates the map; double-click `.ai-gates/verify/fog-map.html`. Open this file directly—no local web server needed. If an older copy exists in another directory, that one does not count.

## Self-evolution

Failures are recorded, successes are recorded too, and the next time they are still usable.

- **Lessons loop**: a failed test is noted first; after a fix, you are asked whether to write it into this project’s lesson book; the next plan reads it; a similar miss later gets a stricter review. The point is not to make the same mistake twice.
- **It grows**: when an approach works and is verified, it is written down as an “allusion”—one short name; from then on, one mention makes the assistant recall the whole agreement. It stays in this project first; to share it with everyone, first reword it without this project’s names and paths, then say “upload”. After maintainers pull it into the skill pack, other repos only get it when you say `PM upgrade ai-gates`.

## Metacognition (advanced attempt)

A few extra checks exist; they run only if you ask: two assistants look for holes in each other, walk backward from “what counts as fail” to see if the design breaks, or write two views in the same round and compare. These have been tried a few times (they can find issues and breaks; they also cost more time and money). Everyday work still uses ordinary review. This is the skill exploring the unknown—not something that starts reflecting by itself after install.

## 30-second install, 3-minute fluency

Path A hands install to one paste. After that, everyday work is: state the demand, reply `approve`, and accept at key nodes against the prompt.

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

[Getting started](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) · [Why this design](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md) · [Changelog](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md)

## Platform

Supports Cursor / Codex / Trae / Claude Code. Platform issues: see [USER-GUIDE](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md).
