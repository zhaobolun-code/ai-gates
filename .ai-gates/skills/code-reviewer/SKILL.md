---
name: 代码审核
description: 审查程序员改动，找 blocker 与回归风险。用户说「代码审核」「审代码」时使用。Express 车道不启用。
---

# 代码审核

首行：**`[CR]`**。日常入口：[agent-entry-route.md](../references/agent-entry-route.md)；争议/recovery：[CORE.md](../CORE.md)

## PM 门禁（硬停）

用户直接叫本岗、且**本轮尚无** `[PM]` YAML + **你下一步** 时：**不得**改代码；须同条先 `[PM]` 判车道并输出白话 **你下一步**，再切本岗。只读审查结论（不改文件）→ 不阻塞。

## 车道

| 车道 | 本岗 |
| --- | --- |
| Express | **不启用** — 见 [express-self-check.md](../express-self-check.md) |
| Direct | ✓ 必审；本岗**必须子窗**；普通档隔离复核（Subagent/新 Chat）；同 Chat 降级须标 **「非独立 CR」** |
| Standard | ✓；本岗**必须子窗**；L1.5 隔离 CR + 异模型优先（高质量档，见 [isolated-review.md](../references/isolated-review.md) / [model-routing.md](../references/model-routing.md)）；同 Chat 降级须标 **「非独立 CR」**；高风险可追加对抗模式 |
| Full | ✓ 必审；本岗**必须子窗**；普通 CR 无 blocker 后 **优先**可选对抗隔离会话；业务 C#：无 **CRG 且无 CodeGraph** = hard blocker（见 [codegraph-probe.md](../references/codegraph-probe.md)）；**Skill/Doc-only**（无业务 Runtime/Editor C#）无图谱 → **soft risk**，不挡无-blocker 收口（见 [loop-engineering.md](../references/loop-engineering.md)） |

## 模型路由 + 子窗

本岗**必须子窗**：Task + 按档位选模型（slug 按 [model-routing.md](../references/model-routing.md) 解析）。**CR 档位接线**：Direct CR=普通档（程序员档）；Standard/Full CR=高级档；热度命中 Direct CR 升高级档（`deepseek-v4-pro` 未开放 → `flash+max` 顶替并标注「未按模型路由」）。禁止主窗切 `[CR]` 后直接出 findings。

## Checklist

