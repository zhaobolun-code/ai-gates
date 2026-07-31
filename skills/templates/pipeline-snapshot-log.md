# 流水线快照日志（项目专属）

> **位置**：`.cursor/pipeline-snapshot.log`（JSONL；已 `.gitignore`，勿提交）
> **模板初始化**：`init-project-context.ps1` 或首次 `append-pipeline-snapshot.ps1`
> **汇总**：`.cursor/scripts/summarize-pipeline-metrics.ps1`

## 何时追加

| event | 触发 |
| --- | --- |
| `pm` | 每轮 `[PM]` 输出结构化 YAML 后（车道判定 / 派岗变更） |
| `recovery` | 用户 `按 CORE 重来` / `流水线重来` |
| `milestone` | `user_state` 变为 **已定版** 或车道升级 |

Agent 应运行脚本；失败则 **Write** 手工 JSONL（见 [pm-tooling.md](../references/pm-tooling.md)）：

```powershell
powershell -ExecutionPolicy Bypass -File .cursor/scripts/append-pipeline-snapshot.ps1 -Event pm ...
```

或手工追加一行 JSON（YAML 标 `snapshot: manual`）。

## JSONL 字段

| 字段 | 说明 |
| --- | --- |
| `ts` | ISO 时间 |
| `event` | pm / recovery / milestone |
| `lane` | Express / Standard / Full |
| `review_tier` | skip / L1 / L1.5 / L2 / L3 |
| `next_role` | planner / developer / CR / … |
| `user_state` | 五态 |
| `lane_rules_hit` | 如 `4/4`、`3→Standard` |
| `diff_hint` | suggest-pipeline-lane 辅助值 |
| `project_context` | loaded / missing-coldstart |
| `deviation_type` | recovery 时（见 retrospective-metrics） |
| `note` | 可选备注 |

## 与 recovery-log 关系

- **pipeline-recovery-log.md**：人类可读表格，仅恢复偏差
- **pipeline-snapshot.log**：全量 PM 状态轨迹，供 TL 统计 lane/L1.5 合规率

偏差类型枚举 → [references/retrospective-metrics.md](../references/retrospective-metrics.md)
