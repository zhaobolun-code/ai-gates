# 模型路由 + 子窗派发（主窗仅 PM）

> 权威：本文件（通用框架）。**具体 slug 优先**看 `.cursor/project-context.md` §模型路由（若有）。  
> **优先派发，不硬拦**：Subagent/`model` 失败 → 次选手动新开 Chat → 最后才降级主窗并标注，流程不中断。  
> 可用 slug 以当期会话 `available_subagent_models` 为准。  
> 审核隔离细则 → [isolated-review.md](./isolated-review.md)。  
> 项目边界 → [project-local-config.md](./project-local-config.md)。

## 硬规则（主窗边界）

1. **主窗 = 仅 `[PM]`**：判车道、确认包、「你下一步」、派发/回收子窗、止损与 Discover 白话、等 Unity/签收、短交接。  
2. **流水线非 PM 岗位一律子窗**：策划 / 方案审 / 程序员 / 代码审（含对抗）/ 验收（`mode=verify`）/ 文档（`readme: docs`）——**有 Subagent 能力时必须 Task 拉起**，禁止主窗切换岗位标记后直接写改交付物。  
3. 主窗**禁止**以 `[planner]` / `[plan-reviewer]` / `[developer]` / `[CR]` / `[CR-对抗]` / `[docs]` 身份执行该岗写改职责（派发说明里提及岗名除外）；验收子窗**禁止**改任何仓库交付物。  
4. **只读咨询**（不改任何交付物）：主窗 PM 可直接答；一旦要落盘方案/改码/出审核 findings/改 README → 转子窗。  
5. **周报例外**：`[weekly]` **不要求子窗**；用户单独调用「周报」时可在当前窗直接做（不参与 Express/Direct/Standard/Full 派岗）。

## 目标

- 主窗保持短、稳、可交接；规格与实现上下文不挤进 PM 对话。  
- 普通档（Grok 4.6）砸**策划**与 Standard 实现 / L1～L2 方案审；高级档（Opus 5 → GPT 5.6 Sol）砸 Full L3 / Standard·Full CR / 验收；最低档（Grok 4.5）走 Express/Direct 实现、Direct CR 与文档。

## 主窗 vs 子窗

| 场所 | 做什么 | 不做什么 |
| --- | --- | --- |
| **主窗（仅 PM）** | YAML 判定、确认包/续链、组装最短派发包、启动/回收 Subagent、五态白话、止损推荐、等测 | 写完整方案、改业务码、代写审核 findings、代 docs 改 README 结构 |
| **策划子窗** | `未完成.md` / 口径 / Step / Mandatory / 选型 / 方案派发工件 | 擅自改业务 Runtime 码 |
| **方案审子窗** | L1/L1.5/L2/L3 findings（只读为主） | 改工件（见 plan-reviewer） |
| **实现子窗** | 按批准 Step 改码、自检、代码派发工件、dev-one-liner README | 改口径/扩 scope/标 runtime-validated |
| **代码审子窗** | CR / 对抗 findings（只读） | 默认改码 |
| **验收子窗**（`mode=verify`） | 按剧本只读/临时目录验收；交通过/不通过+退出码 | 改任何仓库交付物；冒充主 CR |
| **文档子窗** | README 结构（`readme: docs`） | 无 CR 结论时写最终 README |
| **周报（当前窗）** | 用户单独调用「周报」 | 不要求子窗；不参与流水线派岗 |

## 解析顺序（强制）

派 Task 前按下列顺序解析该岗 `model` 链（取第一条可用）：

1. **用户本轮点名**的模型 / 「主窗做」等覆盖  
2. **`.cursor/project-context.md` §模型路由**（若存在该节）— **项目专属，不进通用 Skill**  
3. 本文件下方 **Skill 默认表示例**

解析后 **必须**显式传 `model=` 首选 slug；**禁止**无理由省略 / 一律 `inherit`（省略时常被 UI 显示成某默认快模型）。首选不在白名单或调用失败 → 链上下一档，并标注实际 `model=`。`resume` 沿用原窗模型；要换模型 → **新开** Task。

## Skill 默认表（无 project-context 覆盖时才用 · 示例）

> 下列 slug 仅为**缺省示例**。若仓库有 `.cursor/project-context.md` §模型路由，**整表以项目节为准**。  
> **统一三档**（无 project-context 时用；覆盖旧「两档 / Composer 首选」）：最低 = Grok 4.5（`cursor-grok-4.5-high`；**禁止**把 `cursor-grok-4.5-medium-fast` / `cursor-grok-4.5-high-fast` 当首选）；普通 = Grok 4.6（`cursor-grok-4.6-high`）；高级 = Opus 5 → GPT 5.6 Sol（`claude-opus-5-thinking-high` → `gpt-5.6-sol-medium`，再回退 Grok 4.6）。Composer `composer-2.5-fast` **不再作为任何岗首选**，仅可作链末应急并标注「未按模型路由」。档内链用尽 → 下一档。

