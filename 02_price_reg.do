* ==============================================================================
* 外包价格的决定因素 —— 主回归
*
* 对应结构模型 Step 2（外包成本方程）:
*   log c^B_fjt = δ^B_jct + x^B'_ft γ_B + z^B'_jct λ_B
*
*   δ^B_jct  ← Firm FE + Product FE + City FE
*   x^B_ft   ← ln_firm_output, ln_Capital, n_products
*              （firm-level，单年数据下被 Firm FE 吸收，仅 OLS 规格可识别）
*   z^B_jct  ← ln_n_buyers, ln_n_sellers, ln_mkt_qty, ln_p_mkt  （市场条件）
*              input_similarity  = S_mj  （投入相似度，来自 full_data.dta）
*              output_similarity = C_mj  （产出互补性，来自 full_data.dta）
*              S_mj / C_mj 在 firm×product 层面变化 → FE 规格下可识别
*
* 输入（虚拟机 G:\Kuangyu_Temp\Outsource\productivity\）:
*   invoice_panel.dta           主面板，由 01_clean.ipynb 生成
*   market_conds.dta            product × city 市场条件
*   firm_chars.dta              firm × year 企业特征
*   G:\Kuangyu_Temp\Outsource\full_data.dta     → input/output_similarity
*   G:\Kuangyu_Temp\Outsource\productivity\cid_entid_unique.dta → cid → id
*   H:\汇算数据\2017.dta        → 资产总额 (Capital)
*
* 输出（regression\ 子目录）:
*   T1_baseline.txt       逐步加 FE，展示企业特征 vs 市场条件
*   T2_demand_supply.txt  需求 vs 供给侧分解（Stage 3）
*   T3_similarity.txt     投入/产出相似度（结构模型 S_mj, C_mj）★ 新增
*   T4_interactions.txt   企业规模 × 市场条件 交互
*   T5_robustness.txt     去掉中介企业
*
* SE: 聚类到 firm 层
* ==============================================================================

clear all
set more off
set output proc
set max_memory ., permanently
set matsize 11000

cd "G:\Kuangyu_Temp\Outsource\productivity"
capture mkdir "regression"
log using "regression\02_price_reg.log", replace text

global REGOUT     "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* PART 1: 构造回归数据
* ==============================================================================

display ""
display "===== PART 1: 构造回归数据 ====="

use "invoice_panel.dta", clear
count
display "主面板观测数 (firm × prod × city × year): " r(N)

* --- 合并市场条件 ---
merge m:1 product_id city year using "market_conds.dta", keep(master match) nogen
count
display "after market_conds merge: " r(N)

* --- 合并企业特征（ln_firm_output, n_products, is_intermediary）---
merge m:1 firm_id year using "firm_chars.dta", keep(master match) nogen
count
display "after firm_chars merge: " r(N)

* --- 合并投入/产出相似度（S_mj, C_mj）来自 full_data.dta ---
* 先提取所需列存为临时文件（full_data 有 9000 万行，避免全量 merge）
preserve
    use "G:\Kuangyu_Temp\Outsource\full_data.dta", clear
    keep firm_id product_id year input_similarity output_similarity
    duplicates drop firm_id product_id year, force
    save "sim_temp.dta", replace
restore
merge m:1 firm_id product_id year using "sim_temp.dta", keep(master match) nogen
count if missing(input_similarity)
display "missing input_similarity: " r(N)
count if missing(output_similarity)
display "missing output_similarity: " r(N)

* --- 桥接汇算数据：firm_id (cid) → id → Capital（资产总额）---
preserve
    use "H:\汇算数据\2017.dta", clear
    gen year = 2017
    bysort id year: gen rep_no = _n
    drop if rep_no > 1
    drop rep_no
    keep id 资产总额
    save "huisuan_2017_clean.dta", replace
restore

destring firm_id, gen(cid) force
merge m:1 cid using "G:\Kuangyu_Temp\Outsource\productivity\cid_entid_unique.dta", ///
    keepusing(id) keep(master match) nogen
merge m:1 id using "huisuan_2017_clean.dta", ///
    keepusing(资产总额) keep(master match) nogen
rename 资产总额 Capital
gen ln_Capital = ln(Capital) if Capital > 0 & !missing(Capital)
count if missing(ln_Capital)
display "missing ln_Capital (汇算覆盖不足): " r(N)

* --- 缺失诊断 ---
display ""
display "==== 关键变量缺失统计 ===="
foreach v in ln_p_net ln_firm_output ln_Capital n_products ///
             ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
             input_similarity output_similarity {
    count if missing(`v')
    display "  missing `v': " r(N)
}

* --- 为 reghdfe 创建数值 ID ---
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)
gegen city_n = group(city)

display ""
display "==== 回归面板汇总 ===="
count
display "总观测数: " r(N)
gdistinct firm_n
gdistinct prod_n
gdistinct city_n

