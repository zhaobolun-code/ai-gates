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

The black box lowers cognitive load: day to day you see one “your next step,” reply `approve`, and test at key nodes. The white box is for seeing the coding process and how it was implemented: open this demand’s folder for the plan, why it was done this way, which bits of code changed, and the review. Default black, white when you need it—that is the gray box (small edits can skip a folder).

## Self-evolution

This layer is the **lessons loop** and **it grows**. Failures and verified approaches stay, so the next plan can use them.

Lessons and allusions (a verified approach: one word recalls the whole agreement) both have a **project** level and a **shared** level. Project: reply `approve` into this repo’s lesson book or approach table; only the next plan in this project must read them. To use them everywhere, first **abstract them to the shared level** (drop names and paths that only this project knows), then you may upload to the collect repo. After maintainers pull them into the skill pack, say `PM upgrade ai-gates` to use them in other repos.

- **Lessons loop**: a failed test is noted first; after a fix, you are asked whether to write it into this project’s lesson book; the next plan reads it; a similar miss later gets a stricter review. The point is not to make the same mistake twice.
- **It grows**: users evolve the skill together. `approve` keeps the project level; after abstracting to shared wording you may “upload”; upgrade brings the shared level back. Every AI mistake is a chance to grow.

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
