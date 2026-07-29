clear all
set more off
set linesize 200

*---------------------------------------------------------------------
* ★ 路径：只有这两行需要按机器改 ★
*---------------------------------------------------------------------
global dta "G:/Kuangyu_Temp/Outsource/productivity/large"
global out "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample/unit_harmonization"
*---------------------------------------------------------------------

global log "$out/logs"
global prof "$out/profile"
capture mkdir "$log"
capture mkdir "$prof"

capture log close _all
log using "$log/03_unit_profile.log", replace text

*=====================================================================
* 03_unit_profile —— 单位字段画像（任务书 5.1）
*
* 输入：$dta/firm_buy_clean.dta   $dta/firm_sell_clean.dta （02 的产物）
*
* 产出（都落在 $out/profile/，随 git 同步回来）：
*   unit_freq_all.csv          买卖合并的单位清单：记录数/金额/累计金额占比
*                              —— 这就是 04 建 unit_map.csv 的原料
*   norm_experiment.csv        归一化实验：trim / upper / NFKC 各能折叠掉多少取值
*   product_unit_buy.csv       每个 9 位产品：单位数、主导单位、主导单位金额占比
*   product_unit_sell.csv      同上，卖方侧
*   buysell_unit_match.csv     同一 (企业,产品) 买方单位 vs 卖方单位是否一致
*
* 本步【只读不写业务数据】，不改任何 dta，只出画像。
* 画像结论出来之前【不做】任何同义词合并 —— 策略 A/C/D 要人拍板。
*
* 四件事：
*   1  单位清单 + 金额覆盖曲线：多少个单位能覆盖 99% 的金额？
*      这决定了映射表要不要人工审，还是根本审不过来。
*   2  归一化实验：77k 个取值里有多少纯粹是大小写/全角半角噪音？
*   3  每产品单位集中度：主导单位占比的分布 —— 直接决定策略 A 还是 C。
*   4  买卖单位一致性：决定外包识别能不能忽略单位（任务书决策点 2）。
*=====================================================================


*########################### 1  单位清单 + 金额覆盖 ###########################
di _n(2) as text "================================================================"
di as result "  1  单位清单与金额覆盖"
di as text "================================================================"

use "$dta/firm_sell_clean.dta", clear
qui collapse (count) n_sell = value (sum) v_sell = value, by(unit)
tempfile usell
qui save "`usell'", replace

use "$dta/firm_buy_clean.dta", clear
qui collapse (count) n_buy = value (sum) v_buy = value, by(unit)
qui merge 1:1 unit using "`usell'"
drop _merge

foreach v in n_buy v_buy n_sell v_sell {
    qui replace `v' = 0 if missing(`v')
}
qui gen double n_all = n_buy + n_sell
qui gen double v_all = v_buy + v_sell

qui count
di as text "  买卖合并后的单位去重取值数 = " as result r(N)

* 按金额降序，算累计覆盖
gsort -v_all
qui summ v_all, meanonly
local vtot = r(sum)
qui gen double cum_v      = sum(v_all)
qui gen double cum_share  = cum_v / `vtot'
qui gen long   rank       = _n
qui gen double share      = v_all / `vtot'

di _n as text "  金额覆盖曲线：覆盖到 X% 的金额，需要多少个不同单位"
foreach t in 0.50 0.80 0.90 0.95 0.99 0.999 {
    qui count if cum_share < `t'
    di as text "    " %5.1f `=`t'*100' "%" _col(16) "→ " as result %8.0fc `=r(N)+1' as text " 个单位"
}

di _n as text "  金额占比最大的前 60 个单位"
list rank unit n_all v_all share cum_share in 1/60, clean noobs

order unit n_buy v_buy n_sell v_sell n_all v_all share cum_share rank
export delimited using "$prof/unit_freq_all.csv", replace


