# 汇算数据与发票数据合并说明

## 1. 文件来源

本说明基于以下文件和目录整理：

- 发票与汇算合并脚本：`E:\HZhang_Xing\code\datamerge\merge汇算_2.do`
- 汇算数据目录：`H:\汇算数据`
- 2017 年汇算主文件：`H:\汇算数据\2017.dta`
- 汇算数据处理脚本：`H:\汇算数据\deal.do`、`H:\汇算数据\deal_new.do`

## 2. 汇算数据的大致情况

`H:\汇算数据` 下有 2014--2018 年汇算数据：

| 文件 | 大小 | 修改时间 |
|---|---:|---|
| `2014.dta` | 2.87 GB | 2024-10-27 |
| `2015.dta` | 2.91 GB | 2024-10-27 |
| `2016.dta` | 6.80 GB | 2024-10-27 |
| `2017.dta` | 4.06 GB | 2024-10-27 |
| `2018.dta` | 11.27 GB | 2024-10-27 |

其中，本次原脚本实际使用的是：

```stata
use "H:\汇算数据\2017.dta", clear
```

对 `2017.dta` 的文件头读取结果显示：

- Stata 数据版本：release 118
- 观测数：17,504,177
- 变量数：35
- 文件时间戳：20 Jun 2024 20:53

### 2.1 `2017.dta` 的变量列表

`2017.dta` 包含以下变量：

1. 税款所属期起
2. 税款所属期止
3. 所在区域
4. 登记注册类型代码经济类型性质
5. 经济类型代码
6. 行业代码
7. 经济行业门类
8. 经济行业大类
9. 经济行业中类
10. 从业人数
11. 企业所得税适用税率
12. 征收类型
13. 营业收入
14. 营业成本
15. 营业税金及附加信息
16. 销售费用
17. 管理费用
18. 财务费用
19. 资产减值损失
20. 公允价值变动收益
21. 投资收益
22. 营业利润
23. 营业外收入
24. 营业外支出
25. 利润亏损总额
26. 应纳税额
27. 实际应纳所得税额
28. 净利润
29. b收入总额
30. b成本费用
31. b经费支出
32. 资产总额
33. 注册资本总额
34. eid
35. id

这些变量说明，汇算数据主要是企业所得税汇算清缴相关的企业财务、行业、地区和身份信息。原合并脚本主要从中使用以下变量：

```stata
所在区域 行业代码 从业人数 净利润 b收入总额 资产总额
```

并重命名为：

```stata
county industry Labor Profit_Huisuan Revenue_Huisuan Expend_Capital
```

含义大致为：

| 汇算原变量 | 合并后变量名 | 用途 |
|---|---|---|
| 所在区域 | county | 地区固定效应或地区控制 |
| 行业代码 | industry | 行业固定效应或行业控制 |
| 从业人数 | Labor | 劳动力投入、劳动生产率分母 |
| 净利润 | Profit_Huisuan | 利润、利润率 |
| b收入总额 | Revenue_Huisuan | 汇算口径收入 |
| 资产总额 | Expend_Capital | 资本或资产规模代理变量 |

## 3. 汇算数据自身的预处理线索

`H:\汇算数据\deal.do` 显示，汇算数据曾与地址或注册信息做过匹配。核心思路是：

1. 对每年汇算数据保留企业身份字段 `eid`。
2. 用 `eid` 与地址库 `eid_address.dta` 合并。
3. 删除只在地址库中出现、但不在汇算主数据中的记录。
4. 清理地址字符串，例如去空格、去换行。
5. 后续似乎通过外部 CSV 或地址匹配结果生成企业地址或注册信息匹配结果。

`deal.do` 中记录的 2017 年匹配情况大致为：

- 2017 年汇算数据与地址数据匹配后，matched 记录约 17,118,031 条。
- 匹配率约 97.79%。
- 后续将 2017 年地址匹配结果分块导入后，非缺失 `company_id` 的记录约 2,420,029 条。
- 按 `id` 去重后，约 1,794,261 条。

这说明 `id` 很可能是经过某种企业身份桥接或地址匹配后生成的连接编号，用于把汇算数据和发票侧企业实体编号连接起来。

`H:\汇算数据\deal_new.do` 还显示，汇算数据也曾尝试与 2018 年注册数据中的 `主体身份代码` 逐省合并：

```stata
ren eid 主体身份代码
recast str255 主体身份代码, force
merge m:1 主体身份代码 using "H:\注册-2018\各省基本信息_按拼音排序\..."
```

因此，汇算数据本身既有 `eid`，也有后续桥接出来的 `id`。在 `merge汇算_2.do` 中，真正用于和发票样本合并的是 `id`，不是 `eid`。

## 4. 原脚本中的发票数据整理流程

`merge汇算_2.do` 在接汇算数据之前，先构造了一个发票侧的企业样本。

### 4.1 构造销售端产出数据

脚本先读取 2017 年和 2018 年销项发票汇总文件。2017 年包括：

```stata
E:\HZhang_Xing\data\GX1701_Seller.csv
E:\HZhang_Xing\data\GX1702_Seller.csv
E:\HZhang_Xing\data\GX1703_Seller.csv
```

