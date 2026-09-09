# AI 开发流水线（ai-gates 技能库）

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

1. `.ai-gates/skills/references/agent-entry-route.md`（日常入口）
2. `.ai-gates/skills/CORE.md`（权威规则；争议 / recovery / 按 CORE 重来 时读全文）
3. `.cursor/project-context.md`（改代码前必读；含 Codex 模型映射）
4. 当前岗位 `.ai-gates/skills/<岗位>/SKILL.md`（按 checklist 执行）

## 岗位路由（切岗前 Read 对应 SKILL.md）

| 口令 | 岗位 SKILL.md |
| --- | --- |
| 策划 / 写方案 / 执行文档 | `.ai-gates/skills/planner/SKILL.md` |
| 方案审核 / 审方案 | `.ai-gates/skills/plan-reviewer/SKILL.md` |
| 程序员 / 做 Step N / 按方案实现 | `.ai-gates/skills/developer/SKILL.md` |
| 代码审核 / 审代码 | `.ai-gates/skills/code-reviewer/SKILL.md` |
| 文档 / 更新 README | `.ai-gates/skills/module-readme/SKILL.md` |
| 周报 | `.ai-gates/skills/weekly-report/SKILL.md` |

## 硬门禁（摘要；细则见 CORE）

- **无本轮 `[PM]` 判定不得创建/修改交付物**（代码 / 执行文档 / README）；直接叫岗位也必须同条先 `[PM]`。纯问答/只读咨询 → 主窗直接答，不建窗、不生成文档。
- 改代码前必须读 `.cursor/project-context.md`；只实现当前 Step / 切片范围，验收以 A# 为准；Unity 未测不标「已通过」。
- Express 先有一句话切片；Direct 无方案审但须隔离 CR；Standard 先过方案审；CR 有 blocker 不收口、不写最终 README。
- 主窗只当 PM：策划 / 方案审 / 程序员 / CR / 文档优先子代理（Subagent），派发必须显式传 `model=`（Codex 模型映射见 project-context §模型路由；Codex 桌面 0.146 实测：任务须随 spawn 初始消息，`fork_turns=all` 继承父模型、以送达优先并标注，详见 model-routing §Codex 桌面派发实测）；周报例外，当前窗直接做。

## 冷启动

无 `.cursor/project-context.md` 时：纯问答/只读咨询直接答；要改代码 → 提示 `项目经理 初始化`（生成/确认 project-context 后再动），未初始化前默认 Direct（≤3 文件、无 API/存档/跨模块；Express 仅 1 文件机械）；>3 文件或 API/存档/跨模块 → Standard。若 `.ai-gates/skills/CORE.md` 读不到，先跑 `link-platform.ps1`（见头部说明）。

## 工作区卫生（Codex 产生文件的归属）

- 一次性中间产物（调试/探针脚本、临时输出、revision/hash 计算等）→ **`.ai-gates/tmp/`**（不入库；环节收尾整目录清空，与 Cursor/Trae 同规则）。
- hook 机器层运行时证据（pm-gate.json / changelog-writes.json / *.log）→ `.ai-gates/hooks-log/`（证据，勿清理）。
- `.ai-gates/` 是真实目录（库内容 + 运行时中间文件）：临时产物放 `.ai-gates/tmp/`、运行时证据
  放 `.ai-gates/hooks-log/`、验证产物放 `.ai-gates/verify/`、项目状态（lessons-* / pipeline-* /
  regression-index.yaml）放 `.ai-gates/` 根；全部不入 git（`.ai-gates/` 整体不跟踪）。
- Codex 应用级会话暂存（如 `~/.codex/visualizations/...`）留在 app 自有目录即可；若内容需项目内可见/复用，改放 `.ai-gates/tmp/`。
- 细则：`.ai-gates/skills/CORE.md` §工作区卫生 / `.ai-gates/skills/references/execution-discipline.md` §工作区卫生。
- 说明：`.cursor/` 是历史遗留的运行层目录名（gitignored：只保留项目专属 `project-context.md` /
  `mcp.json` / `hooks.json` 与传送门 `skills|hooks|scripts|rules`），**不表示要求安装 Cursor**；
  Codex-only 只需 `.ai-gates/`（库 + 运行时）+ `.codex` 传送门 + 本文件。

## Codex hooks 接线（机器强制层 · 2026-08-04 实测接线）

Codex 侧机械层由 `.codex/hooks.json` + `.codex/config.toml`（传送门 → `.ai-gates/codex/`，
本地中央副本，不入 git）直接指向 `.ai-gates/hooks/codex/*.ps1`（真实路径，不依赖 `.cursor/` 传送门）。
已实测（codex-cli 0.146.0-alpha.9.2）：PreToolUse/PostToolUse 对 `Bash` 与 `apply_patch`
都触发；deny 真正拦截并回显原因；`additionalContext` 注入可达模型。

| 事件 | matcher | 脚本 | 语义 |
| --- | --- | --- | --- |
| SessionStart | — | check-hooks-drift.ps1 | Codex 接线漂移 → additionalContext 提示 |
| PreToolUse | ^Bash$ | pre-bash-gate.ps1（git-safety-check + bash-write-gate） | 高危 Git（push --force / reset --hard / clean -f / checkout -- / branch -D）→ deny 拦截 |
| PreToolUse | ^apply_patch$ | pre-apply-patch-gate.ps1（audit-write + pm-gate-check） | 写审计；无新鲜 `[PM]` → deny（120 分钟窗口，按 session_id） |
| PostToolUse | ^apply_patch$ | post-apply-patch-gate.ps1（mark-changelog-write + check-unity-compile） | Unity 编译错误提示；CHANGELOG 写打点 |
| Stop | — | mark-pm-gate.ps1 | 回复含 `[PM]` → 写 pm-gate.json（Cursor 版 afterAgentResponse 的等价映射） |

用法要点：
- hooks 需要信任：桌面端首个会话会提示信任项目 hooks，批准后才生效；CLI 一次性验证用
  `codex exec --enable hooks --dangerously-bypass-hook-trust`（0.146 中 `codex_hooks`
  是已废弃别名，正名是 `hooks`）。
- 逃生：`.ai-gates/hooks-log/pm-gate-disabled`（kill switch，临时全放行）/ 手动编辑 /
  先发 `[PM]` 待 Stop 打点 / 改 `.cursor` 或 `.ai-gates` 设施先写 CHANGELOG。
- 局限（如实）：门禁覆盖 `apply_patch`（Codex 标准文件写入工具）；经 Bash 的写入
  （如 `Set-Content`）不在此钩子覆盖内（与 Cursor 版只覆盖 Write 工具同类）。**2026-08-05 实测**：
  Codex 桌面应用会话对 `apply_patch` 钩子可能不触发（信任已批准仍零打点）；CLI 侧（0.147.0-alpha.1.2）
  全链路可用。桌面端关键写操作后自查 `.ai-gates/hooks-log/`，或按需用 CLI 真演补机械证据。
