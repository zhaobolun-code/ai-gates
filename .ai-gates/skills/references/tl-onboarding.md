# TL 项目接入完整步骤

> 精简版入口见 [USER-GUIDE.md §第一次接入](../../USER-GUIDE.md)（三步起步）。本文件是**完整命令 + 细则**，供 TL 首次接入项目或排查冷启动问题时查阅。

## TL 必做（首次改代码前）

**推荐**：在 Agent 粘贴 `项目经理 初始化`（半自动；见 [pm-init.md](./pm-init.md)）。

或手动：

1. 初始化项目配置：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply
# 等价于 init-project-context.ps1 + 创建默认 Assets/Doc/
```

2. 编辑 **`.cursor/project-context.md`** — 技术栈、§Express 车道升级、§运行回归索引（至少 1～2 条 Unity 场景）。填完 MD 表后运行 sync 脚本保持一致。
3. （可选）复制并编辑 **`.ai-gates/regression-index.yaml`**，与 project-context 回归表保持一致：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/sync-regression-index.ps1
```

**双写纪律**：改 project-context 回归索引时，须同步 YAML（或运行 sync 脚本），避免脚本/pre-commit 读到旧数据。见 [anti-patterns.md](./anti-patterns.md)。

## 推荐：安装 CodeGraph

降低 Agent 漂移、辅助代码审核影响面探测。**Standard 强烈推荐；Full 车道无可用图谱 = CR hard blocker。**

在 `PM 初始化` 流程中征得同意后可用：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/pm-init.ps1 -Apply -InstallCodeGraph
```

或手动：

```bash
codegraph install --platform cursor
codegraph init
```

- 探测与降级规则 → [codegraph-probe.md](./codegraph-probe.md)
- 可选审查增强 CRG（非必须）→ 同文件 §可选升级
- Agent 步骤权威 → [pm-init.md](./pm-init.md)

## 冷启动（无 project-context）

| 场景 | Agent 行为 |
| --- | --- |
| 只读咨询 | 不阻塞 |
| 改代码 | 保守 **Standard**；白话提示用户联系 TL 完成上述步骤 |
| Express 小改 | 仅当 ≤3 业务源文件、无 API、无跨模块时可能 Express |

用户无需记内部术语；跟 Agent **你下一步** 即可。初始化完成后车道判定会更准。
