# References 读取路由（降日常 Token）

> 只定义“何时读哪份”，不物理合并 references。任何阶段禁止把 `references/**` 通配注入上下文。

## 默认读取预算

1. **基线**：`agent-entry-route.md` + `.cursor/project-context.md`（若有）+ 当前岗 `SKILL.md` checklist；**CORE 全文不在基线**。
2. **任务白名单**：当前 `未完成.md` / Mandatory、模块 README 风险短段、真实源码/diff、命中的 lessons 行；这些不是 reference 预算，不得为省 Token 跳过。
3. **Reference**：每个阶段默认最多点名 1～2 份；新需要出现时优先替换已完成用途的 reference，不累积整包。确有硬规则冲突可超出，但交接须写理由与文件名。

## 日常按触发加载

| 触发 | 点名 reference |
| --- | --- |
| 测试失败 / 热修 / 止损 / 黑板 / 有意义评审 / A# 复议 | `diagnosis-gates.md`（§0.2.1 有意义评审、§0.6 黑板、§0.7 触顶复议）；需要日志再加 `unity-editor-log.md` |
| 确认 / Auto / 转场 | `handoff-automation.md`；需要停机细则再加 `loop-engineering.md` |
| A# / Delta / 结案收敛 | `acceptance-and-delta.md`；窗口超长再加 `doc-windowing.md` |
| L1.5/L2/L3 隔离 | `isolated-review.md`；派发版本问题再加 `review-dispatch-lifecycle.md` |
| 派岗选模型 / 贵便宜路由 | `model-routing.md`（可与 isolated-review 二选一加载） |
| 测挂 L0 / 签收待准错题 / 错题大纲 | `lessons-learned.md`（含 §错题大纲）；项目文件 `.ai-gates/lessons-outline.md` |
| 签收效果一行 / 月末汇总 | `retrospective-metrics.md` §效果轻量版 |
| 写方案/改码前精简 / 复用 | `execution-discipline.md` §复用四问；项目硬阈见 `.cursor/project-context.md`（若有神类止血） |
| 派发哈希 stale / 路径排序 | `review-dispatch-lifecycle.md`（须 Ordinal 升序） |
| 新窗齐套 kit 标记 / 短名链接纠错 | `doc-windowing.md`（点名新窗齐套标记节；纠错脚本见迁移动作） |

## 按岗加载

- **策划/方案审**：当前缺口优先在 `acceptance-and-delta`、`doc-windowing`、`diagnosis-gates`、`execution-discipline`（复用四问）中点名 1～2 份。
- **程序员**：优先 `unity-editor-log`；Auto/修复计数需要时加 `loop-engineering`；精简/净增加 `execution-discipline`（或 project-context 止血节）。
- **代码审核**：优先 `codegraph-probe`；派发或隔离问题时二选一加载 `review-dispatch-lifecycle` / `isolated-review`。
- **文档/周报**：只读岗位 SKILL 点名的 README/周报规则，不因“参考完整”扫目录。

## 维护者专用

`MAINTAINER.md`、`skill-eval-checklist.md`、脚本说明、模板与反模式全表仅在维护/发布/评测任务按需读取；日常业务实现不加载。

## 禁止

- `Read/Glob references/**` 后逐份展开；把全部 references 塞进派发/system prompt。
- 用“基线”替代真实代码、当前方案、Mandatory、README 风险段或回归索引。
- 为凑“≤2”隐瞒硬约束；正确做法是说明理由并替换/短暂超额。
