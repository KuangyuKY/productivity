set scheme s1color, permanently

// use "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_GX201701.dta" ,clear
// collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)
//
// save "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701.dta" ,replace 

* Construct Seller Set *
clear 
import delimited "E:\HZhang_Xing\data\GX1701_Seller.csv"
rename (销方企业id 销方地区 单价 totalvalue totalquantity)(cid city_sell price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop
collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701.dta" ,replace 

clear
import delimited "E:\HZhang_Xing\data\GX1702_Seller.csv"
rename (销方企业id 销方地区 单价 totalvalue totalquantity)(cid city_sell price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop
collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702.dta" ,replace 


clear
import delimited "E:\HZhang_Xing\data\GX1703_Seller.csv"
rename (销方企业id 销方地区 单价 totalvalue totalquantity)(cid city_sell price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop
collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201703.dta" ,replace 


clear
import delimited "E:\HZhang_Xing\data\GX1801_Seller.csv"
rename (销方企业id weightedprice_output totalvalue_output)(cid price_weighted totalvalue_sell)
gen year = 2018

collapse (sum) totalvalue_sell price_weighted, by(cid year)
save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201801.dta" ,replace 

clear
import delimited "E:\HZhang_Xing\data\GX1802_Seller.csv"
rename (销方企业id weightedprice_output totalvalue_output)(cid price_weighted totalvalue_sell)
gen year = 2018

collapse (sum) totalvalue_sell price_weighted, by(cid year )
save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201802.dta" ,replace 


use "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701.dta", clear
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702.dta"
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201703.dta"
drop city_sell
gen year = 2017
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702.dta"
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201703.dta"

collapse (sum) totalvalue_sell price_weighted, by(cid year)
gen Pindex_output = price_weighted/totalvalue_sell
gen Qindex_output = totalvalue_sell/Pindex_output

rename totalvalue_sell Revenue
keep cid year Pindex_output Qindex_output Revenue

drop if Pindex_output ==.
drop if Pindex_output<=0
drop if Qindex_output ==.
drop if Qindex_output<=0
drop if Revenue ==.
drop if Revenue<=0

order cid year Pindex_output Qindex_output Revenue

sort cid

sum Pindex_output Qindex_output Revenue
save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_20172018.dta", replace 

* Merge Material Inputs *
clear
import delimited "E:\HZhang_Xing\data\GX1701_Expend_Material.csv"
rename 购方企业id cid

gen year = 2017

save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201701.dta"

clear
import delimited "E:\HZhang_Xing\data\GX1702_Expend_Material.csv"
rename 购方企业id cid

gen year = 2017

save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201702.dta"

clear
import delimited "E:\HZhang_Xing\data\GX1703_Expend_Material.csv"
rename 购方企业id cid

gen year = 2017

save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201703.dta"

clear
import delimited "E:\HZhang_Xing\data\GX1801_Expend_Material.csv"
rename 购方企业id cid

gen year = 2018

save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201801.dta"

clear
import delimited "E:\HZhang_Xing\data\GX1802_Expend_Material.csv"
rename 购方企业id cid

gen year = 2018

save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201802.dta"

use "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201701.dta", clear
append using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201702.dta"
append using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201703.dta"
append using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201801.dta"
append using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInf_forAppend_GX201802.dta"

collapse (sum) weightedprice_material expend_material, by(cid year)
gen Pindex_material = weightedprice_material/expend_material
gen Qindex_material = expend_material/Pindex_material

rename expend_material Expend_Material
keep cid year Pindex_material Qindex_material Expend_Material

drop if Pindex_material ==.
drop if Pindex_material <=0
drop if Qindex_material ==.
drop if Qindex_material <=0
drop if Expend_Material ==.
drop if Expend_Material <=0

order cid year Pindex_material Qindex_material Expend_Material

sort cid

sum Pindex_material Qindex_material Expend_Material
save "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInfo_20172018.dta", replace 

use "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_20172018.dta",clear
merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceBuyData\BuyerInfo_20172018.dta"
keep if _merge == 3
drop _merge
save "E:\HZhang_Xing\data\SellExpendMInfo_20172018.dta", replace





use "H:\BaiduNetdiskDownload\汇算file\final_joinby_matched_data_2017_With_cid.dta",clear 
bysort id: gen temp_repo_no =_n
drop if temp_repo_no > 1
drop temp_repo_no

save "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2017_With_cid_distinctid.dta", replace







* Merge Service Input Set *
use "E:\HZhang_Xing\data\merged_parquet\csv_2017\Buyer_InvoiceService_2017.dta",clear
destring(firmid_Invoice_Buyer), gen(cid)
drop firmid_Invoice_Buyer Service_InputShare
rename(invoicevalue_p invoicevalue_r invoicevalue_d invoicevalue_o)(Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O)

//注意：此处的Expend_Service_O里包含了除Production、R&D-Technology、Demand服务业及"（4）Intangible Asset";Expend_Material 里包含了"（1）货物"、"（5）不动产"、"（6）其他不动产"。之后需要重新生成一个只包含了"（1）货物"的Total Value, Price & Quantity的Dataset。

merge 1:1 cid year using "E:\HZhang_Xing\data\SellExpendMInfo_20172018.dta"
keep if _merge == 3 //保留既有购买投入又有产出的企业
drop _merge


gen Expend_Service = Expend_Service_P + Expend_Service_R + Expend_Service_D + Expend_Service_O
* Merge Entity Code *
* Merge Entity Code *
tostring cid, replace
merge 1:1 cid using "F:\SupplyChain\Data\firmdata\identifier\cid_company_id_14-18_short.dta"
keep if _merge == 3
drop _merge

bysort id: gen temp_repo_no =_n
drop if temp_repo_no > 1
drop temp_repo_no

merge 1:1 id using "E:\HZhang_Xing\data\InvoiceSellData\final_joinby_matched_data_2017_With_cid_distinctid.dta"











sort entid year cid
bysort entid year: gen rep_no = _n
drop if rep_no >1
drop rep_no

replace year = 2017 if year ==.

order entid cid id year company_name reg_number org_number usc_code Revenue Pindex_output Qindex_output Expend_Material Expend_Service Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O

save "E:\HZhang_Xing\data\InvoiceSellData\SellBuyInfo_Entyid_2017.dta", replace

use "E:\HZhang_Xing\data\InvoiceSellData\SellBuyInfo_Entyid_2017.dta", clear
gen r = ln( Revenue )
gen q = ln( Qindex_output )
gen p = ln( Pindex_output )
gen es = ln(Expend_Service )

reghdfe r es, absorb(soe) vce(cl entid)
reghdfe r es, absorb(soe city) vce(cl entid)

reghdfe q es, absorb(soe) vce(cl entid)
reghdfe q es, absorb(soe city) vce(cl entid)

reghdfe p es, absorb(soe) vce(cl entid)
reghdfe p es, absorb(soe city) vce(cl entid)


* Merge Labor from 汇算数据*
use "H:\汇算数据\2017.dta", clear
gen year = 2017
bysort id year: gen rep_no = _n
drop if rep_no >1
drop rep_no
merge 1:1 id using "E:\HZhang_Xing\data\InvoiceSellData\SellBuyInfo_Entyid_2017.dta"
keep if _merge == 3
drop _merge
rename (所在区域 行业代码 从业人数 净利润 b收入总额 资产总额 ) (county industry Labor Profit_Huisuan Revenue_Huisuan Expend_Capital)

order entid year company_name county industry Revenue Revenue_Huisuan Profit_Huisuan Pindex_output Qindex_output Labor Expend_Capital Expend_Material Expend_Service Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O
save "E:\HZhang_Xing\data\sample\SellBuyInfo_Entyid_2017.dta", replace


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
