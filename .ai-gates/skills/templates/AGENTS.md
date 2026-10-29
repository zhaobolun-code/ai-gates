# AI 开发流水线（本仓库）

> 技能包唯一真源在 `.ai-gates/`（本地真源，不入 git；Cursor / Trae / Codex 共用同一份）；本文件是 Codex 的常驻入口路由；Cursor 侧对应 `.cursor/rules/ai-dev-pipeline.mdc`。
> `.cursor/`、`.codex/`、`.trae/` 未被 git 跟踪（见 `.gitignore`），它们是通往 `.ai-gates/` 的传送门（软连接）。**clone 后先跑** `powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1`（Unix：`bash .ai-gates/link-platform.sh`），传送门就位后 `.cursor/skills/...`、`.codex/...` 等路径即可照常使用；项目专属文件（`.cursor/project-context.md` 等）保留在 `.cursor/` 真实目录。

## 入口

- 用户说「项目经理」/「PM」+ 需求即接入（等价：`项目经理`=`PM`，`初始化`=`init`，`准`=`approve`，
  `升级`=`upgrade`，`检查健康`=`doctor`）。
- 新项目首次：`项目经理 初始化`（=`PM init`）；升级技能包：`项目经理 升级 ai-gates`（=`PM upgrade ai-gates`）；
  体检：`项目经理 检查健康`（=`PM doctor`）。
- 每轮 `[PM]` 先做结构化判定（内部 YAML），对用户只输出白话「你下一步」；回复仍须带 `[PM]` 字面量 YAML（白话可附后，Stop 打点与门禁依赖字面量）。
- 恢复口令：`按 CORE 重来`（= 流水线重来 / 没按流程来）。

## 必读顺序

1. `.ai-gates/skills/references/resident.md`
2. 当前这一张车道卡（`skills/references/` 下的 `lane-express.md` / `lane-direct.md` / `lane-standard.md` / `lane-full.md`）
3. 用到才打开那一份，不把三份全文装进每轮：`read-evidence`、`run-evidence`、`log-evidence`。主窗不自己读、不自己搜、不自己跑、不自己看日志。

派子窗前再读 `.cursor/project-context.md` 的模型路由那一节。回归索引和物理口径派查正文去读。不把整份项目说明装进每轮。派发只写岗位、轮次、派发文件路径。不贴哈希算法、预期哈希、blocker 原文、岗位卡。子窗交回只留三行。岗位卡由子窗自己读。

## 岗位路由（切岗前 Read 对应 SKILL.md）

| 口令 | 岗位 SKILL.md |
| --- | --- |
| 策划 / 写方案 / 执行文档 | `.ai-gates/skills/planner/SKILL.md` |
| 方案审核 / 审方案 | `.ai-gates/skills/plan-reviewer/SKILL.md` |
| 程序员 / 做 Step N / 按方案实现 | `.ai-gates/skills/developer/SKILL.md` |
| 代码审核 / 审代码 | `.ai-gates/skills/code-reviewer/SKILL.md` |
| 文档 / 更新 README | `.ai-gates/skills/module-readme/SKILL.md` |
| 周报 | `.ai-gates/skills/weekly-report/SKILL.md` |
| 查日志（主窗要看日志时派子窗，不自己读原文） | `.ai-gates/skills/log-evidence/SKILL.md` |
| 查正文（主窗要看代码或文档时派子窗） | `.ai-gates/skills/read-evidence/SKILL.md` |
| 跑命令（主窗要跑终端时派子窗） | `.ai-gates/skills/run-evidence/SKILL.md` |

## 硬门禁

见常驻卡和当前这一张车道卡。车道卡第 1 步仍是扫错题大纲。

## 冷启动

没有项目说明时，按常驻卡的选车道顺序。要改代码先说「项目经理 初始化」。

## 工作区卫生

一次性中间产物只放 `.ai-gates/tmp/`。细则见 `execution-discipline.md` 的工作区卫生。

## Codex 钩子

`apply_patch` 这道门不覆盖 Bash 里的写入。显式写文件另有 shell 门。桌面端拦截未证实。事件和各端是否真拦，见 `.ai-gates/skills/references/hook-gates.md`。
