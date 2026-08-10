# test-first 切片（可选模式）

> 触发：程序员发现本 Step 验收可先行写成可执行断言（EditMode / PlayMode 单测、脚本化验证）；PM 或方案点名「测试先行」时启用。
> 出处：mattpocock/skills tdd（红绿重构、垂直切片），2026-08-07 对照落地。**非默认强制**；Unity golden 回归不因本节取消。

## 怎么做

1. 先写**最小可执行断言**：覆盖 A# 中可机械验证的部分（EditMode 纯逻辑 / PlayMode 场景状态）；断言先红（未实现时失败）。
2. 再实现最小切片至断言绿；随后按 Reflexion 微循环继续（[developer SKILL](../developer/SKILL.md) §4.5）。
3. 断言文件放 `Assets/Tests/` 对应模块（或方案夹 `证据/test-first/` 下的脚本化验证），交接时点名路径。
4. golden 场景 / 手测仍按原验收执行；**test-first 绿 ≠ 业务 A# 通过**。

## 边界

- 只对本 Step 新增逻辑写断言；禁止为凑绿改 A# 或加「测试专用」生产分支。
- 断言无法覆盖的（视觉 / 物理手感 / 时序）仍走 Unity 手测，写 `not run` 不得冒称。
- CR 核对：断言与 A# 对齐；断言恒绿但覆盖不到 A# → **major**。
