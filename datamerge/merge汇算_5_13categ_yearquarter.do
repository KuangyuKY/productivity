clear
set scheme s1color, permanently
set max_memory 64g, permanently


* Merge ID Match Codes *
use "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta",clear 
gen year = 2017

append using "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2018_With_cid.dta", force 
replace year = 2018 if year ==.

destring cid, replace
drop if cid == .

bysort cid year: gen temp_repo_no =_n
drop if temp_repo_no > 1
drop temp_repo_no


save "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_20172018_With_cid_distinctcid.dta", replace

use "E:\HZhang_Xing\data\VAT_SellandInput13categories_2017_yearquarter.dta", clear
merge m:1 cid year using "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_20172018_With_cid_distinctcid.dta"
keep if _merge == 3
drop _merge

bysort eid yearquarter: gen rep_no = _n
drop if rep_no >1
tab year
drop rep_no
distinct cid

save "E:\HZhang_Xing\data\VAT_SellandInput13categories_2017_IDmatched_yearquarter.dta",replace


* Merge Labor from 汇算数据*
use "H:\汇算数据\2018.dta", clear
gen year = 2018
save "E:\HZhang_Xing\data\汇算2018.dta",replace

use "H:\汇算数据\2017.dta", clear
gen year = 2017
// append using "E:\HZhang_Xing\data\汇算2018.dta", force

// tostring id, replace
bysort eid year: gen rep_no = _n
drop if rep_no >1
drop rep_no


merge 1:m eid year using "E:\HZhang_Xing\data\VAT_SellandInput13categories_2017_IDmatched_yearquarter.dta", force

tab year if _merge == 3

keep if _merge == 3
drop _merge

rename (所在区域 行业代码 从业人数 净利润 b收入总额 资产总额 ) (county industry Labor Profit_Huisuan Revenue_Huisuan Expend_Capital)

order eid cid yearquarter year county industry Revenue_Huisuan Profit_Huisuan Labor Expend_Capital VAT_Revenue VAT_Pindex_output VAT_Qindex_output VAT_Exp_M VAT_Pindex_INP_m VAT_Qindex_INP_m

tab year

tab yearquarter

sort eid yearquarter

save "E:\HZhang_Xing\data\sample\VAT_Huisuan_matched_2017_yearquarter.dta", replace

