# References 读取路由（降日常 Token）

> 只定义“何时读哪份”，不物理合并 references。任何阶段禁止把 `references/**` 通配注入上下文。

## 默认读取预算

1. **基线**：`agent-entry-route.md` + `.cursor/project-context.md`（若有）+ 当前岗 `SKILL.md` checklist；**CORE 全文不在基线**。
2. **任务白名单**：当前 `未完成.md` / Mandatory、模块 README 风险短段、真实源码/diff、命中的 lessons 行；这些不是 reference 预算，不得为省 Token 跳过。
3. **Reference**：每个阶段默认最多点名 1～2 份；新需要出现时优先替换已完成用途的 reference，不累积整包。确有硬规则冲突可超出，但交接须写理由与文件名。

## 日常按触发加载

| 触发 | 点名 reference |
| --- | --- |
| 测试失败 / 热修 / 止损 / 黑板 / 有意义评审 / A# 复议 | `diagnosis-gates.md`（§0.2.1 有意义评审、§0.6 黑板、§0.7 触顶复议）；需要日志再加 `unity-editor-log.md` |
| 确认 / Auto / 转场 | `handoff-automation.md`；需要停机细则再加 `loop-engineering.md` |
| A# / Delta / 结案收敛 | `acceptance-and-delta.md`；窗口超长再加 `doc-windowing.md` |
| L1.5/L2/L3 隔离 | `isolated-review.md`；派发版本问题再加 `review-dispatch-lifecycle.md` |
| 派岗选模型 / 贵便宜路由 | `model-routing.md`（可与 isolated-review 二选一加载） |
| 测挂 L0 / 签收待准错题 / 错题大纲 | `lessons-learned.md`（含 §错题大纲）；项目文件 `.ai-gates/lessons-outline.md` |
| 签收可复用结构 / CR 未入表真锚点 / 点名「模式沉淀」 | `pattern-harvest.md` |
| 写 ≥2 Step 契约 / 点名「电路子窗」 | `circuit-windows.md` |
| 7 天卡住 / 质量趋势停点 | `long-task.md` |
| 压缩重派 / 跨会话续作账本 | `loop-engineering.md` |
| 签收效果一行 / 月末汇总 | `retrospective-metrics.md` §效果轻量版 |
| 写方案/改码前精简 / 复用 | `execution-discipline.md` §复用四问；项目硬阈见 `.cursor/project-context.md`（若有神类止血） |
| 写 Mandatory 前设计模式选型 / 方案审核模式结构 | `design-patterns.md` + `execution-discipline.md` §设计模式一问 |
| 方案/CR 术语歧义、同义异名 | `shared-language.md`（活词汇表） |
| CR 双轴（规范轴 + 规格轴） | `dual-axis-review.md` |
| Full 策划前 / 架构概览体检 | `architecture-health-check.md`（CRG 只读） |
| test-first 切片（本 Step 验收含可机械验证项时默认启用；方案点名/PM 指定强制） | `test-first.md` |
| 外部事实 / API / 文档调研（开子窗） | `research-task.md`（只读调研 + 引用证据） |
| 只能人做的步骤（凭证 / 授权 / 后台） | `human-wizard.md`（交互向导） |
| 超大任务决策点地图 | `decision-map.md`（配合阻塞边字段） |
| 派发哈希 stale / 路径排序 | `review-dispatch-lifecycle.md`（须 Ordinal 升序） |
| 新窗齐套 kit 标记 / 短名链接纠错 | `doc-windowing.md`（点名新窗齐套标记节；纠错脚本见迁移动作） |

## 模型自动触发（model-invoked references）

> 本表为既有「日常按触发加载」行的**调用维度注解**，不改既有触发行为。调用权限维度（**双轨调用**；与 [dual-axis-review.md](./dual-axis-review.md) 的 CR「双轴（规范轴/规格轴）」是不同维度，术语登记见 [shared-language.md](./shared-language.md)）：岗位 SKILL = **user-invoked**（口令触发，模型不得自动执行岗，机器可读声明见各岗 `agents/openai.yaml` 的 `policy.allow_implicit_invocation: false`）；下表 references = **model-invoked**——满足触发语义时由模型**自动加载**，无需用户点名。既有 8 行与「日常按触发加载」对应；**新增行按 agent-brief / out-of-scope 先例仅入本表**（模型自动触发），不进「日常按触发加载」表；新增行仍须同步 [MAINTAINER.md](../MAINTAINER.md)「技能元数据规范」，否则视为设施漂移。

