clear all
set more off
set linesize 200

*---------------------------------------------------------------------
* ★ 路径：dta 存在哪，改这一行 ★
*---------------------------------------------------------------------
global dta "G:/Kuangyu_Temp/Outsource/productivity/large"
*---------------------------------------------------------------------

*=====================================================================
* 01b_find_badchars —— 找出 firm_buy 里那个含非数字字符的 购方企业id
*
* 肉眼看不见，是因为混进来的多半是不间断空格(\u00a0)、全角空格(\u3000)、
* 零宽空格(\u200b)、BOM(\ufeff) 这类字符 —— 渲染出来跟普通空格没区别，
* trim() 也去不掉（Stata 的 trim 只认 ASCII 空格）。
*
* ustrtohex() 把字符串逐字符转成十六进制码点，隐形字符立刻现形。
* ustrregexm() 是 Unicode 正则（regexm 按字节走，认不出 \uXXXX）。
* 正则写成"命中即可疑"而不是 ^...$ 全匹配 —— 模式里带 $ 会被 Stata 当成 global 宏。
*=====================================================================

use 购方企业id using "$dta/firm_buy.dta", clear

qui duplicates drop
qui count
di as text "去重后的 购方企业id 个数 = " as result r(N)

gen byte bad = ustrregexm(购方企业id, "[^0-9]")
qui count if bad
di as text "含非数字字符的 = " as result r(N)

keep if bad
gen str244 hex = ustrtohex(购方企业id)
gen int nbyte  = length(购方企业id)
gen int nchar  = ustrlen(购方企业id)

di _n as text "值 / 字节长 / 字符数 / 码点"
list 购方企业id nbyte nchar hex, clean noobs
