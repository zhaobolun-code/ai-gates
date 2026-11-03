# 迷雾地图结构面（5.0 正式页）

> 人看默认 `.ai-gates/verify/fog-map.html`。助手改当前文档窗须读当前格卡片 + 一度边（默认同目录 `fog-map.json`）。地图是索引，不能替代文档窗真源（`未完成.md` / `物理口径.md` / Mandatory）。
> **加载 ≠ 每轮灌整图。** 禁止把 `fog-map.json` 列入默认必读。禁止 Read `fog-map.html`、截图、布局坐标、把 HTML 注入上下文。禁止要求描述图块坐标。本页是 5.0 正式结构面。
> **迷雾图 ≠ 代码认知地图。** 迷雾 = 文档窗，开窗/改邻接/签收时一张卡 + 一度边。代码认知 = 受管对象全图，有 project-context 该节则**本会话整节一次装载**（读法相反，见 [code-cognition-map.md](./code-cognition-map.md)）。禁止把本页「不灌整图」套到热路径认知卡片。

## 脊骨

- **格 = 窗**：已落盘方案夹是一格（短名 = `nodes[].id`）。
- **路 = 过阈自动连**：计入分 ≥3 的边才是邻格；不要手编边。
- **雾 = 未建夹**：关系点名了但还没有文件夹的名字只进 `fog`，不得当已实现。

## 何时读

仅：**开新窗**、**一度边变化**（邻格增删）、**签收/停写/失败迁夹**。未读邻边不得自称已按 5.0.0 合规。
写方案复用四问「已有吗」/ 问下一窗或文档怎么连 → 同样读本页，按短名查一度边。
本 Step 只改代码、只把 Step 正文迁到 `已完成/`、不改邻接 → **不读**。

## 不读

Express 机械改、纯代码热修不碰文档窗、闲聊、战役中刀只实现 → **不读** 本页与 JSON。

## 出图门 / 直通账本

- **出图门**：仅开窗或迁 `签收` / `停写` / `失败` / `换层` / `回退` 后 PM 必须过门，禁止静默 generate。**禁止**每 Step 收口都问。看**该主题根**有没有 `fog-map.html`：① 无图 → 先判断同一主题是否已能形成大地图；能则问用户 **「是否创建迷雾地图」**，不能成图不问。② 有图 → 问用户 **「是否更新迷雾地图」**。用户同意后再跑 `.ai-gates/scripts/generate-fog-map.ps1`（主题旁用 `-DocRoot` + `-OutFile`；总图无 `-OutFile` 落 `.ai-gates/verify/fog-map.html`）。禁止有夹自动出图；禁止未提示、未同意就跑 generate。禁止手编边。
- **默认人看图落点**：无 `-OutFile` 时 HTML 默认 `.ai-gates/verify/fog-map.html`（瘦 JSON 同目录 `fog-map.json`）。4.x 主题旁 `{DocRoot}/fog-map.html` 是显式 `-OutFile` 试点，不能顶替默认 verify。
- **已有图**：将改的系统文档夹里已有 `fog-map.html` 时，考虑把结构面（本页按短名取一度边）给策划或程序员。仍禁止每轮灌整份 JSON / Read HTML。
- **直通账本**：`.ai-gates/Doc/直通文档/{模块名}/DIRECTLOG.md`（模块名由 PM 写）。生成或关联只在 `.ai-gates/Doc/直通文档/` 下找。挂钉不占格：DIRECTLOG **不是图块**、不是方案夹（不要 `未完成.md`）。禁止为挂接扫 `LabSDK` / `Assets`。
- **跨主题点名**：应指向对方主题真格，不要在本根画成雾。

## 怎么查

1. 禁止用 Read 打开 `fog-map.json` / `fog-map.html`；禁止把 `ConvertFrom-Json` 的 `nodes`/`edges` 整表贴进对话。
2. 按短名打一张卡：跑 `.ai-gates/scripts/query-fog-card.ps1 -Id <窗短名>`。默认 JSON=仓库 `.ai-gates/verify/fog-map.json`；主题旁图用 `-JsonPath` 或 `-DocRoot`（读该目录 `fog-map.json`）。stdout 只有这一张卡（`id`/`state`/`neighbors`/`rec`/`fresh`/`gaps`；可附 `generated`/`jsonPath`/`dir`）。找不到节点 → 输出含 `MISSING`。查询短名不在 `nodes` 也不在 `fog` → 另含 `unexplored`。`query-fog-card.ps1` 不调用 generate、不写 JSON/HTML、只列该节点 `dir`，不扫其它窗。
3. 邻格各 ≤1 行写入对话（短名、等级、文件名）；`quote` 留在卡片，用户追问才出示。`rec` 一行。未过阈的 `near` 与雾名不是邻格卡片行。
4. 缺图或图落后于文档状态 → 按出图门问「是否创建迷雾地图」或「是否更新迷雾地图」，同意后再跑 generate。禁止有夹自动出图。禁止每个 Step 收口都问。
5. `fresh.status` 不是 `fresh` 时仍打印 `neighbors` 与 `gaps`，进程仍 0；不得据此声称关系仍成立。

