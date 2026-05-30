# 数据输出文件说明：`01_clean` 输出与回归面板

本文介绍 [`01_clean.ipynb`](01_clean.ipynb) 生成的三个主要数据文件，以及 [`02_price_reg.do`](02_price_reg.do) 构造的最终回归面板。统计结果来自 [`data_outputs_overview.do`](../data_outputs_overview.do) 和日志 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log)。

## 1. 数据流程概览

当前实证流程分为两步：

1. [`01_clean.ipynb`](01_clean.ipynb) 负责清洗原始发票数据，并生成三个基础数据文件：
   - [`invoice_panel.dta`](../invoice_panel.dta)
   - [`market_conds.dta`](../market_conds.dta)
   - [`firm_chars.dta`](../firm_chars.dta)
2. [`02_price_reg.do`](02_price_reg.do) 负责合并上述数据，加入产品相似度，删除中介企业，并生成最终回归面板：
   - [`reg_panel.dta`](../reg_panel.dta)

## 2. 四个核心数据文件概览

| 数据文件 | 生成环节 | 数据层级 | 行数 | 企业数 | 产品数 | 地区数 | 年份 |
|---|---|---|---:|---:|---:|---:|---|
| [`invoice_panel.dta`](../invoice_panel.dta) | [`01_clean.ipynb`](01_clean.ipynb) | firm × product × city × year | 59,445 | 2,108 | 2,160 | 272 | 2017 |
| [`market_conds.dta`](../market_conds.dta) | [`01_clean.ipynb`](01_clean.ipynb) | product × city × year | 1,066,579 | — | 2,778 | 1,174 | 2017 |
| [`firm_chars.dta`](../firm_chars.dta) | [`01_clean.ipynb`](01_clean.ipynb) | firm × year | 12,339,537 | 7,191,877 | — | — | 2017、2018 |
| [`reg_panel.dta`](../reg_panel.dta) | [`02_price_reg.do`](02_price_reg.do) | firm × product × city × year | 46,945 | 1,875 | 2,143 | 262 | 2017 |

对应日志位置：

- [`invoice_panel.dta`](../invoice_panel.dta)：[`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:80)。
- [`market_conds.dta`](../market_conds.dta)：[`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:101)。
- [`firm_chars.dta`](../firm_chars.dta)：[`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:120)。
- [`reg_panel.dta`](../reg_panel.dta)：[`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:150)。

## 3. `invoice_panel.dta`：外包采购价格面板

[`invoice_panel.dta`](../invoice_panel.dta) 是 [`01_clean.ipynb`](01_clean.ipynb) 生成的主价格面板，也是回归因变量的基础数据。

### 3.1 数据层级

数据层级为：

```text
firm × product × city × year
```

当前只有 2017 年，因此基本可以理解为：

```text
企业 × 外包产品 × 城市
```

### 3.2 基本规模

| 指标 | 数值 |
|---|---:|
| 行数 | 59,445 |
| 变量数 | 12 |
| 企业数 | 2,108 |
| 产品数 | 2,160 |
| 地区数 | 272 |
| 年份 | 2017 |

这些结果见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:80)。

### 3.3 样本含义

[`invoice_panel.dta`](../invoice_panel.dta) 不是所有采购记录，而是外包采购价格面板。进入该面板的 firm-product 必须满足：同一企业同一产品既有采购记录，也有销售记录。

因此，虽然采购端有合法产品码的企业数为 3,376 家，但最终外包采购价格面板中只有 2,108 家企业。详细解释见 [`sample_firm_count_explanation.md`](sample_firm_count_explanation.md)。

### 3.4 主要变量

[`invoice_panel.dta`](../invoice_panel.dta) 主要包括：

| 变量 | 含义 |
|---|---|
| firm_id | 企业 ID |
| product_id | 9 位产品码 |
| city | 企业所在地区 |
| year | 年份，目前为 2017 |
| value | 外包采购金额 |
| qty | 外包采购数量 |
| p_buy | 外包采购单价 |
| ln_p_buy | 外包采购单价对数 |
| p_net | 与 p_buy 保持一致，用于兼容回归脚本 |
| ln_p_net | 回归因变量，即外包采购单价对数 |
| ln_qty | 采购数量对数 |
| n_rows | 聚合前发票记录数量 |

