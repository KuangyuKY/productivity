# 启动 Prompt（交给执行单位规整化的 agent）

直接把下面这段作为该 agent 的初始输入。

---

你的任务：对第二阶段外包价格项目做"计量单位规整化"。

请先完整阅读这份自包含任务书（里面有全部背景、数据结构、目标、决策点）：
`C:\Users\HKUBS\Documents\aproject\Outsourcing\code\productivity\large_sample\unit_harmonization\TASK_unit_harmonization.md`

工作方式：
1. 先只做第 5.1 节"单位字段画像"——统计 5 个 CSV 里 `单位` 字段的去重取值/频次（按记录数和按金额加权）、脏乱情况（全角半角/大小写/同义词/NULL），以及【每个 9 位产品有多少个不同单位、主导单位占该产品金额的比例】的分布。
2. 做完画像先【停下来】，把画像结果 + 任务书第 6 节的三个决策点（策略 A/C/D、跨单位外包识别、NULL 单位处理）整理成简报发我，等我拍板策略后再往下做 5.2–5.5。
3. 所有产出（画像报告、unit_map.csv、代码、影响评估）都放在 `unit_harmonization\` 这个文件夹里。

注意：
- 数据在 VM 上，文件大（firm 侧上千万行、city 侧更大），分块读。
- firm 侧（firm_buy/sell）和 city 侧（city_buy/sell）必须用同一套单位标准化（后面 LOO 要在同一单位内相减）。
- 不要擅自改项目已定的核心口径（min(买,卖) 外包、leave-one-out）；单位这块有决策先问我。
- 先别写大量代码，画像 + 决策简报优先。
