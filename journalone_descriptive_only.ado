*! version 0.9.21 06sep2026

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

    local descriptive_unique ""
    foreach descriptive_candidate of local descvars {
        if !strpos(" `descriptive_unique' ", " `descriptive_candidate' ") {
            local descriptive_unique "`descriptive_unique' `descriptive_candidate'"
        }
    }
    local descriptive_count = 0
    foreach descriptive_var of local descriptive_unique {
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
    clonevar N = N_nonmissing
    clonevar Missing = N_missing
    rename variable Variable
    rename mean Mean
    rename sd SD
    rename min Min
    rename max Max
    format Variable %-24s
    format N Missing %12.0fc
    format Mean SD Min Max %14.`decimals'f
    local original_linesize = c(linesize)
    quietly set linesize 255
    noisily display as text "描述性统计（独立模块样本）"
    noisily list Variable N Missing Mean SD Min Max, ///
        noobs separator(0) abbreviate(24)
    quietly set linesize `original_linesize'
    restore

    capture noisily journalone_format_outputs, resultbase(`"`resultbase'"') ///
        descriptive(`"`descriptive_dta'"') decimals(`decimals')             ///
        statistic("`statistic'") pstar1(`pstar1') pstar2(`pstar2')          ///
        pstar3(`pstar3') reportmode("none")
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
    * The formatted CSV in the named result folder is the public result.
    * The run-ID CSV/DTA pair is only an internal publication intermediary.
    capture erase `"`descriptive_file'"'
    capture erase `"`descriptive_dta'"'
    local descriptive_file `"`descriptive_package_csv'"'
    local descriptive_dta ""

    noisily display as result "运行完成：`overall'（仅描述性统计）"
    noisily display as text "描述性统计：`descriptive_file'"
    if strtrim(`"`report_file'"') != "" capture erase `"`report_file'"'
    local report_file ""
    if "`package_output_dirs'" != "" noisily display as result "期刊三件套结果文件夹：`package_output_dirs'"

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
