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


use "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701.dta", clear
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702.dta"
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201703.dta"
collapse (sum) totalvalue_sell price_weighted, by(cid city_sell)
gen Pindex_output = price_weighted/totalvalue_sell
gen Qindex_output = totalvalue_sell/Pindex_output

rename totalvalue_sell Revenue
keep cid city_sell Pindex_output Qindex_output Revenue
gen year = 2017

drop if Pindex_output ==.
drop if Pindex_output<=0
drop if Qindex_output ==.
drop if Qindex_output<=0
drop if Revenue ==.
drop if Revenue<=0

order cid year city_sell Pindex_output Qindex_output Revenue

sort cid

sum Pindex_output Qindex_output Revenue
save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_2017.dta", replace 

* Merge Buyer Set *
use "E:\HZhang_Xing\data\merged_parquet\csv_2017\Buyer_InvoiceService_2017.dta",clear
destring(firmid_Invoice_Buyer), gen(cid)
drop firmid_Invoice_Buyer Service_InputShare
rename(invoicevalue_p invoicevalue_r invoicevalue_d invoicevalue_o invoicevalue_n)(Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O Expend_Material)

//注意：此处的Expend_Service_O里包含了除Production、R&D-Technology、Demand服务业及"（4）Intangible Asset";Expend_Material 里包含了"（1）货物"、"（5）不动产"、"（6）其他不动产"。之后需要重新生成一个只包含了"（1）货物"的Total Value, Price & Quantity的Dataset。

merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_2017.dta"
keep if _merge == 3 //保留既有购买投入又有产出的企业
drop _merge

rename city_sell city

gen Expend_Service = Expend_Service_P + Expend_Service_R + Expend_Service_D + Expend_Service_O

* Merge Entity Code *
merge 1:1 cid using "E:\HZhang_Xing\data\merged_parquet\csv_2017\cid_entid_unique.dta" 
keep if _merge == 3
drop _merge

sort entid year cid
bysort entid year: gen rep_no = _n
drop if rep_no >1
drop rep_no

replace year = 2017 if year ==.

order entid cid id year company_name reg_number org_number usc_code city Revenue Pindex_output Qindex_output Expend_Material Expend_Service Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O

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

order entid year company_name county city industry Revenue Revenue_Huisuan Profit_Huisuan Pindex_output Qindex_output Labor Expend_Capital Expend_Material Expend_Service Expend_Service_P Expend_Service_R Expend_Service_D Expend_Service_O
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

// reghdfe Revenue Expend_Service, absorb(county industry soe) vce(cl entid)
// reghdfe ln_Revenue ln_Expend_Service, absorb(county industry soe) vce(cl entid)
//
// reghdfe Profitrate Expend_Service, absorb(county industry soe) vce(cl entid)
// reghdfe ln_Profitrate ln_Expend_Service, absorb(county industry soe) vce(cl entid)
//
// reghdfe Productivity_L Expend_Service, absorb(county industry soe) vce(cl entid)
// reghdfe ln_Productivity_L ln_Expend_Service, absorb(county industry soe) vce(cl entid)
//
// reghdfe Rawmarkup_M Expend_Service, absorb(county industry soe) vce(cl entid)
// reghdfe ln_Rawmarkup_M ln_Expend_Service, absorb(county industry soe) vce(cl entid)

label var ln_Revenue " Revenue(log) "
label var ln_Productivity_L " Labor Productivity(log) "
label var ln_Qindex_output " Output Quantity(log) "
label var ln_Pindex_output " Output Price(log) "

reghdfe ln_Revenue ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logR
reghdfe ln_Productivity_L ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logOmegaL
reghdfe ln_Qindex_output ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logQ
reghdfe ln_Pindex_output ln_Expend_Service, absorb(county industry soe year) vce(cl entid) keepsing
	est store motive_logP

outreg2 [motive_logR motive_logOmegaL motive_logQ motive_logP] using "E:\HZhang_Xing\results\outregTables\regtable_motive_logROQP", tex(fragment) replace bdec(3) sdec(4) ///
label title("Service Inputs' Effects") adjr2 nocons addtext(Industry FE, YES, County FE, YES, Ownership FE, YES, Year FE, YES)




