# Express 切片 — [简述]

> **车道**：Express（小改专用）。**硬门禁**：PM 输出本切片后，方可派 `[developer]`。
> 权威：[CORE.md](../CORE.md) §三车道 → Express
> **Delta-only**：只写相对当前代码的变更；禁止复述整模块原理。细则 → [acceptance-and-delta.md](../references/acceptance-and-delta.md)

## 目标

[1–2 行：改什么、解决什么]

## 不要动什么

[来自模块 README 的硬约束；无则写「无额外约束」]

## 验收条款（实现不得超出）

- A1：[场景 + 操作 + 预期现象/Console + 失败判据]
- 非目标：[明确不做什么]

## Mandatory Code Changes

- `[文件路径 1]`
- （Express 须 ≤3 **业务源文件**，如 `.cs`；`.meta` 与同批 prefab 配套资源不计入）

## 复用四问（极简 · 见 execution-discipline）

- 已有/复用：[符号或「无」] · 少写或不写：[改参/接旧轨/须新写] · 能删：[REMOVED 指向或无可删]

## Delta Spec（相对现状，可极简）

- **ADDED**：[无则写「无」]
- **MODIFIED**：[无则写「无」]
- **REMOVED**：[无则写「无」]

## 满足验收

A1（及所列条款）

## Unity 验证

[Editor 操作步骤 + 预期现象 / Console 关键词 — 须能覆盖上方 A#]

## 切片状态

- **可交给程序员**：是 / 否（须一次确认包后「准」才改码）
- **改前选型**（一行）：本步方案 / 为什么 / 不选的（可极简）
- **用户已确认**：是 / 否（「准」= 理解+方案+开始改码）