主要处理方式：

1. 把销方企业 ID 改名为 `cid`。
2. 把销方地区改名为 `city_sell`。
3. 把单价改名为 `price_sell`。
4. 保留或生成销售额 `totalvalue_sell`。
5. 构造加权价格项：

```stata
gen price_weighted = price_sell * totalvalue_sell
```

6. 对企业层面 collapse：

```stata
collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)
```

7. 后续按 `cid year` 汇总，并构造：

```stata
gen Pindex_output = price_weighted / totalvalue_sell
gen Qindex_output = totalvalue_sell / Pindex_output
rename totalvalue_sell Revenue
```

所以，发票销售端形成的核心变量是：

| 变量 | 含义 |
|---|---|
| `Revenue` | 发票销售收入 |
| `Pindex_output` | 产出价格指数或加权产出价格 |
| `Qindex_output` | 产出数量指数，等于销售额除以价格指数 |

注意：脚本中 2017 年 seller append 部分看起来把 `GX1702` 和 `GX1703` 对应的中间文件 append 了两次。相关逻辑需要后续核对是否是笔误。

### 4.2 构造采购端材料投入数据

脚本读取材料投入发票文件，例如：

```stata
E:\HZhang_Xing\data\GX1701_Expend_Material.csv
E:\HZhang_Xing\data\GX1702_Expend_Material.csv
E:\HZhang_Xing\data\GX1703_Expend_Material.csv
```

主要处理方式：

1. 把购方企业 ID 改名为 `cid`。
2. 生成年份变量 `year`。
3. append 2017 和 2018 年材料投入数据。
4. 按企业年份汇总：

```stata
collapse (sum) weightedprice_material expend_material, by(cid year)
```

5. 构造材料投入价格和数量指标：

```stata
gen Pindex_material = weightedprice_material / expend_material
gen Qindex_material = expend_material / Pindex_material
rename expend_material Expend_Material
```

形成的核心变量是：

| 变量 | 含义 |
|---|---|
| `Expend_Material` | 材料投入支出 |
| `Pindex_material` | 材料投入价格指数 |
| `Qindex_material` | 材料投入数量指数 |

### 4.3 合并销售端和材料投入端

脚本用企业年份合并销售端和材料投入端：

```stata
use "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_20172018.dta", clear
merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInfo_20172018.dta"
keep if _merge == 3
drop _merge
save "E:\HZhang_Xing\data\SellExpendMInfo_20172018.dta", replace
```

这里保留的是同时有销售产出和材料采购投入的企业年份。

### 4.4 合并服务投入数据

之后脚本读取服务投入数据：

```stata
use "E:\HZhang_Xing\data\merged_parquet\csv_2017\Buyer_InvoiceService_2017.dta", clear
```

处理方式：

1. 将 `firmid_Invoice_Buyer` 转为数值型 `cid`。
2. 删除原企业 ID 字符串和服务投入份额变量。
3. 将服务投入细分类重命名：

```stata
rename(invoicevalue_p invoicevalue_r invoicevalue_d invoicevalue_o) ///
      (Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O)
```

4. 与销售和材料投入数据按 `cid year` 合并：

```stata
merge 1:1 cid year using "E:\HZhang_Xing\data\SellExpendMInfo_20172018.dta"
keep if _merge == 3
```

5. 构造总服务投入：

```stata
gen Expend_Service = Expend_Service_P + Expend_Service_R + Expend_Service_D + Expend_Service_O
```

脚本注释说明：

- `Expend_Service_O` 包含 Production、R&D-Technology、Demand 之外的服务业以及“无形资产”等。
- `Expend_Material` 里包含“货物”“不动产”“其他不动产”等，后续如果要更严格地区分货物投入，需要重新生成只包含“货物”的投入数据。

### 4.5 合并企业实体编号

脚本使用企业 ID 桥表：

```stata
merge 1:1 cid using "E:\HZhang_Xing\data\merged_parquet\csv_2017\cid_entid_unique.dta"
keep if _merge == 3
drop _merge
```

之后按 `entid year` 去重：

```stata
sort entid year cid
bysort entid year: gen rep_no = _n
drop if rep_no > 1
drop rep_no
```

这一步的作用是把发票企业 ID `cid` 连接到统一企业实体编号 `entid`，并保证每个实体年份只保留一条记录。

发票侧最终保存为：

```stata
save "E:\HZhang_Xing\data\InvoiceSellData\SellBuyInfo_Entyid_2017.dta", replace
```

## 5. 与汇算数据的合并办法

原脚本中汇算数据合并部分如下：

```stata
use "H:\汇算数据\2017.dta", clear
gen year = 2017
bysort id year: gen rep_no = _n
drop if rep_no > 1
drop rep_no
merge 1:1 id using "E:\HZhang_Xing\data\InvoiceSellData\SellBuyInfo_Entyid_2017.dta"
keep if _merge == 3
drop _merge
rename (所在区域 行业代码 从业人数 净利润 b收入总额 资产总额) ///
       (county industry Labor Profit_Huisuan Revenue_Huisuan Expend_Capital)
```

