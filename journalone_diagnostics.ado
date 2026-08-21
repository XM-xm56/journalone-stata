*! version 0.9.5 17aug2026

capture program drop journalone_diagnostics
program define journalone_diagnostics, rclass
    version 16.0
    _journalone_require_license
    syntax , RESULTBASE(string) RUNID(string) PACKAGEDIR(string)       ///
        [ DATAFILE(string) CORRVARS(varlist numeric) VIFCHECK          ///
          PANELTESTS IVTESTS DEPVAR(string) INDEPVARS(string)          ///
          CONTROLS(string) PANEL(string) TIME(string) ABSORB(string)   ///
          TIMEFE IFCOND(string) ENDOG(string) INSTRUMENTS(string)      ///
          VCETYPE(string) CLUSTER(string) IVCLUSTER(string) DECIMALS(integer 3) ///
          PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10) ]

    local requested = (strtrim(`"`corrvars'"') != "") +              ///
        ("`vifcheck'" != "") + ("`paneltests'" != "") +           ///
        ("`ivtests'" != "")
    if `requested' == 0 {
        display as error "未选择相关性或模型诊断项目"
        exit 198
    }
    local corrvar_count : word count `corrvars'
    if `corrvar_count' > 30 {
        display as error "相关性分析最多允许30个变量；请按论文表格需要精简变量"
        exit 198
    }
    if ("`vifcheck'" != "" | "`paneltests'" != "" | "`ivtests'" != "") & ///
        strtrim("`depvar'") == "" {
        display as error "VIF、面板模型检验和IV诊断必须同时提供基准回归 depvar()"
        exit 198
    }
    if "`vifcheck'" != "" & strtrim(`"`indepvars' `endog' `controls'"') == "" {
        display as error "VIF检验至少需要一个解释变量或控制变量"
        exit 198
    }
    if "`paneltests'" != "" & ("`panel'" == "" | "`time'" == "") {
        display as error "面板模型检验必须提供 panel() 和 time()"
        exit 198
    }
    if "`ivtests'" != "" & (strtrim(`"`endog'"') == "" | strtrim(`"`instruments'"') == "") {
        display as error "IV诊断必须提供 endog() 和 instruments()"
        exit 198
    }
    if `pstar1' <= 0 | `pstar1' >= `pstar2' | `pstar2' >= `pstar3' | `pstar3' >= 1 {
        display as error "显著性阈值必须满足 0<pstar1()<pstar2()<pstar3()<1"
        exit 198
    }
    if "`vcetype'" == "" local vcetype "conventional"

    local resultbase = subinstr(strtrim(`"`resultbase'"'), char(34), "", .)
    local packagedir = subinstr(strtrim(`"`packagedir'"'), char(34), "", .)
    local datafile = subinstr(strtrim(`"`datafile'"'), char(34), "", .)
    local ifqual ""
    if strtrim(`"`ifcond'"') != "" local ifqual `"if `ifcond'"'

    local fe_terms ""
    foreach fevar of local absorb {
        if "`fevar'" != "`panel'" local fe_terms "`fe_terms' i.`fevar'"
    }
    local time_terms ""
    if "`timefe'" != "" & "`time'" != "" & ///
        !strpos(" `absorb' ", " `time' ") local time_terms "i.`time'"
    local diagnostic_rhs = strtrim(`"`indepvars' `endog' `controls'"')

    capture mkdir `"`packagedir'"'
    local diagnostics_dir `"`packagedir'/相关性与模型诊断结果"'
    capture mkdir `"`diagnostics_dir'"'
    local diagnostics_rtf `"`diagnostics_dir'/相关性与模型诊断.rtf"'
    local diagnostics_do `"`diagnostics_dir'/相关性与模型诊断.do"'
    local diagnostics_csv `"`diagnostics_dir'/相关性与模型诊断.csv"'
    local diagnostics_dta `"`resultbase'_diagnostics.dta"'

    tempfile diagnostics_data
    tempname diagnostics_post
    postfile `diagnostics_post' str40 run_id double row_order col_order ///
        str24 analysis_section str56 test str80 variable1 str80 variable2 ///
        double statistic p_value df N str4 stars str244 note             ///
        using `diagnostics_data', replace

    local warnings = 0
    local successful_sections = 0
    local row_order = 0

    preserve

    if strtrim(`"`corrvars'"') != "" {
        capture quietly pwcorr `corrvars' `ifqual', sig obs
        local corr_rc = _rc
        if `corr_rc' {
            local ++warnings
            local ++row_order
            post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                ("相关性分析") ("Pearson相关系数") ("") ("") ///
                (.) (.) (.) (.) ("") (`"运行失败，rc=`corr_rc'"')
        }
        else {
            local ++successful_sections
            tempname corr_matrix corr_p corr_n
            matrix `corr_matrix' = r(C)
            matrix `corr_p' = r(sig)
            matrix `corr_n' = r(Nobs)
            local corr_count : word count `corrvars'
            forvalues i = 1/`corr_count' {
                local corr_var1 : word `i' of `corrvars'
                forvalues j = 1/`i' {
                    local corr_var2 : word `j' of `corrvars'
                    local corr_value = el(`corr_matrix', `i', `j')
                    local corr_pvalue = el(`corr_p', `i', `j')
                    local corr_obs = el(`corr_n', `i', `j')
                    local corr_stars ""
                    if `corr_pvalue' < . {
                        if `corr_pvalue' < `pstar1' local corr_stars "***"
                        else if `corr_pvalue' < `pstar2' local corr_stars "**"
                        else if `corr_pvalue' < `pstar3' local corr_stars "*"
                    }
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (`j') ///
                        ("相关性分析") ("Pearson相关系数")                 ///
                        ("`corr_var1'") ("`corr_var2'") (`corr_value')  ///
                        (`corr_pvalue') (.) (`corr_obs') ("`corr_stars'") ///
                        ("双侧检验；报告下三角矩阵")
                }
            }
        }
    }

    if "`vifcheck'" != "" {
        capture quietly regress `depvar' `diagnostic_rhs' `ifqual'
        local vif_reg_rc = _rc
        if `vif_reg_rc' {
            local ++warnings
            local ++row_order
            post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                ("多重共线性") ("方差膨胀因子VIF") ("") ("") ///
                (.) (.) (.) (.) ("") (`"辅助OLS失败，rc=`vif_reg_rc'"')
        }
        else {
            local vif_n = e(N)
            capture quietly estat vif
            local vif_rc = _rc
            if `vif_rc' {
                local ++warnings
                local ++row_order
                post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                    ("多重共线性") ("方差膨胀因子VIF") ("") ("") ///
                    (.) (.) (.) (`vif_n') ("") (`"estat vif失败，rc=`vif_rc'"')
            }
            else {
                local ++successful_sections
                local vif_index = 1
                local vif_sum = 0
                local vif_count = 0
                while `vif_index' <= 500 {
                    local vif_name `"`r(name_`vif_index')'"'
                    if strtrim(`"`vif_name'"') == "" continue, break
                    local vif_value = r(vif_`vif_index')
                    local ++vif_count
                    local vif_sum = `vif_sum' + `vif_value'
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (`vif_index') ///
                        ("多重共线性") ("VIF") ("`vif_name'") ("")     ///
                        (`vif_value') (.) (.) (`vif_n') ("")             ///
                        ("基于核心解释变量与控制变量的辅助OLS")
                    local ++vif_index
                }
                if `vif_count' > 0 {
                    local mean_vif = `vif_sum' / `vif_count'
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (501) ///
                        ("多重共线性") ("平均VIF") ("") ("") (`mean_vif') ///
                        (.) (.) (`vif_n') ("") ("仅作共线性诊断，不作为删变量规则")
                }
            }
        }
    }

    if "`paneltests'" != "" {
        capture quietly xtset `panel' `time'
        local xtset_rc = _rc
        if `xtset_rc' {
            local ++warnings
            local ++row_order
            post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                ("面板模型选择") ("面板声明") ("`panel'") ("`time'") ///
                (.) (.) (.) (.) ("") (`"xtset失败，rc=`xtset_rc'"')
        }
        else {
            tempname fe_est re_est
            capture quietly xtreg `depvar' `diagnostic_rhs' `fe_terms' ///
                `time_terms' `ifqual', fe
            local fe_rc = _rc
            if `fe_rc' {
                local ++warnings
                local ++row_order
                post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                    ("面板模型选择") ("个体效应F检验") ("") ("") ///
                    (.) (.) (.) (.) ("") (`"固定效应估计失败，rc=`fe_rc'"')
            }
            else {
                local ++successful_sections
                local fe_n = e(N)
                local fe_f = .
                local fe_p = .
                local fe_df = .
                capture local fe_f = e(F_f)
                capture local fe_p = e(p_f)
                capture local fe_df = e(df_a)
                estimates store `fe_est'
                local ++row_order
                post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                    ("面板模型选择") ("固定效应与混合OLS的F检验") ("") ("") ///
                    (`fe_f') (`fe_p') (`fe_df') (`fe_n') ("") ///
                    ("H0：个体效应共同为0")

                capture quietly xtreg `depvar' `diagnostic_rhs' `fe_terms' ///
                    `time_terms' `ifqual', re
                local re_rc = _rc
                if `re_rc' {
                    local ++warnings
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (2) ///
                        ("面板模型选择") ("随机效应LM检验") ("") ("") ///
                        (.) (.) (.) (.) ("") (`"随机效应估计失败，rc=`re_rc'"')
                }
                else {
                    estimates store `re_est'
                    local re_n = e(N)
                    capture quietly xttest0
                    local lm_rc = _rc
                    if `lm_rc' {
                        local ++warnings
                        local ++row_order
                        post `diagnostics_post' ("`runid'") (`row_order') (2) ///
                            ("面板模型选择") ("Breusch-Pagan随机效应LM检验") ///
                            ("") ("") (.) (.) (.) (`re_n') ("") ///
                            (`"xttest0失败，rc=`lm_rc'"')
                    }
                    else {
                        local lm_stat = r(lm)
                        local lm_p = r(p)
                        local lm_df = r(df)
                        local ++row_order
                        post `diagnostics_post' ("`runid'") (`row_order') (2) ///
                            ("面板模型选择") ("Breusch-Pagan随机效应LM检验") ///
                            ("") ("") (`lm_stat') (`lm_p') (`lm_df') (`re_n') ///
                            ("") ("H0：随机个体效应方差为0")
                    }

                    capture quietly hausman `fe_est' `re_est', sigmamore
                    local hausman_rc = _rc
                    if `hausman_rc' {
                        local ++warnings
                        local ++row_order
                        post `diagnostics_post' ("`runid'") (`row_order') (3) ///
                            ("面板模型选择") ("Hausman检验") ("") ("") ///
                            (.) (.) (.) (`re_n') ("") (`"Hausman失败，rc=`hausman_rc'"')
                    }
                    else {
                        local hausman_stat = r(chi2)
                        local hausman_p = r(p)
                        local hausman_df = r(df)
                        local ++row_order
                        post `diagnostics_post' ("`runid'") (`row_order') (3) ///
                            ("面板模型选择") ("Hausman检验") ("") ("") ///
                            (`hausman_stat') (`hausman_p') (`hausman_df') (`re_n') ///
                            ("") ("H0：随机效应估计一致；使用常规协方差比较")
                    }
                }
            }
            capture estimates drop `fe_est'
            capture estimates drop `re_est'
        }
    }

    if "`ivtests'" != "" {
        capture quietly _journalone_fit, model("iv") depvar("`depvar'") ///
            indepvars(`"`indepvars'"') controls(`"`controls'"')      ///
            panel("`panel'") time("`time'") absorb(`"`absorb'"')  ///
            vcetype("`vcetype'") cluster("`cluster'")              ///
            ivcluster("`ivcluster'")                                  ///
            endog(`"`endog'"') instruments(`"`instruments'"')      ///
            ifcond(`"`ifcond'"') `timefe'
        local iv_rc = _rc
        if `iv_rc' {
            local ++warnings
            local ++row_order
            post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                ("工具变量诊断") ("2SLS重新估计") ("") ("") ///
                (.) (.) (.) (.) ("") (`"估计失败，rc=`iv_rc'"')
        }
        else {
            local iv_n = e(N)
            capture quietly estat firststage, all forcenonrobust
            local first_rc = _rc
            if `first_rc' {
                local ++warnings
                local ++row_order
                post `diagnostics_post' ("`runid'") (`row_order') (1) ///
                    ("工具变量诊断") ("第一阶段诊断") ("") ("") ///
                    (.) (.) (.) (`iv_n') ("") (`"estat firststage失败，rc=`first_rc'"')
            }
            else {
                local ++successful_sections
                tempname first_results
                matrix `first_results' = r(singleresults)
                local min_eigen = r(mineig)
                local endog_count : word count `endog'
                local first_rows = rowsof(`first_results')
                local report_rows = min(`endog_count', `first_rows')
                forvalues i = 1/`report_rows' {
                    local endog_var : word `i' of `endog'
                    local partial_r2 = el(`first_results', `i', 3)
                    local first_f = el(`first_results', `i', 4)
                    local first_df = el(`first_results', `i', 5)
                    local first_p = el(`first_results', `i', 7)
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (`i') ///
                        ("工具变量诊断") ("第一阶段部分R2") ("`endog_var'") ///
                        ("") (`partial_r2') (.) (.) (`iv_n') ("") ///
                        ("排除工具变量对内生变量的增量解释力")
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (`i') ///
                        ("工具变量诊断") ("排除工具变量F统计量") ("`endog_var'") ///
                        ("") (`first_f') (`first_p') (`first_df') (`iv_n') ("") ///
                        ("第一阶段联合显著性；阈值不能替代识别论证")
                }
                local ++row_order
                post `diagnostics_post' ("`runid'") (`row_order') (999) ///
                    ("工具变量诊断") ("最小特征值统计量") ("") ("") ///
                    (`min_eigen') (.) (.) (`iv_n') ("") ///
                    ("Stock-Yogo临界值适用范围取决于设定")

                capture quietly estat overid
                local overid_rc = _rc
                if !`overid_rc' {
                    local overid_stat = r(chi2)
                    local overid_p = r(p)
                    local overid_df = r(df)
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (1000) ///
                        ("工具变量诊断") ("过度识别约束检验") ("") ("") ///
                        (`overid_stat') (`overid_p') (`overid_df') (`iv_n') ("") ///
                        ("仅在过度识别时可用；不单独证明工具变量外生")
                }
                else {
                    local ++row_order
                    post `diagnostics_post' ("`runid'") (`row_order') (1000) ///
                        ("工具变量诊断") ("过度识别约束检验") ("") ("") ///
                        (.) (.) (.) (`iv_n') ("") ///
                        ("模型恰好识别或当前估计不支持该检验")
                }
            }
        }
    }

    postclose `diagnostics_post'

    quietly use `diagnostics_data', clear
    sort row_order col_order
    save `"`diagnostics_dta'"', replace
    export delimited using `"`diagnostics_csv'"', replace
    _journalone_write_diag_rtf, file(`"`diagnostics_rtf'"')          ///
        title("相关性与模型诊断") decimals(`decimals')

    tempname do_handle
    file open `do_handle' using `"`diagnostics_do'"', write text replace
    if strtrim(`"`datafile'"') != "" {
        capture confirm file `"`datafile'"'
        if !_rc file write `do_handle' `"use "`datafile'", clear"' _n
        else file write `do_handle' "* 请先载入本次分析使用的数据文件。" _n
    }
    else file write `do_handle' "* 请先载入本次分析使用的数据文件。" _n
    if strtrim(`"`corrvars'"') != "" {
        file write `do_handle' `"pwcorr `corrvars' `ifqual', sig obs"' _n
    }
    if "`vifcheck'" != "" {
        file write `do_handle' `"regress `depvar' `diagnostic_rhs' `ifqual'"' _n
        file write `do_handle' "estat vif" _n
    }
    if "`paneltests'" != "" {
        file write `do_handle' `"xtset `panel' `time'"' _n
        file write `do_handle' `"xtreg `depvar' `diagnostic_rhs' `fe_terms' `time_terms' `ifqual', fe"' _n
        file write `do_handle' "estimates store fixed_effects" _n
        file write `do_handle' `"xtreg `depvar' `diagnostic_rhs' `fe_terms' `time_terms' `ifqual', re"' _n
        file write `do_handle' "estimates store random_effects" _n
        file write `do_handle' "xttest0" _n
        file write `do_handle' "hausman fixed_effects random_effects, sigmamore" _n
    }
    if "`ivtests'" != "" {
        local iv_vce ""
        local iv_cluster "`ivcluster'"
        if strtrim("`iv_cluster'") == "" local iv_cluster "`cluster'"
        if "`vcetype'" == "robust" local iv_vce ", vce(robust)"
        else if "`vcetype'" == "cluster" local iv_vce ", vce(cluster `iv_cluster')"
        file write `do_handle' `"ivregress 2sls `depvar' `indepvars' `controls' `fe_terms' `time_terms' (`endog' = `instruments') `ifqual'`iv_vce'"' _n
        file write `do_handle' "estat firststage, all forcenonrobust" _n
        file write `do_handle' "capture noisily estat overid" _n
    }
    file close `do_handle'

    restore

    return local diagnostics_dir `"`diagnostics_dir'"'
    return local diagnostics_rtf `"`diagnostics_rtf'"'
    return local diagnostics_do `"`diagnostics_do'"'
    return local diagnostics_csv `"`diagnostics_csv'"'
    return local diagnostics_dta `"`diagnostics_dta'"'
    return scalar warnings = `warnings'
    return scalar successful_sections = `successful_sections'
end
