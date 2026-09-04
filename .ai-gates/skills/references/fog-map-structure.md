# 迷雾地图结构面（5.0 正式页）

> 人看默认 `.ai-gates/verify/fog-map.html`。助手改当前文档窗须读当前格卡片 + 一度边（默认同目录 `fog-map.json`）。地图是索引，不能替代文档窗真源（`未完成.md` / `物理口径.md` / Mandatory）。
> **加载 ≠ 每轮灌整图。** 禁止把 `fog-map.json` 列入默认必读。禁止 Read `fog-map.html`、截图、布局坐标、把 HTML 注入上下文。禁止要求描述图块坐标。本页是 5.0 正式结构面。

## 脊骨

- **格 = 窗**：已落盘方案夹是一格（短名 = `nodes[].id`）。
- **路 = 过阈自动连**：计入分 ≥3 的边才是邻格；不要手编边。
- **雾 = 未建夹**：关系点名了但还没有文件夹的名字只进 `fog`，不得当已实现。

## 何时读

改当前文档窗须读当前格卡片 + 一度边。未读邻边不得自称已按 5.0.0 合规。
写方案复用四问「已有吗」/ 问下一窗或文档怎么连 → 同样读本页，按短名查一度边。

## 不读

Express 机械改、纯代码热修不碰文档窗、闲聊 → **不读** 本页与 JSON。

## 出图门 / 直通账本

- **出图门**：文档状态改变后（新建窗口，或迁 `执行中` / `签收` / `停写` / `失败` / `换层` / `回退`）PM 必须过门，禁止静默 generate。看**该主题根**有没有 `fog-map.html`：① 无图 → 先判断同一主题是否已能形成大地图；能则问用户 **「是否创建迷雾地图」**，不能成图不问。② 有图 → 问用户 **「是否更新迷雾地图」**。用户同意后再跑 `.ai-gates/scripts/generate-fog-map.ps1`（主题旁用 `-DocRoot` + `-OutFile`；总图无 `-OutFile` 落 `.ai-gates/verify/fog-map.html`）。禁止有夹自动出图；禁止未提示、未同意就跑 generate。禁止手编边。
- **默认人看图落点**：无 `-OutFile` 时 HTML 默认 `.ai-gates/verify/fog-map.html`（瘦 JSON 同目录 `fog-map.json`）。4.x 主题旁 `{DocRoot}/fog-map.html` 是显式 `-OutFile` 试点，不能顶替默认 verify。
- **已有图**：将改的系统文档夹里已有 `fog-map.html` 时，考虑把结构面（本页按短名取一度边）给策划或程序员。仍禁止每轮灌整份 JSON / Read HTML。
- **直通账本**：`.ai-gates/Doc/直通文档/{模块名}/DIRECTLOG.md`（模块名由 PM 写）。生成或关联只在 `.ai-gates/Doc/直通文档/` 下找。挂钉不占格：DIRECTLOG **不是图块**、不是方案夹（不要 `未完成.md`）。禁止为挂接扫 `LabSDK` / `Assets`。
- **跨主题点名**：应指向对方主题真格，不要在本根画成雾。

## 怎么查

1. 禁止用 Read 打开 `fog-map.json` / `fog-map.html`；禁止把 `ConvertFrom-Json` 的 `nodes`/`edges` 整表贴进对话。
2. 按短名打一张卡：跑 `.ai-gates/scripts/query-fog-card.ps1 -Id <窗短名>`。默认 JSON=仓库 `.ai-gates/verify/fog-map.json`；主题旁图用 `-JsonPath` 或 `-DocRoot`（读该目录 `fog-map.json`）。stdout 只有这一张卡（`id`/`state`/`neighbors`/`rec`；可附 `generated`/`jsonPath`）。找不到节点 → 输出含 `MISSING`。
3. 邻格各 ≤1 行写入对话；`rec` 一行。未过阈的 `near` 与雾名不是邻格卡片行。
4. 缺图或图落后于文档状态 → 按出图门问「是否创建迷雾地图」或「是否更新迷雾地图」，同意后再跑 generate。禁止有夹自动出图。

## 预算

- 邻格各 ≤1 行；推荐下一站 ≤1 行；只读一度边。
- 禁止把整份 JSON（或 100+ 窗）贴进对话。
- 禁止描述图块 x/y。

## 字段（只读合同）

`nodes[]`：`id`、`state`、`neighbors`、`rec`。顶层：`edges`、`fog`。禁止 `pins` / 布局坐标。
