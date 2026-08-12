# 项目上下文（模板）

> **用法（每个新项目必做一次）**
>
> 1. 复制本文件 → 仓库根 **`.cursor/project-context.md`**
> 2. 按本项目填写技术栈、日志、回归索引等
> 3. （可选）复制 `references/regression-index.template.yaml` → **`.ai-gates/regression-index.yaml`**
> 4. （可选）复制 `templates/pipeline-snapshot-log.md` 说明 → 运行 `init-project-context.ps1` 创建 **`.ai-gates/pipeline-snapshot.log`**
> 5. 运行 `.cursor/scripts/init-project-context.ps1` 可一次创建上述文件（推荐）
> 6. 运行 `.cursor/scripts/sync-regression-index.ps1`（若使用 YAML 副本）
>
> **Skill 包内不含已填好的 `project-context.md`** — 勿把具体模块名/路径写进 `.cursor/skills/` 下的通用 Skill。
> 文档默认根：**用户指定 > `.ai-gates/Doc/`**（见 [doc-path-defaults.md](./references/doc-path-defaults.md)；非 Unity 项目可在下文覆盖）。

## 技术栈

- 引擎：[如 Unity / Unreal / 无]
- 语言：[如 C# / TypeScript / Python]
- 运行环境：[如 Editor / 服务端 / 浏览器]

> 多语言层、热更新等**项目特有**约束写在本节或「代码审核额外关注点」。

## 模型路由（可选 — 本项目覆盖）

> 覆盖 `references/model-routing.md` 默认表示例。无团队偏好则**删除本节**，沿用 Skill 默认表。  
> 细则与解析顺序见 `references/model-routing.md`。

| 岗位 | Task `model`（首选 → 回退） |
| --- | --- |
| 策划 / 方案审 / CR | `[高质量 slug]` → `[回退]` → `inherit` |
| 程序员 / Auto 改码 | `[便宜快速 slug]` → `[回退]` → `inherit` |
| 文档 | `[便宜快速 slug]` → `inherit` |

## 领域词汇表（可选 — 本项目）

> 活文档：方案/CR 发现术语歧义或同义异名时在此登记/改判；禁止两套叫法并行。细则 → `references/shared-language.md`。无则删除本节。

| 术语 | 定义（可观察/可证伪） | 对应代码符号 | 别名（禁） |
| --- | --- | --- | --- |
| [示例] | [现象/行为一句话] | [类/方法/字段] | [旧叫法，禁止再用] |

## 代码审核额外关注点

- [跨语言边界、GC、生命周期等项目特有审查点]
- [无则写「无额外关注点」]

## 注释规范

- [语言与风格]

## 日志格式

```text
[Subsystem][Stage] key=value ...
```

如项目有已有约定，以项目约定为准。

## 文件结构约定

- [如「模块目录须有 README.md」]

## 执行文档存放约定（可选覆盖）

> 默认遵守 [doc-path-defaults.md](./references/doc-path-defaults.md)：**用户指定路径 > `.ai-gates/Doc/`**。
> 非 Unity 或需改默认根时，在此表覆盖；否则**删除本节**。

| 类型 | 默认路径 | 说明 |
| --- | --- | --- |
| 执行方案 | `.ai-gates/Doc/{主题}/` | 用户指定则以用户为准 |
| 周报 | `.ai-gates/Doc/Weekly/` | 保存为文件时 |

### 活跃可改码窗（可选短表）

> 同一主题下多执行窗并存时填写；无则删除本小节。细则见 `references/doc-windowing.md`。

| 主题 | 当前唯一可改码窗 | 备注 |
| --- | --- | --- |
| [例：单导管链顶牛] | [相对路径/未完成.md] | 其余热修窗冻结 |

## 代码审核图谱工具

- 工具：[CodeGraph / CRG / 无]
- Standard 车道无图谱：soft risk（须声明影响面未图谱验证；若项目启用图谱门禁）
- Full 车道无图谱：hard blocker（若项目启用图谱门禁）
- [引擎/语言相关的图谱误报说明]

通用探测流程见 `references/codegraph-probe.md`。

## 车道升级（可选 — 本项目）

> 命中任一条 → 项目经理最低 **Standard**。唯一旁路：满足 CORE §四车道判定 1.5 例外全部合取（单个已跟踪文本文件、仅注释/既有日志字符串、预计且实改新增+删除≤20行、无调用/节流/条件/API/持久/跨模块变化）可 Express；untracked、二进制、R/C、生成文件或任一条件不满足 → **Standard + L1.5**。高风险路径写在此；无则删除本节。

| 路径前缀（仓库内） | 原因 |
| --- | --- |
| `[示例] Assets/Scripts/Core/` | 核心逻辑、public API 多 — **替换为本项目路径或删除** |
| `[示例] Assets/Scripts/Save/` | 持久化/序列化 — **替换或删除** |
| `[如 Assets/.../YourModule/]` | [如核心回归、partial 多文件] |

## 热路径批量回归（可选 — 本项目）

> **通用 Skill 不写死场景 ID**（如 G1/G2/G5）。有本节时：Mandatory 触及「路径 glob」→ 标 `step-completed` / `runtime-validated` **前**须跑「场景 ID」列（默认脚本 `run-unity-verify-golden.ps1`；跑前关本机 Editor）；可用 `check-pm-step-golden-evidence.ps1 -RequireSceneIds …` 核对 JSON。**无本节 = 不强制点名黄金景。** 禁止用场景绿冒充业务 A#。  
> 与下方「运行回归索引」互补：本节 = **批量/机械必跑集**；下表 = 手测/关键词回归行。

| 路径 glob（Mandatory 触及即触发） | 场景 ID（逗号分隔） | 核对脚本（可选） |
| --- | --- | --- |
| `[例] Assets/Scripts/Core/**` | `[例] Smoke1,Smoke2` | `[例] .cursor/scripts/check-pm-step-golden-evidence.ps1` |

无热路径批量回归需求时**删除本节**。

## 运行回归索引

Full 车道、`runtime-validated` 前引用下表。**无表时可删本节**；验证步骤写在 Step / plan-lite 即可。

脚本副本（可选）：`.ai-gates/regression-index.yaml`（从 `references/regression-index.template.yaml` 复制）。**以本 MD 表为准**。

| 模块 | 场景/拓扑 | 最低验证步骤 | 关键 Console 关键词 |
| --- | --- | --- | --- |
| [ModuleName] | [场景] | [步骤] | [关键词] |

未列入索引的新场景：程序员在 Step 交接填「新增回归场景」四列，交用户验证后再标 `runtime-validated`。

### 回归索引维护规则

| 角色 | 职责 |
| --- | --- |
| **程序员** | 交接块填四列：模块 / 场景 / 最低步骤 / Console 关键词 |
| **文档** | 追加本表并同步 `.ai-gates/regression-index.yaml`（若使用） |
| **项目经理** | 迁 `runtime-validated` 前检查本表是否有对应行 |

索引与模块 README 不一致时，**以本文件为准**。
