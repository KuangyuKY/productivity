* ==============================================================================
* 外包价格的决定因素 —— 主回归
*
* 输入（位于 G:\Kuangyu_Temp\Outsource\productivity\）:
*   invoice_panel.dta          firm × product × city × year，主面板，含 ln_p_net (DV)
*   market_conds.dta           product × city × year，旧市场条件；这里主要保留 seller-side 变量
*   market_conds_buy_full.dta  product × city × year，全城市 purchase-side market condition
*   firm_chars.dta             firm × year，企业规模、产品数、是否中介
*
* 输出 (4 张表，落在同目录下):
*   T1_baseline.txt     逐步加 FE 的基准
*   T2_demand_supply.txt   拆需求 / 供给侧
*   T3_interactions.txt  企业规模 × 市场条件 的异质性
*   T4_no_inter.txt     去掉中介企业 后的对照
*
* DV: ln_p_net  = log( (sum 开票金额 − sum 税额) / sum 数量 )
* SE: 聚类到 firm 层
* ==============================================================================

clear all
set more off
set max_memory ., permanently
set matsize 11000

cd "G:\Kuangyu_Temp\Outsource\productivity"

global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* PART 1: 构造回归数据
* ==============================================================================

use "invoice_panel.dta", clear

count
display "DV obs (firm × prod × city × year): " r(N)

* --- 兼容旧版 invoice_panel：如果主面板里有 firm 自己的供应商数，则改名避免和 market_conds 撞名 ---
capture confirm variable n_sellers
if !_rc {
    rename n_sellers n_sellers_firm
}

* --- 合并旧市场条件 ---
* 旧 market_conds.dta 的 purchase-side 变量来自样本内城市聚合，不再作为主 market condition。
* 这里先合并旧文件，主要保留 ln_n_sellers 等 seller-side 变量。
merge m:1 product_id city year using "market_conds.dta", keep(master match) nogen
count
display "after merging old market_conds: " r(N)

* --- 将旧 purchase-side 变量改名为备份变量，避免和全城市口径冲突 ---
foreach v in mkt_value mkt_qty p_mkt ln_p_mkt ln_mkt_qty n_buyers ln_n_buyers {
    capture confirm variable `v'
    if !_rc {
        rename `v' sample_`v'
    }
}

* --- 合并全城市 purchase-side market condition ---
* 这些变量来自 city.csv -> clean_city.ipynb -> market_conds_buy_full.dta。
* 后续回归中的 ln_n_buyers、ln_mkt_qty、ln_p_mkt 均使用这个全城市口径。
merge m:1 product_id city year using "market_conds_buy_full.dta", keep(master match) nogen
count
display "after merging full-city purchase market conditions: " r(N)

* --- 合并企业特征 ---
merge m:1 firm_id year using "firm_chars.dta", keep(master match) nogen
count
display "after merging firm_chars: " r(N)

* --- 缺失诊断 ---
count if missing(ln_firm_output)
display "missing ln_firm_output: " r(N)
count if missing(ln_p_mkt)
display "missing full-city ln_p_mkt: " r(N)
count if missing(ln_mkt_qty)
display "missing full-city ln_mkt_qty: " r(N)
count if missing(ln_n_buyers)
display "missing full-city ln_n_buyers: " r(N)
count if missing(ln_n_sellers)
display "missing seller-side ln_n_sellers: " r(N)


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
summarize ln_p_net ln_firm_output n_products ///
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

use "reg_panel.dta", clear

* --- (1) OLS：只放 similarity-type 控制（这里没有 similarity，只放 firm + market） ---
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

* --- (6) + firm + product × year FE （2018 数据齐全后启用，目前等价于 m4） ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prodyear_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes",     replace
estadd local prod_fe "Prod×Yr", replace
estadd local city_fe "Yes",     replace
estadd local mkt_ctl "Yes",     replace
est store m6

esttab m1 m2 m3 m4 m5 m6 ///
    using "T1_baseline.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe mkt_ctl N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Market controls" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Baseline with progressive FE.") ///
    mtitles("OLS-bare" "OLS-full" "+Firm" "+Firm+Prod" "+Firm+Prod+City" "+Firm+PrYr+City")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 2: 需求侧 vs 供给侧拆分
*
* 在严格 FE 下 (firm + product + city)，分别只放 demand / supply / both，
* 看 n_buyers (需求宽度) 和 n_sellers (供给宽度) 单独和联合的影响。
* ==============================================================================

use "reg_panel.dta", clear

* --- (1) 只放需求侧：n_buyers + 总采购量 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Demand", replace
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store d1

* --- (2) 只放供给侧：n_sellers ---
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
estadd local side "Both",   replace
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store d3

* --- (4) 需 + 供 + 市场均价（控制市场综合水平） ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side "Both+P",  replace
estadd local firm_fe "Yes",  replace
estadd local prod_fe "Yes",  replace
estadd local city_fe "Yes",  replace
est store d4

esttab d1 d2 d3 d4 ///
    using "T2_demand_supply.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt ///
          ln_firm_output n_products) ///
    stats(side firm_fe prod_fe city_fe N r2_a, ///
          labels("Specification" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Demand vs Supply decomposition.") ///
    mtitles("Demand" "Supply" "Both" "Both+Pmkt")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 3: 企业规模 × 市场条件 的交互
*
* 检验：大企业是否更能从买家多 / 卖家多 / 市场均价高 中获益（拿到更低价）
* ==============================================================================

use "reg_panel.dta", clear

gen size_x_nbuy   = ln_firm_output * ln_n_buyers
gen size_x_nsell  = ln_firm_output * ln_n_sellers
gen size_x_pmkt   = ln_firm_output * ln_p_mkt
gen size_x_mktqty = ln_firm_output * ln_mkt_qty

* --- (1) baseline (来自表 1 col 5) ---
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

* --- (5) 全部交互一起 ---
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i5

esttab i1 i2 i3 i4 i5 ///
    using "T3_interactions.txt", replace ///
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
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 4: 去掉中介企业 (is_intermediary == 1) 后的稳健性
*
* 中介企业 >90% 业务为外包，可能不反映真正的"生产型企业"的外包价格行为。
* ==============================================================================

use "reg_panel.dta", clear
drop if is_intermediary == 1

count
display "obs after dropping intermediaries: " r(N)

* --- 复制表 1 的 col 4 / 5 / 6 ---

* (1) 含中介（参照）—— 先把中介加回来跑一次
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
    using "T4_no_inter.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(sample firm_fe prod_fe city_fe N r2_a, ///
          labels("Sample" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Robustness to dropping intermediaries.") ///
    mtitles("All firms" "Drop inter" "Drop inter (D+S)")
est clear


display ""
display "============================================="
display "All four tables saved:"
display "  T1_baseline.txt"
display "  T2_demand_supply.txt"
display "  T3_interactions.txt"
display "  T4_no_inter.txt"
display "============================================="