| 触发语义（模型自动加载） | 点名 reference |
| --- | --- |
| 诊断 / 止损 / 热修自动加载放行规则 | `diagnosis-gates.md` |
| 术语歧义 / 同义异名 | `shared-language.md` |
| 典故词被点名（提词即唤起既定共识，不必复述） | `shared-language.md` |
| 本 Step 验收含可机械验证项 / 方案点名 `test-first` 时 | `test-first.md` |
| 超大任务决策点地图 | `decision-map.md` |
| 只能人做的步骤（凭证 / 授权 / 后台） | `human-wizard.md` |
| 外部事实 / API / 文档调研（开子窗） | `research-task.md` |
| 用户点名「外仓对照」；加载 ≠ 启用；PM 提示 ≠ 启用；禁止每窗必搜 GitHub | `external-compare.md` |
| AFK 子代理委托书 / 耐久契约 | `agent-brief.md` |
| 需求评估 / 被拒需求去重 | `out-of-scope.md` |
| 设计模块形状 / 找 seam / 接口方案对比（与 `architecture-health-check`「体检找候选」互补；并行接口设计见 `design-it-twice.md`，共用本行） | `codebase-design.md` |
| 进行中的 merge / rebase 冲突时 | `resolving-merge-conflicts.md` |
| 方案阶段状态 / UI 设计问题需运行验证时 | `prototype.md` |
| 临时交接 / 轻量传话时 | `handoff-lite.md` |
| 沟通未落地（用户「没听懂 / 再说一遍」）时 | `wait-what.md` |
| 用户点名教学（「教我 X / 带我学 X」）时 | `teach.md` |
| 需求模糊 / 访谈 / grill（需求切片未定、澄清仍分歧时） | `demand-clarification.md`（§grill 访谈） |
| 仍无法证实时 / 不确定则停时 / 确认包·转场前读 open 知识缺口条目 | `knowledge-gap.md` |
| 设计模式症状 / Mandatory 写模式 / 点名 design-patterns 词条 | `design-patterns.md` |
| 高危/止损/跨模块大改/用户点名分歧实验 · 策划或改码前 epistemic 分歧 | `divergence-annotation.md` |
| 用户点名「完整碰撞」**或**（止损触顶/将到 2/3 / 热度爆炸 **且** 确认包选用碰撞）；加载 ≠ 启用；禁止把「止损/热度」单独当启用 | `collision-review.md` |
| 用户点名「逆链」**或**（高危/止损且方案声明启用逆链）；加载 ≠ 启用；禁止每窗必加载 | `reverse-chain.md` |
| 结案归档（completed/失败封存+migrate）且窗内有改前选型三格 **或** 用户点名「逆向总结典故」；加载 ≠ 每个归档必加载；空闲枢纽迁签收不加载；点名「逆向总结」≠启用逆链 | `reverse-allusion.md` |
| 签收或 runtime-validated 抽出可复用结构且对仓三档=有真锚点 **或** CR 发现本仓已有结构、表里没有 **或** 用户点名「模式沉淀」；加载 ≠ 静默入表；Express / 空闲枢纽不加载；点名「模式沉淀」≠启用逆链 | `pattern-harvest.md` |
| 写 ≥2 Step 契约 **或** 点名「电路子窗」；**加载 ≠ 减审**；Express / 单 Step 不加载 | `circuit-windows.md` |
| 跨项目沉淀 / 收集仓 / shareable 队列 | `collect-queue.md` |
| 7 天卡住 / 质量趋势停点 | `long-task.md` |
| 压缩重派 / 跨会话续作账本 | `loop-engineering.md` |
| 覆盖度 / 读过测过失败过 / 禁止自报覆盖率 | `coverage-map.md` |

## 按岗加载

- **策划/方案审**：当前缺口优先在 `acceptance-and-delta`、`doc-windowing`、`diagnosis-gates`、`execution-discipline`（复用四问）中点名 1～2 份；术语歧义加 `shared-language`；Full 策划前可加 `architecture-health-check`；接口设计 / 找 seam / 方案对比加 `codebase-design`；超大任务可加 `decision-map`。主窗派调研子窗加 `research-task`；用户点名「外仓对照」加 `external-compare`（加载 ≠ 启用）；有「只能人做」的步骤加 `human-wizard`。
- **程序员**：优先 `unity-editor-log`；Auto/修复计数需要时加 `loop-engineering`；精简/净增加 `execution-discipline`（或 project-context 止血节）；test-first（含可机械验证项默认启用；方案点名强制）。
- **代码审核**：优先 `codegraph-probe`；派发或隔离问题时二选一加载 `review-dispatch-lifecycle` / `isolated-review`；双轴模式加 `dual-axis-review`；seam / 设计相关评审加 `codebase-design`。
- **文档/周报**：只读岗位 SKILL 点名的 README/周报规则，不因“参考完整”扫目录。

## 维护者专用

`MAINTAINER.md`、`skill-eval-checklist.md`、脚本说明、模板与反模式全表仅在维护/发布/评测任务按需读取；日常业务实现不加载。

## 禁止

- `Read/Glob references/**` 后逐份展开；把全部 references 塞进派发/system prompt。
- 用“基线”替代真实代码、当前方案、Mandatory、README 风险段或回归索引。
- 为凑“≤2”隐瞒硬约束；正确做法是说明理由并替换/短暂超额。
