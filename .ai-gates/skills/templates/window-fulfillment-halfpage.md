# 每窗兑现半页（可复制进交接 / 你下一步）

> 权威细则：[retrospective-metrics.md](../references/retrospective-metrics.md) §每窗兑现清单 · [execution-discipline.md](../references/execution-discipline.md) §复用四问  
> 团队入口：[USER-GUIDE.md](../../USER-GUIDE.md) §半页备忘

```text
兑现：1主窗仅PM  2模型路由  3测挂L0  4pending/暂不升  5outcome  6隔离审
     ✅/❌       ✅/❌      ✅/❌     ✅/❌           ✅/❌     ✅/❌
复用：已有？→能复用？→能少写/不写？→能删？
效果：月末 summarize-pipeline-outcome.ps1 -LastDays 30 → why_multi 只改一条规则
```

缺项在同条写 `❌ + 原因`。项目硬阈（神类净增等）→ `.cursor/project-context.md`（若有）。