summarize ln_p_net ln_firm_output ln_Capital n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          input_similarity output_similarity

compress
save "reg_panel.dta", replace
erase "sim_temp.dta"
erase "huisuan_2017_clean.dta"


* ==============================================================================
* TABLE 1: Baseline —— 逐步加 FE
*
* 目的：展示企业特征（x^B_ft）在 FE 前后的效应
*       ln_firm_output / ln_Capital / n_products 在加入 Firm FE 后被吸收
*       → 单年数据下 firm-level 变量仅在 OLS 规格中可识别
*       市场条件变量（z^B_jct）在所有规格中均可识别
* ==============================================================================

display ""
display "===== TABLE 1: Baseline ====="

use "reg_panel.dta", clear

* (1) OLS-bare: 仅企业特征，无市场条件，无 FE
reg ln_p_net ln_firm_output ln_Capital n_products, vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store m1

* (2) OLS-full: + 市场条件，无 FE
reg ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    vce(cluster firm_n)
estadd local firm_fe "No",  replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store m2

* (3) + Firm FE：企业特征被吸收，市场条件存活
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No",  replace
estadd local city_fe "No",  replace
est store m3

* (4) + Firm + Product FE
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "No",  replace
est store m4

* (5) + Firm + Product + City FE（首选规格）
reghdfe ln_p_net ln_firm_output ln_Capital n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store m5

esttab m1 m2 m3 m4 m5 ///
    using "$REGOUT/T1_baseline.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output ln_Capital n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Baseline with progressive FE.") ///
    mtitles("OLS-bare" "OLS-full" "+FirmFE" "+Firm+Prod" "+Firm+Prod+City")
display "T1 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT     "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 2: 需求侧 vs 供给侧分解
*
* 对应会议纪要 Stage 3 及结构模型 z^B_jct:
*   Demand_pct: ln_n_buyers, ln_mkt_qty
*   Supply_pct: ln_n_sellers
*   P̄_pct:     ln_p_mkt
*
* 均采用 Firm + Product + City FE（首选规格）
* ==============================================================================

display ""
display "===== TABLE 2: Demand vs Supply ====="

use "reg_panel.dta", clear

* (1) 仅需求侧
reghdfe ln_p_net ln_n_buyers ln_mkt_qty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side    "Demand", replace
estadd local firm_fe "Yes",    replace
estadd local prod_fe "Yes",    replace
estadd local city_fe "Yes",    replace
est store d1

* (2) 仅供给侧
reghdfe ln_p_net ln_n_sellers, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side    "Supply", replace
estadd local firm_fe "Yes",    replace
estadd local prod_fe "Yes",    replace
estadd local city_fe "Yes",    replace
est store d2

* (3) 需 + 供
reghdfe ln_p_net ln_n_buyers ln_mkt_qty ln_n_sellers, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side    "Both",   replace
estadd local firm_fe "Yes",    replace
estadd local prod_fe "Yes",    replace
estadd local city_fe "Yes",    replace
est store d3

* (4) 需 + 供 + 市场均价（全规格）
reghdfe ln_p_net ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local side    "Both+Pbar", replace
estadd local firm_fe "Yes",       replace
estadd local prod_fe "Yes",       replace
estadd local city_fe "Yes",       replace
est store d4

