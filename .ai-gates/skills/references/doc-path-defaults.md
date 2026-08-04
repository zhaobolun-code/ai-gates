# 文档路径 — 默认规则（通用）







> **权威来源**：所有岗位创建/保存流水线**产出文档**时遵守本规则。



> **窗口化 / 未完成·已完成 / 审核禁读归档** → [doc-windowing.md](./doc-windowing.md)（降 token）。



> **不含**：岗位 Skill 文件本身（推荐 `.cursor/skills/`，亦可用 `~/.cursor/skills/`；`.cursor/rules/` 须能 Read 到 CORE）。







## 三条规则（按优先级）







| 优先级 | 条件 | 路径 |



| --- | --- | --- |



| **1** | 用户在本轮对话**明确指定**文档/保存路径 | **按用户路径**（可含文件名）；其下仍须用规范文件名 |



| **2** | `.cursor/project-context.md` **显式覆盖**文档根（§执行文档存放约定） | **按 project-context**（本仓库 Chemical 已覆盖为 `化学文档/压力系统/`） |



| **3** | 以上皆无 | **`Assets/Doc/`**（通用 Skill 默认） |







## 默认：一方案一文件夹







用户未指定且无 project-context 覆盖时，新建 Standard/Full 方案：







```text



Assets/Doc/{主题}/{方案短名}/



  未完成.md



  已完成/



    _索引.md



  物理口径.md          （可选）



  证据/                （可选）



```







本仓库（Chemical）未指定时等价于：

```text
Assets/LabSDK/Runtime/Pennon/ExplorationLab/化学文档/压力系统/
  执行中/{方案短名}/          ← 新建 / 进行中（禁止停放空闲）
  签收/{方案短名}/            ← 结案；或空闲枢纽（无活跃 Mandatory）
  失败|回退|停写|换层/{方案短名或legacy文件}/
```







- **不存在则创建**（含状态分类夹与中间目录）。



- **新建** Standard/Full：默认 `{文档根}/执行中/{方案短名}/`（用户另指定除外）。



- **状态变更**：迁入对应分类夹（规则权威 → [doc-windowing.md](./doc-windowing.md) §状态分类夹）；**失败与止损合并为「失败」**。



- **方案夹名不加状态前缀**（禁止 `签收-xxx` 代替分类夹）。



- **活跃窗口固定名**：`未完成.md`（实现/审核默认只读此文件 + 可选 `物理口径.md`）。



- **窗内归档固定名**：`已完成/`（默认禁读全文；仅可扫 `_索引.md`）。



- **周报**：`Assets/Doc/Weekly/` 或方案文件夹内（除非 project-context 另写）。



- 细则与迁移/读权限 → [doc-windowing.md](./doc-windowing.md)。







## 各岗位速查







| 岗位 | 行为 |



| --- | --- |



| **策划** | 新建：用户路径 > project-context 根 > `Assets/Doc/{主题}/执行中/{方案短名}/未完成.md`；完成 Step 后迁入 `已完成/` |



| **周报** | 用户路径 > 方案目录 > `Assets/Doc/Weekly/` |



| **项目经理** | 派发时给到**文件夹 + 未完成.md**；隔离审派发须带阅读白名单 |



| **方案审 / CR** | 默认禁读 `已完成/**` 与 `证据/**` 全文 |







## 与 `.cursor/project-context.md` 的关系







- 无覆盖时：本文件 + doc-windowing。



- **有覆盖时**：以 project-context 的文档根为准；**文件夹与 `未完成.md`/`已完成/` 命名规则仍强制**。



- 非 Unity 项目可改根目录，不得取消窗口化。



- **禁止**把项目专属长路径写进通用岗位 Skill 正文；只写在 project-context。







## 禁止







- 在通用 Skill 中写死 `Assets/LabSDK/...` 等项目专属路径（举例可放 project-context / 本文件「本仓库」段）



- 把岗位 Skill 移到 `Assets/Doc/`



- 用户已指定路径时仍擅自改根



- 有 project-context 覆盖时仍默认落到 `Assets/Doc/{主题}/`（压力系统方案）



- 新建单文件长方案却不建方案文件夹（历史文件除外，下次统筹须拆分）



