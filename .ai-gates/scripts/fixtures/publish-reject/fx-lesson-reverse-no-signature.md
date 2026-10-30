# fixture: origin=逆链 missing hole_signature must reject

```yaml
status: pending
date: 2026-10-29
module: Skill
lesson: "Reverse-chain pending without hole signature must be refused"
source: Skill流程
doc: scripts/fixtures/publish-reject/fx-lesson-reverse-no-signature.md
type: Skill流程
keywords: "hole,reverse-chain"
cause: "Reverse origin pending skipped signature so the hole could not be found next time"
fix: "Require hole_signature when origin is reverse-chain before writing pending"
origin: 逆链
hole_trigger: "倒走撑住未回指将改文件"
hole_next: "倒走前先核纸老虎是否落到冻结表"
```
