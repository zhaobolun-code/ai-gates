# 共享语言 / 领域词汇表（活文档）

> 触发：方案、Mandatory、CR 或代码中出现术语歧义 / 同一概念多个叫法 / 中文词与代码符号对不上。
> 出处：mattpocock/skills 的 grill-with-docs / domain-modeling（共享语言 + ADR），2026-08-07 对照落地。

## 原则

1. 术语以**可观察现象 / 代码符号**为准，不以「顺口」为准；一条术语 = 一个概念，禁止同义异名在方案里并行。
2. 词汇表是**活文档**：策划在方案里首次使用新术语时登记；方案审 / CR 发现歧义时登记或改判；程序员不得私下改名。

## 放哪里

- 项目级：`.cursor/project-context.md` §领域词汇表（每项目一份，模板见 `../project-context.template.md`）。
- 方案级：仅当术语是本次方案引入且项目表未覆盖时，写进 `未完成.md`「链接」节（一行指向项目表 + 新增行），结案收敛时归并回项目表。
- 通用 Skill 不写死业务术语（见 [project-local-config.md](./project-local-config.md)）。

## 登记格式

| 术语 | 定义（可观察 / 可证伪） | 对应代码符号 | 别名（禁） |
| --- | --- | --- | --- |
| [术语] | [现象/行为，一句话] | [类/方法/字段] | [同义异名，禁止再用] |
| Direct（直通道） | **车道**语义（四车道之一）：行为小改（≤3 文件、无 API/持久/跨模块）、策划子窗对话内出 A#/切片**不落盘**、单会话完成；跨会话/改不完自动升 Standard | `CORE.md` §四车道判定 步骤 2；PM YAML `lane: Direct` | 「轻量模式」等 v1 旧称 |
| 双轨调用 | 技能/文档的**调用权限**维度：岗位 SKILL=user-invoked（口令触发，模型不得自动执行岗）；references=model-invoked（触发表按触发自动加载） | `agents/openai.yaml` 的 `policy.allow_implicit_invocation`；`reference-routing.md`「模型自动触发」小表 | 「双轴」（CR 规范轴/规格轴，`dual-axis-review.md`）；「Direct/直通道」（车道语义，`lane-glossary.md`） |

> 「Direct（直通道）」（[CORE.md](../CORE.md) 判定树步骤 2 的车道语义）与「双轨调用」（[reference-routing.md](./reference-routing.md) 的调用权限维度）、「双轴」（[dual-axis-review.md](./dual-axis-review.md) 的 CR 规范轴/规格轴审查维度）、「深模块」（[codebase-design.md](./codebase-design.md) 的设计维度）**不是同一概念**：前者回答「PM 判哪个车道」，后三者分别回答「谁能自动启用该技能/文档」「CR 从哪两个维度审查」「模块接口怎么设计」；禁止混用。

## 争议处理

术语冲突时：主窗 PM 定夺 → 改项目表 → 该术语相关 Step 的 Mandatory 同步；禁止同一 Step 内两套叫法并存（CR 视为 **major**）。
