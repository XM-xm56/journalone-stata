*! version 0.9.5 17aug2026
capture program drop journalone_prep
program define journalone_prep, rclass
    version 16.0

    local original_options `"`0'"'
    if strtrim(`"`0'"') == "" {
        db journalone_prep
        exit
    }

    _journalone_require_license

    syntax [, VARS(string asis) IDVAR(name) TIMEVAR(name)       ///
        MERGEFILE(string) MERGEKEY(string) MERGETYPE(string) ///
        RECODEVAR(name) RECODEFROM(string) RECODETO(string) ///
        DROPVAR1(name) DROPOP1(string) DROPVALUE1(string) ///
        DROPVAR2(name) DROPOP2(string) DROPVALUE2(string) ///
        DROPVAR3(name) DROPOP3(string) DROPVALUE3(string) ///
        DROPIF(string asis)                                      ///
        KEEPIF(string asis) DUPMETHOD(string) DUPKEY(string asis) ///
        MISSMETHOD(string) MISSVARS(string asis) MISSBY(string asis) ///
        OUTMETHOD(string) OUTVARS(string asis) PLOW(real 1)     ///
        PHIGH(real 99) OUTBY(string asis) LOGVARS(string asis)  ///
        LOGMODE(string) ZVARS(string asis) ENCODEVARS(string asis) ///
        DESTRINGVARS(string asis) OUTDIR(string asis) PREFIX(name) ///
        SAVECLEAN ]

    if c(N) == 0 {
        display as error "当前数据集没有观测值"
        exit 2000
    }

    * The dialog accepts a dataset path with or without surrounding quotes.
    * Keep the path in a single macro so spaces in Windows paths are safe.
    local mergefile = strtrim(`"`mergefile'"')
    if substr(`"`mergefile'"', 1, 1) == char(34) & ///
        substr(`"`mergefile'"', -1, 1) == char(34) {
        local mergefile = substr(`"`mergefile'"', 2, length(`"`mergefile'"') - 2)
    }
    local mergekey = strtrim(`"`mergekey'"')
    local mergetype = lower(strtrim(`"`mergetype'"'))
    if "`mergetype'" == "" local mergetype "1:1"
    if strtrim(`"`mergefile'"') == "" & strtrim(`"`mergekey'"') != "" {
        display as error "填写 mergekey() 前必须填写 mergefile()"
        exit 198
    }
    if strtrim(`"`mergefile'"') != "" {
        capture confirm file `"`mergefile'"'
        if _rc {
            display as error "mergefile() 文件不存在或不可读：`mergefile'"
            exit 601
        }
        if !inlist("`mergetype'", "1:1", "m:1", "1:m") {
            display as error "mergetype() 必须是 1:1、m:1 或 1:m"
            exit 198
        }
        if strtrim(`"`mergekey'"') == "" {
            display as error "填写 mergefile() 时必须填写 mergekey()"
            exit 198
        }
        capture unab mergekey_expanded : `mergekey'
        if _rc {
            display as error "mergekey() 中存在无效变量"
            exit 111
        }
        local mergekey "`mergekey_expanded'"
        capture confirm variable _merge
        if !_rc {
            display as error "主数据已存在保留变量 _merge；请先重命名后再合并"
            exit 110
        }
    }

    local has_recode = (strtrim(`"`recodevar'"') != "" | ///
        strtrim(`"`recodefrom'"') != "" | strtrim(`"`recodeto'"') != "")
    if `has_recode' {
        if strtrim(`"`recodevar'"') == "" | ///
            strtrim(`"`recodefrom'"') == "" | strtrim(`"`recodeto'"') == "" {
            display as error "变量值转换必须同时填写变量、原值和新值"
            exit 198
        }
    }

    * Validate each optional sample-deletion row before preserve().
    forvalues di = 1/3 {
        local dname "dropvar`di'"
        local oname "dropop`di'"
        local vname "dropvalue`di'"
        local dvar "``dname''"
        local dop  "``oname''"
        local dval "``vname''"
        local dhas = (strtrim(`"`dvar'"') != "" | strtrim(`"`dop'"') != "" | ///
            strtrim(`"`dval'"') != "")
        if `dhas' {
            if strtrim(`"`dvar'"') == "" | strtrim(`"`dop'"') == "" {
                display as error "第`di'条删除规则必须填写变量和运算符"
                exit 198
            }
            local dop_l = lower(strtrim(`"`dop'"'))
            local validop = inlist("`dop_l'", "=", "==", "eq", "等于", "!=", "~=", "ne", "不等于", ">") | ///
                inlist("`dop_l'", ">=", "gt", "ge", "<", "<=", "lt", "le", "missing", "缺失") | ///
                inlist("`dop_l'", "nonmissing", "非缺失")
            if !`validop' {
                display as error "第`di'条删除规则运算符无效：`dop'"
                exit 198
            }
            if inlist("`dop_l'", "missing", "缺失", "nonmissing", "非缺失") & ///
                strtrim(`"`dval'"') != "" {
                display as error "第`di'条缺失/非缺失规则不应填写值"
                exit 198
            }
        }
    }
    if "`dupmethod'" == "" local dupmethod "report"
    if "`missmethod'" == "" local missmethod "report"
    if "`outmethod'" == "" local outmethod "report"
    if "`logmode'" == "" local logmode "ln"
    foreach method in dupmethod missmethod outmethod logmode {
        local `method' = lower(strtrim("``method''"))
    }

    if !inlist("`dupmethod'", "report", "exact", "keyfirst", "keylast") {
        display as error "dupmethod() 必须是 report、exact、keyfirst 或 keylast"
        exit 198
    }
    if !inlist("`missmethod'", "report", "drop", "mean", "median") {
        display as error "missmethod() 必须是 report、drop、mean 或 median"
        exit 198
    }
    if !inlist("`outmethod'", "report", "winsor", "winsorreplace", "trim") {
        display as error "outmethod() 必须是 report、winsor、winsorreplace 或 trim"
        exit 198
    }
    if !inlist("`logmode'", "ln", "ln1p") {
        display as error "logmode() 必须是 ln 或 ln1p"
        exit 198
    }
    if `plow' < 0 | `phigh' > 100 | `plow' >= `phigh' {
        display as error "缩尾/截尾分位点必须满足 0 <= plow() < phigh() <= 100"
        exit 198
    }

    if strtrim(`"`vars'"') == "" {
        unab auditvars : _all
    }
    else {
        capture unab auditvars : `vars'
        if _rc {
            display as error "vars() 中存在无效变量"
            exit 111
        }
    }

    foreach item in dupkey missvars missby outvars outby logvars zvars encodevars destringvars {
        if strtrim(`"``item''"') != "" {
            capture unab expanded : ``item''
            if _rc {
                display as error "`item'() 中存在无效变量"
                exit 111
            }
            local `item' "`expanded'"
        }
    }

    if "`idvar'" != "" {
        capture confirm variable `idvar'
        if _rc {
            display as error "ID变量不存在：`idvar'"
            exit 111
        }
    }
    if "`timevar'" != "" {
        capture confirm numeric variable `timevar'
        if _rc {
            display as error "时间变量必须是数值型：`timevar'"
            exit 109
        }
    }
    if inlist("`dupmethod'", "keyfirst", "keylast") & strtrim(`"`dupkey'"') == "" {
        display as error "按键去重必须填写 dupkey()"
        exit 198
    }
    if inlist("`missmethod'", "drop", "mean", "median") & strtrim(`"`missvars'"') == "" {
        display as error "执行缺失处理必须填写 missvars()"
        exit 198
    }
    if inlist("`missmethod'", "mean", "median") {
        foreach v of local missvars {
            capture confirm numeric variable `v'
            if _rc {
                display as error "均值/中位数插补仅支持数值变量：`v'"
                exit 109
            }
        }
    }
    if inlist("`outmethod'", "winsor", "winsorreplace", "trim") & strtrim(`"`outvars'"') == "" {
        display as error "执行缩尾/截尾必须填写 outvars()"
        exit 198
    }
    foreach item in outvars logvars zvars {
        foreach v of local `item' {
            capture confirm numeric variable `v'
            if _rc {
                display as error "`item'() 仅支持数值变量：`v'"
                exit 109
            }
        }
    }
    foreach v of local encodevars {
        capture confirm string variable `v'
        if _rc {
            display as error "encodevars() 仅支持字符串变量：`v'"
            exit 109
        }
    }
    foreach v of local destringvars {
        capture confirm string variable `v'
        if _rc {
            display as error "destringvars() 仅支持字符串变量：`v'"
            exit 109
        }
    }
    if strtrim(`"`keepif'"') != "" & strtrim(`"`mergefile'"') == "" {
        capture quietly count if `keepif'
        if _rc {
            display as error "keepif() 不是有效的 Stata 条件表达式"
            exit 198
        }
    }

    if "`outdir'" == "" local outdir "journalone_prep_output"
    if "`prefix'" == "" local prefix "prep"
    capture mkdir `"`outdir'"'
    tempname write_test
    local testfile `"`outdir'/__journalone_prep_write_test.tmp"'
    capture file open `write_test' using `"`testfile'"', write text replace
    if _rc {
        display as error "输出目录不可写：`outdir'"
        exit 603
    }
    file close `write_test'
    capture erase `"`testfile'"'

    local rundate = subinstr("`c(current_date)'", " ", "", .)
    local runtime = subinstr("`c(current_time)'", ":", "", .)
    local runtime = subinstr("`runtime'", ".", "", .)
    local baseid "`prefix'_`rundate'_`runtime'"
    local runid "`baseid'"
    local suffix = 1
    capture confirm file `"`outdir'/`runid'.log"'
    while !_rc {
        local ++suffix
        local runid "`baseid'_`suffix'"
        capture confirm file `"`outdir'/`runid'.log"'
    }
    local resultbase `"`outdir'/`runid'"'

    local raw_n = c(N)
    local raw_k = c(k)
    local input_file `"`c(filename)'"'
    local sig_before ""
    capture quietly datasignature
    if !_rc local sig_before "`r(datasignature)'"

    capture log close journalone_prep_log
    log using `"`resultbase'.log"', text replace name(journalone_prep_log)
    noisily display as text "JournalOne 数据预处理 | run_id=`runid'"
    noisily display as text "原始观测=`raw_n'  原始变量=`raw_k'"
    noisily display as text "原则：原始内存数据不改写；任何删除、插补或缩尾都由用户显式选择。"

    local savecleanopt ""
    if "`saveclean'" != "" local savecleanopt "saveclean"

    preserve
    capture noisily _journalone_prep_work, runid("`runid'")       ///
        resultbase(`"`resultbase'"') auditvars(`"`auditvars'"') ///
        mergefile(`"`mergefile'"') mergekey(`"`mergekey'"') ///
        mergetype("`mergetype'") recodevar("`recodevar'") ///
        recodefrom(`"`recodefrom'"') recodeto(`"`recodeto'"') ///
        dropvar1("`dropvar1'") dropop1(`"`dropop1'"') ///
        dropvalue1(`"`dropvalue1'"') dropvar2("`dropvar2'") ///
        dropop2(`"`dropop2'"') dropvalue2(`"`dropvalue2'"') ///
        dropvar3("`dropvar3'") dropop3(`"`dropop3'"') ///
        dropvalue3(`"`dropvalue3'"') dropif(`"`dropif'"') ///
        idvar("`idvar'") timevar("`timevar'") keepif(`"`keepif'"') ///
        dupmethod("`dupmethod'") dupkey(`"`dupkey'"')          ///
        missmethod("`missmethod'") missvars(`"`missvars'"')    ///
        missby(`"`missby'"') outmethod("`outmethod'")          ///
        outvars(`"`outvars'"') plow(`plow') phigh(`phigh')      ///
        outby(`"`outby'"') logvars(`"`logvars'"')              ///
        logmode("`logmode'") zvars(`"`zvars'"')                ///
        encodevars(`"`encodevars'"') destringvars(`"`destringvars'"') ///
        `savecleanopt'
    local work_rc = _rc
    if !`work_rc' {
        local clean_n = r(clean_n)
        local clean_k = r(clean_k)
        local merge_matched = r(merge_matched)
        local merge_using_only = r(merge_using_only)
        local merge_master_only = r(merge_master_only)
        local recode_changed = r(recode_changed)
        local drop_rule1_dropped = r(drop_rule1_dropped)
        local drop_rule2_dropped = r(drop_rule2_dropped)
        local drop_rule3_dropped = r(drop_rule3_dropped)
        local dropif_dropped = r(dropif_dropped)
        local exact_dup_surplus = r(exact_dup_surplus)
        local key_dup_surplus = r(key_dup_surplus)
        local idtime_dup_surplus = r(idtime_dup_surplus)
        local panel_units = r(panel_units)
        local time_periods = r(time_periods)
        local panel_min_t = r(panel_min_t)
        local panel_max_t = r(panel_max_t)
        local panel_declared = r(panel_declared)
        local panel_set_rc = r(panel_set_rc)
        local idtime_clean_dup_surplus = r(idtime_clean_dup_surplus)
        local keep_dropped = r(keep_dropped)
        local duplicate_dropped = r(duplicate_dropped)
        local missing_rows = r(missing_rows)
        local missing_dropped = r(missing_dropped)
        local imputed_cells = r(imputed_cells)
        local outlier_rows = r(outlier_rows)
        local outlier_cells = r(outlier_cells)
        local outlier_dropped = r(outlier_dropped)
        local transform_invalid = r(transform_invalid)
        local warnings = r(warnings)
        local clean_signature "`r(clean_signature)'"
        local generated_vars "`r(generated_vars)'"
    }
    restore

    if `work_rc' {
        capture log close journalone_prep_log
        display as error "数据预处理失败，返回码 `work_rc'；原始内存数据已恢复"
        exit `work_rc'
    }

    local sig_after ""
    capture quietly datasignature
    if !_rc local sig_after "`r(datasignature)'"
    local memory_unchanged = ("`sig_before'" == "`sig_after'")
    if !`memory_unchanged' local ++warnings

    local findings = `exact_dup_surplus' + `key_dup_surplus' + ///
        `idtime_dup_surplus' + `missing_rows' + `outlier_rows' + ///
        `transform_invalid' + `merge_using_only' + `drop_rule1_dropped' + ///
        `drop_rule2_dropped' + `drop_rule3_dropped' + `dropif_dropped'
    local status "PASS"
    if `findings' > 0 local status "PASS_WITH_FINDINGS"
    if `warnings' > 0 local status "PASS_WITH_WARNINGS"

    tempname audit_handle
    file open `audit_handle' using `"`resultbase'_audit.txt"', write text replace
    file write `audit_handle' "status=`status'" _n
    file write `audit_handle' "run_id=`runid'" _n
    file write `audit_handle' `"input_file=`input_file'"' _n
    file write `audit_handle' "raw_n=`raw_n'" _n
    file write `audit_handle' "raw_k=`raw_k'" _n
    file write `audit_handle' "clean_n=`clean_n'" _n
    file write `audit_handle' "clean_k=`clean_k'" _n
    file write `audit_handle' `"merge_file=`mergefile'"' _n
    file write `audit_handle' `"merge_key=`mergekey'"' _n
    file write `audit_handle' "merge_type=`mergetype'" _n
    file write `audit_handle' "merge_matched=`merge_matched'" _n
    file write `audit_handle' "merge_master_only=`merge_master_only'" _n
    file write `audit_handle' "merge_using_only=`merge_using_only'" _n
    file write `audit_handle' "recode_var=`recodevar'" _n
    file write `audit_handle' `"recode_from=`recodefrom'"' _n
    file write `audit_handle' `"recode_to=`recodeto'"' _n
    file write `audit_handle' "recode_changed=`recode_changed'" _n
    file write `audit_handle' "drop_rule1=`dropvar1' `dropop1' `dropvalue1'" _n
    file write `audit_handle' "drop_rule1_dropped=`drop_rule1_dropped'" _n
    file write `audit_handle' "drop_rule2=`dropvar2' `dropop2' `dropvalue2'" _n
    file write `audit_handle' "drop_rule2_dropped=`drop_rule2_dropped'" _n
    file write `audit_handle' "drop_rule3=`dropvar3' `dropop3' `dropvalue3'" _n
    file write `audit_handle' "drop_rule3_dropped=`drop_rule3_dropped'" _n
    file write `audit_handle' `"dropif=`dropif'"' _n
    file write `audit_handle' "dropif_dropped=`dropif_dropped'" _n
    file write `audit_handle' `"audit_vars=`auditvars'"' _n
    file write `audit_handle' "id_var=`idvar'" _n
    file write `audit_handle' "time_var=`timevar'" _n
    file write `audit_handle' `"sample_condition=`keepif'"' _n
    file write `audit_handle' "duplicate_method=`dupmethod'" _n
    file write `audit_handle' `"duplicate_key=`dupkey'"' _n
    file write `audit_handle' "missing_method=`missmethod'" _n
    file write `audit_handle' `"missing_vars=`missvars'"' _n
    file write `audit_handle' `"missing_by=`missby'"' _n
    file write `audit_handle' "outlier_method=`outmethod'" _n
    file write `audit_handle' `"outlier_vars=`outvars'"' _n
    file write `audit_handle' `"outlier_by=`outby'"' _n
    file write `audit_handle' "outlier_percentiles=`plow',`phigh'" _n
    file write `audit_handle' `"log_vars=`logvars'"' _n
    file write `audit_handle' "log_mode=`logmode'" _n
    file write `audit_handle' `"standardize_vars=`zvars'"' _n
    file write `audit_handle' `"encode_vars=`encodevars'"' _n
    file write `audit_handle' `"destring_vars=`destringvars'"' _n
    file write `audit_handle' "clean_copy_requested=" ("`saveclean'" != "") _n
    file write `audit_handle' "keep_dropped=`keep_dropped'" _n
    file write `audit_handle' "exact_duplicate_surplus=`exact_dup_surplus'" _n
    file write `audit_handle' "key_duplicate_surplus=`key_dup_surplus'" _n
    file write `audit_handle' "id_time_duplicate_surplus=`idtime_dup_surplus'" _n
    file write `audit_handle' "duplicate_dropped=`duplicate_dropped'" _n
    file write `audit_handle' "missing_rows=`missing_rows'" _n
    file write `audit_handle' "missing_dropped=`missing_dropped'" _n
    file write `audit_handle' "imputed_cells=`imputed_cells'" _n
    file write `audit_handle' "outlier_rows=`outlier_rows'" _n
    file write `audit_handle' "outlier_cells=`outlier_cells'" _n
    file write `audit_handle' "outlier_dropped=`outlier_dropped'" _n
    file write `audit_handle' "transform_invalid=`transform_invalid'" _n
    file write `audit_handle' "panel_units=`panel_units'" _n
    file write `audit_handle' "time_periods=`time_periods'" _n
    file write `audit_handle' "panel_min_t=`panel_min_t'" _n
    file write `audit_handle' "panel_max_t=`panel_max_t'" _n
    file write `audit_handle' "panel_declared=`panel_declared'" _n
    file write `audit_handle' "panel_set_rc=`panel_set_rc'" _n
    file write `audit_handle' "id_time_duplicate_surplus_clean=`idtime_clean_dup_surplus'" _n
    file write `audit_handle' `"generated_vars=`generated_vars'"' _n
    file write `audit_handle' "warnings=`warnings'" _n
    file write `audit_handle' "data_signature_raw=`sig_before'" _n
    file write `audit_handle' "data_signature_clean=`clean_signature'" _n
    file write `audit_handle' "data_signature_after_restore=`sig_after'" _n
    file write `audit_handle' "memory_data_unchanged=`memory_unchanged'" _n
    file write `audit_handle' "automatic_causal_validity=NOT_ESTABLISHED" _n
    file close `audit_handle'

    tempname recipe_handle
    file open `recipe_handle' using `"`resultbase'_recipe.do"', write text replace
    file write `recipe_handle' "version 16.0" _n
    file write `recipe_handle' "* JournalOne generated preprocessing recipe" _n
    if strtrim(`"`input_file'"') != "" {
        file write `recipe_handle' `"use "`input_file'", clear"' _n
    }
    else {
        file write `recipe_handle' "* Load the original input dataset before replaying this command." _n
    }
    file write `recipe_handle' `"journalone_prep `original_options'"' _n
    file close `recipe_handle'

    noisily display as result "预处理完成：`status'"
    noisily display as text "审计：`resultbase'_audit.txt"
    noisily display as text "字典：`resultbase'_dictionary.csv"
    noisily display as text "样本流：`resultbase'_flow.csv"
    if "`saveclean'" != "" noisily display as text "清洗数据：`resultbase'_clean.dta"
    noisily display as text "原始内存数据已恢复，未被覆盖。"
    capture log close journalone_prep_log

    return local status "`status'"
    return local runid "`runid'"
    return local audit_path `"`resultbase'_audit.txt"'
    return local dictionary_path `"`resultbase'_dictionary.csv"'
    return local flow_path `"`resultbase'_flow.csv"'
    return local recipe_path `"`resultbase'_recipe.do"'
    if "`saveclean'" != "" return local clean_path `"`resultbase'_clean.dta"'
    return local generated_vars "`generated_vars'"
    return scalar clean_n = `clean_n'
    return scalar merge_matched = `merge_matched'
    return scalar merge_using_only = `merge_using_only'
    return scalar merge_master_only = `merge_master_only'
    return scalar recode_changed = `recode_changed'
    return scalar drop_rule1_dropped = `drop_rule1_dropped'
    return scalar drop_rule2_dropped = `drop_rule2_dropped'
    return scalar drop_rule3_dropped = `drop_rule3_dropped'
    return scalar dropif_dropped = `dropif_dropped'
    return scalar warnings = `warnings'
    return scalar panel_declared = `panel_declared'
    return scalar panel_set_rc = `panel_set_rc'
    return scalar idtime_clean_dup_surplus = `idtime_clean_dup_surplus'
end


capture program drop _journalone_prep_work
program define _journalone_prep_work, rclass
    version 16.0
    syntax , RUNID(string) RESULTBASE(string) AUDITVARS(string) ///
        DUPMETHOD(string) MISSMETHOD(string) OUTMETHOD(string)       ///
        LOGMODE(string) PLOW(real) PHIGH(real)                       ///
        [ MERGEFILE(string) MERGEKEY(string) MERGETYPE(string)        ///
          RECODEVAR(string) RECODEFROM(string) RECODETO(string)      ///
          DROPVAR1(string) DROPOP1(string) DROPVALUE1(string)        ///
          DROPVAR2(string) DROPOP2(string) DROPVALUE2(string)        ///
          DROPVAR3(string) DROPOP3(string) DROPVALUE3(string)        ///
          DROPIF(string) IDVAR(string) TIMEVAR(string) KEEPIF(string) ///
          DUPKEY(string) MISSVARS(string) MISSBY(string)              ///
          OUTVARS(string) OUTBY(string) LOGVARS(string)               ///
          ZVARS(string) ENCODEVARS(string) DESTRINGVARS(string)       ///
          SAVECLEAN ]

    tempfile inventory_data flow_data
    tempname inventory_post flow_post
    postfile `inventory_post' str8 stage str32 variable str12 storage ///
        str80 variable_label double N n_nonmissing n_missing missing_pct ///
        n_unique mean sd min p1 p25 median p75 p99 max                 ///
        using `inventory_data', replace
    postfile `flow_post' str32 step double n_before n_after affected  ///
        str120 detail using `flow_data', replace

    local raw_n = c(N)
    local raw_k = c(k)
    local warnings = 0
    local merge_matched = 0
    local merge_using_only = 0
    local merge_master_only = 0
    local recode_changed = 0
    local drop_rule1_dropped = 0
    local drop_rule2_dropped = 0
    local drop_rule3_dropped = 0
    local dropif_dropped = 0
    local keep_dropped = 0
    local duplicate_dropped = 0
    local missing_rows = 0
    local missing_dropped = 0
    local imputed_cells = 0
    local outlier_rows = 0
    local outlier_cells = 0
    local outlier_dropped = 0
    local transform_invalid = 0
    local generated_vars ""
    local panel_declared = 0
    local panel_set_rc = .
    local idtime_clean_dup_surplus = .

    unab original_vars : _all
    tempvar original_order
    generate long `original_order' = _n

    _journalone_prep_inventory, handle(`inventory_post') stage("raw") ///
        vars(`"`auditvars'"')

    quietly duplicates report `original_vars'
    local exact_dup_surplus = r(N) - r(unique_value)
    local key_dup_surplus = 0
    if strtrim(`"`dupkey'"') != "" {
        quietly duplicates report `dupkey'
        local key_dup_surplus = r(N) - r(unique_value)
    }

    local idtime_dup_surplus = 0
    local panel_units = .
    local time_periods = .
    local panel_min_t = .
    local panel_max_t = .
    if "`idvar'" != "" {
        tempvar id_tag panel_t
        quietly egen byte `id_tag' = tag(`idvar'), missing
        quietly count if `id_tag'
        local panel_units = r(N)
        drop `id_tag'
        bysort `idvar': generate long `panel_t' = _N
        quietly summarize `panel_t', meanonly
        local panel_min_t = r(min)
        local panel_max_t = r(max)
        drop `panel_t'
    }
    if "`timevar'" != "" {
        tempvar time_tag
        quietly egen byte `time_tag' = tag(`timevar'), missing
        quietly count if `time_tag'
        local time_periods = r(N)
        drop `time_tag'
    }
    if "`idvar'" != "" & "`timevar'" != "" {
        quietly duplicates report `idvar' `timevar'
        local idtime_dup_surplus = r(N) - r(unique_value)
    }

    post `flow_post' ("raw") (`raw_n') (`raw_n') (0) ("原始数据")

    * Optional external merge.  The master data are retained; using-only
    * observations are excluded and all merge counts are recorded.
    if strtrim(`"`mergefile'"') != "" {
        local before = c(N)
        capture noisily merge `mergetype' `mergekey' using `"`mergefile'"'
        local merge_rc = _rc
        if `merge_rc' {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "外部数据合并失败；原始内存数据已恢复"
            exit `merge_rc'
        }
        quietly count if _merge == 3
        local merge_matched = r(N)
        quietly count if _merge == 1
        local merge_master_only = r(N)
        quietly count if _merge == 2
        local merge_using_only = r(N)
        quietly drop if _merge == 2
        drop _merge
        local after = c(N)
        post `flow_post' ("merge") (`before') (`after') ///
            (`merge_using_only') (`"type=`mergetype'; matched=`merge_matched'; using_only=`merge_using_only'"')
        if c(N) == 0 {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "合并后没有主数据观测"
            exit 2000
        }
    }

    * Optional one-variable value conversion.  Numeric and string variables
    * are handled separately; invalid numeric literals stop the run safely.
    if strtrim(`"`recodevar'"') != "" {
        capture confirm variable `recodevar'
        if _rc {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "recodevar() 变量不存在：`recodevar'"
            exit 111
        }
        local recode_from_clean = strtrim(`"`recodefrom'"')
        local recode_to_clean = strtrim(`"`recodeto'"')
        if length(`"`recode_from_clean'"') >= 2 & ///
            substr(`"`recode_from_clean'"', 1, 1) == char(34) & ///
            substr(`"`recode_from_clean'"', -1, 1) == char(34) {
            local recode_from_clean = substr(`"`recode_from_clean'"', 2, ///
                length(`"`recode_from_clean'"') - 2)
        }
        if length(`"`recode_to_clean'"') >= 2 & ///
            substr(`"`recode_to_clean'"', 1, 1) == char(34) & ///
            substr(`"`recode_to_clean'"', -1, 1) == char(34) {
            local recode_to_clean = substr(`"`recode_to_clean'"', 2, ///
                length(`"`recode_to_clean'"') - 2)
        }
        capture confirm string variable `recodevar'
        if !_rc {
            if strpos(`"`recode_from_clean'"', char(34)) | ///
                strpos(`"`recode_to_clean'"', char(34)) | ///
                strpos(`"`recode_from_clean'"', char(10)) | ///
                strpos(`"`recode_to_clean'"', char(10)) {
                postclose `inventory_post'
                postclose `flow_post'
                display as error "字符串值转换不接受引号或换行符"
                exit 198
            }
            quietly count if `recodevar' == `"`recode_from_clean'"'
            local recode_changed = r(N)
            quietly replace `recodevar' = `"`recode_to_clean'"' if ///
                `recodevar' == `"`recode_from_clean'"'
        }
        else {
            capture confirm number `recode_from_clean'
            if _rc {
                postclose `inventory_post'
                postclose `flow_post'
                display as error "数值变量的原值不是有效数值：`recode_from_clean'"
                exit 198
            }
            capture confirm number `recode_to_clean'
            if _rc {
                postclose `inventory_post'
                postclose `flow_post'
                display as error "数值变量的新值不是有效数值：`recode_to_clean'"
                exit 198
            }
            quietly count if `recodevar' == `recode_from_clean'
            local recode_changed = r(N)
            quietly replace `recodevar' = `recode_to_clean' if ///
                `recodevar' == `recode_from_clean'
        }
        post `flow_post' ("value_recode") (c(N)) (c(N)) ///
            (`recode_changed') (`"var=`recodevar'; from=`recode_from_clean'; to=`recode_to_clean'"')
    }

    if strtrim(`"`keepif'"') != "" {
        capture quietly count if `keepif'
        if _rc {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "keepif() 不是有效的 Stata 条件表达式"
            exit 198
        }
        local before = c(N)
        quietly keep if `keepif'
        local after = c(N)
        local keep_dropped = `before' - `after'
        post `flow_post' ("sample_condition") (`before') (`after') ///
            (`keep_dropped') (`"keep if `keepif'"')
        if c(N) == 0 {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "keepif() 删除了全部观测"
            exit 2000
        }
    }

    if "`dupmethod'" != "report" {
        local before = c(N)
        if "`dupmethod'" == "exact" {
            quietly duplicates drop `original_vars', force
        }
        if "`dupmethod'" == "keyfirst" {
            quietly sort `original_order'
            quietly duplicates drop `dupkey', force
        }
        if "`dupmethod'" == "keylast" {
            quietly gsort `dupkey' -`original_order'
            quietly duplicates drop `dupkey', force
        }
        quietly sort `original_order'
        local after = c(N)
        local duplicate_dropped = `before' - `after'
        post `flow_post' ("duplicates") (`before') (`after')       ///
            (`duplicate_dropped') (`"method=`dupmethod'"')
    }

    local effective_missvars `"`missvars'"'
    if strtrim(`"`effective_missvars'"') == "" local effective_missvars `"`auditvars'"'
    tempvar missing_row
    generate byte `missing_row' = 0
    foreach v of local effective_missvars {
        quietly replace `missing_row' = 1 if missing(`v')
    }
    quietly count if `missing_row'
    local missing_rows = r(N)

    if "`missmethod'" == "drop" {
        local before = c(N)
        quietly drop if `missing_row'
        local after = c(N)
        local missing_dropped = `before' - `after'
        post `flow_post' ("missing_listwise") (`before') (`after') ///
            (`missing_dropped') (`"vars=`missvars'"')
        if c(N) == 0 {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "完整案例删除后没有观测值"
            exit 2000
        }
    }
    if inlist("`missmethod'", "mean", "median") {
        foreach v of local missvars {
            _journalone_prep_newname, base("mi_`v'")
            local newvar "`r(name)'"
            _journalone_prep_newname, base("m_`v'")
            local flagvar "`r(name)'"
            generate byte `flagvar' = missing(`v')
            generate double `newvar' = `v'

            local fallback = .
            if "`missmethod'" == "mean" {
                quietly summarize `v', meanonly
                local fallback = r(mean)
            }
            if "`missmethod'" == "median" {
                quietly summarize `v', detail
                local fallback = r(p50)
            }

            if strtrim(`"`missby'"') != "" {
                tempvar group_fill
                if "`missmethod'" == "mean" {
                    bysort `missby': egen double `group_fill' = mean(`v')
                }
                if "`missmethod'" == "median" {
                    bysort `missby': egen double `group_fill' = median(`v')
                }
                quietly replace `newvar' = `group_fill' if `flagvar' & !missing(`group_fill')
                drop `group_fill'
            }
            if !missing(`fallback') {
                quietly replace `newvar' = `fallback' if `flagvar' & missing(`newvar')
            }
            else local ++warnings

            quietly count if `flagvar' & !missing(`newvar')
            local imputed_cells = `imputed_cells' + r(N)
            label variable `newvar' "`missmethod' imputation of `v'"
            label variable `flagvar' "Missing-value flag for `v'"
            local generated_vars "`generated_vars' `newvar' `flagvar'"
        }
        post `flow_post' ("missing_imputation") (c(N)) (c(N))    ///
            (`imputed_cells') (`"method=`missmethod'; new variables"')
    }
    drop `missing_row'

    tempvar outlier_row outlier_cell lower_cut upper_cut
    generate byte `outlier_row' = 0
    foreach v of local outvars {
        if strtrim(`"`outby'"') != "" {
            if `plow' == 0 {
                bysort `outby': egen double `lower_cut' = min(`v')
            }
            else {
                bysort `outby': egen double `lower_cut' = pctile(`v'), p(`plow')
            }
            if `phigh' == 100 {
                bysort `outby': egen double `upper_cut' = max(`v')
            }
            else {
                bysort `outby': egen double `upper_cut' = pctile(`v'), p(`phigh')
            }
        }
        else {
            local lower_value = .
            local upper_value = .
            if `plow' == 0 | `phigh' == 100 {
                quietly summarize `v', meanonly
                if `plow' == 0 local lower_value = r(min)
                if `phigh' == 100 local upper_value = r(max)
            }
            if `plow' > 0 & `phigh' < 100 {
                quietly _pctile `v', percentiles(`plow' `phigh')
                local lower_value = r(r1)
                local upper_value = r(r2)
            }
            if `plow' > 0 & `phigh' == 100 {
                quietly _pctile `v', percentiles(`plow')
                local lower_value = r(r1)
            }
            if `plow' == 0 & `phigh' < 100 {
                quietly _pctile `v', percentiles(`phigh')
                local upper_value = r(r1)
            }
            generate double `lower_cut' = `lower_value'
            generate double `upper_cut' = `upper_value'
        }
        generate byte `outlier_cell' = !missing(`v') &               ///
            (`v' < `lower_cut' | `v' > `upper_cut')
        quietly count if `outlier_cell'
        local outlier_cells = `outlier_cells' + r(N)
        quietly replace `outlier_row' = 1 if `outlier_cell'

        if inlist("`outmethod'", "winsor", "winsorreplace") {
            local target "`v'"
            if "`outmethod'" == "winsor" {
                _journalone_prep_newname, base("w_`v'")
                local target "`r(name)'"
                generate double `target' = `v'
                label variable `target' "Winsorized `v' (`plow', `phigh')"
                local generated_vars "`generated_vars' `target'"
            }
            quietly replace `target' = `lower_cut' if !missing(`target') & `target' < `lower_cut'
            quietly replace `target' = `upper_cut' if !missing(`target') & `target' > `upper_cut'
        }
        drop `outlier_cell' `lower_cut' `upper_cut'
    }
    quietly count if `outlier_row'
    local outlier_rows = r(N)
    if "`outmethod'" == "trim" {
        local before = c(N)
        quietly drop if `outlier_row'
        local after = c(N)
        local outlier_dropped = `before' - `after'
        post `flow_post' ("outlier_trim") (`before') (`after')      ///
            (`outlier_dropped') (`"p=`plow',`phigh'"')
        if c(N) == 0 {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "截尾后没有观测值"
            exit 2000
        }
    }
    if inlist("`outmethod'", "winsor", "winsorreplace") {
        post `flow_post' ("outlier_winsor") (c(N)) (c(N))          ///
            (`outlier_cells') (`"method=`outmethod'; p=`plow',`phigh'"')
    }
    drop `outlier_row'

    foreach v of local logvars {
        _journalone_prep_newname, base("ln_`v'")
        local newvar "`r(name)'"
        if "`logmode'" == "ln" {
            generate double `newvar' = ln(`v') if `v' > 0
            quietly count if !missing(`v') & `v' <= 0
        }
        if "`logmode'" == "ln1p" {
            generate double `newvar' = ln(1 + `v') if `v' > -1
            quietly count if !missing(`v') & `v' <= -1
        }
        local transform_invalid = `transform_invalid' + r(N)
        label variable `newvar' "`logmode' transform of `v'"
        local generated_vars "`generated_vars' `newvar'"
    }

    foreach v of local zvars {
        _journalone_prep_newname, base("z_`v'")
        local newvar "`r(name)'"
        quietly summarize `v'
        if r(N) > 1 & r(sd) > 0 {
            generate double `newvar' = (`v' - r(mean)) / r(sd)
        }
        else {
            generate double `newvar' = .
            local ++warnings
        }
        label variable `newvar' "Standardized `v'"
        local generated_vars "`generated_vars' `newvar'"
    }

    foreach v of local encodevars {
        _journalone_prep_newname, base("cat_`v'")
        local newvar "`r(name)'"
        capture noisily encode `v', generate(`newvar')
        local encode_rc = _rc
        if !`encode_rc' {
            capture confirm numeric variable `newvar'
            if _rc local encode_rc = 459
        }
        if `encode_rc' {
            postclose `inventory_post'
            postclose `flow_post'
            exit `encode_rc'
        }
        local generated_vars "`generated_vars' `newvar'"
    }

    foreach v of local destringvars {
        _journalone_prep_newname, base("num_`v'")
        local newvar "`r(name)'"
        capture noisily destring `v', generate(`newvar')
        local destring_rc = _rc
        if !`destring_rc' {
            capture confirm numeric variable `newvar'
            if _rc local destring_rc = 459
        }
        if `destring_rc' {
            postclose `inventory_post'
            postclose `flow_post'
            exit `destring_rc'
        }
        local generated_vars "`generated_vars' `newvar'"
    }

    * Optional sample-deletion rows from the dialog.  They run sequentially
    * and are written to the sample-flow file one row at a time.
    forvalues di = 1/3 {
        local dname "dropvar`di'"
        local oname "dropop`di'"
        local vname "dropvalue`di'"
        local dvar "``dname''"
        local dop  "``oname''"
        local dval  "``vname''"
        if strtrim(`"`dvar'"') != "" {
            local before = c(N)
            capture noisily _journalone_prep_drop_condition, ///
                var("`dvar'") op(`"`dop'"') value(`"`dval'"')
            local drop_rc = _rc
            if `drop_rc' {
                postclose `inventory_post'
                postclose `flow_post'
                display as error "第`di'条删除规则执行失败；原始内存数据已恢复"
                exit `drop_rc'
            }
            local affected = r(affected)
            local dnorm "`r(operator)'"
            local detail `"var=`dvar'; op=`dnorm'; value=`dval'"'
            local after = c(N)
            if `di' == 1 local drop_rule1_dropped = `before' - `after'
            if `di' == 2 local drop_rule2_dropped = `before' - `after'
            if `di' == 3 local drop_rule3_dropped = `before' - `after'
            post `flow_post' ("drop_rule`di'") (`before') (`after') ///
                (`affected') (`"`detail'"')
            if c(N) == 0 {
                postclose `inventory_post'
                postclose `flow_post'
                display as error "第`di'条删除规则删除了全部观测"
                exit 2000
            }
        }
    }

    if strtrim(`"`dropif'"') != "" {
        capture quietly count if `dropif'
        if _rc {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "dropif() 不是有效的 Stata 条件表达式"
            exit 198
        }
        local before = c(N)
        quietly count if `dropif'
        local dropif_dropped = r(N)
        quietly drop if `dropif'
        local after = c(N)
        post `flow_post' ("drop_if") (`before') (`after') ///
            (`dropif_dropped') (`"drop if `dropif'"')
        if c(N) == 0 {
            postclose `inventory_post'
            postclose `flow_post'
            display as error "dropif() 删除了全部观测"
            exit 2000
        }
    }

    quietly sort `original_order'
    drop `original_order'

    * Preserve the declared panel structure in the cleaned copy whenever the
    * requested ID/time variables form a valid Stata panel.  A declaration
    * failure is recorded as a warning rather than changing or discarding the
    * cleaned data; the outer preserve/restore still protects source memory.
    if "`idvar'" != "" {
        local panel_command "xtset `idvar'"
        if "`timevar'" != "" {
            quietly duplicates report `idvar' `timevar'
            local idtime_clean_dup_surplus = r(N) - r(unique_value)
            local panel_command "xtset `idvar' `timevar'"
        }
        capture quietly `panel_command'
        local panel_set_rc = _rc
        if `panel_set_rc' {
            local ++warnings
            post `flow_post' ("panel_declaration") (c(N)) (c(N)) (0) ///
                (`"`panel_command'; rc=`panel_set_rc'; not declared"')
        }
        else {
            local panel_declared = 1
            post `flow_post' ("panel_declaration") (c(N)) (c(N)) (1) ///
                (`"`panel_command'; rc=0"')
        }
    }

    local clean_n = c(N)
    local clean_k = c(k)
    local clean_signature ""
    capture quietly datasignature
    if !_rc local clean_signature "`r(datasignature)'"

    unab cleanvars : _all
    _journalone_prep_inventory, handle(`inventory_post') stage("clean") ///
        vars(`"`cleanvars'"')
    post `flow_post' ("clean_final") (`clean_n') (`clean_n') (0)       ///
        ("最终清洗数据")
    postclose `inventory_post'
    postclose `flow_post'

    if "`saveclean'" != "" {
        save `"`resultbase'_clean.dta"', replace
    }

    quietly use `inventory_data', clear
    sort stage variable
    save `"`resultbase'_dictionary.dta"', replace
    export delimited using `"`resultbase'_dictionary.csv"', replace

    quietly use `flow_data', clear
    save `"`resultbase'_flow.dta"', replace
    export delimited using `"`resultbase'_flow.csv"', replace

    return scalar clean_n = `clean_n'
    return scalar clean_k = `clean_k'
    return scalar merge_matched = `merge_matched'
    return scalar merge_using_only = `merge_using_only'
    return scalar merge_master_only = `merge_master_only'
    return scalar recode_changed = `recode_changed'
    return scalar drop_rule1_dropped = `drop_rule1_dropped'
    return scalar drop_rule2_dropped = `drop_rule2_dropped'
    return scalar drop_rule3_dropped = `drop_rule3_dropped'
    return scalar dropif_dropped = `dropif_dropped'
    return scalar exact_dup_surplus = `exact_dup_surplus'
    return scalar key_dup_surplus = `key_dup_surplus'
    return scalar idtime_dup_surplus = `idtime_dup_surplus'
    return scalar panel_units = `panel_units'
    return scalar time_periods = `time_periods'
    return scalar panel_min_t = `panel_min_t'
    return scalar panel_max_t = `panel_max_t'
    return scalar panel_declared = `panel_declared'
    return scalar panel_set_rc = `panel_set_rc'
    return scalar idtime_clean_dup_surplus = `idtime_clean_dup_surplus'
    return scalar keep_dropped = `keep_dropped'
    return scalar duplicate_dropped = `duplicate_dropped'
    return scalar missing_rows = `missing_rows'
    return scalar missing_dropped = `missing_dropped'
    return scalar imputed_cells = `imputed_cells'
    return scalar outlier_rows = `outlier_rows'
    return scalar outlier_cells = `outlier_cells'
    return scalar outlier_dropped = `outlier_dropped'
    return scalar transform_invalid = `transform_invalid'
    return scalar warnings = `warnings'
    return local clean_signature "`clean_signature'"
    return local generated_vars "`generated_vars'"
