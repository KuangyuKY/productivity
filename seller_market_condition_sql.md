# 卖方市场条件口径调整说明与 SQL

## 1. 当前问题

目前 `city_sell.csv` 的口径是：

> 按销方地区和项目代码分组，统计每个城市本地有多少卖方企业销售某个产品。

这个口径对应的经济含义是：

> 城市 c 本地供给能力 / 本地产业集聚程度。

如果研究问题是“本地有多少供应商会影响采购价格”，这个口径可以使用。

但如果研究问题是“买方企业采购价格受到其面对的供应商竞争影响”，那么更合适的口径应该是：

> 按购方地区和项目代码分组，统计向该购方城市供货的不同销方企业数量。

也就是说，城市变量应该始终表示买方所在地，而不是卖方所在地。

## 2. 三种卖方数量口径的区别

| 口径 | 分组方式 | 变量含义 | 是否有城市差异 | 是否适合采购价格机制 |
|---|---|---|---|---|
| 当前口径：本地卖方数量 | 销方地区 × 项目代码 | 城市 c 本地有多少企业卖产品 p | 有 | 可以，但解释为本地供给集聚 |
| 全国卖方数量 | 项目代码 | 全国有多少企业卖产品 p | 无 | 可以作为产品层面供给厚度，但容易被产品固定效应吸收 |
| 建议口径：买方城市面对的卖方数量 | 购方地区 × 项目代码 | 有多少不同卖方企业向城市 c 的买方销售产品 p | 有 | 更适合解释采购价格 |

## 3. 建议重新抓取的 city_sell_new SQL

下面这个版本用于构造新的卖方市场条件。注意：虽然统计的是卖方企业数，但分组城市使用的是购方地区。

```sql
SELECT
    购方地区,
    项目代码,
    COUNT(DISTINCT 销方企业ID) AS 卖方企业数,
    SUM(开票金额) AS 金额合计,
    SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE 购方地区 IS NOT NULL
  AND 项目代码 IS NOT NULL
  AND 销方企业ID IS NOT NULL
GROUP BY 购方地区, 项目代码;
```

## 4. 如果继续使用全年 12 个月数据

如果后面要扩展到全年 12 个月，可以使用如下结构，把所有月份 `UNION ALL` 进去：

```sql
SELECT
    购方地区,
    项目代码,
    COUNT(DISTINCT 销方企业ID) AS 卖方企业数,
    SUM(开票金额) AS 金额合计,
    SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1703
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1704
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1705
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1706
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1707
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1708
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1709
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1710
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1711
    UNION ALL
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1712
) a
WHERE 购方地区 IS NOT NULL
  AND 项目代码 IS NOT NULL
  AND 销方企业ID IS NOT NULL
GROUP BY 购方地区, 项目代码;
```

## 5. 新数据导出后的 notebook 修改方向

如果把上面的查询结果仍然保存成 `city_sell.csv`，那么 `01_clean.ipynb` 中读取卖方侧数据时，列名逻辑需要从：

```python
cs_cols = {'销方地区': 'city', '项目代码': 'product_code',
           '卖方企业数': 'n_sellers_raw', '金额合计': 'value', '数量合计': 'qty'}
```

改为：

```python
cs_cols = {'购方地区': 'city', '项目代码': 'product_code',
           '卖方企业数': 'n_sellers_raw', '金额合计': 'value', '数量合计': 'qty'}
```

这样 `invoice_panel.dta`、`city_buy.csv` 和新的卖方市场条件中的 `city` 都表示买方企业所在地。

## 6. 当前版本是否可以先给老师看

可以。当前版本并不是程序错误，而是一个市场条件口径选择问题。现有结果可以先作为第一版结果给老师看，但解释时要说明：

> 当前的卖方市场条件衡量的是企业所在城市的本地卖方数量，即本地供给集聚，而不是该城市买方面对的全部供应商数量。

后续如果老师更关注采购价格中的供应商竞争机制，建议再替换为本文件中的新 SQL 口径。
