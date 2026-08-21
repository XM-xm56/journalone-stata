*! version 0.9.17 19aug2026

capture program drop journalone_extra
program define journalone_extra, rclass
    version 16.0
    syntax , HANDLE(name) RUNID(string) RESULTBASE(string) MODEL(string) ///
        DEPVAR(string) [ INDEPVARS(string) CONTROLS(string)                  ///
        PANEL(string) TIME(string) ABSORB(string) TIMEFE                     ///
        VCETYPE(string) CLUSTER(string) TREAT(string) POSTVAR(string)       ///
        IVCLUSTER(string)                                                     ///
        ENDOG(string) INSTRUMENTS(string) IFCOND(string)                    ///
        LEVEL(real 95) SEED(integer 20260814)                               ///
        PSMMETHOD(string) PSMCOVARS(string) PSMTIME(string) PSMWEIGHT(string) ///
        PSMNEIGHBOR(integer 1) HECKMANSEL(string) HECKMANCOVARS(string)     ///
        HECKMANIMR(string) HECKMANOUTCOVARS(string) HECKMANFE GMMMETHOD(string) ///
        GMMEXTRA(string) GMMLAGS(integer 1) GMMTWOSTEP                      ///
        DMLMETHOD(string) DMLINSTRUMENTS(string)                            ///
        DMLCONTROLS(string) DMLFOLDS(integer 5) OVBTEST                    ///
        PTREND PTLEVEL(real 95) PTBASE(integer -1)                          ///
        GROUP(string) GROUPBINS(integer 0) GROUPTEST                        ///
        MODPLOT MODERATORS(string) MEDCLUSTERS(string asis)                  ///
        MODINTERACTIONS(string asis) ADJUSTMETHOD(string)                    ///
        WINSORLOW(real 1) WINSORHIGH(real 99) REPS(integer 1) ]

    local models = 0
    local warnings = 0
    local parallel_test_file ""
    local group_test_file ""
    local moderation_files ""
    local ifqual ""
    if strtrim(`"`ifcond'"') != "" local ifqual `"if `ifcond'"'
    local modinteractions = subinstr(strtrim(`"`modinteractions'"'), char(34), "", .)

    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"

    * A prior matching workflow may already have produced validated numeric
    * weights.  When explicitly supplied, estimate the weighted outcome
    * equation as its own auditable PSM column; no variable name is assumed.
    if strtrim(`"`psmweight'"') != "" {
        capture confirm numeric variable `psmweight'
        if _rc {
            noisily display as error "PSM权重变量不存在或不是数值型；已跳过加权规格"
            local ++warnings
        }
        else {
            local weighted_vce ""
            * A weighted PSM outcome equation estimates the effect of the
            * treatment indicator.  Fall back to the main X list only when no
            * treatment variable was supplied (legacy command compatibility).
            local weighted_rhs = strtrim(`"`indepvars'"')
            if strtrim("`treat'") != "" local weighted_rhs "`treat'"
            if "`vcetype'" == "robust" local weighted_vce "vce(robust)"
            else if "`vcetype'" == "cluster" local weighted_vce "vce(cluster `cluster')"
            capture noisily {
                if "`model'" == "hdfe" {
                    local weighted_absorb = strtrim(`"`absorb'"')
                    if "`timefe'" != "" & "`time'" != "" & ///
                        !strpos(" `weighted_absorb' ", " `time' ") {
                        local weighted_absorb = strtrim("`weighted_absorb' `time'")
                    }
                    local weighted_absorbopt "noabsorb"
                    if strtrim(`"`weighted_absorb'"') != "" local weighted_absorbopt "absorb(`weighted_absorb')"
                    reghdfe `depvar' `weighted_rhs' `controls' [fweight=`psmweight'] ///
                        `ifqual', `weighted_absorbopt' `weighted_vce'
                }
                else {
                    local weighted_fe ""
                    foreach fevar of local absorb {
                        local weighted_fe "`weighted_fe' i.`fevar'"
                    }
                    regress `depvar' `weighted_rhs' `controls' `weighted_fe' ///
                        [fweight=`psmweight'] `ifqual', `weighted_vce'
                }
            }
            local weighted_rc = _rc
            if `weighted_rc' {
                noisily display as error "PSM加权结果失败；请检查权重变量和模型设定"
                local ++warnings
            }
            else {
                _journalone_post_current, handle(`handle') runid("`runid'") ///
                    spec("psm_weighted") outcome("`depvar'") level(`level')
                local ++models
            }
        }
    }

    * Propensity-score matching. Official teffects is used for nearest-neighbor;
    * radius and kernel matching require the installed psmatch2 command.
    if "`psmmethod'" != "" & "`psmmethod'" != "none" {
        if "`treat'" == "" {
            noisily display as error "PSM需要0/1处理组变量；已跳过"
            local ++warnings
        }
        else {
            capture confirm numeric variable `treat'
            if _rc {
                noisily display as error "PSM处理变量必须为数值型0/1变量；已跳过"
                local ++warnings
            }
            else {
                local psm_covars = strtrim(`"`psmcovars'"')
                if "`psm_covars'" == "" local psm_covars = strtrim(`"`indepvars' `controls'"')
                if "`psmtime'" != "" {
                    capture confirm numeric variable `psmtime'
                    if _rc {
                        noisily display as error "PSM时期变量必须为数值型；已忽略该时期变量"
                        local ++warnings
                    }
                    else local psm_covars `"`psm_covars' i.`psmtime'"'
                }
                if strtrim(`"`psm_covars'"') == "" {
                    noisily display as error "PSM没有可用匹配协变量；已跳过"
                    local ++warnings
                }
                else if "`psmmethod'" == "nearest" {
                    local psm_vce ""
                    if "`vcetype'" == "robust" local psm_vce "vce(robust)"
                    if "`vcetype'" == "cluster" {
                        // teffects psmatch does not accept cluster VCE.  Its
                        // supported robust VCE is used and the substitution
                        // is made explicit in the audit warning count.
                        local psm_vce "vce(robust)"
                        noisily display as text "PSM官方估计不支持cluster VCE；已使用robust VCE"
                        local ++warnings
                    }
                    capture noisily teffects psmatch (`depvar') (`treat' `psm_covars') ///
                        `ifqual', atet nneighbor(`psmneighbor') `psm_vce'
                    if _rc {
                        noisily display as error "PSM近邻匹配失败；已保留其他结果"
                        local ++warnings
                    }
                    else {
                        _journalone_post_current, handle(`handle') runid("`runid'") ///
                            spec("psm_nearest") outcome("`depvar'") level(`level')
                        local ++models
                    }
                }
                else {
                    capture which psmatch2
                    if _rc {
                        noisily display as error "半径/核匹配需要psmatch2；当前未安装，已跳过"
                        local ++warnings
                    }
                    else {
                        preserve
                        capture drop _pscore _weight _treated _support _id _n1 _nn
                        local psm_options "common"
                        if "`psmmethod'" == "radius" local psm_options "radius caliper(.1) common"
                        if "`psmmethod'" == "kernel" local psm_options "kernel common"
                        capture noisily psmatch2 `treat' `psm_covars' `ifqual', ///
                            outcome(`depvar') `psm_options'
                        local psm_rc = _rc
                        if `psm_rc' {
                            noisily display as error "PSM `psmmethod' 匹配失败；已保留其他结果"
                            local ++warnings
                        }
                        else {
                            scalar __jo_att = r(att)
                            scalar __jo_att_se = r(seatt)
                            scalar __jo_att_z = cond(__jo_att_se>0, __jo_att/__jo_att_se, .)
                            scalar __jo_att_p = 2*normal(-abs(__jo_att_z))
                            scalar __jo_att_crit = invnormal(1-(100-`level')/200)
                            scalar __jo_att_low = __jo_att-__jo_att_crit*__jo_att_se
                            scalar __jo_att_high = __jo_att+__jo_att_crit*__jo_att_se
                            capture quietly count if _support == 1 & !missing(_weight)
                            scalar __jo_att_n = cond(_rc, ., r(N))
                            post `handle' ("`runid'") ("psm_`psmmethod'") ("`depvar'") ///
                                (1) ("ATT") (__jo_att) (__jo_att_se) (__jo_att_p) ///
                                (__jo_att_low) (__jo_att_high) (__jo_att_n) (.)
                            local ++models
                        }
                        restore
                    }
                }
            }
        }
    }

    * Report every IV first-stage equation on the same estimation sample as
    * the structural equation.  Multiple endogenous variables therefore
    * produce multiple, clearly named first-stage columns rather than being
    * hidden behind a single 2SLS result.
    if strtrim(`"`endog'"') != "" & strtrim(`"`instruments'"') != "" {
        local iv_first_model "`model'"
        if "`iv_first_model'" == "iv" {
            local iv_first_model "ols"
            capture which reghdfe
            if !_rc & strtrim(`"`absorb'"') != "" local iv_first_model "hdfe"
        }
        if !inlist("`iv_first_model'", "ols", "hdfe", "fe", "re") {
            local iv_first_model "ols"
        }
        local iv_first_cluster "`cluster'"
        if strtrim("`ivcluster'") != "" local iv_first_cluster "`ivcluster'"
        local iv_exogenous = strtrim(`"`indepvars' `controls'"')
        foreach endogenous_variable of local endog {
            local iv_exogenous : list iv_exogenous - endogenous_variable
        }
        foreach instrument_variable of local instruments {
            local iv_exogenous : list iv_exogenous - instrument_variable
        }
        local iv_exogenous : list uniq iv_exogenous
        local iv_first_ifcond `"`ifcond'"'
        if strtrim(`"`iv_first_ifcond'"') == "" {
            local iv_first_ifcond "!missing(`depvar')"
        }
        else local iv_first_ifcond "(`iv_first_ifcond') & !missing(`depvar')"

        local iv_first_index = 0
        foreach endogenous_variable of local endog {
            local ++iv_first_index
            capture noisily _journalone_fit, model("`iv_first_model'") ///
                depvar("`endogenous_variable'") indepvars(`"`instruments'"') ///
                controls(`"`iv_exogenous'"') panel("`panel'") time("`time'") ///
                absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`iv_first_cluster'") ///
                ifcond(`"`iv_first_ifcond'"') `timefeopt'
            local iv_first_rc = _rc
            if `iv_first_rc' {
                noisily display as error "IV第一阶段（`endogenous_variable'）失败；第二阶段仍将单独尝试"
                local ++warnings
            }
            else {
                scalar __jo_iv_first_n = e(N)
                scalar __jo_iv_first_r2 = .
                capture scalar __jo_iv_first_r2 = e(r2)
                if missing(__jo_iv_first_r2) capture scalar __jo_iv_first_r2 = e(r2_w)
                scalar __jo_iv_first_r2a = .
                capture scalar __jo_iv_first_r2a = e(r2_a)
                if missing(__jo_iv_first_r2a) capture scalar __jo_iv_first_r2a = e(r2_a_within)
                scalar __jo_iv_first_f = .
                capture quietly test `instruments'
                if !_rc capture scalar __jo_iv_first_f = r(F)
                local iv_first_spec "iv_first_`iv_first_index'"
                _journalone_post_current, handle(`handle') runid("`runid'") ///
                    spec("`iv_first_spec'") outcome("`endogenous_variable'") level(`level')
                if !missing(__jo_iv_first_f) {
                    post `handle' ("`runid'") ("`iv_first_spec'") ///
                        ("`endogenous_variable'") (999) ("FIRST_STAGE_F") ///
                        (__jo_iv_first_f) (.) (.) (.) (.) (__jo_iv_first_n) ///
                        (__jo_iv_first_r2) (__jo_iv_first_r2a)
                }
                local ++models
            }
        }
    }

    * Run the IV structural equation in addition to a non-IV baseline.  A
    * baseline model(iv) already supplies the second-stage column.
    if "`model'" != "iv" & strtrim(`"`endog'"') != "" & ///
        strtrim(`"`instruments'"') != "" {
        capture noisily _journalone_fit, model("iv") depvar("`depvar'") ///
            indepvars(`"`indepvars'"') controls(`"`controls'"')          ///
            panel("`panel'") time("`time'") absorb(`"`absorb'"')        ///
            vcetype("`vcetype'") cluster("`cluster'")                  ///
            ivcluster("`ivcluster'")                                        ///
            endog(`"`endog'"') instruments(`"`instruments'"')            ///
            ifcond(`"`ifcond'"') `timefeopt'
        local iv_extra_rc = _rc
        if `iv_extra_rc' {
            noisily display as error "IV内生性规格失败；请检查工具变量、固定效应和聚类设定"
            local ++warnings
        }
        else {
            _journalone_post_current, handle(`handle') runid("`runid'") ///
                spec("iv_2sls") outcome("`depvar'") level(`level')
            _journalone_post_iv_diagnostics, handle(`handle') runid("`runid'") ///
                spec("iv_2sls") outcome("`depvar'")
            local ++models
        }
    }

    * Omitted-variable-bias sensitivity (paper-style nested specifications).
    * The plugin reports every nested estimate and appends the F-style
    * sensitivity measure used in the reference code as a visible OVB_F row.
    if "`ovbtest'" != "" {
        if !inlist("`model'", "ols", "hdfe", "fe", "re") {
            noisily display as error "遗漏变量偏误检验目前需要 OLS/HDFE/FE/RE；已跳过"
            local ++warnings
        }
        else {
            local ovb_focus : word 1 of `indepvars'
            local ovb_focus = subinstr("`ovb_focus'", "c.", "", .)
            local ovb_focus = subinstr("`ovb_focus'", "i.", "", .)
            local ovb_full_beta = .
            local ovb_full_ok = 0
            local ovb_plain_model "`model'"
            if inlist("`model'", "fe", "re") local ovb_plain_model "ols"

            capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
                indepvars(`"`indepvars'"') controls(`"`controls'"')         ///
                panel("`panel'") time("`time'") absorb(`"`absorb'"')       ///
                vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') ///
                `timefeopt'
            if _rc {
                noisily display as error "遗漏变量偏误检验的完整模型失败；已跳过"
                local ++warnings
            }
            else {
                capture local ovb_full_beta = _b[`ovb_focus']
                if _rc | missing(`ovb_full_beta') {
                    noisily display as error "无法读取核心变量系数；遗漏变量偏误检验已跳过"
                    local ++warnings
                }
                else {
                    local ovb_full_ok = 1
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("ovb_full") outcome("`depvar'") level(`level')
                    local ++models
                }
            }

            if `ovb_full_ok' {
                * Helper-like repeated blocks are deliberately explicit so the
                * generated output and audit trail map directly to the paper.
                local ovb_variant_names "basic fe_only entity_only"
                local ovb_variant_labels "无控制无固定效应 仅时间固定效应 控制变量加个体固定效应"
                local ovb_variant_controls1 ""
                local ovb_variant_controls2 ""
                local ovb_variant_controls3 `"`controls'"'
                local ovb_variant_absorb1 ""
                local ovb_variant_absorb2 `"`absorb'"'
                local ovb_variant_absorb3 ""
                if "`panel'" != "" local ovb_variant_absorb3 "`panel'"
                local ovb_variant_timefe1 ""
                local ovb_variant_timefe2 "`timefeopt'"
                local ovb_variant_timefe3 ""
                local ovb_variant_models "`ovb_plain_model' `model' `model'"
                local ovb_variant_index = 0
                foreach ovb_variant of local ovb_variant_names {
                    local ++ovb_variant_index
                    local ovb_controls `"`ovb_variant_controls`ovb_variant_index''"'
                    local ovb_absorb `"`ovb_variant_absorb`ovb_variant_index''"'
                    local ovb_variant_timefe `"`ovb_variant_timefe`ovb_variant_index''"'
                    local ovb_variant_model : word `ovb_variant_index' of `ovb_variant_models'
                    capture noisily _journalone_fit, model("`ovb_variant_model'") ///
                        depvar("`depvar'") indepvars(`"`indepvars'"')       ///
                        controls(`"`ovb_controls'"') panel("`panel'")      ///
                        time("`time'") absorb(`"`ovb_absorb'"')            ///
                        vcetype("`vcetype'") cluster("`cluster'")        ///
                        ifcond(`"`ifcond'"') `ovb_variant_timefe'
                    local ovb_rc = _rc
                    if `ovb_rc' {
                        noisily display as error "遗漏变量偏误规格 `ovb_variant' 失败；已跳过"
                        local ++warnings
                    }
                    else {
                        local ovb_beta = .
                        capture local ovb_beta = _b[`ovb_focus']
                        if _rc | missing(`ovb_beta') {
                            noisily display as error "遗漏变量偏误规格 `ovb_variant' 无法读取核心变量系数"
                            local ++warnings
                        }
                        else {
                            local ovb_f = .
                            if abs(`ovb_beta' - `ovb_full_beta') > 1e-12 {
                                local ovb_f = abs(`ovb_full_beta'/(`ovb_beta' - `ovb_full_beta'))
                            }
                            local ovb_spec "ovb_`ovb_variant'"
                            _journalone_post_current, handle(`handle') runid("`runid'") ///
                                spec("`ovb_spec'") outcome("`depvar'") level(`level')
                            local ++models
                            capture scalar __jo_ovb_n = e(N)
                            capture scalar __jo_ovb_r2 = e(r2)
                            capture scalar __jo_ovb_r2a = e(r2_a)
                            post `handle' ("`runid'") ("`ovb_spec'") ("`depvar'") ///
                                (999) ("OVB_F") (`ovb_f') (.) (.) (.) (.)       ///
                                (__jo_ovb_n) (__jo_ovb_r2) (__jo_ovb_r2a)
                        }
                    }
                }
            }
        }
    }

    * Heckman two-step selection correction requires an explicit selection
    * indicator and explicit selection covariates/exclusion restrictions.
    if "`heckmansel'" != "" {
        local selection_covars = strtrim(`"`heckmancovars'"')
        if "`selection_covars'" == "" local selection_covars = strtrim(`"`instruments' `controls'"')
        if "`selection_covars'" == "" {
            noisily display as error "Heckman需要选择方程协变量/排除限制；已跳过"
            local ++warnings
        }
        else {
            local heckman_manual = ("`heckmanfe'" != "" & "`model'" == "hdfe" & "`time'" != "")
            if `heckman_manual' {
                * The reference paper uses probit + inverse Mills ratio +
                * reghdfe.  Reproduce that path when HDFE/FE is requested.
                tempvar heckman_xb heckman_generated_imr
                capture noisily probit `heckmansel' `selection_covars' i.`time' `ifqual'
                local heckman_first_rc = _rc
                if !`heckman_first_rc' {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("heckman_selection") outcome("`heckmansel'") level(`level') ///
                        equation("`heckmansel'")
                    local ++models
                }
                if !`heckman_first_rc' capture quietly predict double `heckman_xb', xb
                local heckman_imr_used "`heckmanimr'"
                if "`heckman_imr_used'" == "" & !`heckman_first_rc' {
                    capture quietly generate double `heckman_generated_imr' = ///
                        normalden(`heckman_xb')/normal(`heckman_xb')
                    if !_rc local heckman_imr_used "`heckman_generated_imr'"
                }
                else if "`heckman_imr_used'" != "" {
                    capture confirm numeric variable `heckman_imr_used'
                }
                local heckman_imr_rc = _rc
                if `heckman_first_rc' | `heckman_imr_rc' {
                    noisily display as error "Heckman第一阶段Probit或IMR生成失败；请检查选择变量和排除限制"
                    local ++warnings
                }
                else {
                    local heckman_out_controls = strtrim(`"`controls' `heckmanoutcovars' `heckman_imr_used'"')
                    capture noisily _journalone_fit, model("hdfe") depvar("`depvar'") ///
                        indepvars(`"`indepvars'"') controls(`"`heckman_out_controls'"') ///
                        panel("`panel'") time("`time'") absorb(`"`absorb'"')       ///
                        vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') ///
                        `timefeopt'
                    if _rc {
                        noisily display as error "Heckman第二阶段HDFE失败；请检查共线性和固定效应"
                        local ++warnings
                    }
                    else {
                        _journalone_post_current, handle(`handle') runid("`runid'") ///
                            spec("heckman_twostep") outcome("`depvar'") level(`level')
                        local ++models
                    }
                }
            }
            else {
                local heckman_fe_terms ""
                foreach fevar of local absorb {
                    local heckman_fe_terms "`heckman_fe_terms' i.`fevar'"
                }
                if "`timefe'" != "" & "`time'" != "" {
                    local heckman_fe_terms "`heckman_fe_terms' i.`time'"
                }
                if "`heckmanfe'" == "" local heckman_fe_terms ""
                local heckman_vce ""
                if inlist("`vcetype'", "robust", "cluster") {
                    * Official Heckman two-step uses its own corrected
                    * covariance estimator and rejects robust/cluster VCE.
                    noisily display as text "Heckman两步法不接受`vcetype' VCE；已使用两步法校正标准误"
                    local ++warnings
                }
                capture noisily probit `heckmansel' `selection_covars' `heckman_fe_terms' `ifqual'
                local heckman_first_rc = _rc
                if `heckman_first_rc' {
                    noisily display as error "Heckman第一阶段Probit失败；联合两步估计仍将单独尝试"
                    local ++warnings
                }
                else {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("heckman_selection") outcome("`heckmansel'") level(`level') ///
                        equation("`heckmansel'")
                    local ++models
                }
                capture noisily heckman `depvar' `indepvars' `controls' `heckmanoutcovars' `heckman_fe_terms' ///
                    `ifqual', select(`heckmansel' = `selection_covars') twostep `heckman_vce'
                if _rc {
                    noisily display as error "Heckman两步法失败；请检查选择变量、排除限制和共线性"
                    local ++warnings
                }
                else {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("heckman_twostep") outcome("`depvar'") level(`level') ///
                        equation("`depvar'") keepmills
                    local ++models
                }
            }
        }
    }

    * Official difference or system dynamic-panel GMM.
    if "`gmmmethod'" != "" & "`gmmmethod'" != "none" {
        if "`panel'" == "" | "`time'" == "" {
            noisily display as error "动态GMM需要面板ID和时间变量；已跳过"
            local ++warnings
        }
        else {
            capture quietly xtset `panel' `time'
            if _rc {
                noisily display as error "动态GMM的xtset失败；已跳过"
                local ++warnings
            }
            else {
                local gmm_twostep_option ""
                if "`gmmtwostep'" != "" local gmm_twostep_option "twostep"
                local gmm_vce ""
                if inlist("`vcetype'", "robust", "cluster") local gmm_vce "vce(robust)"
                if "`vcetype'" == "cluster" {
                    noisily display as text "动态GMM不接受任意聚类层级；已使用官方robust VCE"
                    local ++warnings
                }
                if "`gmmmethod'" == "difference" {
                    capture noisily xtabond `depvar' `indepvars' `controls' `gmmextra' ///
                        `ifqual', lags(`gmmlags') `gmm_twostep_option' `gmm_vce'
                }
                else {
                    capture noisily xtdpdsys `depvar' `indepvars' `controls' `gmmextra' ///
                        `ifqual', lags(`gmmlags') `gmm_twostep_option' `gmm_vce'
                }
                if _rc {
                    noisily display as error "动态GMM估计失败；请检查时间维度、工具数量和变量设定"
                    local ++warnings
                }
                else {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("gmm_`gmmmethod'") outcome("`depvar'") level(`level')
                    local ++models
                }
            }
        }
    }

    * Official cross-fit partialing-out lasso / IV-lasso inference.
    if "`dmlmethod'" != "" & "`dmlmethod'" != "none" {
        local dml_controls_all = strtrim(`"`controls' `dmlcontrols'"')
        local dml_controls_option ""
        if "`dml_controls_all'" != "" local dml_controls_option `"controls(`dml_controls_all')"'
        if "`dmlmethod'" == "partial" {
            if strtrim(`"`indepvars'"') == "" {
                noisily display as error "部分线性DML需要核心解释变量；已跳过"
                local ++warnings
            }
            else {
                capture noisily xporegress `depvar' `indepvars' `ifqual', ///
                    `dml_controls_option' xfolds(`dmlfolds')             ///
                    resample(`reps') rseed(`seed')
                if _rc {
                    noisily display as error "部分线性DML失败；已保留其他结果"
                    local ++warnings
                }
                else {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("dml_partial") outcome("`depvar'") level(`level')
                    local ++models
                }
            }
        }
        else {
            local dml_endog = strtrim(`"`endog'"')
            local dml_exog = strtrim(`"`indepvars'"')
            if "`dml_endog'" == "" {
                local dml_endog : word 1 of `indepvars'
                local dml_exog : list indepvars - dml_endog
            }
            else local dml_exog : list indepvars - dml_endog
            local dml_iv = strtrim(`"`dmlinstruments'"')
            if "`dml_iv'" == "" local dml_iv = strtrim(`"`instruments'"')
            if "`dml_endog'" == "" | "`dml_iv'" == "" {
                noisily display as error "DML-IV需要内生变量和DML工具变量；已跳过"
                local ++warnings
            }
            else {
                capture noisily xpoivregress `depvar' `dml_exog' ///
                    (`dml_endog' = `dml_iv') `ifqual', `dml_controls_option' ///
                    xfolds(`dmlfolds') resample(`reps') rseed(`seed')
                if _rc {
                    noisily display as error "DML-IV失败；已保留其他结果"
                    local ++warnings
                }
                else {
                    _journalone_post_current, handle(`handle') runid("`runid'") ///
                        spec("dml_iv") outcome("`depvar'") level(`level')
                    local ++models
                }
            }
        }
    }

    * Common-timing event-study diagnostic for the built-in 2x2 DID design.
    if "`ptrend'" != "" {
        if "`treat'" == "" | "`postvar'" == "" | "`panel'" == "" | "`time'" == "" {
            noisily display as error "平行趋势需要处理组、政策后、面板ID和时间变量；已跳过"
            local ++warnings
        }
        else {
            preserve
            local policy_condition "`treat'==1 & `postvar'==1"
            if strtrim(`"`ifcond'"') != "" local policy_condition `"(`ifcond') & (`policy_condition')"'
            capture quietly summarize `time' if `policy_condition', meanonly
            if _rc | r(N) == 0 {
                noisily display as error "无法识别共同政策起始期；已跳过平行趋势"
                local ++warnings
            }
            else {
                local policy_time = r(min)
                tempvar event_time event_index
                quietly generate double `event_time' = `time' - `policy_time'
                local base_condition "`event_time'==`ptbase'"
                if strtrim(`"`ifcond'"') != "" {
                    local base_condition `"(`ifcond') & (`base_condition')"'
                }
                capture quietly count if `base_condition'
                if _rc | r(N) == 0 {
                    noisily display as error "平行趋势基准期 `ptbase' 不存在；已跳过"
                    local ++warnings
                }
                else {
                    capture quietly summarize `event_time' `ifqual', meanonly
                    local event_min = r(min)
                    quietly generate long `event_index' = `event_time' - `event_min'
                    local base_index = `ptbase' - `event_min'
                    quietly fvset base `base_index' `event_index'
                    local event_fe_terms "i.`panel' i.`time'"
                    foreach fevar of local absorb {
                        if "`fevar'" != "`panel'" & "`fevar'" != "`time'" {
                            local event_fe_terms "`event_fe_terms' i.`fevar'"
                        }
                    }
                    local event_vce ""
                    if "`vcetype'" == "robust" local event_vce "vce(robust)"
                    if "`vcetype'" == "cluster" & "`cluster'" != "" local event_vce "vce(cluster `cluster')"
                    capture noisily regress `depvar' i.`event_index'#1.`treat' ///
                        `indepvars' `controls' `event_fe_terms' `ifqual', `event_vce'
                    if _rc {
                        noisily display as error "平行趋势事件研究回归失败；已跳过"
                        local ++warnings
                    }
                    else {
                        _journalone_post_current, handle(`handle') runid("`runid'") ///
                            spec("parallel_trend") outcome("`depvar'") level(`ptlevel')
                        local ++models
                        local pre_terms ""
                        local pre_condition "`event_time'<0 & `event_time'!=`ptbase'"
                        if strtrim(`"`ifcond'"') != "" {
                            local pre_condition `"(`ifcond') & (`pre_condition')"'
                        }
                        capture quietly levelsof `event_index' if `pre_condition', local(pre_levels)
                        if !_rc {
                            foreach pre_level of local pre_levels {
                                local pre_terms "`pre_terms' `pre_level'.`event_index'#1.`treat'"
                            }
                        }
                        local parallel_p = .
                        if strtrim("`pre_terms'") != "" {
                            capture noisily testparm `pre_terms'
                            if !_rc local parallel_p = r(p)
                            else local ++warnings
                        }
                        local parallel_test_file `"`resultbase'_parallel_trend.txt"'
                        tempname parallel_handle
                        file open `parallel_handle' using `"`parallel_test_file'"', write text replace
                        file write `parallel_handle' "policy_time=`policy_time'" _n
                        file write `parallel_handle' "base_period=`ptbase'" _n
                        file write `parallel_handle' "confidence_level=`ptlevel'" _n
                        file write `parallel_handle' "joint_pretrend_p=`parallel_p'" _n
                        file write `parallel_handle' "interpretation=FAIL_TO_REJECT_IS_NOT_PROOF_OF_PARALLEL_TRENDS" _n
                        file close `parallel_handle'
                    }
                }
            }
            restore
        }
    }

    * Explicit quantile grouping is allowed only when the user requests a bin count.
    if `groupbins' > 1 {
        if "`group'" == "" {
            noisily display as error "异质性重新分类需要分组变量；已跳过"
            local ++warnings
        }
        else {
            preserve
            tempvar quantile_group
            capture noisily xtile `quantile_group' = `group' `ifqual', nq(`groupbins')
            if _rc {
                noisily display as error "异质性分位组生成失败；已跳过"
                local ++warnings
            }
            else {
                quietly levelsof `quantile_group', local(quantile_levels)
                foreach quantile_level of local quantile_levels {
                    local quantile_if "`quantile_group'==`quantile_level'"
                    if strtrim(`"`ifcond'"') != "" local quantile_if `"(`ifcond') & (`quantile_if')"'
                    _journalone_run_spec, handle(`handle') runid("`runid'") ///
                        spec("group_quantile_`quantile_level'") model("`model'") ///
                        depvar("`depvar'") indepvars(`"`indepvars'"') controls(`"`controls'"') ///
                        panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                        vcetype("`vcetype'") cluster("`cluster'") treat("`treat'") ///
                        postvar("`postvar'") endog(`"`endog'"') instruments(`"`instruments'"') ///
                        ifcond(`"`quantile_if'"') level(`level') `timefeopt'
                    if r(rc) local ++warnings
                    else local ++models
                }
            }
            restore
        }
    }

    * Formal cross-group test for the first focal variable.
    if "`grouptest'" != "" {
        local group_firstx : word 1 of `indepvars'
        local group_restx : list indepvars - group_firstx
        if "`group'" == "" | "`group_firstx'" == "" | !inlist("`model'", "ols", "hdfe", "fe", "re") {
            noisily display as error "组间系数检验需要分组变量、核心变量以及OLS/HDFE/FE/RE；已跳过"
            local ++warnings
        }
        else {
            capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
                indepvars("c.`group_firstx'##i.`group' `group_restx'") controls(`"`controls'"') ///
                panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') `timefeopt'
            if _rc {
                noisily display as error "组间交互模型失败；已跳过联合检验"
                local ++warnings
            }
            else {
                capture noisily testparm i.`group'#c.`group_firstx'
                if _rc {
                    noisily display as error "组间联合检验失败"
                    local ++warnings
                }
                else {
                    local group_test_p = r(p)
                    local group_test_file `"`resultbase'_group_test.txt"'
                    tempname group_handle
                    file open `group_handle' using `"`group_test_file'"', write text replace
                    file write `group_handle' "group_variable=`group'" _n
                    file write `group_handle' "focal_variable=`group_firstx'" _n
                    file write `group_handle' "joint_interaction_p=`group_test_p'" _n
                    file write `group_handle' "interpretation=JOINT_TEST_REQUIRED_FOR_CROSS_GROUP_DIFFERENCES" _n
                    file close `group_handle'
                }
            }
        }
    }

    * Moderation marginal-effect plot at moderator p25/p50/p75.
    if "`modplot'" != "" {
        local plot_firstx : word 1 of `indepvars'
        local plot_restx : list indepvars - plot_firstx
        local plot_moderator : word 1 of `moderators'
        local mapped_plot_interaction ""
        if strtrim(`"`modinteractions'"') != "" & "`plot_moderator'" != "" {
            quietly _journalone_lookup_map, map("`modinteractions'") key("`plot_moderator'")
            local mapped_plot_interaction `"`r(value)'"'
        }
        if "`plot_firstx'" == "" | "`plot_moderator'" == "" | !inlist("`model'", "ols", "hdfe", "fe", "re") {
            noisily display as error "调节效应图需要核心变量、调节变量以及OLS/HDFE/FE/RE；已跳过"
            local ++warnings
        }
        else if strtrim(`"`mapped_plot_interaction'"') != "" {
            noisily display as text "调节交互映射使用了预生成变量 `mapped_plot_interaction'；为避免图形与回归设定不一致，未自动生成边际效应图"
        }
        else {
            preserve
            capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
                indepvars("c.`plot_firstx'##c.`plot_moderator' `plot_restx'") ///
                controls(`"`controls'"') panel("`panel'") time("`time'") ///
                absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                ifcond(`"`ifcond'"') `timefeopt'
            if _rc {
                noisily display as error "调节效应图模型失败；已跳过"
                local ++warnings
            }
            else {
                quietly summarize `plot_moderator' if e(sample), detail
                local moderator_low = r(p25)
                local moderator_mid = r(p50)
                local moderator_high = r(p75)
                capture noisily margins, dydx(`plot_firstx') ///
                    at(`plot_moderator'=(`moderator_low' `moderator_mid' `moderator_high'))
                if _rc {
                    noisily display as error "调节效应边际计算失败；已跳过图形"
                    local ++warnings
                }
                else {
                    capture noisily marginsplot, name(__journalone_modplot, replace)
                    if _rc {
                        local ++warnings
                    }
                    else {
                        local moderation_file `"`resultbase'_moderator_`plot_moderator'.png"'
                        capture noisily graph export `"`moderation_file'"', replace name(__journalone_modplot)
                        if _rc local ++warnings
                        else local moderation_files `"`moderation_files' `moderation_file'"'
                        capture graph drop __journalone_modplot
                    }
                }
            }
            restore
        }
    }

    * Winsorized robustness specification runs on temporary variables only.
    if "`adjustmethod'" == "winsor" {
        if !inlist("`model'", "ols", "hdfe", "fe", "re", "did") {
            noisily display as error "临时缩尾稳健性当前支持OLS/HDFE/FE/RE/DID；已跳过"
            local ++warnings
        }
        else {
            preserve
            local winsor_valid = 1
            tempvar winsor_dep
            capture quietly centile `depvar' `ifqual', centile(`winsorlow' `winsorhigh')
            if _rc local winsor_valid = 0
            else {
                local dep_low = r(c_1)
                local dep_high = r(c_2)
                quietly generate double `winsor_dep' = `depvar'
                quietly replace `winsor_dep' = `dep_low' if `winsor_dep' < `dep_low' & !missing(`winsor_dep')
                quietly replace `winsor_dep' = `dep_high' if `winsor_dep' > `dep_high' & !missing(`winsor_dep')
            }
            local winsor_x ""
            foreach winsor_var of local indepvars {
                capture confirm numeric variable `winsor_var'
                if _rc local winsor_valid = 0
                else {
                    tempvar winsor_one
                    quietly centile `winsor_var' `ifqual', centile(`winsorlow' `winsorhigh')
                    local winsor_one_low = r(c_1)
                    local winsor_one_high = r(c_2)
                    quietly generate double `winsor_one' = `winsor_var'
                    quietly replace `winsor_one' = `winsor_one_low' if `winsor_one' < `winsor_one_low' & !missing(`winsor_one')
                    quietly replace `winsor_one' = `winsor_one_high' if `winsor_one' > `winsor_one_high' & !missing(`winsor_one')
                    local winsor_x "`winsor_x' `winsor_one'"
                }
            }
            local winsor_controls ""
            foreach winsor_var of local controls {
                capture confirm numeric variable `winsor_var'
                if _rc local winsor_valid = 0
                else {
                    tempvar winsor_one
                    quietly centile `winsor_var' `ifqual', centile(`winsorlow' `winsorhigh')
                    local winsor_one_low = r(c_1)
                    local winsor_one_high = r(c_2)
                    quietly generate double `winsor_one' = `winsor_var'
                    quietly replace `winsor_one' = `winsor_one_low' if `winsor_one' < `winsor_one_low' & !missing(`winsor_one')
                    quietly replace `winsor_one' = `winsor_one_high' if `winsor_one' > `winsor_one_high' & !missing(`winsor_one')
                    local winsor_controls "`winsor_controls' `winsor_one'"
                }
            }
            if !`winsor_valid' {
                noisily display as error "缩尾变量含因子/时间序列表达式或无法计算分位数；已跳过"
                local ++warnings
            }
            else {
                _journalone_run_spec, handle(`handle') runid("`runid'") ///
                    spec("winsor_`winsorlow'_`winsorhigh'") model("`model'") ///
                    depvar("`winsor_dep'") indepvars(`"`winsor_x'"') ///
                    controls(`"`winsor_controls'"') panel("`panel'") time("`time'") ///
                    absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                    treat("`treat'") postvar("`postvar'") ifcond(`"`ifcond'"') ///
                    level(`level') `timefeopt'
                if r(rc) local ++warnings
                else local ++models
            }
            restore
        }
    }

    return scalar models = `models'
    return scalar warnings = `warnings'
    return local parallel_test_file `"`parallel_test_file'"'
    return local group_test_file `"`group_test_file'"'
    return local moderation_files `"`moderation_files'"'
end
