# AI 开发流水线 Skill - 打包信息

- 版本：以 skills/VERSION 为准
- 打包日期：打包装时由 package-release.ps1 写入当天日期。最近已发布的包是 releases/ai_dev_v6.0.1.7z，日期 2026-11-27。
- 来源：本包由 .ai-gates/package-release.ps1 从中央技能库生成，仅含随 Skill 分发的通用文件。

## 本包不含（按设计，维护者专属）

- MAINTAINER.md：版本升级策略、RC 转正条件、发布检查清单，含源仓库专属的审计记录，不通用
- 项目词条本仓验证：`.ai-gates/design-patterns.project.md` 不进包；进包的 skills/references/design-patterns.md 为空表手续
- 错题本 / 口诀本：.ai-gates/lessons-*.md、.cursor/project-context.md 本就不拷

## 本包含变更历史

- CHANGELOG.md：随包分发，便于公开仓/Release 增信与接入方对照版本。

维护策略与发布清单仍以源仓库 MAINTAINER.md 为准；本包已随附 references/skill-eval-checklist.md（迷你 Harness，可直接用于新项目自测）。

## 首次接入新项目

1. 解压本包到目标仓库根：包顶层 = 中央技能库 .ai-gates/ 的内容（skills/、hooks/（含 hooks/codex、hooks/claude、hooks/copilot 与 hooks/plugin）、scripts/（含 fog-map.template.html）、rules/、codex/、claude/、link-platform.* 等），无需额外嵌套
2. 在 Agent 窗口说「升级 ai-gates」（=upgrade），由 Agent 建好传送门（自动建 .cursor/*、.codex、.claude、.trae/skills 软连接；手动运行 .ai-gates/link-platform.ps1 亦可，非必需）
3. 先读 .ai-gates/README.md（30 秒看懂 + 安装）→ .ai-gates/USER-GUIDE.md（口令与第一次接入）→ 需要时再读 .ai-gates/METHODOLOGY.md（为什么这么设计）
4. Codex 用户：按源仓库示例创建根级 AGENTS.md（入口路由；本包不含，项目相关），再在 Agent 说「初始化」（=init）。检查健康说「检查健康」（=doctor）。同意说「准」（=approve）。填写 project-context 后直接说要做的事

## 预期（避免「不好用」）

- 不是万能药：每步仍要人验收；须自建项目说明（project-context）
- 入口是直接说要做的事。不必先说「项目经理」
- 复杂问题仍可能失败并归档——那是叫停换路，不是流程坏了

版本号以 skills/VERSION 为准；变更摘要见 CHANGELOG.md（包根）。
