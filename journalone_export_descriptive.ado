*! version 0.9.20 06sep2026

capture program drop journalone_export_descriptive
program define journalone_export_descriptive, rclass
    version 16.0
    _journalone_require_license
    syntax varlist(numeric) [if] , RTF(string) CSV(string) TITLE(string) ///
        [ RUNID(string) DECIMALS(integer 3) ]

    if "`runid'" == "" local runid "reproduced"
    marksample sample, novarlist
    quietly count if `sample'
    local total_n = r(N)
    if `total_n' == 0 exit 2000

    tempfile descriptive_data
    tempname descriptive_post
    postfile `descriptive_post' str40 run_id double variable_order      ///
        str24 variable_role str32 variable str244 variable_label        ///
        double N_total N_nonmissing N_missing mean sd min max           ///
        using `descriptive_data', replace

    local unique_varlist ""
    foreach candidate of local varlist {
        if !strpos(" `unique_varlist' ", " `candidate' ") {
            local unique_varlist "`unique_varlist' `candidate'"
        }
    }
    local order = 0
    foreach variable of local unique_varlist {
        local ++order
        quietly summarize `variable' if `sample'
        local nonmissing = r(N)
        local missing = `total_n' - `nonmissing'
        local variable_label : variable label `variable'
        post `descriptive_post' ("`runid'") (`order') ("reproduced")   ///
            ("`variable'") (`"`variable_label'"') (`total_n')         ///
            (`nonmissing') (`missing') (r(mean)) (r(sd)) (r(min))      ///
            (r(max))
    }
    postclose `descriptive_post'

    preserve
    quietly use `descriptive_data', clear
    generate str40 analysis_module = "`title'"
    order analysis_module run_id variable_order variable_role variable ///
        variable_label
    sort variable_order
    export delimited using `"`csv'"', replace
    capture which journalone_publish_outputs
    _journalone_write_desc_rtf, file(`"`rtf'"') title("`title'")     ///
        decimals(`decimals')
    restore

    return local rtf `"`rtf'"'
    return local csv `"`csv'"'
    return scalar variables = `order'
end
