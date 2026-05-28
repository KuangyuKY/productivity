# 第二阶段实证：外包价格的决定因素 — 项目说明文档

**最后更新：2026-05-25**

本文档记录第二阶段实证的整体框架、数据结构、代码管线和当前进度，供新会话接力或向他人交接使用。

---

## 目录

1. [项目背景与研究问题](#1-项目背景与研究问题)
2. [与第一阶段的关系](#2-与第一阶段的关系)
3. [工作目录结构](#3-工作目录结构)
4. [数据文件说明](#4-数据文件说明)
5. [SQL 数据抽取逻辑](#5-sql-数据抽取逻辑)
6. [清洗管线：01_clean.ipynb](#6-清洗管线01_cleanipynb)
7. [回归管线：02_price_reg.do](#7-回归管线02_price_regdo)
8. [回归方程设计](#8-回归方程设计)
9. [已确认的设计决策](#9-已确认的设计决策)
10. [当前进度与待办事项](#10-当前进度与待办事项)
11. [已知限制与风险说明](#11-已知限制与风险说明)

---

## 1. 项目背景与研究问题

**研究题目**：Output Outsourcing, Product Diversification, and Industry Growth

**第二阶段核心问题**：

> 企业的外包价格（即企业以买方身份购买某产品时支付的单价）由哪些因素决定？

具体地：

- **企业特征**（规模、产品广度）如何影响它能拿到的外包价格？
- **市场条件**（买方数、卖方数、市场总量、市场均价）如何影响交易价格？
- 大企业是否更能利用市场厚度拿到更低的采购价？
- 需求侧（买方竞争）与供给侧（卖方竞争）的影响方向和大小是否对称？

**理论联系**：在模型中，外包价格目前作为外生变量处理（简化模型）。本阶段用数据打开它，为后续判断是否需要将价格形成机制内生化提供实证依据。

---

## 2. 与第一阶段的关系

| 维度 | 第一阶段（description/） | 第二阶段（productivity/） |
|---|---|---|
| **数据层级** | firm × product × year 聚合面板 | 发票层预聚合 CSV（firm × product 年总） |
| **核心 DV** | outsourcing_percen（外包比例） | 单价 = 金额合计 / 数量合计（外包价格） |
| **主要 IV** | input_similarity, output_similarity | 企业规模, 买方数, 卖方数, 市场均价 |
| **主要数据源** | full_data.dta（75M 行，含相似度） | 增值税发票 CSV（SQL 预聚合） |
| **企业特征** | 来自 full_data.dta 本身 | 来自 full_data.dta（跨阶段 merge） |

第二阶段继续使用 `full_data.dta` 和 `bianma.dta` 作为辅助数据源，与发票数据 merge。

---

## 3. 工作目录结构

**本地**（代码写作 + git 同步）：
```
C:\Users\HKUBS\Documents\aproject\Outsourcing\code\productivity\
├── HANDOFF.md              ← 本文件
├── data_des.md             ← 虚拟机数据位置与 SQL 代码记录（调试用）
├── original_data.md        ← 早期原始发票字段说明（已部分过时）
├── meeting_minutes_*       ← 会议纪要（pdf + tex）
├── 01_clean.ipynb          ← Python 清洗脚本（★ 主要工作文件）
├── 02_price_reg.do         ← Stata 回归脚本（★ 主要工作文件）
└── clean/                  ← （空）预留给中间产物
```

**虚拟机**（实际运行数据 + 跑代码）：
```
G:\Kuangyu_Temp\Outsource\
├── full_data.dta              ← 第一阶段主面板（firm × product × year）
├── bianma.dta                 ← 2778 个 9 位产品码 + 货物名称
└── productivity\              ← 本阶段工作目录
    ├── *firm_buy.csv          ← 购方企业 × 产品 聚合（★ 主 DV 来源）
    ├── *firm_sell.csv         ← 销方企业 × 产品 聚合
    ├── *city_buy.csv          ← 购方地区 × 产品 聚合（市场需求条件）
    ├── *city_sell.csv         ← 销方地区 × 产品 聚合（市场供给条件）
    ├── firm_region.csv        ← 企业 ID → 地区代码映射（SQL 跑完后落盘，待同步）
    ├── 01_clean.ipynb         ← 由本地 git 同步过来
    ├── 02_price_reg.do        ← 由本地 git 同步过来
    └── output\                ← 清洗 + 回归输出落盘目录（自动创建）
        ├── invoice_panel.dta
        ├── market_conds.dta
        ├── firm_chars.dta
        ├── reg_panel.dta
        ├── T1_baseline.txt
        ├── T2_demand_supply.txt
        ├── T3_interactions.txt
        └── T4_no_inter.txt
```

---

## 4. 数据文件说明

### 4.1 新增发票 CSV（4 类，每类覆盖 2017 全年）

| 文件后缀 | 加总维度 | 主要列 | 用途 |
|---|---|---|---|
| `*firm_buy.csv` | (购方企业id, 项目代码) | 购方企业id, 项目代码, 金额合计, 数量合计 | 构造 DV：firm i 买 product p 的单价 |
| `*firm_sell.csv` | (销方企业id, 项目代码) | 销方企业id, 项目代码, 金额合计, 数量合计 | 构造企业销售规模（firm size 辅助 proxy） |
| `*city_buy.csv` | (购方地区, 项目代码) | 购方地区, 项目代码, 金额合计, 数量合计 | 需求侧市场条件：买方数、总量、均价 |
| `*city_sell.csv` | (销方地区, 项目代码) | 销方地区, 项目代码, 金额合计, 数量合计 | 供给侧市场条件：卖方数、总量、均价 |

**注意**：所有 ID、代码字段均为字符串存储；`项目代码` 仍是原始长码，未经清洗。

### 4.2 待同步数据

| 文件 | 内容 | 状态 |
|---|---|---|
| `firm_region.csv` | 购方企业id → 购方地区（4 位）映射，每 firm 一行 | SQL 正在跑，待落盘 |

### 4.3 沿用数据（来自第一阶段）

| 文件 | 位置 | 用途 |
|---|---|---|
| `full_data.dta` | `G:\Kuangyu_Temp\Outsource\` | firm × year 特征：firm_total_output, n_products, is_intermediary |
| `bianma.dta` | `G:\Kuangyu_Temp\Outsource\` | 2778 个合法 9 位产品码，用于产品代码匹配 |

---

## 5. SQL 数据抽取逻辑

数据库中原始发票表 `dbo.GX1701/1702/1703`，均通过 `UNION ALL` 合并后按样本企业 (`tmp_sample_cid`) 过滤，然后分别按购方/销方维度 `GROUP BY` 求和输出。

**关键细节**：
- 红冲发票（负值）**未被过滤**，直接与正值合并求和。净值可能 ≤ 0，需 Python 端清洗。
- 数量用 `TRY_CAST(数量 AS float)` 转换，无法转换的（含字母乱码）变为 NULL，`SUM` 自动忽略。数量合计可能为 NULL（所有行均无法转换时）。
- `项目代码` 未做任何清洗——原始长码，可含字母、长度不等，需 Python 端匹配 bianma。
- 样本企业是基于企业 ID 的**抽样子集**（`tmp_sample_cid`），不是全量。city 级聚合是从这些样本企业的交易计算的，因此 `n_buyers` 等指标反映的是**样本内市场活跃度**而非全国总量。

---

## 6. 清洗管线：01_clean.ipynb

**文件**：`01_clean.ipynb`（Python，Jupyter notebook，顺序型 cell，无封装函数）

### 清洗步骤

| Step | 内容 | 关键操作 |
|---|---|---|
| 1 | 读入 CSV | 指定 dtype（ID/代码列为 str），na_values 统一识别 NULL/空 |
| 2 | 数值列转换 | `pd.to_numeric(errors='coerce')` for 金额/数量/单价/税额；打印缺失率 |
| 3 | 项目代码清洗 | ① 过滤非纯数字码 ② 右补零至 19 位 ③ 截前 9 位 → `product_id` |
| 4 | bianma 匹配 | inner join，只保留 2778 个合法产品，打印匹配率 |
| 5 | 净值过滤 | 丢弃 金额合计 ≤ 0 或 数量合计 ≤ 0 的行（红冲未覆盖的异常净值） |
| 6 | 构造 DV | `p_buy = 金额合计 / 数量合计`；同时保存 `ln_p_buy` |
| 7 | 市场条件 | 从 city_buy 构造：`n_buyers`, `mkt_qty`, `p_mkt`；从 city_sell 构造 `n_sellers` |
| 8 | merge 企业地区 | firm_buy × firm_region.csv（待同步）→ 拿到每家企业的 `city` |
| 9 | merge 企业特征 | firm_buy × full_data.dta → `ln_firm_output`, `n_products`, `is_intermediary` |
| 10 | 导出 | `invoice_panel.dta`（主面板）、`market_conds.dta`、`firm_chars.dta` |

### 输出 .dta 结构

**`invoice_panel.dta`**（主回归面板，firm × product 级）

| 列 | 说明 |
|---|---|
| firm_id | 购方企业 ID |
| product_id | 9 位产品码 |
| city | 购方地区（4 位代码，从 firm_region 合并进来） |
| year | 2017（暂只有一年） |
| value / qty | 净金额 / 净数量 |
| p_buy / ln_p_buy | 单价（DV 原值 + 对数） |
| n_sellers | 该企业为该产品采购过的不同卖家数 |

**`market_conds.dta`**（product × city 级）

| 列 | 说明 |
|---|---|
| product_id | 9 位产品码 |
| city | 购方地区 |
| n_buyers | 在该城市买该产品的不同企业数 |
| n_sellers | 向该城市买家供货的不同企业数（来自 city_sell） |
| mkt_qty / p_mkt | 市场总量、市场均价（net-of-tax） |
| ln_n_buyers / ln_n_sellers / ln_p_mkt | 对数版本（回归直接用） |

**`firm_chars.dta`**（firm × year 级，来自 full_data.dta）

| 列 | 说明 |
|---|---|
| firm_id / year | 键 |
| firm_total_output / ln_firm_output | 企业总产出（规模 proxy） |
| n_products | 产品广度 |
| is_intermediary | 是否中介企业（>90% 外包，回归时 drop） |

---

## 7. 回归管线：02_price_reg.do

**文件**：`02_price_reg.do`（Stata，无循环，一个回归一个 block）

输出目录：`G:\Kuangyu_Temp\Outsource\productivity\regression\`

| 输出文件 | 内容 |
|---|---|
| `T1_baseline.txt` | 逐步加 FE（5 列）：OLS-bare → OLS-full → +FirmFE → +Firm+Prod → +Firm+Prod+City |
| `T2_demand_supply.txt` | 需求 vs 供给侧分解（4 列），对应会议纪要 Stage 3 |
| `T3_similarity.txt` | 投入/产出相似度 S_mj, C_mj（4 列），对应结构模型核心变量 ★ |
| `T4_interactions.txt` | 企业规模 × 市场条件交互（5 列） |
| `T5_robustness.txt` | 去掉中介企业（3 列），col 3 额外加相似度稳健性 |

**风格约定**（与 `diversification_complete.do` 保持一致）：
- 每张表前 `clear all` + 重置 `global esttab_opts`
- `reghdfe ... absorb(...) vce(cluster firm_n)` 全程
- `estadd local` 明示每列 FE 状态
- `esttab ... using "*.txt", replace` 输出

---

## 8. 回归方程设计

对应结构模型 Step 2（外包成本方程）：

$$\log c^B_{fjt} = \delta^B_{jct} + x^{B\prime}_{ft}\,\gamma_B + z^{B\prime}_{jct}\,\lambda_B$$

| 组件 | 对应变量 | 说明 |
|---|---|---|
| $\delta^B_{jct}$ | Firm FE + Product FE + City FE | 产品×城市×时间固定效应（分开加入） |
| $x^B_{ft}$（企业特征） | `ln_firm_output`, `ln_Capital`, `n_products` | 单年数据下被 Firm FE 吸收，仅 OLS 可识别 |
| $z^B_{jct}$（市场条件） | `ln_n_buyers`, `ln_n_sellers`, `ln_mkt_qty`, `ln_p_mkt` | FE 规格下可识别 |
| $S_{mj}$（投入相似度） | `input_similarity`（来自 full_data.dta） | firm×product 层面变化，FE 规格下可识别 ★ |
| $C_{mj}$（产出互补性） | `output_similarity`（来自 full_data.dta） | 同上 ★ |

**PART 1 额外 merge（在 02_price_reg.do 中完成）**：
- `full_data.dta` → `input_similarity`, `output_similarity`（merge on firm_id × product_id × year）
- `cid_entid_unique.dta` + `H:\汇算数据\2017.dta` → `ln_Capital`（merge on cid → id）

---

## 9. 已确认的设计决策

| 决策点 | 结论 | 理由 |
|---|---|---|
| 项目代码补零方向 | 右补零（`str.ljust`） | 产品码从左往右越来越细，高位有意义 |
| 时间粒度 | 年度 | SQL 已聚合至年度；与第一阶段一致 |
| city 定义 | 购方地区 | DV 是购方视角，市场以买家所在地划定 |
| 红冲处理 | Python 端过滤净值 ≤ 0 | SQL 做了求和但未 drop 负净值 |
| 企业特征来源 | full_data.dta（跨阶段 merge） | 避免从样本内发票重新构造偏差的 firm size |
| 单位混杂 | 暂接受（先看大概方向） | SQL 未按单位拆分；做为限制在论文中说明 |
| 样本企业子集 | 使用 SQL `tmp_sample_cid` 筛选的样本企业 | 全量 10 亿行 Python 无法支撑 |

---

## 10. 当前进度与待办事项

### 已完成

- [x] 确定数据来源和 SQL 抽取逻辑
- [x] 确定 4 类 CSV 的结构（含 SQL 代码核实）
- [x] 确定各项设计决策（表见上）
- [x] `01_clean.ipynb` 在虚拟机上可跑通
- [x] `02_price_reg.do` 重写：5 张表，加入 input_similarity / output_similarity / ln_Capital

### 待完成（按优先级）

1. **跑 `02_price_reg.do`**：同步到虚拟机后运行，重点观察 T3 相似度系数方向和显著性
2. **结果解读**：T1 firm chars OLS 系数、T2 需供分解符号、T3 S_mj/C_mj 经济解释
3. **ln_Capital 覆盖率确认**：汇算数据桥接后实际覆盖多少观测（预期 ~48%）；若太低考虑单独列一张 OLS 表
4. **结果调整**：根据跑出结果决定是否增加 product×city 交互 FE、winsorize ln_p_net 等

### 已知限制（单年数据）

- `ln_firm_output`, `ln_Capital`, `n_products` 在 FE 规格中被 Firm FE 吸收（显示 0/.）
- 仅 OLS 规格（T1 col 1–2）可识别 firm-level 变量的截面效应
- `input_similarity`, `output_similarity` 在 firm×product 层面变化 → FE 规格下**可以识别** ✓

---

## 11. 已知限制与风险说明

| 限制 | 影响 | 应对 |
|---|---|---|
| 单位混杂（SUM 不区分 EA/吨/箱） | DV 单价在跨单位产品上噪声很大 | 论文中明示；若结果噪声太大，再向 SQL 索取 (firm, product, 单位) 三维版本 |
| 样本企业子集（非全量） | 市场条件指标（n_buyers, n_sellers）仅反映样本内活跃度，可能低估真实市场厚度 | 论文中说明；系数方向仍可解释，量级要谨慎 |
| 只有 2017（单一年份） | year FE 无法识别，时间序列变异为零 | 等 2018 数据到齐后 append，届时 product×year FE 自然激活 |
| 企业注册地 ≠ 实际采购地 | firm_region 用注册地代理市场所在地 | 接受此假设；大部分采购在注册地城市发生是合理近似 |
| 红冲未完全对冲 | 若同一企业在不同省购买同一产品并分别红冲，4 位地区码聚合可能遗漏配对 | 已在 Python 端 drop 净值 ≤ 0 的行；残留影响有限 |
