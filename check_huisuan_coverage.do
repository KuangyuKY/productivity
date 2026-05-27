* ==============================================================================
* 汇算数据覆盖率检查
*
* 目的：确认 3,410 家样本企业通过 cid → id → 汇算 两跳合并的覆盖情况
* 运行前提：invoice_panel.dta 和 firm_chars.dta 已由 01_clean.ipynb 生成
* ==============================================================================

clear all
set more off
cd "G:\Kuangyu_Temp\Outsource\productivity"

* ------------------------------------------------------------------------------
* Step 1：从 firm_buy.csv 读样本企业 ID（只含 3,410 家样本企业）
* ------------------------------------------------------------------------------
import delimited "G:\Kuangyu_Temp\Outsource\productivity\firm_buy.csv", ///
    stringcols(_all) clear
* firm_buy.csv 的购方企业ID列名——根据实际列名调整
* 常见列名：购方企业id / firm_id / 购方企业ID
ds
* 把企业ID列 destring 成数值型 cid（改下面的 varname 为实际列名）
destring 购方企业id, gen(cid) force
keep cid
duplicates drop cid, force
drop if missing(cid)
count
display "样本企业总数（firm_buy 中）: " r(N)
save "tmp_sample_cids.dta", replace

* ------------------------------------------------------------------------------
* Step 2：第一跳 — cid → 桥表 → id / entid
* ------------------------------------------------------------------------------
merge 1:1 cid using ///
    "E:\HZhang_Xing\data\merged_parquet\csv_2017\cid_entid_unique.dta", ///
    keepusing(id entid)

display ""
display "===== Step 2：cid → cid_entid_unique 覆盖率 ====="
count if _merge == 3
display "  matched（有 id）: " r(N)
count if _merge == 1
display "  master only（无 id）: " r(N)
count if _merge == 2
display "  using only（桥表有但样本无）: " r(N)

* 只保留 matched，继续往下
keep if _merge == 3
drop _merge
count
display "进入第二跳的企业数: " r(N)
save "tmp_sample_with_id.dta", replace

* ------------------------------------------------------------------------------
* Step 3：第二跳 — id → 汇算数据
* ------------------------------------------------------------------------------
use "H:\汇算数据\2017.dta", clear

* 汇算数据按 id 去重（学长脚本中的处理）
gen year = 2017
bysort id year: gen rep_no = _n
drop if rep_no > 1
drop rep_no
drop year

keep id 从业人数 资产总额 行业代码
count
display ""
display "汇算 2017 去重后行数: " r(N)

save "tmp_huisuan_slim.dta", replace

* 以样本为 master，汇算为 using（m:1：多个 cid 可对应同一 id）
use "tmp_sample_with_id.dta", clear
merge m:1 id using "tmp_huisuan_slim.dta"

display ""
display "===== Step 3：id → 汇算数据 覆盖率 ====="
count if _merge == 3
display "  matched（有汇算变量）: " r(N)
count if _merge == 1
display "  sample only（有 id 但汇算无记录）: " r(N)
count if _merge == 2
display "  huisuan only（汇算有但样本无）: " r(N)

keep if _merge == 3
drop _merge

* ------------------------------------------------------------------------------
* Step 4：汇算关键变量的缺失诊断
* ------------------------------------------------------------------------------
display ""
display "===== Step 4：汇算变量质量 ====="
count if missing(从业人数)  | 从业人数  <= 0
display "  Labor 缺失或非正: " r(N)
count if missing(资产总额)  | 资产总额  <= 0
display "  Capital 缺失或非正: " r(N)
count if missing(行业代码)
display "  industry 缺失: " r(N)

rename (从业人数 资产总额 行业代码) (Labor Capital industry)
gen ln_Labor   = ln(Labor)   if Labor   > 0 & !missing(Labor)
gen ln_Capital = ln(Capital) if Capital > 0 & !missing(Capital)
summarize Labor Capital ln_Labor ln_Capital

* ------------------------------------------------------------------------------
* Step 5：汇总覆盖率
* ------------------------------------------------------------------------------
display ""
display "============================================="
display "覆盖率汇总（相对于 firm_chars 中的样本企业）"
display "============================================="

* 取总样本数
use "tmp_sample_cids.dta", clear
count
local total = r(N)

use "tmp_sample_with_id.dta", clear
count
local after_bridge = r(N)

* 第二跳覆盖数：重用 tmp_huisuan_slim 和 tmp_sample_with_id
use "tmp_sample_with_id.dta", clear
merge m:1 id using "tmp_huisuan_slim.dta", keep(match) nogen
count
local after_huisuan = r(N)

display "样本企业总数:                    `total'"
display "第一跳后（有 id）:               `after_bridge'  (" %5.1f (100*`after_bridge'/`total') "%)"
display "第二跳后（有汇算变量）:          `after_huisuan'  (" %5.1f (100*`after_huisuan'/`total') "%)"

* 清理临时文件
erase "tmp_sample_cids.dta"
erase "tmp_sample_with_id.dta"
erase "tmp_huisuan_slim.dta"

display ""
display "检查完毕。"
