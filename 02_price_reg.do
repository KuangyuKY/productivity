* ==============================================================================
* 外包价格的决定因素 —— 主回归
*
* 输入（位于 G:\Kuangyu_Temp\Outsource\productivity\）:
*   invoice_panel.dta   firm × product × city × year，主面板，含 ln_p_net (DV)
*   market_conds.dta    product × city × year，市场条件 (buy-side + sell-side, 全城市口径)
*   firm_chars.dta      firm × year，企业规模、产品数、是否中介
*
* 桥接（路径固定，来自实验室共享数据）:
*   G:\Kuangyu_Temp\Outsource\productivity\cid_entid_unique.dta     cid → id 桥表
*   H:\汇算数据\2017.dta                                            id → Labor / Capital
*
* 输出（落在 regression\ 子目录）:
*   T1_baseline.txt       逐步加 FE 的基准
*   T2_demand_supply.txt  拆需求 / 供给侧
*   T3_interactions.txt   企业规模 × 市场条件 的异质性
*   T4_no_inter.txt       去掉中介企业 后的对照
*
* DV: ln_p_net  = log( (sum 开票金额) / sum 数量 )
* SE: 聚类到 firm 层
* ==============================================================================

clear all
set more off
set output proc
set max_memory ., permanently
set matsize 11000

cd "G:\Kuangyu_Temp\Outsource\productivity"

* --- 日志 & 输出目录 ---
capture mkdir "G:\Kuangyu_Temp\Outsource\productivity\regression"
log using "G:\Kuangyu_Temp\Outsource\productivity\02_price_reg.log", replace text

global REGOUT  "G:\Kuangyu_Temp\Outsource\productivity\regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* PART 1: 构造回归数据
* ==============================================================================

display ""
display "===== PART 1: 构造回归数据 ====="

use "invoice_panel.dta", clear

count
display "DV obs (firm × prod × city × year): " r(N)

* --- 合并市场条件（buy-side + sell-side，全城市口径，由 01_clean.ipynb 统一生成） ---
merge m:1 product_id city year using "market_conds.dta", keep(master match) nogen
count
display "after merging market_conds: " r(N)

* --- 合并企业特征 ---
merge m:1 firm_id year using "firm_chars.dta", keep(master match) nogen
count
display "after merging firm_chars: " r(N)

* --- 桥接汇算数据：firm_id (str) → cid (long) → id → Labor / Capital ---
* 先按 merge汇算_2.do 的旧做法处理汇算数据：同一个 id-year 只保留第一条。
* 这样避免直接 merge m:1 id using "H:\汇算数据\2017.dta" 时，using 端 id 不唯一而报错。
preserve
    use "H:\汇算数据\2017.dta", clear
    gen year = 2017
    bysort id year: gen rep_no = _n
    drop if rep_no > 1
    drop rep_no
    keep id 从业人数 资产总额
    save "huisuan_2017_keepfirst_by_id.dta", replace
restore

destring firm_id, gen(cid) force
merge m:1 cid using ///
    "G:\Kuangyu_Temp\Outsource\productivity\cid_entid_unique.dta", ///
    keepusing(id) keep(master match) nogen
merge m:1 id using "huisuan_2017_keepfirst_by_id.dta", ///
    keepusing(从业人数 资产总额) keep(master match) nogen
rename (从业人数 资产总额) (Labor Capital)
gen ln_Labor   = ln(Labor)   if Labor   > 0 & !missing(Labor)
gen ln_Capital = ln(Capital) if Capital > 0 & !missing(Capital)
count
display "after merging 汇算 (Labor/Capital): " r(N)
count if missing(ln_Labor)
display "missing ln_Labor: " r(N)
count if missing(ln_Capital)
display "missing ln_Capital: " r(N)

* --- 缺失诊断 ---
count if missing(ln_firm_output)
display "missing ln_firm_output: " r(N)
count if missing(ln_p_mkt)
display "missing ln_p_mkt: " r(N)
count if missing(ln_mkt_qty)
display "missing ln_mkt_qty: " r(N)
count if missing(ln_n_buyers)
display "missing ln_n_buyers: " r(N)
count if missing(ln_n_sellers)
display "missing ln_n_sellers: " r(N)

* --- 数值化 ID 给 reghdfe ---
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)
gegen city_n = group(city)
gegen prodyear_n = group(product_id year)

display ""
display "============================================="
display "回归数据 final"
display "============================================="
count
gdistinct firm_n
gdistinct prod_n
gdistinct city_n

* --- 摘要 ---
summarize ln_p_net ln_firm_output n_products ln_Labor ln_Capital ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt

compress
save "reg_panel.dta", replace


* ==============================================================================
* TABLE 1: Baseline —— 逐步加 FE
*
* 模型：  ln_p_ipct = β X_it + γ Z_pct + FE + ε
*   X_it: ln_firm_output, n_products
*   Z_pct: ln_n_buyers, ln_n_sellers, ln_mkt_qty, ln_p_mkt
* ==============================================================================