| 岗位 / 场景 | 场所 | 档位 | Task `model`（首选 → 回退） |
| --- | --- | --- | --- |
| **PM**（主窗） | 主窗 | 用户所选 | — |
| Express / Direct 实现与 Auto 微改 | **必须子窗** | 最低 | `cursor-grok-4.5-high` → `cursor-grok-4.6-high` |
| **代码审** / 对抗（Direct CR） | **必须子窗** | 最低 | `cursor-grok-4.5-high` → `cursor-grok-4.6-high` |
| **文档** `readme: docs` | **必须子窗** | 最低 | `cursor-grok-4.5-high` → `cursor-grok-4.6-high` |
| **策划** | **必须子窗** | 普通 | `cursor-grok-4.6-high` → `claude-opus-5-thinking-high` → `gpt-5.6-sol-medium` |
| **程序员** / Auto（Standard 及以上） | **必须子窗** | 普通 | `cursor-grok-4.6-high` → `claude-opus-5-thinking-high` → `gpt-5.6-sol-medium` |
| **方案审** L1 / L1.5 / L2 | **必须子窗** | 普通 | `cursor-grok-4.6-high` → `claude-opus-5-thinking-high` → `gpt-5.6-sol-medium` |
| **方案审** Full L3 round 1 | **必须子窗** | 高级 | `claude-opus-5-thinking-high` → `gpt-5.6-sol-medium` → `cursor-grok-4.6-high` |
| **方案审** Full L3 round 2 | **必须子窗**（须与 round1 **不同子窗**） | 高级 | `gpt-5.6-sol-medium` → `cursor-grok-4.6-high` |
| **代码审** / 对抗（Standard/Full CR） | **必须子窗** | 高级 | `claude-opus-5-thinking-high` → `gpt-5.6-sol-medium` → `cursor-grok-4.6-high` |
| **验收/verify** | **必须子窗** | 高级 | 同 Standard/Full CR；**禁止**最低/普通档首发或省略 `model=`；**禁止** Composer 冒充验收首选 |
| **周报** | **不要求子窗** | 用户所选 | — |
| Express / Direct 切片文案 | **主窗 PM** 出切片（Express=主窗 PM 一句话切片；Direct=策划子窗对话内 A#/切片、不落盘）；**实现仍必须子窗** | 实现走最低档 | 同上 |

## 派发方式（全岗统一顺序）

1. **优先**：主窗 PM 用 Task/Subagent 拉起目标岗 + **显式**解析后的首选 `model` + **最短派发包**（白名单；禁塞主对话长闲聊、`已完成/` 全文）  
2. **次选**：Subagent 失败 → 提示用户**手动新开 Chat**粘贴派发块（写明岗位 + 应选模型）  
3. **降级**：仅当用户书面要求主窗做、或 Subagent 与手动新开均不可用 → 主窗临时代行，**必须**标 **「主窗执行（未开子窗 · 非独立）」**；不得冒充已隔离  
4. **`model` 失败**：按下表/项目覆盖链回退，最终 `inherit`，标 **「未按模型路由」**，不得停流程  

子窗交回短结论；主窗 PM 更新「你下一步」与确认包。审核子窗默认只读。

### Codex 桌面派发实测（2026-08-04 · codex-cli 0.146.0-alpha.9.2）

> - 任务必须随 spawn **初始消息**投递；`followup_task` 补投在本环境不可靠（子窗只见环境
>   上下文，连「回复 OK」都收不到）。
> - 显式 `model=` / `reasoning_effort=` 覆盖仅在 `fork_turns=none`（或正整数）时生效；
>   `fork_turns=all` 继承父模型、不接受覆盖，但消息送达可靠。
> - 首选：`fork_turns=none` + 显式 `model=` + **完整任务放初始消息**；若首回合回复疑似
>   空上下文（无任务内容）→ 立即改用 `fork_turns=all` 重派（继承父模型并标注），勿反复
>   `followup_task` 补投。
> - 模型可用性以当期 `available_subagent_models` / API 实测为准（2026-08-04：
>   `deepseek-v4-pro` 未开放，高级档用 `deepseek-v4-flash` + `max` 顶替并标注）。

### 子窗健康检查与有界等待（2026-08-05 实测补 · 2026-08-07 收紧）

> 背景：真实会话 23 次 `wait_agent` 中 16 次等满 600s（合计 ~175 分钟）——子窗投递不稳定 ×
> 主窗超时续等放大。2026-08-07 又实测：fork_turns=none 初始消息投递丢失、followup_task 补投
> 丢失、fork_turns=all 继承旧上下文后「有响应但干错事」。改为三件套：**首轮 1 分钟 ACK 握手 →
> 执行期每 5 分钟确认 → 失败级联清理/降级**。
> **1 分钟重启只作用于「没送达」的子窗**，不误杀在跑长验证（Unity 等）的子窗。

