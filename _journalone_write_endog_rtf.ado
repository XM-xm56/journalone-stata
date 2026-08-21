*! version 0.9.18 20aug2026

capture program drop _journalone_write_endog_rtf
program define _journalone_write_endog_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)                 ///
        MODEL(string) DEPVAR(string) INDEPVARS(string) CONTROLS(string) ABSORB(string) PANEL(string) ///
        TIME(string) TIMEFE HECKMANFE ADDCONTROLS(string) ADDFE(string)    ///
        TREAT(string) ENDOG(string) INSTRUMENTS(string) HECKMANCOVARS(string) ///
        HECKMANIMR(string) HECKMANOUTCOVARS(string)]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198
    quietly count
    if r(N) == 0 exit 2000

    sort specification_order term_order
    capture confirm variable r2_a
    if _rc generate double r2_a = .
    capture confirm variable specification_label
    local has_specification_label = (_rc == 0)
    capture confirm variable term_label
    local has_term_label = (_rc == 0)

    * The publisher has already ordered endogeneity stages.  Preserve that
    * order, but keep every requested specification (OVB/GMM/DML continue on
    * additional pages rather than being silently discarded).
    local specifications ""
    forvalues row = 1/`=_N' {
        local this_specification = specification[`row']
        if !strpos(" `specifications' ", " `this_specification' ") {
            local specifications "`specifications' `this_specification'"
        }
    }
    local specifications = strtrim("`specifications'")
    local specification_count : word count `specifications'
    if `specification_count' < 1 exit 2000

    * Build a compact, generic row set.  Core variables, endogenous
    * variables, instruments, and Heckman exclusion variables are retained;
    * ordinary controls/year dummies remain fully available in CSV/DO and are
    * represented by the design rows in the publication table.
    local primary_x : word 1 of `indepvars'
    local candidate_terms `"`indepvars' `endog' `heckmanoutcovars' `heckmanimr' `instruments'"'
    if strtrim(`"`indepvars'"') == "" local candidate_terms `"`treat' `candidate_terms'"'
    * Heckman exclusion variables are focal only when they are not ordinary
    * outcome-equation controls.  This is what makes an exclusion such as
    * OverseaBack visible while keeping Size/Age/etc. in the design row.
    foreach heckman_candidate of local heckmancovars {
        local heckman_is_control : list heckman_candidate in controls
        if !`heckman_is_control' local candidate_terms `"`candidate_terms' `heckman_candidate'"'
    }
    local observed_terms ""
    forvalues row = 1/`=_N' {
        local this_term = term[`row']
        if !strpos(" `observed_terms' ", " `this_term' ") {
            local observed_terms "`observed_terms' `this_term'"
        }
    }
    local observed_terms = strtrim("`observed_terms'")

    local terms ""
    foreach candidate of local candidate_terms {
        if "`candidate'" == "" continue
        if "`candidate'" == "_cons" continue
        if strpos(" `observed_terms' ", " `candidate' ") & ///
            !strpos(" `terms' ", " `candidate' ") {
            local terms "`terms' `candidate'"
        }
    }

    local special_terms ""
    foreach observed of local observed_terms {
        local keep_special = 0
        if substr("`observed'", 1, 2) == "__" local keep_special = 1
        if inlist("`observed'", "lambda", "KP_LM", "CD_F", "OVB_F") | ///
            ("`heckmanimr'" != "" & "`observed'" == "`heckmanimr'") {
            local keep_special = 1
        }
        * FIRST_STAGE_F is preserved in the machine-readable files, but the
        * compact paper table uses the stronger KP/CD diagnostics when the IV
        * estimator exposes them.
        if "`observed'" == "FIRST_STAGE_F" local keep_special = 0
        if `keep_special' & !strpos(" `terms' `special_terms' ", " `observed' ") {
            local special_terms "`special_terms' `observed'"
        }
    }
    local terms = strtrim("`terms' `special_terms'")

    * If the user did not provide explicit focal lists, retain all non-control
    * non-year terms as a safe fallback.  This keeps the formatter useful for
    * arbitrary empirical designs rather than only the reference paper.
    if "`terms'" == "" {
        foreach observed of local observed_terms {
            if "`observed'" == "_cons" | "`observed'" == "FIRST_STAGE_F" continue
            local is_control : list observed in controls
            local is_year = 0
            if "`time'" != "" {
                if strpos("`observed'", ".`time'") | ///
                    strpos("`observed'", "i.`time'") | ///
                    strpos("`observed'", "`time'#") local is_year = 1
            }
            if !`is_control' & !`is_year' & ///
                !strpos(" `terms' ", " `observed' ") local terms "`terms' `observed'"
        }
    }
    local terms = strtrim("`terms'")

    * Always reserve the two paper-standard weak-identification rows when an
    * IV structural column exists.  If the estimator does not expose a value,
    * the cell remains blank and the explanatory note says so explicitly.
    local has_iv = 0
    foreach this_specification of local specifications {
        if "`this_specification'" == "iv_2sls" | "`this_specification'" == "main" & ///
            lower("`model'") == "iv" local has_iv = 1
    }
    if `has_iv' {
        foreach iv_diag in KP_LM CD_F {
            if !strpos(" `terms' ", " `iv_diag' ") local terms "`terms' `iv_diag'"
        }
    }

    local primary_count = 0
    local extra_count = 0
    foreach this_specification of local specifications {
        if substr("`this_specification'",1,4) == "ovb_" | ///
            substr("`this_specification'",1,4) == "gmm_" | ///
            substr("`this_specification'",1,4) == "dml_" local ++extra_count
        else local ++primary_count
    }
    * Keep OVB/GMM/DML on a continuation page instead of mixing them into the
    * five-column paper-style PSM/Heckman/IV table.  For designs with more than
    * six primary equations Stata's normal six-column page limit still applies.
    local table_capacity = 6
    if `extra_count' > 0 & `primary_count' > 0 & `primary_count' <= 6 {
        local table_capacity = `primary_count'
    }
    local table_count = ceil(`specification_count'/`table_capacity')
    if `table_count' < 1 local table_count = 1

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    * ISO A4 portrait with the same margins as descriptive and baseline RTFs.
    * The compact endogeneity layout still supports its five paper columns.
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

        if `table_index' > 1 {
            local continuation_index = `table_index' - 1
            local table_caption "`title'（续表`continuation_index'）"
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
            local tab_position = 2050 + floor(8200*(`model_index'-.5)/`model_count')
            local table_tabs "`table_tabs'\tqc\tx`tab_position'"
        }

        * Header row 1: model numbers.
        _journalone_rtf_escape, text("变量")
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20`table_tabs'\ql\b `r(escaped)'\b0"
        forvalues model_index = 1/`model_count' {
            _journalone_rtf_escape, text(`"(`model_index')"')
            file write `rtf_handle' "\tab\qc\b `r(escaped)'\b0"
        }
        file write `rtf_handle' "\par" _n

        * Header row 2: equation outcome, exactly as in journal tables.
        _journalone_rtf_escape, text("被解释变量")
        file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw10\brsp20`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            _journalone_rtf_escape, text(`"`outcome`model_index''"')
            file write `rtf_handle' "\tab\qc\i `r(escaped)'\i0"
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
            if "`this_term'" == "KP_LM" local displayed_term "Kleibergen-Paap rk LM"
            if "`this_term'" == "CD_F" local displayed_term "Cragg-Donald Wald F"
            if "`this_term'" == "KP_F" local displayed_term "Kleibergen-Paap rk Wald F"
            if "`this_term'" == "FIRST_STAGE_F" local displayed_term "第一阶段排除工具变量F值"
            if "`this_term'" == "lambda" | substr("`this_term'",1,2) == "__" | ///
                ("`heckmanimr'" != "" & "`this_term'" == "`heckmanimr'") local displayed_term "IMR"
            if "`this_term'" == "OVB_F" local displayed_term "遗漏变量偏误F值"

            _journalone_rtf_escape, text(`"`displayed_term'"')
            file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql `r(escaped)'"
            forvalues model_index = 1/`model_count' {
                local this_specification : word `model_index' of `table_specs'
                local coefficient ""
                local lookup_term "`this_term'"
                if "`this_specification'" == "psm_weighted" & ///
                    "`this_term'" == "`primary_x'" & "`treat'" != "" {
                    local lookup_term "`treat'"
                }
                forvalues row = 1/`=_N' {
                    local diagnostic_source "`this_specification'"
                    if inlist("`this_term'", "KP_LM", "CD_F", "KP_F") {
                        if substr("`this_specification'",1,9) == "iv_first_" {
                            local diagnostic_source "iv_2sls"
                            if lower("`model'") == "iv" local diagnostic_source "main"
                        }
                        else local diagnostic_source "__jo_diagnostic_not_here__"
                    }
                    if specification[`row'] == "`diagnostic_source'" & term[`row'] == "`lookup_term'" {
                        local stars ""
                        if !missing(p_value[`row']) {
                            if p_value[`row'] <= `pstar1' local stars "***"
                            else if p_value[`row'] <= `pstar2' local stars "**"
                            else if p_value[`row'] <= `pstar3' local stars "*"
                        }
                        if !missing(estimate[`row']) local coefficient = strtrim(string(estimate[`row'], "`number_format'")) + "`stars'"
                        continue, break
                    }
                }
                _journalone_rtf_escape, text(`"`coefficient'"')
                file write `rtf_handle' "\tab\qc `r(escaped)'"
            }
            file write `rtf_handle' "\par" _n

            if !inlist("`this_term'", "KP_LM", "CD_F", "KP_F", "OVB_F", "FIRST_STAGE_F") {
                file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`table_tabs'\ql "
                forvalues model_index = 1/`model_count' {
                    local this_specification : word `model_index' of `table_specs'
                    local lookup_term "`this_term'"
                    if "`this_specification'" == "psm_weighted" & ///
                        "`this_term'" == "`primary_x'" & "`treat'" != "" {
                        local lookup_term "`treat'"
                    }
                    local reported_stat ""
                    forvalues row = 1/`=_N' {
                        if specification[`row'] == "`this_specification'" & term[`row'] == "`lookup_term'" {
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

        _journalone_rtf_escape, text("R²_adjusted")
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1\brdrb\brdrs\brdrw20\brsp20`table_tabs'\ql `r(escaped)'"
        forvalues model_index = 1/`model_count' {
            local fit_display ""
            local fit_specification : word `model_index' of `table_specs'
            local hide_fit = ("`fit_specification'" == "iv_2sls")
            if "`fit_specification'" == "main" & lower("`model'") == "iv" local hide_fit = 1
            if !`hide_fit' & !missing(`fit`model_index'') {
                local fit_display = strtrim(string(`fit`model_index'', "`number_format'"))
            }
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
    _journalone_rtf_escape, text("列顺序按实际运行的规格排列；控制变量和固定效应以表中“是/否”标记表示，完整控制变量系数保留在CSV和DO文件中。")
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    if "`treat'" != "" & "`primary_x'" != "" {
        _journalone_rtf_escape, text("PSM加权列在核心效应行报告处理组变量 `treat' 的系数；该处理变量由研究者按 `primary_x' 的处理定义构造。")
        file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    }
    local star_note "* p < `pstar3', ** p < `pstar2', *** p < `pstar1'"
    _journalone_rtf_escape, text(`"`star_note'"')
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `r(escaped)'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(regression) ///
        title(`"`title'"') decimals(`decimals') pstar1(`pstar1')       ///
        pstar2(`pstar2') pstar3(`pstar3')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
