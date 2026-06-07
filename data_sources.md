# 数据来源与 SQL 抽取（合并文档）

> 本文档合并自原 `original_data.md`、`data_des.md`、`sql_reference.md`、`baidu_huisuan_2017_data_description.md`，统一记录"数据从哪里来"：原始发票字段、抽样方式、虚拟机数据位置、SQL 抽取查询、以及 Capital 桥接数据源。

---

## 0. 两层数据口径（重要）

本阶段数据有**两个口径**，不要混淆：

1. **早期原始逐笔发票 CSV**（`sample_GX1701/02/03.csv`）——逐条发票明细，列名为中文原始字段。因数据量约 10 亿行，Python 无法直接支撑，**已弃用**。其字段说明保留于 §1，仅作字段参考。
2. **当前 SQL 预聚合 CSV**（`firm_buy/firm_sell/city_buy/city_sell/firm_city.csv`）——在 SQL 端先 `GROUP BY` 聚合后导出，列名与原始数据不同。**这是当前实际使用的数据**，见 §2–§3。

**抽样方式**：按企业抽样。先随机选定一批样本企业（名单表 `dbo.tmp_sample_cid`，约 **3,410 家**），再取这些企业作为购方或销方的**全部**发票记录。被选中企业全年买卖记录完整，但样本偏向交易量较大的企业（抽样机制导致的选择性，分析时需注意）。City 级聚合（city_buy/city_sell）为**全量**口径，不限样本企业。

---

## 1. 早期原始发票字段（已弃用，仅作字段参考）

每行 = 一条发票明细：某购方企业向某销方企业就某项目开具的一笔发票。三个 CSV（1701/1702/1703）列完全一致，合并即 2017 全年。

| 列名 | 类型 | 含义 |
|---|---|---|
| 开票日期 | date | 发票开具日期，如 `2017-02-04` |
| 购方企业ID | int | 购买方企业唯一标识 |
| 购方地区 | string | 购买方地区代码（如 `3200`，当类别处理） |
| 销方企业ID | int | 销售方企业唯一标识 |
| 销方地区 | string | 销售方地区代码（当类别处理） |
| 项目代码 | string | 商品/项目代码，19 位长数字串（**必须当字符串**，否则精度丢失） |
| 项目 | string | 商品/项目名称（中文） |
| 开票金额 | float | 发票金额，**可为负**（红冲/退票） |
| 单位 | string | 计量单位（EA/批/箱…），**大量缺失** |
| 数量 | text→num | 原始以文本存储，可缺失、可为负 |
| 单价 | float | 单价 |
| 税额 | float | 税额，**可为负** |

**清洗关键点**（同样适用于当前 SQL CSV 的下游处理）：
1. `数量` 是文本，需 `pd.to_numeric(errors='coerce')` / `destring ... force` 转数值。
2. 长 ID / `项目代码` 必须当字符串，防精度丢失。
3. 编码 UTF-8（`utf-8-sig` 防中文乱码）。
4. 金额/税额负值是真实业务（红冲/退货/折让），勿误删；净额计算需保留。
5. 缺失值统一识别（`na_values=['','NULL','(Null)']`）。
6. 同一企业可同时为购方与销方，存在自交易记录。

**原始样本示例**：

| 开票日期 | 购方企业ID | 购方地区 | 销方企业ID | 销方地区 | 项目代码 | 项目 | 开票金额 | 单位 | 数量 | 单价 | 税额 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2017-02-04 | 14546297 | 3200 | 8980839 | 3101 | 3040502020400000000 | 租金 | 41591.75 | (Null) | 1 | 39611.19 | 1980.56 |
| 2017-02-07 | 17868992 | 3303 | 9726286 | 3100 | 1090512020000000000 | 嵌入式开关电源 | -10089.78 | 批 | -1 | 8623.74 | -1466.04 |
| 2017-02-20 | 27620494 | 4201 | 9579225 | 3101 | 1070222020000000000 | 汰渍洗衣粉 | 87911.75 | 箱 | 1000 | 75.14 | 12773.5 |

