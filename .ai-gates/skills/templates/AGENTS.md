# AI 开发流水线（本仓库）

> 技能包唯一真源在 `.ai-gates/`（本地真源，不入 git；Cursor / Trae / Codex 共用同一份）；本文件是 Codex 的常驻入口路由；Cursor 侧对应 `.cursor/rules/ai-dev-pipeline.mdc`。
> `.cursor/`、`.codex/`、`.trae/` 未被 git 跟踪（见 `.gitignore`），它们是通往 `.ai-gates/` 的传送门（软连接）。**clone 后先跑** `powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1`（Unix：`bash .ai-gates/link-platform.sh`），传送门就位后 `.cursor/skills/...`、`.codex/...` 等路径即可照常使用；项目专属文件（`.cursor/project-context.md` 等）保留在 `.cursor/` 真实目录。

## 入口

- 仓库里有 `.ai-gates/skills/references/resident.md` 时，先读这一份。不必先说「项目经理」或「PM」。
- 初始化说 `初始化`（=`init`）。升级技能包说 `升级 ai-gates`。体检说 `检查健康`（=`doctor`）。同意说 `准`（=`approve`）。
- 问句先答，不改文件。Express 里用户已经说出改哪一行，主窗自己读、自己改。消息带「Auto车道」才走 auto 车道。标准道和完整道仍先有方案再改代码。
- 恢复口令：`按 CORE 重来`（= 流水线重来 / 没按流程来）。

## 必读顺序

当前版本是 `6.0.0`。

1. `.ai-gates/skills/references/resident.md`
2. 再只读这一刀的一张车道卡：`lane-express.md` / `lane-auto.md` / `lane-direct.md` / `lane-standard.md` / `lane-full.md`。不读其余车道卡。停在 Express 时不再打开其它 `skills/`。消息带「Auto车道」才读 `lane-auto.md`。
3. 标准道和完整道用到才打开那一份：`read-evidence`、`run-evidence`、`log-evidence`。Express、问句、直通由主窗自己读、自己搜、自己跑、自己改。直通改完派隔离审核，审核窗只读派发白名单。

离开 Express 之后，派子窗前读 `.cursor/project-context.md` 的「先读哪一节」，再读表里点名的节。不把整份项目说明装进每轮。派发只写岗位、轮次、派发文件路径。不贴哈希算法、预期哈希、blocker 原文、岗位卡。子窗交回只留三行。实现子窗自己读岗位卡。隔离审核子窗只读派发白名单。

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

没有项目说明时，按常驻卡。要补项目说明，说「初始化」。

## 工作区卫生

一次性中间产物只放 `.ai-gates/tmp/`。细则见 `execution-discipline.md` 的工作区卫生。

## Codex 钩子

`apply_patch` 这道门不覆盖 Bash 里的写入。显式写文件另有 shell 门。桌面端拦截未证实。事件和各端是否真拦，见 `.ai-gates/skills/references/hook-gates.md`。
