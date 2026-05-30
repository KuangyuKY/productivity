* ==============================================================================
* 外包价格的决定因素 —— 主回归
*
* 变量分三类：
*   企业层面   (x)  : ln_firm_output, ln_Capital, n_products
*                     单年截面下被 Firm FE 完全吸收，仅 OLS 规格可识别
*   市场层面   (z)  : ln_n_buyers, ln_n_sellers, ln_mkt_qty, ln_p_mkt
*                     在 product×city 层面变化，FE 规格下可识别
*   产品相似性 (s)  : input_similarity (S_mj), output_similarity (C_mj)
*                     在 firm×product 层面变化，FE 规格下可识别
*
* 表格结构（每张表均先 OLS、最后列加 FE）：
*   T1  仅企业层面                       OLS | +Firm FE
*   T2  企业层面 + 产品相似性            OLS | +FirmFE | +Firm+Prod | +All FE
*   T3  仅市场层面                       OLS | +FirmFE | +Firm+Prod | +All FE
*   T4  企业层面 + 市场层面              OLS | +FirmFE | +Firm+Prod | +All FE
*   T5  企业层面 + 产品相似性 + 市场层面 OLS | +FirmFE | +Firm+Prod | +All FE
*   T6  交互项（企业规模 × 市场条件）    全 FE，逐步加入各交互项
*
* 输入（虚拟机 G:\Kuangyu_Temp\Outsource\productivity\）:
*   invoice_panel.dta     主面板，由 01_clean.ipynb 生成
*   market_conds.dta      product × city 市场条件
*   firm_chars.dta        firm × year 企业特征（含 Capital / ln_Capital）
*   G:\Kuangyu_Temp\Outsource\full_data.dta   → input/output_similarity
*
* 样本：去掉中介企业（is_intermediary == 1，外包比例 > 90%）
*   所有表格均使用同一 reg_panel.dta，样本在 PART 1 一次性过滤
*
* SE：聚类到 firm 层
* ==============================================================================

clear all
set more off
set output proc
set max_memory ., permanently
set matsize 11000

cd "G:\Kuangyu_Temp\Outsource\productivity"
capture mkdir "regression"
log using "regression\02_price_reg.log", replace text

global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* PART 1: 构造回归数据
* ==============================================================================

display ""
display "===== PART 1: 构造回归数据 ====="

use "invoice_panel.dta", clear
count
display "主面板观测数 (firm × prod × city × year): " r(N)

merge m:1 product_id city year using "market_conds.dta", keep(master match) nogen
count
display "after market_conds merge: " r(N)

merge m:1 firm_id year using "firm_chars.dta", keep(master match) nogen
count
display "after firm_chars merge: " r(N)

* --- 去掉中介企业 ---
drop if is_intermediary == 1
count
display "after dropping intermediaries: " r(N)

* --- 合并产品相似度 ---
preserve
    use "G:\Kuangyu_Temp\Outsource\full_data.dta", clear
    keep firm_id year product_id input_similarity output_similarity
    duplicates drop firm_id year product_id, force
    save "sim_temp.dta", replace
restore

merge m:1 firm_id product_id year using "sim_temp.dta", ///
    keepusing(input_similarity output_similarity) keep(master match) nogen
erase "sim_temp.dta"

* --- 数值 ID（供 reghdfe 使用）---
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)
gegen city_n = group(city)

display ""
display "==== 关键变量缺失统计 ===="
foreach v in ln_p_net ln_firm_output ln_Capital n_products ///
             input_similarity output_similarity ///
             ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt {
    count if missing(`v')
    display "  missing `v': " r(N)
}

display ""
display "==== 回归面板汇总 ===="
count
display "总观测数: " r(N)
gdistinct firm_n
gdistinct prod_n
gdistinct city_n

compress
save "reg_panel.dta", replace


* ==============================================================================
* TABLE 1: 仅企业层面
*
* 展示企业特征（规模、资本、产品数）对外包价格的截面相关性。
* 企业变量在 OLS 可识别；加入 Firm FE 后完全被吸收（单年截面数据）。
* ==============================================================================

display ""
display "===== TABLE 1: Firm-level only ====="

use "reg_panel.dta", clear

* (1) OLS
reg ln_p_net ln_firm_output ln_Capital n_products, vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t1_m1

* (2) + Firm FE（企业变量全部被吸收，系数显示为 0/.）
reghdfe ln_p_net ln_firm_output ln_Capital n_products, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t1_m2

esttab t1_m1 t1_m2 ///
    using "$REGOUT/T1_firm_only.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output ln_Capital n_products) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-level variables only.") ///
    mtitles("OLS" "+Firm FE")
display "T1 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 2: 企业层面 + 产品相似性
*
* S_mj / C_mj 在 firm×product 层面变化，FE 规格下可识别。
* OLS 三类变量均可识别；加入 Firm FE 后企业变量被吸收，相似度系数存活。
* ==============================================================================

display ""
display "===== TABLE 2: Firm-level + Similarity ====="

use "reg_panel.dta", clear

* (1) OLS
reg ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t2_m1

