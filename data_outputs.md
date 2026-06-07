# 数据输出与回归面板（合并文档）

> 本文档合并自原 `data_outputs_and_reg_panel_overview.md` 与 `sample_firm_count_explanation.md`，统一记录"我们产出了什么"：`01_clean.ipynb` 生成的三个基础 .dta、`02_price_reg.do` 构造的最终回归面板，以及样本企业数的变化链条（3,410 → 3,376 → 2,108 → 1,875）。统计来自 `data_outputs_overview.do` / `data_outputs_overview_latest.log` 及 `check_invoice_panel_firm_drop_stata.do`。

---

## 1. 数据流程概览

1. **`01_clean.ipynb`** 清洗原始发票数据，生成三个基础文件：`invoice_panel.dta`、`market_conds.dta`、`firm_chars.dta`。
2. **`02_price_reg.do`** 合并上述数据 + 产品相似度，删除中介企业，生成最终回归面板 `reg_panel.dta`。

## 2. 四个核心数据文件总览

| 数据文件 | 生成环节 | 数据层级 | 行数 | 企业数 | 产品数 | 地区数 | 年份 |
|---|---|---|---:|---:|---:|---:|---|
| `invoice_panel.dta` | 01_clean | firm × product × city × year | 59,445 | 2,108 | 2,160 | 272 | 2017 |
| `market_conds.dta` | 01_clean | product × city × year | 1,066,579 | — | 2,778 | 1,174 | 2017 |
| `firm_chars.dta` | 01_clean | firm × year | 12,339,537 | 7,191,877 | — | — | 2017、2018 |
| `reg_panel.dta` | 02_price_reg | firm × product × city × year | 46,945 | 1,875 | 2,143 | 262 | 2017 |

---

## 3. `invoice_panel.dta`：外包采购价格面板

主价格面板，回归因变量基础。层级 firm × product × city × year（当前仅 2017，可理解为 企业 × 外包产品 × 城市）。**59,445 行、2,108 家企业、2,160 产品、272 地区。**

**样本含义**：不是所有采购记录，而是外包采购价格面板——进入的 firm-product 必须满足"同一企业同一产品**既买又卖**"（见 §7）。

| 变量 | 含义 |
|---|---|
| firm_id / product_id / city / year | 键（product_id = 9 位码；city = 购方地区；year = 2017） |
| value / qty | 外包采购金额 / 数量（净额） |
| p_buy / ln_p_buy | 外包采购单价（原值 + 对数） |
| p_net / ln_p_net | 同 p_buy（兼容回归脚本命名，**DV = ln_p_net**） |
| ln_qty / n_rows | 采购数量对数 / 聚合前发票记录数 |
| p_mkt_loo / ln_p_mkt_loo | leave-one-out 市场均价（02 当前市场价控制；唯一买家时缺失） |

---

## 4. `market_conds.dta`：市场条件数据

来自全量 city_buy/city_sell（不限样本企业）。层级 product × city × year。**1,066,579 行、2,778 产品、1,174 地区。**

| 变量 | 含义 |
|---|---|
| product_id / city / year | 键 |
| mkt_value / mkt_qty / p_mkt / ln_p_mkt / ln_mkt_qty | 城市-产品采购总额/总量/均价及对数（p_mkt 含本企业，已不进回归，保留对比） |
| n_buyers / ln_n_buyers | 买方企业数 |
| sell_value / sell_qty / n_sellers / ln_n_sellers | 销售总额/总量/卖方企业数及对数 |

---

## 5. `firm_chars.dta`：企业特征数据

来自 `full_data.dta` + 百度汇算桥接（Capital）。层级 firm × year。**12,339,537 行、7,191,877 企业、2017+2018（2017 年 5,719,292 行）。**

| 变量 | 含义 |
|---|---|
| firm_id / year | 键 |
| firm_total_output / ln_firm_output | 企业总产出（规模 proxy） |
| firm_total_outsource / ln_firm_outsource | 企业外包采购总额 |
| n_products | 产品广度 |
| is_intermediary | 中介标记（外包比例 > 90%，回归时 drop） |
| Capital / ln_Capital | 资产总额（来自百度汇算 total_assets）及对数 |

- 资本覆盖（全表）：ln_Capital 非缺失 7,974,680 / 缺失 4,364,857。
- 中介标记（全表）：is_intermediary=0 占 93.76%，=1 占 6.24%（769,614 行）。