这个流程可以概括为：

1. 以汇算数据为 master。
2. 给汇算数据加上年份 `year = 2017`。
3. 对 `id year` 去重，只保留第一条。
4. 用 `id` 与发票侧的 `SellBuyInfo_Entyid_2017.dta` 做一对一合并。
5. 只保留汇算和发票两边都存在的企业。
6. 将汇算中的地区、行业、就业、利润、收入和资产变量重命名，接入最终样本。

合并后的样本保存为：

```stata
save "E:\HZhang_Xing\data\sample\SellBuyInfo_Entyid_2017.dta", replace
```

## 6. 合并后样本中的主要变量

原脚本合并后进行了如下排序：

```stata
order entid year company_name county industry Revenue Revenue_Huisuan ///
      Profit_Huisuan Pindex_output Qindex_output Labor Expend_Capital ///
      Expend_Material Expend_Service Expend_Service_P Expend_Service_R ///
      Expend_Service_D Expend_Service_O
```

因此，最终样本大致包括三类变量：

### 6.1 发票产出变量

| 变量 | 来源 | 含义 |
|---|---|---|
| `Revenue` | 销项发票 | 发票口径销售收入 |
| `Pindex_output` | 销项发票 | 产出价格指数 |
| `Qindex_output` | 销项发票 | 产出数量指数 |

### 6.2 发票投入变量

| 变量 | 来源 | 含义 |
|---|---|---|
| `Expend_Material` | 进项发票 | 材料投入支出 |
| `Pindex_material` | 进项发票 | 材料投入价格指数 |
| `Qindex_material` | 进项发票 | 材料投入数量指数 |
| `Expend_Service` | 服务投入发票分类 | 总服务投入 |
| `Expend_Service_P` | 服务投入发票分类 | Production 类服务投入 |
| `Expend_Service_R` | 服务投入发票分类 | R&D / Technology 类服务投入 |
| `Expend_Service_D` | 服务投入发票分类 | Demand 类服务投入 |
| `Expend_Service_O` | 服务投入发票分类 | 其他服务投入 |

### 6.3 汇算变量

| 变量 | 来源 | 含义 |
|---|---|---|
| `county` | 汇算 `所在区域` | 企业所在区域 |
| `industry` | 汇算 `行业代码` | 行业代码 |
| `Labor` | 汇算 `从业人数` | 从业人数 |
| `Profit_Huisuan` | 汇算 `净利润` | 净利润 |
| `Revenue_Huisuan` | 汇算 `b收入总额` | 汇算口径收入总额 |
| `Expend_Capital` | 汇算 `资产总额` | 资产总额，作为资本规模代理 |

## 7. 后续分析中如何使用汇算变量

合并后脚本构造了若干分析变量：

```stata
gen Profitrate = Profit_Huisuan / Revenue_Huisuan
gen ln_Profitrate = ln(Profitrate)

gen Productivity_L = Qindex_output / Labor
gen ln_Productivity_L = ln(Productivity_L)

gen Rawmarkup_M = Revenue / Expend_Material
gen ln_Rawmarkup_M = ln(Rawmarkup_M)
```

其中：

- `Profitrate` 使用汇算利润和汇算收入构造。
- `Productivity_L` 使用发票产出数量指数除以汇算从业人数。
- `Rawmarkup_M` 使用发票收入除以发票材料投入。

因此，汇算数据在这个脚本中的核心作用是补充企业的：

1. 劳动力投入。
2. 行业代码。
3. 地区代码。
4. 利润。
5. 汇算口径收入。
6. 资产总额。

## 8. 对当前项目的启示

如果当前 outsourcing price 项目需要企业层面的规模、劳动、行业、资产、利润等控制变量，`H:\汇算数据\2017.dta` 是一个可用来源。

但需要注意两个关键点：

1. 原脚本不是直接用发票企业 ID `cid` 合并汇算数据，而是通过桥接后的 `id` 合并。
2. 必须确认当前项目中的样本企业 ID 能否连接到汇算数据中的 `id` 或 `eid`。

如果当前项目只有 VAT 发票里的 `cid`，则需要找到或重建类似下面这个桥表：

```stata
E:\HZhang_Xing\data\merged_parquet\csv_2017\cid_entid_unique.dta
```

或者使用已有的企业身份映射，把 VAT 企业 ID 转换到汇算数据可识别的 `id` / `eid`。

## 9. 需要核对的问题

1. `merge汇算_2.do` 中 seller 端 2017 年 append 逻辑似乎重复 append 了 201702 和 201703 的中间文件，需要确认是否为笔误。
2. 汇算合并使用的是 `id`，但 `id` 的具体生成过程需要进一步确认；它可能来自地址匹配或企业身份桥接。
3. 如果要在当前项目中复用汇算变量，需要确认当前 3,410 家样本企业是否已有 `cid -> id` 或 `cid -> eid` 的桥接关系。
4. `Expend_Material` 的定义在原脚本注释中并不完全等同于“货物投入”，可能还包含不动产等类别；如果当前研究对投入类别要求严格，需要重新限定项目类别。
