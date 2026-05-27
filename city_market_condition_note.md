# `city.csv` 全城市购买市场条件数据说明

## 1. 数据定位

`city.csv` 是新导出的 **全城市购买情况** 数据，用途是构造 purchase-side market condition。

它的核心作用是替代之前样本内的 `city_buy.csv`。

之前的 `city_buy.csv` 来自只针对 3410 家样本企业的 SQL 聚合，因此它不是严格意义上的城市总体市场条件。比如，如果某个城市只有一家样本企业进入样本，那么旧的城市层面购买金额、购买数量和市场价格就可能机械地等于这家企业自己的采购情况。

新的 `city.csv` 应该来自全体城市企业的购买记录，不再限制在样本企业内。因此它更适合作为城市 × 产品层面的外部市场条件。

## 2. 原始数据结构

文件位置：

```text
G:\Kuangyu_Temp\Outsource\productivity\city.csv
```

当前读取到的原始列为：

| 原始列名 | 含义 |
|---|---|
| `购方地区` | 买方所在城市或地区代码 |
| `项目代码` | 原始 VAT 项目代码 |
| `买方企业数` | 城市 × 原始项目代码层面的买方企业数 |
| `金额合计` | 城市 × 原始项目代码层面的购买金额合计 |
| `数量合计` | 城市 × 原始项目代码层面的购买数量合计 |

样例中可以看到，`项目代码` 存在大量异常或乱码值，例如：

```text

#N/A
#N/A000000000000000
(?
)???'
```

因此，`city.csv` 不能直接用于回归，需要先按照 `01_clean.ipynb` 中的产品代码规则清理。

## 3. 清理 notebook

清理脚本写在：

```text
G:\Kuangyu_Temp\Outsource\productivity\productivity\clean_city.ipynb
```

相对当前项目目录的位置为：

```text
productivity/clean_city.ipynb
```

这个 notebook 专门把 `city.csv` 清理成全城市 purchase-side market condition。

## 4. 清理逻辑

清理过程与 `01_clean.ipynb` 中的项目代码处理保持一致。

### 4.1 读入数据

所有列先按字符串读入，避免 `项目代码` 被自动转成数值或科学计数法。

### 4.2 标准化列名

将原始列改名为后续统一使用的变量名：

| 原始列名 | 清理后变量名 |
|---|---|
| `购方地区` | `city` |
| `项目代码` | `product_code` |
| `买方企业数` | `n_buyers_raw` |
| `金额合计` | `value` |
| `数量合计` | `qty` |

并加入年份变量：

```python
year = 2017
```

### 4.3 删除异常项目代码

项目代码清理规则为：

1. 删除缺失的 `city`、`product_code`、`value`、`qty`。
2. 只保留纯数字 `product_code`。
3. 删除乱码、`#N/A`、含符号或字母的项目代码。
4. 将纯数字项目代码右补零到 19 位，生成 `code19`。
5. 取 `code19` 前 9 位生成 `product_id`。
6. 删除金额或数量非正的记录。

核心逻辑为：

```python
city_clean = city.dropna(subset=['city', 'product_code', 'value', 'qty']).copy()
city_clean = city_clean[city_clean['product_code'].str.fullmatch(r'\d+', na=False)].copy()
city_clean['code19'] = city_clean['product_code'].str.ljust(19, '0').str[:19]
city_clean['product_id'] = city_clean['code19'].str[:9]
city_clean = city_clean[(city_clean['value'] > 0) & (city_clean['qty'] > 0)].copy()
```

### 4.4 匹配合法 9 位产品码

使用 `bianma.dta` 中的合法 9 位产品码，只保留能够匹配上的 `product_id`。

```python
bianma = pd.read_stata(bianma_path)
valid_products = set(bianma['product_id'].astype(str).str.strip())
city_clean = city_clean[city_clean['product_id'].isin(valid_products)].copy()
```

### 4.5 构造城市 × 产品 market condition

清理后按以下键重新聚合：

```text
city × product_id × year
```

聚合后生成：

| 变量 | 含义 |
|---|---|
| `product_id` | 9 位产品码 |
| `city` | 购方城市或地区代码 |
| `year` | 年份，当前为 2017 |
| `mkt_value` | 全城市该产品购买金额 |
| `mkt_qty` | 全城市该产品购买数量 |
| `p_mkt` | 全城市该产品平均采购价格，等于 `mkt_value / mkt_qty` |
| `ln_p_mkt` | `p_mkt` 的对数 |
| `ln_mkt_qty` | `mkt_qty` 的对数 |
| `n_buyers` | 买方企业数 |
| `ln_n_buyers` | 买方企业数对数 |
| `n_raw_codes` | 聚合到该 9 位产品下的原始项目代码数量 |
| `n_rows` | 聚合前记录数 |