---

## 6. `reg_panel.dta`：最终回归面板

以 `invoice_panel.dta` 为主表，合并 `market_conds.dta`、`firm_chars.dta`，再从 `full_data.dta` 合并产品相似度，最后删除中介企业。**46,945 行、1,875 家企业、2,143 产品、262 地区。**

**构造流程（02_price_reg.do）**：
1. `use invoice_panel.dta`
2. `merge m:1 product_id city year using market_conds.dta`
3. `merge m:1 firm_id year using firm_chars.dta`
4. `drop if is_intermediary == 1`（去中介）
5. `merge m:1 firm_id product_id year using sim_temp.dta`（相似度）
6. `save reg_panel.dta`

### 6.1 与 invoice_panel 的差异（主要来自去中介）

| 指标 | invoice_panel | reg_panel | 变化 |
|---|---:|---:|---:|
| 行数 | 59,445 | 46,945 | −12,500 |
| 企业数 | 2,108 | 1,875 | −233 |
| 产品数 | 2,160 | 2,143 | −17 |
| 地区数 | 272 | 262 | −10 |

### 6.2 资本变量覆盖（回归面板内）

| 指标 | 数值 | 比例 |
|---|---:|---:|
| ln_Capital 非缺失 | 29,247 | 62.30% |
| ln_Capital 缺失 | 17,698 | 37.70% |
| 总观测 | 46,945 | 100% |

> 因此含 ln_Capital 的规格（T1/T2/T4/T5）有效观测约 29,000，不含 Capital 的全 FE 规格（T3/T6）约 45,669。

### 6.3 产品相似度覆盖

input_similarity / output_similarity 各：非缺失 46,933，缺失 12。

### 6.4 回归变量分组

| 类型 | 变量 | 说明 |
|---|---|---|
| 企业层面 | ln_firm_output, ln_Capital, n_products | 单年截面被 Firm FE 吸收，仅 OLS 可识别 |
| 市场层面 | ln_n_buyers, ln_n_sellers, ln_mkt_qty, ln_p_mkt(_loo) | product × city 层面变化 |
| 产品相似度 | input_similarity, output_similarity | firm × product 层面变化 |

---

## 7. 样本企业数变化链条（3,410 → 3,376 → 2,108 → 1,875）

诊断依据：`check_invoice_panel_firm_drop_stata.do` 及日志。**核心结论：样本变化正常，主因是外包产品定义较严格。**

| 阶段 | 行数 | 企业数 | 含义 |
|---|---:|---:|---|
| 原始样本企业 | — | 3,410 | 来自 firm_city.csv |
| 原始采购记录 | 473,268 | 3,410 | firm_buy.csv |
| 采购记录清洗后 | 441,318 | 3,383 | 删除金额/数量/项目代码异常 |
| 匹配合法 9 位产品码后 | 425,713 | 3,376 | **"采购端有合法码企业数"，非最终外包面板** |
| 采购端 firm-product 聚合 | 403,400 | 3,376 | 仅采购端产品面板 |
| 销售端 firm-product 聚合 | 84,870 | 2,711 | 有合法销售产品的企业数 |
| 买卖同产品取交集 | 59,445 | 2,108 | 外包定义：同企业同产品既买又卖 → `invoice_panel.dta` |
| 去中介后 | 46,945 | 1,875 | `reg_panel.dta`（剔除 233 家中介） |

**要点澄清**：
- **3,376 家** = 采购端有合法 9 位产品码的企业数，**不是**最终外包样本数。早期在 notebook 里看到的 "invoice_panel rows: 403400 / unique firms: 3376" 实际是采购端聚合规模，还没做外包交集筛选。
- **3,376 → 2,108**：外包产品要求"同一企业同一产品同时出现在采购端和销售端"（采购端 3,376 家 ∩ 销售端 2,711 家 → 交集 2,108 家），是定义造成的，不是数据错误。
- **2,108 → 1,875**：`02_price_reg.do` 的 `drop if is_intermediary == 1` 删除 233 家中介企业（外包比例 > 90%）。即 2,108 − 233 = 1,875。

数据逻辑自洽：01 生成 invoice_panel（2,108 家，外包定义筛选后）→ 02 去中介 → reg_panel（1,875 家）。
