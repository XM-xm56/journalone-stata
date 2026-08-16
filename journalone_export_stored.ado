*! version 0.8.0 15aug2026

capture program drop journalone_export_stored
program define journalone_export_stored, rclass
    version 16.0
    _journalone_require_license
    syntax namelist(name=estimate_names) , SPECS(string)                ///
        RTF(string) CSV(string) TITLE(string)                            ///
        [ RUNID(string) DECIMALS(integer 3) STATISTIC(string)           ///
          LEVEL(real 95) PSTAR1(real .01) PSTAR2(real .05)              ///
          PSTAR3(real .10) ]

    if "`runid'" == "" local runid "reproduced"
    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198

    local estimate_n : word count `estimate_names'
    local spec_n : word count `specs'
    if `estimate_n' == 0 | `estimate_n' != `spec_n' {
        display as error "estimate names and specs() must have the same length"
        exit 198
    }

    tempfile coefficient_data
    tempname result_post
    postfile `result_post' str40 run_id str48 specification str32 outcome ///
        double term_order str96 term double estimate std_error p_value    ///
        ci_low ci_high N r2 r2_a using `coefficient_data', replace

    forvalues index = 1/`estimate_n' {
        local estimate_name : word `index' of `estimate_names'
        local specification : word `index' of `specs'
        estimates restore `estimate_name'
        local outcome `"`e(depvar)'"'
        if strtrim(`"`outcome'"') == "" local outcome "outcome"
        _journalone_post_current, handle(`result_post') runid("`runid'") ///
            spec("`specification'") outcome("`outcome'") level(`level')
    }
    postclose `result_post'

    preserve
    quietly use `coefficient_data', clear
    generate long __posted_order = _n
    bysort specification: egen long __specification_first = min(__posted_order)
    egen long specification_order = group(__specification_first)
    drop __posted_order __specification_first
    sort specification_order term_order

    capture which journalone_publish_outputs
    _journalone_add_spec_labels
    generate str40 analysis_module = "`title'"
    generate double t_value = estimate/std_error
    generate str4 significance = cond(p_value<=`pstar1', "***",          ///
        cond(p_value<=`pstar2', "**", cond(p_value<=`pstar3', "*", ""))) ///
        if !missing(p_value)
    replace significance = "" if missing(significance)
    generate str40 estimate_with_stars =                              ///
        strtrim(string(estimate, "%21.`decimals'f")) + significance  ///
        if !missing(estimate)
    if "`statistic'" == "t" {
        generate double reported_statistic = t_value
        generate str8 statistic_type = "t"
    }
    else {
        generate double reported_statistic = std_error
        generate str8 statistic_type = "SE"
    }
    order analysis_module run_id specification_order specification       ///
        specification_label outcome term_order term term_label estimate  ///
        std_error t_value reported_statistic statistic_type p_value      ///
        significance estimate_with_stars ci_low ci_high N r2 r2_a
    export delimited using `"`csv'"', replace
    _journalone_write_reg_rtf, file(`"`rtf'"') title("`title'")      ///
        decimals(`decimals') statistic("`statistic'")                 ///
        pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3')
    restore

    return local rtf `"`rtf'"'
    return local csv `"`csv'"'
    return scalar models = `estimate_n'
end
