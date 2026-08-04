# 复核派发工件模板

> 复制到方案夹 `证据/_方案审核派发.md` 或 `_Step{NN}-代码审核派发.md` / `_Step{NN}-对抗CR派发.md`。验收派发用 [verify-dispatch.md](./verify-dispatch.md)。  
> 生命周期与哈希算法 → [review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md)。

```yaml
mode: plan   # plan | code | adversarial | verify（仅此四种；verify 用 verify-dispatch 模板）
dispatch_revision: 1
target_files:
  - path/to/未完成.md
  - path/to/物理口径.md
target_revision: "<sha256 hex>"
review_input_revision: "<sha256 hex>"
tier: L3          # 或 L1 / L1.5 / L2 / CR
round: 1          # 仅 mode=plan 的 L3：1|2
step: null        # mode=code|adversarial|verify 时填 NN
whitelist:
  - path/to/file.md
fixed_checks:
  - "…"
blocker_regression: []   # ≤20 行可证伪项；可空
```

## 只读白名单

（列出具体文件；须满足 `target_files ⊆ whitelist`）

## 固定检查

-

## blocker_regression（≤20 行）

-

## 输出要求

- findings：blocker / major / minor / note
- 结论：通过/不通过
- **禁止**修改本工件或白名单外文件；模式只读
