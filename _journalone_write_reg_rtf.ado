*! version 0.9.18 05sep2026

capture program drop _journalone_write_reg_rtf
program define _journalone_write_reg_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)                 ///
        MODEL(string) CONTROLS(string) ABSORB(string) PANEL(string)       ///
        TIME(string) TIMEFE HECKMANFE ADDCONTROLS(string) ADDFE(string)]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198

    sort specification_order term_order
    quietly count
    if r(N) == 0 exit 2000
    capture confirm variable r2_a
    if _rc generate double r2_a = .
    capture confirm variable specification_label
    local has_specification_label = (_rc == 0)
    capture confirm variable term_label
    local has_term_label = (_rc == 0)

    local specifications ""
    local terms ""
    local has_constant = 0
    forvalues row = 1/`=_N' {
        local this_specification = specification[`row']
        if !strpos(" `specifications' ", " `this_specification' ") {
            local specifications "`specifications' `this_specification'"
        }
        local this_term = term[`row']
        if "`this_term'" == "_cons" local has_constant = 1
        else if !strpos(" `terms' ", " `this_term' ") {
            local terms "`terms' `this_term'"
        }
    }
    local specifications = strtrim("`specifications'")
    local terms = strtrim("`terms'")
    if `has_constant' local terms = strtrim("`terms' _cons")
    local specification_count : word count `specifications'
    if `specification_count' < 1 exit 2000

    * Match the baseline-table layout: A4 portrait with at most four model
    * columns. Additional specifications continue on a new page while
    * retaining the same variable row order.
    local table_capacity = 4
    local table_count = ceil(`specification_count'/`table_capacity')
    if `table_count' < 1 local table_count = 1

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    * ISO A4 portrait, using the same margins as descriptive and baseline RTFs.
    file write `rtf_handle' "\paperw11907\paperh16840\margl720\margr720\margt720\margb720" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\b\f0\fs24 `rtf_title'\b0\par" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\f0\fs18\par" _n

    local number_format "%21.`decimals'f"
    forvalues table_index = 1/`table_count' {
        local first_spec = (`table_index' - 1) * `table_capacity' + 1
        local last_spec = min(`table_index' * `table_capacity', `specification_count')
        local table_specs ""
        forvalues spec_index = `first_spec'/`last_spec' {
            local this_specification : word `spec_index' of `specifications'
            local table_specs "`table_specs' `this_specification'"
        }
        local table_specs = strtrim("`table_specs'")
        local model_count : word count `table_specs'
        if `model_count' < 1 continue

        if `table_count' > 1 {
            local table_caption "`title'（第`table_index'组，共`table_count'组）"
            _journalone_rtf_escape, text(`"`table_caption'"')
            file write `rtf_handle' "\pard\ql\sb120\sa0\sl360\slmult1\b\f0\fs18 `r(escaped)'\b0\par" _n
        }

        forvalues model_index = 1/`model_count' {
            local this_specification : word `model_index' of `table_specs'
            local outcome`model_index' ""
            local n`model_index' = .
            local fit`model_index' = .
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

        local table_tabs ""
        forvalues model_index = 1/`model_count' {
            local tab_position = 2800 + floor(7600*(`model_index'-.5)/`model_count')
            local table_tabs "`table_tabs'\tqc\tx`tab_position'"
        }

        _journalone_rtf_escape, text("模型")
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20`table_tabs'\ql\b `r(escaped)'\b0"
        forvalues model_index = 1/`model_count' {
            local model_header "(`model_index')"
            _journalone_rtf_escape, text(`"`model_header'"')
            file write `rtf_handle' "\tab\qc\b `r(escaped)'\b0"
        }
        file write `rtf_handle' "\par" _n

        _journalone_rtf_escape, text("被解释变量")
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            _journalone_rtf_escape, text(`"`outcome`model_index''"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        _journalone_rtf_escape, text("规格")
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw10\brsp20`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            local this_specification : word `model_index' of `table_specs'
            local column_label "`this_specification'"
            if "`this_specification'" == "main" local column_label "基准模型"
            else if substr("`this_specification'",1,4) == "iv_" local column_label "IV-2SLS"
            else if "`this_specification'" == "heckman_twostep" local column_label "Heckman两步法"
            else if "`this_specification'" == "psm_weighted" local column_label "PSM加权"
            else if "`this_specification'" == "psm_nearest" local column_label "PSM近邻"
            else if substr("`this_specification'",1,4) == "psm_" local column_label "PSM匹配"
            else if substr("`this_specification'",1,4) == "med_" local column_label = "中介：" + substr("`this_specification'",5,.)
            else if substr("`this_specification'",1,10) == "moderator_" local column_label = "调节：" + substr("`this_specification'",11,.)
            else if substr("`this_specification'",1,6) == "group_" local column_label = "分组：" + substr("`this_specification'",7,.)
            else if substr("`this_specification'",1,7) == "custom_" local column_label = "规格" + string(real(substr("`this_specification'",8,.)), "%9.0f")
            if `has_specification_label' {
                forvalues row = 1/`=_N' {
                    if specification[`row'] == "`this_specification'" {
                        if strtrim(specification_label[`row']) != "" local column_label = specification_label[`row']
                        continue, break
                    }
                }
            }
            _journalone_rtf_escape, text(`"`column_label'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        foreach this_term of local terms {
            local displayed_term "`this_term'"
            if "`this_term'" == "_cons" local displayed_term "常数项"
            else if `has_term_label' {
                forvalues row = 1/`=_N' {
                    if term[`row'] == "`this_term'" {
                        if strtrim(term_label[`row']) != "" local displayed_term = term_label[`row']
                        continue, break
                    }
                }
            }
            _journalone_rtf_escape, text(`"`displayed_term'"')
            file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `r(escaped)'"
            forvalues model_index = 1/`model_count' {
                local this_specification : word `model_index' of `table_specs'
                local coefficient ""
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
                local this_specification : word `model_index' of `table_specs'
                local reported_stat ""
                forvalues row = 1/`=_N' {
                    if specification[`row'] == "`this_specification'" & term[`row'] == "`this_term'" {
                        if !missing(std_error[`row']) {
                            if "`statistic'" == "t" local reported_stat = strtrim(string(estimate[`row']/std_error[`row'], "`number_format'"))
                            else local reported_stat = strtrim(string(std_error[`row'], "`number_format'"))
                            local reported_stat "(`reported_stat')"
                        }
                        continue, break
                    }
                }
                _journalone_rtf_escape, text(`"`reported_stat'"')
                file write `rtf_handle' "\tab\qc `r(escaped)'"
            }
            file write `rtf_handle' "\par" _n
        }

        _journalone_write_spec_meta_rows, handle(`rtf_handle')             ///
            tabs(`"`table_tabs'"') specs("`table_specs'")               ///
            model("`model'") controls(`"`controls'"') absorb(`"`absorb'"') ///
            panel("`panel'") time("`time'") `timefe' `heckmanfe'        ///
            addcontrols(`"`addcontrols'"') addfe(`"`addfe'"')

        _journalone_rtf_escape, text("N")
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            local n_display ""
            if !missing(`n`model_index'') local n_display = strtrim(string(`n`model_index'', "%12.0f"))
            _journalone_rtf_escape, text(`"`n_display'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        _journalone_rtf_escape, text("Adjusted R²")
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw20\brsp20`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            local fit_display ""
            if !missing(`fit`model_index'') local fit_display = strtrim(string(`fit`model_index'', "`number_format'"))
            _journalone_rtf_escape, text(`"`fit_display'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n
        if `table_index' < `table_count' file write `rtf_handle' "\page" _n
    }

    local statistic_note "Standard errors in parentheses"
    if "`statistic'" == "t" local statistic_note "t statistics in parentheses"
    _journalone_rtf_escape, text(`"`statistic_note'"')
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    local star_note "* p < `pstar3', ** p < `pstar2', *** p < `pstar1'"
    _journalone_rtf_escape, text(`"`star_note'"')
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(regression) ///
        title(`"`title'"') decimals(`decimals') pstar1(`pstar1')       ///
        pstar2(`pstar2') pstar3(`pstar3')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
