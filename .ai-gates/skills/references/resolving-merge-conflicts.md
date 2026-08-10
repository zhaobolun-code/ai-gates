# 解决合并冲突（resolving-merge-conflicts）

> 触发：进行中的 merge / rebase 出现冲突时自动加载。
> 出处：mattpocock/skills resolving-merge-conflicts（2026-08-07 对照落地）。primary source 本地化：commit message + 窗口文档 + 派发工件；PR/issue 若已有可用，**不引入 tracker 依赖**。
> 边界：本文件处理已在进行中的 merge / rebase 冲突；高危 git 命令防误触由 git-safety hook（`.ai-gates/hooks/**`）拦截；撤销已落地代码按 [rollback.md](./rollback.md)。

## 5 步

1. **看当前 merge / rebase 状态**：git status、git history、冲突文件。
2. **找每侧 primary source**：理解每处变更为什么存在、原始意图是什么。读 commit message、窗口文档、派发工件（PR/issue 若已有可用）。
3. **逐 hunk 按意图解**：尽量保留双意图；不兼容时按 merge 目标选并注明 trade-off；**禁止发明新行为**。始终解决冲突，**禁止 `--abort`**。
4. **跑自动化检查**：typecheck → test → format；修复 merge 弄坏的东西。
5. **完成操作**：stage 全部并 commit；rebase 则继续 rebase 直到全部 commit 重放完。
