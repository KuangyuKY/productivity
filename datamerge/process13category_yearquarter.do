

import delimited "E:\HZhang_Xing\data\GX1702_13categories_yearmonth_less10000000.csv",clear
save "E:\HZhang_Xing\data\GX1702_13categories_yearmonth.dta", replace

import delimited "E:\HZhang_Xing\data\GX1703_13categories_yearmonth_less10000000.csv",clear
save "E:\HZhang_Xing\data\GX1703_13categories_yearmonth.dta", replace


import delimited "E:\HZhang_Xing\data\GX1701_13categories_yearmonth_less10000000.csv",clear
save "E:\HZhang_Xing\data\GX1701_13categories_yearmonth.dta", replace

append using "E:\HZhang_Xing\data\GX1702_13categories_yearmonth.dta"
gen yearquarter = .
replace yearquarter = 20171 if yearmonth >= 201701 & yearmonth <= 201703
replace yearquarter = 20172 if yearmonth >= 201704 & yearmonth <= 201706
replace yearquarter = 20173 if yearmonth >= 201707 & yearmonth <= 201709
replace yearquarter = 20174 if yearmonth >= 201710 & yearmonth <= 201712

collapse(sum) totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti weightedprice_e weightedprice_i weightedprice_m weightedprice_s_p weightedprice_s_r weightedprice_s_d weightedprice_s_a weightedprice_s_t weightedprice_s_o weightedprice_ia weightedprice_nr weightedprice_re weightedprice_nti, by(购方企业id yearquarter)

append using "E:\HZhang_Xing\data\GX1703_13categories_yearmonth.dta"
collapse(sum) totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti weightedprice_e weightedprice_i weightedprice_m weightedprice_s_p weightedprice_s_r weightedprice_s_d weightedprice_s_a weightedprice_s_t weightedprice_s_o weightedprice_ia weightedprice_nr weightedprice_re weightedprice_nti, by(购方企业id yearquarter)


save "E:\HZhang_Xing\data\Input13categories_2017_yearquarter.dta", replace

// ******* 2018 **********
// foreach yy in 18_01_1 18_01_2 18_02_1 18_02_2 18_03_1 18_03_2 18_04_1 18_04_2 18_05_1 18_05_2 18_06_1 18_06_2 18_06_3 18_07_1 18_07_2 18_07_3 18_08_1 18_08_2 18_08_3 18_09_1 18_09_2 18_09_3 18_10_1 18_10_2 18_10_3 18_11_1 18_11_2 18_12_1 18_12_2{
//     import delimited "E:\HZhang_Xing\data\GX_`yy'_13categories.csv",clear
// 	collapse(sum) totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti totalweightedprice_e totalweightedprice_i totalweightedprice_m totalweightedprice_s_p totalweightedprice_s_r totalweightedprice_s_d totalweightedprice_s_a totalweightedprice_s_t totalweightedprice_s_o totalweightedprice_ia totalweightedprice_nr totalweightedprice_re totalweightedprice_nti, by(购方企业id)
// 	save "E:\HZhang_Xing\data\GX`yy'_13categories.dta", replace
// }
//
// use "E:\HZhang_Xing\data\GX18_01_1_13categories.dta", clear
// foreach yy in 18_01_2 18_02_1 18_02_2 18_03_1 18_03_2 18_04_1 18_04_2 18_05_1 18_05_2 18_06_1 18_06_2 18_06_3 18_07_1 18_07_2 18_07_3 18_08_1 18_08_2 18_08_3 18_09_1 18_09_2 18_09_3 18_10_1 18_10_2 18_10_3 18_11_1 18_11_2 18_12_1 18_12_2{
//     append using "E:\HZhang_Xing\data\GX`yy'_13categories.dta"
// 	collapse(sum) totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti totalweightedprice_e totalweightedprice_i totalweightedprice_m totalweightedprice_s_p totalweightedprice_s_r totalweightedprice_s_d totalweightedprice_s_a totalweightedprice_s_t totalweightedprice_s_o totalweightedprice_ia totalweightedprice_nr totalweightedprice_re totalweightedprice_nti, by(购方企业id)
// }
//
// gen year = 2018
// save "E:\HZhang_Xing\data\Input13categories_2018.dta", replace
//
// rename (totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti totalweightedprice_e totalweightedprice_i totalweightedprice_m totalweightedprice_s_p totalweightedprice_s_r totalweightedprice_s_d totalweightedprice_s_a totalweightedprice_s_t totalweightedprice_s_o totalweightedprice_ia totalweightedprice_nr totalweightedprice_re totalweightedprice_nti) (totalvalue_e totalvalue_i totalvalue_m totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti weightedprice_e weightedprice_i weightedprice_m weightedprice_s_p weightedprice_s_r weightedprice_s_d weightedprice_s_a weightedprice_s_t weightedprice_s_o weightedprice_ia weightedprice_nr weightedprice_re weightedprice_nti)
// append using "E:\HZhang_Xing\data\Input13categories_2017.dta"
//
// order 购方企业id year
// sort 购方企业id year
// save "E:\HZhang_Xing\data\Input13categories_20172018.dta", replace
//
//
//
//
// use "E:\HZhang_Xing\data\Input13categories_20172018.dta", clear
//
// foreach cc in e i m s_p s_r s_d s_a s_t s_o ia nr re nti{
// 	gen Pindex_INP_`cc' = weightedprice_`cc'/totalvalue_`cc'
// 	gen Qindex_INP_`cc' = totalvalue_`cc'/Pindex_INP_`cc'
// }



