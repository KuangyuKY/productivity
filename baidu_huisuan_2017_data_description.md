# BaiduNetdisk 2017 汇算预匹配数据说明

## 1. 文件基本信息

本说明基于 Stata 的 [`describe`](productivity/baidu_huisuan_describe.log:12) 输出，而不是手动解析 `.dta` 文件头。

- 数据文件：`H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta`
- Stata 日志：[`productivity/baidu_huisuan_describe.log`](productivity/baidu_huisuan_describe.log)
- 观测数：15,334,226 行，见 [`Observations`](productivity/baidu_huisuan_describe.log:16)
- 变量数：42 个，见 [`Variables`](productivity/baidu_huisuan_describe.log:17)
- 文件内部时间戳：10 Feb 2025 13:09，见 [`describe`](productivity/baidu_huisuan_describe.log:16)

前一版说明里很多财务变量被写成 `byte`，这是因为我用 PowerShell 直接解析 Stata 118 格式文件头时，变量存储类型解析不可靠。现在已经改为以 Stata 官方 [`describe`](productivity/baidu_huisuan_describe.log:12) 结果为准。根据 Stata 输出，核心财务变量大多是 `double`，不是 `byte`。

## 2. 核心结论

这个文件不是单纯的 `cid -> id` 桥接表。它本身已经包含企业识别变量、注册信息、行业地区变量和一批汇算财务变量。

尤其重要的是：文件中已经有 `total_assets`，其变量标签是 `Total Assets`，见 [`total_assets`](productivity/baidu_huisuan_describe.log:71)。因此，如果我们只是为了构造回归里的资本变量 `Capital` / `ln_Capital`，可以直接从这个 BaiduNetdisk 文件里取 `total_assets`，不一定需要再去 `H:\汇算数据\2017.dta` 里二次匹配中文变量 `资产总额`。

当前更合理的资本匹配链条应当是：

```stata
firm_id -> cid -> total_assets -> Capital -> ln_Capital
```

而不是：

```stata
firm_id -> cid -> id -> H:\汇算数据\2017.dta -> 资产总额 -> Capital -> ln_Capital
```

## 3. Stata describe 原始结果摘录

Stata 运行的命令是：

```stata
describe using "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta"
```

对应日志见 [`productivity/baidu_huisuan_describe.log`](productivity/baidu_huisuan_describe.log)。

核心输出：

```text
Contains data
 Observations:    15,334,226                  10 Feb 2025 13:09
    Variables:            42
```

完整变量列表根据 [`describe`](productivity/baidu_huisuan_describe.log:19) 整理如下。

## 4. 企业识别变量

| 变量名 | Storage type | Display format | Variable label | 说明 |
|---|---:|---:|---|---|
| `eid` | str32 | %32s |  | 企业识别码。学长部分代码中也使用 `eid` 进行汇算匹配。 |
| `reg_number` | str72 | %72s |  | 注册号。 |
| `usc_code` | str39 | %39s |  | 统一社会信用代码。 |
| `org_number` | str19 | %19s |  | 组织机构代码。 |
| `obs_id` | long | %12.0g |  | 文件内部观测编号。 |
| `id` | str9 | %9s | ID | 汇算侧 ID。 |
| `cid` | str9 | %9s |  | 发票侧企业 ID。我们的回归面板 `firm_id` 应与该变量对接。 |

对应 Stata 输出位置：[`eid`](productivity/baidu_huisuan_describe.log:22)、[`id`](productivity/baidu_huisuan_describe.log:75)、[`cid`](productivity/baidu_huisuan_describe.log:76)。

## 5. 地区、注册和行业变量

| 变量名 | Storage type | Display format | Variable label | 中文说明 |
|---|---:|---:|---|---|
| `province` | str9 | %9s |  | 省份。 |
| `province_code` | float | %9.0g |  | 省份代码。 |
| `tax_period_start` | str10 | %10s | Tax Period Start Date | 纳税期开始日期。 |
| `tax_period_end` | str10 | %10s | Tax Period End Date | 纳税期结束日期。 |
| `region` | long | %12.0g | Region | 地区。 |
| `reg_type` | str3 | %9s | Registration Type | 登记注册类型。 |
| `econ_type_code` | int | %8.0g | Economic Type Code | 经济类型代码。 |
| `industry_code` | str4 | %9s | Industry Code | 行业代码。 |
| `industry_category` | str1 | %9s | Industry Category | 行业类别。 |
| `industry_major` | str2 | %9s | Industry Major Category | 行业大类。 |
| `industry_medium` | str3 | %9s | Industry Medium Category | 行业中类。 |
| `corp_tax_rate` | float | %9.0g | Corporate Tax Rate | 企业所得税税率。 |
| `levy_type` | str1 | %9s | Levy Type | 征收方式。 |

