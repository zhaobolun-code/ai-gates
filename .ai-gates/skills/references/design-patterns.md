# 设计模式症状/结构表

> **设计模式症状/结构表**：登记可复用结构的症状、结构与本仓验证实例。流程/架构共识词（神类止血、复用四问、双轴、深模块）见 [shared-language.md](./shared-language.md) §典故——**禁止同义双挂**。

## 词条表

| 典故词 | 触发症状 | 压缩包（适用/结构/本仓验证实例） | 验证状态 | 禁用边界 |
| --- | --- | --- | --- | --- |
| State 快照 | 同帧临时标志/互斥键散落多处 | **适用**：同帧内须互斥执行或只读快照的判据。**结构**：集中 `*RuntimeState` + 帧级只读/记账 API。**本仓验证**：`确定[有代码证据]` `Assets/LabSDK/.../PressureRuntimeState.cs`（帧级字典如 `s_pipeSegmentHandoverExecutedFrameByEndpoint`）+ `Tests/EditMode/PressureRuntimeStateTests.cs`；`推断[有间接证据]` handover 帧互斥模式见 R30 执行中窗 Mandatory（规划落 `PipeSegmentHandoverService`，结构登记不依赖 R30 落地）。 | `static-checked(静态核对)`（见 [evidence-levels.md](./evidence-levels.md)） | 持久业务态；第二套 parallel 字典 |
| Policy 策略 | 门闸 if/switch 分支膨胀 | **适用**：拓扑/门态判定可枚举化。**结构**：`*Policy`/`Evaluate*` 返回枚举态。**本仓验证**：`确定[有代码证据]` `BalanceGroupGatePolicy.cs`（`Evaluate`/`ResolveTopology*`）；`确定[有代码证据]` `PressureController.ValveAndTransferCore.cs:86` `EvaluateOneWayValveFsm`；`推断[有间接证据]` R30 执行中窗读码复核引用上述符号。 | `static-checked(静态核对)` | 单场景 dead branch；Policy 内 mutation |
| Seam Service | 同判据 ≥3 调用点复制 | **适用**：同一物理判据多处重复。**结构**：`*Service` 承载判据+薄 mutation 入口、Controller 一行委托（神类落点写「`*Service` 落点 / 神类止血」指针 [shared-language.md](./shared-language.md) §典故，不得在本表重复登记神类止血词条）。**本仓验证**：`确定[有代码证据]` `PipeSegmentHandoverService.cs` / `GasDomainSolver.cs` / `LiquidSealService.cs`（均位于 `Assets/LabSDK/.../` 压力域 Service 目录）；`推断[有间接证据]` 压力域多起执行窗 Mandatory/CR 留痕引用上述 Service（文档留痕，非单次读码）。 | `static-checked(静态核对)` | 定位器式 DI；Service 再堆 Controller 逻辑 |

## 强制选型句（Mandatory 须含）

```text
采用 {典故词} 模式（触发症状：…；理由：…；词条出处：design-patterns.md §{典故词}）
```

缺触发症状或无本仓验证实例 → **默认 YAGNI**（见 [anti-patterns.md](./anti-patterns.md)）。

验证状态档位见 [evidence-levels.md](./evidence-levels.md)。本仓 §晋升闸已接 01-B；跨项目 ≥2 依赖 `collect-queue.md`（本地已签收；gh 未接线则跨项目不可实施）；6 个月自动降级脚本仍不做。

## 晋升闸

本仓四条（对外称「晋升闸」）。机器候选 ≠ 已确认；晋升仍须人工留痕 + 用户「准」。

1. **本仓复现**：复用已落地 01-B 钥匙（近 90 天 ≥2 次命中且最近命中 ≤30 天）；机器候选=`compute-evolution-candidates.ps1` → `evolution-candidates.yaml`；**候选≠已确认**。
2. **去上下文化**：升 skill 级前去掉项目点名。通用 skill 禁止把项目专名写进词条表（禁用示例：PressureManager）。
3. **禁用边界必填**：五字段「禁用边界」非空。
4. **无争议 + 用户「准」**：方案审/CR 无 blocker 后用户「准」才改 skill 级词条。

**跨项目 ≥2**：依赖收集仓同典故词在 ≥2 项目队列出现（depends-on [collect-queue.md](./collect-queue.md) / 窗 `evolution-01-collect`）。本地队列**已签收**；**gh 未接线** → 本条规则可写、**不可实施**。
