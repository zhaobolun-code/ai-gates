# 收集仓（本地 shareable 队列）

> **收集仓已开通**：公开仓 [`zhaobolun-code/ai-gates-collect`](https://github.com/zhaobolun-code/ai-gates-collect)。谁都可以开分支交 PR；**合并须权限**（PR 合并=审查，≠已下发）。本机上传仍须 `gh auth status` exit 0 + 独立口令「上传」。禁止把「收集仓已开通」写成「本机已登录」或「技能包已下发」。跨项目闸（evolution-03-promote）depends-on 本机制；收集仓已通后跨项目 ≥2 可实施（须有收集仓同词证据）。

## 定位

跨项目 / 跨会话可传递的条目收集仓。

**不是**：知识缺口（不知道 → `_knowledge-gap.md`）、lessons pending（错题）、`evolution-candidates.yaml`（机器候选）。三者禁止混表。

## 默认载体

`.ai-gates/collect-queue.md`（markdown 表，可检索）。空仓合法。本文件在 `.ai-gates/`（不入 git）= 本机队列。

## 三态

| 态 | 含义 |
| --- | --- |
| `draft` | 草稿（未确认可传） |
| `shareable` | 可传（允许复制/导出） |
| `promoted` | 已晋升引用 |

## 可传

允许把 `shareable` 行复制 / 导出到其他项目的同名队列文件。导出须在实现拍本窗 `证据/` 留一行（本步可只写规则，不必真导出）。

## 不可静默删

禁止钩子 / 脚本自动删行；删行须用户确认。无自动 GC。

## 入队

人工提名，或 01-B 候选经**用户确认**后写入。禁止扫主表 / `evolution-candidates.yaml` 自动入仓。禁止「准」自动入仓。

**本地环**：项目格已「准」条目 → 去上下文化（去掉本仓窗号/场景名/模块专名）→ 写入默认载体 `.ai-gates/collect-queue.md` 且 `state=shareable` → 抽象成通用级草稿仍停在队列 → 仍须用户「准」才入通用格。三态 `draft/shareable/promoted` 不变。写入 `shareable` 后抽象草稿停队列；入通用格须另一次「准」。禁止第二套队列页。

## gh（收集仓已开通；本机仍须探测）

收集仓已开通。公开仓：上传 = fork / 开分支 + PR，**不需要合并权限**。默认载体仍是本地队列（未登录也能留下 `shareable`）。开 PR 的前提是本机探测成功 + 独立口令「上传」。禁止 `gh pr merge`、禁止直接改 `main`。

1. 探测：`gh auth status`（及 `gh --version`）。
2. 仅 exit 0 时，可写「本机已登录，可开 PR」；主通道为 **PR** 到收集仓；issue 仅草稿讨论，不是主上传通道。
3. 探测失败或未跑：**禁止**写「本机已登录 / 已开 PR / 技能包已下发」。**允许**写「收集仓已开通」（仓级事实，不等于本机已登录）。
4. Chemical「准」不触发 `gh pr create` 与 `gh issue create`、不自动入仓。建 PR / 贴 issue 草稿须独立口令「上传」（≠「准」）。缺探测成功 → 不得开 PR；本地队列照常。

须钉死的默认决策：

```text
默认载体仍是 .ai-gates/collect-queue.md
收集仓已开通：公开仓 zhaobolun-code/ai-gates-collect
上传 = fork/开分支 + PR（不需要合并权限）
合并须维护者权限；上传者禁改/合并 main、禁 force push
本机 gh auth status 仅 exit 0 时，可把 shareable 行去上下文化后，
按独立口令「上传」以 PR 写入收集仓（fork → 按模板建条目文件 → PR）
默认仓：zhaobolun-code/ai-gates-collect
  https://github.com/zhaobolun-code/ai-gates-collect
目录：典故/（项目典故）+ 错题本/（项目错题）
模板：templates/典故-条目.md 、 templates/错题本-条目.md
一条一文件；文件名=标题；去上下文化（禁窗号/场景名/文件路径/内部编号）
合并 = 审查（收集仓侧审查，≠ Chemical「准」）
main 受保护：禁直接改/删 main、禁 force push
issue 仅可贴草稿讨论，不是主上传通道
Chemical「准」不触发 gh pr create / gh issue create、不自动入仓
缺探测成功 → 不得开 PR；本地队列照常
禁止 cron；禁止自动扫主表开 PR
zhaobolun-code/ai-gates 仍是技能包真源，不是收集仓默认
下发 = 「项目经理 升级 ai-gates」拉 zhaobolun-code/ai-gates（不是拉 collect 仓，不是再开 PR）
收集仓合并 ≠ 已下发
入通用格须另「准」
```

本窗未将探测成功作为落地前提；未登录时默认出口仍是本地队列。仅用户口令「上传」且本机 `gh auth status` exit 0 时才执行 `gh pr create`。禁止 `gh repo create`。

### 附录：「上传」命令示例（仅独立口令且探测成功才跑）

独立口令「上传」且 `gh auth status` exit 0 时，按收集仓 README 开 **pull request**：

```bash
gh auth status
# fork 后按 templates/ 建一条一文件，再：
# gh pr create --repo zhaobolun-code/ai-gates-collect --title "..." --body "..."
# issue 仅草稿讨论，不是主通道：勿把 gh issue create 当上传。
```

## Skill 自进化（回传 = 升级拉包）

最终：用户上传 GitHub（项目典故 + 项目错题本）→ 抽象成通用级 → 下发到用户 Skill。四格与本仓抽象路径见 [pattern-harvest.md](./pattern-harvest.md) §Skill 自进化。回传=升级拉包：下发=「项目经理 升级 ai-gates」（=`PM upgrade ai-gates`）拉 `zhaobolun-code/ai-gates`，不是拉 collect 仓。收集仓已开通；收集仓合并 ≠ 已下发。入通用格须另「准」。未登录时出口仍是本地队列；上传=collect PR。「准」不开 PR。禁止平行 `github-collect.md`。未验证本机 `gh auth status` 成功时禁止写「本机已登录/已开 PR/技能包已下发」。

本地环到 `shareable` + 抽象草稿为止；「准」才入通用格。禁止把「准」写成自动入仓或自动写入 `shared-language.md` §典故 / `anti-patterns.md` 的触发器。

## 禁止

- 平行第二套队列
- lessons pending 混表
- cron 同步 GitHub
- 未探测成功仍写「本机已登录 / 已开 PR / 技能包已下发」（收集仓已开通 ≠ 本机已登录 ≠ 已下发）
- 把「准」写成 `gh pr create` / `gh issue create` 或自动入仓触发器
- 把 `zhaobolun-code/ai-gates` 当收集仓默认（该仓仅技能包真源）
- 本窗执行 `gh repo create`
- 平行 `github-collect.md`
- 上传者 `gh pr merge` 或直接改 `main`
- 把下发写成拉 collect 仓
