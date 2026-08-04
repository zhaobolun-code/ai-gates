# AI 开发流水线 Skill - 打包信息

- 版本：v3.2.1
- 打包日期：2026-08-04
- 来源：本包由 .ai-gates/package-release.ps1 从中央技能库生成，仅含随 Skill 分发的通用文件。

## 本包不含（按设计，维护者专属）

- MAINTAINER.md：版本升级策略、RC 转正条件、发布检查清单，含源仓库专属的审计记录，不通用

## 本包含变更历史

- CHANGELOG.md：随包分发，便于公开仓/Release 增信与接入方对照版本。

维护策略与发布清单仍以源仓库 MAINTAINER.md 为准；本包已随附 references/skill-eval-checklist.md（迷你 Harness，可直接用于新项目自测）。

## 首次接入新项目

1. 解压本包到目标仓库根：包顶层 = 中央技能库 .ai-gates/ 的内容（skills/、hooks/、scripts/、rules/、codex/、link-platform.* 等），无需额外嵌套
2. 跑一次传送门脚本：powershell -ExecutionPolicy Bypass -File .ai-gates/link-platform.ps1（macOS/Linux：bash .ai-gates/link-platform.sh）——自动建 .cursor/*、.codex、.trae/skills 软连接
3. 先读 .ai-gates/METHODOLOGY.md（预期）→ .ai-gates/USER-GUIDE.md（口令）→ .ai-gates/SKILLS.md（第一次接入）
4. Codex 用户：按源仓库示例创建根级 AGENTS.md（入口路由；本包不含，项目相关），再在 Agent 粘贴「项目经理 初始化」（项目经理=PM，初始化=init），填写 project-context 后提需求

## 预期（避免「不好用」）

- 不是万能药：每步仍要人验收；须自建项目说明（project-context）
- 入口固定为「项目经理 + 需求」；跳过容易乱
- 复杂问题仍可能失败并归档——那是叫停换路，不是流程坏了

版本号以 skills/VERSION 为准；变更摘要见 skills/CHANGELOG.md。