* (2) + Firm FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t2_m2

* (3) + Firm + Product FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
est store t2_m3

* (4) + Firm + Product + City FE（首选规格）
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t2_m4

esttab t2_m1 t2_m2 t2_m3 t2_m4 ///
    using "$REGOUT/T2_firm_similarity.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output ln_Capital n_products input_similarity output_similarity) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-level + product similarity (S_mj, C_mj).") ///
    mtitles("OLS" "+Firm FE" "+Firm+Prod" "+Firm+Prod+City")
display "T2 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 3: 仅市场层面
*
* 展示买卖双方竞争结构与市场均价对外包采购价格的影响。
* 市场变量在 product×city 层面变化，OLS 和 FE 规格均可识别。
* ==============================================================================

display ""
display "===== TABLE 3: Market-level only ====="

use "reg_panel.dta", clear

* (1) OLS
reg ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t3_m1

* (2) + Firm FE
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t3_m2

* (3) + Firm + Product FE
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
est store t3_m3

* (4) + Firm + Product + City FE（首选规格）
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t3_m4

esttab t3_m1 t3_m2 t3_m3 t3_m4 ///
    using "$REGOUT/T3_market_only.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Market-level variables only.") ///
    mtitles("OLS" "+Firm FE" "+Firm+Prod" "+Firm+Prod+City")
display "T3 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 4: 企业层面 + 市场层面
*
* OLS：企业变量与市场变量均可识别，展示控制市场条件后企业特征的净效应。
* FE：企业变量被吸收，仅市场变量存活；与 T3 的对比揭示市场变量系数的稳健性。
* ==============================================================================

display ""
display "===== TABLE 4: Firm-level + Market-level ====="

use "reg_panel.dta", clear

* (1) OLS
reg ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t4_m1

* (2) + Firm FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t4_m2

* (3) + Firm + Product FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
est store t4_m3

* (4) + Firm + Product + City FE（首选规格）
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t4_m4

esttab t4_m1 t4_m2 t4_m3 t4_m4 ///
    using "$REGOUT/T4_firm_market.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output ln_Capital n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-level + market-level variables.") ///
    mtitles("OLS" "+Firm FE" "+Firm+Prod" "+Firm+Prod+City")
display "T4 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 5: 全规格（企业层面 + 产品相似性 + 市场层面）
*
* 三类变量同时纳入的完整规格。
* OLS：所有变量可识别；FE：企业变量被吸收，相似度与市场变量存活。
* ==============================================================================

display ""
display "===== TABLE 5: Full specification ====="

use "reg_panel.dta", clear

* (1) OLS
reg ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t5_m1

* (2) + Firm FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store t5_m2

* (3) + Firm + Product FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
est store t5_m3

* (4) + Firm + Product + City FE（首选规格）
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    input_similarity output_similarity ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t5_m4

esttab t5_m1 t5_m2 t5_m3 t5_m4 ///
    using "$REGOUT/T5_full_spec.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output ln_Capital n_products ///
          input_similarity output_similarity ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Full specification (firm + similarity + market).") ///
    mtitles("OLS" "+Firm FE" "+Firm+Prod" "+Firm+Prod+City")
display "T5 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT      "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 6: 交互项（企业规模 × 市场条件）
*
* 检验：大企业是否能更好地利用市场厚度获取折扣？
* 交互项在 firm×product 层面变化，FE 规格下可识别。
* ln_firm_output 主效应被 Firm FE 吸收，但交互项系数可识别。
* ==============================================================================

display ""
display "===== TABLE 6: Firm-size × Market interactions ====="

use "reg_panel.dta", clear

gen size_x_nbuy   = ln_firm_output * ln_n_buyers
gen size_x_nsell  = ln_firm_output * ln_n_sellers
gen size_x_pmkt   = ln_firm_output * ln_p_mkt
gen size_x_mktqty = ln_firm_output * ln_mkt_qty

* (1) 基准（全 FE，无交互）
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t6_m1

* (2) + 规模 × 买方数
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t6_m2

* (3) + 规模 × 卖方数
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nsell, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t6_m3

* (4) + 规模 × 市场均价
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_pmkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t6_m4

* (5) 全部交互
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store t6_m5

esttab t6_m1 t6_m2 t6_m3 t6_m4 t6_m5 ///
    using "$REGOUT/T6_interactions.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-size x market condition interactions.") ///
    mtitles("Baseline" "+Size*Nbuy" "+Size*Nsell" "+Size*Pmkt" "All")
display "T6 saved."
est clear

display ""
display "====================================================="
display "All six tables saved to: $REGOUT"
display "  T1_firm_only.txt         (仅企业层面)"
display "  T2_firm_similarity.txt   (企业层面 + 产品相似性)"
display "  T3_market_only.txt       (仅市场层面)"
display "  T4_firm_market.txt       (企业层面 + 市场层面)"
display "  T5_full_spec.txt         (全规格)"
display "  T6_interactions.txt      (企业规模 × 市场条件交互)"
display "  样本：均已去掉中介企业（is_intermediary == 1）"
display "====================================================="

log close
