# 共享语言 / 领域词汇表（活文档）

> 触发：方案、Mandatory、CR 或代码中出现术语歧义 / 同一概念多个叫法 / 中文词与代码符号对不上。
> 出处：mattpocock/skills 的 grill-with-docs / domain-modeling（共享语言 + ADR），2026-08-07 对照落地。

## 原则

1. 术语以**可观察现象 / 代码符号**为准，不以「顺口」为准；一条术语 = 一个概念，禁止同义异名在方案里并行。
2. 词汇表是**活文档**：策划在方案里首次使用新术语时登记；方案审 / CR 发现歧义时登记或改判；程序员不得私下改名。
3. **典故 = 验证智慧的压缩**：典故词是**经方案审 / CR / 验收验证过的既定共识**的压缩包，提词即唤起、不必复述全文；本质是**可信共识的压缩**，不是省 token 的摘要——摘要未经验证、可能失真，禁止拿典故词当『顺手缩写』用。

## 放哪里

- 项目级：`.cursor/project-context.md` §领域词汇表（每项目一份，模板见 `../project-context.template.md`）。
- 方案级：仅当术语是本次方案引入且项目表未覆盖时，写进 `未完成.md`「链接」节（一行指向项目表 + 新增行），结案收敛时归并回项目表。
- 通用 Skill 不写死业务术语（见 [project-local-config.md](./project-local-config.md)）。
- 通用典故（流水线共识）登记在本文件典故节；项目级典故（业务域共识）按模板 `project-context.template.md` §领域词汇表登记在 `.cursor/project-context.md`——本仓 project-context.md 当前无该节，本次不补（项目专属文件不在本窗交付物范围），故以模板出处表述。

## 登记格式

| 术语 | 定义（可观察 / 可证伪） | 对应代码符号 | 别名（禁） |
| --- | --- | --- | --- |
| [术语] | [现象/行为，一句话] | [类/方法/字段] | [同义异名，禁止再用] |
| Direct（直通道） | **车道**语义（四车道之一）：行为小改（≤3 文件、无 API/持久/跨模块）、策划子窗对话内出 A#/切片**不落盘**、单会话完成；跨会话/改不完自动升 Standard | `CORE.md` §四车道判定 步骤 2；PM YAML `lane: Direct` | 「轻量模式」等 v1 旧称 |
| 双轨调用 | 技能/文档的**调用权限**维度：岗位 SKILL=user-invoked（口令触发，模型不得自动执行岗）；references=model-invoked（触发表按触发自动加载） | `agents/openai.yaml` 的 `policy.allow_implicit_invocation`；`reference-routing.md`「模型自动触发」小表 | 「双轴」（CR 规范轴/规格轴，`dual-axis-review.md`）；「Direct/直通道」（车道语义，`lane-glossary.md`） |
| 并行实现 | 实现层并存路径（同一可观察行为 ≥2 条执行链并存）：互斥 / 降级 / 收敛定义须在 Mandatory/CR 写明 | diagnosis-gates §2.3「并行实现一句」/ §3「并行实现收敛闸门」（流程对象） | 旧词形已全部并入本词（清单见审计决策表 #1 / audit-double-meaning.md） |
| 门闸 | 代码路径判断点（放行 / 拦截 / 就绪信号所在处，如 `*_not_ready` 信号） | diagnosis-gates §0.8 预扫链「跳」；与「调用边」成对使用 | 旧词形已并入本词（清单见审计决策表 #2 / audit-double-meaning.md） |
| 瘦身一拍 | 交审前删本 Step 新写/整段重写代码冗余（删除 ≥ 新增）；与技能包「收敛与精简」区分（v3.2 文档精简） | developer SKILL §2.1「瘦身一拍」；project-context 补强三口 | — |

> 「Direct（直通道）」（[CORE.md](../CORE.md) 判定树步骤 2 的车道语义）与「双轨调用」（[reference-routing.md](./reference-routing.md) 的调用权限维度）、「双轴」（[dual-axis-review.md](./dual-axis-review.md) 的 CR 规范轴/规格轴审查维度）、「深模块」（[codebase-design.md](./codebase-design.md) 的设计维度）**不是同一概念**：前者回答「PM 判哪个车道」，后三者分别回答「谁能自动启用该技能/文档」「CR 从哪两个维度审查」「模块接口怎么设计」；禁止混用。
> 门闸 ≠ 诊断闸门：「门闸」是代码路径判断点（预扫链「跳」），「诊断闸门」是流程检查点（diagnosis-gates.md 文档节），成对消歧、非同义。
> 止血 / 复用四问 / 瘦身一拍：三词不同机制（神类增长控制 / 写前复用检视 / 交审前精简），同段出现按角色语境取义；压缩包见「典故」节 4 词条，本节不重复。

## 争议处理

术语冲突时：主窗 PM 定夺 → 改项目表 → 该术语相关 Step 的 Mandatory 同步；禁止同一 Step 内两套叫法并存（CR 视为 **major**）。

## 典故

辨析表回答「一个概念一个词，防同义异名」；典故节回答「一个词唤起一整段既定共识」；辨析表保留不动。

| 典故词 | 压缩包（提词即唤起、不必复述的全文） | 触发 |
| --- | --- | --- |
| 神类止血 | 神类（如 PressureManager Controller partial）禁堆逻辑：新逻辑默认落 `*Service` + Controller 一行委托；净增阈（单文件新增−删除 >80 或新增 >120）须落点改写或同窗 REMOVED；新/重写方法体 ≤40 行；Mandatory 用替换句式（仅追加无下沉 → 方案审 major/blocker）；交审前瘦身一拍。出处：`.cursor/project-context.md` §PressureManager 神类止血 | 方案/CR 触及神类文件时点名即唤起，不复述阈值 |
| 复用四问 | 已有吗→能复用吗→能少写/不写吗→能删吗；写 Mandatory 前强制，未检索不得写新路径。出处：`.ai-gates/skills/references/execution-discipline.md` §复用四问 | 写方案/改码/扩 README 前点名即唤起 |
| 双轴 | CR 从两维审：规范轴 = 与仓库规范一致性（CORE / 岗位 SKILL / README 硬约束，应当怎么写）；规格轴 = 与本次规格一致性（A# 覆盖未越界 / Delta Spec 落实 / DO NOT TOUCH 未碰，这次要做什么）；findings 按轴分组输出。出处：`.ai-gates/skills/references/dual-axis-review.md`（与「双轨调用」「Direct」是不同维度，见辨析注记） | CR 场景点名即唤起 |
| 深模块 | Depth 是接口属性非实现属性；Interface=调用者须知一切；Seam 位置是独立设计决策；删除测试；一个 adapter=假设的 seam、两个=真的；词汇 8 词逐词禁止漂移。出处：`.ai-gates/skills/references/codebase-design.md` | 设计模块形状/找 seam/接口方案对比时点名即唤起 |

**漂移防护**：典故词条禁止静默改义——压缩包内容或触发语义变更，须更新登记表对应行并同步引用文档（与 §争议处理 同构：主窗 PM 定夺 → 改表 → 相关文档同步）；口头改义不落表 → CR 视为 major。
