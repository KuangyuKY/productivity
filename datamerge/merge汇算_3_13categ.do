set scheme s1color, permanently

* Merge ID Match Codes *
use "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta",clear 
destring cid, replace
drop if cid == .
bysort cid: gen temp_repo_no =_n
drop if temp_repo_no > 1
drop temp_repo_no
gen year = 2017

destring id, replace
save "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2017_With_cid_distinctcid.dta", replace

use "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2018_With_cid.dta",clear 
destring cid, replace
drop if cid == .
bysort cid: gen temp_repo_no =_n
drop if temp_repo_no > 1
drop temp_repo_no
gen year = 2018
tostring reg_type, replace
destring id, replace
save "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2018_With_cid_distinctcid.dta", replace

use "E:\HZhang_Xing\data\VAT_SellandInput13categories_20172018.dta", clear
merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2017_With_cid_distinctcid.dta"
drop if (_merge == 1) & (year == 2017)
drop if _merge == 2
drop _merge

merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2018_With_cid_distinctcid.dta"
drop if _merge == 2
drop if (_merge == 1) & (year == 2018)
drop _merge 
save "E:\HZhang_Xing\data\VAT_SellandInput13categories_20172018_IDmatched.dta",replace

use "E:\HZhang_Xing\data\VAT_SellandInput13categories_20172018_IDmatched.dta", clear
bysort eid year: gen rep_no = _n
drop if rep_no >1
tab year

drop rep_no
distinct cid
save "E:\HZhang_Xing\data\VAT_SellandInput13categories_20172018_IDmatched.dta",replace



* Merge Labor from 汇算数据*
use "H:\汇算数据\2018.dta", clear
gen year = 2018
tostring id, replace
bysort id year: gen rep_no = _n
drop if rep_no >1
drop rep_no
tostring 登记注册类型代码经济类型性质,replace
save "E:\HZhang_Xing\data\汇算2018.dta",replace

use "H:\汇算数据\2017.dta", clear
gen year = 2017
tostring id, replace
bysort id year: gen rep_no = _n
drop if rep_no >1
drop rep_no
merge 1:1 id year using "E:\HZhang_Xing\data\VAT_SellandInput13categories_20172018_IDmatched.dta"
drop if _merge == 1
drop if (_merge == 2) & (year == 2017)
drop _merge

tostring id, replace
merge 1:1 id year using "E:\HZhang_Xing\data\汇算2018.dta"
drop if _merge == 2
drop if (_merge == 1) & (year == 2018)
drop _merge

rename (所在区域 行业代码 从业人数 净利润 b收入总额 资产总额 ) (county industry Labor Profit_Huisuan Revenue_Huisuan Expend_Capital)

order cid year county industry Revenue_Huisuan Profit_Huisuan Labor Expend_Capital VAT_Revenue VAT_Pindex_output VAT_Qindex_output VAT_Exp_M VAT_Pindex_INP_m VAT_Qindex_INP_m

tab year

sort cid year

save "E:\HZhang_Xing\data\sample\VAT_Huisuan_matched_20172018.dta", replace


* Reduced-Form Analysis
use "E:\HZhang_Xing\data\sample\SellBuyInfo_Entyid_2017.dta",clear
gen ln_Expend_Service = ln(Expend_Service)
gen ln_Revenue = ln(Revenue)
gen ln_Qindex_output = ln(Qindex_output)
gen ln_Pindex_output = ln(Pindex_output)

gen Profitrate = Profit_Huisuan / Revenue_Huisuan
gen ln_Profitrate = ln(Profitrate)

gen Productivity_L = Qindex_output/Labor
gen ln_Productivity_L = ln(Productivity_L)

gen Rawmarkup_M = Revenue/Expend_Material
gen ln_Rawmarkup_M = ln(Rawmarkup_M)

* Share of Observations *
gen D_BuyService = (Expend_Service>0)
tab D_BuyService

* Share of Firms *
preserve
keep if year == 2017
collapse(max) D_BuyService, by(cid)
tab D_BuyService
restore 

* Share of Different Types *
preserve
keep if year == 2017
collapse(sum) Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O Expend_Service
foreach cc in P R D O {
	gen `cc'_share = Expend_Service_`cc' / Expend_Service
}
sum *_share
restore 

* Kdensity *
twoway(kdensity ln_Expend_Service if D_BuyService == 1, lcolor(dknavy)), xtitle("Expenditure on Service Inputs (log)") ytitle("Kernel Density", height(5)) name(firmsizedensity, replace)
graph export "E:\HZhang_Xing\results\graphs\fig_ServiceDistribution.jpg", width(3200) replace

sum Revenue if D_BuyService == 0
sum Revenue if D_BuyService == 1


* Group Bar Figures *
label variable ln_Revenue "Sales(log)"

statsby mean_G=r(mean) upper=r(ub) lower=r(lb), by(D_BuyService) clear : ci mean ln_Revenue
format mean_G %5.3f

