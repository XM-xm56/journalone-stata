*! version 0.5.0 14aug2026
capture program drop journalone_format_outputs
program define journalone_format_outputs, rclass
    version 16.0
    _journalone_require_license
    syntax , RESULTBASE(string)                                  ///
        [ RESULTS(string) DESCRIPTIVE(string) DECIMALS(integer 3) STATISTIC(string) ///
          PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)            ///
          REPORTMODE(string) SPLITHET SPLITMED ]

    local report_file ""
    if "`statistic'" == "" local statistic "se"
    if "`reportmode'" == "" local reportmode "none"
    local number_format "%21.`decimals'f"
    local has_results = 0
    if strtrim(`"`results'"') != "" {
        capture confirm file `"`results'"'
        if _rc exit _rc
        local has_results = 1
    }

    if `has_results' {
        preserve
        quietly use `"`results'"', clear
        capture drop t_value stars estimate_display statistic_display p_value_display ci_display
        generate double t_value = estimate/std_error
        generate str4 stars = cond(p_value<=`pstar1', "***", ///
            cond(p_value<=`pstar2', "**", cond(p_value<=`pstar3', "*", ""))) if !missing(p_value)
        replace stars = "" if missing(stars)
        generate str32 estimate_display = trim(string(estimate, "`number_format'")) if !missing(estimate)
        if "`statistic'" == "t" {
            generate str32 statistic_display = trim(string(t_value, "`number_format'")) if !missing(t_value)
            label variable statistic_display "t值"
        }
        else {
            generate str32 statistic_display = trim(string(std_error, "`number_format'")) if !missing(std_error)
            label variable statistic_display "标准误"
        }
        generate str32 p_value_display = trim(string(p_value, "`number_format'")) if !missing(p_value)
        generate str80 ci_display = "[" + trim(string(ci_low, "`number_format'")) + ", " + ///
            trim(string(ci_high, "`number_format'")) + "]" if !missing(ci_low, ci_high)
        label variable term "变量"
        label variable estimate_display "系数"
        label variable p_value_display "p值"
        label variable stars "显著性"
        sort specification_order term_order
        save `"`results'"', replace
        local results_csv = subinstr(`"`results'"', ".dta", ".csv", .)
        export delimited using `"`results_csv'"', replace
        restore
    }

    // Stata does not allow nested preserve/restore.  Re-open the saved
    // result dataset for each optional split so the caller's data remain
    // untouched and each split is independent.
    if `has_results' & "`splitmed'" != "" {
        preserve
        quietly use `"`results'"', clear
        keep if substr(specification,1,4) == "med_"
        if _N > 0 {
            save `"`resultbase'_mediation.dta"', replace
            export delimited using `"`resultbase'_mediation.csv"', replace
        }
        restore
    }
    if `has_results' & "`splithet'" != "" {
        preserve
        quietly use `"`results'"', clear
        keep if substr(specification,1,6) == "group_"
        if _N > 0 {
            save `"`resultbase'_heterogeneity.dta"', replace
            export delimited using `"`resultbase'_heterogeneity.csv"', replace
        }
        restore
    }

    if strtrim(`"`descriptive'"') != "" {
        capture confirm file `"`descriptive'"'
        if !_rc {
            preserve
            quietly use `"`descriptive'"', clear
            capture drop mean_display sd_display min_display max_display
            foreach descriptive_stat in mean sd min max {
                generate str32 `descriptive_stat'_display = ///
                    trim(string(`descriptive_stat', "`number_format'")) if !missing(`descriptive_stat')
            }
            sort variable_order
            save `"`descriptive'"', replace
            local descriptive_csv = subinstr(`"`descriptive'"', ".dta", ".csv", .)
            export delimited using `"`descriptive_csv'"', replace
            restore
        }
    }

    if inlist("`reportmode'", "docx", "docx_open") {
        capture noisily putdocx clear
        capture noisily putdocx begin
        if _rc exit _rc
        putdocx paragraph, style(Title)
        if `has_results' putdocx text ("JournalOne 实证分析报告")
        else putdocx text ("JournalOne 描述性统计报告")
        if `has_results' {
            putdocx paragraph
            putdocx text ("主模型系数；星号阈值：*** p<=`pstar1'，** p<=`pstar2'，* p<=`pstar3'。")
            preserve
            quietly use `"`results'"', clear
            quietly keep if specification == "main"
            quietly keep term estimate_display statistic_display p_value_display stars
            putdocx table main_results = data(term estimate_display statistic_display p_value_display stars), varnames
            restore
        }
        if strtrim(`"`descriptive'"') != "" {
            capture confirm file `"`descriptive'"'
            if !_rc {
                putdocx paragraph, style(Heading1)
                putdocx text ("描述性统计")
                preserve
                quietly use `"`descriptive'"', clear
                quietly keep variable N_nonmissing mean_display sd_display min_display max_display
                putdocx table descriptive_results = data(variable N_nonmissing mean_display sd_display min_display max_display), varnames
                restore
            }
        }
        local report_file `"`resultbase'_report.docx"'
        capture noisily putdocx save `"`report_file'"', replace
        if _rc local report_file ""
        else if "`reportmode'" == "docx_open" {
            capture noisily winexec `"`report_file'"'
        }
    }

    return local report_file `"`report_file'"'
end