核心逻辑为：

```python
market_conds_buy = city_clean.groupby(['city', 'product_id', 'year'], as_index=False).agg(
    mkt_value=('value', 'sum'),
    mkt_qty=('qty', 'sum'),
    n_buyers=('n_buyers_raw', 'sum'),
    n_raw_codes=('product_code', 'nunique'),
    n_rows=('product_code', 'size')
)

market_conds_buy = market_conds_buy[(market_conds_buy['mkt_value'] > 0) & (market_conds_buy['mkt_qty'] > 0)].copy()
market_conds_buy['p_mkt'] = market_conds_buy['mkt_value'] / market_conds_buy['mkt_qty']
market_conds_buy['ln_p_mkt'] = np.log(market_conds_buy['p_mkt'])
market_conds_buy['ln_mkt_qty'] = np.log(market_conds_buy['mkt_qty'])
market_conds_buy['ln_n_buyers'] = np.log(market_conds_buy['n_buyers'])
```

## 5. 输出文件

`clean_city.ipynb` 不直接覆盖主回归使用的 `market_conds.dta`，而是先生成清楚命名的全城市购买市场条件文件。

输出文件包括：

| 文件 | 内容 |
|---|---|
| `city_buy_full_clean.csv` | 清理后的城市购买原始层面数据，仍保留原始 `product_code` 和 `code19` |
| `city_buy_full_clean.dta` | 上述数据的 Stata 版本 |
| `market_conds_buy_full.csv` | 城市 × 9 位产品 × 年份层面的 purchase-side market condition |
| `market_conds_buy_full.dta` | 上述 market condition 的 Stata 版本 |

其中，最重要的回归用文件是：

```text
market_conds_buy_full.dta
```

它可以后续按以下键并入企业购买面板：

```text
product_id city year
```

## 6. 与旧 market condition 的区别

旧口径：

```text
city_buy.csv
```

旧口径的问题是，它来自样本企业聚合。其 SQL 逻辑限制在 `tmp_sample_cid` 内，所以城市市场条件实际是“样本企业在该城市该产品上的购买情况”。

新口径：

```text
city.csv -> market_conds_buy_full.dta
```

新口径应该来自全体城市企业聚合，不再限制样本企业。因此它衡量的是该城市该产品的总体购买市场情况，包括：

- 城市总体购买规模；
- 城市总体购买数量；
- 城市平均采购价格；
- 城市市场厚度。

这更符合回归中 market condition 的定义。

## 7. 需要特别注意的问题

### 7.1 `n_buyers` 可能存在重复加总

当前 `city.csv` 中的 `买方企业数` 是在原始 `项目代码` 层面统计的。如果一个企业在同一城市、同一 9 位产品下购买了多个不同的原始项目代码，那么在压缩到 9 位 `product_id` 后，简单加总 `买方企业数` 可能会重复计算该企业。

因此：

- `mkt_value`、`mkt_qty`、`p_mkt` 是可靠的，因为金额和数量可以直接加总。
- `n_buyers` 是近似的市场厚度指标。
- 如果需要严格的不同买方企业数，最好在 SQL 中直接按 9 位产品码统计：

```sql
COUNT(DISTINCT 购方企业ID)
```

### 7.2 最理想的 SQL 口径

最理想的取数方式是在 SQL 中先把 `项目代码` 清理为 9 位 `product_id`，然后直接按：

```text
购方地区 × product_id
```

聚合：

```sql
SUM(开票金额)
SUM(TRY_CAST(数量 AS float))
COUNT(DISTINCT 购方企业ID)
```

这样可以避免 Python 端压缩产品码后重复加总 `买方企业数` 的问题。

## 8. 后续使用建议

后续主清理流程可以有两种做法。

### 做法一：先单独跑 `clean_city.ipynb`

先生成：

```text
market_conds_buy_full.dta
```

然后在主回归数据构造流程中，用它替换旧的 purchase-side market condition。

### 做法二：把逻辑并入 `01_clean.ipynb`

如果确认 `city.csv` 是最终口径，可以把 `clean_city.ipynb` 中的逻辑合并进 `01_clean.ipynb`，让主清理流程直接生成新的 `market_conds.dta`。

不过在 seller-side 全城市数据尚未同步整理之前，建议暂时保留独立文件：

```text
market_conds_buy_full.dta
```

这样不会误覆盖原来包含 seller-side 信息的 `market_conds.dta`。