display ""
display "===== TABLE 1: Baseline ====="

use "reg_panel.dta", clear

* --- (1) OLS：只放企业控制 ---
reg ln_p_net ln_firm_output n_products, vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
estadd local mkt_ctl "No",  replace
est store m1

* --- (2) OLS + 市场条件 ---
reg ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
estadd local mkt_ctl "Yes", replace
est store m2

* --- (3) + firm FE ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
estadd local mkt_ctl "Yes", replace
est store m3

* --- (4) + firm + product FE ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
estadd local mkt_ctl "Yes", replace
est store m4

* --- (5) + firm + product + city FE ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
estadd local mkt_ctl "Yes", replace
est store m5

* --- (6) + firm + product × year FE ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prodyear_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes",     replace
estadd local prod_fe "Prod×Yr", replace
estadd local city_fe "Yes",     replace
estadd local mkt_ctl "Yes",     replace
est store m6

esttab m1 m2 m3 m4 m5 m6 ///
    using "$REGOUT/T1_baseline.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe mkt_ctl N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Market controls" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Baseline with progressive FE.") ///
    mtitles("OLS-bare" "OLS-full" "+Firm" "+Firm+Prod" "+Firm+Prod+City" "+Firm+PrYr+City")
display "T1 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT  "G:\Kuangyu_Temp\Outsource\productivity\regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 2: 需求侧 vs 供给侧拆分
* ==============================================================================

display ""
display "===== TABLE 2: Demand vs Supply ====="

use "reg_panel.dta", clear

* --- (1) 只放需求侧 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Demand", replace
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store d1

* --- (2) 只放供给侧 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_sellers, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Supply", replace
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store d2

* --- (3) 需 + 供 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty ln_n_sellers, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Both", replace
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store d3

* --- (4) 需 + 供 + 市场均价 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Both+P",  replace
estadd local firm_fe "Yes",  replace
estadd local prod_fe "Yes",  replace
estadd local city_fe "Yes",  replace
est store d4

esttab d1 d2 d3 d4 ///
    using "$REGOUT/T2_demand_supply.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt ///
          ln_firm_output n_products) ///
    stats(side firm_fe prod_fe city_fe N r2_a, ///
          labels("Specification" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Demand vs Supply decomposition.") ///
    mtitles("Demand" "Supply" "Both" "Both+Pmkt")
display "T2 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT  "G:\Kuangyu_Temp\Outsource\productivity\regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 3: 企业规模 × 市场条件 的交互
* ==============================================================================

display ""
display "===== TABLE 3: Interactions ====="

use "reg_panel.dta", clear

gen size_x_nbuy   = ln_firm_output * ln_n_buyers
gen size_x_nsell  = ln_firm_output * ln_n_sellers
gen size_x_pmkt   = ln_firm_output * ln_p_mkt
gen size_x_mktqty = ln_firm_output * ln_mkt_qty

* --- (1) baseline ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i1

* --- (2) + size × n_buyers ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i2

* --- (3) + size × n_sellers ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nsell, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i3

* --- (4) + size × p_mkt ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_pmkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i4

* --- (5) 全部交互 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i5

esttab i1 i2 i3 i4 i5 ///
    using "$REGOUT/T3_interactions.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-size × market interactions.") ///
    mtitles("Baseline" "+Size×Nbuy" "+Size×Nsell" "+Size×Pmkt" "All")
display "T3 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT  "G:\Kuangyu_Temp\Outsource\productivity\regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 4: 去掉中介企业 后的稳健性
* ==============================================================================

display ""
display "===== TABLE 4: No Intermediaries ====="

use "reg_panel.dta", clear
drop if is_intermediary == 1

count
display "obs after dropping intermediaries: " r(N)

* (1) 含中介（参照）
preserve
use "reg_panel.dta", clear
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "All",  replace
estadd local firm_fe "Yes",  replace
estadd local prod_fe "Yes",  replace
estadd local city_fe "Yes",  replace
est store r1
restore

* (2) 去中介，firm+prod+city FE
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "No-Inter", replace
estadd local firm_fe "Yes",     replace
estadd local prod_fe "Yes",     replace
estadd local city_fe "Yes",     replace
est store r2

* (3) 去中介，需供拆分
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "No-Inter", replace
estadd local firm_fe "Yes",     replace
estadd local prod_fe "Yes",     replace
estadd local city_fe "Yes",     replace
est store r3

esttab r1 r2 r3 ///
    using "$REGOUT/T4_no_inter.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(sample firm_fe prod_fe city_fe N r2_a, ///
          labels("Sample" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Robustness to dropping intermediaries.") ///
    mtitles("All firms" "Drop inter" "Drop inter (D+S)")
display "T4 saved."
est clear


display ""
display "============================================="
display "All four tables saved to: $REGOUT"
display "  T1_baseline.txt"
display "  T2_demand_supply.txt"
display "  T3_interactions.txt"
display "  T4_no_inter.txt"
display "============================================="

log close