## 预算

- 邻格各 ≤1 行；推荐下一站 ≤1 行；只读一度边。
- 禁止把整份 JSON（或 100+ 窗）贴进对话。
- 禁止描述图块 x/y。

## 字段（只读合同）

瘦 `nodes[]`：`id`、`state`、`dir`（该窗相对仓库路径、`/` 分隔、generate 扫到的文件夹原样写入）、`fp`、`fpFiles`、`neighbors`、`rec`、`evCount`、`gaps`。顶层：`edges`、`fog`。禁止 `pins` / 布局坐标。

`fresh.status` 只能是 `fresh` / `stale` / `absent`。只比窗指纹，不比 `generated`、不用 mtime。窗指纹覆盖且仅覆盖：`未完成.md`（必有）；`物理口径.md`（存在才算）；窗根 `Mandatory-Step*.md`（不递归）。证据目录不进窗指纹。哈希 = 文件原始字节 SHA-256；payload 路径仓库相对、`/` 分隔、Ordinal 排序、每行 `path=sha256` 加换行、UTF-8 无 BOM，再哈希。旧节点无 `fp`/`fpFiles` 或无 `dir` → `absent`。相对存储 `fpFiles`：内容变、集合里消失、或生成后新增 `物理口径.md`/`Mandatory-Step*.md` → `stale`，`changed` 含该文件名。读卡只列这一 `dir` 发现新增；禁止只重哈希已记名单，禁止从 `id`/`fpFiles` 反推窗根。

过阈边 `neighbors[]` 增加 `grade` 与 `cite`。`grade` 只能是 `confirmed` / `supported` / `inferred`（取最高，禁止并列）。计分 KEEP：关系表 +5、正文 +3、符号共现 +3、证据 +2，过阈 ≥3。`confirmed` 只认关系摘要表格单元格：名称列走 `Get-RelNames`，其它列走该单元格 `Test-IdInText`；段内表外正文不算 rel、不加 +5、不得 `confirmed`。`supported`：已经过阈、无关系表命中、任一侧证据目录点名对方。`inferred`：已经过阈、不是上两者，仅正文或 `.cs` 共现。仅证据 +2 不过阈，进 `pending`，不进 `neighbors`，不是 `supported`。

`cite`：`file`、`quote`、`sha256`、`raw`、`resolved` 均非空。`quote` Trim 后 `.NET String.Length` ≤80。`confirmed` 的 `quote` 取该表实际命中行：名称列命中用名称列那一行（`raw`=解析前名字，`resolved`=邻格 `id`）；名称列未命中、完整短名只在其它列用该列所在行且必须非空（`raw`=`resolved`=对方完整短名）。同一过阈边只一条 cite：两侧关系表或多份证据/正文同时命中时，只取短名 Ordinal 升序靠前那一侧的 `file`/`quote`。证据文件变只标该条 `cite.status=stale`，不把整窗打成 `stale`。

`gaps.kind` 只能四种：`undocumented`（关系摘要点名且当时无方案夹）、`thin-evidence`（本窗 `evCount=0`）、`pending`（与本窗有关、分数 1–2 的 near，含仅证据 +2）、`unexplored`（仅 query：查询短名不在 `nodes` 也不在 `fog`）。禁止第五种。过阈 `inferred` 不进 `pending`。`unexplored` 不列举未被点名的对象。

`rec` 只从 `grade=confirmed ∧ broken=false` 的邻格里挑，过滤后再走现有 `Get-Recommend`。窗状态不是执行中 → `rec` 必须为 `null`。没有合格候选 → `rec` 为 `null`。「有合格候选则 rec 不得为 null」只约束执行中的窗。`supported` / `inferred` 可在 `neighbors`，不得当 `rec`。

读卡能出卡（含 `stale`/`absent`）则 exit 0。非 0 仅当：JSON 不存在或读不成；查询短名不在 `nodes`（`MISSING`，exit 1）；`-SelfCheck` 失败。Agent 不回写地图。地图仍是索引，不替代 `未完成.md` / `物理口径.md` / Mandatory。
