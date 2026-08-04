# [功能名] 执行方案（lite）— 写入 `未完成.md`

> **车道**：Standard（常道）默认模板。Full 车道见 [references/execution-doc-template.md](../references/execution-doc-template.md)。
> **路径**：用户指定 > project-context 文档根 > 默认 `Assets/Doc/{主题}/{方案短名}/未完成.md`（须同时有 `已完成/_索引.md`）。窗口化 → [doc-windowing.md](../references/doc-windowing.md)；闸门 → [diagnosis-gates.md](../references/diagnosis-gates.md)

> **Delta-only**：只写相对当前代码的变更；模块原理以 README / `物理口径.md` 为准，禁止在本文重写系统说明。细则 → [acceptance-and-delta.md](../references/acceptance-and-delta.md)

## 目标

[3 行以内：要做什么、解决什么现象]

## 链接

- 物理口径：新窗（有 `.kit-v1`）强制 `./物理口径.md`；历史无 kit 不强制（见 [doc-windowing.md](../references/doc-windowing.md) §新窗齐套标记）
- 已完成索引：`./已完成/_索引.md`
- 模块 README：
- 相关黄金场景子集：`.ai-gates/verify/golden-scenes.yaml`（无则写无）

## 窗口关系摘要

> 跨窗/续作/旁路时**必填**；纯单窗无邻窗可写「无（单窗）」一行。窗路径列写**主题短名**（文件夹 basename），不写完整分类夹路径。

| 窗路径（主题短名） | 关系（Beads 枚举） | 状态 | 关键结论（一句） |
| --- | --- | --- | --- |
| `[方案短名或邻窗短名]` | `upstream` / `downstream` / `related` / `evidence-from` / `blocks` / `depends-on` | [draft / 执行中 / 签收 / 停写 / runtime-validated 等] | [一句可检索结论] |

> **搬家/断链**：分类夹可变（`执行中/`→`签收/` 等）；搬家后**必须**跑 `migrate-pipeline-window.ps1`；跨链相对路径用 `repair-doc-crosslinks.ps1`（见 [doc-windowing.md](../references/doc-windowing.md) §迁移动作）。**禁止**手挪文件夹后只改状态字段。

## 不要动什么

[来自模块 README 的硬约束；C#/Lua 层边界 — 只列本次相关条目]

## 错题本必读（给程序员）

> 策划写 Mandatory 前扫 `.ai-gates/lessons-outline.md` → 主表；程序员改码前只读下列点名条（含**错因/改正**）。细则 → [lessons-learned.md](../references/lessons-learned.md) §错题大纲。

- 大纲桶：`[如 压力 / 门闸与传质]`
- 主表锚点：`[YYYY-MM-DD / 模块 / 关键词]`（≤5；无则写「无（已扫大纲·{桶}）」）

## 验收条款（实现不得超出）

> 每条可证伪：`A#：场景 + 操作 + 预期现象/Console + 失败判据`

- A1：[场景 + 操作 + 预期 + 失败判据]
- A2：[可选]
- 非目标：[明确不做什么]

## 上一步摘要（≤30 行；无则写「无」）

[已完成 Step 的一句话结论；详情见已完成/]

## 结案变更摘要（仅准备 completed 时填写；一页内）

- **ADDED**：[全案最终新增；无则写「无」]
- **MODIFIED**：[旧→新；无则写「无」]
- **REMOVED**：[全案最终移除；无则写「无」]
- **归并到**：[已更新的物理口径/A#/README具体章节；无则写「无」]

## Step 列表（仅未完成）

### Step 1 — [名称]

- **DO NOT TOUCH（冻结表）**：[本步冻结的 README 版本段 + 点名 API/文件；空则写「无（已扫）」。窗级「不要动什么」≠本字段，不可省]
- **Mandatory Code Changes**：[具体文件路径]
- **复用四问**（写 Mandatory 前；见 [execution-discipline.md](../references/execution-discipline.md)）：
  - 已有：[README/符号/同主题窗检索结论]
  - 复用：[指名 helper/Service/门闸/分支；不能则一句为什么]
  - 少写/不写：[改参/接旧轨/只改口径？须新写才写]
  - 能删：[REMOVED 指向 / 本步无可删 / 建议抽离]
- **Delta Spec**（相对当前物理口径 / README，必填）：
  - **ADDED**：[本步新增能力/约束/日志；无则写「无」]
  - **MODIFIED**：[本步修改的既有口径/行为；无则写「无」]
  - **REMOVED**：[本步废除的口径/行为/字段用法；无则写「无」]
- **满足验收**：A1, A2
- **Agent 易错语义**：[符号 + 实际语义 + 文件/类/方法证据；未发现则写「未发现；已检查 [关键符号]」]
- **Unity 验证**：[Editor 操作步骤]
- **Regression Validation**：[预期现象 + Console 关键词]
- **口径同步提示**（签收后由策划/PM 填写或确认）：物理口径 / A# 需改动的句子 → [无 / 列出字段]

### Step 2 — [名称]（可选）

- **DO NOT TOUCH（冻结表）**：[同上；空=「无（已扫）」]
- **Mandatory Code Changes**：
- **Delta Spec**：ADDED / MODIFIED / REMOVED（同上；无变更写「无」）
- **满足验收**：
- **Agent 易错语义**：
- **Unity 验证**：
- **Regression Validation**：
- **口径同步提示**：

## 文档状态

> **方案审核档位**：须**单选**其一（`L1` | `L1.5` | `L2` | `L3` | `跳过`），定稿时删未选项；**禁止**未决串 `L1 / L1.5 / L2 / L3 / 跳过`。`.cursor/skills/**` 改动默认 **L1.5**。

- **状态**：draft(草稿)
- **当前 Step(步骤)**：N/A
- **车道**：Standard
- **方案审核档位**：L1.5
- **证据等级**：claimed(已声称)
- **可交给程序员**：否
- **方案文件夹**：`Assets/Doc/{主题}/{方案短名}/`

## 给程序员的说明

一次只做一个 Step；只为实现所引用的验收条款。方案与真实代码冲突时停下报差异，禁止臆测 API。Step 签收后由策划/PM 迁入 `已完成/`；若 Delta Spec 含 MODIFIED/REMOVED，须同步提示并更新 `物理口径.md`/A#（见 [acceptance-and-delta.md](../references/acceptance-and-delta.md) §Delta Spec）。

状态迁移：`draft` → 用户确认后 `review-pending` → L1/L1.5 无 blocker 后 `implementation-ready` + **可交给程序员**=是。

**L1.5**：CR **优先** Subagent 隔离；派发默认可读本 `未完成.md`，禁读 `已完成/` 全文。
