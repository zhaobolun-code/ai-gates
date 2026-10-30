# ai-gates

中文版：[技能包里的说明](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/README.md)

AI often says the work is done. Can the old config still be read? Did anyone actually run a test? Ask, and the answer is sometimes vague. There are also hallucinations: functions, files, or interfaces that do not exist in this project, described as if they were already wired up.

ai-gates is a guardrail you install inside the project. You state the need in ordinary language. A change to exactly one business file, limited to a comment, an existing log line, or a constant of no more than three lines, and with no behavior change, can go straight through. If the change touches saved data or an API, or reaches across several modules, it writes a plan first. Whatever review that size of change requires happens before you reply `approve`. Only then does it edit code. Afterward, another pass looks at the result. A test that was not run must be reported as not run. It must not be reported as passed. This is for a project you will keep changing. A one-off script does not need it.

When it says it is finished, it has to say how far verification went: not run, static checks only, or actually run. Two rounds in a row with only static checks and no real run stop here until someone runs a real check.

## An example

Add hot reload for config, and keep old config files readable. That does not start by editing files. It first writes which files change, how old config stays compatible, and how to verify that. The reviews that fit this change come first. After you reply `approve`, it edits the code.

A later pass looks from another angle, and tries not to lean on the implementation story or on the author's own explanation. It then says which tests actually ran and which did not. Whether your project can still read the config is something you check yourself.

A one-line comment that fits the small-change case above does not walk through all of those steps.

## Install

Paste the block below into Cursor, Codex, or Claude Code. It will list the files it intends to change and wait until you agree.

### Paste this to the agent (recommended)

```text
Install ai-gates (the AI development pipeline skill pack) from https://github.com/zhaobolun-code/ai-gates into this project. This replaces a manual download and unzip. Initialization is not part of this step:
- Take the latest release tag. Clone or download it into a temp directory. Require a root .ai-gates/ whose skills/VERSION is a legal x.y.z equal to that tag, or stop.
- Copy skills, hooks, scripts, rules, codex, the root docs, hooks.json, link-platform.*, and LICENSE from the temp .ai-gates/ into the project .ai-gates/. If it is already installed, compare versions and replace only when updating. Keep project-context, mcp.json, hooks-log, tmp, verify, regression-*, pipeline-*, and other project state.
- Run link-platform.ps1 to create the portals and write install-info.json. On macOS or Linux, link-platform.sh is only for creating portals. It is not a full one-step installer. Machine hooks still need PowerShell 7, and the registered command name is still powershell.
- Run pm-init.ps1. It only creates files such as .cursor/project-context.md. It does not choose models for me. Do not say work can start. The regression index can be filled in later.
- Then report the version and portal status. Ask me to say "PM doctor" first. Project notes and model choice wait until I say "PM init".
List a plan and wait for my confirm before touching files. On failure or network problems, do not change files. Give a manual download path.
```

### Two other ways