* Construct Seller Set *
clear 
import delimited "E:\HZhang_Xing\data\GX1701_Seller_yearmonth_less10000000.csv"
rename (销方企业id 单价 totalvalue totalquantity)(cid price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop

gen yearquarter = .
replace yearquarter = 20171 if yearmonth >= 201701 & yearmonth <= 201703
replace yearquarter = 20172 if yearmonth >= 201704 & yearmonth <= 201706
replace yearquarter = 20173 if yearmonth >= 201707 & yearmonth <= 201709
replace yearquarter = 20174 if yearmonth >= 201710 & yearmonth <= 201712
collapse (sum) totalvalue_sell price_weighted, by(cid yearquarter)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701_yearquarter_less10000000.dta" ,replace 

clear
import delimited "E:\HZhang_Xing\data\GX1702_Seller_yearmonth_less10000000.csv"
rename (销方企业id 单价 totalvalue totalquantity)(cid price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop

gen yearquarter = .
replace yearquarter = 20171 if yearmonth >= 201701 & yearmonth <= 201703
replace yearquarter = 20172 if yearmonth >= 201704 & yearmonth <= 201706
replace yearquarter = 20173 if yearmonth >= 201707 & yearmonth <= 201709
replace yearquarter = 20174 if yearmonth >= 201710 & yearmonth <= 201712
collapse (sum) totalvalue_sell price_weighted, by(cid yearquarter)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702_yearquarter_less10000000.dta" ,replace 


clear
import delimited "E:\HZhang_Xing\data\GX1703_Seller_yearmonth_less10000000.csv"
rename (销方企业id 单价 totalvalue totalquantity)(cid price_sell totalvalue_sell totalquantity_sell)
drop totalquantity_sell
gen price_weighted = price_sell*totalvalue_sell
duplicates drop

gen yearquarter = .
replace yearquarter = 20171 if yearmonth >= 201701 & yearmonth <= 201703
replace yearquarter = 20172 if yearmonth >= 201704 & yearmonth <= 201706
replace yearquarter = 20173 if yearmonth >= 201707 & yearmonth <= 201709
replace yearquarter = 20174 if yearmonth >= 201710 & yearmonth <= 201712
collapse (sum) totalvalue_sell price_weighted, by(cid yearquarter)

save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201703_yearquarter_less10000000.dta" ,replace 


// clear
// import delimited "E:\HZhang_Xing\data\GX1801_Seller.csv"
// rename (销方企业id weightedprice_output totalvalue_output)(cid price_weighted totalvalue_sell)
// gen year = 2018
//
// collapse (sum) totalvalue_sell price_weighted, by(cid year)
// save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201801.dta" ,replace 
//
// clear
// import delimited "E:\HZhang_Xing\data\GX1802_Seller.csv"
// rename (销方企业id weightedprice_output totalvalue_output)(cid price_weighted totalvalue_sell)
// gen year = 2018
//
// collapse (sum) totalvalue_sell price_weighted, by(cid year )
// save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201802.dta" ,replace 


use "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201701_yearquarter_less10000000.dta", clear
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInf_forAppend_GX201702_yearquarter_less10000000.dta"
append using "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_forAppend_GX201703_yearquarter_less10000000.dta"

collapse (sum) totalvalue_sell price_weighted, by(cid yearquarter)
gen Pindex_output = price_weighted/totalvalue_sell
gen Qindex_output = totalvalue_sell/Pindex_output

rename totalvalue_sell Revenue
keep cid yearquarter Pindex_output Qindex_output Revenue

drop if Pindex_output ==.
drop if Pindex_output<=0
drop if Qindex_output ==.
drop if Qindex_output<=0
drop if Revenue ==.
drop if Revenue<=0

order cid yearquarter Pindex_output Qindex_output Revenue

sort cid

sum Pindex_output Qindex_output Revenue
save "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_2017_yearquarter_less10000000.dta", replace




* Merge Seller and Buyer 
// use "E:\HZhang_Xing\data\Input13categories_2017_yearmonth.dta", clear
//
// merge 1:1 cid year using "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_2017_yearmonth_less10000000.dta"
// drop _merge
//
// rename totalvalue_m Exp_M
// order cid year Revenue Pindex_output Qindex_output Exp_M Pindex_INP_m Qindex_INP_m
// sort cid year
//
// foreach vv in Revenue Pindex_output Qindex_output Exp_M Pindex_INP_m Qindex_INP_m totalvalue_e totalvalue_i totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti Pindex_INP_e Qindex_INP_e Pindex_INP_i Qindex_INP_i Pindex_INP_s_p Qindex_INP_s_p Pindex_INP_s_r Qindex_INP_s_r Pindex_INP_s_d Qindex_INP_s_d Pindex_INP_s_a Qindex_INP_s_a Pindex_INP_s_t Qindex_INP_s_t Pindex_INP_s_o Qindex_INP_s_o Pindex_INP_ia Qindex_INP_ia Pindex_INP_nr Qindex_INP_nr Pindex_INP_re Qindex_INP_re Pindex_INP_nti Qindex_INP_nti{
// 	replace `vv' = 0 if `vv' ==.
// 	rename `vv' VAT_`vv'
// }
//
// save "E:\HZhang_Xing\data\VAT_SellandInput13categories_2017_yearmonth.dta", replace
//
//
//
// * Merge Seller and Buyer
// use "E:\HZhang_Xing\data\Input13categories_20172018.dta", clear
//
// foreach cc in e i m s_p s_r s_d s_a s_t s_o ia nr re nti{
// 	gen Pindex_INP_`cc' = weightedprice_`cc'/totalvalue_`cc'
// 	gen Qindex_INP_`cc' = totalvalue_`cc'/Pindex_INP_`cc'
// }
//
//
//
// keep cid year Pindex_* Qindex_*  totalvalue_*

use "E:\HZhang_Xing\data\Input13categories_2017_yearquarter.dta", clear

foreach cc in e i m s_p s_r s_d s_a s_t s_o ia nr re nti{
	gen Pindex_INP_`cc' = weightedprice_`cc'/totalvalue_`cc'
	gen Qindex_INP_`cc' = totalvalue_`cc'/Pindex_INP_`cc'
}


rename 购方企业id cid
keep cid yearquarter Pindex_* Qindex_*  totalvalue_*

merge 1:1 cid yearquarter using "E:\HZhang_Xing\data\InvoiceSellData\SellerInfo_2017_yearquarter_less10000000.dta"
keep if _merge == 3
drop _merge

rename totalvalue_m Exp_M
order cid yearquarter Revenue Pindex_output Qindex_output Exp_M Pindex_INP_m Qindex_INP_m
sort cid yearquarter

foreach vv in Revenue Pindex_output Qindex_output Exp_M Pindex_INP_m Qindex_INP_m totalvalue_e totalvalue_i totalvalue_s_p totalvalue_s_r totalvalue_s_d totalvalue_s_a totalvalue_s_t totalvalue_s_o totalvalue_ia totalvalue_nr totalvalue_re totalvalue_nti Pindex_INP_e Qindex_INP_e Pindex_INP_i Qindex_INP_i Pindex_INP_s_p Qindex_INP_s_p Pindex_INP_s_r Qindex_INP_s_r Pindex_INP_s_d Qindex_INP_s_d Pindex_INP_s_a Qindex_INP_s_a Pindex_INP_s_t Qindex_INP_s_t Pindex_INP_s_o Qindex_INP_s_o Pindex_INP_ia Qindex_INP_ia Pindex_INP_nr Qindex_INP_nr Pindex_INP_re Qindex_INP_re Pindex_INP_nti Qindex_INP_nti{
	replace `vv' = 0 if `vv' ==.
	rename `vv' VAT_`vv'
}
gen year = 2017
save "E:\HZhang_Xing\data\VAT_SellandInput13categories_2017_yearquarter.dta", replace
