# Hooks 硬门禁（观察期 · 未默认启用）

> 状态：**评估完成，暂不强制启用**（2026-07-14）。先靠 Skill 纪律 + `validate-pipeline.ps1` advisory。

## 目标（未来）

用 Cursor Hooks 在「无 PM / 无白名单读归档」时机器拦截，避免仅靠模型自觉。

## 为何暂缓

1. Unity 大仓误伤成本高（合法 Read `已完成/_索引.md`、合法抽 Mandatory）。  
2. 「无 PM 不改交付物」已是硬门禁 #7；再加 Hook 需先有稳定 path 白名单。  
3. 当前杠杆更大的是：窗口化 + 派发最短包 + CodeGraph 定向。

## 启用条件（满足后再做）

- 窗口化方案文件夹 ≥3 个且跑满 2 周无「误禁读」投诉  
- `validate-pipeline.ps1` 对窗口结构检查稳定为 green  
- TL 书面同意 soft→hard

## 候选规则（届时）

- soft warn：Read 匹配 `**/已完成/历史全文*` 或 `**/证据/**` 且派发未声明例外  
- soft warn：改 `Assets/**/*.cs` 前本会话无 `[PM]` 标记（难可靠，慎做）

在此之前：**禁止**安装会阻断提交/读写的硬 Hook。
