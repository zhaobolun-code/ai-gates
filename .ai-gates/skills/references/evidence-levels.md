# 证据等级

本文件为 ai-dev-pipeline **唯一权威来源**。各岗位 SKILL 与 README 只引用此处，不重复定义。

> **车道术语**：Express / Standard / Full — 见 [lane-glossary.md](./lane-glossary.md)。

## 等级定义

| 等级 | 含义 |
| --- | --- |
| `claimed(已声称)` | 来自用户、旧文档、README 或上一岗位交接的声称 |
| `static-checked(静态核对)` | 已读代码、README、配置、diff 或图谱后静态确认 |
| `locally-validated(本地已验证)` | 已运行本地诊断、测试、类型检查或构建 |
| `runtime-validated(运行已验证)` | 已在运行环境中验证，或用户提供了运行时证据 |

## 输出规则

- 不要把 `claimed(已声称)` 或 `static-checked(静态核对)` 写成 `runtime-validated(运行已验证)`。
- 运行时未测时，应明确写 `not run(未运行)` 或 `static-checked(静态核对)`。
- AI 不得在无用户或运行时证据时自行迁移文档状态至 `runtime-validated(运行已验证)`。
- 证据等级表示**验证强度**；文档「状态」（见 `state-machine.md`）表示**流程阶段**。二者不可互相替代。
- **Agent 自称** `locally-validated(本地已验证)` 时，**本条消息**必须含命令 + 退出码或失败计数。上一轮输出、会话记忆、「应该过了 / 编译没问题」都不算。
- **用户** Unity 目视签收：仍可口头 `locally-validated(本地已验证)`；Agent **不得**因此改写成自己已 Play。
- Unity 手测 / 黄金回归在用户或脚本证据出现前保持 `not run`。
- 不新增第四套等级名；不把 `locally-validated` 并进 `runtime-validated`。
- Skill/Doc-only 命中 AI 验收后，verify 子窗仍可通过≡抬升 `runtime-validated`（[handoff-automation.md](./handoff-automation.md) §C/§E；CORE）；本条不砍该路径。

## 示例

| 组合 | 含义 |
| --- | --- |
| `step-completed(步骤完成)` + `static-checked(静态核对)` | 代码与审查静态通过，但未进运行环境 |
| `step-completed(步骤完成)` + `locally-validated(本地已验证)` | 本地构建或诊断通过，但未运行环境验证 |
| `runtime-validated(运行已验证)` + `runtime-validated(运行已验证)` | 运行环境证据已确认 |

## Express 车道特殊规则

Express 车道（含仅 prefab/资源、无脚本的小改）下，Agent 输出必须包含：

```markdown
- 车道：Express
- 证据等级：static-checked(静态核对)（未做独立代码审核；以 express-self-check 为准）
```

不得使用高于 `static-checked(静态核对)` 的证据等级，不得走 Standard 文档状态机（`implementation-ready` / 自写 `runtime-validated`）。用户 Unity Editor 目视确认后，可口头声明 `locally-validated(本地已验证)`，但 Agent 不得自行写入 `runtime-validated(运行已验证)`。Agent 仍不得自写 `locally-validated`（仅用户口头）。Express 仍允许 `static-checked(静态核对)` + 自检；未改 cs 则 `not run`，不强制每条 Express 都 `dotnet build`。**已建分类夹**的迁夹（签收/停写）见 [doc-windowing.md](./doc-windowing.md) §与 Express，≠ 自写 `runtime-validated`。

## hard blocker / soft risk（门禁类型）

与证据等级配合使用；完整示例见 [CORE.md](../CORE.md) 附录。

| 类型 | 含义 | 示例 |
| --- | --- | --- |
| **hard blocker** | 必须解除才能继续当前阶段 | 无 `implementation-ready` 派程序员；Full 车道无 CodeGraph；CR 有 blocker 写最终 README |
| **soft risk** | 可继续或阶段完成，但须在交接/README 中声明风险与未验证项 | Standard 车道无图谱；同 Step 周期内交接有「新增回归场景」但 `project-context.md` 索引未同步 |

## 置信标注（陈述依据 · 句级）

与「证据等级」（上表）不同维度：证据等级=**验证强度**（文档/流程级，迁移由状态机管）；置信标注=**陈述依据**（句级，写在自检/交接/方案/CR 文本里）。二者不可互相替代——`static-checked` 证据等级不豁免句级标注，句级标注也不改变证据等级。

| 档位 | 字面量 | 含义 |
| --- | --- | --- |
| 确定 | `确定[有代码证据]` | 陈述可直接回引代码 / README / diff 位置（文件 + 符号/行），已读真实源码核对 |
| 推断 | `推断[有间接证据]` | 陈述引用间接依据：文档、图谱边、邻窗结论、运行日志等，未经直接源码核对 |
| 猜测 | `猜测[无证据]` | 陈述明示无据：未核对、凭记忆/类比/推测 |

**输出规则**：

- 关键行为断言（如「既有 X 流程会…」「状态已是…」「我已核对调用链」）必须带三档标注；只写结论不写依据视为未标注。
- 「确定」须可回引真实符号/文件位置（回引不实 = 伪称，见下）；「猜测」必须明示无据，禁止借「推断」淡化无据。
- 仍无法证实 → 按岗位既有「不确定则停」处理（如 developer §5.5），禁止带猜测交审。
- **核验底座**：无据称有据 = 伪称执行同族（`.ai-gates/lessons-learned.md` 2026-08-10 行「三角核验：机器打点 / 时间线 / 承载物」）——方案审/CR 按标注回引核验，回引不实或冒充确定 → blocker。
