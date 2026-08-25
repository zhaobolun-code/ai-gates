# 项目专属 vs 通用 Skill（边界说明）

> 维护者审计 Skill 时对照本表。**通用 Skill 不得硬编码具体仓库路径、模块名或回归场景。**

## 放哪里

| 内容 | 权威位置 | 是否随 Skill 复制到其他项目 |
| --- | --- | --- |
| 技术栈、注释/日志约定 | **`.cursor/project-context.md`** | **否** — 从 `project-context.template.md` 生成 |
| 执行文档**存放路径** | [doc-path-defaults.md](./doc-path-defaults.md)（默认 `.ai-gates/Doc/`） | **否** — project-context 仅可选覆盖 |
| 运行回归索引（MD 表） | **`.cursor/project-context.md`** §运行回归索引 | **否** |
| **热路径批量回归**（路径 glob → 场景 ID） | **`.cursor/project-context.md`** §热路径批量回归 | **否** — Skill 只写「若存在该节则按表跑」；禁止在 Skill 正文写死 G1/G2/G5 等场景 ID |
| 回归索引 YAML 副本 | **`.ai-gates/regression-index.yaml`** | **否** — 从 `regression-index.template.yaml` 复制 |
| 一次性中间产物（revision/hash 计算、压力测试、批量迁移脚本等） | **`.ai-gates/tmp/`** | **否** — 不入库；环节收尾整目录清空（见 [execution-discipline.md](./execution-discipline.md) §工作区卫生） |
| 图谱工具启用与项目误报说明 | **`.cursor/project-context.md`** §代码审核图谱工具 | **否** |
| Express 车道提示路径（高回归模块，**不封车道**） | **`.cursor/project-context.md`** §车道升级 | **否** |
| **岗位模型 slug / 回退链** | **`.cursor/project-context.md`** §模型路由（可选覆盖） | **否** — Skill 只留档位+默认示例（见 [model-routing.md](./model-routing.md)） |
| 流水线路由、状态机、车道、岗位 | `.cursor/skills/` 或 `~/.cursor/skills/` 下 CORE、references、各 `SKILL.md` | **是** |
| 执行文档**结构**模板/黄金样例 | `references/execution-doc-template.md`、`执行文档黄金样例.md` | **是** |

## 通用 Skill 里只允许

- 写「若存在 **`.cursor/project-context.md`** 则读取」
- 占位符：`[ModuleName]`、`.ai-gates/Doc/{主题}/`
- 文档默认根：**用户指定 > `.ai-gates/Doc/`**（见 [doc-path-defaults.md](./doc-path-defaults.md)）
- 引擎**类型**的泛化表述，不绑定具体产品模块

## 禁止出现在通用 Skill 中

- 已填写的 `project-context.md`（含模块回归行）
- 具体 `Assets/LabSDK/...` 等项目路径
- 具体模块名（如某业务系统的真实类名）作为 Skill 正文示例
- 含项目数据的 `.ai-gates/regression-index.yaml` 写进 Skill 包

## 新项目 checklist

1. 运行 `.cursor/scripts/init-project-context.ps1`（或手动复制 template → **`.cursor/project-context.md`**）
2. 填写技术栈与（可选）回归索引表
3. （可选）编辑 **`.ai-gates/regression-index.yaml`** 并运行 `sync-regression-index.ps1`
4. 复制 `.cursor/skills/` 到新仓库；**不要**复制他项目的 `project-context.md`
