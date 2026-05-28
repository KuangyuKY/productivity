clear all
set more off

* ============================================================
* Prepare unique 2017 huisuan firm characteristics by id
* Purpose: fix "variable id does not uniquely identify observations in the using data"
* Input : H:\汇算数据\2017.dta
* Output: G:\Kuangyu_Temp\Outsource\productivity\huisuan_2017_unique_by_id.dta
* ============================================================

log using "productivity/huisuan_2017_unique_by_id.log", replace text

use "H:\汇算数据\2017.dta", clear

* Only keep variables needed by 02_price_reg.do
keep id 从业人数 资产总额

* id must exist for merge key
count if missing(id)
drop if missing(id)

* Convert target variables to numeric if needed
capture confirm numeric variable 从业人数
if _rc {
    destring 从业人数, replace force
}

capture confirm numeric variable 资产总额
if _rc {
    destring 资产总额, replace force
}

* Diagnose duplicate id problem before collapsing
capture noisily isid id
duplicates report id
duplicates tag id, gen(dup_id)

display "Number of rows before collapse:"
count

display "Number of duplicated rows before collapse:"
count if dup_id > 0

* Collapse to one record per id.
* If duplicate id rows contain repeated or multiple reported values, max keeps a nonmissing positive value when available.
* You can change max to mean if you prefer averaging duplicate filings.
collapse (max) 从业人数 资产总额 (count) n_huisuan_rows=id, by(id)

isid id

display "Number of unique ids after collapse:"
count

label variable 从业人数 "从业人数, collapsed to id level by max"
label variable 资产总额 "资产总额, collapsed to id level by max"
label variable n_huisuan_rows "Number of original huisuan rows under this id"

compress
save "G:\Kuangyu_Temp\Outsource\productivity\huisuan_2017_unique_by_id.dta", replace

log close
