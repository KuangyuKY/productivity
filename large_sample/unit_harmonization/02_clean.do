clear all
set more off
set linesize 200

*---------------------------------------------------------------------
* ★ 路径：只有这三行需要按机器改 ★
*---------------------------------------------------------------------
* firm_buy.dta / firm_sell.dta 所在目录（同时也是清洗产物的落点）
global dta  "G:/Kuangyu_Temp/Outsource/productivity/large"
* bianma.dta 所在目录
global root "G:/Kuangyu_Temp/Outsource"
* 代码/产出目录（= 本 do 所在的 git 文件夹，log 与损耗表随 git 同步回来）
global out  "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample/unit_harmonization"
*---------------------------------------------------------------------

global log "$out/logs"
capture mkdir "$log"

capture log close _all
log using "$log/02_clean.log", replace text

*=====================================================================
* 02_clean —— firm 侧清洗（表1 firm_buy / 表2 firm_sell）
*
* 输入：$dta/firm_buy.dta   $dta/firm_sell.dta   （01 体检后已存好的 dta）
*       $root/bianma.dta    （2,778 个合法 9 位产品码）
*
* 产出：$dta/firm_buy_val.dta    金额有效，数量可缺失 —— 供外包识别 min(买,卖) 用
*       $dta/firm_buy_clean.dta  金额+数量都有效 —— 供单价/画像用
*       （firm_sell 同）
*       $out/cleaning_attrition.xlsx  逐步损耗表
*
* 口径（沿用项目既定逻辑，未做改动）：
*   - 产品键 = 项目代码右补零至 19 位 → 取前 9 位 → 与 bianma 的 2,778 码 inner join
*   - 单价 p = 金额合计 / 数量合计，所以算价的样本要求 value>0 且 qty>0
*   - 外包 = 同企业同产品既买又卖，外包额 = min(买,卖)，只用到金额
*
* 单位这一步【只做最保守处理】：ustrtrim 去空白 + 空/NULL 归为 UNKNOWN。
*   同义词合并（公斤=kg=KG=千克、个=只=PCS…）一律不做 —— 等 03 画像看完
*   77,253 个取值的完整分布再建映射表，现在合并等于拍脑袋。
*   注意用 ustrtrim() 不是 trim()：trim 只认 ASCII 空格，去不掉全角空格
*   (\u3000) 和不间断空格 (\u00a0)，而这两个在本数据里确实存在。
*=====================================================================


*########################### Part A：准备 bianma ###########################
use "$root/bianma.dta", clear
di _n as text ">>> bianma.dta 结构"
describe

