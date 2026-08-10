# 多会话教学（teach）

> 触发：用户主动点名「教我 X / 带我学 X」时自动加载；教学是用户驱动的会话态，与流水线岗位严格区分，禁止自动进入。
> 出处：mattpocock/skills teach（2026-08-07 对照落地）；单 reference 内嵌结构摘要，不复制上游三份格式文件。

## 启用与边界

- 仅用户主动要求「教我 X / 带我学 X」时启用；不因话题内容自动切教学态。
- 教学工作区**独立于 Unity 工程**、放用户指定位置；不向 Unity 工程引入任何工具链依赖。

## 工作区结构

| 文件 / 目录 | 用途 |
| --- | --- |
| `MISSION.md` | 学习使命（理由），锚定所有教学 |
| `RESOURCES.md` | 高信任资源清单 |
| `learning-records/` | 学习记录（类似 ADR：非显然教训、可修订） |
| `lessons/` | 单课产物（HTML 或 Markdown），一课一文件、小而可完成 |
| `reference/` | 速查 / 参考材料（可打印、供快速查阅） |
| `assets/` | 复用组件（见下） |
| `NOTES.md` | 用户偏好速记 |

## assets 复用默认

可复用组件进 `assets/` 并在单课中链接；**首组件为共享样式表**——每课链接它，课程像一门一致课而非一堆一次件。新组件可被未来课程复用时写成 `assets/` 组件再链接，**禁止逐课内联未来会重复的代码**。

## 三要素

- **知识**：来自高信任资源；先充实 RESOURCES.md，不依赖参数化知识。
- **技能**：互动反馈环——紧密、即时（理想自动）的反馈。
- **智慧**：真实社区——引导用户到现实世界实践处，不代替。

## 记忆机制

区分 **fluency strength**（当下提取顺畅）与 **storage strength**（长期保留）；用合意困难建 storage：
- retrieval practice（凭记忆提取）
- spacing（拉长练习间隔）
- interleaving（混合相关主题练习，仅技能练习用）

## ZPD

读 `learning-records/` 算最近发展区；每课在 ZPD 内、小而可完成、锚定 MISSION、给出一手资源引用。教学文档同样过 [skill-eval-checklist.md](./skill-eval-checklist.md) 写作三律，不因教学态豁免。
