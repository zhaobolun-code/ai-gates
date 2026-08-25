# 模式沉淀（入表手续）

> **模式沉淀**。定位=**错题本同构的入表手续**，显式 **不是岗**。岗位路由表不加行。**禁止** `knowledge-harvest` 岗 / **第七岗**。
> **目的**：见通用典故 **一错不二犯**。典故把已验证的结构/共识压成一词，提词即唤起。错题本记坑、典故记结构，都为此。
> **加载本文件 ≠ 静默入表。**

## 准全自动（硬）

触发时**自动**起草 pending；主窗只问「准否」；写入 `design-patterns.md`（**项目典故**）或 `shared-language.md` §典故（**通用典故**）或项目口诀 **须「准」**。**禁止静默入表**。**不准默认超时入库**。

```text
可复用结构 + 对仓三档=有真锚点
  →【自动】写/刷新 证据/_pattern-pending.md（status: pending + 五格）
  → 主窗 PM「你下一步」一句：回「准」写入词条/口诀 /「不准」作废 /「改：…」修订
  → 用户「准」/`approve`
  →【须「准」后】Agent 等价写入主表或口诀；pending→committed
```

| 步骤 | 自动？ | 执行者 |
| --- | --- | --- |
| 起草 `_pattern-pending.md` | **是（强制）** | 触发时同条落盘；主窗只问「准否」 |
| 写入 `design-patterns.md` 词条或口诀 | **否** | 仅用户「准」后：Agent 等价落表 |
| 默认准 / 超时入库 | **不做** | **禁止静默入表** |

## 存放位置

| 层 | 路径 |
| --- | --- |
| 机制说明（本文件） | `skills/references/pattern-harvest.md` |
| 待准 | 方案夹 `证据/_pattern-pending.md`（模板 → [pattern-pending.md](../templates/pattern-pending.md)） |
| 主表 | **项目典故**：`design-patterns.md` 词条 或 `.cursor/project-context.md` 项目口诀。**通用典故**：`shared-language.md` §典故（架构层，禁本仓窗号当压缩包主体） |

**禁止塞进 `_lesson-pending.md`**（那边强制 cause/fix，五格对不上，`commit-lesson-pending.ps1` 会拒）。

## 起草触发表

| 触发 | 谁起草 |
| --- | --- |
| 签收 / 抬 `runtime-validated(运行已验证)` 且本窗抽出可复用结构，对仓三档=「有真锚点」 | 主窗 PM（实现子窗交回后同条） |
| CR 发现「本仓已有结构、表里没有」 | CR 交回后主窗 PM 自动起草 |
| 用户点名「模式沉淀」（=错题本「写入错题本」：触发扫一遍，仍须「准」才入表） | 主窗 PM |
| 归档逆向总结卡已有本仓锚点 → 转一份 pattern pending，不重复压卡 | 主窗 PM（结案同条；不改 reverse-allusion 压卡手续） |

**不起草**：无锚点 / 误匹配 / 与现有词条同义；Express、空闲枢纽（与 reverse-allusion 一样默认不跑）。

## 四格（正交 · 禁止混挂）

两套分界正交：**典故 ≠ 错题本**，**通用 ≠ 项目**。同一事实只进一格。

| | **典故**（可复用结构 / 共识） | **错题本**（坑：错因 + 改正） |
| --- | --- | --- |
| **通用** | 架构层，禁本仓窗号/场景当压缩包主体。落 `shared-language.md` §典故 | 未晋升：项目主表大纲桶「Skill / 流水线」。晋升后：`anti-patterns.md`（[lessons-learned.md](./lessons-learned.md) 机制 B） |
| **项目** | 本仓实际结构或口诀。落 `design-patterns.md` 或 project-context 项目口诀 | `.ai-gates/lessons-learned.md` 业务桶（如「压力 / 门闸与传质」） |

`destination`：`design-patterns` / `maxim`（项目典故·口诀）/ `maxim-generic`（通用典故）/ `allusion`。pending 的本仓验证只作证据，**不**写进通用压缩包。

## Skill 自进化（目标 / 现状）

Skill 自进化靠把项目格**抽象**成通用级典故和错题本，不是再开岗、也不是把项目坑直接抄进 Skill。

```text
本仓已有：项目格沉淀 →「准」入表 → 去上下文化（机制 B / 晋升闸）→「准」升通用格
最终目标：用户把项目典故 + 项目错题本上传 GitHub 收集仓
         → 抽象成通用级典故和错题本
         → 下发到用户 Skill
```

