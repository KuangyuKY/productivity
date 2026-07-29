clear all
set more off
set linesize 200

*---------------------------------------------------------------------
* ★ 路径：只有这两行需要按机器改 ★
*---------------------------------------------------------------------
global dta "G:/Kuangyu_Temp/Outsource/productivity/large"
global out "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample/unit_harmonization"
*---------------------------------------------------------------------

global log  "$out/logs"
global prof "$out/profile"
capture mkdir "$log"
capture mkdir "$prof"

capture log close _all
log using "$log/04_apply_unit_map.log", replace text

*=====================================================================
* 04_apply_unit_map —— 施加单位映射，再看每产品有多少个单位
*
* 输入：$dta/firm_{buy,sell}_clean.dta   （02 的产物，unit 是原始拼写）
*       $out/unit_map.csv                （124 个单位的量纲映射，人工审过）
*
* 产出：$dta/firm_{buy,sell}_std.dta        带 unit_std / qty_std
*       $prof/product_unit_matrix_*.csv     完整的 产品 × 规范单位 矩阵
*       $prof/dimension_summary.csv         各量纲的金额占比
*       $prof/unit_std_freq.csv             规范单位清单
*
* 三步（按讨论定的方案）：
*   1  只保留金额覆盖 99% 的那 124 个单位，其余 89,353 个 → OTHER（保留不丢）
*   2  按量纲建映射：MASS/COUNT/LENGTH/AREA/VOLUME/ENERGY 可换算，
*      SET/CONTAINER/SERVICE/BATCH/TIME/POWER/MONEY/UNKNOWN/OTHER 不换算
*   3  可换算量纲折算到基准单位：质量→千克 计数→个 能量→千瓦时
*      长度→千米 体积→立方米 面积→平方米
*
* 然后重算 03 第 3 节的三个指标（每产品单位数 / 主导单位占比 / 策略A损失），
* 与规整前逐一对照 —— 这才是选策略的依据。
*
* 注意：不可换算的量纲【不是】不处理，而是同义拼写归一到一个规范名
*       （SET：套/组/SET/ST/台套 → 套），但绝不跨概念合并
*       （箱 ≠ 个，因为一箱装几个不知道）。
*=====================================================================


*########################### Part A：读映射表 ###########################
import delimited "$out/unit_map.csv", clear varnames(1) stringcols(_all) bindquote(nobind)

di _n as text ">>> unit_map.csv 结构"
describe

qui destring factor, replace
qui replace raw_unit  = ustrtrim(raw_unit)
qui replace base_unit = ustrtrim(base_unit)
qui replace dimension = ustrtrim(dimension)

* 映射表必须在 raw_unit 上唯一，否则 m:1 会失败
capture isid raw_unit
if _rc {
    di as error "！unit_map.csv 的 raw_unit 有重复，请修正后重跑"
    duplicates list raw_unit
    exit 459
}

qui count
di as text ">>> 映射表条数 = " as result r(N)

di _n as text ">>> 各量纲覆盖的单位数与名义金额占比（来自 unit_map 的 share_pct）"
qui destring share_pct, replace
preserve
    qui collapse (count) n_unit = factor (sum) share_pct, by(dimension)
    gsort -share_pct
    list dimension n_unit share_pct, clean noobs
    export delimited using "$prof/dimension_summary.csv", replace
restore

keep raw_unit dimension base_unit factor
rename raw_unit unit
tempfile map
qui save "`map'", replace


