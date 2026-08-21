*! version 0.9.17 19aug2026

capture program drop _jo_display_results_table
program define _jo_display_results_table
    version 16.0
    syntax , TITLE(string) [DECIMALS(integer 3) STATISTIC(string)          ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)                ///
        MODEL(string) DEPVAR(string) INDEPVARS(string) CONTROLS(string) ABSORB(string) PANEL(string) ///
        TIME(string) TIMEFE CONTROLS2(string) ABSORB2(string) PANEL2(string) ///
        TIME2(string) MODEL2(string) TIMEFE2 CONTROLS3(string)             ///
        ABSORB3(string) PANEL3(string) TIME3(string) MODEL3(string)       ///
        TIMEFE3 CONTROLS4(string) ABSORB4(string) PANEL4(string)           ///
        TIME4(string) MODEL4(string) TIMEFE4 CONTROLS5(string) ABSORB5(string) ///
        PANEL5(string) TIME5(string) MODEL5(string) TIMEFE5 CONTROLS6(string) ///
        ABSORB6(string) PANEL6(string) TIME6(string) MODEL6(string) TIMEFE6 ///
        ADDCONTROLS(string) ADDFE(string) HECKMANFE ///
        TREAT(string) ENDOG(string) INSTRUMENTS(string) HECKMANSEL(string)       ///
        PSMWEIGHT(string) HECKMANIMR(string) HECKMANOUTCOVARS(string) HECKMANCOVARS(string)]

    * Endogeneity specifications are deliberately shown in the same compact
    * horizontal layout as the publication RTF (PSM, Heckman selection,
    * Heckman outcome, IV first stage, IV second stage).  The generic renderer
    * remains the fallback for ordinary baseline/robustness runs.
    if strtrim(`"`treat' `endog' `instruments' `heckmansel' `psmweight' `heckmanimr' `heckmanoutcovars'"') != "" {
        capture noisily _jo_display_endog_table, title(`"`title'"')          ///
            decimals(`decimals') statistic(`"`statistic'"')                 ///
            pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3')                ///
            model(`"`model'"') depvar(`"`depvar'"') indepvars(`"`indepvars'"') ///
            controls(`"`controls'"') absorb(`"`absorb'"') panel(`"`panel'"') ///
            time(`"`time'"') `timefe' `heckmanfe'                           ///
            treat(`"`treat'"') endog(`"`endog'"') instruments(`"`instruments'"') ///
            heckmansel(`"`heckmansel'"') psmweight(`"`psmweight'"')          ///
            heckmancovars(`"`heckmancovars'"')                                  ///
            heckmanimr(`"`heckmanimr'"')                                     ///
            heckmanoutcovars(`"`heckmanoutcovars'"')
        if !_rc exit
    }

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198
    quietly count
    if r(N) == 0 exit 2000

    sort specification_order term_order
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
    local model_count : word count `specifications'
    if `model_count' < 1 exit 2000

    capture confirm variable specification_label
    local has_specification_label = (_rc == 0)
    capture confirm variable term_label
    local has_term_label = (_rc == 0)
    capture confirm variable significance
    local has_significance = (_rc == 0)
    capture confirm variable r2_a
    local has_r2_a = (_rc == 0)

    * Resolve design metadata once per specification.  These flags are also
    * used by the RTF writer, so the Results window reflects the actual setup.
    forvalues meta_index = 1/`model_count' {
        local this_specification : word `meta_index' of `specifications'
        local this_controls `"`controls'"'
        local this_absorb `"`absorb'"'
        local this_panel `"`panel'"'
        local this_time `"`time'"'
        local this_model = lower(strtrim(`"`model'"'))
        local this_timefe "`timefe'"
        if substr("`this_specification'", 1, 9) == "baseline_" {
            local baseline_index = real(substr("`this_specification'", 10, .))
            if `baseline_index' == 2 {
                local this_controls `"`controls2'"'
                local this_absorb `"`absorb2'"'
                local this_panel `"`panel2'"'
                local this_time `"`time2'"'
                local this_model = lower(strtrim(`"`model2'"'))
                local this_timefe "`timefe2'"
            }
            if `baseline_index' == 3 {
                local this_controls `"`controls3'"'
                local this_absorb `"`absorb3'"'
                local this_panel `"`panel3'"'
                local this_time `"`time3'"'
                local this_model = lower(strtrim(`"`model3'"'))
                local this_timefe "`timefe3'"
            }
            if `baseline_index' == 4 {
                local this_controls `"`controls4'"'
                local this_absorb `"`absorb4'"'
                local this_panel `"`panel4'"'
                local this_time `"`time4'"'
                local this_model = lower(strtrim(`"`model4'"'))
                local this_timefe "`timefe4'"
            }
            if `baseline_index' == 5 {
                local this_controls `"`controls5'"'
                local this_absorb `"`absorb5'"'
                local this_panel `"`panel5'"'
                local this_time `"`time5'"'
                local this_model = lower(strtrim(`"`model5'"'))
                local this_timefe "`timefe5'"
            }
            if `baseline_index' == 6 {
                local this_controls `"`controls6'"'
                local this_absorb `"`absorb6'"'
                local this_panel `"`panel6'"'
                local this_time `"`time6'"'
                local this_model = lower(strtrim(`"`model6'"'))
                local this_timefe "`timefe6'"
            }
        }
        if "`this_specification'" == "additional_controls" {
            local this_controls = strtrim(`"`this_controls' `addcontrols'"')
        }
        if "`this_specification'" == "additional_fe" {
            local this_absorb = strtrim(`"`this_absorb' `addfe'"')
        }
        local meta_controls`meta_index' = (strtrim(`"`this_controls'"') != "")
        local meta_year`meta_index' = ("`this_timefe'" != "")
        if "`this_model'" == "did" local meta_year`meta_index' = 1
        if "`this_time'" != "" & strpos(lower(`"`this_absorb'"'), lower(`"`this_time'"')) > 0 {
            local meta_year`meta_index' = 1
        }
        local meta_entity`meta_index' = 0
        if inlist("`this_model'", "fe", "re") & strtrim(`"`this_panel'"') != "" {
            local meta_entity`meta_index' = 1
        }
        if "`this_panel'" != "" & strpos(lower(`"`this_absorb'"'), lower(`"`this_panel'"')) > 0 {
            local meta_entity`meta_index' = 1
        }
        * Advanced estimators report only the design actually used by the
        * command.  PSM and default Heckman do not inherit baseline FE;
        * GMM/DML likewise report no absorption unless their own command does.
        if substr("`this_specification'", 1, 4) == "psm_" & ///
            "`this_specification'" != "psm_weighted" {
            local meta_year`meta_index' = 0
            local meta_entity`meta_index' = 0
        }
        if inlist("`this_specification'", "heckman_selection", "heckman_twostep") & ///
            "`heckmanfe'" == "" {
            local meta_year`meta_index' = 0
            local meta_entity`meta_index' = 0
        }
        if substr("`this_specification'", 1, 4) == "gmm_" | ///
            substr("`this_specification'", 1, 4) == "dml_" {
            local meta_year`meta_index' = 0
            local meta_entity`meta_index' = 0
        }
        if "`this_specification'" == "ovb_basic" {
            local meta_controls`meta_index' = 0
            local meta_year`meta_index' = 0
            local meta_entity`meta_index' = 0
        }
        if "`this_specification'" == "ovb_fe_only" {
            local meta_controls`meta_index' = 0
        }
        if "`this_specification'" == "ovb_entity_only" {
            local meta_year`meta_index' = 0
            local meta_entity`meta_index' = (strtrim(`"`this_panel'"') != "")
        }
    }

    local old_linesize = c(linesize)
    quietly set linesize 255
    local statistic_label "标准误"
    if "`statistic'" == "t" local statistic_label "t值"
    display as text _newline "`title'（完整结果表）"
    display as text "注：变量为行、估计规格为列；括号内报告`statistic_label'。"
    local column_width = 22
    if `model_count' > 8 local column_width = 18
    local pad "                                                                                                    "
    local header = usubstr("项目`pad'", 1, 26)
    forvalues meta_index = 1/`model_count' {
        local this_specification : word `meta_index' of `specifications'
        local column_label "`this_specification'"
        if `has_specification_label' {
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" {
                    if strtrim(specification_label[`row']) != "" local column_label = specification_label[`row']
                    continue, break
                }
            }
        }
        if "`this_specification'" == "psm_weighted" local column_label "PSM加权结果"
        if "`this_specification'" == "psm_nearest" local column_label "PSM近邻匹配（ATT）"
        if substr("`this_specification'",1,9) == "iv_first_" {
            local first_stage_number = real(substr("`this_specification'",10,.))
            local first_stage_outcome ""
            forvalues first_stage_row = 1/`=_N' {
                if specification[`first_stage_row'] == "`this_specification'" {
                    local first_stage_outcome = outcome[`first_stage_row']
                    continue, break
                }
            }
            local column_label "IV第一阶段：`first_stage_outcome'"
        }
        if "`this_specification'" == "iv_2sls" local column_label "IV第二阶段（2SLS）"
        if "`this_specification'" == "heckman_selection" local column_label "Heckman第一阶段（选择方程）"
        if "`this_specification'" == "heckman_twostep" local column_label "Heckman第二阶段（结果方程）"
        local header_cell = usubstr("`column_label'`pad'", 1, `column_width')
        local header `"`header'| `header_cell'"'
    }
    display as text "`header'"
    local separator ""
    forvalues separator_index = 1/255 {
        local separator "`separator'-"
    }
    display as text "`separator'"

    local row_labels "被解释变量 控制变量 时间固定效应 个体固定效应"
    local row_index = 0
    foreach row_label of local row_labels {
        local ++row_index
        local rowline = usubstr("`row_label'`pad'", 1, 26)
        forvalues meta_index = 1/`model_count' {
            local this_specification : word `meta_index' of `specifications'
            local cell "否"
            if `row_index' == 1 {
                forvalues row = 1/`=_N' {
                    if specification[`row'] == "`this_specification'" {
                        local cell = outcome[`row']
                        continue, break
                    }
                }
            }
            if `row_index' == 2 & `meta_controls`meta_index'' local cell "是"
            if `row_index' == 3 & `meta_year`meta_index'' local cell "是"
            if `row_index' == 4 & `meta_entity`meta_index'' local cell "是"
            local cell_length = ustrlen("`cell'")
            local cell_padding = `column_width' - `cell_length'
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local cell "`cell'`filler'"
            }
            local rowline `"`rowline'| `cell'"'
        }
        display as text "`rowline'"
    }
    display as text "`separator'"

    foreach this_term of local terms {
        local displayed_term "`this_term'"
        if "`this_term'" != "_cons" & `has_term_label' {
            forvalues row = 1/`=_N' {
                if term[`row'] == "`this_term'" {
                    if strtrim(term_label[`row']) != "" local displayed_term = term_label[`row']
                    continue, break
                }
            }
        }
        if "`this_term'" == "_cons" local displayed_term "常数项"
        if "`this_term'" == "FIRST_STAGE_F" local displayed_term "第一阶段排除工具变量F值"
        if "`this_term'" == "lambda" local displayed_term "IMR"
        local rowline = usubstr("`displayed_term'`pad'", 1, 26)
        forvalues meta_index = 1/`model_count' {
            local this_specification : word `meta_index' of `specifications'
            local cell "--"
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" & term[`row'] == "`this_term'" {
                    local stars ""
                    if `has_significance' local stars = significance[`row']
                    if !`has_significance' & !missing(p_value[`row']) {
                        if p_value[`row'] <= `pstar1' local stars "***"
                        else if p_value[`row'] <= `pstar2' local stars "**"
                        else if p_value[`row'] <= `pstar3' local stars "*"
                    }
                    local beta = strtrim(string(estimate[`row'], "%21.`decimals'f"))
                    local stat_value ""
                    if "`statistic'" == "t" local stat_value = strtrim(string(estimate[`row']/std_error[`row'], "%21.`decimals'f"))
                    else local stat_value = strtrim(string(std_error[`row'], "%21.`decimals'f"))
                    if missing(estimate[`row']) local cell "--"
                    else if missing(std_error[`row']) local cell "`beta'`stars'"
                    else local cell "`beta'`stars' (`stat_value')"
                    continue, break
                }
            }
            * Do not truncate coefficient cells: a missing closing parenthesis
            * is worse than a slightly wider Results line.
            local cell_length = ustrlen("`cell'")
            local cell_padding = `column_width' - `cell_length'
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local cell "`cell'`filler'"
            }
            local rowline `"`rowline'| `cell'"'
        }
        display as text "`rowline'"
    }

    display as text "`separator'"
    foreach footer in "N" "Adjusted R2" {
        local rowline = usubstr("`footer'`pad'", 1, 26)
        forvalues meta_index = 1/`model_count' {
            local this_specification : word `meta_index' of `specifications'
            local cell "--"
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" {
                    if "`footer'" == "N" local cell = strtrim(string(N[`row'], "%12.0f"))
                    else if `has_r2_a' & !missing(r2_a[`row']) local cell = strtrim(string(r2_a[`row'], "%9.4f"))
                    else if !missing(r2[`row']) local cell = strtrim(string(r2[`row'], "%9.4f"))
                    continue, break
                }
            }
            local cell_length = ustrlen("`cell'")
            local cell_padding = `column_width' - `cell_length'
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local cell "`cell'`filler'"
            }
            local rowline `"`rowline'| `cell'"'
        }
        display as text "`rowline'"
    }
    display as text "`separator'"
    quietly set linesize `old_linesize'
end


* Paper-style endogeneity table for the Stata Results window.  This is kept in
* the existing display file so installed users receive it with the normal
* JournalOne package; no extra command is exposed to the user.
capture program drop _jo_display_endog_table
program define _jo_display_endog_table
    version 16.0
    syntax , TITLE(string) [DECIMALS(integer 3) STATISTIC(string)              ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10) MODEL(string)       ///
        DEPVAR(string) INDEPVARS(string) CONTROLS(string) ABSORB(string)        ///
        PANEL(string) TIME(string) TIMEFE HECKMANFE TREAT(string) ENDOG(string) ///
        INSTRUMENTS(string) HECKMANSEL(string) HECKMANCOVARS(string)             ///
        PSMWEIGHT(string) HECKMANIMR(string) HECKMANOUTCOVARS(string)]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198
    quietly count
    if r(N) == 0 exit 2000

    sort specification_order term_order
    local specs ""
    foreach preferred in psm_weighted heckman_selection heckman_twostep {
        quietly count if specification == "`preferred'"
        if r(N) > 0 local specs "`specs' `preferred'"
    }
    local iv_first_spec ""
    forvalues row = 1/`=_N' {
        local candidate_spec = specification[`row']
        if substr("`candidate_spec'", 1, 9) == "iv_first_" {
            local iv_first_spec "`candidate_spec'"
            continue, break
        }
    }
    if "`iv_first_spec'" != "" local specs "`specs' `iv_first_spec'"
    local iv_second_spec "iv_2sls"
    quietly count if specification == "iv_2sls"
    if r(N) == 0 & lower(strtrim("`model'")) == "iv" {
        quietly count if specification == "main"
        if r(N) > 0 local iv_second_spec "main"
    }
    quietly count if specification == "`iv_second_spec'"
    if r(N) > 0 local specs "`specs' `iv_second_spec'"
    local specs = strtrim("`specs'")
    local model_count : word count `specs'
    if `model_count' == 0 exit 2000

    local primary_x : word 1 of `indepvars'
    if "`primary_x'" == "" local primary_x : word 1 of `endog'
    if "`primary_x'" == "" local primary_x : word 1 of `treat'

    local observed_terms ""
    forvalues row = 1/`=_N' {
        local observed = term[`row']
        if !strpos(" `observed_terms' ", " `observed' ") local observed_terms "`observed_terms' `observed'"
    }
    local candidate_terms `"`indepvars' `endog' `heckmanoutcovars' `heckmanimr' `instruments' `heckmancovars'"'
    if "`candidate_terms'" == "" local candidate_terms "`primary_x'"
    local terms ""
    foreach candidate of local candidate_terms {
        if "`candidate'" == "" | "`candidate'" == "_cons" continue
        local is_control : list candidate in controls
        if `is_control' & "`candidate'" != "`heckmanoutcovars'" continue
        if strpos(" `observed_terms' ", " `candidate' ") & ///
            !strpos(" `terms' ", " `candidate' ") local terms "`terms' `candidate'"
    }
    local special_terms ""
    foreach observed of local observed_terms {
        if inlist("`observed'", "KP_LM", "CD_F") | ///
            ("`heckmanimr'" != "" & "`observed'" == "`heckmanimr'") {
            if !strpos(" `terms' `special_terms' ", " `observed' ") local special_terms "`special_terms' `observed'"
        }
    }
    local terms = strtrim("`terms' `special_terms'")
    if "`terms'" == "" {
        foreach observed of local observed_terms {
            if "`observed'" != "_cons" & "`observed'" != "FIRST_STAGE_F" local terms "`terms' `observed'"
        }
    }

    local old_linesize = c(linesize)
    quietly set linesize 255
    local column_width = 25
    local pad "                                                                                                    "
    local separator ""
    forvalues i = 1/150 {
        local separator "`separator'-"
    }
    display as text _newline "`title'（论文式完整表）"
    local stat_label "标准误"
    if "`statistic'" == "t" local stat_label "t值"
    display as text "注：列顺序为PSM加权、Heckman选择方程、Heckman结果方程、IV第一阶段和IV第二阶段；括号内为`stat_label'。"

    local header = usubstr("变量`pad'", 1, `column_width')
    forvalues j = 1/`model_count' {
        local header_cell "(`j')"
        local cell_padding = `column_width' - ustrlen("`header_cell'")
        if `cell_padding' > 0 {
            local filler = usubstr("`pad'", 1, `cell_padding')
            local header_cell "`header_cell'`filler'"
        }
        local header `"`header'| `header_cell'"'
    }
    display as text "`header'"
    local line2 = usubstr("被解释变量`pad'", 1, `column_width')
    forvalues j = 1/`model_count' {
        local spec : word `j' of `specs'
        local outcome ""
        forvalues row = 1/`=_N' {
            if specification[`row'] == "`spec'" {
                local outcome = outcome[`row']
                continue, break
            }
        }
        local cell_padding = `column_width' - ustrlen("`outcome'")
        if `cell_padding' > 0 {
            local filler = usubstr("`pad'", 1, `cell_padding')
            local outcome "`outcome'`filler'"
        }
        local line2 `"`line2'| `outcome'"'
    }
    display as text "`line2'"
    display as text "`separator'"

    foreach this_term of local terms {
        local label "`this_term'"
        if "`this_term'" == "`heckmanimr'" | substr("`this_term'",1,2) == "__" local label "IMR"
        if "`this_term'" == "KP_LM" local label "Kleibergen-Paap rk LM"
        if "`this_term'" == "CD_F" local label "Cragg-Donald Wald F"
        local rowline = usubstr("`label'`pad'", 1, `column_width')
        forvalues j = 1/`model_count' {
            local spec : word `j' of `specs'
            local lookup "`this_term'"
            if "`spec'" == "psm_weighted" & "`this_term'" == "`primary_x'" & "`treat'" != "" local lookup "`treat'"
            local source "`spec'"
            local diagnostic = inlist("`this_term'", "KP_LM", "CD_F")
            if `diagnostic' local source "`iv_second_spec'"
            local beta ""
            local stat_value ""
            if !`diagnostic' | "`spec'" == "`iv_first_spec'" {
                forvalues row = 1/`=_N' {
                    if specification[`row'] == "`source'" & term[`row'] == "`lookup'" {
                    if !missing(estimate[`row']) {
                        local stars ""
                        if !missing(p_value[`row']) {
                            if p_value[`row'] <= `pstar1' local stars "***"
                            else if p_value[`row'] <= `pstar2' local stars "**"
                            else if p_value[`row'] <= `pstar3' local stars "*"
                        }
                        local beta = strtrim(string(estimate[`row'], "%21.`decimals'f")) + "`stars'"
                        if !`diagnostic' & !missing(std_error[`row']) {
                            if "`statistic'" == "t" local stat_value = strtrim(string(estimate[`row']/std_error[`row'], "%21.`decimals'f"))
                            else local stat_value = strtrim(string(std_error[`row'], "%21.`decimals'f"))
                            local beta "`beta' (`stat_value')"
                        }
                    }
                        continue, break
                    }
                }
            }
            local cell_padding = `column_width' - ustrlen("`beta'")
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local beta "`beta'`filler'"
            }
            local rowline `"`rowline'| `beta'"'
        }
        display as text "`rowline'"
    }
    display as text "`separator'"

    foreach footer in "控制变量" "年份固定效应" "企业固定效应" {
        local rowline = usubstr("`footer'`pad'", 1, `column_width')
        forvalues j = 1/`model_count' {
            local spec : word `j' of `specs'
            local cell "是"
            if "`footer'" == "企业固定效应" & "`spec'" == "heckman_selection" local cell "否"
            if "`footer'" == "年份固定效应" & inlist("`spec'", "heckman_selection", "heckman_twostep") & "`time'" == "" local cell "否"
            if "`footer'" == "企业固定效应" & "`spec'" == "heckman_twostep" & "`heckmanfe'" == "" local cell "否"
            local cell_padding = `column_width' - ustrlen("`cell'")
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local cell "`cell'`filler'"
            }
            local rowline `"`rowline'| `cell'"'
        }
        display as text "`rowline'"
    }
    display as text "`separator'"
    foreach footer in "N" "R2_adjusted" {
        local rowline = usubstr("`footer'`pad'", 1, `column_width')
        forvalues j = 1/`model_count' {
            local spec : word `j' of `specs'
            local cell ""
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`spec'" {
                    if "`footer'" == "N" & !missing(N[`row']) local cell = strtrim(string(N[`row'], "%12.0f"))
                    if "`footer'" == "R2_adjusted" & !missing(r2_a[`row']) local cell = strtrim(string(r2_a[`row'], "%9.4f"))
                    if "`footer'" == "R2_adjusted" & "`spec'" == "`iv_second_spec'" local cell ""
                    if "`cell'" != "" continue, break
                }
            }
            local cell_padding = `column_width' - ustrlen("`cell'")
            if `cell_padding' > 0 {
                local filler = usubstr("`pad'", 1, `cell_padding')
                local cell "`cell'`filler'"
            }
            local rowline `"`rowline'| `cell'"'
        }
        display as text "`rowline'"
    }
    display as text "`separator'"
    display as text "注：完整控制变量系数、所有失败/附加规格及机器可读诊断保留在内生性检验三件套中。"
    quietly set linesize `old_linesize'
end
