# 深模块设计（codebase-design）

> 触发：设计或改进模块接口、找 deepening 机会、决定 seam 放哪、提升可测性或 AI 可导航性时自动加载。
> 与 [architecture-health-check.md](./architecture-health-check.md) 互补：体检找候选深化点，本文件定形接口 / 找 seam / 做方案对比。
> 出处：mattpocock/skills codebase-design（2026-08-07 对照落地）；词汇为通用设计语言，不登记 `shared-language` 项目术语，与业务冲突时再登记。

## 目标

设计**深模块**：小接口背后大量行为，放在干净的 seam 上，通过接口可测。调用者得 leverage，维护者得 locality，所有人都可测。

## 词汇表（8 词 · 逐词禁止漂移）

用词必须精确，不得用 component / service / API / boundary 等替代——「一致语言」是这套方法的核心。

| 词 | 定义 | 禁止漂移词 |
| --- | --- | --- |
| `Module` | 有接口和实现的东西，刻意跨规模：函数、类、包或跨层切片 | unit / component / service |
| `Interface` | 调用者正确使用模块所需知道的一切：类型签名 + 不变量、顺序约束、错误模式、必要配置、性能特征 | API / signature（过窄，仅类型层表面） |
| `Implementation` | 模块内部的东西、代码体；与 `Adapter` 区分——seam 是主题时用 adapter，否则用 implementation | 与 adapter 混用（两者不是同义词） |
| `Depth` | 接口处的 leverage：调用者（或测试）每学一单位接口能拿到的行为量；深=小接口背后大量行为，浅=接口复杂度接近实现 | depth-as-ratio（实现行数/接口行数口径） |
| `Seam` | 能不改动该处而改变行为的位置；模块接口所在的位置，seam 放哪是独立设计决策 | boundary（DDD 有界上下文重载） |
| `Adapter` | 在 seam 处满足接口的具体东西；描述角色（填什么槽），不是物质（里面是什么） | 无（指角色不指物质） |
| `Leverage` | 调用者从 depth 得到的收益：每学一单位接口获得更多能力；一份实现回馈 N 个调用点 + M 个测试 | 实现体量 / 代码行数（是调用者收益，不是实现大小） |
| `Locality` | 维护者从 depth 得到的收益：变更、bug、知识、验证集中在一处而非散落调用点；修一处全修好 | 代码就近 / 文件位置（是维护者收益，不是放置位置） |

## 四原则

1. **`Depth` 是接口的属性，不是实现的属性。** 深模块内部可以由小块、可 mock、可替换的部件组成——它们只是不进接口。模块可以有**内部 seam**（实现私有、供自身测试用）和接口处的**外部 seam**；内部 seam 不外露进接口，即使测试用到它。
2. **删除测试（deletion test）**：想象删除该模块。复杂度消失 → 是透传；复杂度重新散落到 N 个调用者 → 它在赚自己的存在。
3. **接口就是测试面**：调用者和测试跨同一个 seam。想测接口之外 → 模块形状多半错了。
4. **一个 adapter = 假设的 seam；两个 adapter = 真的 seam**：某处没有真正变化时，不引入 seam。

## 可测性三式

1. **接受依赖而非创建**（Accept dependencies, don't create them）：依赖经参数/构造注入，不在方法内 new。
2. **返回结果而非副作用**（Return results, don't produce side effects）：函数式改写状态；测试断言返回值而非外部变更。
3. **小表面积**（Small surface area）：方法越少要测的越少；参数越少测试 setup 越简单。

## Deepening：四依赖分类 + seam 纪律 + replace-don't-layer

对候选深化簇，先分类其依赖，分类决定跨 seam 怎么测：

| 分类 | 判定 | 深化方式 |
| --- | --- | --- |
| `in-process` | 纯计算 / 内存状态 / 无 I/O | 直接合并模块、经新接口测试；无 adapter |
| `local-substitutable` | 有本地测试替身（如内存文件系统） | 可深化；测试套件用替身跑；seam 是内部的，外部接口无 port |
| `remote-but-owned` | 自己服务跨网络边界（微服务 / 内部 API） | 在 seam 定义 **port**（接口）；深模块拥有逻辑，传输层注入为 **adapter**；测试用内存 adapter，生产用 HTTP/gRPC/队列 adapter |
| `true-external` | 第三方服务（不可控） | 外部依赖作为注入的 port；测试提供 mock adapter |

**seam 纪律**：一个 adapter=假设的 seam，两个=真的；单 adapter 的 seam 只是间接层。区分**内部 seam**（实现私有、自身测试用）与**外部 seam**（接口处）；内部 seam 不进接口。

**测试策略：replace, don't layer**：深模块接口测试就位后，浅模块旧单测变废——删除它们；新测试写在深化后模块的接口上；断言走接口的可观察结果，不碰内部状态；测试应能在内部重构下存活——测试描述行为而非实现。

## 被拒框架

- **depth-as-ratio**（实现行数/接口行数）：奖励注水实现。用 depth-as-leverage。
- **interface 只是类型层关键字 / 公开方法**：太窄——interface 含调用者须知道的一切事实。
- **boundary**：被 DDD 有界上下文重载；说 seam 或 interface。

## 并行接口设计

需要为深化候选探索多种接口方案时，按 [design-it-twice.md](./design-it-twice.md) 起 3+ 并行子代理设计 radically different 接口，再对比推荐。
