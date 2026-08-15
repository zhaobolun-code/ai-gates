# 设计模式症状/结构表

> **设计模式症状/结构表**：登记可复用结构的症状、结构与本仓验证实例。流程/架构共识词（神类止血、复用四问、双轴、深模块）见 [shared-language.md](./shared-language.md) §典故——**禁止同义双挂**。

## 对仓压缩

人给教材三说明（定义 / 优缺点 / 适不适合）→ 对仓找**结构**锚点（不搜 GoF 类名）→ 三档：

| 档 | 处理 |
| --- | --- |
| 有真锚点（LabSDK 业务代码） | 压成五格提名；用户「准」才写入本表 |
| 误匹配（平台/第三方/仅像） | 不当本仓验证；不提名 |
| 本仓没有 | 不沉淀 |

禁止：全量 GoF 图鉴；无锚点入库；把教材优点/开闭原则/异框架示例写进词条；热度满自动入典。表上限 **6 行**（含已有）；超过先停。现有词条禁止同义再挂。优点不入库。「不适合」升成禁用边界。「适合」压成触发症状。一次一条。入表通道=模式沉淀（见 [pattern-harvest.md](./pattern-harvest.md)）；本表上限仍 6 行。

## 词条表

| 典故词 | 触发症状 | 压缩包（适用/结构/本仓验证实例） | 验证状态 | 禁用边界 |
| --- | --- | --- | --- | --- |
| State 快照 | 同帧临时标志/互斥键散落多处 | **适用**：同帧内须互斥执行或只读快照的判据。**结构**：集中 `*RuntimeState` + 帧级只读/记账 API。**本仓验证**：`确定[有代码证据]` `Assets/LabSDK/.../PressureRuntimeState.cs`（帧级字典如 `s_pipeSegmentHandoverExecutedFrameByEndpoint`）+ `Tests/EditMode/PressureRuntimeStateTests.cs`；`推断[有间接证据]` handover 帧互斥模式见 R30 执行中窗 Mandatory（规划落 `PipeSegmentHandoverService`，结构登记不依赖 R30 落地）。 | `static-checked(静态核对)`（见 [evidence-levels.md](./evidence-levels.md)） | 持久业务态；第二套 parallel 字典 |
| Policy 策略 | 门闸 if/switch 分支膨胀 | **适用**：拓扑/门态判定可枚举化。**结构**：`*Policy`/`Evaluate*` 返回枚举态。**本仓验证**：`确定[有代码证据]` `BalanceGroupGatePolicy.cs`（`Evaluate`/`ResolveTopology*`）；`确定[有代码证据]` `PressureController.ValveAndTransferCore.cs:86` `EvaluateOneWayValveFsm`；`推断[有间接证据]` R30 执行中窗读码复核引用上述符号。 | `static-checked(静态核对)` | 单场景 dead branch；Policy 内 mutation |
| Seam Service | 同判据 ≥3 调用点复制 | **适用**：同一物理判据多处重复。**结构**：`*Service` 承载判据+薄 mutation 入口、Controller 一行委托（神类落点写「`*Service` 落点 / 神类止血」指针 [shared-language.md](./shared-language.md) §典故，不得在本表重复登记神类止血词条）。**本仓验证**：`确定[有代码证据]` `PipeSegmentHandoverService.cs` / `GasDomainSolver.cs` / `LiquidSealService.cs`（均位于 `Assets/LabSDK/.../` 压力域 Service 目录）；`推断[有间接证据]` 压力域多起执行窗 Mandatory/CR 留痕引用上述 Service（文档留痕，非单次读码）。 | `static-checked(静态核对)` | 定位器式 DI；Service 再堆 Controller 逻辑 |
| 事件分发（观察者） | 一处交互事实要通知多处，且变更源不关心谁响应、不必拿返回值 | **适用**：订阅-推送。**结构**：优先复用已有 `ChemicalEquipmentEventDispatcher`（枚举事件 + 成对 `AddListener`/`RemoveListener`/`Dispatch`，分发须快照）。对象局部一对多用已有 C# `event`。禁止新开第二套全局总线。**本仓验证**：`确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Events/ChemicalEquipmentEventDispatcher.cs`；`确定[有代码证据]` `BaseEquipment.OnStateChanged`；`确定[有代码证据]` `ConfigurablePourAbility` 订阅 `PourUIEvent`。平台/第三方（`GlobalEventObserver`、XCharts、AVPro）不当验证实例。 | `static-checked(静态核对)` | 仅通知一个固定对象 → 直调。同帧须保序或拿返回值 → 直调。物理步进/门闸/传质/守恒判定禁止走事件总线。回调内禁止再改主题状态。高频每帧全量广播禁止。订阅必须成对解除 |
| 命令（撤销） | 用户操作要可撤销/重做，或要把「做了什么」从「当场改场景」拆开再入栈 | **适用**：用户操作须可撤销/重做，或把「做了什么」从当场改场景拆开再入栈。**结构**：复用已有 `ICommand`（Execute/Undo/Redo）+ `CommandManager` 双栈（`CommandContainer.undoStack`/`redoStack`）；新操作加 `ICommand_*`，禁止第二套撤销栈。**本仓验证**：`确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/UI/Revocation/ICommand.cs`；`确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/UI/Revocation/CommandManager.cs`；`确定[有代码证据]` `ICommand_Move.cs`（及 `ICommand_Delete.cs`）。URP CommandBuffer / `UndoManager`（`IUndoCommand`）/ 第三方不当验证实例。 | `static-checked(静态核对)` | 压力步进/门闸/传质/守恒 → 直调不要包 Command。只要返回值或同帧必须保序 → 直调。一次性内部调用不需要撤销 → 不要套壳。禁止新开第二套 undo/redo 栈 |
| 能力模板 | 器材之间一种交互（倒液/加热/镊取等）要走同一套「能否交互 → 执行」生命周期，且各器材只差 Execute 体内 | **适用**：器材间交互共享生命周期、差异只在 Execute。**结构**：继承/复用 `InteractionAbilityBase`，在 `Execute(source,target)` 写该能力；由既有 `InteractionManager` 调度。禁止为单一器材新开平行交互管理器。**本仓验证**：`确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Abilities/Core/InteractionAbilityBase.cs`；`确定[有代码证据]` 子类 `ConfigurablePourAbility` / `SimpleHeatingAbility`（均 `override Execute`）；`确定[有代码证据]` `InteractionManager.StartInteraction` `ability.Execute(source, target)` 与 `InteractionPair.Execute` 内同调。 | `static-checked(静态核对)` | 一次性内部直调、不需要交互生命周期 → 不要新 Ability。热路径/压力/门闸/传质/守恒不要做成 Ability。禁止新开平行 InteractionManager。与 `ICommand` 撤销栈不是同一结构（撤销走命令词条）。不要把 `IPourStrategy` 再挂成第二条策略（已有 Policy 词条）。输入设备（鼠标/陀螺仪）不要写进 Ability 体内（输入输出分离，只点名既有 `输入输出分离架构设计.md`，不在本表展开）。 |

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
