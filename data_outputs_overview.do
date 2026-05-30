clear all
set more off
capture log close
log using "data_outputs_overview_latest.log", replace text

* ============================================================
* Overview stats for 01_clean outputs and reg_panel
* ============================================================

foreach f in invoice_panel market_conds firm_chars reg_panel {
    display ""
    display "===== `f'.dta ====="
    use "`f'.dta", clear
    count
    display "rows: " r(N)
    describe, short

    capture confirm variable firm_id
    if _rc == 0 {
        bysort firm_id: gen tag_firm = (_n == 1)
        count if tag_firm
        display "distinct firm_id: " r(N)
        drop tag_firm
    }

    capture confirm variable product_id
    if _rc == 0 {
        bysort product_id: gen tag_product = (_n == 1)
        count if tag_product
        display "distinct product_id: " r(N)
        drop tag_product
    }

    capture confirm variable city
    if _rc == 0 {
        bysort city: gen tag_city = (_n == 1)
        count if tag_city
        display "distinct city: " r(N)
        drop tag_city
    }

    capture confirm variable year
    if _rc == 0 {
        tab year
    }

    capture confirm variable ln_Capital
    if _rc == 0 {
        count if !missing(ln_Capital)
        display "nonmissing ln_Capital: " r(N)
        count if missing(ln_Capital)
        display "missing ln_Capital: " r(N)
    }

    capture confirm variable is_intermediary
    if _rc == 0 {
        tab is_intermediary, missing
    }

    capture confirm variable input_similarity
    if _rc == 0 {
        count if !missing(input_similarity)
        display "nonmissing input_similarity: " r(N)
        count if missing(input_similarity)
        display "missing input_similarity: " r(N)
    }

    capture confirm variable output_similarity
    if _rc == 0 {
        count if !missing(output_similarity)
        display "nonmissing output_similarity: " r(N)
        count if missing(output_similarity)
        display "missing output_similarity: " r(N)
    }
}

log close
exit
