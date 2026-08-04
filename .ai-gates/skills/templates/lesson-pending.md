# 待准 L1（错题本）

> 准全自动：Agent **自动起草**本文件；用户回「准」后由脚本/Agent 写入 `.ai-gates/lessons-learned.md`。  
> **禁止**未「准」写入主表。「准」≠根因已证。权威 → [references/lessons-learned.md](../references/lessons-learned.md)。

```yaml
status: pending   # pending | committed | rejected | revise
date: YYYY-MM-DD
module: ModuleName
lesson: "一句话根因或成功经验（须具体，禁空话；含 A# 等须双引号）"
source: 方案审核|代码审核|成功路径|运行时|自引入|Skill流程
doc: 关联方案夹或文档相对路径
type: 成功经验   # 方案blocker|CR blocker|运行时bug|自引入bug|Skill流程|成功经验
keywords: "词1,词2"   # ≤8 词，逗号分隔
cause: "错因：为什么会错（机制一句；含 # 须双引号）"
fix: "改正：应该怎么改才对（可执行一句；含 # 须双引号）"
prevent: "防再发一句（可与 fix 互补；含 # 须双引号）"
scope: 作用域路径前缀
l0_section: false    # true 时「准」后把未完成.md 中 L0 标为已晋升L1
outline_bucket: ""   # 可选：补进大纲的桶名，如 压力 / 门闸与传质
```

## 给用户

回 **「准」** 写入主表；回 **「不准」** / **「改：…」** 则 `rejected` / 修订后再提。