* 键名兜底：优先用 product_id；只有一个变量时就把它当作产品码
capture confirm variable product_id
if _rc {
    qui ds
    local bv = r(varlist)
    local nv : word count `bv'
    if `nv' == 1 {
        rename `bv' product_id
    }
    else {
        di as error "！bianma.dta 里没有 product_id 变量，请照上面的 describe 手动指定"
        exit 198
    }
}

* 产品码必须是字符串，且是 9 位（数值型会把前导零吃掉）
capture confirm string variable product_id
if _rc {
    tostring product_id, replace format(%09.0f) force
}
qui replace product_id = ustrtrim(product_id)
keep product_id
qui duplicates drop
qui count
di as text ">>> bianma 合法 9 位码数 = " as result r(N)
tempfile bianma9
qui save "`bianma9'", replace


*########################### 损耗记录 ###########################
* _snap：给当前内存中的数据拍一张快照，post 一行
*   args 1 = 步骤名   2 = 用哪个变量数"产品数"
capture program drop _snap
program define _snap
    args step pvar

    qui count
    local n = r(N)

    tempvar tf
    qui egen byte `tf' = tag(firm_id)
    qui count if `tf'
    local f = r(N)
    drop `tf'

    tempvar tp
    qui egen byte `tp' = tag(`pvar')
    qui count if `tp'
    local p = r(N)
    drop `tp'

    qui summ value, meanonly
    local v = r(sum)

    post $H ("$SIDE") ("`step'") (`n') (`f') (`p') (`v')
    di as text "    [`step']" _col(34) "行=" as result %14.0fc `n' ///
       as text "  企业=" as result %8.0fc `f' ///
       as text "  产品=" as result %9.0fc `p' ///
       as text "  金额=" as result %16.0fc `v'
end

tempfile attr
postfile hh str10 side str28 step double nrow double nfirm double nprod double value ///
    using "`attr'", replace
global H hh


*########################### Part B：逐侧清洗 ###########################
foreach side in buy sell {

    global SIDE "`side'"

    di _n(2) as text "================================================================"
    di as result "  firm_`side'.dta"
    di as text "================================================================"

    use "$dta/firm_`side'.dta", clear

    * ---- 列名统一成英文（原始列名是中文，import 时 ASCII 部分被转小写）----
    capture rename 购方企业id firm_id
    capture rename 销方企业id firm_id
    capture rename 项目代码   product_code
    capture rename 单位       unit
    capture rename 金额合计   value
    capture rename 数量合计   qty

    * 产品码必须是字符串（数值型会丢精度、吃前导零）
    capture confirm string variable product_code
    if _rc {
        di as error "！product_code 是数值型 —— 19 位码已经丢精度，需要回到 CSV 用 stringcols 重读"
        exit 198
    }

    _snap "0 原始" product_code

    * ---- B1 丢掉解析残骸：year 缺失的行 ----
    * 01 体检里 firm_buy 有 14 行 year 缺失。year 是 SQL 里的常数，不可能缺失，
    * 只能是 CSV 里孤立的引号把两行拼坏留下的残骸，整行不可信。
    qui drop if missing(year)
    _snap "1 去 year 缺失" product_code

    * ---- B2 项目代码：必须非空且纯数字 ----
    qui replace product_code = ustrtrim(product_code)
    qui drop if product_code == ""
    qui drop if ustrregexm(product_code, "[^0-9]")
    _snap "2 去空/非纯数字码" product_code

    * ---- B3 右补零至 19 位 → 取前 9 位 ----
    qui gen str19 product_19 = substr(product_code + "0000000000000000000", 1, 19)
    qui gen str9  product_id = substr(product_19, 1, 9)
    _snap "3 取前9位" product_id

    * ---- B4 并 bianma，只留合法产品码 ----
    qui merge m:1 product_id using "`bianma9'"
    qui drop if _merge == 2
    qui keep if _merge == 3
    drop _merge
    _snap "4 匹配 bianma" product_id

    * ---- B5 金额有效（红冲净额 ≤0 的丢掉）----
    qui drop if missing(value)
    qui drop if value <= 0
    _snap "5 去金额<=0" product_id

    * ---- B6 单位最保守处理 ----
    * ustrtrim 去掉首尾空白（含全角空格/不间断空格），空串与字面 NULL 归 UNKNOWN。
    * 不做任何同义词合并。
    qui replace unit = ustrtrim(unit)
    qui replace unit = "UNKNOWN" if unit == ""
    qui replace unit = "UNKNOWN" if inlist(upper(unit), "NULL", "(NULL)", "NA", "N/A", "#N/A", "NAN")
    qui count if unit == "UNKNOWN"
    di as text "    单位归为 UNKNOWN 的行数 = " as result r(N)

    * ---- B7 瘦身：19 位码和原始码到这里已经用不到了 ----
    * 顺手 compress —— unit 是 str48，实际值大多两三个字符，preserve 的临时文件能小一大截
    drop product_code product_19
    qui compress

    * ---- B8 落金额口径的产物（数量可缺失，供外包识别 min(买,卖) 用）----
    * 注意：这一版【保留】数量缺失/非正的行，因为外包额只用金额。
    * 若在这里就把数量无效的行丢掉，外包识别会白白损失一批交易
    * （买方侧数量缺失占 7.3%，不是小数目）。
    * 提醒：collapse (sum) 把缺失当 0 加，所以这份数据里 qty==0 的含义是
    *       "该组没有任何有效数量"，不要拿它去算单价。
    preserve
        qui collapse (sum) value qty, by(firm_id product_id unit year)
        qui compress
        qui save "$dta/firm_`side'_val.dta", replace
        qui count
        di as text "    → firm_`side'_val.dta   行数 = " as result r(N)
    restore

    * ---- B9 数量有效（算单价必须）----
    qui drop if missing(qty)
    qui drop if qty <= 0
    _snap "6 去数量缺失/<=0" product_id

    * ---- B10 按 (企业, 9位产品, 单位, 年) 汇总 ----
    * 取前 9 位之后，同一 (企业,产品,单位,年) 会有多行（原来是不同的 19 位码），必须合并
    qui collapse (sum) value qty, by(firm_id product_id unit year)
    _snap "7 collapse 后" product_id

    qui gen double p = value / qty
    label var p "单价 = 金额合计/数量合计（仅在同一 unit 内可比）"

    qui compress
    qui save "$dta/firm_`side'_clean.dta", replace
    qui count
    di as text "    → firm_`side'_clean.dta 行数 = " as result r(N)
}

postclose hh


*########################### Part C：损耗表 ###########################
use "`attr'", clear

* 相对上一步的损耗，以及相对原始的累计留存
bysort side (step): gen double row_keep = nrow / nrow[1]
bysort side (step): gen double val_keep = value / value[1]
bysort side (step): gen double row_drop = 1 - nrow / nrow[_n-1]

format row_keep val_keep row_drop %6.4f
format nrow nfirm nprod %14.0fc
format value %18.0fc

di _n(2) as text "================================================================"
di as result "  逐步损耗表"
di as text "================================================================"
list side step nrow nfirm nprod value row_drop row_keep val_keep, clean noobs

export excel using "$out/cleaning_attrition.xlsx", firstrow(variables) replace

di _n(2) as result "==== 完成 ===="
di as text "  数据 : $dta/firm_{buy,sell}_val.dta   （金额口径，供外包识别）"
di as text "         $dta/firm_{buy,sell}_clean.dta （金额+数量口径，供单价/画像）"
di as text "  损耗 : $out/cleaning_attrition.xlsx"
di as text "  日志 : $log/02_clean.log"
log close
