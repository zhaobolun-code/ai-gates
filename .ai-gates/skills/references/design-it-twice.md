# 并行接口设计（design-it-twice）

> 触发：为选定深化候选探索替代接口时使用（基于 Ousterhout「Design It Twice」——第一个想法大概率不是最好的）。
> 词汇与 [codebase-design.md](./codebase-design.md) 一致：module / interface / seam / adapter / depth / leverage / locality。

## 流程

1. **先向用户展示问题空间**：写一段用户可见的问题空间说明——新接口须满足的约束、依赖及所属分类（见 codebase-design 四依赖分类）、一张示意草图把约束落地（不是方案，只是让约束具体）。展示后立即进入第 2 步；用户阅读思考的同时子代理并行工作。
2. **3+ 子代理并行设计**：每个子代理产出一个 **radically different** 接口。各自独立技术简报（文件路径、耦合细节、依赖分类、seam 背后是什么），并给不同设计约束：
   - 代理 1「最小接口」：入口 ≤3 个，最大化每个入口的 leverage。
   - 代理 2「最大灵活」：支持多种用例与扩展。
   - 代理 3「最常用调用者优先」：默认用例零成本。
   - 代理 4（适用时）「端口适配器」：围绕跨 seam 依赖设计 ports & adapters。
   每个子代理输出：接口（类型 / 方法 / 参数 + 不变量、顺序、错误模式）、调用示例、实现藏在 seam 后面的东西、依赖策略与 adapter、权衡（哪里 leverage 高 / 薄）。
3. **按对比维度比较**：按 `depth`（接口处 leverage）、`locality`（变更集中度）、`seam placement` 对比各设计。
4. **给有观点推荐**：给出最强的设计及理由；不同设计元素能组合则提出 hybrid。**有观点，不交菜单**。

## 本仓接线

- 子代理任务按 [agent-brief.md](./agent-brief.md) 委托书撰写（耐久 / 行为式 / 验收标准 / out of scope），派发按 [model-routing.md](./model-routing.md) 实测（完整任务随 spawn 初始消息投递；显式 `model=` 需 `fork_turns=none`）。
- 子代理只读白名单：点名文件 / 路径；禁止改交付物。
