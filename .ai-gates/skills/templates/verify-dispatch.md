# 验收派发工件模板（mode=verify）

> 复制到方案夹 `证据/_Step{NN}-验收派发.md`。  
> 生命周期 → [review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md)。  
> 模型档 → [model-routing.md](../references/model-routing.md)「验收/verify」行（高质量；须显式 `model=`）。

```yaml
mode: verify   # plan | code | adversarial | verify（仅此四种）
dispatch_revision: 1
target_files:
  - path/to/未完成.md
  - path/to/物理口径.md
target_revision: "<sha256 hex>"
review_input_revision: "<sha256 hex>"
tier: verify
round: null
step: NN       # 当前 Step 编号
whitelist:
  - path/to/file.md
fixed_checks:
  - "剧本=本 Step「Unity 验证」+「Regression Validation」"
  - "只读仓库交付物；可跑只读或临时目录剧本"
  - "输出通过/不通过 + 命令与退出码"
blocker_regression: []   # ≤20 行可证伪项；可空
```

## 只读白名单

（列出具体文件；须满足 `target_files ⊆ whitelist`）

## 固定检查 / 验收剧本

- 按本 Step「Unity 验证」+「Regression Validation」执行（只读或临时目录）
-

## blocker_regression（≤20 行）

-

## 输出要求

- 结论：通过 / 不通过
- 证据：命令 + 退出码（可附关键 stdout 行；禁贴长日志）
- **禁止**修改本工件、白名单内外**任何**仓库交付物（含 `.cursor/skills/**`、模板、`project-context`、本窗 A#/Mandatory/物理口径）；模式只读
- **不可替代**隔离主 CR（`mode=code`）
