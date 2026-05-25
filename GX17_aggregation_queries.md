# GX17 — 2017年发票数据 聚合取数 SQL 汇总

## 说明

- 数据库:`GX17`,schema:`dbo`,SQL Server。
- 三张年表 `GX1701` / `GX1702` / `GX1703` 合起来是 2017 全年数据,**每个查询内部已用 `UNION ALL` 合并三张表**,直接产出全年结果。
- 所有查询**只针对抽样的样本公司**(名单表 `dbo.tmp_sample_cid`,约 3410 家)。
- 聚合指标:`SUM(开票金额)` 金额合计(正负红冲自动对冲为净额)、`SUM(数量)` 数量合计。
- `数量` 原始是字符串,用 `TRY_CAST(数量 AS float)` 转数值,转不了的记为 NULL 不影响求和。

> **前提**:运行前确保 `dbo.tmp_sample_cid` 是你那 3410 家的名单,且整个过程中**不要重新生成名单**,否则各表口径会不一致。

> **运行方式**:每段查询单独跑(Run Selected),出结果确认行数合理后,在结果网格右键 / 用 Export 导出为 CSV,**UTF-8 编码**(中文不乱码)。各查询都要扫三张表近 10 亿行,且按销方筛选无索引,**耗时较长**,逐个挂着跑即可。

> **注意全角字符**:在 Navicat 里输入时切换到英文半角输入法,标点、空格、括号都用半角,避免出现 `"SUM"附近有语法错误` 这类全角字符导致的报错。

---

## 表1:企业购买表(样本公司作为购方)

颗粒度:`购方企业ID + 购方地区 + 项目代码`。每行表示某样本企业作为买方、就某产品的全年采购汇总。
(已带上 `购方地区` 列,因地区由企业ID唯一决定,加入不改变分组结果,方便后续按地区分析。)

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

建议导出文件名:`enterprise_buy.csv`

---

## 表2:企业销售表(样本公司作为销方)

颗粒度:`销方企业ID + 销方地区 + 项目代码`。每行表示某样本企业作为卖方、就某产品的全年销售汇总。

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

建议导出文件名:`enterprise_sell.csv`

---

## 表3:地区购买表(样本公司作为购方,按购方地区汇总)

颗粒度:`购方地区 + 项目代码`。把同地区所有样本企业的采购合并,行数很少。

```sql
SELECT 购方地区, 项目代码,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 购方企业ID, 购方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.购方企业ID)
GROUP BY 购方地区, 项目代码;
```

建议导出文件名:`region_buy.csv`

---

## 表4:地区销售表(样本公司作为销方,按销方地区汇总)

颗粒度:`销方地区 + 项目代码`。

```sql
SELECT 销方地区, 项目代码,
       SUM(开票金额) AS 金额合计,
       SUM(TRY_CAST(数量 AS float)) AS 数量合计
FROM (
    SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1701
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1702
    UNION ALL SELECT 销方企业ID, 销方地区, 项目代码, 开票金额, 数量 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.销方企业ID)
GROUP BY 销方地区, 项目代码;
```

建议导出文件名:`region_sell.csv`

---

## 表5:企业-地区对照表(连接公司与地区的桥梁)

每个样本企业对应它的地区。用于在 Python / Stata 里把"公司层面"和"地区层面"的数据按企业ID关联起来。

企业可能作为购方出现(带购方地区),也可能作为销方出现(带销方地区);正常情况下同一企业两处地区一致。下面把两种角色的"企业-地区"对都收集起来去重:

```sql
SELECT DISTINCT 企业ID, 地区
FROM (
    -- 作为购方时的企业-地区
    SELECT 购方企业ID AS 企业ID, 购方地区 AS 地区 FROM dbo.GX1701
    UNION SELECT 购方企业ID, 购方地区 FROM dbo.GX1702
    UNION SELECT 购方企业ID, 购方地区 FROM dbo.GX1703
    UNION
    -- 作为销方时的企业-地区
    SELECT 销方企业ID, 销方地区 FROM dbo.GX1701
    UNION SELECT 销方企业ID, 销方地区 FROM dbo.GX1702
    UNION SELECT 销方企业ID, 销方地区 FROM dbo.GX1703
) a
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.企业ID);
```

建议导出文件名:`firm_region_map.csv`

> 提示:若同一企业ID出现了多个不同地区(数据中偶有此情况),对照表里该企业会有多行。分析时若需要每个企业唯一地区,可在 Python/Stata 里按企业ID取众数或第一条处理。

---

## 在 Python / Stata 中连接公司与地区

表1、表2已自带地区列,本身就含公司+地区,通常无需再连。
若要把纯地区表(表3、表4)与公司关联,或想给任意公司层面的数据补上地区,用表5对照表按企业ID合并即可。

### Python (pandas)
```python
import pandas as pd

# 读入时长ID/代码当字符串,避免精度丢失;中文用utf-8
buy   = pd.read_csv('enterprise_buy.csv',
                    dtype={'购方企业ID': str, '项目代码': str, '购方地区': str},
                    encoding='utf-8')
fmap  = pd.read_csv('firm_region_map.csv',
                    dtype={'企业ID': str, '地区': str}, encoding='utf-8')

# 例:给企业购买表按企业ID补地区(若表里没带地区时)
buy = buy.merge(fmap, left_on='购方企业ID', right_on='企业ID', how='left')
```

### Stata
```stata
import delimited "firm_region_map.csv", ///
    stringcols(企业id 地区) encoding("UTF-8") clear
tempfile fmap
save `fmap'

import delimited "enterprise_buy.csv", ///
    stringcols(购方企业id 项目代码 购方地区) encoding("UTF-8") clear
* 按企业ID合并地区(示例)
* rename 购方企业id 企业id
* merge m:1 企业id using `fmap'
```

> Stata `import delimited` 会把列名转小写;中文列名导入后可能异常,实际列名以 CSV 表头为准,必要时用 `rename` 调整,或在导出时改用英文表头。

---

## 数据使用注意点

1. **金额已对冲**:`金额合计` 是同组正负开票相抵后的净额(含红冲/退货)。可能为负,属正常。
2. **数量同理**:`数量合计` 也是净值,可能为负。
3. **长ID/代码当字符串**:`项目代码`(长数字串)、企业ID、地区代码读入时按字符串处理,防止精度丢失或被当数值。
4. **口径**:表1/表3只含样本公司作为购方的交易;表2/表4只含样本公司作为销方的交易。
5. **样本选择性**:样本由 TABLESAMPLE 抽取,偏向交易量大的企业,分析时注意这一选择性偏倚。