twoway (bar mean_G D_BuyService if D_BuyService == 0, barwidth(0.5) lcolor(navy) fcolor(white) lwidth(medium)) ///
	   (bar mean_G D_BuyService if D_BuyService == 1, barwidth(0.5) color(maroon) lwidth(medium)) ///
       (rcap lower upper D_BuyService) ///
       (scatter mean_G D_BuyService,  msymbol(none) mlabel(mean_G) mlabposition(1) mlabsize(medium) mlabcolor(black)), ///
       legend(rows(1) order( 1 "Not Buying" 2 "Buying" 3 "95%CI"))  ///
	    ytitle("Mean", height(5)) xtitle("Buying Service Inputs Dummy") xlabel(0 (1) 1) ylabel(13.5 (0.5) 15.5, format(%5.1f))  name(firmsizebar, replace)
graph export "E:\HZhang_Xing\results\graphs\fig_firmsizebar.jpg", width(3200) replace

* Firmsize and Service Inputs
twoway(scatter ln_Revenue ln_Expend_Service, msymbol(Oh) mcolor(navy))(lfit ln_Revenue ln_Expend_Service, lcolor(maroon)), ytitle("Firm Sales (log)", height(5)) xtitle("Expenditure on Service Inputs (log)") name(firmsizerelation, replace)
// graph export "E:\HZhang_Xing\results\graphs\fig_firmsizecorrelation.jpg", width(3200) replace

reghdfe Revenue Expend_Service, absorb(county industry soe) vce(cl entid)
reghdfe ln_Revenue ln_Expend_Service, absorb(county industry soe) vce(cl entid)

reghdfe Profitrate Expend_Service, absorb(county industry soe) vce(cl entid)
reghdfe ln_Profitrate ln_Expend_Service, absorb(county industry soe) vce(cl entid)

reghdfe Productivity_L Expend_Service, absorb(county industry soe) vce(cl entid)
reghdfe ln_Productivity_L ln_Expend_Service, absorb(county industry soe) vce(cl entid)

reghdfe Rawmarkup_M Expend_Service, absorb(county industry soe) vce(cl entid)
reghdfe ln_Rawmarkup_M ln_Expend_Service, absorb(county industry soe) vce(cl entid)

label var ln_Revenue " Revenue(log) "
label var ln_Productivity_L " Labor Productivity(log) "
label var ln_Qindex_output " Output Quantity(log) "
label var ln_Pindex_output " Output Price(log) "
label var ln_Rawmarkup_M " Raw Markup(log) "

// drop ln_Expend_Service
// gen ln_Expend_Service = ln(Expend_Service+1)
//
// label var ln_Expend_Service " Service Expend(log) "

reghdfe ln_Revenue ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logR
reghdfe ln_Productivity_L ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logOmegaL
reghdfe ln_Rawmarkup_M ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logRawMuM
reghdfe ln_Qindex_output ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logQ
reghdfe ln_Pindex_output ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logP

outreg2 [motive_logR motive_logOmegaL motive_logRawMuM motive_logQ motive_logP] using "E:\HZhang_Xing\results\outregTables\regtable_motive_logROMQP", tex(fragment) replace bdec(3) sdec(4) ///
label title("Service Inputs' Effects") adjr2 nocons addtext(Industry FE, YES, County FE, YES, Ownership FE, YES, Year FE, YES)


foreach cc in P R D O {
	gen ln_Expend_Service_`cc' = ln(Expend_Service_`cc'+1)
}

label var ln_Expend_Service_P " Production Service(log) "
label var ln_Expend_Service_R " RD-Tech Service(log) "
label var ln_Expend_Service_D " Demand Service(log) "
label var ln_Expend_Service_O " Other Service(log) "

reghdfe ln_Revenue ln_Expend_Service_P ln_Expend_Service_D ln_Expend_Service_O, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logR_2
reghdfe ln_Productivity_L ln_Expend_Service_R, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logOmegaL_2
reghdfe ln_Rawmarkup_M ln_Expend_Service_D, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logRawMuM_2
reghdfe ln_Qindex_output ln_Expend_Service_P ln_Expend_Service_O ln_Expend_Service_R, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logQ_2
reghdfe ln_Pindex_output ln_Expend_Service_D , absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logP_2
	outreg2 [motive_logR_2 motive_logOmegaL_2 motive_logRawMuM_2 motive_logQ_2 motive_logP_2] using "E:\HZhang_Xing\results\outregTables\regtable_motive_logROMQP_H", tex(fragment) replace bdec(3) sdec(4) ///
label title("Service Inputs' Effects") adjr2 nocons addtext(Industry FE, YES, County FE, YES, Ownership FE, YES, Year FE, YES)

reghdfe Revenue Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O, absorb(county industry soe year) vce(cl entid) keepsing

reghdfe ln_Productivity_L ln_Expend_Service_R, absorb(county industry soe year) vce(cl entid) keepsing

reghdfe ln_Rawmarkup_M ln_Expend_Service_D, absorb(county industry soe year) vce(cl entid) keepsing

reghdfe ln_Qindex_output ln_Expend_Service_P ln_Expend_Service_O, absorb(county industry soe year) vce(cl entid) keepsing
