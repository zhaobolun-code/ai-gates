# 验收条款与 Delta-only（降漂移 / 降 Token）

> **权威路由**：[CORE.md](../CORE.md)。本文件为 plan-lite / Express 切片 / Full 执行文档的共用细则。  
> **借鉴**：Spec Kit（可证伪验收）+ OpenSpec（只写相对现状的变更）；**不**引入多命令入口或自动编排。

## 何时强制

| 产物 | 验收条款 | Delta-only |
| --- | --- | --- |
| Express 切片 | **须有**（可与 Unity 验证合并为编号 A1…） | **须遵守** |
| Standard plan-lite | **须有**独立 `## 验收条款` | **须遵守** |
| Full 执行文档 | **须有**（可放在「完成标准」前，或每 Step 引用全局 A#） | **须遵守** |

缺验收条款或 Step/切片未引用 A# → 方案审核记 **blocker**，不得 `implementation-ready` / 可交给程序员=是。  
`check-pipeline-doc.ps1` 对缺「验收条款」做 **advisory 警告**（默认不阻断；`-Strict` 升 error）。

## 验收条款（Spec 硬度）

每条须可证伪，推荐格式：

```text
A#：[场景] + [操作] + [预期现象或 Console 关键词] + [失败判据]
```

规则：

1. 编号连续：`A1`、`A2`…；实现与 CR **不得超出**条款范围。
2. 须含至少一条**正向预期**；建议含一条**非目标/失败判据**（什么算没做对）。
3. 每个 Step / Express 切片须写 **`满足验收：A1, A2`**（或等价「覆盖验收」）。
4. Unity 未测不得把条款标为已通过（仍遵守证据等级；人工测）。
5. 禁止空话：如「更顺畅」「体验更好」且无可观察判据 → 先澄清或改写成可观察条款。

### 每 Step 最小验证（Standard / Full）

- **业务 C#**：交 CR 前至少完成“编译或 Editor.log 无新增错误”并给出可执行 Unity 验收步骤、预期现象/Console 关键词；适用的自动测试须运行。Unity 未跑仍写 `not run`，不得冒充 runtime。
- **Skill / 纯文档**：静态引用核对 + 可证伪假需求即可，不伪造 Unity；developer §7 的业务 C# 连续 static 计数不适用。
- 缺最小验证 → 不得交 CR；业务 C# 连续第2次交审级 `static-checked` 仍未 Unity → 停车请测，微循环不计。

## Analyze 对表（交审前轻量 · P2）

交审/定版前把三表对齐，防「验收条款与实现范围脱节」：

| 表 | 内容 |
| --- | --- |
| A# | 本 Step / 切片覆盖哪些可证伪验收条款（`满足验收：A1, A2`） |
| Mandatory | Code Changes / Delta Spec（ADDED/MODIFIED/REMOVED 相对当前物理口径） |
| 预期 Console 关键词 | 回归索引场景 / 验收信号（[unity-editor-log.md](./unity-editor-log.md)） |

三表须一致：A# 覆盖范围 ⊇ 实现改动（不得超出），Mandatory 的 MODIFIED/REMOVED 与 A# 现象对应，预期关键词能作为 A# 的观察信号。缺任一或对不上 → 方案审 **major**（缺 A# 直接 blocker，见 §验收条款）；Developer 交 CR 前自检缺任一不得交。

## Delta Spec（形式化 · P1.5）

Standard / Full 每个 Step（Express 切片可极简）须相对**当前** `物理口径.md`（无则相对模块 README 相关节）写清三段：

| 段 | 含义 |
| --- | --- |
| **ADDED** | 本步新增的能力、约束、日志标记、验收外延 |
| **MODIFIED** | 本步修改的既有口径、行为或阈值（写清「旧→新」一句即可） |
| **REMOVED** | 本步废除的口径、行为、字段用法或旧路径 |

规则：

1. 三段均须出现；无内容写「无」，禁止省略字段名。
2. 与 [diagnosis-gates.md](./diagnosis-gates.md) §0.5 规格漂移闸门衔接：Discover 改判后，先改口径/A#，再写下一刀的 Delta Spec。
3. **签收后口径收敛**：用户「测试通过」或准备标方案 `completed` 时，策划/PM **须**根据本步 Delta Spec 提示「物理口径/A# 需同步的句子」；有 MODIFIED/REMOVED 而口径未改 → 不得标方案 `completed`（可先 `step-completed` 待补口径）。
4. 方案审核：缺 Delta Spec 三段 → **blocker**。
5. **结案摘要**：准备 `completed` 时，在活跃 `未完成.md` 生成一页内 `## 结案变更摘要`，汇总全案 ADDED/MODIFIED/REMOVED 与“归并到”路径；有 MODIFIED/REMOVED 必须实际更新物理口径/A# 后才能结案，禁止只写“待同步”。

```markdown
## 结案变更摘要
- **ADDED**：[最终新增；无则写无]
- **MODIFIED**：[旧→新；无则写无]
- **REMOVED**：[最终移除；无则写无]
- **归并到**：[物理口径/A#/README具体章节；无则写无]
```

## Delta-only（精简）

执行文档 / 切片 **只写相对当前仓库的变更**：

1. **禁止**复述整模块原理、架构长文（以模块 README / `物理口径.md` / project-context 为 SoT）。
2. 「不要动什么」只列本次相关硬约束，不抄全文 README。
3. 「当前代码状态与缺口」（Full）只列**已读到的真实符号**与缺口；空着不得定版。
4. 定版后可选：向模块 README 版本记录或 `.ai-gates/lessons-learned.md` **归档一行**（人工确认，非自动）。
5. **窗口化**：活跃正文只在 `未完成.md`；已完成 Step 迁 `已完成/`（见 [doc-windowing.md](./doc-windowing.md)），禁止在未完成窗口堆历史长文。
6. **Mandatory 可打开**：当前 Step 须有 `Mandatory-Step{NN}.md` 或完整写入未完成窗；禁止只活在历史全文。
7. **诊断闸门**：止损 / 热修旁路 / 双轨收敛 → [diagnosis-gates.md](./diagnosis-gates.md)。
8. **证据外置**：长 Console 进 `证据/`；交接短表。

## 岗位要点

| 岗位 | 动作 |
| --- | --- |
| 策划 / PM（Express 切片） | 写 A# + Delta Spec（ADDED/MODIFIED/REMOVED）；Step 引用 A#；签收后提示口径同步 |
| 方案审核 | 查：可证伪、Step 未越界、无整模块复述、**有 Delta Spec 三段** |
| 程序员 | 只为实现所引 A#；冲突停报；按微循环自检 |
| CR / Express 自检 | 对照 A#；越界或未覆盖 → blocker / 不通过 |

## 反模式（摘要）

| 反模式 | 正确做法 |
| --- | --- |
| 无 A# 就 `implementation-ready` | 补条款后再审 |
| Step 改了条款外文件/行为 | 停；改方案或升车道 |
| plan-lite 重写系统说明 | 删复述，改链到 README |
| 用「感觉好了」当验收 | 改成 Console/现象判据 |
| Step 无 ADDED/MODIFIED/REMOVED | 补 Delta Spec 三段后再审 |
| 有 MODIFIED/REMOVED 却结案不改口径 | 先同步物理口径/A# 再 `completed` |
