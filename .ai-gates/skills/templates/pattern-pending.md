# 待准模式沉淀

> Agent **自动起草**本文件；用户「准」后写入 `design-patterns.md` 或口诀。禁止未「准」入表。权威 → [references/pattern-harvest.md](../references/pattern-harvest.md)。

```yaml
status: pending   # pending | committed | rejected | revise
date: YYYY-MM-DD
name: "典故词（须具体，禁空话；含特殊字符须双引号）"
symptom: "触发症状：何时该想起这条结构"
pack: "压缩包：适用 / 结构 / 本仓验证实例（path:symbol）"
verify_status: "static-checked(静态核对)"
forbid: "禁用边界：什么情况不要套"
anchor: "本仓真锚点 path:symbol"
destination: design-patterns   # design-patterns | maxim | allusion
doc: 关联方案夹或文档相对路径
```

## 五格（对齐 design-patterns 词条表，不当新表结构）

| 典故词 | 触发症状 | 压缩包（适用/结构/本仓验证实例） | 验证状态 | 禁用边界 |
| --- | --- | --- | --- | --- |
| … | … | … | `static-checked(静态核对)` 或口径允许档 | … |

YAML 键对照五格：`name`←典故词 / `symptom`←触发症状 / `pack`←压缩包 / `verify_status`←验证状态 / `forbid`←禁用边界。**禁止**用 cause/fix 冒充五格。

## 给用户

回 **「准」** 写入 `design-patterns.md` 或口诀；回 **「不准」** 作废（`rejected`）；回 **「改：…」** 修订后再提（保持 `pending`）。
