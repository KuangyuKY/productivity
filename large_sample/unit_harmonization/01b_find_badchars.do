clear all
set more off
set linesize 200

*---------------------------------------------------------------------
* ★ 路径：只有这两行需要按机器改 ★
*---------------------------------------------------------------------
global csv "G:/Kuangyu_Temp/Outsource/productivity/large"
global out "G:/Kuangyu_Temp/Outsource/productivity/productivity/large_sample/unit_harmonization"
*---------------------------------------------------------------------

global log "$out/logs"
capture mkdir "$log"

capture log close _all
log using "$log/01b_find_badchars.log", replace text

*=====================================================================
* 01b_find_badchars —— 定位字符串字段里"肉眼看不见"的字符
*
* 用途：firm_id / 项目代码 / 单位 里混进了看不出来的字符（不间断空格、零宽空格、
*       BOM、制表符、全角空格、控制字符……）。肉眼和 list 都看不到，但会让
*       "^[0-9]+$" 判定失败、让本该相同的单位裂成两个取值。
*
* 原理：ustrtohex() 把字符串逐字符转成十六进制码点，隐形字符立刻现形；
*       ustrregexm() 是 Unicode 正则（regexm 按字节走，认不出 \uXXXX）。
*
* 做法：每次只用 colrange() 读【一列】，再 contract 成去重清单再扫描
*       —— 内存占用极小，不需要 preserve，也不会写几个 GB 的临时文件。
*
* 本步【只读不写】，只产 log。
*=====================================================================


*########################### 工具程序 ###########################
* _hexscan：单列体检
*   args 1 = CSV 文件名
*        2 = 列号（colrange）
*        3 = 该列的中文名（仅用于打印）
*        4 = "可疑字符"的 Unicode 正则；命中即为可疑
*   注：正则一律写成【命中即可疑】的形式，不要用 ^...$ 全匹配
*       —— 模式里带 $ 会被 Stata 当成 global 宏前缀
capture program drop _hexscan
program define _hexscan
    args file col label pat

    di _n as text "  ----------------------------------------------------------"
    di as result "  `file'  第 `col' 列：`label'"

    qui import delimited "$csv/`file'", clear stringcols(_all) bindquote(nobind) ///
        colrange(`col':`col')
    qui count
    di as text "    该列行数        : " as result r(N)

    * 只剩一个变量，取它的名字
    qui ds
    local v = r(varlist)

    * 去重成清单（77k / 549k 量级，很小）
    qui contract `v', freq(_freq)
    qui count
    di as text "    去重取值数      : " as result r(N)

    qui gen byte _bad = ustrregexm(`v', "`pat'")
    qui count if _bad
    local nbad = r(N)
    di as text "    命中可疑字符的取值数 : " as result `nbad'

    if `nbad' == 0 {
        di as text "    ✓ 干净"
        exit
    }

    qui summ _freq if _bad, meanonly
    di as text "    这些取值一共影响行数 : " as result r(sum)

    * 只列前 200 个，按影响行数从大到小
    qui keep if _bad
    gsort -_freq
    qui gen str244 _hex = ustrtohex(`v')
    qui gen int  _nb  = length(`v')
    qui gen int  _nc  = ustrlen(`v')
    local nshow = min(200, `nbad')
    di _n as text "    值 / 影响行数 / 字节长 / 字符数 / 码点"
    list `v' _freq _nb _nc _hex in 1/`nshow', clean noobs
    if `nbad' > 200 {
        di as text "    —— 共 `nbad' 个，上面只列了影响行数最大的 200 个"
    }
end


*########################### 表1：firm_buy ###########################
* 列序：1 购方企业ID  2 项目代码  3 单位  4 year  5 金额合计  6 数量合计

* 企业 ID：只要出现非数字字符就算可疑
_hexscan "firm_buy.csv" 1 "购方企业ID" "[^0-9]"

* 项目代码：数字/字母之外的都算可疑（企业自编码里有字母是正常的，
*           但汉字、符号、隐形字符不正常）
_hexscan "firm_buy.csv" 2 "项目代码" "[^0-9A-Za-z]"

* 单位：中文本来就合法，只抓控制字符和各种隐形空白
*   \x00-\x1F 控制符  \x7F DEL  \u00A0 不间断空格  \u200B-\u200F 零宽/方向标记
*   \u2028\u2029 行/段分隔  \u3000 全角空格  \uFEFF BOM
_hexscan "firm_buy.csv" 3 "单位" "[\x00-\x1F\x7F\u00A0\u200B-\u200F\u2028\u2029\u3000\uFEFF]"


*########################### 表2：firm_sell ##########################
* 列序：1 销方企业ID  2 项目代码  3 单位  4 year  5 金额合计  6 数量合计

_hexscan "firm_sell.csv" 1 "销方企业ID" "[^0-9]"
_hexscan "firm_sell.csv" 2 "项目代码"   "[^0-9A-Za-z]"
_hexscan "firm_sell.csv" 3 "单位"       "[\x00-\x1F\x7F\u00A0\u200B-\u200F\u2028\u2029\u3000\uFEFF]"


di _n(2) as result "==== 完成：log 在 $log/01b_find_badchars.log ===="
log close
