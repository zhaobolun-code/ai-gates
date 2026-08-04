# 经验沉淀 / 错题本（Lessons Learned）

> 目的：把方案/CR blocker、运行时与自引入 bug、Skill 流程错，以及签收后的成功经验，沉淀成可复用的「一句话」，供策划/CR/开发检索避坑。
> **准全自动**：L0 与待准 L1 **自动起草**；写入主表仍须用户/TL「准」。「准」≠根因已证。
> **禁止**静默写主表。

## 存放位置

| 层 | 路径 |
| --- | --- |
| 机制说明（本文件） | `skills/references/lessons-learned.md` |
| 项目 L1 主表 | 仓库根 `.ai-gates/lessons-learned.md`（模板 → [templates/lessons-learned.md](../templates/lessons-learned.md)） |
| **错题大纲** | 仓库根 `.ai-gates/lessons-outline.md`（模板 → [templates/lessons-outline.md](../templates/lessons-outline.md)） |
| L0 草稿 | 方案夹 `未完成.md` → `## 错题 L0 草稿` |
| **待准 L1** | 方案夹 `证据/_lesson-pending.md`（模板 → [templates/lesson-pending.md](../templates/lesson-pending.md)） |
| 落表脚本 | `.cursor/scripts/commit-lesson-pending.ps1` |

## 准全自动流程（强制）

```text
测挂 / Verify 失败
  →【自动】写/刷新 L0（不问用户、不写主表）
  → Discover / 修复 …

签收通过 · 或 blocker 已正确响应 · 或根因已验证
  →【自动】写/刷新 证据/_lesson-pending.md（status: pending）
  → 主窗 PM「你下一步」一句：回「准」/`approve` 写入错题本 /「不准」作废 /「改：…」修订
  → 用户「准」/`approve`
  →【须「准」/`approve` 后】脚本 -Apply 或 Agent 等价写入主表；pending→committed；L0 可标已晋升L1
```

| 步骤 | 自动？ | 执行者 |
| --- | --- | --- |
| 写 L0 | **是（强制）** | PM / 实现子窗在测挂同条完成；缺 L0 → major（流程债） |
| 扫表 + 更新「最近命中」 | **是（强制）** | 策划/CR 子窗命中行时改日期 |
| 起草 `_lesson-pending.md` | **是（强制）** | 触发条件满足时同条落盘；主窗只问「准否」 |
| 写入 `.ai-gates/lessons-learned.md` | **否** | 仅用户「准」后：`commit-lesson-pending.ps1 -Apply` 或等价追加 |
| 默认准 / 超时入库 | **不做** | 避免脏表 |

**硬律**：禁止测失败同条写 L1/pending 当成功经验；禁止空话「本次无特别经验」充 pending；禁止未「准」改主表；「准」只授权落表。

## L0 / L1 / pending

| 层 | 落点 | 规则 |
| --- | --- | --- |
| **L0** | `未完成.md` → `## 错题 L0 草稿` | 测失败 / Verify **自动**只写 L0；状态 `draft` / `已晋升L1` / `已废弃：…` |
| **pending** | `证据/_lesson-pending.md` | 可晋升时**自动**起草；`status: pending` |
| **L1 主表** | `.ai-gates/lessons-learned.md` | **须「准」**；脚本或 Agent 追加一行 |

## 何时自动起草 pending

| 触发 | 类型默认 | 谁起草 |
| --- | --- | --- |
| 方案 blocker 且策划已正确响应 | `方案blocker` | 方案审子窗交回后由 **主窗 PM** 落 pending（或策划子窗修订收口时） |
| CR blocker 且修复确认 | `CR blocker` | CR 子窗结论交回后 **主窗 PM** / 实现复审收口 |
| 「测试通过」且无业务 blocker | `成功经验` | 主窗 PM 在迁 `runtime-validated` / 签收白话同条 |
| 根因已修复并验证（从 L0 晋升） | `运行时bug` | 主窗 PM |
| 自引入 bug 已改掉并确认 | `自引入bug` | 实现子窗交审前可 L0；确认后 PM 起草 pending |
| Skill/流程错且已修规则 | `Skill流程` | PM（维护场景） |

