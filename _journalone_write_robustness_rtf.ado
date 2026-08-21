*! version 0.9.14 18aug2026

capture program drop _journalone_write_robustness_rtf
program define _journalone_write_robustness_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)                 ///
        MODEL(string) CONTROLS(string) ABSORB(string) PANEL(string)       ///
        TIME(string) TIMEFE ADDCONTROLS(string) ADDFE(string)]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198

    sort specification_order term_order
    quietly count
    if r(N) == 0 exit 2000

    capture confirm variable r2_a
    if _rc generate double r2_a = .
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
        if "`this_term'" == "_cons" {
            local has_constant = 1
        }
        else if !strpos(" `terms' ", " `this_term' ") {
            local terms "`terms' `this_term'"
        }
    }
    local specifications = strtrim("`specifications'")
    local terms = strtrim("`terms'")
    if `has_constant' local terms = strtrim("`terms' _cons")

    * The main model is repeated as the first column of every continuation
    * table, so each robustness specification has an immediate comparator.
    local has_main = strpos(" `specifications' ", " main ") > 0
    local has_custom = 0
    foreach candidate of local specifications {
        if substr("`candidate'", 1, 7) == "custom_" local has_custom = 1
    }
    local robustness_specs : list specifications - main
    if `has_main' local specifications "main `robustness_specs'"

    * Match the baseline-table layout: no more than four model columns on an
    * A4 portrait page. When main is present, each continuation therefore
    * contains main plus at most three robustness specifications.
    local table_capacity = 4
    local robust_per_table = `table_capacity'
    if `has_main' local robust_per_table = `table_capacity' - 1
    local robustness_count : word count `robustness_specs'
    local table_count = 1
    if `has_main' & `robustness_count' > 0 {
        local table_count = ceil(`robustness_count'/`robust_per_table')
    }
    else if !`has_main' {
        local total_specifications : word count `specifications'
        local table_count = ceil(`total_specifications'/`table_capacity')
    }
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

    local remaining_specs "`robustness_specs'"
    local remaining_all_specs "`specifications'"
    local number_format "%21.`decimals'f"

    forvalues table_index = 1/`table_count' {
        local table_specs ""
        if `has_main' local table_specs "main"
        local slots = `robust_per_table'
        if !`has_main' local slots = `table_capacity'
        forvalues slot = 1/`slots' {
            if `has_main' {
                gettoken next_spec remaining_specs : remaining_specs
            }
            else {
                gettoken next_spec remaining_all_specs : remaining_all_specs
            }
            if "`next_spec'" == "" continue, break
            local table_specs "`table_specs' `next_spec'"
        }
        local table_specs = strtrim("`table_specs'")
        local model_count : word count `table_specs'
        if `model_count' == 0 continue

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

        if `table_count' > 1 {
            local table_caption "稳健性规格（第`table_index'组，共`table_count'组）"
            _journalone_rtf_escape, text(`"`table_caption'"')
            file write `rtf_handle' "\pard\ql\sb120\sa0\sl360\slmult1\b\f0\fs18 `r(escaped)'\b0\par" _n
        }

        * Top rule, model number row, and the two metadata rows form one
        * standard multi-column table rather than a term-by-term long list.
        _journalone_rtf_escape, text("模型")
        local model_label `"`r(escaped)'"'
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20`table_tabs'\ql\b `model_label'\b0"
        forvalues model_index = 1/`model_count' {
            local model_header "(`model_index')"
            _journalone_rtf_escape, text(`"`model_header'"')
            file write `rtf_handle' "\tab\qc\b `r(escaped)'\b0"
        }
        file write `rtf_handle' "\par" _n

        _journalone_rtf_escape, text("被解释变量")
        local outcome_label `"`r(escaped)'"'
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1`table_tabs'\ql `outcome_label'"
        forvalues model_index = 1/`model_count' {
            _journalone_rtf_escape, text(`"`outcome`model_index''"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        _journalone_rtf_escape, text("稳健性规格")
        local specification_label `"`r(escaped)'"'
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw10\brsp20`table_tabs'\ql `specification_label'"
        forvalues model_index = 1/`model_count' {
            local this_specification : word `model_index' of `table_specs'
            local column_label "`this_specification'"
            if "`this_specification'" == "main" {
                if `has_custom' local column_label "规格1"
                else local column_label "基准模型"
            }
            else if substr("`this_specification'", 1, 6) == "alt_y_" local column_label "替换Y"
            else if substr("`this_specification'", 1, 6) == "alt_x_" local column_label "替换X"
            else if substr("`this_specification'", 1, 7) == "custom_" {
                local custom_number = real(substr("`this_specification'", 8, .)) + 1
                local column_label "规格`custom_number'"
            }
            else if "`this_specification'" == "additional_controls" local column_label "增加控制变量"
            else if "`this_specification'" == "additional_fe" local column_label "增加固定效应"
            else if "`this_specification'" == "subsample" local column_label "替代样本"
            else if substr("`this_specification'", 1, 4) == "lag_" local column_label "滞后" + substr("`this_specification'", 5, .) + "期"
            else if substr("`this_specification'", 1, 5) == "lead_" local column_label "超前" + substr("`this_specification'", 6, .) + "期"
            else if "`this_specification'" == "alternative_vce" local column_label "替代标准误"
            else if substr("`this_specification'", 1, 7) == "winsor_" local column_label "分位缩尾"
            _journalone_rtf_escape, text(`"`column_label'"')
            file write `rtf_handle' "\tab\qc `r(escaped)'"
        }
        file write `rtf_handle' "\par" _n

        foreach this_term of local terms {
            local displayed_term "`this_term'"
            if `has_term_label' {
                forvalues row = 1/`=_N' {
                    if term[`row'] == "`this_term'" {
                        if strtrim(term_label[`row']) != "" local displayed_term = term_label[`row']
                        continue, break
                    }
                }
            }
            _journalone_rtf_escape, text(`"`displayed_term'"')
            local rtf_term `"`r(escaped)'"'
            file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `rtf_term'"
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

        * Keep the paper's design rows with the corresponding specification
        * columns, including additional FE/controls and custom specifications.
        _journalone_write_spec_meta_rows, handle(`rtf_handle')             ///
            tabs(`"`table_tabs'"')                                        ///
            specs("`table_specs'") model("`model'")                    ///
            controls(`"`controls'"') absorb(`"`absorb'"')                ///
            panel("`panel'") time("`time'") `timefe'                    ///
            addcontrols(`"`addcontrols'"') addfe(`"`addfe'"')

        _journalone_rtf_escape, text("N")
        local n_label `"`r(escaped)'"'
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `n_label'"
        forvalues model_index = 1/`model_count' {
            local n_display ""
            if !missing(`n`model_index'') local n_display = strtrim(string(`n`model_index'', "%12.0f"))
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
        title(`"`title'"') decimals(`decimals') pstar1(`pstar1') ///
        pstar2(`pstar2') pstar3(`pstar3')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
