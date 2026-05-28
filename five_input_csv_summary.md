# 01_clean 使用的五个 CSV 输入文件说明

本文档说明 `01_clean.ipynb` 中直接使用的五个 CSV 输入文件，包括列名、数据粒度和在清洗流程中的用途。

这五个文件均位于：

```text
G:\Kuangyu_Temp\Outsource\productivity
```

## 1. 文件总览

| 文件 | 数据行数 | 文件大小 | 数据粒度 | 主要用途 |
|---|---:|---:|---|---|
| `city_buy.csv` | 2,105,334 | 105,696,451 bytes | 购方地区 × 项目代码 | 构造全城市采购侧市场条件 |
| `city_sell.csv` | 1,540,248 | 75,965,716 bytes | 销方地区 × 项目代码 | 构造全城市销售侧市场条件 |
| `firm_buy.csv` | 473,281 | 23,300,601 bytes | 购方企业ID × 项目代码 | 构造样本企业采购价格，即主要因变量 |
| `firm_sell.csv` | 101,845 | 5,080,913 bytes | 销方企业ID × 项目代码 | 记录样本企业销售侧聚合情况，目前主要用于辅助检查 |
| `firm_city.csv` | 3,410 | 64,152 bytes | 企业ID × 地区 | 给样本企业合并地区信息 |

## 2. `city_buy.csv`

完整路径：

```text
G:\Kuangyu_Temp\Outsource\productivity\city_buy.csv
```

列名：

| 列名 | 含义 |
|---|---|
| `购方地区` | 购买方所在地区/城市代码 |
| `项目代码` | 发票项目代码，后续清洗为 9 位产品码 |
| `买方企业数` | 该地区、该项目代码下的不同买方企业数量 |
| `金额合计` | 该地区、该项目代码下的采购金额合计 |
| `数量合计` | 该地区、该项目代码下的采购数量合计 |

在 `01_clean.ipynb` 中的作用：

- 用于构造 full-city purchase-side market condition。
- 后续变量包括：`mkt_value`、`mkt_qty`、`p_mkt`、`ln_p_mkt`、`ln_mkt_qty`、`n_buyers`、`ln_n_buyers`。

## 3. `city_sell.csv`

完整路径：

```text
G:\Kuangyu_Temp\Outsource\productivity\city_sell.csv
```

列名：

| 列名 | 含义 |
|---|---|
| `销方地区` | 销售方所在地区/城市代码 |
| `项目代码` | 发票项目代码，后续清洗为 9 位产品码 |
| `卖方企业数` | 该地区、该项目代码下的不同卖方企业数量 |
| `金额合计` | 该地区、该项目代码下的销售金额合计 |
| `数量合计` | 该地区、该项目代码下的销售数量合计 |

在 `01_clean.ipynb` 中的作用：

- 用于构造 full-city seller-side market condition。
- 后续变量包括：`sell_value`、`sell_qty`、`n_sellers`、`ln_n_sellers`。
- 当前口径是按 `销方地区 × 项目代码` 聚合，因此代表城市供给侧厚度。

## 4. `firm_buy.csv`

完整路径：

```text
G:\Kuangyu_Temp\Outsource\productivity\firm_buy.csv
```

列名：

| 列名 | 含义 |
|---|---|
| `购方企业ID` | 样本企业作为购买方时的企业 ID |
| `项目代码` | 发票项目代码，后续清洗为 9 位产品码 |
| `金额合计` | 该企业、该项目代码下的采购金额合计 |
| `数量合计` | 该企业、该项目代码下的采购数量合计 |

在 `01_clean.ipynb` 中的作用：

- 用于构造主回归面板 `invoice_panel.dta`。
- 采购价格定义为：

```text
p_buy = 金额合计 / 数量合计
ln_p_buy = log(p_buy)
```

- 为了和后续 Stata 回归脚本兼容，`ln_p_buy` 同时保存为 `ln_p_net`。
- 由于 `firm_buy.csv` 本身没有地区列，清洗时需要用 `firm_city.csv` 按企业 ID 合并 `city`。

## 5. `firm_sell.csv`

完整路径：

```text
G:\Kuangyu_Temp\Outsource\productivity\firm_sell.csv
```

列名：

| 列名 | 含义 |
|---|---|
| `销方企业ID` | 样本企业作为销售方时的企业 ID |
| `项目代码` | 发票项目代码，后续清洗为 9 位产品码 |
| `金额合计` | 该企业、该项目代码下的销售金额合计 |
| `数量合计` | 该企业、该项目代码下的销售数量合计 |

在 `01_clean.ipynb` 中的作用：

- 记录样本企业销售侧的企业-产品聚合情况。
- 当前主因变量来自采购侧 `firm_buy.csv`，因此 `firm_sell.csv` 不是主回归价格因变量的来源。
- 由于 `firm_sell.csv` 本身没有地区列，清洗时同样需要用 `firm_city.csv` 按企业 ID 合并 `city`。

## 6. `firm_city.csv`

完整路径：

```text
G:\Kuangyu_Temp\Outsource\productivity\firm_city.csv
```

列名：

| 列名 | 含义 |
|---|---|
| `企业ID` | 3,410 家样本企业的企业 ID |
| `地区` | 样本企业所在地区/城市代码 |

在 `01_clean.ipynb` 中的作用：

- 给 `firm_buy.csv` 合并企业所在城市。
- 给 `firm_sell.csv` 合并企业所在城市。
- 该文件共有 3,410 条数据，对应 3,410 家样本企业。

## 7. 与 `01_clean.ipynb` 的关系

`01_clean.ipynb` 读取这五个 CSV 后，主要生成以下中间和最终数据：

| 输出文件 | 来源 |
|---|---|
| `invoice_panel.dta` | 主要来自 `firm_buy.csv`，并合并 `firm_city.csv` 中的地区 |
| `market_conds.dta` | 来自 `city_buy.csv` 和 `city_sell.csv` |
| `firm_chars.dta` | 来自外部企业特征数据 `full_data.dta` |

需要注意：这五个 CSV 是 `01_clean.ipynb` 中发票聚合和市场条件部分的核心输入；完整清洗流程还另外使用 `bianma.dta` 做合法产品码匹配，并使用 `full_data.dta` 构造企业特征。
