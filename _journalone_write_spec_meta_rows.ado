*! version 0.9.17 19aug2026

capture program drop _journalone_write_spec_meta_rows
program define _journalone_write_spec_meta_rows
    version 16.0
    syntax , HANDLE(name) SPECS(string) [TABS(string) LONG MODEL(string) CONTROLS(string) ///
        ABSORB(string) PANEL(string) TIME(string) TIMEFE                     ///
        CONTROLS2(string) ABSORB2(string) PANEL2(string) TIME2(string)        ///
        MODEL2(string) TIMEFE2 CONTROLS3(string) ABSORB3(string)              ///
        PANEL3(string) TIME3(string) MODEL3(string) TIMEFE3                   ///
        CONTROLS4(string) ABSORB4(string) PANEL4(string) TIME4(string)        ///
        MODEL4(string) TIMEFE4 CONTROLS5(string) ABSORB5(string) PANEL5(string) ///
        TIME5(string) MODEL5(string) TIMEFE5 CONTROLS6(string) ABSORB6(string) ///
        PANEL6(string) TIME6(string) MODEL6(string) TIMEFE6                   ///
        ADDCONTROLS(string) ADDFE(string) HECKMANFE]

    local specifications = strtrim(`"`specs'"')
    local meta_labels "控制变量 时间固定效应 个体固定效应"
    local model = lower(strtrim(`"`model'"'))

    local model_count : word count `specifications'
    if `model_count' < 1 exit 2000
    forvalues model_index = 1/`model_count' {
        local controls_flag`model_index' = 0
        local year_flag`model_index' = 0
        local entity_flag`model_index' = 0
    }

    forvalues model_index = 1/`model_count' {
        local this_specification : word `model_index' of `specifications'
        local this_controls `"`controls'"'
        local this_absorb `"`absorb'"'
        local this_panel `"`panel'"'
        local this_time `"`time'"'
        local this_model `"`model'"'
        local this_timefe "`timefe'"

        * Baseline columns can have independent settings.
        if substr("`this_specification'", 1, 9) == "baseline_" {
            local baseline_index = real(substr("`this_specification'", 10, .))
            if `baseline_index' == 2 {
                local this_controls `"`controls2'"'
                local this_absorb `"`absorb2'"'
                local this_panel `"`panel2'"'
                local this_time `"`time2'"'
                local this_model `"`model2'"'
                local this_timefe "`timefe2'"
            }
            if `baseline_index' == 3 {
                local this_controls `"`controls3'"'
                local this_absorb `"`absorb3'"'
                local this_panel `"`panel3'"'
                local this_time `"`time3'"'
                local this_model `"`model3'"'
                local this_timefe "`timefe3'"
            }
            if `baseline_index' == 4 {
                local this_controls `"`controls4'"'
                local this_absorb `"`absorb4'"'
                local this_panel `"`panel4'"'
                local this_time `"`time4'"'
                local this_model `"`model4'"'
                local this_timefe "`timefe4'"
            }
            if `baseline_index' == 5 {
                local this_controls `"`controls5'"'
                local this_absorb `"`absorb5'"'
                local this_panel `"`panel5'"'
                local this_time `"`time5'"'
                local this_model `"`model5'"'
                local this_timefe "`timefe5'"
            }
            if `baseline_index' == 6 {
                local this_controls `"`controls6'"'
                local this_absorb `"`absorb6'"'
                local this_panel `"`panel6'"'
                local this_time `"`time6'"'
                local this_model `"`model6'"'
                local this_timefe "`timefe6'"
            }
        }

        * The additional-control and additional-FE specifications inherit the
        * baseline model and add only the option that defines their column.
        if "`this_specification'" == "additional_controls" {
            local this_controls = strtrim(`"`this_controls' `addcontrols'"')
        }
        if "`this_specification'" == "additional_fe" {
            local this_absorb = strtrim(`"`this_absorb' `addfe'"')
        }

        if strtrim(`"`this_controls'"') != "" local controls_flag`model_index' = 1
        if "`this_timefe'" != "" local year_flag`model_index' = 1
        if "`this_model'" == "did" local year_flag`model_index' = 1
        if "`this_time'" != "" & strpos(lower(`"`this_absorb'"'), lower(`"`this_time'"')) > 0 {
            local year_flag`model_index' = 1
        }
        if "`this_model'" == "fe" | "`this_model'" == "re" {
            if strtrim(`"`this_panel'"') != "" local entity_flag`model_index' = 1
        }
        if "`this_panel'" != "" & strpos(lower(`"`this_absorb'"'), lower(`"`this_panel'"')) > 0 {
            local entity_flag`model_index' = 1
        }

        * Advanced estimators do not automatically inherit the baseline FE.
        * Report what the plugin actually estimates rather than filling "yes".
        if substr("`this_specification'", 1, 4) == "psm_" & ///
            "`this_specification'" != "psm_weighted" {
            local controls_flag`model_index' = 1
            local year_flag`model_index' = 0
            local entity_flag`model_index' = 0
        }
        if inlist("`this_specification'", "heckman_selection", "heckman_twostep") {
            local controls_flag`model_index' = 1
            if "`heckmanfe'" == "" {
                local year_flag`model_index' = 0
                local entity_flag`model_index' = 0
            }
        }
        * The manual HDFE two-step route uses time indicators in the
        * selection Probit but does not absorb entity fixed effects there.
        if "`this_specification'" == "heckman_selection" & ///
            "`heckmanfe'" != "" & "`model'" == "hdfe" {
            local year_flag`model_index' = (strtrim("`this_time'") != "")
            local entity_flag`model_index' = 0
        }
        if substr("`this_specification'", 1, 4) == "gmm_" | ///
            substr("`this_specification'", 1, 4) == "dml_" {
            local controls_flag`model_index' = 1
            local year_flag`model_index' = 0
            local entity_flag`model_index' = 0
        }
        if "`this_specification'" == "ovb_basic" {
            local controls_flag`model_index' = 0
            local year_flag`model_index' = 0
            local entity_flag`model_index' = 0
        }
        if "`this_specification'" == "ovb_fe_only" {
            local controls_flag`model_index' = 0
        }
        if "`this_specification'" == "ovb_entity_only" {
            local year_flag`model_index' = 0
            local entity_flag`model_index' = (strtrim(`"`this_panel'"') != "")
        }
    }

    if "`long'" != "" {
        local long_tabs "\tx5200\tqc\tx7200\tqc\tx9200\tqc\tx11200"
        local header_labels "规格 控制变量 时间固定效应 个体固定效应"
        local header_index = 0
        file write `handle' "\pard\keepn\sb120\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`long_tabs'\ql"
        foreach header_label of local header_labels {
            local ++header_index
            _journalone_rtf_escape, text(`"`header_label'"')
            if `header_index' == 1 file write `handle' "\b `r(escaped)'\b0"
            else file write `handle' "\tab\qc\b `r(escaped)'\b0"
        }
        file write `handle' "\par" _n

        capture confirm variable specification_label
        local has_specification_label = (_rc == 0)
        forvalues model_index = 1/`model_count' {
            local this_specification : word `model_index' of `specifications'
            local displayed_specification "`this_specification'"
            if `has_specification_label' {
                forvalues row = 1/`=_N' {
                    if specification[`row'] == "`this_specification'" {
                        if strtrim(specification_label[`row']) != "" {
                            local displayed_specification = specification_label[`row']
                        }
                        continue, break
                    }
                }
            }
            local bottom_border ""
            if `model_index' == `model_count' local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
            _journalone_rtf_escape, text(`"`displayed_specification'"')
            file write `handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`long_tabs'\ql `r(escaped)'"
            foreach flag_name in controls year entity {
                local cell "否"
                if ``flag_name'_flag`model_index'' local cell "是"
                _journalone_rtf_escape, text(`"`cell'"')
                file write `handle' "\tab\qc `r(escaped)'"
            }
            file write `handle' "\par" _n
        }
        exit
    }

    local meta_index = 0
    local meta_count : word count `meta_labels'
    foreach meta_label of local meta_labels {
        local ++meta_index
        _journalone_rtf_escape, text(`"`meta_label'"')
        local escaped_label `"`r(escaped)'"'
        file write `handle' "\pard\keep\sb0\sa0\sl360\slmult1`tabs'\ql `escaped_label'"
        forvalues model_index = 1/`model_count' {
            local cell "否"
            if `meta_index' == 1 & `controls_flag`model_index'' local cell "是"
            if `meta_index' == 2 & `year_flag`model_index'' local cell "是"
            if `meta_index' == 3 & `entity_flag`model_index'' local cell "是"
            _journalone_rtf_escape, text(`"`cell'"')
            file write `handle' "\tab\qc `r(escaped)'"
        }
        if `meta_index' == `meta_count' {
            file write `handle' "\brdrb\brdrs\brdrw10\brsp20"
        }
        file write `handle' "\par" _n
    }
end