*########################### 2  归一化实验 ###########################
* 问题：77k 个取值里，有多少纯粹是"大小写不同"和"全角半角不同"造成的重复？
* 逐级施加归一化，看去重取值数塌到多少 —— 塌得越多，说明脏乱越是表面功夫。
*   L1 ustrtrim         去首尾空白（02 已做，这里是基线）
*   L2 L1 + 去所有空白  连中间的空格也去掉（"公 斤" → "公斤"）
*   L3 L2 + upper       大小写合并（kg/KG/Kg）
*   L4 L3 + NFKC        全角转半角（ＫＧ → KG，全角数字/字母同理）
di _n(2) as text "================================================================"
di as result "  2  归一化实验（只是实验，不改数据）"
di as text "================================================================"

qui gen str48 u1 = unit
qui gen str48 u2 = ustrregexra(u1, "\s", "")
qui replace   u2 = "UNKNOWN" if u2 == ""
qui gen str48 u3 = upper(u2)
qui gen str48 u4 = upper(ustrnormalize(u2, "nfkc"))

tempname NP
postfile `NP' str48 level double nunit using "$prof/_norm.dta", replace

foreach L in unit u1 u2 u3 u4 {
    preserve
        qui collapse (sum) n_all v_all, by(`L')
        qui count
        local k = r(N)
    restore
    post `NP' ("`L'") (`k')
}
postclose `NP'

use "$prof/_norm.dta", clear
qui replace level = "L0 原始（02 已 trim）" if level == "unit"
qui replace level = "L1 ustrtrim"           if level == "u1"
qui replace level = "L2 + 去所有空白"        if level == "u2"
qui replace level = "L3 + upper"            if level == "u3"
qui replace level = "L4 + NFKC 全角转半角"   if level == "u4"
keep level nunit
list, clean noobs
export delimited using "$prof/norm_experiment.csv", replace
erase "$prof/_norm.dta"


*########################### 3  每产品单位集中度 ###########################
* ★ 这一节直接决定策略选 A（只留主导单位）还是 C（把 (产品,单位) 当分析单元）
capture program drop _produnit
program define _produnit
    args side

    di _n(2) as text "================================================================"
    di as result "  3  每产品单位集中度 —— `side' 侧"
    di as text "================================================================"

    use "$dta/firm_`side'_clean.dta", clear
    qui collapse (sum) value qty (count) nrec = p, by(product_id unit)

    * 每个产品：有几个不同单位、总金额
    bysort product_id: egen double v_prod = total(value)
    bysort product_id: gen long  n_units  = _N

    * 主导单位 = 该产品内金额最大的单位
    * （按 value 升序排，组内最后一行即最大；不用 gsort，避免 by 前缀的排序坑）
    bysort product_id (value): gen byte is_dom = (_n == _N)
    qui gen double dom_share = value / v_prod

    * ---- 分布 1：每产品的单位数 ----
    preserve
        qui keep if is_dom
        qui gen byte ubin = .
        qui replace ubin = 1 if n_units == 1
        qui replace ubin = 2 if n_units == 2
        qui replace ubin = 3 if inrange(n_units, 3, 5)
        qui replace ubin = 4 if inrange(n_units, 6, 10)
        qui replace ubin = 5 if inrange(n_units, 11, 20)
        qui replace ubin = 6 if n_units > 20
        label define UB 1 "1 个单位" 2 "2 个" 3 "3-5 个" 4 "6-10 个" ///
                        5 "11-20 个" 6 ">20 个", replace
        label values ubin UB

        di _n as text "  每个产品有多少个不同单位（产品数 / 按产品数占比）"
        tabulate ubin

        di _n as text "  同上，但按【金额】加权（这个更重要）"
        qui summ v_prod, meanonly
        local T = r(sum)
        forvalues b = 1/6 {
            qui summ v_prod if ubin == `b', meanonly
            local s = cond(r(N) == 0, 0, r(sum) / `T')
            di as text "    " %-12s "`: label UB `b''" _col(20) as result %7.4f `s'
        }

        * ---- 分布 2：主导单位占该产品金额的比例 ----
        di _n as text "  主导单位占该产品金额的比例 —— 分布"
        summarize dom_share, detail

        di _n as text "  主导单位占比分档（产品数）"
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
        tabulate dbin

        qui summ value, meanonly
        local kept = r(sum)
        qui summ v_prod, meanonly
        local tot = r(sum)
        di _n as text "  ★ 若选策略 A（只留主导单位），会丢掉的金额占比 = " ///
            as result %6.4f `=1 - `kept'/`tot''

        keep product_id unit n_units v_prod value dom_share
        rename unit  dom_unit
        rename value dom_value
        order product_id n_units dom_unit dom_share dom_value v_prod
        gsort -v_prod
        export delimited using "$prof/product_unit_`side'.csv", replace
    restore
end

_produnit buy
_produnit sell


*########################### 4  买卖单位一致性 ###########################
* 任务书决策点 2：外包 = 同企业同产品既买又卖，外包额 = min(买,卖)。
* 若一家企业买报 kg、卖报箱，min 在不同单位下没有意义。
* 这里量化：同一 (企业,产品) 上，买方主导单位与卖方主导单位相同的比例。
di _n(2) as text "================================================================"
di as result "  4  买卖单位一致性（决策点 2）"
di as text "================================================================"

foreach side in buy sell {
    use "$dta/firm_`side'_clean.dta", clear
    qui collapse (sum) value, by(firm_id product_id unit)
    * 主导单位 = 该 (企业,产品) 内金额最大的单位
    * keep 不能带 by 前缀，所以先打标再筛
    bysort firm_id product_id (value): gen byte is_dom = (_n == _N)
    qui keep if is_dom
    drop is_dom
    qui gen double v_`side' = value
    keep firm_id product_id unit v_`side'
    rename unit unit_`side'
    tempfile m`side'
    qui save "`m`side''", replace
}

use "`mbuy'", clear
qui merge 1:1 firm_id product_id using "`msell'"

di _n as text "  (企业,产品) 对的匹配情况：1=只买 2=只卖 3=既买又卖（= 外包候选）"
tabulate _merge

qui keep if _merge == 3
drop _merge
qui gen byte same = (unit_buy == unit_sell)

qui count
local N = r(N)
di _n as text "  既买又卖的 (企业,产品) 对数 = " as result %12.0fc `N'

di _n as text "  买卖主导单位是否一致（按对数）"
tabulate same

di _n as text "  同上，按【外包额 min(买,卖)】加权"
qui gen double v_out = min(v_buy, v_sell)
qui summ v_out, meanonly
local T = r(sum)
qui summ v_out if same, meanonly
di as text "    一致的占外包额比例 = " as result %6.4f `=r(sum)/`T''

di _n as text "  不一致时最常见的 20 种 (买方单位, 卖方单位) 组合"
preserve
    qui keep if !same
    qui collapse (count) npair = v_out (sum) v_out, by(unit_buy unit_sell)
    gsort -v_out
    local n20 = min(20, _N)
    list unit_buy unit_sell npair v_out in 1/`n20', clean noobs
restore

qui collapse (count) npair = v_out (sum) v_out, by(unit_buy unit_sell same)
gsort -v_out
export delimited using "$prof/buysell_unit_match.csv", replace


di _n(2) as result "==== 画像完成 ===="
di as text "  $prof/unit_freq_all.csv        单位清单 + 金额覆盖（建映射表的原料）"
di as text "  $prof/norm_experiment.csv      归一化能折叠掉多少取值"
di as text "  $prof/product_unit_buy.csv     每产品单位数 / 主导单位 / 主导占比"
di as text "  $prof/product_unit_sell.csv"
di as text "  $prof/buysell_unit_match.csv   买卖单位一致性"
di as text "  $log/03_unit_profile.log"
log close
