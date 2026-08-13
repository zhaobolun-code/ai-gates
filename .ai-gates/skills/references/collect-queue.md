# 收集仓（本地 shareable 队列）

> evolution-01 机制 C **本地默认**。原 gh issues 收集仓方案**未在本仓验证**，禁止写成已接线。跨项目闸（evolution-03-promote）depends-on 本机制落地，未通前禁止假装已通。

## 定位

跨项目 / 跨会话可传递的条目收集仓。

**不是**：知识缺口（不知道 → `_knowledge-gap.md`）、lessons pending（错题）、`evolution-candidates.yaml`（机器候选）。三者禁止混表。

## 默认载体

`.ai-gates/collect-queue.md`（markdown 表，可检索）。空仓合法。本文件在 `.ai-gates/`（不入 git）= 本机队列。

## 三态

| 态 | 含义 |
| --- | --- |
| `draft` | 草稿（未确认可传） |
| `shareable` | 可传（允许复制/导出） |
| `promoted` | 已晋升引用 |

## 可传

允许把 `shareable` 行复制 / 导出到其他项目的同名队列文件。导出须在实现拍本窗 `证据/` 留一行（本步可只写规则，不必真导出）。

## 不可静默删

禁止钩子 / 脚本自动删行；删行须用户确认。无自动 GC。

## 入队

人工提名，或 01-B 候选经**用户确认**后写入。禁止扫主表 / `evolution-candidates.yaml` 自动入仓。禁止「准」自动入仓。

## gh（可选，非默认）

1. 探测：`gh auth status`（及 `gh --version`）。
2. 仅 exit 0 时，**可**写「本机可选用 gh issue 作跨机出口」。
3. 探测失败或未跑：**禁止**出现「gh 已接线」陈述。
4. **禁止**把「准」映射为 `gh issue create`。建 issue 须单独用户口令（≠「准」）。

本窗未将探测成功作为落地前提；默认出口始终是本地队列。

## 禁止

- 平行第二套队列
- lessons pending 混表
- cron 同步 GitHub
- 未限定探测成功的句子里写「gh 已接线」
- 把「准」写成 `gh issue create` 或自动入仓触发器
