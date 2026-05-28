# GX17 — SQL 数据抽取参考

## 前提与运行说明

- 数据库：`GX17`，schema：`dbo`，SQL Server。
- 三张年表 `GX1701` / `GX1702` / `GX1703` 合起来是 2017 全年数据，每个查询内部已用 `UNION ALL` 合并，直接产出全年结果。
- 所有查询**只针对抽样的样本公司**（名单表 `dbo.tmp_sample_cid`，约 3410 家）。
- 金额用 `SUM(开票金额)`，正负红冲自动对冲为净额；数量用 `TRY_CAST(数量 AS float)` 转数值，转不了的记为 NULL 自动被 `SUM` 忽略。
- 运行时在 Navicat 中切换**英文半角输入法**，避免全角字符导致语法报错。
- 各查询须扫三张表近 10 亿行，耗时较长，逐个单独运行即可。
- 运行前确保 `dbo.tmp_sample_cid` 名单固定，整个过程中**不要重新生成**，否则各表口径不一致。

---

## 表1：企业购买表（样本企业作为购方）

颗粒度：`购方企业ID × 项目代码`（含地区）。

```sql
SELECT 购方企业ID, 购方地区, 项目代码,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.购方企业ID)
GROUP BY 购方企业ID, 购方地区, 项目代码;
```

导出文件名：`firm_buy.csv`

---

## 表2：企业销售表（样本企业作为销方）

颗粒度：`销方企业ID × 项目代码`（含地区）。

```sql
SELECT 销方企业ID, 销方地区, 项目代码,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.销方企业ID)
GROUP BY 销方企业ID, 销方地区, 项目代码;
```

导出文件名：`firm_sell.csv`

---

## 表3：地区购买表（全城市采购侧，全量）

颗粒度：`购方地区 × 项目代码`。**不限样本企业，全量口径**，用于构造市场需求条件。

```sql
SELECT 购方地区, 项目代码,
       COUNT(DISTINCT 购方企业ID) AS 买方企业数,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE 购方地区 IS NOT NULL AND 项目代码 IS NOT NULL
GROUP BY 购方地区, 项目代码;
```

导出文件名：`city_buy.csv`

---

## 表4：地区销售表（全城市供给侧）

卖方市场条件有两种口径，见下方说明，请根据研究需要选择。

### 口径A（当前使用）：按销方地区分组

统计本地有多少企业卖某产品（本地供给集聚）。

```sql
SELECT 销方地区, 项目代码,
       COUNT(DISTINCT 销方企业ID) AS 卖方企业数,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE 销方地区 IS NOT NULL AND 项目代码 IS NOT NULL
GROUP BY 销方地区, 项目代码;
```

导出文件名：`city_sell.csv`（对应 `01_clean.ipynb` 中用 `销方地区` 作为 `city`）

### 口径B（备选，与采购价格机制更吻合）：按购方地区分组

统计向某城市买方供货的不同卖方企业数（买方面对的供应商竞争）。分组城市为**购方地区**，但计数对象是**销方企业**。

```sql
SELECT 购方地区, 项目代码,
       COUNT(DISTINCT 销方企业ID) AS 卖方企业数,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 购方地区, 销方企业ID, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE 购方地区 IS NOT NULL AND 项目代码 IS NOT NULL AND 销方企业ID IS NOT NULL
GROUP BY 购方地区, 项目代码;
```

若用此口径替换，`01_clean.ipynb` 中读取 `city_sell.csv` 时列名从 `销方地区` 改为 `购方地区`，其余逻辑不变。

**两种口径对比：**

| 口径 | 分组城市 | 含义 | city 对齐 |
|---|---|---|---|
| A（当前）| 销方地区 | 本地供给集聚 | 与 city_buy、invoice_panel 不一致 |
| B（备选）| 购方地区 | 买方面对的供应商竞争 | 与 city_buy、invoice_panel 一致 ✓ |

---

## 表5：企业-地区对照表

给样本企业补地区信息。

```sql
SELECT DISTINCT 企业ID, 地区
FROM (
    SELECT 购方企业ID AS 企业ID, 购方地区 AS 地区 FROM dbo.GX1701
    UNION SELECT 购方企业ID, 购方地区 FROM dbo.GX1702
    UNION SELECT 购方企业ID, 购方地区 FROM dbo.GX1703
    UNION
    SELECT 销方企业ID, 销方地区 FROM dbo.GX1701
    UNION SELECT 销方企业ID, 销方地区 FROM dbo.GX1702
    UNION SELECT 销方企业ID, 销方地区 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.企业ID);
```

导出文件名：`firm_city.csv`（当前已有，3410 行）

> 若同一企业 ID 出现多个地区，Python 端可取第一条或众数。实测样本企业基本为 1:1 映射。

---

## 扩展到全年 12 个月

若后续要扩展到全年 12 个月，在每个查询的子查询里追加 `GX1704` … `GX1712` 的 `UNION ALL` 块即可，结构相同。