对应 Stata 输出位置：[`province`](productivity/baidu_huisuan_describe.log:26) 到 [`levy_type`](productivity/baidu_huisuan_describe.log:41)。

## 6. 汇算财务变量

| 变量名 | Storage type | Display format | Variable label | 中文说明 / 用途 |
|---|---:|---:|---|---|
| `employees` | double | %10.0g | Number of Employees | 从业人数。 |
| `operating_revenue` | double | %10.0g | Operating Revenue | 营业收入。 |
| `operating_cost` | double | %10.0g | Operating Cost | 营业成本。 |
| `operating_tax` | double | %10.0g | Operating Tax and Surcharge | 营业税金及附加。 |
| `sales_expense` | double | %10.0g | Sales Expense | 销售费用。 |
| `admin_expense` | double | %10.0g | Administrative Expense | 管理费用。 |
| `financial_expense` | float | %9.0g | Financial Expense | 财务费用。 |
| `asset_impairment` | double | %10.0g | Asset Impairment Loss | 资产减值损失。 |
| `fair_value_change` | double | %10.0g | Fair Value Change Gain/Loss | 公允价值变动收益/损失。 |
| `investment_income` | double | %10.0g | Investment Income | 投资收益。 |
| `operating_profit` | double | %10.0g | Operating Profit | 营业利润。 |
| `non_operating_income` | double | %10.0g | Non-Operating Income | 营业外收入。 |
| `non_operating_expense` | float | %9.0g | Non-Operating Expense | 营业外支出。 |
| `total_profit_loss` | double | %10.0g | Total Profit (Loss) | 利润总额。 |
| `tax_payable` | float | %9.0g | Tax Payable | 应纳税额。 |
| `actual_tax_payable` | float | %9.0g | Actual Tax Payable | 实际应纳税额。 |
| `net_profit` | double | %10.0g | Net Profit | 净利润。 |
| `b_class_revenue` | double | %10.0g | B Class Revenue | B 类收入。 |
| `b_class_cost` | float | %9.0g | B Class Cost | B 类成本。 |
| `b_class_expense` | float | %9.0g | B Class Expense | B 类费用。 |
| `total_assets` | double | %10.0g | Total Assets | 总资产。建议作为 `Capital` 来源。 |
| `total_reg_capital` | double | %10.0g | Total Registered Capital | 注册资本。 |

对应 Stata 输出位置：[`employees`](productivity/baidu_huisuan_describe.log:39) 到 [`total_reg_capital`](productivity/baidu_huisuan_describe.log:73)。

## 7. 对资本变量的判断

[`total_assets`](productivity/baidu_huisuan_describe.log:71) 是 `double` 类型，变量标签是 `Total Assets`。这比之前通过 `id` 再去 `H:\汇算数据\2017.dta` 匹配中文变量 `资产总额` 更直接。

因此，在 [`02_price_reg.do`](productivity/02_price_reg.do) 中构造 `ln_Capital` 时，可以考虑直接使用：

```stata
rename total_assets Capital
gen ln_Capital = ln(Capital) if Capital > 0 & !missing(Capital)
```

这会避免当前第二步 `id -> H:\汇算数据\2017.dta` 匹配造成的样本损失。

## 8. 建议的 Stata 匹配逻辑

建议把当前 [`02_price_reg.do`](productivity/02_price_reg.do) 中的两步资本匹配：

```stata
firm_id -> cid -> id -> H:\汇算数据\2017.dta -> 资产总额
```

改成直接使用 BaiduNetdisk 文件中的 `total_assets`：

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

## 9. 需要进一步核查的问题

虽然 [`describe`](productivity/baidu_huisuan_describe.log:12) 已经确认 `total_assets` 是 `double`，但正式替换回归代码前，仍建议检查以下内容：

1. `total_assets` 的非缺失数量；
2. `total_assets > 0` 的数量；
3. `cid` 的唯一数量；
4. 一个 `cid` 对应多条记录时，`total_assets` 是否一致；
5. 合并到当前回归面板后，`ln_Capital` 缺失数是否显著下降。

这些检查需要实际读取数据内容，而不仅是 [`describe`](productivity/baidu_huisuan_describe.log:12) 元数据。由于文件约 5.6GB，建议用 Stata 单独生成一个小的清洗后中间文件，再用于回归。