---
description: AI 开发流水线 — 当前版本见 skills/VERSION。先读常驻卡，再只读这一刀的一张车道卡
alwaysApply: true
---

# AI 开发流水线 Skills（当前版本见 `skills/VERSION`）

**入口**：仓库里有 [resident.md](../skills/references/resident.md) 时，先读这一份，再只读这一刀的一张路由卡（`lane-express.md` / `lane-direct.md` / `lane-standard.md` / `lane-full.md`）。人点名「Auto车道」才读 `lane-auto.md`，不把它算进路由。助手自己写上这句不算。不必先说「项目经理」或「PM」。不读其余卡。已经说出改哪一行、改成什么的读 Express。人没点名不读 `lane-auto.md`。除此之外，停在 Express 时不再打开 `skills/` 里的其它文件，不读 human-voice、项目说明。CORE 全文仅争议 / recovery / `按 CORE 重来`。问句先答。Express 里用户已经说出改哪一行，主窗自己读、自己改。直通也由主窗自己改，改完派隔离审核。普通 Standard L1 允许主窗同会话复核并标「非独立 CR」；Direct、Standard L1.5/L2、Full 和高风险 CR 按隔离规则处理。隔离审核子窗只读派发白名单，不读 resident、human-voice、project-context。离开 Express 之后，对人说的话先读 [human-voice.md](../skills/references/human-voice.md)。命令、路径、表头、周报骨架不改口吻。隔离审核子窗不读 human-voice。

**硬门禁 #7**：问句不改文件。标准道和完整道仍先有方案再改代码。离开 Express 之后，改代码前先读 **`.cursor/project-context.md`** 的「先读哪一节」（若存在），再读表里点名的节。停在 Express 不读。

**子窗模型**：派 Task 前按 project-context 的模型路由写 `model=`。禁止无理由省略。Unity 测、新开对话、换模型只提示，不替人校验。
