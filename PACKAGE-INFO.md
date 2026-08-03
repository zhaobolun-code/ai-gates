# AI 开发流水线 Skill - 打包信息

- 版本：v3.2.0
- 打包日期：2026-08-03
- 来源：本包由 .cursor/package-release.ps1 从源仓库生成，仅含随 Skill 分发的通用文件。

## 本包不含（按设计，维护者专属）

- MAINTAINER.md：版本升级策略、RC 转正条件、发布检查清单，含源仓库专属的审计记录，不通用

## 本包含变更历史

- CHANGELOG.md：随包分发，便于公开仓/Release 增信与接入方对照版本。

维护策略与发布清单仍以源仓库 MAINTAINER.md 为准；本包已随附 references/skill-eval-checklist.md（迷你 Harness，可直接用于新项目自测）。

## 首次接入新项目

1. 解压本包到目标仓库的 .cursor/ 下（无需额外嵌套一层 .cursor）
2. 先读 skills/METHODOLOGY.md（预期）→ skills/TEAM-GUIDE.md（口令）→ skills/README.md（第一次接入）
3. 在 Agent 粘贴「项目经理 初始化」（项目经理=PM，初始化=init），填写 project-context 后再提需求（日常入口：项目经理 + 需求）

## 预期（避免「不好用」）

- 不是万能药：每步仍要人验收；须自建项目说明（project-context）
- 入口固定为「项目经理 + 需求」；跳过容易乱
- 复杂问题仍可能失败并归档——那是叫停换路，不是流程坏了

版本号以 skills/VERSION 为准；变更摘要见 skills/CHANGELOG.md。
