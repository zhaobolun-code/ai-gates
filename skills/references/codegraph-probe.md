# CodeGraph / CRG 图谱探测与降级

本文件为 ai-dev-pipeline **唯一权威来源**。`代码审核` / `方案审核` 与 README 中的图谱说明只引用此处。

> **车道术语**：Express / Standard / Full — 见 [lane-glossary.md](./lane-glossary.md)。  
> **分岗默认**：日常探索 = **CodeGraph**；方案审 / 代码审 = **CRG**（有则优先）。

## 工具角色

| 工具 | 角色 | 探测信号 |
| --- | --- | --- |
| **CodeGraph**（日常主工具） | 策划查入口、程序员改码、Discover 钉符号；`codegraph_explore` 一次拿源码 + 调用链 + blast radius | 项目根有 `.codegraph/`，MCP `codegraph` / `codegraph_explore` 可用 |
| **CRG**（code-review-graph，**审核岗优先**） | 方案审 / 代码审：diff 影响面、`detect-changes` / review context / blast radius；**不替代**策划/程序员日常探索 | 有 `.code-review-graph/`（含子模块根）或 `code-review-graph status` 可用；MCP `code-review-graph` |

**两个都装时按岗位分流**（禁止全局「永远只用其中一个」）：

| 岗位 | 优先 | 补充 |
| --- | --- | --- |
| 策划 / 程序员 / Discover / PM 钉符号 | **CodeGraph** | CRG 不可用时不必硬等 |
| 方案审核 / 代码审核（含对抗 CR） | **CRG** | 需 verbatim 源码或 CRG 未覆盖符号时，再用 CodeGraph 窄 query；**禁止**两套各跑一遍完整影响面 |

## 安装

```bash
# CodeGraph（日常）
codegraph install --platform cursor
codegraph init

# CRG（审核岗；可用 uv tool / pip）
uv tool install code-review-graph   # 或: pip install code-review-graph
code-review-graph install --platform cursor --no-instructions --no-hooks --no-skills
# 子模块仓须分别 build（CRG 按 git ls-files，父仓看不到子模块内文件）
code-review-graph register <父仓> --alias chemical
code-review-graph register <LabSDK子模块根> --alias labsdk
code-review-graph build --repo <LabSDK子模块根>
```

## 工具探测与优先级（本流水线）

### 日常岗（策划 / 程序员 / Discover）

| 优先级 | 工具 | 条件 |
| --- | --- | --- |
| 1 | **CodeGraph** | `.codegraph/` 或 MCP `codegraph_explore` 可用 |
| 2 | **CRG** | 仅 CodeGraph 不可用时降级 |
| 3 | 无图谱 | 按下方降级表 |

### 审核岗（方案审核 / 代码审核）

| 优先级 | 工具 | 条件 |
| --- | --- | --- |
| 1 | **CRG** | 目标仓（含业务子模块）有 `.code-review-graph/` 或 MCP / CLI 可用 |
| 2 | **CodeGraph** | CRG 不可用，或需窄 query 补钉 Mandatory 符号 / verbatim 源码 |
| 3 | 无图谱 | 按下方降级表 |

## 禁止「额度 / 预算用尽」停用（强制）

CodeGraph 是**本地索引**，**没有**付费次数额度。

工具描述里的 `Budget: use at most N calls`（按仓库规模约 1～5）只是**效率建议**，**不是**硬门禁。

| 禁止 | 正确做法 |
| --- | --- |
| 对用户说「CodeGraph 额度已用尽」 | 说「本轮建议收窄 query」；**继续可用** |
| 因 soft budget 整轮弃用 CodeGraph，改全面 Grep/Read | 用更短符号名再调 `codegraph_explore`；仅对**本次返回未覆盖**的文件用 Read |
| 因返回截断就永久停用 | 再调一次更窄 query（`maxFiles` 可更小）；截断区以外仍可用 CodeGraph |
| 把 soft budget 写进交接当系统故障 | 记「查询过宽 / 已收窄」，不算工具不可用 |

**允许**在单次探索后对**缺口片段**用 Read；**不允许**据此宣布本会话 CodeGraph 不可用。

## CodeGraph 使用流程（默认）

1. 从当前 Step / Mandatory / diff 提取类名、方法名、文件路径。  
2. **优先** MCP `codegraph_explore`（可多次；优先窄 query）。  
3. 必要时 CLI：`codegraph impact`、`codegraph callers/callees`、`codegraph affected`。  
4. 影响面过宽（如 partial 拉出数百符号）→ **收窄名字再 explore**，不要改成全目录 Read。  
5. 返回已含 verbatim 源码的文件：**禁止**再整文件 Read（浪费 token）。

## CRG 使用流程（审核岗优先）

1. 确认索引仓：业务 C# 在子模块时，对**子模块根** `status` / `detect-changes`（勿只查父仓空图）。  
2. 读取本次 diff 或改动文件列表。  
3. CLI：`code-review-graph detect-changes --brief`（`--repo` 点子模块）；怀疑 stale → `update --brief`。  
4. 或 MCP（`code-review-graph`）：`get_review_context` / `get_impact_radius` / `detect_changes` / `query_graph` / `search` 等（以当前 MCP 工具名为准）。  
5. 边上置信度为 `INFERRED` / `AMBIGUOUS` 时，结论降级表述，不得写成确定回归点。  
6. 需要函数体原文时：改用 CodeGraph `codegraph_explore` 窄 query（或 Read 缺口文件）；勿再对同一 diff 用 CodeGraph 重做整轮 blast。

## 无图谱时的降级

| 车道 | 处理方式 |
| --- | --- |
| **Full** | **hard blocker**：审核岗未检测到 **CRG 且未检测到 CodeGraph** 则无法完成影响面分析；给出 LabSDK `code-review-graph build` / `codegraph init` / 重载 MCP；不得伪称「未发现 blocker / 可交给文档」 |
| **Standard** | **soft risk**：可继续；须声明「未做图谱影响面分析」并附修复步骤 |
| **Express** | 允许 diff + README + Grep/Read；开头声明未做图谱分析 |
| 用户仅咨询 | 不必探测工具 |

### MCP 已 init 但不可用

若项目根已有 `.codegraph/` 但 MCP 未连接：

- 提示重载 Cursor 窗口或检查 `.cursor/mcp.json`
- 可尝试 CLI `codegraph status` 作为降级证据
- **不得**把 soft budget 误报成「MCP 不可用」
- Standard 仍按 soft risk；不得伪造已完成图谱分析

## 输出要求

```markdown
图谱工具：[CodeGraph / CRG / 无]
影响面摘要：...
建议回归：...
图谱证据等级：static-checked(静态核对)（图谱不能替代 runtime-validated(运行已验证)）
```

## 选型结论（给 TL）

| 问题 | 答案 |
| --- | --- |
| 日常改码 / Discover？ | **CodeGraph** |
| 方案审 / 代码审？ | **CRG**（有则优先）；符号钉死可补 CodeGraph |
| 两者都装谁优先？ | **按岗位分流**（见上表）；旧「全局只认 CodeGraph」与「全局只认 CRG」均作废 |

## 项目特定注意

引擎、语言、图谱误报边界等**项目专属**说明，只写在 **`.cursor/project-context.md`**「代码审核图谱工具」与「代码审核额外关注点」；本文件不写具体项目名或模块名。