策划写 Mandatory **前**、CR 审查前：先扫 **错题大纲** 相关桶，再点名读主表行避坑（不写 pending）。

## 错题大纲（强制 · 提高命中 + 改对率）

| 要求 | 说明 |
| --- | --- |
| 文件 | 项目根 `.ai-gates/lessons-outline.md`（无则从模板复制） |
| 条目必填 | **错因**（为何错）+ **改正**（怎么改才对）+ 主表锚点；禁只有教训句 |
| 策划 | 写 Mandatory 前扫桶；在 `未完成.md` 写 **`## 错题本必读（给程序员）`**：大纲桶名 + 主表锚点（日期/模块/关键词）≤5 条；未命中写「无（已扫大纲·{桶}）」 |
| 程序员 | 改码前 Read 必读节点名条目（大纲条 + 对应主表行）；禁全表灌入 |
| 方案审 | 热模块/压力窗缺「错题本必读」节 → **major**；有命中却写「无」→ **major** |
| CR | 未读点名行却复现同错因手法 → **major**；新 pending 缺 cause/fix → **major** |
| 维护 | 高频新 L1「准」后补进大纲对应桶（同步错因/改正） |

大纲管**检索命中**；错因/改正管**改对概率**；与证据黑板（本窗反例）互补，仍不保证零再犯。

## 用户口令

| 用户说 | 动作 |
| --- | --- |
| **准** / **approve**（针对错题/pending） | `commit-lesson-pending.ps1 -PendingPath … -Apply`（或等价写入）；pending→`committed` |
| **不准** / **reject**（可选） | pending `status: rejected`；不写主表 |
| **改：…** | 修订 pending 课文后保持 `pending`，再问一次 |

与方案确认包的「准」/`approve` 冲突时：主窗须写清「准的是错题本 / 准的是开干」，禁止模糊一准两用（可同条两问）。

## 脚本用法

```powershell
# dry-run
powershell -ExecutionPolicy Bypass -File .cursor/scripts/commit-lesson-pending.ps1 `
  -PendingPath "{方案夹}/证据/_lesson-pending.md"

# 用户已「准」
powershell -ExecutionPolicy Bypass -File .cursor/scripts/commit-lesson-pending.ps1 `
  -PendingPath "{方案夹}/证据/_lesson-pending.md" -Apply
```

## 格式（L1 主表）

| 日期 | 模块 | 教训（一句话） | 来源 | 关联文档 | 最近命中 | 类型 | 症状关键词 | 错因 | 改正 | 防再发 | 作用域 | 晋升 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | [Module] | 一句话 | … | 路径 | YYYY-MM-DD | 见类型枚举 | ≤8 词 | 为何错 | 怎么改 | 一句（可与改正互补） | 路径前缀 | 空/已晋升…/已废弃… |

类型：`方案blocker` · `CR blocker` · `运行时bug` · `自引入bug` · `Skill流程` · `成功经验`。  
旧行「错因/改正」可空；**新行必填错因、改正**（pending 字段 `cause` / `fix`）。「最近命中」：写入日；策划/CR 引用时更新。

## 检索

优先 **大纲桶** → 再主表行；亦可按作用域 / 症状关键词 / 模块扫表；**禁止**全表灌进派发。近 6 个月命中 → 至少 L1.5（文件热度）。

## 时效归档

- 「最近命中」> 6 个月且非本轮 → 可标 `[低活跃]`（须人工确认）
- 高频可晋升 `anti-patterns.md`；主表「晋升」列标记
- **只增不删**；过期写「已废弃：原因」

## 边界

| 机制 | 边界 |
| --- | --- |
| `anti-patterns.md` | 团队级通用；本表项目具体 |
| review-dispatch | 管本次 revision；本表跨轮避坑 |
| Auto / 子窗 | 不削弱「准」；pending 由主窗 PM 问准 |
| diagnosis-gates | 测挂自动 L0；不自动 L1 |

不做：静默写主表、默认准超时入库、自动语义聚类、每轮全表注入、Hook 硬拦漏记（可选后续 ask）。
