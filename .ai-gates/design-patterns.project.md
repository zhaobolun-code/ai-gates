# 设计模式 — 本仓验证（项目专属）

> **不进技能包。** 通用词条在 `skills/references/design-patterns.md`。本文件只记本仓库的代码锚点，供策划「有则复用」。  
> 入表仍须用户「准」。打包 / 升级 / 拷到别的仓库时不要带上本文件。

| 典故词 | 本仓验证 | 验证状态 |
| --- | --- | --- |
| State 快照 | `确定[有代码证据]` `Assets/LabSDK/.../PressureRuntimeState.cs`（帧级字典如 `s_pipeSegmentHandoverExecutedFrameByEndpoint`）+ `Tests/EditMode/PressureRuntimeStateTests.cs`；`推断[有间接证据]` handover 帧互斥模式见 R30 执行中窗 Mandatory（规划落 `PipeSegmentHandoverService`，结构登记不依赖 R30 落地）。 | `static-checked(静态核对)` |
| Policy 策略 | `确定[有代码证据]` `BalanceGroupGatePolicy.cs`（`Evaluate`/`ResolveTopology*`）；`PressureController.ValveAndTransferCore.cs:86` `EvaluateOneWayValveFsm`；`EvaporationPolicy.cs` + `EvaporationPolicyResolver.Resolve`；`EvaporationService` `switch (resolved.Policy)`；`推断[有间接证据]` R30 执行中窗读码复核引用上述符号。 | `static-checked(静态核对)` |
| Seam Service | `确定[有代码证据]` `PipeSegmentHandoverService.cs` / `GasDomainSolver.cs` / `LiquidSealService.cs`（压力域 Service 目录）；`推断[有间接证据]` 压力域多起执行窗 Mandatory/CR 留痕引用上述 Service。 | `static-checked(静态核对)` |
| 事件分发（观察者） | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Events/ChemicalEquipmentEventDispatcher.cs`；`BaseEquipment.OnStateChanged`；`ConfigurablePourAbility` 订阅 `PourUIEvent`。平台/第三方（`GlobalEventObserver`、XCharts、AVPro）不当验证实例。 | `static-checked(静态核对)` |
| 命令（撤销） | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/UI/Revocation/ICommand.cs`；`CommandManager.cs`；`ICommand_Move.cs`（及 `ICommand_Delete.cs`）。URP CommandBuffer / `UndoManager`（`IUndoCommand`）/ 第三方不当验证实例。 | `static-checked(静态核对)` |
| 能力模板 | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Abilities/Core/InteractionAbilityBase.cs`；子类 `ConfigurablePourAbility` / `SimpleHeatingAbility`（均 `override Execute`）；`InteractionManager.StartInteraction` `ability.Execute(source, target)` 与 `InteractionPair.Execute` 内同调。 | `static-checked(静态核对)` |
| 简单工厂（按类型创建） | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Data/ChemicalSubstanceDataFactory.cs` 的 `CreateSubstanceData`（及 `CreateSubstanceDataByMoles`）：查 `ChemicalDataManager` 配置后 `new ChemicalSubstanceData`。 | `static-checked(静态核对)` |
| 特效适配器 | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Visual/IEffectAdapter.cs`；`EffectSpawner.InitializeAdapters` 与 `adapters[effectType].AdaptEffect`（约 `:167`）；`BubbleEffectAdapter`（及同目录其余 `*EffectAdapter`）。**邻仓配方落地**：`确定[有代码证据]` `../THYJ/Assets/Scripts/Farm/FarmBloomGate.cs` 的 `Emerge`/`Retarget`/`Adapt`/`Update`；`FarmPlotSystem` 成功点直调。不当本仓复用入口。 | `static-checked(静态核对)` |
| 倾倒策略 | `确定[有代码证据]` `Assets/LabSDK/Runtime/Pennon/ExplorationLab/Chemical/Abilities/Pour/IPourStrategy.cs`；`TopLayerPourStrategy` / `ProportionalPourStrategy`；`ConfigurablePourAbility.ExecutePourLogic` `pourStrategy.Pour(...)`。平台 `HMKJ.Procedure.Strategy`（投屏）不当验证。 | `static-checked(静态核对)` |
