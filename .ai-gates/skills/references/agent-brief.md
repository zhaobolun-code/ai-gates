# Agent Brief（AFK 子代理委托书）

> 触发：需要派 AFK（异步）子代理独立完成一段任务时，按本模板写委托书。来源：mattpocock/skills `triage/AGENT-BRIEF.md`（2026-08-07 对照落地）。
> **派发工件 ≠ AFK 委托书**：`证据/_…派发.md` 是审核白名单工件（见 [review-dispatch-lifecycle.md](./review-dispatch-lifecycle.md)）；本文件是给 AFK 子代理的任务契约；两者按各自规范，不混用。

## 原则

1. **耐久性优于精确**：不写文件路径/行号——会过期；点名接口/类型/行为契约（文件被改名、移动、重构后委托书仍可用）。
2. **行为式不过程式**：写系统该做什么（what），不写怎么实现（how）——子代理会重新探索代码并自行决定实现。
3. **验收标准可独立验证**：每条验收可单独检验，子代理能判断何时完成。
4. **显式 out of scope**：写明不做什么，防止镀金或对相邻功能做假设。

## 模板

```markdown
## Agent Brief

**Category:** bug / enhancement
**Summary:** 一句话说明要做什么

**Current behavior:**
描述现状（bug 写坏行为；enhancement 写被增强的基线）。

**Desired behavior:**
描述完成后应有的行为；写清边界与错误情形。

**Key interfaces:**
- `类型/函数/接口` — 需要改什么、为什么
- 配置形状 — 需要的新配置项

**Acceptance criteria:**
- [ ] 可独立验证的验收 1
- [ ] 可独立验证的验收 2

**Out of scope:**
- 本任务不应触碰的东西
- 看似相关但独立的相邻功能
```

## 反例

### 坏委托书（缺契约）

```markdown
## Agent Brief

**Summary:** 修一下 triage 的问题

**What to do:**
triage 坏了。打开主文件修一下。问题在 150 行附近的函数。

**Files to change:**
- src/triage/handler.ts（第 150 行）
- src/types.ts（第 42 行）
```

坏在：无 Category / 描述含糊 / 写文件路径与行号（会过期）/ 无验收标准 / 无范围边界 / 无当前 vs 期望行为。

### 好委托书（按模板）

```markdown
## Agent Brief

**Category:** enhancement
**Summary:** 让 `SkillConfig` 支持可选的 `schedule` 字段

**Current behavior:**
`SkillConfig` 只有静态字段，无法按时间触发。

**Desired behavior:**
`SkillConfig` 接受可选 `schedule` 字段；缺失时行为与现状一致。

**Key interfaces:**
- `SkillConfig` 类型 — 新增可选 `schedule` 字段
- 校验/处理 `SkillConfig` 的函数 — 透传该字段

**Acceptance criteria:**
- [ ] 无 `schedule` 时现有行为不变
- [ ] 有 `schedule` 时可解析为时间表达式
- [ ] 非法 `schedule` 有明确报错

**Out of scope:**
- 定时执行器本身
- 其它配置字段的改动
```

## 回传四态（what · 行为契约）

委托书要求子代理**最后一条消息 ≤15 行**，**第一行**必须是四态之一（what，不是 how）：`DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`。详情报文件**仅 Standard/Full**（`证据/_Step{NN}-implement-report.md` 或方案夹「实现者报告」）。Direct 只要口头第一行；Express 不加四态。**禁止**要求计划里贴完整实现代码。原则第 2 条「行为式不过程式」保留：不要把 brief 改成「先打开某文件第 N 行再怎么改」。

## 本仓接线

- **工人不自审**：实现者禁止 Task 派审核子窗；刷新 CR 派发 md 仍允许，由 PM 在报告之后派审。
- **Codex 桌面派发**：任务须随 spawn 初始消息投递（完整任务放初始消息；`followup_task` 补投不可靠，见 [model-routing.md](./model-routing.md) §Codex 桌面派发实测）。
- **长任务**：可另落 `.ai-gates/tmp/{窗口}-{岗}-task.md` 作为任务唯一来源文件（收尾清空，见 CORE §工作区卫生）；委托书按本模板撰写，任务文件即唯一权威契约。