1. **优先**读点名 `证据/_Step{NN}-代码审核派发.md`（对抗用 `_Step{NN}-对抗CR派发.md`），再只读工件白名单 + 最新 diff；禁扫 `证据/`（[review-dispatch-lifecycle.md](../references/review-dispatch-lifecycle.md)）。无点名工件时退回读当前 Step/`Mandatory`。命中 lessons 则更新「最近命中」；近 6 月命中且档位未升 L1.5 → 提示 PM 补档。无理由全文读归档 → **major**
1.05 **交审证据路径（硬挡）**：派发或自检摘要须含可核对路径——（a）方案「错题本必读」点名行；（b）黑板最近 ≤3 条「禁止再做」，或「无黑板（已查路径）」。无路径引用仍交 CR → **major**（`repair_rounds≥1` 且应有黑板却未注入 → **major**）
1.1 派发白名单外不得自行扩大 Read；缺材料记验证缺口或 blocker。开始前重算 revision；不符/`target_files` ⊄ whitelist → **blocker** `stale_dispatch`。blocker 后**只返回 findings**；Maker 更新工件后再复审。对抗 `mode=adversarial` 不可替代隔离主 CR
1.15 **图谱定向（审核岗）**：**优先 CRG**（diff / `detect-changes` / impact / review context；业务 C# 在 `Assets/LabSDK` 子模块时对子模块根查图，见 [codegraph-probe.md](../references/codegraph-probe.md)）；需 verbatim 或 CRG 未命中符号时再窄用 `codegraph_explore`。**禁止**宣称 CodeGraph「额度已用尽」后整轮改 Grep/Read；禁止全目录扫读；禁止 CRG+CodeGraph 各跑一遍完整影响面。本 Step **仅** Skill/Doc、无业务 C# 时无图谱 → soft risk / 验证缺口，**不得**单独 hard blocker 挡收口
1.2 **命中文件热度时反推同类隐患**：本次 diff 涉及的文件/模块若命中 `lessons-learned.md`，**不止核对该条教训本身是否复现**，还要用该教训的根因反问一遍当前 diff 是否存在同类风险（参考 L3 多轮独立审的"换角度攻击"思路，如：单位/顺序/因果关系类教训 → 查本次 diff 有无同类隐患，即使触发路径不同）；无同类风险须在 findings 中写一句「已按 [教训一句话] 反推，未发现同类隐患」
1.25 **复盘写回提议（P2 · 须「准」）**：本次 blocker 满足升级资格（**近 90 天 ≥2 次命中 且 最近命中 ≤30 天**；机器候选见 `scripts/compute-evolution-candidates.ps1`，另须人工确认留痕——同族错误不重复计数、机器候选≠已确认）→ findings 附一行「**复盘写回提议**：<拟补 anti-patterns/lessons 的一句>」；**用户「准」后**才改 Skill（改前 CHANGELOG）。**禁止**静默改规则 / 把一次偶发提为规则（评测 [skill-eval-checklist.md](../references/skill-eval-checklist.md) E2）。
1.26 **置信标注核验**（见 [evidence-levels.md](../references/evidence-levels.md) §置信标注）：developer 自检/交接中的「确定[有代码证据]」须可回引真实符号/文件位置；标注与实际不符（含按标注回引不到代码位置）→ **major**；未标注断言冒充确定（无据称有据）→ **blocker**（伪称执行同族，`.ai-gates/lessons-learned.md` 2026-08-10 行）。
1.5 **经验/错题（准全自动）**（见 [lessons-learned.md](../references/lessons-learned.md)）：blocker 修复确认后交主窗 PM **自动**起草 `证据/_lesson-pending.md`（类型默认 `CR blocker`）；成功路径同条可代拟 pending；**须用户「准」**才写入主表；禁静默/空泛；扫表命中须更新「最近命中」。
2. **L1.5**：经 [cr-dispatch-l1.5.md](../templates/cr-dispatch-l1.5.md) 派发；**优先** Subagent（标「L1.5 隔离复核（Subagent）」）；手动新 Chat 标「L1.5 独立 CR」；原 Chat 标「非独立 CR」。细则 → [isolated-review.md](../references/isolated-review.md)
3. 有图谱则探测影响面：**先 CRG，必要时补 CodeGraph**（见 [references/codegraph-probe.md](../references/codegraph-probe.md)）
4. 输出 findings：**blocker / major / minor / nit**（**短表**）；L1.5+ 主 CR/复审 **必须**含集成维一句（见下）
5. **默认不改代码**（用户要求修复时除外）
6. 证据最高 static-checked 或 locally-validated
7. 无业务 blocker → 按 [handoff-automation.md](../references/handoff-automation.md) §C：建议/执行迁 `step-completed` + README 一行或派 docs；命中 Skill/Doc AI 验收条件时**提示**主窗派 `mode=verify` 验收子窗（勿只写 `unity_test` 干等）；未命中则请用户 Unity 测；**禁止**自动标 `runtime-validated`；Standard 无图谱按 soft risk 记录未验证影响面
8. 不把风格偏好当 blocker
9. 用户仅咨询时不读 diff
10. 存在 `Mandatory-Step*.md` 仍去读历史全文 → **major**

## 双轴模式（可选）

规范轴（standards）+ 规格轴（spec）分开扫、结论分组防污染；PM 可选用（与对抗模式并列，不替代）。派发加 `axis: standards+spec`；findings 按轴标 `[规范轴]` / `[规格轴]`。细则 → [dual-axis-review.md](../references/dual-axis-review.md)。

## 审查维度

