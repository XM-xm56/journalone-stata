*! version 0.9.8 17aug2026

capture program drop _journalone_write_baseline_rtf
program define _journalone_write_baseline_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198
    sort specification_order term_order
    quietly count
    if r(N) == 0 exit 2000

    capture confirm variable r2_a
    if _rc generate double r2_a = .

    local specifications ""
    local terms ""
    local has_constant = 0
    forvalues row = 1/`=_N' {
        local this_specification = specification[`row']
        if !strpos(" `specifications' ", " `this_specification' ") {
            local specifications "`specifications' `this_specification'"
        }
        local this_term = term[`row']
        if "`this_term'" == "_cons" {
            local has_constant = 1
        }
        else if !strpos(" `terms' ", " `this_term' ") {
            local terms "`terms' `this_term'"
        }
    }
    local specifications = strtrim("`specifications'")
    local terms = strtrim("`terms'")
    * esttab-style order: explanatory variables first and the constant last,
    * even when model 1 contains fewer controls than later columns.
    if `has_constant' local terms = strtrim("`terms' _cons")
    local model_count : word count `specifications'
    if `model_count' < 1 | `model_count' > 4 exit 198

    forvalues model_index = 1/`model_count' {
        local this_specification : word `model_index' of `specifications'
        forvalues row = 1/`=_N' {
            if specification[`row'] == "`this_specification'" {
                local outcome`model_index' = outcome[`row']
                local n`model_index' = N[`row']
                local fit`model_index' = r2_a[`row']
                if missing(`fit`model_index'') local fit`model_index' = r2[`row']
                continue, break
            }
        }
    }

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    local table_tabs ""
    forvalues model_index = 1/`model_count' {
        local tab_position = 2800 + floor(7600*(`model_index'-.5)/`model_count')
        local table_tabs "`table_tabs'\tqc\tx`tab_position'"
    }

    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    * ISO A4 portrait and Word 1.5-line spacing.
    file write `rtf_handle' "\paperw11907\paperh16840\margl720\margr720\margt720\margb720" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\b\f0\fs24 `rtf_title'\b0\par" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\f0\fs18\par" _n

    * First and second publication rules surround the two-line model header.
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20`table_tabs'\ql "
    forvalues model_index = 1/`model_count' {
        local model_header "(`model_index')"
        _journalone_rtf_escape, text(`"`model_header'"')
        file write `rtf_handle' "\tab\qc\b `r(escaped)'\b0"
    }
    file write `rtf_handle' "\par" _n

    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw10\brsp20`table_tabs'\ql "
    forvalues model_index = 1/`model_count' {
        _journalone_rtf_escape, text(`"`outcome`model_index''"')
        file write `rtf_handle' "\tab\qc\b `r(escaped)'\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    foreach this_term of local terms {
        _journalone_rtf_escape, text(`"`this_term'"')
        local rtf_term `"`r(escaped)'"'
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `rtf_term'"
        forvalues model_index = 1/`model_count' {
            local coefficient ""
            local this_specification : word `model_index' of `specifications'
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" & term[`row'] == "`this_term'" {
                    local stars ""
                    if !missing(p_value[`row']) {
                        if p_value[`row'] <= `pstar1' local stars "***"
                        else if p_value[`row'] <= `pstar2' local stars "**"
                        else if p_value[`row'] <= `pstar3' local stars "*"
                    }
                    local coefficient = strtrim(string(estimate[`row'], "`number_format'")) + "`stars'"
                    continue, break
                }
            }
            _journalone_rtf_escape, text(`"`coefficient'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql "
        forvalues model_index = 1/`model_count' {
            local reported_stat ""
            local this_specification : word `model_index' of `specifications'
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" & term[`row'] == "`this_term'" {
                    if "`statistic'" == "t" {
                        local reported_stat = strtrim(string(estimate[`row']/std_error[`row'], "`number_format'"))
                    }
                    else local reported_stat = strtrim(string(std_error[`row'], "`number_format'"))
                    local reported_stat "(`reported_stat')"
                    continue, break
                }
            }
            _journalone_rtf_escape, text(`"`reported_stat'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n
    }

    _journalone_rtf_escape, text("N")
    file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `r(escaped)'"
    forvalues model_index = 1/`model_count' {
        local n_display = strtrim(string(`n`model_index'', "%12.0f"))
        _journalone_rtf_escape, text(`"`n_display'"')
        file write `rtf_handle' "\tab\qc `r(escaped)'"
    }
    file write `rtf_handle' "\par" _n

    _journalone_rtf_escape, text("Adjusted R²")
    local fit_label `"`r(escaped)'"'
    file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw20\brsp20`table_tabs'\ql `fit_label'"
    forvalues model_index = 1/`model_count' {
        local fit_display ""
        if !missing(`fit`model_index'') local fit_display = strtrim(string(`fit`model_index'', "`number_format'"))
        _journalone_rtf_escape, text(`"`fit_display'"')
        file write `rtf_handle' "\tab\qc `r(escaped)'"
    }
    file write `rtf_handle' "\par" _n

    local statistic_note "Standard errors in parentheses"
    if "`statistic'" == "t" local statistic_note "t statistics in parentheses"
    _journalone_rtf_escape, text(`"`statistic_note'"')
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    local star_note "* p < `pstar3', ** p < `pstar2', *** p < `pstar1'"
    _journalone_rtf_escape, text(`"`star_note'"')
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(baseline) ///
        title(`"`title'"') decimals(`decimals') pstar1(`pstar1') ///
        pstar2(`pstar2') pstar3(`pstar3')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
