# Express 自检清单（= 代码审核完成）

> **v3.1.3**：Express 车道完成改动后填写；**视为 CR 完成**，无需再派「代码审核」。
> 权威路由见 [CORE.md](./CORE.md)。实现前须有 PM 的 [express-slice.md](./templates/express-slice.md)。

## 何时使用

- PM 判定 **车道：Express**
- 改动完成后，在同一条回复末尾输出本清单

## 自检清单（须逐项勾选）

```markdown
[Express 自检 — 视同代码审核]
□ 只改了 express-slice 说定的文件/范围（未悄悄扩 scope）
□ 切片含可证伪验收条款 A#，且改动覆盖且未越出所列 A#（见 acceptance-and-delta.md）
□ 已读相关模块 README 硬约束；未在切片/回复中复述整模块原理
□ 已读真实代码/API，无臆测（冲突已停并说明）
□ 语言层/技术栈约束未违反（见 `.cursor/project-context.md`，若存在）
□ 未命中 project-context §车道升级（若存在；禁入 Express/Direct → 最低 Standard）
□ 本 Chat 内**此前**未对同一模块已做过 Express 改动（有则累计文件数，命中 CORE §Express 升级任一条即升级，不得拆多轮绕过）
□ 日志格式符合 project-context（若存在；如有新增日志）
□ 无已知 Console 报错，或已说明原因与后续
□ 用户可见行为与需求/说明一致
□ 未夸大验证（Unity 未测则写 not run，不说「已通过」）
□ 无 blocker（public API/持久/跨模块/超范围 — 有则升级车道）
```

## 输出要求

- 标题 **`[Express 自检 — 视同代码审核]`**
- 首行 **`[developer]`**
- 须含 **`车道：Express`** 与 **`证据等级：static-checked(静态核对)`**
- 任一 □ 无法满足 → **不得**声明通过；实改超机械范围 / 超 2 文件 / 跨模块 → 升 Direct（再升 Standard/Full 按判定树）并说明原因

## 与代码审核岗

| 车道 | 代码审核 |
| --- | --- |
| Express | **本清单 = 审核完成** |
| Direct | **不走本清单**（完成 = 隔离 CR，见 [code-reviewer/SKILL.md](./code-reviewer/SKILL.md)） |
| Standard / Full | Read `code-reviewer/SKILL.md` |