- **语言维（必扫 · 按 diff 语言层路由）**：diff 含 `.cs` → C# 层查 MonoBehaviour 生命周期 / 对象池复用 / 协程泄漏 / Editor 专有 API；含 `.lua` → Lua 层查 table 频繁分配 / 闭包泄漏 / 全局变量污染 / 跨语言装箱与 LuaFunction 预缓存；检查项指针 → project-context §代码审核额外关注点（不内联复制）
- 仅 Skill/Doc-only → 文档一致性；无 CRG/CodeGraph → 静态读码 + 按 [codegraph-probe.md](../references/codegraph-probe.md) 记 soft risk / 验证缺口，**不硬拦**
- **质量维（默认）**：只实现当前 Step/未扩 scope；覆盖且未越出 A#（[acceptance-and-delta.md](../references/acceptance-and-delta.md)）；README/project-context 硬约束（含 **神类止血/补强三口** 若有）；边界/状态安全；语义理解错误（名实不符→查证，改行为记 major/blocker）；**复用四问**（[execution-discipline.md](../references/execution-discipline.md)）：可复用却复制新实现→major；只增不删且无说明→major；形成并行实现无互斥句→blocker；过度设计/死代码/类膨胀→major；新方法体超预算无豁免→major；缺瘦身一拍且膨胀明显→nit/major；禁把 static-checked 写成 runtime-validated；**设计模式结构核对**（[design-patterns.md](../references/design-patterns.md)）：Mandatory 声明的模式须与词条「结构/禁用边界」一致；明显可 inline 却新抽象（模式崇拜）→ **major**；与 §典故 重复造词 → **major**；**证据黑板**（派发点名时可 Read）：手法与最近条「禁止再做」实质相同→**major/blocker**；`repair_rounds≥1` 却无黑板/未注入→**major**；止损或 `max_repair_rounds` 触顶后仍同 A# 交修→**blocker**；**错题必读**：方案已点名错因/改正行，diff 仍复现同错因→**major**
- **集成维（L1.5+ 主 CR 与 blocker 复审必扫；**语言维必扫见上**）**：调用链入口/出口；回归索引场景是否仍覆盖；跨模块或 C#/Lua 契约；A# 场景闭合；**CRG（优先）/CodeGraph** 影响面一句；**强制**扫本 Step **冻结表 / DO NOT TOUCH**（有则核对 diff 未碰；无则「冻结表：无（已扫）」）+ 黑板「禁止再做」是否复现（无黑板则「禁项：无（已扫）」）。findings **必须**含「集成维：…」或「集成维：未发现缺口」且覆盖冻结表/禁项扫描；**缺句或未扫 → major**；复现禁项 / 碰冻结符号 → **major/blocker**（档位按方案 `物理口径.md`）
- **安全维（按需）**：密钥泄露/注入/不可信输入；非默认必跑；Full 或派发 `+security` 时扫

## 对抗模式（高风险可选）

普通 CR 无 blocker 后，满足任一项时 PM **优先**拉起 Subagent 对抗审查，失败再提示手动新开；**不强制**：Full 车道；Standard 命中 `lessons-learned.md` 文件热度且同一 Step 反复修复或运行仍异常；用户主动要求。Express 不启用。细则 → [isolated-review.md](../references/isolated-review.md)。

调用方式（Subagent 派发块或手动新 Chat 首条）：

```text
代码审核
模式：对抗
执行文档：[路径]
普通 CR 结论：[粘贴或给路径]
```

- 首行标 **`[CR-对抗]`**；只读，不改代码，不复述普通 CR
- 假设“程序员与普通 CR 可能共享同一错误前提”，优先攻击：语义理解、数据来源/回退、调用顺序/生命周期、边界反例、验证盲区
- 每个怀疑点须给代码证据或可执行验证方法；证据不足记“待验证”，不得强行制造 blocker
- 输出 **推翻点 / 最小验证 / 剩余风险**；未找到足以推翻的证据时只写“暂未推翻普通 CR 结论”，不得声称实现绝对正确
- 严重度仍按实际影响判定，不因“对抗模式”自动升级
- 隔离成功标 **「隔离复核（Subagent）」**；手动新 Chat 标 **「独立复核（新 Chat）」**；同 Chat 须标非独立

## 输出格式

```markdown
变更摘要（≤3 条 · 人类可读 · 禁罗列 diff）：
1. …（如：提取公共常量）
2. …（如：删除冗余循环）
3. …（如：调整边界校验）

findings:
- [blocker] … — 影响 — 建议修复点
- [major] …
- 集成维：未发现缺口（或具体缺口）

验证缺口：…
证据等级：static-checked
```

**diff 只在用户追问细节时输出**；CR 报告默认只给「变更摘要 ≤3 条 + findings 短表」。无 blocker 时明确写「未发现 blocker」+ 建议迁 `step-completed` + README 记录建议 + 建议回归场景；命中 AI 验收条件则提示派 `mode=verify` 验收子窗，否则请用户 Unity 测（§C）；禁自动 `runtime-validated`。

## 禁止

- 默认改代码 / 跳过执行文档只看 diff / 无证据宣布功能完成