规则：

1. **内容握手（ACK + 回显）**：子窗首回合必须输出 `[ACK] 子窗已响应，开始 <Step/岗>` **且回显
   任务要点**（岗位 + 一句任务摘要 + 「不越权：只做 X，不动 Y」）。仅环境话术 / 空上下文询问 /
   答非所问 → 视同未送达。
2. **等 ACK 阶段（主窗）**：spawn 后 `wait_agent` 上限 **1 分钟**，等子窗首条消息（ACK）。
   1 分钟无更新 → `list_agents` 确认是否已开始（`sub_agent_activity` started / 产物 mtime 变化）；
   仍未开始 → 按第 4 条重启。收到内容握手 → 结束等 ACK，进入「等完成」。
3. **执行期每 5 分钟确认**：等完成阶段用短 `wait_agent`（≤5 分钟）循环；每轮无更新 →
   `list_agents` + 查产物 mtime / hooks-log；有活动（消息、产物、子活动）→ 继续下一轮；
   连续 3 轮（约 15 分钟）零活动 → `interrupt_agent` 并走恢复路径（与 loop-engineering §4 一致）。
   禁止用固定 5 分钟轮询打断正在产出 / 长验证的子窗。
4. **失败重启与降级**：无 ACK / 握手失败 → `interrupt_agent` → `fork_turns=all` + 完整任务重派；
   同一子窗重启上限 **2 次**；仍失败 → 主窗执行并标注「主窗执行（未开子窗 · 非独立）」。
   执行中发现越权（改了任务外路径 / 自称主代理 / 再派生流浪树）→ 立即 interrupt + 主窗接管 +
   记 recovery，不再给第 3 次机会。
5. **级联清理**：`interrupt_agent` 父代理**不级联**停孩子；打断后必须 `list_agents` 逐个停掉
   存活子树，确认清空再重派。
6. **禁止**：spawn 后靠 `followup_task` 补投（实测不可靠）；等 ACK 阶段连续 wait 满 600s 不打断；
   重派前不清理旧子树。

### Codex 子窗派发实测补（2026-08-10 · lane-restructure 窗 4 小时空等实证）

> lane-restructure 窗 2026-08-10 实测（多次 spawn）：`fork_turns=none` 三次 spawn 均
> **空上下文待命**——子窗只按 AGENTS.md 入口回「已就绪等待指令 / 请说需求」，任务消息未
> 送达；`fork_turns=all` 时消息送达但 **30–60 分钟无产出 / 卡死**，且同一配置表现不稳定
> （rev12d 45 分钟无产出、r12/r12b 60+ 分钟无产出、r12c 约 40 分钟后才落盘、rev13 约
> 1.5 小时才完成并派生复核子窗）。
>
> 根因：spawn 消息投递 + `fork_turns` 语义在 CLI 模式不稳定；**主窗未按既有协议执行**
> （首轮 1 分钟 ACK 握手 → 有界等待 → 重启上限 2 次 → 主窗降级标注），连续 long-wait
> 把机制问题放大成数小时空等。
>
> 应对（重申并收紧）：spawn 后首轮 **1 分钟 ACK 握手**；无 ACK 立即 `interrupt_agent` →
> `fork_turns=all` 重派；同一子窗重启上限 **2 次**；仍失败 → **主窗执行并标注「主窗执行
> （未开子窗 · 非独立）」**；禁止 spawn 后 long-wait 满 600s 不打断。本次记录即按此降级
> 由主窗代行落盘。

### Auto

每一刀：**实现子窗** → **CR 子窗** → 主窗 `await_human`。禁止主窗静默连改多 Step；禁止主窗自写自审。

## 标注

- 非审核岗：`venue=subagent|main` + `model=…`  
- 审核岗：isolated-review 标注；高质量隔离 → **「隔离复核（Subagent · 异模型/同模型）」**  
- 主窗代行非 PM 岗 → **「主窗执行（未开子窗 · 非独立）」**（硬标注）

## 禁止

- 主窗切换岗位后直接写方案 / 改码 / 出 CR·方案审 findings / 改 README（有子窗能力时）  
- 因图省事把策划+实现+审核全堆在主窗  
- 因模型/子窗不可用而跳过方案审、隔离审、或「准」门禁  
- 把「开了子窗/用了某模型」写成已 Unity 验证  
- 未「准」仅因「要开实现子窗」而提前改码  
- 向子窗塞主对话长讨论或归档全文  
- 把**项目专属**模型偏好写进通用 Skill（须进 project-context）  