- One Windows command: `powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/zhaobolun-code/ai-gates/main/.ai-gates/scripts/install-ai-gates.ps1 | iex"`
- Download the archive from [Releases](https://github.com/zhaobolun-code/ai-gates/releases/latest) and extract it into the project root. The archive contains `.ai-gates/`.

The official Cursor Marketplace listing is not up yet. Do not install from the Marketplace yet. macOS and Linux have no full one-step installer. The `.sh` script only creates portals.

## After install

Install stops here: the files are in place, the portals (the entry files for each app) have been created, and the install record has been written. Say `PM doctor` and see whether the hooks (the automatic blocks) are connected.

Initialization is the next step. Say `PM init`. It will ask which model to use for the higher tier and which for the lower tier, and it will ask you to confirm the project notes. The script in the paste above only creates the notes file. It does not pick models for you. The regression index can wait. You can start work without it.

After that, say `PM` plus what you want done. Reply `approve` to a plan. When it asks you to try something, open it yourself.

To upgrade, say `PM upgrade ai-gates`.

| You say | What it does |
| --- | --- |
| `PM`, plus the request | Start a piece of work |
| `approve` | Accept this plan, or accept writing it down |
| `PM init` | Fill in the project notes the first time |
| `PM doctor` | See whether the entry files and the blocks are connected |
| `PM upgrade ai-gates` | Update this guardrail |

## What each app can actually block

Windows uses the PowerShell that comes with the system. macOS and Linux need PowerShell 7, command name `pwsh`. If the machine has only `pwsh` and no `powershell`, the blocks do not start. `PM doctor` reports an error, and that does not count as installed. If neither command exists, only the rules in the conversation remain.

| App | What actually happens |
| --- | --- |
| Cursor | Can block. Whether it is connected is what doctor reports |
| Codex CLI | Can block. Whether it is connected is what doctor reports |
| Codex desktop | `apply_patch` may skip the block. Do not rely on every write being stopped |
| Claude Code | Can block. Whether it is connected is what doctor reports |
| Trae | No automatic block. The rules are still there |

`PM doctor` checks whether the entry files and the blocks are connected. A machine allow is a different fact. It only means this conversation left a start mark within the last two hours. It does not mean this item finished its routing decision, and it does not mean this change was reviewed or accepted. If a command is not recognized, or a state file cannot be read, that check lets the action through. The block is not an absolute boundary. What to do when you are blocked is in the [user guide](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md).

## How tight the process is

Routing means which lane this change takes. The guardrail mainly stops four things: editing before the lane is chosen, calling a test passed when it was not run, sending a tiny change through the full process, and meeting the same mistake again under a new name.

| Lane | When | Example |
| --- | --- | --- |
| Express | Exactly one business file, and only a comment, an existing log line, or a constant of no more than three lines, with no behavior change | Change one comment line |
| Direct | The default. An ordinary behavior change, or two or three files, without an API, saved data, or a cross-module change | Add a check inside a function |
| Standard | More than three files, or an API, saved data, a cross-module change, or an unclear scope. The first time Express or Direct keeps failing, it moves up here too | Hot reload that must still read old config |
| Full | A stricter mandatory case | Decided from CORE. Not summarized here |

After the lane is chosen, only that lane's card is read.

## What the project remembers

Failures go into a lesson book. A failed test is noted first. After the fix, you confirm before it is written into this project. The next plan looks at related lessons. A similar area later gets a stricter review.

An approach that was finished and verified can get a short name. The project calls that an allusion: a verified approach. Mention the name later and the agreement comes back with its limits. You do not explain it again. One example is keeping pitfalls and structure in separate records.

Both stay in this project by default. `approve` only agrees to write them here. It does not upload them. Say `upload` to hand them to the public collection. After a maintainer merges them, other projects can pull the result with `PM upgrade ai-gates`. Window ids and paths do not travel with them.

## The map

When there are many folders, people and the assistant both stare at the one in front of them. The fog map is drawn from the project's work documents. A work folder that exists is drawn. A link appears only when the relation is strong enough. Something only named in a document, with no work folder yet, is drawn as fog. Ordinary data directories are not added just because they exist.

The map navigates how the work relates. It is not an index of the code. The detail stays in the original documents. The assistant asks whether to create or update the map, and draws it only after you agree. Then double-click `.ai-gates/verify/fog-map.html`. No local web server is required. A very small change can skip creating a folder, and then the map does not gain a tile. An older copy in some other directory does not count.

## An optional extra check

You can ask two assistants to look for holes in each other's work, walk backward from what would count as failure, or write two views in the same round and compare them. This does not run unless you ask. It also costs more time and money. Ordinary work still uses an ordinary review.

[User guide](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/USER-GUIDE.md) · [Why this design](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/METHODOLOGY.md) · [Changelog](https://github.com/zhaobolun-code/ai-gates/blob/main/.ai-gates/CHANGELOG.md)
