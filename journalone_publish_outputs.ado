*! version 0.9.17 19aug2026

capture program drop journalone_publish_outputs
program define journalone_publish_outputs, rclass
    version 16.0
    _journalone_require_license
    syntax , PACKAGEDIR(string) RUNID(string) SOURCECOMMAND(string)      ///
        [ RESULTS(string) DESCRIPTIVE(string) DATAFILE(string)           ///
          MODEL(string) DEPVAR(string) INDEPVARS(string) CONTROLS(string) ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE               ///
          VCETYPE(string) CLUSTER(string) IVCLUSTER(string)              ///
          MODEL2(string) DEPVAR2(string) INDEPVARS2(string) CONTROLS2(string) ///
          PANEL2(string) TIME2(string) ABSORB2(string) TIMEFE2           ///
          VCETYPE2(string) CLUSTER2(string) IFCOND2(string)              ///
          MODEL3(string) DEPVAR3(string) INDEPVARS3(string) CONTROLS3(string) ///
          PANEL3(string) TIME3(string) ABSORB3(string) TIMEFE3           ///
          VCETYPE3(string) CLUSTER3(string) IFCOND3(string)              ///
          MODEL4(string) DEPVAR4(string) INDEPVARS4(string) CONTROLS4(string) ///
          PANEL4(string) TIME4(string) ABSORB4(string) TIMEFE4           ///
          VCETYPE4(string) CLUSTER4(string) IFCOND4(string)              ///
          MODEL5(string) DEPVAR5(string) INDEPVARS5(string) CONTROLS5(string) ///
          PANEL5(string) TIME5(string) ABSORB5(string) TIMEFE5           ///
          VCETYPE5(string) CLUSTER5(string) IFCOND5(string)              ///
          MODEL6(string) DEPVAR6(string) INDEPVARS6(string) CONTROLS6(string) ///
          PANEL6(string) TIME6(string) ABSORB6(string) TIMEFE6           ///
          VCETYPE6(string) CLUSTER6(string) IFCOND6(string)              ///
          TREAT(string) POSTVAR(string) ENDOG(string) INSTRUMENTS(string) OVBTEST ///
          IFCOND(string) DESCSAMPLE(string) ALTY(string) ALTX(string)    ///
          CUSTOMSPECS(string)                                            ///
          ADDCONTROLS(string) ADDFE(string) LAGS(string) LEADS(string)  ///
          SUBSAMPLE(string) ALTVCE(string) ALTCLUSTER(string)           ///
          MEDIATORS(string) MEDCLUSTERS(string) MODERATORS(string)      ///
          MODINTERACTIONS(string) GROUP(string)                         ///
          PSMMETHOD(string) PSMCOVARS(string) PSMTIME(string) PSMWEIGHT(string) ///
          PSMNEIGHBOR(integer 1) HECKMANSEL(string)                      ///
          HECKMANCOVARS(string) HECKMANIMR(string) HECKMANOUTCOVARS(string) ///
          HECKMANFE GMMMETHOD(string)                                    ///
          GMMEXTRA(string) GMMLAGS(integer 1) GMMTWOSTEP                ///
          DMLMETHOD(string) DMLINSTRUMENTS(string) DMLCONTROLS(string) ///
          DMLFOLDS(integer 5)                                            ///
          REPS(integer 1) SEED(integer 20260814)                         ///
          ADJUSTMETHOD(string) WINSORLOW(real 1) WINSORHIGH(real 99)    ///
          PTREND PTBASE(integer -1) GROUPBINS(integer 0) GROUPTEST      ///
          LEVEL(real 95) DECIMALS(integer 3) STATISTIC(string)          ///
          PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)              ///
          PUBLISHMODULES(string) ]

    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") exit 198
    capture mkdir `"`packagedir'"'

    local warnings = 0
    local module_count = 0
    * The publisher is also callable directly by tests and by downstream
    * wrappers.  Normalize multi-variable options here as well as in the
    * main command, so every emitted DO file matches the actual specification.
    local indepvars = subinstr(strtrim(`"`indepvars'"'), char(34), "", .)
    local controls = subinstr(strtrim(`"`controls'"'), char(34), "", .)
    local absorb = subinstr(strtrim(`"`absorb'"'), char(34), "", .)
    local endog = subinstr(strtrim(`"`endog'"'), char(34), "", .)
    local instruments = subinstr(strtrim(`"`instruments'"'), char(34), "", .)
    local mediators = subinstr(strtrim(`"`mediators'"'), char(34), "", .)
    local moderators = subinstr(strtrim(`"`moderators'"'), char(34), "", .)
    local psmcovars = subinstr(strtrim(`"`psmcovars'"'), char(34), "", .)
    local heckmancovars = subinstr(strtrim(`"`heckmancovars'"'), char(34), "", .)
    local heckmanoutcovars = subinstr(strtrim(`"`heckmanoutcovars'"'), char(34), "", .)
    local gmmextra = subinstr(strtrim(`"`gmmextra'"'), char(34), "", .)
    local dmlinstruments = subinstr(strtrim(`"`dmlinstruments'"'), char(34), "", .)
    local dmlcontrols = subinstr(strtrim(`"`dmlcontrols'"'), char(34), "", .)
    local customspecs = subinstr(strtrim(`"`customspecs'"'), char(34), "", .)
    local ifcond = subinstr(strtrim(`"`ifcond'"'), char(34), "", .)
    local publishmodules = lower(subinstr(strtrim(`"`publishmodules'"'), char(34), "", .))
    if strtrim(`"`publishmodules'"') != "" {
        local normalized_publishmodules ""
        foreach requested_module of local publishmodules {
            if !inlist("`requested_module'", "none", "descriptive", "baseline", ///
                "robustness", "endogeneity", "mechanism", "heterogeneity") {
                display as error "publishmodules() 包含未知模块：`requested_module'"
                exit 198
            }
            if !strpos(" `normalized_publishmodules' ", " `requested_module' ") {
                local normalized_publishmodules "`normalized_publishmodules' `requested_module'"
            }
        }
        local publishmodules = strtrim("`normalized_publishmodules'")
        if strpos(" `publishmodules' ", " none ") & "`publishmodules'" != "none" {
            display as error "publishmodules(none) 不能与其他模块同时使用"
            exit 198
        }
    }
    local package_dirs ""
    local rtf_files ""
    local do_files ""
    local csv_files ""
    local published_modules ""

    local descriptive_rtf ""
    local descriptive_do ""
    local descriptive_csv ""
    local descriptive_dir ""
    local baseline_rtf ""
    local baseline_do ""
    local baseline_csv ""
    local baseline_dir ""
    local robustness_rtf ""
    local robustness_do ""
    local robustness_csv ""
    local robustness_dir ""
    local endogeneity_rtf ""
    local endogeneity_do ""
    local endogeneity_csv ""
    local endogeneity_dir ""
    local mechanism_rtf ""
    local mechanism_do ""
    local mechanism_csv ""
    local mechanism_dir ""
    local heterogeneity_rtf ""
    local heterogeneity_do ""
    local heterogeneity_csv ""
    local heterogeneity_dir ""

    local publish_descriptive = (strtrim(`"`publishmodules'"') == "" | ///
        strpos(" `publishmodules' ", " descriptive ") > 0)
    if strtrim(`"`descriptive'"') != "" & `publish_descriptive' {
        capture confirm file `"`descriptive'"'
        if _rc local ++warnings
        else {
            local descriptive_dir `"`packagedir'/描述性统计分析结果"'
            capture mkdir `"`descriptive_dir'"'
            local descriptive_rtf `"`descriptive_dir'/描述性统计分析.rtf"'
            local descriptive_do `"`descriptive_dir'/描述性统计分析.do"'
            local descriptive_csv `"`descriptive_dir'/描述性统计分析.csv"'
            preserve
            quietly use `"`descriptive'"', clear
            local do_descvars ""
            forvalues row = 1/`=_N' {
                local do_variable = variable[`row']
                local do_descvars "`do_descvars' `do_variable'"
            }
            local do_descvars = strtrim("`do_descvars'")
            capture drop analysis_module
            generate str40 analysis_module = "描述性统计分析"
            order analysis_module run_id variable_order variable_role variable variable_label
            capture noisily export delimited using `"`descriptive_csv'"', replace
            if _rc {
                local descriptive_csv ""
                local ++warnings
            }
            capture noisily _journalone_write_desc_rtf,                  ///
                file(`"`descriptive_rtf'"') title("描述性统计分析")    ///
                decimals(`decimals')
            if _rc {
                local descriptive_rtf ""
                local ++warnings
            }
            capture noisily journalone_write_do,                        ///
                file(`"`descriptive_do'"') title("描述性统计分析")   ///
                module("descriptive") runid("`runid'")               ///
                sourcecommand(`"`sourcecommand'"') datafile(`"`datafile'"') ///
                outputdir(`"`descriptive_dir'"') model("`model'")    ///
                depvar("`depvar'") indepvars(`"`indepvars'"')       ///
                controls(`"`controls'"') panel("`panel'") time("`time'") ///
                absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                treat("`treat'") postvar("`postvar'") endog(`"`endog'"') ///
                instruments(`"`instruments'"') ifcond(`"`ifcond'"') ///
                descvars(`"`do_descvars'"') descsample("`descsample'") ///
                decimals(`decimals') statistic("`statistic'") level(`level') ///
                pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3') `timefe'
            if _rc {
                local descriptive_do ""
                local ++warnings
            }
            restore
            if "`descriptive_rtf'" != "" & "`descriptive_do'" != "" & "`descriptive_csv'" != "" {
                local ++module_count
                local published_modules "`published_modules' descriptive"
                local package_dirs `"`package_dirs' `descriptive_dir'"'
                local rtf_files `"`rtf_files' `descriptive_rtf'"'
                local do_files `"`do_files' `descriptive_do'"'
                local csv_files `"`csv_files' `descriptive_csv'"'
            }
        }
    }

    if strtrim(`"`results'"') != "" {
        capture confirm file `"`results'"'
        if _rc local ++warnings
        else {
            foreach module_id in baseline robustness endogeneity mechanism heterogeneity {
                if strtrim(`"`publishmodules'"') != "" &                 ///
                    !strpos(" `publishmodules' ", " `module_id' ") continue
                preserve
                quietly use `"`results'"', clear
                if "`module_id'" == "baseline" {
                    quietly keep if specification == "main" | ///
                        substr(specification,1,9) == "baseline_"
                    local module_title "基准回归分析"
                    local module_stub "baseline"
                }
                else if "`module_id'" == "robustness" {
                    generate byte __jo_robust_spec =                              ///
                        substr(specification,1,6) == "alt_y_" |                 ///
                        substr(specification,1,6) == "alt_x_" |                 ///
                        substr(specification,1,7) == "custom_" |               ///
                        inlist(specification, "additional_controls",             ///
                            "additional_fe", "subsample", "alternative_vce",   ///
                            "parallel_trend") |                                 ///
                        substr(specification,1,4) == "lag_" |                    ///
                        substr(specification,1,5) == "lead_" |                   ///
                        substr(specification,1,7) == "winsor_"
                    quietly count if __jo_robust_spec
                    if r(N) > 0 {
                        * Keep the original main model as a comparator.  It is
                        * repeated in continuation tables by the RTF writer.
                        quietly keep if __jo_robust_spec | specification == "main"
                    }
                    else quietly keep if 0
                    drop __jo_robust_spec
                    local module_title "稳健性检验"
                    local module_stub "robustness"
                }
                else if "`module_id'" == "endogeneity" {
                    local iv_main ""
                    if "`model'" == "iv" local iv_main `"| specification == "main""'
                    quietly keep if substr(specification,1,4) == "psm_" |       ///
                        substr(specification,1,3) == "iv_" |                    ///
                        substr(specification,1,4) == "ovb_" |                   ///
                        substr(specification,1,8) == "heckman_" |                ///
                        substr(specification,1,4) == "gmm_" |                    ///
                        substr(specification,1,4) == "dml_" `iv_main'
                    local module_title "内生性检验"
                    local module_stub "endogeneity"
                }
                else if "`module_id'" == "mechanism" {
                    quietly keep if substr(specification,1,4) == "med_" |       ///
                        substr(specification,1,10) == "moderator_"
                    local module_title "机制检验"
                    local module_stub "mechanism"
                }
                else {
                    quietly keep if substr(specification,1,6) == "group_"
                    local module_title "异质性分析"
                    local module_stub "heterogeneity"
                }

                quietly count
                if r(N) > 0 {
                    if "`module_id'" == "endogeneity" {
                        generate long __jo_endog_priority = 90
                        replace __jo_endog_priority = 10 if substr(specification,1,4) == "psm_"
                        replace __jo_endog_priority = 20 if specification == "heckman_selection"
                        replace __jo_endog_priority = 30 if specification == "heckman_twostep"
                        replace __jo_endog_priority = 40 if substr(specification,1,9) == "iv_first_"
                        replace __jo_endog_priority = 50 if specification == "iv_2sls" | specification == "main"
                        replace __jo_endog_priority = 60 if substr(specification,1,4) == "ovb_"
                        replace __jo_endog_priority = 70 if substr(specification,1,4) == "gmm_"
                        replace __jo_endog_priority = 80 if substr(specification,1,4) == "dml_"
                        sort __jo_endog_priority specification_order term_order
                        generate long __jo_endog_row = _n
                        bysort specification: egen long __jo_endog_first = min(__jo_endog_row)
                        drop specification_order
                        egen long specification_order = group(__jo_endog_first)
                        drop __jo_endog_priority __jo_endog_row __jo_endog_first
                    }
                    else sort specification_order term_order
                    local do_specs ""
                    forvalues row = 1/`=_N' {
                        local do_specification = specification[`row']
                        if !strpos(" `do_specs' ", " `do_specification' ") {
                            local do_specs "`do_specs' `do_specification'"
                        }
                    }
                    local do_specs = strtrim("`do_specs'")
                    _journalone_add_spec_labels
                    * When IV is the baseline estimator, main is the actual
                    * structural second-stage equation rather than an OLS
                    * comparator.  Label it explicitly in the endogeneity
                    * package so the table remains self-explanatory.
                    if "`module_id'" == "endogeneity" & "`model'" == "iv" {
                        replace specification_label = "IV第二阶段（2SLS）" ///
                            if specification == "main"
                    }
                    capture confirm variable r2_a
                    if _rc generate double r2_a = .
                    foreach generated_var in analysis_module t_value             ///
                        significance estimate_with_stars reported_statistic       ///
                        statistic_type {
                        capture drop `generated_var'
                    }
                    generate str40 analysis_module = "`module_title'"
                    generate double t_value = estimate/std_error
                    generate str4 significance = cond(p_value<=`pstar1', "***", ///
                        cond(p_value<=`pstar2', "**",                            ///
                        cond(p_value<=`pstar3', "*", ""))) if !missing(p_value)
                    replace significance = "" if missing(significance)
                    generate str40 estimate_with_stars =                         ///
                        strtrim(string(estimate, "%21.`decimals'f")) + significance ///
                        if !missing(estimate)
                    if "`statistic'" == "t" {
                        generate double reported_statistic = t_value
                        generate str8 statistic_type = "t"
                    }
                    else {
                        generate double reported_statistic = std_error
                        generate str8 statistic_type = "SE"
                    }
                    order analysis_module run_id specification_order             ///
                        specification specification_label outcome term_order      ///
                        term term_label estimate std_error t_value                ///
                        reported_statistic statistic_type p_value significance   ///
                        estimate_with_stars ci_low ci_high N r2 r2_a

                    local module_dir `"`packagedir'/`module_title'结果"'
                    capture mkdir `"`module_dir'"'
                    local module_rtf `"`module_dir'/`module_title'.rtf"'
                    local module_do `"`module_dir'/`module_title'.do"'
                    local module_csv `"`module_dir'/`module_title'.csv"'
                    capture noisily export delimited using `"`module_csv'"', replace
                    if _rc {
                        local module_csv ""
                        local ++warnings
                    }
                    if "`module_id'" == "baseline" {
                        capture noisily _journalone_write_baseline_rtf,          ///
                            file(`"`module_rtf'"') title("`module_title'")     ///
                            decimals(`decimals') statistic("`statistic'")      ///
                            pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3') ///
                            model("`model'") controls(`"`controls'"')       ///
                            absorb(`"`absorb'"') panel("`panel'")           ///
                            time("`time'") `timefe'                        ///
                            controls2(`"`controls2'"') absorb2(`"`absorb2'"') ///
                            panel2("`panel2'") time2("`time2'")           ///
                            model2("`model2'") `timefe2'                    ///
                            controls3(`"`controls3'"') absorb3(`"`absorb3'"') ///
                            panel3("`panel3'") time3("`time3'")           ///
                            model3("`model3'") `timefe3'                    ///
                            controls4(`"`controls4'"') absorb4(`"`absorb4'"') ///
                            panel4("`panel4'") time4("`time4'")           ///
                            model4("`model4'") `timefe4'                    ///
                            controls5(`"`controls5'"') absorb5(`"`absorb5'"') ///
                            panel5("`panel5'") time5("`time5'")           ///
                            model5("`model5'") `timefe5'                    ///
                            controls6(`"`controls6'"') absorb6(`"`absorb6'"') ///
                            panel6("`panel6'") time6("`time6'")           ///
                            model6("`model6'") `timefe6'                    ///
                            addcontrols(`"`addcontrols'"') addfe(`"`addfe'"')
                    }
                    else if "`module_id'" == "robustness" {
                        capture noisily _journalone_write_robustness_rtf,        ///
                            file(`"`module_rtf'"') title("`module_title'")     ///
                            decimals(`decimals') statistic("`statistic'")      ///
                            pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3') ///
                            model("`model'") controls(`"`controls'"')       ///
                            absorb(`"`absorb'"') panel("`panel'")           ///
                            time("`time'") `timefe'                        ///
                            addcontrols(`"`addcontrols'"') addfe(`"`addfe'"')
                    }
                    else if "`module_id'" == "endogeneity" {
                        * Publication table: compact, paper-style columns with
                        * focal terms and identification diagnostics.  The
                        * underlying CSV/DO remain complete and unchanged.
                        capture noisily _journalone_write_endog_rtf,          ///
                            file(`"`module_rtf'"') title("`module_title'")  ///
                            decimals(`decimals') statistic("`statistic'")   ///
                            pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3') ///
                            model("`model'") depvar("`depvar'")            ///
                            indepvars(`"`indepvars'"') controls(`"`controls'"') ///
                            absorb(`"`absorb'"') panel("`panel'")           ///
                            time("`time'") `timefe' `heckmanfe'              ///
                            addcontrols(`"`addcontrols'"') addfe(`"`addfe'"') ///
                            treat("`treat'") endog(`"`endog'"') instruments(`"`instruments'"') ///
                            heckmancovars(`"`heckmancovars'"') heckmanimr("`heckmanimr'") ///
                            heckmanoutcovars(`"`heckmanoutcovars'"')
                    }
                    else {
                        capture noisily _journalone_write_reg_rtf,               ///
                            file(`"`module_rtf'"') title("`module_title'")     ///
                            decimals(`decimals') statistic("`statistic'")      ///
                            pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3') ///
                            model("`model'") controls(`"`controls'"')       ///
                            absorb(`"`absorb'"') panel("`panel'")           ///
                            time("`time'") `timefe' `heckmanfe'
                    }
                    if _rc {
                        local module_rtf ""
                        local ++warnings
                    }
                    capture noisily journalone_write_do,                         ///
                        file(`"`module_do'"') title("`module_title'")          ///
                        module("`module_id'") runid("`runid'")                ///
                        sourcecommand(`"`sourcecommand'"') datafile(`"`datafile'"') ///
                        outputdir(`"`module_dir'"') model("`model'")          ///
                        depvar("`depvar'") indepvars(`"`indepvars'"')         ///
                        controls(`"`controls'"') panel("`panel'") time("`time'") ///
                        ivcluster("`ivcluster'")                          ///
                        absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                        model2("`model2'") depvar2("`depvar2'") indepvars2(`"`indepvars2'"') ///
                        controls2(`"`controls2'"') panel2("`panel2'") time2("`time2'") ///
                        absorb2(`"`absorb2'"') vcetype2("`vcetype2'") cluster2("`cluster2'") ///
                        ifcond2(`"`ifcond2'"') model3("`model3'") depvar3("`depvar3'") ///
                        indepvars3(`"`indepvars3'"') controls3(`"`controls3'"') ///
                        panel3("`panel3'") time3("`time3'") absorb3(`"`absorb3'"') ///
                        vcetype3("`vcetype3'") cluster3("`cluster3'") ifcond3(`"`ifcond3'"') ///
                        model4("`model4'") depvar4("`depvar4'") indepvars4(`"`indepvars4'"') ///
                        controls4(`"`controls4'"') panel4("`panel4'") time4("`time4'") ///
                        absorb4(`"`absorb4'"') vcetype4("`vcetype4'") cluster4("`cluster4'") ///
                        ifcond4(`"`ifcond4'"')                            ///
                        model5("`model5'") depvar5("`depvar5'") indepvars5(`"`indepvars5'"') ///
                        controls5(`"`controls5'"') panel5("`panel5'") time5("`time5'") ///
                        absorb5(`"`absorb5'"') vcetype5("`vcetype5'") cluster5("`cluster5'") ///
                        ifcond5(`"`ifcond5'"') model6("`model6'") depvar6("`depvar6'") ///
                        indepvars6(`"`indepvars6'"') controls6(`"`controls6'"') ///
                        panel6("`panel6'") time6("`time6'") absorb6(`"`absorb6'"') ///
                        vcetype6("`vcetype6'") cluster6("`cluster6'") ifcond6(`"`ifcond6'"') ///
                        treat("`treat'") postvar("`postvar'") endog(`"`endog'"') ///
                        instruments(`"`instruments'"') ifcond(`"`ifcond'"')   ///
                        specs(`"`do_specs'"') alty(`"`alty'"') altx(`"`altx'"') ///
                        customspecs(`"`customspecs'"')                           ///
                        addcontrols(`"`addcontrols'"') addfe(`"`addfe'"')     ///
                        lags("`lags'") leads("`leads'") subsample(`"`subsample'"') ///
                        altvce("`altvce'") altcluster("`altcluster'")         ///
                        mediators("`mediators'") medclusters("`medclusters'") ///
                        moderators("`moderators'") modinteractions("`modinteractions'") ///
                        group("`group'") psmmethod("`psmmethod'")            ///
                        psmcovars(`"`psmcovars'"') psmtime("`psmtime'") psmweight("`psmweight'") ///
                        psmneighbor(`psmneighbor') heckmansel("`heckmansel'") ///
                        heckmancovars(`"`heckmancovars'"') heckmanimr("`heckmanimr'") ///
                        heckmanoutcovars(`"`heckmanoutcovars'"') gmmmethod("`gmmmethod'") ///
                        gmmextra(`"`gmmextra'"') gmmlags(`gmmlags')           ///
                        dmlmethod("`dmlmethod'") dmlinstruments(`"`dmlinstruments'"') ///
                        dmlcontrols(`"`dmlcontrols'"') dmlfolds(`dmlfolds')   ///
                        reps(`reps') seed(`seed') adjustmethod("`adjustmethod'") ///
                        winsorlow(`winsorlow') winsorhigh(`winsorhigh')         ///
                        ptbase(`ptbase') groupbins(`groupbins')                 ///
                        decimals(`decimals') statistic("`statistic'") level(`level') ///
                        pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3')      ///
                        `timefe' `timefe2' `timefe3' `timefe4' `timefe5' `timefe6' `heckmanfe' ///
                        `gmmtwostep' `ptrend' `grouptest' `ovbtest'
                    if _rc {
                        local module_do ""
                        local ++warnings
                    }

                    local `module_stub'_rtf `"`module_rtf'"'
                    local `module_stub'_do `"`module_do'"'
                    local `module_stub'_csv `"`module_csv'"'
                    local `module_stub'_dir `"`module_dir'"'
                    if "`module_rtf'" != "" & "`module_do'" != "" & "`module_csv'" != "" {
                        local ++module_count
                        local published_modules "`published_modules' `module_id'"
                        local package_dirs `"`package_dirs' `module_dir'"'
                        local rtf_files `"`rtf_files' `module_rtf'"'
                        local do_files `"`do_files' `module_do'"'
                        local csv_files `"`csv_files' `module_csv'"'
                    }
                }
                restore
            }
        }
    }

    local package_dirs = strtrim(`"`package_dirs'"')
    local rtf_files = strtrim(`"`rtf_files'"')
    local do_files = strtrim(`"`do_files'"')
    local csv_files = strtrim(`"`csv_files'"')
    local published_modules = stritrim(strtrim(`"`published_modules'"'))
    return local package_dir `"`packagedir'"'
    return local package_dirs `"`package_dirs'"'
    return local rtf_files `"`rtf_files'"'
    return local do_files `"`do_files'"'
    return local csv_files `"`csv_files'"'
    return local published_modules `"`published_modules'"'
    return local descriptive_rtf `"`descriptive_rtf'"'
    return local descriptive_do `"`descriptive_do'"'
    return local descriptive_csv `"`descriptive_csv'"'
    return local descriptive_dir `"`descriptive_dir'"'
    return local baseline_rtf `"`baseline_rtf'"'
    return local baseline_do `"`baseline_do'"'
    return local baseline_csv `"`baseline_csv'"'
    return local baseline_dir `"`baseline_dir'"'
    return local robustness_rtf `"`robustness_rtf'"'
    return local robustness_do `"`robustness_do'"'
    return local robustness_csv `"`robustness_csv'"'
    return local robustness_dir `"`robustness_dir'"'
    return local endogeneity_rtf `"`endogeneity_rtf'"'
    return local endogeneity_do `"`endogeneity_do'"'
    return local endogeneity_csv `"`endogeneity_csv'"'
    return local endogeneity_dir `"`endogeneity_dir'"'
    return local mechanism_rtf `"`mechanism_rtf'"'
    return local mechanism_do `"`mechanism_do'"'
    return local mechanism_csv `"`mechanism_csv'"'
    return local mechanism_dir `"`mechanism_dir'"'
    return local heterogeneity_rtf `"`heterogeneity_rtf'"'
    return local heterogeneity_do `"`heterogeneity_do'"'
    return local heterogeneity_csv `"`heterogeneity_csv'"'
    return local heterogeneity_dir `"`heterogeneity_dir'"'
    return scalar modules = `module_count'
    return scalar warnings = `warnings'
end


capture program drop _journalone_add_spec_labels
program define _journalone_add_spec_labels
    version 16.0
    capture drop specification_label term_label
    generate str244 specification_label = specification
    replace specification_label = "基准模型" if specification == "main"
    replace specification_label = "基准模型（" + substr(specification,10,.) + "）" ///
        if substr(specification,1,9) == "baseline_"
    replace specification_label = "替换被解释变量：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "alt_y_"
    replace specification_label = "替换核心解释变量：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "alt_x_"
    replace specification_label = "自定义规格 " + substr(specification,8,.) ///
        if substr(specification,1,7) == "custom_"
    replace specification_label = "增加控制变量" if specification == "additional_controls"
    replace specification_label = "增加固定效应" if specification == "additional_fe"
    replace specification_label = "替代样本" if specification == "subsample"
    replace specification_label = "核心变量滞后" + substr(specification,5,.) + "期" ///
        if substr(specification,1,4) == "lag_"
    replace specification_label = "核心变量超前" + substr(specification,6,.) + "期" ///
        if substr(specification,1,5) == "lead_"
    replace specification_label = "替代标准误" if specification == "alternative_vce"
    replace specification_label = "分位缩尾：" + substr(specification,8,.) ///
        if substr(specification,1,7) == "winsor_"
    replace specification_label = "平行趋势检验" if specification == "parallel_trend"
    replace specification_label = "PSM：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "psm_"
    replace specification_label = "PSM加权结果" if specification == "psm_weighted"
    replace specification_label = "PSM近邻匹配（ATT）" if specification == "psm_nearest"
    replace specification_label = "IV第一阶段：" + outcome ///
        if substr(specification,1,9) == "iv_first_"
    replace specification_label = "IV第二阶段（2SLS）" if specification == "iv_2sls"
    replace specification_label = "Heckman第一阶段（选择方程）" ///
        if specification == "heckman_selection"
    replace specification_label = "Heckman第二阶段（结果方程）" ///
        if specification == "heckman_twostep"
    replace specification_label = "动态GMM：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "gmm_"
    replace specification_label = "双重机器学习：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "dml_"
    replace specification_label = "机制路径A：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "med_a_"
    replace specification_label = "机制路径B：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "med_b_"
    replace specification_label = "调节效应：" + substr(specification,11,.) ///
        if substr(specification,1,10) == "moderator_"
    replace specification_label = "异质性分组：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "group_"
    generate str244 term_label = term
    * Generated diagnostics may be translated; user variable names remain
    * exactly as Stata returned them in term_label.
    replace term_label = "遗漏变量偏误F值" if term == "OVB_F"
    replace term_label = "第一阶段排除工具变量F值" if term == "FIRST_STAGE_F"
    replace term_label = "Kleibergen–Paap rk LM" if term == "KP_LM"
    replace term_label = "Cragg–Donald Wald F" if term == "CD_F"
    replace term_label = "Kleibergen–Paap rk Wald F" if term == "KP_F"
    replace term_label = "逆米尔斯比率（IMR）" if term == "lambda"
    replace term_label = "逆米尔斯比率（IMR）" if specification == "heckman_twostep" & ///
        substr(term,1,2) == "__"
    * Keep every reported variable/term exactly as Stata returned it.
    * In particular, do not translate English names such as _cons into Chinese.
end


capture program drop _journalone_write_repro_do
program define _journalone_write_repro_do
    version 16.0
    syntax , FILE(string) TITLE(string) RUNID(string) SOURCECOMMAND(string)
    tempname do_handle
    file open `do_handle' using `"`file'"', write text replace
    file write `do_handle' "*! JournalOne 0.7.0 兼容性包装脚本" _n
    file write `do_handle' "* 模块：`title'" _n
    file write `do_handle' "* 原运行编号：`runid'" _n
    file write `do_handle' "* 运行前请先载入与原分析相同的数据。" _n
    file write `do_handle' "version 16.0" _n
    file write `do_handle' `"`sourcecommand'"' _n
    file close `do_handle'
end


capture program drop _journalone_write_desc_rtf
program define _journalone_write_desc_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3)]
    sort variable_order
    quietly count
    if r(N) == 0 exit 2000

    * Keep the Chinese table/file names; only the statistical headers are English.
    local output_title `"`title'"'
    if inlist(strtrim(`"`title'"'), "描述性统计分析", "描述性统计") {
        local output_title "表 A1：描述性统计"
    }
    _journalone_rtf_escape, text(`"`output_title'"')
    local rtf_title `"`r(escaped)'"'
    local header1 "Variable"
    local header2 "N"
    local header3 "Mean"
    local header4 "SD"
    local header5 "Min"
    local header6 "Max"
    forvalues column = 1/6 {
        _journalone_rtf_escape, text(`"`header`column''"')
        local rtf_header`column' `"`r(escaped)'"'
    }

    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    * ISO A4 portrait: 210 x 297 mm.  \sl360\slmult1 is Word's 1.5-line spacing.
    file write `rtf_handle' "\paperw11907\paperh16840\margl720\margr720\margt720\margb720" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\b\f0\fs24 `rtf_title'\b0\par" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\f0\fs18\par" _n
    local descriptive_tabs "\tqr\tx4400\tqr\tx5900\tqr\tx7400\tqr\tx8900\tqr\tx10400"
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`descriptive_tabs'\ql\b `rtf_header1'\b0"
    forvalues column = 2/6 {
        file write `rtf_handle' "\tab\b `rtf_header`column''\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    forvalues row = 1/`=_N' {
        * Publication tables display the actual Stata variable name, never its label.
        local cell1 = variable[`row']
        local cell2 = strtrim(string(N_nonmissing[`row'], "%12.0f"))
        local cell3 = strtrim(string(mean[`row'], "`number_format'"))
        local cell4 = strtrim(string(sd[`row'], "`number_format'"))
        local cell5 = strtrim(string(min[`row'], "`number_format'"))
        local cell6 = strtrim(string(max[`row'], "`number_format'"))
        forvalues column = 1/6 {
            _journalone_rtf_escape, text(`"`cell`column''"')
            local rtf_cell`column' `"`r(escaped)'"'
        }
        local bottom_border ""
        if `row' == _N local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`descriptive_tabs'\ql `rtf_cell1'"
        forvalues column = 2/6 {
            file write `rtf_handle' "\tab `rtf_cell`column''"
        }
        file write `rtf_handle' "\par" _n
    }
    local raw_note "注：N为非缺失观测数；变量按用户设定顺序报告，左列使用Stata中的原始变量名，不使用变量标签且不进行翻译。"
    _journalone_rtf_escape, text(`"`raw_note'"')
    local rtf_note `"`r(escaped)'"'
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `rtf_note'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(descriptive) ///
        title(`"`title'"') decimals(`decimals')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end


* Legacy inline writer retained under a private name for old cached sessions;
* the package now uses the standalone writer with design-metadata rows.
capture program drop _journalone_write_reg_rtf_legacy
program define _journalone_write_reg_rtf_legacy
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)]
    if "`statistic'" == "" local statistic "se"
    sort specification_order term_order
    quietly count
    if r(N) == 0 exit 2000

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    local header1 "模型"
    local header2 "因变量"
    local header3 "变量"
    local header4 "系数"
    if "`statistic'" == "t" local header5 "t值"
    else local header5 "标准误"
    local header6 "p值"
    local header7 "N"
    local header8 "R²"
    forvalues column = 1/8 {
        _journalone_rtf_escape, text(`"`header`column''"')
        local rtf_header`column' `"`r(escaped)'"'
    }

    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    * ISO A4 portrait: 210 x 297 mm.  \sl360\slmult1 is Word's 1.5-line spacing.
    file write `rtf_handle' "\paperw11907\paperh16840\margl720\margr720\margt720\margb720" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\b\f0\fs24 `rtf_title'\b0\par" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\f0\fs18\par" _n
    local regression_tabs "\tx2200\tx3400\tqr\tx5700\tqr\tx6900\tqr\tx8000\tqr\tx9100\tqr\tx10400"
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`regression_tabs'\ql\b `rtf_header1'\b0"
    file write `rtf_handle' "\tab\b `rtf_header2'\b0"
    file write `rtf_handle' "\tab\b `rtf_header3'\b0"
    forvalues column = 4/8 {
        file write `rtf_handle' "\tab\b `rtf_header`column''\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    forvalues row = 1/`=_N' {
        local cell1 = specification_label[`row']
        local cell2 = outcome[`row']
        local cell3 = term_label[`row']
        local stars ""
        if !missing(p_value[`row']) {
            if p_value[`row'] <= `pstar1' local stars "***"
            else if p_value[`row'] <= `pstar2' local stars "**"
            else if p_value[`row'] <= `pstar3' local stars "*"
        }
        local cell4 = strtrim(string(estimate[`row'], "`number_format'")) + "`stars'"
        if "`statistic'" == "t" {
            local cell5 = strtrim(string(estimate[`row']/std_error[`row'], "`number_format'"))
        }
        else local cell5 = strtrim(string(std_error[`row'], "`number_format'"))
        local cell6 = strtrim(string(p_value[`row'], "`number_format'"))
        local cell7 = strtrim(string(N[`row'], "%12.0f"))
        local cell8 = ""
        if !missing(r2[`row']) local cell8 = strtrim(string(r2[`row'], "`number_format'"))
        forvalues column = 1/8 {
            _journalone_rtf_escape, text(`"`cell`column''"')
            local rtf_cell`column' `"`r(escaped)'"'
        }
        local bottom_border ""
        if `row' == _N local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`regression_tabs'\ql `rtf_cell1'"
        file write `rtf_handle' "\tab `rtf_cell2'"
        file write `rtf_handle' "\tab `rtf_cell3'"
        forvalues column = 4/8 {
            file write `rtf_handle' "\tab `rtf_cell`column''"
        }
        file write `rtf_handle' "\par" _n
    }
    local raw_note "注：***、**、*分别表示p≤`pstar1'、p≤`pstar2'、p≤`pstar3'；变量名称按估计结果原文显示，不进行翻译。"
    _journalone_rtf_escape, text(`"`raw_note'"')
    local rtf_note `"`r(escaped)'"'
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `rtf_note'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(regression) ///
        title(`"`title'"') decimals(`decimals') pstar1(`pstar1') ///
        pstar2(`pstar2') pstar3(`pstar3')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
