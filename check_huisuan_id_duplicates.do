clear all
set more off

log using "productivity/huisuan_id_duplicate_check.log", replace text

use "H:\汇算数据\2017.dta", clear

display "=== basic info ==="
describe id eid 从业人数 资产总额
count

display "=== id uniqueness ==="
capture noisily isid id
duplicates report id

display "=== missing id ==="
count if missing(id)

display "=== duplicate examples ==="
duplicates tag id, gen(dup_id)
tab dup_id if dup_id > 0, missing
list id eid 从业人数 资产总额 dup_id in 1/20 if dup_id > 0, abbreviate(20)

display "=== duplicate id summary after excluding missing id ==="
preserve
keep if !missing(id)
collapse (count) n_obs=id (count) n_emp=从业人数 (count) n_asset=资产总额, by(id)
summarize n_obs n_emp n_asset, detail
count if n_obs > 1
restore

log close