esttab d1 d2 d3 d4 ///
    using "$REGOUT/T2_demand_supply.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_mkt_qty ln_n_sellers ln_p_mkt) ///
    stats(side firm_fe prod_fe city_fe N r2_a, ///
          labels("Specification" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Demand vs Supply decomposition.") ///
    mtitles("Demand" "Supply" "Both" "Both+Pbar")
display "T2 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT     "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 3: 产品相似度（结构模型 S_mj, C_mj）★ 核心新增表格
*
* 对应结构模型 z^B_jct 中的产品对特征:
*   input_similarity  = S_mj：产品 j 与企业核心产品在投入结构上的相似程度
*   output_similarity = C_mj：产品 j 与企业核心产品在客户群/分销上的互补程度
*
* 识别说明：
*   input_similarity[f,j] = sim(main_product[f], j)
*   在 firm × product 层面变化 → 不被 Firm FE 或 Product FE 单独吸收 → 可识别
*
* 经济逻辑：
*   - S_mj 高（投入相似）→ 企业对产品 j 有更强的议价能力（熟悉供应链）
*     → 预期系数为负（价格更低）
*   - C_mj 高（产出互补）→ 企业采购意愿更强（需求方效应）
*     → 方向待检验
* ==============================================================================

display ""
display "===== TABLE 3: Similarity Variables (S_mj, C_mj) ====="

use "reg_panel.dta", clear

* (1) 基准：市场条件 + FE（无相似度）
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store s1

* (2) + 投入相似度（S_mj）
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    input_similarity, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store s2

* (3) + 产出互补性（C_mj）
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    output_similarity, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store s3

* (4) 两个相似度同时纳入（全规格）
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    input_similarity output_similarity, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store s4

esttab s1 s2 s3 s4 ///
    using "$REGOUT/T3_similarity.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          input_similarity output_similarity) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Input/output similarity (structural S_mj and C_mj).") ///
    mtitles("Baseline" "+InputSim" "+OutputSim" "Both")
display "T3 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT     "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 4: 企业规模 × 市场条件 交互
*
* 检验：大企业是否能更好地利用市场厚度获取折扣？
*
* 注意：ln_firm_output 本身被 Firm FE 吸收（单年，显示为 0/.）
*       但交互项 ln_firm_output × z^B_jct 在 firm×product 层面变化 → 可识别
* ==============================================================================

display ""
display "===== TABLE 4: Firm-Size × Market Interactions ====="

use "reg_panel.dta", clear

gen size_x_nbuy   = ln_firm_output * ln_n_buyers
gen size_x_nsell  = ln_firm_output * ln_n_sellers
gen size_x_pmkt   = ln_firm_output * ln_p_mkt
gen size_x_mktqty = ln_firm_output * ln_mkt_qty

* (1) 基准（无交互）
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i1

* (2) + 规模 × 买方数
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i2

* (3) + 规模 × 卖方数
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nsell, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i3

* (4) + 规模 × 市场均价
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_pmkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i4

* (5) 全部交互
reghdfe ln_p_net ln_firm_output n_products ///
    ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local city_fe "Yes", replace
est store i5

esttab i1 i2 i3 i4 i5 ///
    using "$REGOUT/T4_interactions.txt", replace ///
    $esttab_opts ///
    order(ln_firm_output n_products ///
          ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          size_x_nbuy size_x_nsell size_x_pmkt size_x_mktqty) ///
    stats(firm_fe prod_fe city_fe N r2_a, ///
          labels("Firm FE" "Product FE" "City FE" "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Firm-size x market condition interactions.") ///
    mtitles("Baseline" "+Size*Nbuy" "+Size*Nsell" "+Size*Pmkt" "All")
display "T4 saved."
est clear
clear all
set output proc
set max_memory ., permanently
global REGOUT     "regression"
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ==============================================================================
* TABLE 5: 稳健性 —— 去掉中介企业
*
* is_intermediary = 1：外包比例 > 90%（纯转卖商，非生产型采购）
* 去掉这类企业后，外包价格的决定因素是否仍然稳健？
*
* col (3) 额外检验相似度变量在非中介样本中的稳健性
* ==============================================================================

display ""
display "===== TABLE 5: Robustness - No Intermediaries ====="

use "reg_panel.dta", clear

* (1) 全样本基准
reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "All",  replace
estadd local firm_fe "Yes",  replace
estadd local prod_fe "Yes",  replace
estadd local city_fe "Yes",  replace
est store r1

* (2) 去掉中介企业，市场条件基准
preserve
drop if is_intermediary == 1
count
display "obs after dropping intermediaries: " r(N)

reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "No-Inter", replace
estadd local firm_fe "Yes",      replace
estadd local prod_fe "Yes",      replace
estadd local city_fe "Yes",      replace
est store r2
restore

* (3) 去掉中介企业，+ 相似度变量
preserve
drop if is_intermediary == 1

reghdfe ln_p_net ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
    input_similarity output_similarity, ///
    absorb(firm_n prod_n city_n) vce(cluster firm_n)
estadd local sample  "No-Inter", replace
estadd local firm_fe "Yes",      replace
estadd local prod_fe "Yes",      replace
estadd local city_fe "Yes",      replace
est store r3
restore

esttab r1 r2 r3 ///
    using "$REGOUT/T5_robustness.txt", replace ///
    $esttab_opts ///
    order(ln_n_buyers ln_n_sellers ln_mkt_qty ln_p_mkt ///
          input_similarity output_similarity) ///
    stats(sample firm_fe prod_fe city_fe N r2_a, ///
          labels("Sample" "Firm FE" "Product FE" "City FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("DV: ln(purchase price). Robustness: dropping intermediaries.") ///
    mtitles("All firms" "No-Inter" "No-Inter+Sim")
display "T5 saved."
est clear


display ""
display "====================================================="
display "All five tables saved to: $REGOUT"
display "  T1_baseline.txt      (逐步加 FE，展示 firm chars 被吸收)"
display "  T2_demand_supply.txt (需求 vs 供给侧分解)"
display "  T3_similarity.txt    (投入/产出相似度 S_mj, C_mj)"
display "  T4_interactions.txt  (企业规模 × 市场条件 交互)"
display "  T5_robustness.txt    (去掉中介企业)"
display "====================================================="

log close
