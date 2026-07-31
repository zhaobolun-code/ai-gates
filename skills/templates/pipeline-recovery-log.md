# 流水线恢复记录（项目专属）

> **位置**：复制本模板 → 仓库根 **`.cursor/pipeline-recovery-log.md`**（勿提交敏感信息时可加入 `.gitignore`）。
> **何时追加**：用户发送 `按 CORE 重来` / `流水线重来` 时，Agent 在恢复流程末尾追加一行。
> **快照日志**（全量 PM 轨迹）：`.cursor/pipeline-snapshot.log` — 见 [pipeline-snapshot-log.md](./pipeline-snapshot-log.md)
> 偏差类型枚举 → [references/retrospective-metrics.md](../references/retrospective-metrics.md) §恢复偏差类型

## 记录表

| 日期 | 偏差类型 | 原车道 | 恢复后车道 | 备注 |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD | 示例：缺 PM 结构化输出 | Express | Express | 已补 YAML 块 |

## 用法

- **Agent**：每次恢复追加一行，不删历史行；并 `append-pipeline-snapshot.ps1 -Event recovery -DeviationType ...`
- **TL**：`summarize-pipeline-metrics.ps1` 汇总 snapshot + 本表；按 sprint 驱动 CORE / SKILL 修订
