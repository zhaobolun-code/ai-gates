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

不得使用高于 `static-checked(静态核对)` 的证据等级，不得迁移文档状态机。用户 Unity Editor 目视确认后，可口头声明 `locally-validated(本地已验证)`，但 Agent 不得自行写入 `runtime-validated(运行已验证)`。

## hard blocker / soft risk（门禁类型）

与证据等级配合使用；完整示例见 [CORE.md](../CORE.md) 附录。

| 类型 | 含义 | 示例 |
| --- | --- | --- |
| **hard blocker** | 必须解除才能继续当前阶段 | 无 `implementation-ready` 派程序员；Full 车道无 CodeGraph；CR 有 blocker 写最终 README |
| **soft risk** | 可继续或阶段完成，但须在交接/README 中声明风险与未验证项 | Standard 车道无图谱；同 Step 周期内交接有「新增回归场景」但 `project-context.md` 索引未同步 |
