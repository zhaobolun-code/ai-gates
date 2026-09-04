# 项目经验沉淀 / 错题本（项目专属）

> **位置**：复制本模板 → 仓库根 **`.ai-gates/lessons-learned.md`**。  
> **大纲**：复制 [lessons-outline.md](./lessons-outline.md) → `.ai-gates/lessons-outline.md`。  
> **何时追加/查阅**：见 [references/lessons-learned.md](../references/lessons-learned.md)。

## 记录表

| 日期 | 模块 | 教训（一句话） | 来源 | 关联文档 | 最近命中 | 类型 | 症状关键词 | 错因 | 改正 | 防再发 | 作用域 | 晋升 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | 示例模块 | 示例：判定口径与常量单位不一致 | 代码审核 | 路径 | YYYY-MM-DD | CR blocker | 单位,阈值 | 用错单位量级做阈值 | 改用同单位同源常量 | CR 反推同类混用 | 示例模块 | |

类型：`方案blocker` / `CR blocker` / `运行时bug` / `自引入bug` / `Skill流程` / `成功经验`。旧行新列可空；**新行必填错因、改正**。

## 用法

- **策划**：先扫 `.ai-gates/lessons-outline.md` → 主表；方案写「## 错题本必读（给程序员）」
- **测失败**：**自动**写方案夹 `## 错题 L0 草稿`（禁写主表）
- **可晋升时**：**自动**写 `证据/_lesson-pending.md`（含 cause/fix）；主窗问「准」
- **用户「准」**：`commit-lesson-pending.ps1 -Apply`；禁静默写主表；高频补大纲
- **时效**：最近命中 > 6 个月可标 `[低活跃]`