## 4. `market_conds.dta`：市场条件数据

[`market_conds.dta`](../market_conds.dta) 是 [`01_clean.ipynb`](01_clean.ipynb) 生成的 product × city × year 层面的市场条件数据。

### 4.1 数据层级

```text
product × city × year
```

该数据来自全量城市采购和销售数据，不只限于样本企业。

### 4.2 基本规模

| 指标 | 数值 |
|---|---:|
| 行数 | 1,066,579 |
| 变量数 | 14 |
| 产品数 | 2,778 |
| 地区数 | 1,174 |
| 年份 | 2017 |

这些结果见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:101)。

### 4.3 主要变量

[`market_conds.dta`](../market_conds.dta) 主要包括：

| 变量 | 含义 |
|---|---|
| product_id | 9 位产品码 |
| city | 城市或地区代码 |
| year | 年份，目前为 2017 |
| mkt_value | 城市-产品层面的采购总金额 |
| mkt_qty | 城市-产品层面的采购总数量 |
| p_mkt | 城市-产品层面的市场采购均价 |
| ln_p_mkt | 市场采购均价对数 |
| ln_mkt_qty | 市场采购数量对数 |
| n_buyers | 城市-产品层面的买方企业数 |
| ln_n_buyers | 买方企业数对数 |
| sell_value | 城市-产品层面的销售总金额 |
| sell_qty | 城市-产品层面的销售总数量 |
| n_sellers | 城市-产品层面的卖方企业数 |
| ln_n_sellers | 卖方企业数对数 |

## 5. `firm_chars.dta`：企业特征数据

[`firm_chars.dta`](../firm_chars.dta) 是 [`01_clean.ipynb`](01_clean.ipynb) 生成的 firm × year 层面企业特征数据。它来自 [`full_data.dta`](../full_data.dta)，并通过百度网盘预匹配汇算文件补充资本变量。

### 5.1 数据层级

```text
firm × year
```

### 5.2 基本规模

| 指标 | 数值 |
|---|---:|
| 行数 | 12,339,537 |
| 变量数 | 10 |
| 企业数 | 7,191,877 |
| 年份 | 2017、2018 |
| 2017 年记录数 | 5,719,292 |
| 2018 年记录数 | 6,620,245 |

这些结果见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:120)。

### 5.3 资本变量覆盖

| 指标 | 数值 |
|---|---:|
| ln_Capital 非缺失 | 7,974,680 |
| ln_Capital 缺失 | 4,364,857 |

对应日志见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:137)。

### 5.4 中介企业标记

| is_intermediary | 行数 | 比例 |
|---:|---:|---:|
| 0 | 11,569,923 | 93.76% |
| 1 | 769,614 | 6.24% |

对应日志见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:142)。

### 5.5 主要变量

[`firm_chars.dta`](../firm_chars.dta) 主要包括：

| 变量 | 含义 |
|---|---|
| firm_id | 企业 ID |
| year | 年份 |
| firm_total_output | 企业总产出 |
| firm_total_outsource | 企业总外包采购 |
| n_products | 企业产品数 |
| is_intermediary | 中介企业标记，外包比例超过 90% |
| ln_firm_output | 企业总产出对数 |
| ln_firm_outsource | 企业外包采购额对数 |
| Capital | 企业资本，来自 Baidu 汇算匹配文件中的 total_assets |
| ln_Capital | 企业资本对数 |

## 6. `reg_panel.dta`：最终回归面板

[`reg_panel.dta`](../reg_panel.dta) 是 [`02_price_reg.do`](02_price_reg.do) 构造并保存的最终回归面板。它以 [`invoice_panel.dta`](../invoice_panel.dta) 为主表，合并 [`market_conds.dta`](../market_conds.dta)、[`firm_chars.dta`](../firm_chars.dta)，再从 [`full_data.dta`](../full_data.dta) 合并产品相似度变量，最后删除中介企业。

