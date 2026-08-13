# 覆盖度表（机器可核验）

> evolution-02。读过 / 测过 / 失败过须机器源，**禁止模型自报**覆盖率或百分比。

## 三维与机器源

| 列 | 机器源 | 缺源 |
| --- | --- | --- |
| 测过 | `.ai-gates/verify/editmode-tests.trx`（`run-dotnet-editmode-tests.ps1`） | `tested.status=missing`，rows 空；**禁止填 100%** |
| 失败过 | `.ai-gates/regression-heat.yaml` + `.ai-gates/pipeline-outcome.log` | heat 缺 → `failed` **整块** `missing`；outcome 缺 → `outcome_event_count: missing`，heat 行仍列出、**不与 outcome 对齐** |
| 结构覆盖（代理「读过」） | 项目根 `.codegraph/` 存在性 + 可统计文件相对路径 | 无目录 → `structure.status=index_absent` |

**硬句**：结构覆盖 = 索引可达，**结构可达 ≠ 本会话已读**。一次 `codegraph_explore` ≠ 已读 blast radius。无会话 read-trace；本机制不新建平行读取探针。

## 权威产出

`.ai-gates/coverage-map.yaml`，**仅** `compute-coverage-map.ps1` 可写覆盖率/计数字段。

顶层**元数据键白名单仅** `generated_by: compute-coverage-map.ps1` 与 `source_fingerprint`（三源存在性或内容指纹，稳定可重算）。**数据块仅三块** `tested` / `failed` / `structure`（块状态在块内）。两元数据键与「数据块仅三块」**不互斥**。禁止第四数据块、禁止顶层白名单外键、禁止跨源 join、禁止 `coverage_percent`。

行键源内：trx=`test_fullname`（`UnitTestResult/@testName`，行值至少 `outcome`）；heat=现有 `module`/`path` 及其标量；codegraph=相对 `.codegraph/` 的路径。块内点名标量仅 `failed.outcome_event_count`、`structure.file_count`。

## `-Verify`

无开关=生成 yaml。`-Verify`=重算后**点名比对**：`generated_by` 字面、`source_fingerprint`、三块**行键集合**、**各行行值**、点名标量、块状态。yaml 不存在或不一致 → **非 0**。禁止只比条数或哑 `count`。手改行键或计数字段（如 `fail_count` / `outcome_event_count`）未重跑 → 非 0。

## 与 heat 的边界

`regression-heat.yaml`（`compute-failure-heat.ps1`）是**失败热度**，**不是**覆盖度。覆盖度表只读 heat 作「失败过」一列；禁止把 heat 档位、三源计数相除或加权当成总覆盖率。

## 禁止

- 模型自报「我读过/测过 X%」
- 无机器源的空表充作已启用
- 改 trx 绿灯或 heat 档位来「做绿」覆盖度
- 会话级 read-log / cron 刷表（非本机制）