end


capture program drop _journalone_prep_drop_condition
program define _journalone_prep_drop_condition, rclass
    version 16.0
    syntax , VAR(name) OP(string) [ VALUE(string) ]

    local op = lower(strtrim(`"`op'"'))
    local value_clean = strtrim(`"`value'"')
    if length(`"`value_clean'"') >= 2 & ///
        substr(`"`value_clean'"', 1, 1) == char(34) & ///
        substr(`"`value_clean'"', -1, 1) == char(34) {
        local value_clean = substr(`"`value_clean'"', 2, ///
            length(`"`value_clean'"') - 2)
    }

    local opnorm ""
    if inlist("`op'", "=", "==", "eq", "等于") local opnorm "=="
    if inlist("`op'", "!=", "~=", "ne", "不等于") local opnorm "!="
    if inlist("`op'", ">", "gt") local opnorm ">"
    if inlist("`op'", ">=", "ge") local opnorm ">="
    if inlist("`op'", "<", "lt") local opnorm "<"
    if inlist("`op'", "<=", "le") local opnorm "<="
    if inlist("`op'", "missing", "缺失") local opnorm "missing"
    if inlist("`op'", "nonmissing", "非缺失") local opnorm "nonmissing"
    if "`opnorm'" == "" {
        display as error "删除规则运算符无效：`op'"
        exit 198
    }

    capture confirm variable `var'
    if _rc {
        display as error "删除规则变量不存在：`var'"
        exit 111
    }

    local condition ""
    if "`opnorm'" == "missing" local condition "missing(`var')"
    if "`opnorm'" == "nonmissing" local condition "!missing(`var')"
    if inlist("`opnorm'", "==", "!=", ">", ">=", "<", "<=") {
        if strtrim(`"`value_clean'"') == "" {
            display as error "删除规则运算符 `op' 必须填写值"
            exit 198
        }
        capture confirm string variable `var'
        if !_rc {
            if strpos(`"`value_clean'"', char(34)) | ///
                strpos(`"`value_clean'"', char(10)) | ///
                strpos(`"`value_clean'"', char(13)) {
                display as error "字符串删除规则的值不接受引号或换行符"
                exit 198
            }
            local value_quoted = char(34) + `"`value_clean'"' + char(34)
            local condition "`var' `opnorm' `value_quoted'"
        }
        else {
            capture confirm number `value_clean'
            if _rc {
                display as error "数值删除规则的值不是有效数值：`value_clean'"
                exit 198
            }
            local condition "`var' `opnorm' `value_clean'"
        }
    }

    quietly count if `condition'
    local affected = r(N)
    quietly drop if `condition'
    return scalar affected = `affected'
    return local operator "`opnorm'"