---

## 2. 虚拟机数据位置

代码在本地写作 + git 同步，实际运行在虚拟机 `G:\Kuangyu_Temp\Outsource\`。

| 文件 | 位置 | 说明 |
|---|---|---|
| `full_data.dta` | `G:\Kuangyu_Temp\Outsource\` | 第一阶段主面板（firm × product × year，约 90M 行），含企业特征、main_product、input/output similarity |
| `bianma.dta` | `G:\Kuangyu_Temp\Outsource\` | 2,778 个合法 9 位产品码 + 货物名称，用于产品代码匹配 |
| 5 个发票 CSV | `G:\Kuangyu_Temp\Outsource\productivity\` | 见 §3，本阶段 DV + 市场条件来源 |
| 百度汇算文件 | `H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta` | Capital 桥接源，见 §5 |

> 数据量过大（直接导出约 10 亿行），故先在 SQL 中合并再输出 CSV，列名与原始数据不同。所有 ID、地区代码、项目代码均为字符串存储。

---

## 3. 五个 SQL 预聚合 CSV

### 3.1 文件结构总览

| 文件 | 行数 | 大小 | 颗粒度 | 主要用途 |
|---|---:|---:|---|---|
| `firm_buy.csv` | ~473,281 | 23 MB | 购方企业ID × 项目代码（含地区） | 构造 DV：外包采购单价 = 金额合计/数量合计 |
| `firm_sell.csv` | ~101,845 | 5 MB | 销方企业ID × 项目代码（含地区） | 外包识别 + 净生产额（主产品定义）+ 卖方侧 LOO 扣除项 |
| `city_buy.csv` | ~2,105,334 | 106 MB | 购方地区 × 项目代码 | 需求侧市场条件（全量）：n_buyers, mkt_qty, p_mkt |
| `city_sell.csv` | ~1,540,248 | 76 MB | 销方地区 × 项目代码 | 供给侧市场条件（全量）：n_sellers |
| `firm_city.csv` | 3,410 | 64 KB | 企业ID × 地区 | 给样本企业补地区信息 |

主要列名：firm_buy/firm_sell = (企业ID, 项目代码, 金额合计, 数量合计)；city_buy/city_sell 另含（买方企业数/卖方企业数）。
- 金额用 `SUM(开票金额)`，正负红冲自动对冲为净额（净值可能 ≤ 0，由 Python 端 drop）。
- 数量用 `SUM(TRY_CAST(数量 AS float))`，转不了的记为 NULL 自动被 SUM 忽略。
- 项目代码未清洗，Python 端处理（右补零 19 位 → 截前 9 位 → 与 bianma 匹配）。

### 3.2 SQL 查询

**前提**：数据库 `GX17`，schema `dbo`，SQL Server。三张年表 `GX1701/02/03` 用 `UNION ALL` 合并即全年。仅针对名单表 `dbo.tmp_sample_cid`（约 3,410 家）；city 级为全量。运行前确保名单表固定、整个过程不要重新生成，否则各表口径不一致。Navicat 中用英文半角输入法。每个查询扫近 10 亿行，逐个单独运行。

**表1 企业购买表（firm_buy.csv）** — 颗粒度 `购方企业ID × 项目代码`（含地区）
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

**表2 企业销售表（firm_sell.csv）** — 颗粒度 `销方企业ID × 项目代码`（含地区）
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

**表3 地区购买表（city_buy.csv）** — 颗粒度 `购方地区 × 项目代码`，**全量口径**，构造市场需求条件
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

**表4 地区销售表（city_sell.csv）** — 卖方市场条件有两种口径：

*口径A（当前使用）：按销方地区分组* — 统计本地有多少企业卖某产品（本地供给集聚）
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

*口径B（备选，与采购价格机制更吻合）：按购方地区分组* — 统计向某城市买方供货的不同卖方企业数（买方面对的供应商竞争）
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

| 口径 | 分组城市 | 含义 | city 对齐 |
|---|---|---|---|
| A（当前）| 销方地区 | 本地供给集聚 | 与 city_buy、invoice_panel **不一致** |
| B（备选）| 购方地区 | 买方面对的供应商竞争 | 与 city_buy、invoice_panel 一致 ✓ |

> 若改用口径 B，`01_clean.ipynb` 读取 `city_sell.csv` 时列名从 `销方地区` 改为 `购方地区`，其余逻辑不变。**卖方口径是否切换为待决项。**

**表5 企业-地区对照表（firm_city.csv）** — 给样本企业补地区（当前 3,410 行）
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
> 若同一企业 ID 出现多个地区，Python 端取第一条或众数（实测基本 1:1）。

**扩展到全年 12 个月**：在每个查询子查询里追加 `GX1704 … GX1712` 的 `UNION ALL` 块即可，结构相同。

---

## 4. 沿用数据（来自第一阶段）

- **`full_data.dta`**：firm × product × year 特征，含 `main_product`（按企业最大生产产值定义，与本阶段 VAT 净生产额 sell−buy 取正最大者一致）、`input_similarity`、`output_similarity`。外包产品必出现在销售侧 → 在 full_data 中有对应记录，可直接 `merge on (firm_id, product_id)`。无需用 `full_product_similarity.dta`（旧覆盖率低是因为包含了原材料采购，非方法问题）。
- **`bianma.dta`**：2,778 个合法 9 位产品码，用于产品代码匹配。本地副本在 `C:\Users\HKUBS\Documents\aproject\Outsourcing\code\description\bianma.dta`（与 VM 一致）。

---

## 5. Capital 桥接数据源（百度汇算文件）

**文件**：`H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta`（约 5.6 GB，15,334,226 行，42 变量；时间戳 2025-02-10）。基于 Stata `describe` 输出整理（非手动解析文件头）。

**核心结论**：该文件不是单纯 `cid → id` 桥接表，本身已含企业识别、注册信息、行业地区和一批汇算财务变量。**关键是自带 `total_assets`（double，标签 Total Assets）**，因此构造回归资本变量 `Capital`/`ln_Capital` 可**一步桥接**：

```
firm_id (=cid) → total_assets → Capital → ln_Capital
```
而不需要旧的两步路径 `firm_id → cid → id → H:\汇算数据\2017.dta → 资产总额`。

**企业识别变量**：`cid`（str9，发票侧企业 ID，与回归面板 `firm_id` 对接）、`id`（str9，汇算侧 ID）、`eid`（str32）、`reg_number`、`usc_code`、`org_number`、`obs_id`。

**主要财务变量**（均来自汇算）：`total_assets`（→ Capital）、`total_reg_capital`、`employees`、`operating_revenue`、`operating_cost`、`operating_profit`、`net_profit`、`total_profit_loss`、`sales_expense`、`admin_expense` 等；另有省份/行业/税率等注册行业变量。

**建议的 Stata 桥接逻辑**：
```stata
preserve
    use "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta", clear
    destring cid, replace force
    drop if missing(cid)
    keep cid total_assets employees operating_revenue net_profit
    bysort cid: gen rep_no = _n
    keep if rep_no == 1
    drop rep_no
    rename total_assets Capital
    save "baidu_huisuan_2017_clean.dta", replace
restore

destring firm_id, gen(cid) force
merge m:1 cid using "baidu_huisuan_2017_clean.dta", ///
    keepusing(Capital employees operating_revenue net_profit) keep(master match) nogen
gen ln_Capital = ln(Capital) if Capital > 0 & !missing(Capital)
```

> 当前实现里 Capital 已在 `01_clean.ipynb` Step 10b 桥接进 `firm_chars.dta`，`02_price_reg.do` 直接用 `ln_Capital`。回归面板内匹配率约 **62.3%**（详见 `data_outputs.md` §6.4）。

**正式替换前建议核查**：`total_assets` 非缺失数、`>0` 数、`cid` 唯一数、一个 cid 多条记录时 total_assets 是否一致、合并后 `ln_Capital` 缺失下降幅度。
