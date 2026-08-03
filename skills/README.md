# AI 开发流水线 Skill

> **版本**：[VERSION](./VERSION)  
> **放哪**：推荐本仓库 `.cursor/skills/`；也可拷到个人技能目录多项目共用。  
> **每个项目自己填、不会打进安装包**：`.cursor/project-context.md`（项目说明）、回归清单、业务方案文档。

同事日常怎么提需求 → [TEAM-GUIDE.md](./TEAM-GUIDE.md)。  
这是什么、好不好用 → [METHODOLOGY.md](./METHODOLOGY.md)。  
本页只负责：**第一次怎么接上**。

## 新人怎么读

1. [METHODOLOGY.md](./METHODOLOGY.md) — 先对齐预期（不是万能药）  
2. [TEAM-GUIDE.md](./TEAM-GUIDE.md) — 学会「项目经理 + 需求」  
3. 下文「第一次接入」— 做完再让 AI 稳定改本项目  
4. 日常由助手按内部说明执行；你不必先读完所有规则

若你解压的是安装包：解压到目标项目的 `.cursor/` 下，然后从第 3 步做起。包里**没有**源项目的业务文档和项目说明。

## 日常怎么开口

```text
项目经理
[需求 / 现象 / 报错]
```

也可写 `PM`（`项目经理`=`PM`）。新项目第一次先说：`项目经理 初始化`（`初始化`=`init`）。  
没填项目说明时，助手会偏保守，车道可能判不准。

## 第一次接入（三步）

1. 在助手里粘贴 `项目经理 初始化`（**引导式**），或运行：  
   `powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply`  
   脚本会探测四态并输出「下一步清单」（生成/确认 project-context → rules 对齐 → 可选 CodeGraph），按清单逐步确认即可。
2. 打开并填写 `.cursor/project-context.md`：用什么技术、哪些目录要格外小心、有哪些必测场景。填完如有同步脚本再跑一下（助手会提示）。  
3. （推荐）征得同意后安装代码检索工具 CodeGraph，方便少读错文件。

更细的命令 → [tl-onboarding.md](./references/tl-onboarding.md)  
**前提**：Cursor 用能改文件的 **Agent** 模式；要验业务现象时，通常要能在编辑器里跑起来（例如 Unity 点 Play）。怎么操作 → TEAM-GUIDE。

## 日常流程（你只要知道这些）

| 改动大小 | 你大致要做的 |
| --- | --- |
| 很小 | 确认一小段说明 → 等它改完 → 测一下 |
| 常规 | 看方案 → 回「准」→ 等它改和检查 → 逐步验收 |
| 很大 | 需要技术负责人明确说走完整流程 |

补充（听懂即可，细节交给助手）：

- 每个需求一个文件夹；事情结束应离开「进行中」，不能只改状态字。  
- 只改说明、不改业务程序时，有时用另一助手做静态核对；业务现象仍以你亲眼看为准。  
- 测不过会停下来换思路，而不是无限小改。  
- 助手完全没按流程、直接乱改：回 **`按 CORE 重来`**。  
- 标准车道：plan-lite → L1/L1.5/L2 方案审核 → 确认（细节见 CORE §三车道 → 派岗）。

## 给技术负责人（可选）

| 用途 | 去哪 |
| --- | --- |
| 新建任务文件夹 | 脚本 `new-pipeline-window.ps1` |
| 结束后挪文件夹 | 脚本 `migrate-pipeline-window.ps1` |
| 检查文档是否合规 | 脚本 `check-pipeline-doc.ps1` / `validate-pipeline.ps1` |

岗位细则在各 `*/SKILL.md`；规则争议查 [CORE.md](./CORE.md)。