**本地环（可跑 · 不接 GitHub）**：

```text
项目格（已「准」的项目典故/错题）
  → 去上下文化（去掉本仓窗号/场景名/模块专名）
  → 写入本地收集仓 collect-queue，state=shareable
  → 抽象成通用级典故/错题草稿
  → 仍须用户「准」才入通用格（shared-language §典故 / anti-patterns.md）
```

**回传（项目侧收包）**：下发 = 「项目经理 升级 ai-gates」（=`PM upgrade ai-gates`）拉技能包真源仓 `zhaobolun-code/ai-gates`，不是拉 collect 仓，也不是再开 PR。

```text
收集仓合并（=审查）
  → 维护者抽象进技能包真源仓 zhaobolun-code/ai-gates（通用典故/反模式）
  → 各项目「项目经理 升级 ai-gates」（=`PM upgrade ai-gates`）拉回技能包
下发 = 升级拉 ai-gates 真源仓，不是拉 collect 仓，也不是再开 PR
收集仓合并 ≠ 已下发
升级成功 ≠ 自动写入本仓 shared-language.md / anti-patterns.md 之外的项目表
入本仓通用格若仍走本地环，须另「准」
本页不实施维护者在 ai-gates 仓里的抽象合入
跨机仍须探测；上传通道仍是 collect 仓 PR
禁止包级自称「gh 已接线/已通/已下发」
禁止第七岗
```

**跨机仍须探测**：仅本机 `gh auth status` exit 0 时可选用 gh，按 [collect-queue.md](./collect-queue.md) §gh 以 **PR** 上传到 `zhaobolun-code/ai-gates-collect`；未探测成功则不得开 PR，本地队列照常。上传通道=collect 仓 PR。禁止包级自称「gh 已接线/已通/已下发」。禁止再写「往 ai-gates 开 issue」当上传通道。
「准」不自动入仓、不自动写入通用格。禁止静默入通用格。禁止第七岗。入通用格须另「准」。

**现状**：本地 [collect-queue.md](./collect-queue.md) 已签收；**跨机仍须探测**。上传通道=collect 仓 PR（`zhaobolun-code/ai-gates-collect`）。回传=「项目经理 升级 ai-gates」拉 ai-gates 真源。下发=拉 ai-gates 真源。收集仓合并 ≠ 已下发。入通用格须另「准」。本页不实施维护者在 ai-gates 仓里的抽象合入。禁止包级自称已通。禁止第七岗。不新建通用错题主表文件（晋升前共用项目主表对应桶）。

## 边界（硬）

错题本记坑；模式沉淀记可复用结构。同一事实禁止双挂。reverse-allusion = 归档压卡，**不当新表**；入表只走本页的「准」。Agent 等价落表即可；**先不写** `commit-pattern-pending.ps1`（YAGNI）。本机制页只声明「准」后可进口诀，本窗实现不改 project-context 口诀节。

## 用户口令

| 用户说 | 动作 |
| --- | --- |
| **准** / **approve**（针对 pattern pending） | Agent 等价写入主表或口诀；pending→`committed` |
| **不准** / **reject** | pending `status: rejected`；不入表 |
| **改：…** | 修订后保持 `pending` |

与方案确认包的「准」冲突时：主窗须写清「准的是模式沉淀 / 准的是开干」，禁止模糊一准两用。

## 借口表

| 借口 | 驳回 |
| --- | --- |
| 「再加一个 knowledge-harvest 岗更干净」 | 禁止第七岗 |
| 「先写进 _lesson-pending 凑合」 | A2 禁止（五格对不上） |
| 「自动起草=自动入表」 | 禁止静默入表 |
| 「点名模式沉淀就是启用逆链」 | 正交，本窗不启用逆链 |
| 「gh 已通 / 已自进化下发」 | 禁止包级自称已通；跨机须探测；上传通道=collect 仓 PR；回传=升级拉 ai-gates；收集仓合并 ≠ 已下发 |

## 禁止

- 新建岗 SKILL；岗位路由表加行；把模式沉淀写成第七岗 / `knowledge-harvest`。
- 改 execution-discipline 必扫问法。
- 改业务 C#；改 project-context 口诀节（本页只声明「准」后可进口诀）。
- bump VERSION。
- 写「逆链已通过」。
- 把五格塞进 `_lesson-pending.md`。
- 未升级成功自称已下发。
- 写「gh 已接线 / 已自进化下发」。
