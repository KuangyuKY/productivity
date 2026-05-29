# BaiduNetdisk 2017 汇算预匹配数据说明

## 1. 文件基本信息

- 数据文件：`H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta`
- 文件大小：约 5.613 GB
- Stata `.dta` 版本：release 118
- 观测数：15,334,226 行
- 变量数：42 个
- 文件修改时间：2025-06-08 12:02:22
- 文件内部时间戳：10 Feb 2025 13:09

这个文件不是一个单纯的 `cid -> id` 桥接表。它本身已经包含了一批汇算财务变量和企业识别变量，因此可以直接从这里提取资本、收入、利润、员工数等变量。

## 2. 核心结论

此前在 `02_price_reg.do` 中的处理逻辑是：

1. 用 BaiduNetdisk 文件拿到 `cid -> id`；
2. 再用 `id` 去 `H:\汇算数据\2017.dta` 里找 `资产总额`；
3. 把 `资产总额` 改名为 `Capital`，再生成 `ln_Capital`。

检查后发现，BaiduNetdisk 文件本身已经有 `total_assets`，变量标签是 `Total Assets`。这个变量对应中文口径里的资产总额。因此，如果只是为了构造资本变量，理论上不必再去 `H:\汇算数据\2017.dta` 做第二次匹配。

更合理的新逻辑应该是：

1. 从 BaiduNetdisk 文件中保留 `cid` 和 `total_assets`；
2. 对 `cid` 去重，保证每个发票企业只对应一条记录；
3. 直接把 `total_assets` 合并到回归面板；
4. 把 `total_assets` 改名为 `Capital`；
5. 生成 `ln_Capital = ln(Capital)`。

这样可以避免当前 `id -> H:\汇算数据\2017.dta` 这一步造成额外样本损失。

## 3. 关键识别变量

| 变量名 | 类型 | 标签 | 说明 |
|---|---:|---|---|
| `eid` | str32 | 无 | 企业识别码。学长部分代码中用 `eid` 与汇算数据匹配。 |
| `id` | str9 | ID | 汇算侧企业 ID。此前我用它继续连接 `H:\汇算数据\2017.dta`。 |
| `cid` | str9 | 无 | 发票侧企业 ID。我们的 `firm_id` 转成数值后逻辑上对应这个变量。 |
| `obs_id` | long | 无 | 文件内部观测编号。 |

## 4. 汇算财务和企业变量

| 变量名 | 类型 | 标签 | 中文含义 / 用途 |
|---|---:|---|---|
| `employees` | byte | Number of Employees | 从业人数。 |
| `operating_revenue` | byte | Operating Revenue | 营业收入。 |
| `operating_cost` | byte | Operating Cost | 营业成本。 |
| `operating_tax` | byte | Operating Tax and Surcharge | 营业税金及附加。 |
| `sales_expense` | byte | Sales Expense | 销售费用。 |
| `admin_expense` | byte | Administrative Expense | 管理费用。 |
| `financial_expense` | int | Financial Expense | 财务费用。 |
| `asset_impairment` | byte | Asset Impairment Loss | 资产减值损失。 |
| `fair_value_change` | byte | Fair Value Change Gain/Loss | 公允价值变动收益/损失。 |
| `investment_income` | byte | Investment Income | 投资收益。 |
| `operating_profit` | byte | Operating Profit | 营业利润。 |
| `non_operating_income` | byte | Non-Operating Income | 营业外收入。 |
| `non_operating_expense` | int | Non-Operating Expense | 营业外支出。 |
| `total_profit_loss` | byte | Total Profit (Loss) | 利润总额。 |
| `tax_payable` | int | Tax Payable | 应纳税额。 |
| `actual_tax_payable` | int | Actual Tax Payable | 实际应纳税额。 |
| `net_profit` | byte | Net Profit | 净利润。 |
| `b_class_revenue` | byte | B Class Revenue | B 类收入。 |
| `b_class_cost` | int | B Class Cost | B 类成本。 |
| `b_class_expense` | int | B Class Expense | B 类费用。 |
| `total_assets` | byte | Total Assets | 总资产。应当对应我们需要的 `Capital`。 |
| `total_reg_capital` | byte | Total Registered Capital | 注册资本。 |

重要：这个文件中没有中文变量名 `资产总额`，但有英文变量 `total_assets`，标签是 `Total Assets`。因此如果使用这个文件本身的数据，资本变量应该从 `total_assets` 提取，而不是继续寻找中文变量 `资产总额`。

