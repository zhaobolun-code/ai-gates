# 复核派发工件生命周期

> 权威算法与边界与方案夹「物理口径」对齐；本文件为 Skill 可复制 SoT。  
> 相关：[isolated-review.md](./isolated-review.md)、[doc-windowing.md](./doc-windowing.md)、模板 [review-dispatch.md](../templates/review-dispatch.md)、[verify-dispatch.md](../templates/verify-dispatch.md)。

## 1. 工件与 mode（仅四种）

| mode | 工件路径 | 生成/维护 |
| --- | --- | --- |
| `plan` | `证据/_方案审核派发.md` | PM / planner |
| `code` | `证据/_Step{NN}-代码审核派发.md` | PM / developer |
| `adversarial` | `证据/_Step{NN}-对抗CR派发.md`（可选） | PM / code-reviewer |
| `verify` | `证据/_Step{NN}-验收派发.md` | PM（CR 无 blocker 后） |

L3 第 1/2 轮用字段 `round`（1|2），**仍属 `mode=plan`**，不算独立 mode。

`mode=verify`：**禁止**改任何仓库交付物（含 `.cursor/skills/**`、模板、`project-context`、本窗 A#/Mandatory/物理口径）；只读 + 可跑只读或临时目录剧本；须交通过/不通过 + 命令与退出码。模板 → [verify-dispatch.md](../templates/verify-dispatch.md)。**不可替代**隔离主 CR（`mode=code`）。

## 2. 精确读权限

- `证据/**` 默认禁读（见 doc-windowing）。
- **唯一例外**：派发时**明确点名的一个** `_...派发.md`；禁止扫描 `证据/`、读其它日志、把整个证据夹加入白名单。
- Reviewer：**先读**点名工件 → **再只读**工件内白名单。Checker **禁止修改**工件；修订由 Maker/PM 在主会话完成。

## 3. 机械版本（公共算法）

参与哈希的文件取**磁盘原始字节** SHA-256（小写 hex）。规范清单：UTF-8、无 BOM、行间单个 `LF`、清单末**保留**结尾 `LF`；字段分隔单个 `TAB`；路径仓库相对、`/`、**升序必须按 ordinal（字节/码点序）**——PowerShell 用 `[Array]::Sort($paths, [StringComparer]::Ordinal)` 或等价；**禁止** `Sort-Object` 默认文化排序（会把 `PressureController.cs` 排到 `PressureController.Pipe*.cs` 前，导致 `review_input_revision` 假 stale）。对清单 UTF-8 字节再 SHA-256。

### 3.1 `target_revision`

- 方案：`target_files` 须含 `未完成.md`、`物理口径.md`、已存在的 `Mandatory-Step*.md`；行格式 `path<TAB>sha256|DELETED`。
- `未完成.md` **先排除**再哈希（节标题到下一 `##` 前）：
  1. `## 给下一个 AI 的第一条指令`
  2. `## 文档状态`
  3. `## 实施/审查摘要` 及之后审计追加  
  不排除：`## AI 无歧义执行规则`、验收条款、Step/A# 等正文。
- **排除视图换行（现行 · 阶段 B）**：排除完成后，将视图内所有 `CRLF`/`CR` **统一规范为 `LF`**，再以 UTF-8（无 BOM）字节做 SHA-256。其余白名单文件仍用磁盘**原始字节**（不做换行规范化）。（历史阶段 A「保留原始换行」仅用于尚未启用本句前的旧派发对齐，新派发一律按本句。）
- 代码：当前 Step Mandatory 规格 + 全部 Mandatory 源码；删除 `path<TAB>DELETED`。

### 3.2 权威与集合

- **权威文件 ≡ 只读白名单全集**（具体文件路径，禁目录/通配）。
- **硬约束** `target_files ⊆ whitelist`；违例 → `blocked reason=stale_dispatch`。

### 3.3 `review_input_revision`

清单再哈希：

1. 首行：`target_revision<TAB><hex>`
2. 每个白名单路径（**Ordinal 升序**）：`whitelist<TAB><path><TAB><content_sha256|DELETED>`

`未完成.md` 的 content hash **必须**与 target 使用**同一排除视图字节**（含上述 LF 规范化）；其余白名单文件用原始字节。

派发前与 Reviewer 开始前各算一次；与工件字段不一致或集合违例 → `stale_dispatch`，旧结论不可复用。

### 3.4 清零边界

非排除节正文 / 物理口径 / A# / Step / Prerequisites / `target_files` / 白名单变化 → L3 有效轮次清零。  
仅排除三节变更、或同一 `review_input_revision` 下第1→第2 轮切轮 → 不清零。

## 4. blocker 优化

- 首次：`blocker_regression` 可空。
- 有 blocker：Reviewer 只返回 findings；Maker 修目标后递增 `dispatch_revision`，更新 revision/diff，去重压缩回归项（≤20 行）；禁复制整段对话。
- 方案实质修改：L3 清零，重生第 1 轮；第 2 轮不得带第 1 轮结论。
- 代码复审：绑定最新 diff + 上轮 blocker≤20 行；禁用旧 diff 无-blocker结论。
- 重复项提升为固定检查；失效临时项删除。

## 5. L3 第1→第2 转场

1. 第1轮无 blocker → PM/planner 重算 `review_input_revision`；不一致则清零重生第1轮。
2. 一致 → 记 1/2，递增 `dispatch_revision`，同工件切 `round=2`，保留相同 target/review_input revision。
3. **转场纪律（强制）**：第1轮通过后、第2轮开始前，**只允许**改 `未完成.md` 的排除三节（给下一个 AI / 文档状态 / 实施审查摘要）。若改了非排除节正文 / 物理口径 / 白名单文件 → **必须**重算 revision 并**清零重生第1轮**，禁止带着旧 `review_input_revision` 硬派第2轮（否则必 stale_dispatch）。
3. 第2轮从固定骨架生成，**不含**第1轮结论；Checker 无写权。
4. 派新独立 Checker；第2轮无 blocker 且 revision 仍一致 → 2/2；有 blocker → Maker 修订、清零回第1轮。

## 6. 岗位接线（摘要）

| 动作 | 责任岗 |
| --- | --- |
| 生成/优化方案工件、验 revision、切第2轮 | PM / planner |
| 生成/刷新代码 CR 工件（含修复后） | PM / developer |
| 可选对抗工件 | PM / code-reviewer |
| 生成/刷新验收派发工件（`mode=verify`） | PM |
| 只读点名工件 + findings / 验收结论 | plan-reviewer / code-reviewer / 验收子窗（Checker **无写权**） |

handoff 转场条目 → [handoff-automation.md](./handoff-automation.md) §I。
