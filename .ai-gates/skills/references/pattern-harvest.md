# 模式沉淀（入表手续）

> **模式沉淀**。定位=**错题本同构的入表手续**，显式 **不是岗**。岗位路由表不加行。**禁止** `knowledge-harvest` 岗 / **第七岗**。
> **加载本文件 ≠ 静默入表。**

## 准全自动（硬）

触发时**自动**起草 pending；主窗只问「准否」；写入 `design-patterns.md` 词条一行或口诀进 `.cursor/project-context.md` **须「准」**。**禁止静默入表**。**不准默认超时入库**。

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
| 主表 | `design-patterns.md` 词条一行 **或** 口诀进 `.cursor/project-context.md`（不占表） |

**禁止塞进 `_lesson-pending.md`**（那边强制 cause/fix，五格对不上，`commit-lesson-pending.ps1` 会拒）。

## 起草触发表

| 触发 | 谁起草 |
| --- | --- |
| 签收 / 抬 `runtime-validated(运行已验证)` 且本窗抽出可复用结构，对仓三档=「有真锚点」 | 主窗 PM（实现子窗交回后同条） |
| CR 发现「本仓已有结构、表里没有」 | CR 交回后主窗 PM 自动起草 |
| 用户点名「模式沉淀」（=错题本「写入错题本」：触发扫一遍，仍须「准」才入表） | 主窗 PM |
| 归档逆向总结卡已有本仓锚点 → 转一份 pattern pending，不重复压卡 | 主窗 PM（结案同条；不改 reverse-allusion 压卡手续） |

**不起草**：无锚点 / 误匹配 / 与现有词条同义；表已满 6 行**且**也进不了口诀/典故；Express、空闲枢纽（与 reverse-allusion 一样默认不跑）。

## 表满

词条表现行 **6/6**。pending **仍可起草**，但「准」写入须**停**或改走口诀/典故（**进口诀**）。**禁止**加第 7 行。本页是流程不是第 7 行词条。

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
| 「表满了先加第 7 行」 | 禁止；停或进口诀 |
| 「自动起草=自动入表」 | 禁止静默入表 |
| 「点名模式沉淀就是启用逆链」 | 正交，本窗不启用逆链 |

## 禁止

- 新建岗 SKILL；岗位路由表加行；把模式沉淀写成第七岗 / `knowledge-harvest`。
- 改词条表 6 行语义；加第 7 行。
- 改 execution-discipline 必扫问法。
- 改业务 C#；改 project-context 口诀节（本页只声明「准」后可进口诀）。
- bump VERSION。
- 写「逆链已通过」。
- 把五格塞进 `_lesson-pending.md`。