## 5. 注册、地区和行业变量

| 变量名 | 类型 | 标签 | 说明 |
|---|---:|---|---|
| `reg_number` | str72 | 无 | 注册号。 |
| `usc_code` | str39 | 无 | 统一社会信用代码。 |
| `org_number` | str19 | 无 | 组织机构代码。 |
| `province` | str9 | 无 | 省份。 |
| `province_code` | int | 无 | 省份代码。 |
| `region` | long | Region | 地区。 |
| `reg_type` | str3 | Registration Type | 登记注册类型。 |
| `econ_type_code` | float | Economic Type Code | 经济类型代码。 |
| `industry_code` | str4 | Industry Code | 行业代码。 |
| `industry_category` | str1 | Industry Category | 行业大类。 |
| `industry_major` | str2 | Industry Major Category | 行业门类/大类。 |
| `industry_medium` | str3 | Industry Medium Category | 行业中类。 |
| `corp_tax_rate` | int | Corporate Tax Rate | 企业所得税税率。 |
| `levy_type` | str1 | Levy Type | 征收方式。 |

## 6. 税期变量

| 变量名 | 类型 | 标签 | 说明 |
|---|---:|---|---|
| `tax_period_start` | str10 | Tax Period Start Date | 纳税期开始日期。 |
| `tax_period_end` | str10 | Tax Period End Date | 纳税期结束日期。 |

## 7. 与学长代码的关系

学长代码里确实大量使用了这个 BaiduNetdisk 文件作为预匹配文件。例如：

- `datamerge/merge汇算_3_13categ.do` 先读取该文件，处理 `cid`，再保存唯一 `cid` 的匹配文件。
- `datamerge/merge汇算_6_13categ_yearmonth_2017.do` 也是先读取该文件，生成带 `cid` 和 `year` 的匹配数据。
- 但是学长后续很多代码又会重新合并 `H:\汇算数据\2017.dta`，并把中文变量 `资产总额` 重命名为 `Expend_Capital`。

这说明学长当时可能把 BaiduNetdisk 文件主要当作匹配结果使用。但从本次元数据检查看，这个文件本身已经保留了标准化后的汇算财务变量，所以我们当前项目可以直接用 `total_assets` 来构造资本变量。

## 8. 对 `02_price_reg.do` 的建议

建议把资本匹配逻辑从当前的两步：

```stata
firm_id -> cid -> id -> H:\汇算数据\2017.dta -> 资产总额 -> Capital
```

改成一步：

```stata
firm_id -> cid -> BaiduNetdisk 文件中的 total_assets -> Capital
```

对应 Stata 逻辑大致如下：

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

这样做的优点是：

1. 不再经过 `id -> H:\汇算数据\2017.dta` 的第二次匹配；
2. 能直接利用 BaiduNetdisk 文件中已经整理好的汇算变量；
3. 理论上应该显著减少 `ln_Capital` 缺失；
4. 逻辑上也更接近用户现在希望采用的 BaiduNetdisk 口径。

## 9. 需要注意的问题

1. `total_assets` 的存储类型显示为 `byte`，这说明该文件里的财务变量可能不是原始金额，也可能经过压缩、编码或单位处理。后续正式用于回归前，应当检查 `total_assets` 的分布、取值范围和单位。
2. `cid` 在文件中是字符串，需要转成数值后再与回归面板中的 `firm_id` 对接。
3. 文件有 15,334,226 行，非常大。每次直接读取会比较慢，最好在第一次清洗后保存一个小的中间文件，例如 `baidu_huisuan_2017_clean.dta`。
4. 如果一个 `cid` 对应多条记录，目前建议先保留第一条，以复现学长代码中的常见做法；但更严谨的做法是检查重复 `cid` 的来源和变量差异。

## 10. 本次检查依据

本次检查读取了该 `.dta` 文件头部元数据，确认了：

- 观测数；
- 变量数；
- 全部变量名；
- Stata 存储类型；
- 变量显示格式；
- 变量标签。

本次没有完整加载 5.6GB 数据进入内存，因此没有计算每个变量的描述统计。下一步如果要正式替换 `02_price_reg.do`，建议先运行一次小范围检查，重点看：

- `cid` 非缺失数量；
- `cid` 唯一数量；
- `total_assets` 非缺失数量；
- `total_assets > 0` 的数量；
- 合并到当前回归面板后的 `ln_Capital` 缺失数。