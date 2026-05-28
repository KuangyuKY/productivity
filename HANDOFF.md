# 第二阶段实证：外包价格的决定因素 — 项目说明文档

**最后更新：2026-05-28**

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
12. [代码风格约定](#12-代码风格约定)

---

## 1. 项目背景与研究问题

**研究题目**：Output Outsourcing, Product Diversification, and Industry Growth

**第二阶段核心问题**：

> 企业的外包价格（即企业以买方身份购买某产品、并将该产品转售时，所支付的单价）由哪些因素决定？

**外包的定义**：若一家样本企业在同一年度内，既购买了某产品（出现在 `firm_buy.csv`），又销售了该产品（出现在 `firm_sell.csv`），则认为该企业对该产品存在外包行为。外包量 = min(采购金额, 销售金额)。

具体研究关注：
- **企业特征**（规模、产品广度）如何影响它能拿到的外包价格？
- **市场条件**（买方数、卖方数、市场总量、市场均价）如何影响交易价格？
- 大企业是否更能利用市场厚度拿到更低的采购价？
- 需求侧与供给侧的影响方向和大小是否对称？

**理论联系**：在模型中，外包价格对应结构模型 Step 2 的外包成本方程 $\log c^B_{fjt}$，样本限制为 $Q^B_{fjt} > 0$（企业实际外包的观测）。

---

## 2. 与第一阶段的关系

| 维度 | 第一阶段（description/） | 第二阶段（productivity/） |
|---|---|---|
| **数据层级** | firm × product × year 聚合面板 | 发票层预聚合 CSV（firm × product 年总） |
| **核心 DV** | outsourcing_percen（外包比例） | 外包产品采购单价 = 金额合计 / 数量合计 |
| **主要 IV** | input_similarity, output_similarity | 企业规模, 买方数, 卖方数, 市场均价 |
| **主要数据源** | full_data.dta（90M 行，含相似度） | 增值税发票 CSV（SQL 预聚合）|
| **企业特征** | 来自 full_data.dta 本身 | 来自 full_data.dta（跨阶段 merge） |

第二阶段继续使用 `full_data.dta` 和 `bianma.dta` 作为辅助数据源。`full_data` 提供 firm-level 特征及 input/output similarity（按最大生产额定义主产品，与本阶段 VAT 推导一致）。

---

## 3. 工作目录结构

**本地**（代码写作 + git 同步）：
```
C:\Users\HKUBS\Documents\aproject\Outsourcing\code\productivity\
├── HANDOFF.md              ← 本文件
├── sql_reference.md        ← 所有 SQL 查询汇总（含两种卖方口径说明）
├── data_des.md             ← 虚拟机数据位置说明（调试用）
├── original_data.md        ← 早期原始发票字段说明（已部分过时）
├── 01_clean.ipynb          ← Python 清洗脚本（★ 主要工作文件）
└── 02_price_reg.do         ← Stata 回归脚本（★ 主要工作文件）
```

**虚拟机**（实际运行数据 + 跑代码）：
```
G:\Kuangyu_Temp\Outsource\
├── full_data.dta              ← 第一阶段主面板（firm × product × year，90M 行）
├── bianma.dta                 ← 2778 个 9 位产品码 + 货物名称
└── productivity\              ← 本阶段工作目录
    ├── firm_buy.csv           ← 购方企业 × 产品 聚合（★ DV 来源）
    ├── firm_sell.csv          ← 销方企业 × 产品 聚合（★ 外包识别 + 主产品计算）
    ├── city_buy.csv           ← 购方地区 × 产品 聚合（市场需求条件，全量）
    ├── city_sell.csv          ← 销方地区 × 产品 聚合（市场供给条件，全量）
    ├── firm_city.csv          ← 3410 家样本企业 ID → 地区映射
    ├── 01_clean.ipynb         ← 由本地 git 同步
    ├── 02_price_reg.do        ← 由本地 git 同步
    └── regression\            ← 回归结果落盘目录
        ├── T1_baseline.txt
        ├── T2_demand_supply.txt
        ├── T3_similarity.txt
        ├── T4_interactions.txt
        └── T5_robustness.txt
```

辅助数据（第一阶段产物，跨阶段使用）：
```
G:\Kuangyu_Temp\Outsource\productivity\
├── cid_entid_unique.dta       ← cid（发票企业ID）→ id（汇算企业ID）桥接表
H:\汇算数据\
└── 2017.dta                   ← 企业年度所得税汇算清缴，含资产总额（Capital）
```

---

## 4. 数据文件说明

### 4.1 发票 CSV（5 个文件，均位于 `G:\Kuangyu_Temp\Outsource\productivity\`）

| 文件 | 数据行数 | 文件大小 | 颗粒度 | 主要用途 |
|---|---:|---:|---|---|
| `firm_buy.csv` | 473,281 | 23 MB | 购方企业ID × 项目代码 | 构造 DV：外包产品采购单价 |
| `firm_sell.csv` | 101,845 | 5 MB | 销方企业ID × 项目代码 | 识别外包产品 + 计算净生产额（主产品定义） |
| `city_buy.csv` | 2,105,334 | 106 MB | 购方地区 × 项目代码 | 需求侧市场条件（全量） |
| `city_sell.csv` | 1,540,248 | 76 MB | 销方地区 × 项目代码 | 供给侧市场条件（全量） |
| `firm_city.csv` | 3,410 | 64 KB | 企业ID × 地区 | 给样本企业合并地区信息 |

**所有 ID、代码字段均为字符串存储；`项目代码` 是原始长码，未经清洗。**

#### `firm_buy.csv` 列结构

| 列名 | 含义 |
|---|---|
| `购方企业ID` | 样本企业作为购买方的企业 ID |
| `项目代码` | 发票项目代码（原始，需清洗为 9 位 `product_id`） |
| `金额合计` | 该企业该产品全年采购金额净额 |
| `数量合计` | 该企业该产品全年采购数量净额 |

用途：构造主回归面板，`p_buy = 金额合计 / 数量合计`，DV = `ln_p_buy`。

#### `firm_sell.csv` 列结构

| 列名 | 含义 |
|---|---|
| `销方企业ID` | 样本企业作为销售方的企业 ID |
| `项目代码` | 发票项目代码（同上需清洗） |
| `金额合计` | 该企业该产品全年销售金额净额 |
| `数量合计` | 该企业该产品全年销售数量净额 |

用途（关键，非辅助）：
1. **外包识别**：与 `firm_buy` 取交集 → firm 同时购买且销售同一产品 → 外包产品
2. **净生产额计算**：`net_production = sell_value - buy_value`（正值为自产，负值排除）→ 主产品 = 净生产额最大的产品

#### `city_buy.csv` 列结构

| 列名 | 含义 |
|---|---|
| `购方地区` | 购买方所在地区代码（4 位）|
| `项目代码` | 发票项目代码 |
| `买方企业数` | 该地区该产品的不同买方企业数 |
| `金额合计` | 该地区该产品全量采购金额 |
| `数量合计` | 该地区该产品全量采购数量 |

用途：构造 `n_buyers`、`mkt_qty`、`p_mkt`、`ln_p_mkt`、`ln_mkt_qty`、`ln_n_buyers`。

#### `city_sell.csv` 列结构（当前口径：按销方地区）

| 列名 | 含义 |
|---|---|
| `销方地区` | 销售方所在地区代码（4 位）|
| `项目代码` | 发票项目代码 |
| `卖方企业数` | 该地区该产品的不同卖方企业数 |
| `金额合计` | 该地区该产品全量销售金额 |
| `数量合计` | 该地区该产品全量销售数量 |

用途：构造 `n_sellers`、`ln_n_sellers`。注意当前 `city` 用销方地区，与 invoice_panel 的买方地区存在口径差异，详见 `sql_reference.md` § 表4。

#### `firm_city.csv` 列结构

| 列名 | 含义 |
|---|---|
| `企业ID` | 3410 家样本企业的企业 ID |
| `地区` | 样本企业所在地区代码（4 位）|

用途：给 `firm_buy` 和 `firm_sell` 合并城市信息。

### 4.2 沿用数据（来自第一阶段）

| 文件 | 位置 | 用途 |
|---|---|---|
| `full_data.dta` | `G:\Kuangyu_Temp\Outsource\` | firm × product × year 特征，含 main_product（最大生产额）、input_similarity、output_similarity |
| `bianma.dta` | `G:\Kuangyu_Temp\Outsource\` | 2778 个合法 9 位产品码，用于产品代码匹配 |

**关于 `full_data` 的主产品定义**：`main_product` 按企业最大生产产值（production value）定义，与本阶段 VAT 推导的净生产额定义一致（sell - buy 取正值最大者），可直接沿用。

**关于 similarity 来源**：`input_similarity`、`output_similarity` 存储在 `full_data`（firm × product 层面，= sim(main_product, product_j)），外包产品必然出现在销售侧，因而在 `full_data` 中有对应记录，可直接 merge on `(firm_id, product_id)`。无需使用 `full_product_similarity.dta`（全产品对宇宙文件，15% 覆盖率低的原因是旧代码包含了原材料采购，而非方法问题）。

---

## 5. SQL 数据抽取逻辑

完整 SQL 代码见 `sql_reference.md`。以下是关键要点：

- 三张年表（GX1701/02/03）在每个查询内部 `UNION ALL` 合并，直接出全年结果
- 红冲发票（负值）**未被过滤**，直接与正值合并求和；净值可能 ≤ 0，由 Python 端清洗
- `数量` 用 `TRY_CAST(数量 AS float)` 转换，乱码字母自动变 NULL，不影响 `SUM`
- `项目代码` 未做清洗，Python 端处理
- 样本企业为 `dbo.tmp_sample_cid`（约 3410 家），city 级聚合（city_buy/city_sell）为**全量**口径

**卖方口径注意**：当前 `city_sell.csv` 按**销方地区**分组，衡量本地供给集聚。若需衡量买方面对的供应商竞争，应按**购方地区**分组重新抓取，详见 `sql_reference.md` § 表4。

---

## 6. 清洗管线：01_clean.ipynb

**文件**：`01_clean.ipynb`（Python，Jupyter notebook，顺序型 cell，无封装函数）

### 清洗步骤

| Step | 内容 | 关键操作 |
|---|---|---|
| 1 | 读入 CSV | `dtype=str` 读入 ID/代码列；`na_values` 统一识别 NULL/空 |
| 2 | 统一列名，合并城市 | `firm_buy` 和 `firm_sell` 均从 `firm_city.csv` 按企业 ID 合并 `city` |
| 3 | 清洗项目代码 + 数值 | 过滤非纯数字码；右补零至 19 位，截前 9 位 → `product_id`；drop 金额/数量 ≤ 0 |
| 4 | bianma 匹配 | inner join，只保留 2778 个合法产品 |
| **4a** ★ | **识别外包产品** | **fb ∩ fs on (firm_id, product_id)；outsourcing_value = min(buy_value, sell_value)；仅保留 > 0 的行** |
| **4b** ★ | **计算净生产额与主产品** | **net_production_j = sell_value_j − buy_value_j（逐 firm×product）；main_product = argmax net_production（只取正值）** |
| **4c** ★ | **过滤 DV 样本** | **invoice_panel 只保留外包产品（Step 4a 识别的 firm×product 对）** |
| 5 | 构造 DV | `p_buy = value / qty`；`ln_p_net = log(p_buy)` |
| 6 | 市场条件（买方侧）| 从 `city_buy` 构造 `n_buyers`、`mkt_qty`、`p_mkt` 及其对数版本 |
| 7 | 市场条件（卖方侧）| 从 `city_sell` 构造 `n_sellers` 及其对数版本 |
| 8 | 合并市场条件 | `invoice_panel` left join `market_conds` on `(product_id, city, year)` |
| 9 | 合并企业特征 | `invoice_panel` left join `full_data` on `(firm_id, year)` → `ln_firm_output`、`n_products`、`is_intermediary` |
| 10 | 诊断 | 打印各 merge 覆盖率；重点看 similarity 覆盖率（外包样本预期 > 90%）|
| 11 | 导出 | `invoice_panel.dta`、`market_conds.dta`、`firm_chars.dta` |

> ★ 步骤 4a/4b/4c 为**待实施的新步骤**，当前版本 01_clean.ipynb 尚未包含。

### 输出 .dta 结构

**`invoice_panel.dta`**（主回归面板，firm × product 级，仅外包产品）

| 列 | 说明 |
|---|---|
| firm_id | 购方企业 ID |
| product_id | 9 位产品码（外包产品） |
| city | 购方地区（4 位代码） |
| year | 2017 |
| value / qty | 净采购金额 / 净采购数量 |
| p_buy / ln_p_net | 外包采购单价（DV 原值 + 对数） |

**`market_conds.dta`**（product × city 级）

| 列 | 说明 |
|---|---|
| product_id | 9 位产品码 |
| city | 购方地区 |
| n_buyers / ln_n_buyers | 买方数 |
| n_sellers / ln_n_sellers | 卖方数 |
| mkt_qty / ln_mkt_qty | 市场总量 |
| p_mkt / ln_p_mkt | 市场均价 |

**`firm_chars.dta`**（firm × year 级，来自 full_data.dta）

| 列 | 说明 |
|---|---|
| firm_id / year | 键 |
| firm_total_output / ln_firm_output | 企业总产出（规模 proxy） |
| n_products | 产品广度 |
| is_intermediary | 是否中介企业（> 90% 外包，回归时 drop） |

---

## 7. 回归管线：02_price_reg.do

**文件**：`02_price_reg.do`（Stata，无循环，一个回归一个 block）

输出目录：`G:\Kuangyu_Temp\Outsource\productivity\regression\`

| 输出文件 | 内容 |
|---|---|
| `T1_baseline.txt` | 逐步加 FE（5 列）：OLS-bare → OLS-full → +FirmFE → +Firm+Prod → +Firm+Prod+City |
| `T2_demand_supply.txt` | 需求 vs 供给侧分解（4 列） |
| `T3_similarity.txt` | 投入/产出相似度 S_mj、C_mj（4 列）★ |
| `T4_interactions.txt` | 企业规模 × 市场条件交互（5 列） |
| `T5_robustness.txt` | 去掉中介企业稳健性（3 列，col3 额外加相似度） |

**PART 1 数据准备（在回归前完成的 merge）**：

1. **Similarity merge**（来自 `full_data.dta`）：merge on `(firm_id, product_id, year)` 直接获取 `input_similarity`、`output_similarity`。外包产品必在 full_data 的销售侧，覆盖率预期 > 90%。
2. **Capital merge**：`cid_entid_unique.dta`（cid→id）+ `H:\汇算数据\2017.dta`（资产总额）→ `ln_Capital`（约 48% 覆盖）

---

## 8. 回归方程设计

对应结构模型 Step 2（外包成本方程），样本限制为外包观测（$Q^B_{fjt} > 0$，即 firm 同时购买且销售产品 j）：

$$\log c^B_{fjt} = \delta^B_{jct} + x^{B\prime}_{ft}\,\gamma_B + z^{B\prime}_{jct}\,\lambda_B + e^B_{fjt}$$

| 组件 | 对应变量 | 数据来源 | FE 可识别？ |
|---|---|---|---|
| $\delta^B_{jct}$ | Firm FE + Product FE + City FE | — | — |
| $x^B_{ft}$：企业规模 | `ln_firm_output`（`ln_Capital`）| full_data（汇算数据） | 单年被 Firm FE 吸收，仅 OLS 可识别 |
| $z^B_{jct}$：买方数 | `ln_n_buyers` | city_buy（全量）| ✓ |
| $z^B_{jct}$：卖方数 | `ln_n_sellers` | city_sell（全量）| ✓ |
| $z^B_{jct}$：市场量 | `ln_mkt_qty` | city_buy（全量）| ✓ |
| $z^B_{jct}$：市场价 | `ln_p_mkt` | city_buy（全量）| ✓ |
| $S_{mj}$：投入相似度 | `input_similarity` | full_data（firm×product 层面）| ✓ |
| $C_{mj}$：产出互补性 | `output_similarity` | full_data（firm×product 层面）| ✓ |

---

## 9. 已确认的设计决策

| 决策点 | 结论 | 理由 |
|---|---|---|
| 项目代码补零方向 | 右补零（`str.ljust`） | 产品码从左往右越来越细，高位有意义 |
| 时间粒度 | 年度 | SQL 已聚合至年度；与第一阶段一致 |
| city 定义 | 购方地区（4 位） | DV 是购方视角，市场以买家所在地划定 |
| 红冲处理 | Python 端过滤净值 ≤ 0 | SQL 做了求和但未 drop 负净值 |
| 企业特征来源 | full_data.dta（跨阶段 merge） | 避免从样本内发票重新构造偏差的 firm size |
| 单位混杂 | 暂接受（先看大概方向） | SQL 未按单位拆分；作为限制在论文中说明 |
| 样本企业子集 | SQL `tmp_sample_cid` 约 3410 家 | 全量 10 亿行 Python 无法支撑 |
| **外包定义** | **firm 同时购买且销售同一产品（fb ∩ fs）** | **结构模型要求 $Q^B > 0$；VAT 数据的操作化定义** |
| **主产品定义** | **max(sell_value − buy_value) where positive（VAT 净生产额）** | **与 full_data 的 production_value 定义一致** |
| **Similarity 来源** | **full_data 直接 merge on (firm_id, product_id)**  | **外包产品必在 full_data 销售侧；覆盖率低的旧问题源于包含原材料，与方法无关** |
| **firm_sell.csv 角色** | **主动用于外包识别 + 净生产额计算** | **不再是"辅助"文件；是识别外包样本的关键输入** |

---

## 10. 当前进度与待办事项

### 已完成

- [x] 确定数据来源和 SQL 抽取逻辑（含两种卖方口径对比）
- [x] 确定 5 个 CSV 的结构和用途
- [x] 确认设计决策（见上表）
- [x] `01_clean.ipynb` 在虚拟机上可跑通（当前版本，未含新步骤）
- [x] `02_price_reg.do` 重写：5 张表（T1–T5），含 input/output_similarity、ln_Capital
- [x] 确认外包定义（fb ∩ fs）、主产品定义（净生产额）、similarity 来源（full_data）
- [x] 确认 full_data 的 main_product 用生产产值定义，与 VAT 推导一致

### 待完成（按优先级）

1. **更新 `01_clean.ipynb`**：新增 Step 4a/4b/4c（外包识别、净生产额、样本过滤）
2. **更新 `02_price_reg.do`**：PART 1 中 similarity merge 改回 full_data 直接 merge（删除 full_product_similarity.dta 路径）
3. **在虚拟机重跑**：同步后运行，重点观察 T3 similarity 覆盖率（预期 > 90%）和系数方向
4. **结果解读**：T2 需供分解符号、T3 S_mj/C_mj 系数经济含义
5. **卖方口径决定**：是否重新抓取按购方地区分组的 city_sell（见 sql_reference.md § 表4）

---

## 11. 已知限制与风险说明

| 限制 | 影响 | 应对 |
|---|---|---|
| 单位混杂（SUM 不区分 EA/吨/箱） | 跨单位产品的 DV 噪声大 | 论文中明示；若噪声过大，向 SQL 索取 (firm, product, 单位) 三维版本 |
| 样本企业子集（非全量） | n_buyers/n_sellers 低估真实市场厚度 | 论文中说明；系数方向可解释，量级须谨慎 |
| 只有 2017（单一年份） | year FE 无法识别；无时序变异 | 等 2018 数据到位后 append |
| 企业注册地 ≠ 实际采购地 | firm_city 用注册地代理市场地 | 接受此假设；对大多数企业是合理近似 |
| 红冲未完全对冲 | 极少数净值为负的行已 drop | 影响有限 |
| 外包识别依赖 VAT 同年数据 | 若买卖跨年则漏识别 | 单年数据下无法验证；作为限制说明 |
| ln_Capital 覆盖率约 48% | OLS 规格有效样本大幅下降 | T1 单独展示 OLS；FE 规格样本被 Firm FE 吸收后 Capital 无法识别 |

---

## 12. 代码风格约定

**总原则**：简洁明快，不要过度封装。

### Python（01_clean.ipynb）

- 格式：`.ipynb`，Jupyter notebook，便于实时交互观察
- 风格：顺序型 cell，一步一步推进，清楚显示 where we are
- **不要**写大量 `def` 函数包装；直接写操作步骤，打印中间结果
- 不要用复杂 pipeline 或链式调用，保持可读性优先
- ID/代码列：`dtype=str` 读入，防止长数字精度丢失
- 中文：`encoding='utf-8-sig'`

### Stata（02_price_reg.do）

- **不要写循环**，一个回归一个 block，显式展开
- 参考风格：`C:\Users\HKUBS\Documents\aproject\Outsourcing\code\description\diversification\diversification_complete.do`
- 每张表前 `clear all` + 重置 `global esttab_opts`
- 全程 `reghdfe ... absorb(...) vce(cluster firm_id)`
- `estadd local` 明示每列 FE 状态
- `esttab ... using "*.txt", replace` 输出结果
