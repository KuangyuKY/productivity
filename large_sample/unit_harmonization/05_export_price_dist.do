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
log using "$log/05_export_price_dist.log", replace text

*=====================================================================
* 05_export_price_dist —— 导出 (产品 × 规范单位) 的价格分布
*
* 输入：$dta/firm_{buy,sell}_std.dta  （04 的产物，含 p_std = value/qty_std）
* 产出：$prof/price_dist_{buy,sell}.csv
*
* 用途：给 dashboard.ipynb 用 —— 选中一个产品、点一个单位之后，
*       要能看出"同样以千克计量时，这个产品的价格分布在什么范围"。
*
* 为什么要单独导：product_unit_matrix 里只有 Σ金额 和 Σ数量（聚合价一个数），
*       看不出跨企业的离散程度。分位数必须在企业层的原始观测上算。
*
* 一行 = 一个 (product_id, unit_std)，观测单位是 (企业 × 年)。
* 分位数【不加权】，就是"跨企业的价格分布"；p_agg 是金额加权的聚合价，
* 两者并排放，能看出加权价被大企业拉到分布的哪个位置。
*=====================================================================

foreach side in buy sell {

    di _n(2) as text "================================================================"
    di as result "  firm_`side'_std"
    di as text "================================================================"

    use "$dta/firm_`side'_std.dta", clear
    qui count
    di as text "  行数 = " as result %14.0fc r(N)

    * 价格必须是正的有限值（qty_std>0 已在 02 保证，这里防御一下）
    qui drop if missing(p_std) | p_std <= 0
    qui count
    di as text "  去掉 p_std 缺失/<=0 后 = " as result %14.0fc r(N)

    * 每个 (产品,单位) 里有多少家不同企业 —— collapse 不能算 distinct，先打标
    bysort product_id unit_std firm_id: gen byte _f1 = (_n == 1)
    bysort product_id unit_std: egen long n_firms = total(_f1)
    drop _f1

    * 分位数在企业×年观测上算；value/qty_std 求和用于算聚合价
    qui collapse (count)  n_obs   = p_std  ///
                 (mean)   p_mean  = p_std  ///
                 (sd)     p_sd    = p_std  ///
                 (min)    p_min   = p_std  ///
                 (p1)     p1      = p_std  ///
                 (p5)     p5      = p_std  ///
                 (p10)    p10     = p_std  ///
                 (p25)    p25     = p_std  ///
                 (p50)    p50     = p_std  ///
                 (p75)    p75     = p_std  ///
                 (p90)    p90     = p_std  ///
                 (p95)    p95     = p_std  ///
                 (p99)    p99     = p_std  ///
                 (max)    p_max   = p_std  ///
                 (sum)    value qty_std    ///
                 (first)  n_firms          ///
                 , by(product_id unit_std dimension)

    * 聚合价（金额加权）：Σ金额 / Σ折算后数量
    qui gen double p_agg = value / qty_std

    * 离散度指标
    qui gen double cv       = p_sd / p_mean
    qui gen double r_p90p10 = p90 / p10
    qui gen double r_p75p25 = p75 / p25

    * 该单位占本产品金额的比重（看板里的"比重"就是这一列）
    bysort product_id: egen double v_prod = total(value)
    qui gen double share = value / v_prod

    label var p_agg    "聚合价 = Σ金额/Σ数量（金额加权）"
    label var p50      "跨企业价格中位数（不加权）"
    label var r_p90p10 "p90/p10 价格离散度"
    label var share    "该单位占本产品金额的比重"

    order product_id unit_std dimension share value qty_std p_agg ///
          n_obs n_firms p50 p_mean p_sd cv r_p75p25 r_p90p10 ///
          p_min p1 p5 p10 p25 p75 p90 p95 p99 p_max v_prod
    gsort product_id -value

    export delimited using "$prof/price_dist_`side'.csv", replace
    qui count
    di as text "  → price_dist_`side'.csv  行数 = " as result r(N)

    di _n as text "  价格离散度 p90/p10 的分布（只看占本产品金额 >=5% 的格子）"
    summarize r_p90p10 if share >= 0.05, detail
}

di _n(2) as result "==== 完成 ===="
di as text "  $prof/price_dist_{buy,sell}.csv"
di as text "  $log/05_export_price_dist.log"
log close