### 6.1 构造流程

[`02_price_reg.do`](02_price_reg.do) 中的关键流程为：

1. 读取 [`invoice_panel.dta`](../invoice_panel.dta)：[`use "invoice_panel.dta", clear`](02_price_reg.do:53)。
2. 合并 [`market_conds.dta`](../market_conds.dta)：[`merge m:1 product_id city year using "market_conds.dta"`](02_price_reg.do:57)。
3. 合并 [`firm_chars.dta`](../firm_chars.dta)：[`merge m:1 firm_id year using "firm_chars.dta"`](02_price_reg.do:61)。
4. 删除中介企业：[`drop if is_intermediary == 1`](02_price_reg.do:66)。
5. 合并产品相似度：[`merge m:1 firm_id product_id year using "sim_temp.dta"`](02_price_reg.do:78)。
6. 保存 [`reg_panel.dta`](../reg_panel.dta)：[`save "reg_panel.dta", replace`](02_price_reg.do:105)。

### 6.2 基本规模

| 指标 | 数值 |
|---|---:|
| 行数 | 46,945 |
| 变量数 | 36 |
| 企业数 | 1,875 |
| 产品数 | 2,143 |
| 地区数 | 262 |
| 年份 | 2017 |

这些结果见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:150)。

### 6.3 与 `invoice_panel.dta` 的差异

| 指标 | [`invoice_panel.dta`](../invoice_panel.dta) | [`reg_panel.dta`](../reg_panel.dta) | 变化 |
|---|---:|---:|---:|
| 行数 | 59,445 | 46,945 | -12,500 |
| 企业数 | 2,108 | 1,875 | -233 |
| 产品数 | 2,160 | 2,143 | -17 |
| 地区数 | 272 | 262 | -10 |

主要变化来自删除中介企业，即 [`drop if is_intermediary == 1`](02_price_reg.do:66)。

### 6.4 资本变量覆盖

| 指标 | 数值 | 比例 |
|---|---:|---:|
| ln_Capital 非缺失 | 29,247 | 62.30% |
| ln_Capital 缺失 | 17,698 | 37.70% |
| 总观测 | 46,945 | 100.00% |

对应日志见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:170)。

### 6.5 产品相似度覆盖

| 变量 | 非缺失 | 缺失 |
|---|---:|---:|
| input_similarity | 46,933 | 12 |
| output_similarity | 46,933 | 12 |

对应日志见 [`data_outputs_overview_latest.log`](../data_outputs_overview_latest.log:181)。

### 6.6 回归中的主要变量组

[`02_price_reg.do`](02_price_reg.do:4) 将变量分为三类：

| 类型 | 变量 | 说明 |
|---|---|---|
| 企业层面 | ln_firm_output, ln_Capital, n_products | 单年截面下会被 firm fixed effects 吸收 |
| 市场层面 | ln_n_buyers, ln_n_sellers, ln_mkt_qty, ln_p_mkt | product × city 层面变化 |
| 产品相似度 | input_similarity, output_similarity | firm × product 层面变化 |

## 7. 当前推荐引用口径

如果需要在汇报或文档中简要描述当前数据，可以使用以下表述：

> 本项目首先由 [`01_clean.ipynb`](01_clean.ipynb) 生成三个基础数据：外包采购价格面板 [`invoice_panel.dta`](../invoice_panel.dta)、市场条件数据 [`market_conds.dta`](../market_conds.dta)、企业特征数据 [`firm_chars.dta`](../firm_chars.dta)。其中外包采购价格面板包含 59,445 条 firm-product-city-year 观测，覆盖 2,108 家企业、2,160 个产品、272 个地区。随后 [`02_price_reg.do`](02_price_reg.do) 合并市场条件、企业特征与产品相似度，并删除中介企业，得到最终回归面板 [`reg_panel.dta`](../reg_panel.dta)，包含 46,945 条观测，覆盖 1,875 家企业、2,143 个产品、262 个地区。
