*=====================================================================
* 01_inspect_raw —— 原始 CSV 体检（表1 firm_buy / 表2 firm_sell）
*
* 目的：在写清洗代码之前，先看清楚 import delimited 读进来的原始数据长什么样
*       —— 列名叫什么、每列被 Stata 读成了什么类型、有没有 NULL/空串、
*          项目代码有没有被读成数值（19 位码会丢精度）、单位字段有多脏。
*
* 本步【只读不写】：不生成任何 dta，只产出一份 log。
* 跑完把 $log 目录下的 .log 文件 commit 回 git，据此再写 02 清洗代码。
*
* 运行：Stata 里 do "…/unit_harmonization/01_inspect_raw.do"
*       两个文件都是千万行级别，整段跑完预计较慢，建议挂着跑。
*=====================================================================
clear all
set more off
set linesize 200

* ---- 路径 ----------------------------------------------------------
* CSV 输入目录（Navicat 手动导出，UTF-8、带表头、中文列名）
global csv "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample"
* 产出目录（= 本文件所在的 git 文件夹，log 随 git 同步回来）
global out "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample/unit_harmonization"
global log "$out/logs"
capture mkdir "$out"
capture mkdir "$log"

capture log close _all
log using "$log/01_inspect_raw.log", replace text


*########################### 环境信息 ###########################
di _n as text "==================== 运行环境 ===================="
di as text "Stata 版本 : " as result c(stata_version)
di as text "flavor     : " as result c(flavor)
di as text "处理器数   : " as result c(processors)
di as text "系统       : " as result c(os)
di as text "当前时间   : " as result c(current_date) " " c(current_time)


*########################### 体检程序 ###########################
* _inspect：对内存中已 import 好的数据做逐列体检
*   1) 行数 / describe（列名 + 存储类型 + 显示格式）
*   2) 前 20 行原样打印
*   3) 逐列：字符串 → 空串数、字面 NULL 数、长度 min/max、去重取值数
*             数值   → 缺失数、summarize（N/mean/sd/min/max）
*   4) 项目代码专项：是否被读成数值（19 位码丢精度的红线）
*   5) 单位专项：去重取值数 + 按频次排序的 Top 40（★ 破坏性，放最后）
capture program drop _inspect
program define _inspect
    args tag

    di _n(2) as text "================================================================"
    di as result "  数据集：`tag'"
    di as text "================================================================"

    * ----- 1) 行数 + 结构 -----
    count
    di _n as text ">>> 行数 = " as result r(N)
    di _n as text ">>> describe（列名 / 存储类型 / 显示格式 / 值标签）"
    describe, fullnames

    * ----- 2) 前 20 行原样 -----
    qui count
    local n20 = min(20, r(N))
    di _n as text ">>> 前 `n20' 行原样"
    list in 1/`n20', clean noobs

    * ----- 3) 逐列体检 -----
    di _n as text ">>> 逐列体检"
    foreach v of varlist _all {
        di _n as text "  ----------------------------------------------------------"
        capture confirm string variable `v'
        if _rc == 0 {
            di as result "  [字符串] `v'"

            qui count if trim(`v') == ""
            di as text "    空串/纯空白           : " as result r(N)

            qui count if inlist(upper(trim(`v')), "NULL", "(NULL)", "NA", "N/A", "#N/A", "NAN", ".")
            di as text "    字面 NULL/NA 类       : " as result r(N)

            tempvar L
            qui gen int `L' = length(`v')
            qui summ `L'
            di as text "    字符长度 min/max      : " as result r(min) " / " r(max)
            drop `L'

            tempvar T
            qui egen byte `T' = tag(`v')
            qui count if `T'
            di as text "    去重取值数            : " as result r(N)
            drop `T'
        }
        else {
            di as result "  [数值] `v'"

            qui count if missing(`v')
            di as text "    缺失（.）             : " as result r(N)

            qui count if `v' <= 0 & !missing(`v')
            di as text "    <= 0                  : " as result r(N)

            summ `v', format
        }
    }

    * ----- 4) 项目代码专项 -----
    di _n as text "  ----------------------------------------------------------"
    capture confirm variable 项目代码
    if _rc != 0 {
        di as error "  ！找不到变量【项目代码】—— 请核对 describe 里的实际列名"
    }
    else {
        capture confirm string variable 项目代码
        if _rc == 0 {
            di as result "  项目代码 = 字符串 ✓（19 位码安全）"
            di as text   "  按长度分布："
            tempvar LP
            qui gen int `LP' = length(trim(项目代码))
            tabulate `LP', missing
            drop `LP'
            di as text "  非纯数字的项目代码行数："
            qui count if !regexm(trim(项目代码), "^[0-9]+$")
            di as result "    " r(N)
        }
        else {
            di as error "  ★★★ 项目代码 被 import delimited 读成了【数值型】"
            di as error "  ★★★ 19 位码超出双精度整数上限(2^53≈16位)，末几位会被抹平"
            di as error "  ★★★ 清洗代码里必须改成 import delimited …, stringcols(…) 或先 tostring"
            summ 项目代码, format
            di as text "  存储类型 / 显示格式："
            describe 项目代码
        }
    }

    * ----- 4b) year 专项 -----
    di _n as text "  ----------------------------------------------------------"
    capture confirm variable year
    if _rc != 0 {
        di as error "  ！找不到变量【year】—— 请核对 describe 里的实际列名"
    }
    else {
        di as result "  year 分布："
        tabulate year, missing
    }

    * ----- 5) 单位专项（★ contract 会重塑数据，必须放最后）-----
    di _n as text "  ----------------------------------------------------------"
    capture confirm variable 单位
    if _rc != 0 {
        di as error "  ！找不到变量【单位】—— 请核对 describe 里的实际列名"
    }
    else {
        capture confirm string variable 单位
        if _rc != 0 {
            di as error "  ！【单位】被读成了数值型，很反常，请看上面的 describe"
            tostring 单位, replace force
        }
        di as result "  单位：按频次排序的 Top 50（含空串）"
        contract 单位, freq(_freq)
        gsort -_freq
        qui count
        local nu = r(N)
        local n50 = min(50, `nu')
        di as text "    单位去重取值数（原始，未做任何规整）= " as result `nu'
        list in 1/`n50', clean noobs
        di as text "    —— 上面只列了前 `n50' 个（共 `nu' 个），完整清单进下一步画像"
    }
end


*########################### 表1：firm_buy ###########################
* 颗粒度：购方企业ID × 项目代码 × 单位 × year
* 列    ：购方企业ID, 项目代码, 单位, year, 金额合计, 数量合计
import delimited "$csv/firm_buy.csv", clear
_inspect "firm_buy.csv（表1 企业购买）"


*########################### 表2：firm_sell ##########################
* 颗粒度：销方企业ID × 项目代码 × 单位 × year
* 列    ：销方企业ID, 项目代码, 单位, year, 金额合计, 数量合计
import delimited "$csv/firm_sell.csv", clear
_inspect "firm_sell.csv（表2 企业销售）"


di _n(2) as result "==== 体检完成：log 在 $log/01_inspect_raw.log，请 commit 回 git ===="
log close