*########################### 指标程序 ###########################
* _conc：给定一个"单位变量"，报三个指标
*   1 每产品的不同单位数（分档，按产品数 + 按金额加权）
*   2 主导单位占该产品金额的比例（分位数）
*   3 策略 A（只留主导单位）会丢掉的金额占比
* args 1 = 单位变量名   2 = 标题
capture program drop _conc
program define _conc
    args uvar title

    di _n as text "  ---------------- `title' ----------------"

    preserve
        qui collapse (sum) value, by(product_id `uvar')
        bysort product_id: egen double v_prod = total(value)
        bysort product_id: gen long   n_units = _N
        bysort product_id (value): gen byte is_dom = (_n == _N)
        qui gen double dom_share = value / v_prod

        qui summ value if is_dom, meanonly
        local kept = r(sum)

        qui keep if is_dom
        qui summ v_prod, meanonly
        local tot = r(sum)

        qui summ n_units, detail
        di as text "    每产品单位数    中位数=" as result %6.0f r(p50) ///
           as text "  均值=" as result %8.2f r(mean) ///
           as text "  p90=" as result %6.0f r(p90) ///
           as text "  max=" as result %6.0f r(max)

        qui summ dom_share, detail
        di as text "    主导单位占比    中位数=" as result %6.4f r(p50) ///
           as text "  均值=" as result %6.4f r(mean) ///
           as text "  p10=" as result %6.4f r(p10) ///
           as text "  p25=" as result %6.4f r(p25)

        di as text "    ★ 策略A 丢掉金额  = " as result %6.4f `=1 - `kept'/`tot''

        qui count if n_units == 1
        di as text "    只有 1 个单位的产品数 = " as result r(N) ///
           as text " / " as result `=_N'

        qui gen byte dbin = .
        qui replace dbin = 1 if dom_share >= 0.99
        qui replace dbin = 2 if dom_share >= 0.95 & dom_share < 0.99
        qui replace dbin = 3 if dom_share >= 0.90 & dom_share < 0.95
        qui replace dbin = 4 if dom_share >= 0.75 & dom_share < 0.90
        qui replace dbin = 5 if dom_share >= 0.50 & dom_share < 0.75
        qui replace dbin = 6 if dom_share <  0.50
        label define DB 1 ">=99%" 2 "95-99%" 3 "90-95%" 4 "75-90%" ///
                        5 "50-75%" 6 "<50%", replace
        label values dbin DB
        di _n as text "    主导单位占比分档（产品数）"
        tabulate dbin
    restore
end


*########################### Part B：逐侧施加映射 ###########################
foreach side in buy sell {

    di _n(2) as text "================================================================"
    di as result "  firm_`side'"
    di as text "================================================================"

    use "$dta/firm_`side'_clean.dta", clear
    qui count
    local n0 = r(N)

    qui merge m:1 unit using "`map'"
    qui drop if _merge == 2

    * 不在 124 里的（_merge==1）→ OTHER，保留不丢
    qui replace dimension = "OTHER"   if _merge == 1
    qui replace base_unit = "OTHER"   if _merge == 1
    qui replace factor    = 1         if _merge == 1

    qui count if _merge == 1
    local nother = r(N)
    qui summ value if _merge == 1, meanonly
    local vother = r(sum)
    qui summ value, meanonly
    local vtot = r(sum)
    di as text "  落入 OTHER 的行数   = " as result %12.0fc `nother' ///
       as text "  （占 " as result %5.2f `=100*`nother'/`n0'' as text "%）"
    di as text "  落入 OTHER 的金额占比 = " as result %6.4f `=`vother'/`vtot''
    drop _merge

    * ---- 折算 ----
    * qty_std：可换算量纲乘系数；不可换算量纲 factor=1，数量原样
    qui gen double qty_std  = qty * factor
    qui gen str24  unit_std = base_unit
    qui gen double p_std    = value / qty_std
    label var qty_std  "折算到基准单位后的数量"
    label var unit_std "规范单位（同量纲已折算到基准）"
    label var p_std    "折算后单价（同一 unit_std 内可比）"

    * ---- 规整前 vs 规整后 ----
    _conc unit     "规整前（原始拼写，89,477 个取值）"
    _conc unit_std "规整后（量纲折算 + OTHER）"

    * 再看一版：把 OTHER 排除掉（OTHER 只占约 1% 金额，看看它是不是在虚增单位数）
    preserve
        qui drop if unit_std == "OTHER"
        _conc unit_std "规整后（且剔除 OTHER）"
    restore

    * ---- 导出完整的 产品 × 规范单位 矩阵（本地可复算，别再来一轮）----
    preserve
        qui collapse (sum) value qty_std (count) nrec = p, by(product_id unit_std dimension)
        bysort product_id: egen double v_prod = total(value)
        qui gen double share = value / v_prod
        gsort product_id -value
        order product_id unit_std dimension nrec value share qty_std v_prod
        export delimited using "$prof/product_unit_matrix_`side'.csv", replace
        qui count
        di as text "  → product_unit_matrix_`side'.csv  行数 = " as result r(N)
    restore

    * ---- 规范单位清单 ----
    preserve
        qui collapse (count) nrec = p (sum) value qty_std, by(unit_std dimension)
        gsort -value
        export delimited using "$prof/unit_std_freq_`side'.csv", replace
    restore

    qui compress
    qui save "$dta/firm_`side'_std.dta", replace
    di as text "  → firm_`side'_std.dta"
}


di _n(2) as result "==== 完成 ===="
di as text "  $dta/firm_{buy,sell}_std.dta"
di as text "  $prof/product_unit_matrix_{buy,sell}.csv   产品 × 规范单位 完整矩阵"
di as text "  $prof/unit_std_freq_{buy,sell}.csv         规范单位清单"
di as text "  $prof/dimension_summary.csv                各量纲金额占比"
di as text "  $log/04_apply_unit_map.log"
log close