end


capture program drop _journalone_prep_inventory
program define _journalone_prep_inventory
    version 16.0
    syntax , HANDLE(name) STAGE(string) VARS(string)

    tempvar unique_tag
    foreach v of local vars {
        local vtype : type `v'
        local vlabel : variable label `v'
        local vlabel = subinstr(`"`vlabel'"', char(34), "'", .)
        local vlabel = subinstr(`"`vlabel'"', char(13), " ", .)
        local vlabel = subinstr(`"`vlabel'"', char(10), " ", .)
        local total = c(N)
        quietly count if missing(`v')
        local n_missing = r(N)
        local n_nonmissing = `total' - `n_missing'
        local missing_pct = cond(`total' > 0, 100 * `n_missing' / `total', .)

        local n_unique = .
        capture quietly egen byte `unique_tag' = tag(`v'), missing
        if !_rc {
            quietly count if `unique_tag'
            local n_unique = r(N)
            drop `unique_tag'
        }

        local mean = .
        local sd = .
        local min = .
        local p1 = .
        local p25 = .
        local median = .
        local p75 = .
        local p99 = .
        local max = .
        capture confirm numeric variable `v'
        if !_rc {
            quietly summarize `v', detail
            local mean = r(mean)
            local sd = r(sd)
            local min = r(min)
            local p1 = r(p1)
            local p25 = r(p25)
            local median = r(p50)
            local p75 = r(p75)
            local p99 = r(p99)
            local max = r(max)
        }

        post `handle' ("`stage'") ("`v'") ("`vtype'") (`"`vlabel'"') ///
            (`total') (`n_nonmissing') (`n_missing') (`missing_pct') ///
            (`n_unique') (`mean') (`sd') (`min') (`p1') (`p25')    ///
            (`median') (`p75') (`p99') (`max')
    }
end


capture program drop _journalone_prep_newname
program define _journalone_prep_newname, rclass
    version 16.0
    syntax , BASE(string)

    local root = strtoname("`base'")
    local root = substr("`root'", 1, 32)
    if "`root'" == "" local root "jo_newvar"
    local candidate "`root'"
    local index = 1
    capture confirm new variable `candidate'
    while _rc != 0 {
        local ++index
        local suffix "_`index'"
        local stem = substr("`root'", 1, 32 - length("`suffix'"))
        local candidate "`stem'`suffix'"
        capture confirm new variable `candidate'
    }
    return local name "`candidate'"
end
