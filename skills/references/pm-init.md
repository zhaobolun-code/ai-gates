# PM 初始化（引导式接入）

> 口令等价（强制）：**`项目经理` = `PM`**，**`初始化` = `init`**。  
> 二者相加即本流程（任选语种组合，**效果相同**）：如 `项目经理 初始化`、`PM init`、`PM 初始化`、`项目经理 init`；裸写 `init` 且本轮意图为流水线接入时亦同（勿与 `codegraph init` 混淆）。同义：`流水线初始化`。  
> 由 **`[PM]`** 执行；不是新岗位。细则权威：本文件；TL 完整命令仍见 [tl-onboarding.md](./tl-onboarding.md)。

## 目标

一次对话内完成「能跑流水线」的最小接入：

1. 生成/确认 `.cursor/project-context.md` + `regression-index.yaml`
2. 确认并创建**执行文档根目录**（默认 `Assets/Doc/`，可覆盖）
3. 探测并引导安装 **CodeGraph**（征得同意后再装）
4. 列出仍须人工填写的项目专属项（技术栈、回归索引等）

**不做**：替用户编造回归场景、擅自覆盖已有 project-context 内容、未经确认执行高侵入安装。

## Agent 步骤（强制顺序）

1. **Read** 本文件 + 探测仓库状态（优先跑脚本，见下）。
2. 若无 `.cursor/project-context.md` → 运行 `init-project-context.ps1`（或 `pm-init.ps1` 的 CreateContext）。
3. **文档根**：默认 `Assets/Doc/`（见 [doc-path-defaults.md](./doc-path-defaults.md)）。
   - 用户本轮指定路径 → 用用户路径，并在 project-context「执行文档存放约定」写覆盖表。
   - 未指定 → 创建默认 `Assets/Doc/` 与 `Assets/Doc/Weekly/`（已存在则跳过）。
4. **CodeGraph**：
   - 已有 `.codegraph/` 或 `codegraph` CLI 可用 → 记「已就绪」，提示必要时重载 Cursor。
   - 未安装 → **先征得用户同意**，再执行 `codegraph install --platform cursor` 与 `codegraph init`；失败则给出手动命令与 [codegraph-probe.md](./codegraph-probe.md)。
5. 输出白话汇总：**已完成 / 跳过 / 失败 / 仍须你填**。
6. **你下一步**：引导用户编辑 project-context（技术栈、Express 升级表、至少 1～2 条回归索引），填完后跑 `sync-regression-index.ps1`；然后可用 `PM + 需求` 开工。

## 用户可见输出（强制）

初始化轮**不做**三车道派岗；仍须首行内部 `[PM]`，面向用户只输出白话：

| 块 | 内容 |
| --- | --- |
| 探测结果 | project-context / 文档根 / CodeGraph 各一行：已有 / 已创建 / 待装 / 失败 |
| 已执行 | 实际跑过的脚本与创建的路径 |
| 下一步清单（引导式） | `-Apply` 后按序输出：① init-project-context（自动，不覆盖）② rules 对齐（link-trae-skills 命令 + `.mdc ↔ .trae` 复制提示）③ CodeGraph 安装命令（可选，须同意）④ 人工填写项目专属项 |
| 仍须你填 | 技术栈、回归索引（至少 1～2 条）、Express 升级表（可选） |
| **你下一步** | 明确下一动作（改配置 / 同意装 CodeGraph / 重载 Cursor / 用 `PM + 需求` 开工） |

## 脚本入口

```powershell
# 仅探测（默认；零副作用）
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1

# 引导式 Apply：创建缺失的 project-context / 默认文档根（不覆盖已有 context），并输出「下一步清单」
# （① init-project-context ② rules 对齐 link-trae-skills ③ 可选 CodeGraph ④ 人工填写项）
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply

# 指定文档根（相对仓库根）
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -DocRoot "docs"

# 同意后尝试安装 CodeGraph（需本机已有 codegraph CLI 或可下载安装器；失败则打印手动命令）
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -InstallCodeGraph
```

Agent 应优先 `-Apply` 做安全创建；`-InstallCodeGraph` **仅在用户明确同意后**使用。

## 与冷启动的关系

- 未初始化时改代码仍走 CORE §无 project-context 冷启动（保守 Standard）。
- `项目经理 初始化` / `PM init`（及口令等价组合）是**主动接入**口令，完成后 `project_context: loaded`，车道判定可按项目表执行。
- 已初始化仓库再跑 → 幂等探测 + 补缺，不得 `-Force` 覆盖已有 project-context（除非用户明确要求覆盖）。
