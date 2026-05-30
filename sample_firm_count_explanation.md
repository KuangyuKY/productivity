# 外包样本企业数变化说明

本文说明为什么样本企业数会从 3,410 家，先变成 3,376 家，再变成 2,108 家，最后在回归面板中变成 1,875 家。诊断依据来自 [`check_invoice_panel_firm_drop_stata.do`](../check_invoice_panel_firm_drop_stata.do) 及其日志 [`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log)。

## 1. 核心结论

当前样本变化是正常的，主要原因是外包产品的定义较严格。

我们最终的外包采购价格面板不是所有有采购记录的企业，而是要求：同一企业、同一产品，在 2017 年内同时出现在采购端和销售端。

也就是说，只有满足以下条件的 firm-product 才进入 [`invoice_panel.dta`](../invoice_panel.dta)：

```text
企业 f 采购产品 j
并且
企业 f 销售产品 j
```

因此，3,376 家企业并不是最终外包面板企业数，而是“采购端有合法 9 位产品码的企业数”。真正进入外包采购价格面板的企业数是 2,108 家。

## 2. 企业数变化链条

| 阶段 | 行数 | 企业数 | 含义 |
|---|---:|---:|---|
| 原始样本企业 | 3,410 | 3,410 | 来自 [`firm_city.csv`](../firm_city.csv) |
| 原始采购记录 | 473,268 | 3,410 | 来自 [`firm_buy.csv`](../firm_buy.csv) |
| 采购记录清洗后 | 441,318 | 3,383 | 删除金额、数量、项目代码异常记录 |
| 采购记录匹配合法 9 位产品码后 | 425,713 | 3,376 | 这一步对应之前看到的 3,376 家 |
| 采购端 firm-product 聚合后 | 403,400 | 3,376 | 这不是最终外包面板，只是采购端产品面板 |
| 销售端 firm-product 聚合后 | 84,870 | 2,711 | 有合法销售产品的企业数 |
| 采购端与销售端按 firm-product 取交集后 | 59,445 | 2,108 | 同一企业同一产品既买又卖，定义为外包产品 |
| 最终 [`invoice_panel.dta`](../invoice_panel.dta) | 59,445 | 2,108 | [`01_clean.ipynb`](01_clean.ipynb) 生成的主外包采购价格面板 |
| 最终 [`reg_panel.dta`](../reg_panel.dta) | 46,945 | 1,875 | [`02_price_reg.do`](02_price_reg.do:66) 删除中介企业后得到 |

## 3. 为什么之前会看到 3,376 家？

之前在 [`01_clean.ipynb`](01_clean.ipynb:298) 里看到：

```text
invoice_panel rows: 403400
unique firms:    3376
```

这个数实际对应的是采购端合法产品码之后的 firm-product 聚合规模，即采购端面板。它还没有经过“同一企业同一产品既买又卖”的外包产品交集筛选。

诊断日志中对应结果为：

- 采购端匹配合法 9 位产品码后：3,376 家企业；见 [`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log:216)。
- 采购端 firm-product 聚合后：403,400 行、3,376 家企业；见 [`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log:226)。

所以，3,376 家不是最终外包样本企业数，而是采购端有合法产品码的企业数。

## 4. 为什么最终外包面板是 2,108 家？

外包产品定义要求同一企业同一产品同时出现在采购端和销售端。诊断结果显示：

- 采购端 firm-product 聚合后：403,400 行、3,376 家企业。
- 销售端 firm-product 聚合后：84,870 行、2,711 家企业。
- 两者按 firm_id 和 product_id 取交集后：59,445 行、2,108 家企业。

对应日志位置：

- 销售端 firm-product 聚合：[`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log:361)。
- 买卖同产品交集：[`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log:390)。
- 交集后企业数 2,108：[`check_invoice_panel_firm_drop_stata_latest2.log`](../check_invoice_panel_firm_drop_stata_latest2.log:409)。

因此，从 3,376 家下降到 2,108 家，是外包产品定义造成的，不是数据错误。

## 5. 为什么回归面板是 1,875 家？

[`02_price_reg.do`](02_price_reg.do:53) 先读取 [`invoice_panel.dta`](../invoice_panel.dta)，再合并 [`market_conds.dta`](../market_conds.dta) 和 [`firm_chars.dta`](../firm_chars.dta)，然后执行删除中介企业的语句：[`drop if is_intermediary == 1`](02_price_reg.do:66)。

删除中介企业后：

| 阶段 | 行数 | 企业数 |
|---|---:|---:|
| 删除中介前的 [`invoice_panel.dta`](../invoice_panel.dta) | 59,445 | 2,108 |
| 中介企业观测 | 12,500 | 233 |
| 删除中介后的 [`reg_panel.dta`](../reg_panel.dta) | 46,945 | 1,875 |

也就是说：

```text
2,108 家外包样本企业
- 233 家中介企业
= 1,875 家最终回归企业
```

## 6. 当前判断

当前数据逻辑是自洽的：

1. [`01_clean.ipynb`](01_clean.ipynb) 生成的外包采购价格面板是 [`invoice_panel.dta`](../invoice_panel.dta)。
2. [`invoice_panel.dta`](../invoice_panel.dta) 的 2,108 家企业是外包定义筛选后的结果。
3. [`02_price_reg.do`](02_price_reg.do:66) 进一步删除中介企业，得到 1,875 家企业的 [`reg_panel.dta`](../reg_panel.dta)。
4. 之前的 3,376 家企业应理解为采购端有合法产品码的企业数，不应理解为最终外包价格面板企业数。
