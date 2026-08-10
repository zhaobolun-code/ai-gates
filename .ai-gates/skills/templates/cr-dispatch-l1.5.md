# L1.5 代码审核 — 隔离派发模板

> **何时使用**：Standard + L1.5，程序员 Step 完成后，由 `[PM]` 使用本块。
> **优先级**：① 主 Agent 拉起 Subagent 隔离会话 ② 提示用户手动新开 Chat ③ 同 Chat 续审须标非独立。
> 权威：[CORE.md](../CORE.md) · [isolated-review.md](../references/isolated-review.md) · [doc-windowing.md](../references/doc-windowing.md)

## 派发方式

| 优先级 | 方式 | 标注 |
| --- | --- | --- |
| 1 | **Subagent 隔离**（推荐） | **L1.5 隔离复核（Subagent）** |
| 2 | **手动新开 Chat** | **L1.5 独立 CR** |
| 3 | **原 Chat** | **非独立 CR**（须显式标注） |

## 派发块（最短包）

将 `【…】` 替换为实际值。

```text
代码审核

【L1.5 — 隔离复核】

车道：Standard + L1.5
执行文档：【{文档根}/{方案短名}/未完成.md】
Mandatory 规格：【同目录 Mandatory-StepN.md 或未完成.md 内 Mandatory】
当前 Step：【Step N — 名称】
dimensions: quality+integration
（Full/高风险可写 dimensions: quality+integration+security；安全维按需）
axis（可选）：standards+spec（双轴模式，规范轴/规格轴分开扫；细则 [dual-axis-review.md](../references/dual-axis-review.md)）
错题本必读路径：【未完成.md##错题本必读 → 点名大纲/主表行】
黑板证据：【证据/_repair-blackboard.md 最近≤3「禁止再做」】或【无黑板（已查路径）】
冻结表扫描：【本 Step DO NOT TOUCH / 冻结符号清单；空=无（已扫）】
Mandatory 源码：
- 【文件路径 1】
回归索引：【模块 / 场景 — 步骤 — Console 关键词】
上轮 blocker（≤20 行，可无）：【…】

默认可读：未完成.md；物理口径.md（若有）；Mandatory-Step*.md（若有）；上列源码；派发点名的错题行/黑板（≤3）。
图谱：优先 CRG（detect-changes / impact；业务 C# 用 LabSDK 子模块图）；需原文再窄用 codegraph_explore。禁止全目录扫读；禁止两套完整双跑。
禁止：已完成/ 历史全文与除 _索引 外全文；证据/（派发点名黑板除外）；第二份长方案；主对话长讨论。

只读输出 findings 短表（blocker/major/minor）与验证缺口；**必须**含「集成维：…」且覆盖冻结表+禁项扫描（或「无/已扫」）；缺句/未扫=major；复现禁项/碰冻结=major/blocker。无 blocker 方可建议更新 README。
独立寻找问题；不得扩大阅读面。
```

## PM 输出要求

- 已拉起 Subagent：`你下一步` 说明「隔离审核进行中」
- 需手动：粘贴上方最短包
- 同 Chat 降级须标 **「非独立 CR」**
