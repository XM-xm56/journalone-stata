*! version 0.8.0 15aug2026

capture program drop journalone_descriptive_only
program define journalone_descriptive_only, rclass
    version 16.0
    _journalone_require_license
    syntax , RESULTBASE(string) RUNID(string) DESCVARS(varlist numeric) ///
        PACKAGEDIR(string) SOURCECOMMAND(string)                         ///
        [ IFCOND(string) DATAFILE(string) RAWN(integer 0)               ///
          SIGBEFORE(string)                                             ///
          MISSINGMODE(string) REPORTMODE(string) DECIMALS(integer 3)   ///
          STATISTIC(string) PSTAR1(real .01) PSTAR2(real .05)          ///
          PSTAR3(real .10) ]

    local warnings = 0
    local descriptive_if ""
    if strtrim(`"`ifcond'"') != "" local descriptive_if `"if `ifcond'"'

    quietly count `descriptive_if'
    local descriptive_n = r(N)
    if `descriptive_n' == 0 {
        display as error "描述性统计样本为0；请检查样本条件"
        exit 2000
    }

    tempfile descriptive_data
    tempname descriptive_post
    postfile `descriptive_post' str40 run_id double variable_order          ///
        str24 variable_role str32 variable str244 variable_label            ///
        double N_total N_nonmissing N_missing mean sd min max ///
        using `descriptive_data', replace

    local descriptive_count = 0
    foreach descriptive_var of local descvars {
        local ++descriptive_count
        quietly summarize `descriptive_var' `descriptive_if'
        local descriptive_nonmissing = r(N)
        local descriptive_missing = `descriptive_n' - `descriptive_nonmissing'
        local descriptive_label : variable label `descriptive_var'
        if strtrim(`"`descriptive_label'"') == "" local descriptive_label "`descriptive_var'"
        post `descriptive_post' ("`runid'") (`descriptive_count')             ///
            ("descriptive_only") ("`descriptive_var'") (`"`descriptive_label'"') ///
            (`descriptive_n') (`descriptive_nonmissing') (`descriptive_missing') ///
            (r(mean)) (r(sd)) (r(min)) (r(max))
    }
    postclose `descriptive_post'

    local descriptive_dta `"`resultbase'_descriptive.dta"'
    local descriptive_file `"`resultbase'_descriptive.csv"'
    preserve
    quietly use `descriptive_data', clear
    sort variable_order
    save `"`descriptive_dta'"', replace
    export delimited using `"`descriptive_file'"', replace
    noisily display as text "描述性统计（独立模块样本）"
    noisily list variable_order variable_role variable N_total N_nonmissing ///
        N_missing mean sd min max, noobs abbreviate(24)
    restore

    capture noisily journalone_format_outputs, resultbase(`"`resultbase'"') ///
        descriptive(`"`descriptive_dta'"') decimals(`decimals')             ///
        statistic("`statistic'") pstar1(`pstar1') pstar2(`pstar2')          ///
        pstar3(`pstar3') reportmode("`reportmode'")
    local format_rc = _rc
    local report_file ""
    if `format_rc' {
        noisily display as error "描述性统计格式化失败，返回码 `format_rc'；原始DTA/CSV仍保留"
        local ++warnings
    }
    else local report_file `"`r(report_file)'"'

    local package_output_dir ""
    local package_output_dirs ""
    local rtf_files ""
    local do_files ""
    local csv_files ""
    local descriptive_rtf ""
    local descriptive_do ""
    local descriptive_package_csv ""
    local descriptive_dir ""
    capture noisily journalone_publish_outputs,                         ///
        packagedir(`"`packagedir'"') runid("`runid'")                ///
        sourcecommand(`"`sourcecommand'"') datafile(`"`datafile'"') ///
        descriptive(`"`descriptive_dta'"') decimals(`decimals')       ///
        ifcond(`"`ifcond'"')                                           ///
        statistic("`statistic'") pstar1(`pstar1') pstar2(`pstar2')    ///
        pstar3(`pstar3')
    local package_rc = _rc
    if `package_rc' {
        noisily display as error "三件套结果包生成失败，返回码 `package_rc'；原始结果仍保留"
        local ++warnings
    }
    else {
        local package_output_dir `"`r(package_dir)'"'
        local package_output_dirs `"`r(package_dirs)'"'
        local rtf_files `"`r(rtf_files)'"'
        local do_files `"`r(do_files)'"'
        local csv_files `"`r(csv_files)'"'
        local descriptive_rtf `"`r(descriptive_rtf)'"'
        local descriptive_do `"`r(descriptive_do)'"'
        local descriptive_package_csv `"`r(descriptive_csv)'"'
        local descriptive_dir `"`r(descriptive_dir)'"'
        local warnings = `warnings' + r(warnings)
    }

    local sig_after ""
    capture quietly datasignature
    if !_rc local sig_after "`r(datasignature)'"
    if "`sigbefore'" != "" & "`sig_after'" != "" & "`sigbefore'" != "`sig_after'" {
        local ++warnings
    }

    local overall "PASS"
    if `warnings' > 0 local overall "PASS_WITH_WARNINGS"
    tempname audit_handle
    file open `audit_handle' using `"`resultbase'_audit.txt"', write text replace
    file write `audit_handle' "status=`overall'" _n
    file write `audit_handle' "run_id=`runid'" _n
    file write `audit_handle' "modules=descriptive" _n
    file write `audit_handle' "model=NONE" _n
    file write `audit_handle' "main_n=." _n
    file write `audit_handle' "main_r2=." _n
    file write `audit_handle' "raw_n=`rawn'" _n
    file write `audit_handle' "models_success=0" _n
    file write `audit_handle' "warnings=`warnings'" _n
    file write `audit_handle' "descriptive_status=PASS" _n
    file write `audit_handle' "descriptive_variables=`descriptive_count'" _n
    file write `audit_handle' "descriptive_sample_n=`descriptive_n'" _n
    file write `audit_handle' "descriptive_sample_mode=standalone_full" _n
    file write `audit_handle' "descriptive_file=`descriptive_file'" _n
    file write `audit_handle' "descriptive_dta=`descriptive_dta'" _n
    file write `audit_handle' "missing_mode=`missingmode'" _n
    file write `audit_handle' "report_file=`report_file'" _n
    file write `audit_handle' "package_dir=`package_output_dir'" _n
    file write `audit_handle' "package_dirs=`package_output_dirs'" _n
    file write `audit_handle' "rtf_files=`rtf_files'" _n
    file write `audit_handle' "do_files=`do_files'" _n
    file write `audit_handle' "module_csv_files=`csv_files'" _n
    file write `audit_handle' "data_signature_before=`sigbefore'" _n
    file write `audit_handle' "data_signature_after=`sig_after'" _n
    file write `audit_handle' "causal_validity=NOT_APPLICABLE_DESCRIPTIVE_ONLY" _n
    file close `audit_handle'

    noisily display as result "运行完成：`overall'（仅描述性统计）"
    noisily display as text "描述性统计：`descriptive_file'"
    if "`report_file'" != "" noisily display as text "Word报告：`report_file'"
    if "`package_output_dirs'" != "" noisily display as result "期刊三件套结果文件夹：`package_output_dirs'"
    noisily display as text "审计：`resultbase'_audit.txt"

    return local status "`overall'"
    return local descriptive_file `"`descriptive_file'"'
    return local descriptive_dta `"`descriptive_dta'"'
    return local report_file `"`report_file'"'
    return local package_dir `"`package_output_dir'"'
    return local package_dirs `"`package_output_dirs'"'
    return local rtf_files `"`rtf_files'"'
    return local do_files `"`do_files'"'
    return local csv_files `"`csv_files'"'
    return local descriptive_rtf `"`descriptive_rtf'"'
    return local descriptive_do `"`descriptive_do'"'
    return local descriptive_package_csv `"`descriptive_package_csv'"'
    return local descriptive_dir `"`descriptive_dir'"'
    return local signature_after "`sig_after'"
    return scalar descriptive_count = `descriptive_count'
    return scalar descriptive_n = `descriptive_n'
    return scalar warnings = `warnings'
end
