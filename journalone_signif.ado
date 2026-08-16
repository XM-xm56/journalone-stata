*! version 0.1.0 15aug2026

capture program drop _journalone_signif_one
program define _journalone_signif_one, rclass
    version 16.0
    syntax , HANDLE(name) DOHANDLE(name) SPEC(string) MODEL(string)      ///
        DEPVAR(string) INDEPvars(string) [ CONTROLS(string)                ///
        ABSORB(string) VCETYPE(string) CLUSTER(string)                     ///
        PANEL(string) TIME(string) IFCOND(string) TIMEFE ]

    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"
    file write `dohandle' "* `spec'" _n
    * Keep the generated do-file readable even when a varlist was passed as a
    * compound-quoted local.  Do not interpolate that local into a quoted
    * file-write string (which creates nested quotes and r(198)).
    file write `dohandle' "* model=`model'; depvar=`depvar'; vcetype=`vcetype'" _n
    * Locals received through `string asis' may retain compound-quote markers.
    * Keep the original values for the estimator call, but strip those markers
    * from the human-readable do-file command text.
    local indep_clean = strtrim(`"`indepvars'"')
    local controls_clean = strtrim(`"`controls'"')
    local absorb_clean = strtrim(`"`absorb'"')
    foreach clean_local in indep_clean controls_clean absorb_clean {
        local clean_value ``clean_local''
        if length(`"`clean_value'"') >= 2 & ///
            substr(`"`clean_value'"', 1, 1) == char(34) & ///
            substr(`"`clean_value'"', -1, 1) == char(34) {
            local clean_value = substr(`"`clean_value'"', 2, ///
                length(`"`clean_value'"') - 2)
            local ``clean_local'' `"`clean_value'"'
        }
    }
    local vce_tail ""
    if "`vcetype'" == "robust" local vce_tail "vce(robust)"
    if "`vcetype'" == "cluster" local vce_tail "vce(cluster `cluster')"
    local vce_ols ""
    if "`vce_tail'" != "" local vce_ols ", `vce_tail'"
    local if_clean = strtrim(`"`ifcond'"')
    local if_option ""
    if "`if_clean'" != "" local if_option " if `if_clean'"
    if "`panel'" != "" {
        if "`time'" != "" file write `dohandle' "capture noisily xtset `panel' `time'" _n
        else file write `dohandle' "capture noisily xtset `panel'" _n
    }
    local fe_terms ""
    foreach fevar of local absorb_clean {
        local fe_terms "`fe_terms' i.`fevar'"
    }
    local all_terms "`indep_clean' `controls_clean' `fe_terms'"
    if "`model'" == "ols" {
        file write `dohandle' "quietly regress `depvar' `all_terms'`if_option'`vce_ols'" _n
    }
    else if "`model'" == "hdfe" {
        local hdfe_tail "noabsorb"
        if "`absorb_clean'" != "" local hdfe_tail "absorb(`absorb_clean')"
        if "`vce_tail'" != "" local hdfe_tail "`hdfe_tail' `vce_tail'"
        file write `dohandle' "quietly reghdfe `depvar' `indep_clean' `controls_clean'`if_option', `hdfe_tail'" _n
    }
    else if inlist("`model'", "fe", "re") {
        local panel_tail "`model'"
        if "`vce_tail'" != "" local panel_tail "`panel_tail' `vce_tail'"
        file write `dohandle' "quietly xtreg `depvar' `indep_clean' `controls_clean'`fe_terms'`if_option', `panel_tail'" _n
    }
    else {
        file write `dohandle' "* model `model' requires additional identification fields; inspect the specification above" _n
    }
    file write `dohandle' "capture estimates store signif_last" _n
    local posted_level 95
    capture scalar __jo_signif_ci_level
    if !_rc local posted_level = __jo_signif_ci_level
    if strpos(`"`spec'"', "中介") {
        capture scalar __jo_signif_medlevel
        if !_rc local posted_level = __jo_signif_medlevel
    }
    if strpos(`"`spec'"', "调节") {
        capture scalar __jo_signif_modlevel
        if !_rc local posted_level = __jo_signif_modlevel
    }
    capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
        indepvars("`indep_clean'") controls("`controls_clean'")         ///
        absorb("`absorb_clean'") vcetype("`vcetype'") cluster("`cluster'") ///
        panel("`panel'") time("`time'") ifcond(`"`ifcond'"') `timefeopt'
    local rc = _rc
    if !`rc' {
        capture noisily _journalone_post_current, handle(`handle')       ///
            runid("signif") spec("`spec'") outcome("`depvar'") level(`posted_level')
        local rc = _rc
    }
    return scalar rc = `rc'
end

capture program drop journalone_signif
program define journalone_signif, rclass
    version 16.0

    if strtrim(`"`0'"') == "" {
        db journalone_signif
        exit
    }

    _journalone_require_license

    syntax [, SELECT(string) KEY(string asis) DEPVAR(name) CORE(string asis) ///
        FE(string asis) VCE(string) CLUSTER(name) PANEL(name) TIME(name)  ///
        KEEPCONTROLS(string asis) CANDIDATES(string asis)                  ///
        ALTX(string asis) ALTY(string asis) LAGS(numlist integer >=0)      ///
        LEADS(numlist integer >=0) SUBSAMPLE(string asis) ALTVCE(string)   ///
        ADDFE(string asis) POLICY(string asis) ADDCONTROLS(string asis)    ///
        PTREND PLACEBO(string asis) ALTMODEL(string)                      ///
        MEDIATOR(string asis) MODERATOR(string asis) GROUP(name)          ///
        DIMENSION(string asis) HETY(name) HETX(string asis)                ///
        EXPECTXY(string) EXPECTXM(string) EXPECTXWY(string)               ///
        LEVEL(real 90) MEDLEVEL(real 90) MODLEVEL(real 90)                 ///
        MINCONTROLS(integer 1) MAXSPECS(integer 200)                       ///
        OUTDIR(string asis) PREFIX(string asis) SEED(integer 20260814) REPLACE ]

    if strtrim(`"`depvar'"') == "" | strtrim(`"`core'"') == "" {
        display as error "显著组合至少需要填写被解释变量和解释变量"
        exit 198
    }
    capture confirm variable `depvar'
    if _rc {
        display as error "被解释变量不存在：`depvar'"
        exit 111
    }
    local core_first : word 1 of `core'
    local core_first = subinstr("`core_first'", "c.", "", .)
    local core_first = subinstr("`core_first'", "i.", "", .)
    local core_first = subinstr("`core_first'", "L.", "", .)
    local core_first = subinstr("`core_first'", "F.", "", .)
    capture confirm variable `core_first'
    if _rc {
        display as error "解释变量不存在：`core_first'"
        exit 111
    }
    foreach checkvar of local fe {
        capture confirm variable `checkvar'
        if _rc {
            display as error "固定效应变量不存在：`checkvar'"
            exit 111
        }
        capture confirm numeric variable `checkvar'
        if _rc {
            display as error "固定效应变量必须是数值型：`checkvar'"
            exit 109
        }
    }
    foreach checkvar of local keepcontrols {
        capture confirm variable `checkvar'
        if _rc {
            display as error "必留控制变量不存在：`checkvar'"
            exit 111
        }
    }
    foreach checkvar of local candidates {
        capture confirm variable `checkvar'
        if _rc {
            display as error "候选控制变量不存在：`checkvar'"
            exit 111
        }
    }
    if strtrim(`"`cluster'"') != "" {
        capture confirm variable `cluster'
        if _rc {
            display as error "聚类变量不存在：`cluster'"
            exit 111
        }
        capture confirm numeric variable `cluster'
        if _rc {
            display as error "聚类变量必须是数值型：`cluster'"
            exit 109
        }
    }

    local model "ols"
    local select_clean = lower(strtrim(`"`select'"'))
    if strpos("`select_clean'", "hdfe") | strpos("`select_clean'", "高维固定") local model "hdfe"
    else if strpos("`select_clean'", "面板固定") | inlist("`select_clean'", "fe", "fixed effects") local model "fe"
    else if strpos("`select_clean'", "面板随机") | strpos("`select_clean'", "随机效应") | inlist("`select_clean'", "re", "random effects") local model "re"
    if "`altmodel'" != "" & "`altmodel'" != "不更换" {
        local altmodel_clean = lower(strtrim(`"`altmodel'"'))
        if strpos("`altmodel_clean'", "hdfe") | strpos("`altmodel_clean'", "高维固定") local altmodel "hdfe"
        else if strpos("`altmodel_clean'", "面板固定") | inlist("`altmodel_clean'", "fe", "fixed effects") local altmodel "fe"
        else if strpos("`altmodel_clean'", "面板随机") | strpos("`altmodel_clean'", "随机效应") | inlist("`altmodel_clean'", "re", "random effects") local altmodel "re"
        else local altmodel "ols"
    }

    local vce_clean = lower(strtrim(`"`vce'"'))
    if inlist("`vce_clean'", "异方差稳健", "robust") local vce_clean "robust"
    else if inlist("`vce_clean'", "聚类稳健", "cluster") local vce_clean "cluster"
    else local vce_clean "conventional"
    if "`vce_clean'" == "cluster" & "`cluster'" == "" {
        display as error "聚类稳健标准误必须填写聚类变量"
        exit 198
    }
    local altvce_clean = lower(strtrim(`"`altvce'"'))
    if inlist("`altvce_clean'", "异方差稳健", "robust") local altvce_clean "robust"
    else if inlist("`altvce_clean'", "聚类稳健", "cluster") local altvce_clean "cluster"
    else if inlist("`altvce_clean'", "常规标准误", "conventional") local altvce_clean "conventional"
    else local altvce_clean ""
    if "`altvce_clean'" == "cluster" & strtrim(`"`cluster'"') == "" {
        display as error "替换为聚类稳健标准误时必须填写聚类变量"
        exit 198
    }
    foreach panelvar in panel time {
        local panel_value ``panelvar''
        if strtrim(`"`panel_value'"') != "" {
            capture confirm variable `panel_value'
            if _rc {
                display as error "`panelvar'() 变量不存在：`panel_value'"
                exit 111
            }
            capture confirm numeric variable `panel_value'
            if _rc {
                display as error "`panelvar'() 变量必须是数值型：`panel_value'"
                exit 109
            }
        }
    }
    if inlist("`model'", "fe", "re") & strtrim(`"`panel'"') == "" {
        display as error "面板固定/随机效应模型必须同时填写 panel()（以及可选的 time()）"
        exit 198
    }
    if (strtrim(`"`lags'"') != "" | strtrim(`"`leads'"') != "") & ///
        (strtrim(`"`panel'"') == "" | strtrim(`"`time'"') == "") {
        display as error "滞后/滞前分析必须同时填写 panel() 和 time()"
        exit 198
    }
    if inlist("`altmodel'", "fe", "re") & strtrim(`"`panel'"') == "" {
        display as error "替换为面板固定/随机效应模型时必须填写 panel()"
        exit 198
    }

    if `mincontrols' < 0 {
        display as error "mincontrols() 不得小于0"
        exit 198
    }
    if `maxspecs' < 1 | `maxspecs' > 2000 {
        display as error "maxspecs() 必须介于1和2000之间"
        exit 198
    }
    foreach requested_level in level medlevel modlevel {
        local requested_value ``requested_level''
        if `requested_value' <= 50 | `requested_value' >= 100 {
            display as error "`requested_level'() 必须大于50且小于100"
            exit 198
        }
    }
    * `string asis' preserves the quote characters supplied by a dialog.
    * Normalize those values before comparing or composing file paths; otherwise
    * an input such as outdir("my results") expands to an invalid numeric
    * expression in an `if' statement (r(109)).
    local outdir = subinstr(strtrim(`"`outdir'"'), char(34), "", .)
    local prefix = subinstr(strtrim(`"`prefix'"'), char(34), "", .)
    local key = subinstr(strtrim(`"`key'"'), char(34), "", .)
    if strtrim(`"`outdir'"') == "" local outdir "显著组合结果"
    if strtrim(`"`prefix'"') == "" local prefix "显著组合"
    local outdir = subinstr(`"`outdir'"', "\", "/", .)
    local caller_cwd `"`c(pwd)'"'
    capture mkdir `"`outdir'"'
    if _rc {
        * mkdir returns an error when the directory already exists.  Verify
        * that case by changing into it, then restore the caller's directory.
        capture cd `"`outdir'"'
        local dir_ok = !_rc
        capture cd `"`caller_cwd'"'
        if !`dir_ok' {
            display as error "无法创建输出目录：`outdir'"
            exit 603
        }
    }

    quietly set seed `seed'
    local sig_before ""
    capture datasignature
    if !_rc local sig_before `"`r(datasignature)'"'
    local sig_after ""

    local candidate_count : word count `candidates'
    local keep_count : word count `keepcontrols'
    local required_candidate_count = max(0, `mincontrols' - `keep_count')
    if `candidate_count' > 0 {
        local candidate_masks = 2^`candidate_count'
        if `candidate_masks' > `maxspecs' {
            display as error "候选控制变量组合数为 `candidate_masks'，超过 maxspecs(`maxspecs')；为避免组合爆炸已停止"
            exit 198
        }
    }
    else if `keep_count' < `mincontrols' {
        display as error "必留控制变量数量少于 mincontrols(`mincontrols')，且没有候选控制变量可补足"
        exit 198
    }

    tempfile result_data
    tempname result_post do_handle
    postfile `result_post' str40 run_id str80 specification str32 outcome ///
        double term_order str120 term double estimate std_error p_value    ///
        ci_low ci_high N r2 r2_a using `result_data', replace
    local dofile `"`outdir'/`prefix'.do"'
    file open `do_handle' using `"`dofile'"', write text replace
    file write `do_handle' "version 16.0" _n
    file write `do_handle' "set more off" _n
    file write `do_handle' "* 显著组合：预先登记的模型规格" _n
    file write `do_handle' "* 请先载入分析数据；本脚本只运行下列估计，不改写原始数据。" _n
    file write `do_handle' "* 候选控制变量按预先设定的顺序逐组加入，显著和不显著结果均保留。" _n _n

    preserve
    scalar __jo_signif_ci_level = `level'
    scalar __jo_signif_medlevel = `medlevel'
    scalar __jo_signif_modlevel = `modlevel'
    local spec_total = 0
    local spec_success = 0
    local spec_fail = 0
    local spec_note ""
    local controls_base `"`keepcontrols'"'
    local candidate_controls `"`candidates'"'
    local subsample_clean = strtrim(`"`subsample'"')
    if length(`"`subsample_clean'"') >= 2 & ///
        substr(`"`subsample_clean'"', 1, 1) == char(34) & ///
        substr(`"`subsample_clean'"', -1, 1) == char(34) {
        local subsample_clean = substr(`"`subsample_clean'"', 2, ///
            length(`"`subsample_clean'"') - 2)
    }
    local sample_option ""
    if strtrim(`"`subsample_clean'"') != "" {
        local sample_option `"ifcond(`"`subsample_clean'"')"'
    }

    * Enumerate the predeclared candidate-control subsets in a fixed order.
    * The output keeps every subset, including nonsignificant results.
    local grid_mode = (strpos("`select_clean'", "grid") | ///
        strpos("`select_clean'", "查找") | strpos("`select_clean'", "组合"))
    local total_masks = 1
    if `candidate_count' > 0 local total_masks = 2^`candidate_count'
    forvalues mask = 0/`=`total_masks'-1' {
        local subset_controls `"`controls_base'"'
        local subset_count = 0
        if `candidate_count' > 0 {
            forvalues candidate_index = 1/`candidate_count' {
                local bit = mod(floor(`mask'/2^(`candidate_index'-1)), 2)
                if `bit' == 1 {
                    local candidate_var : word `candidate_index' of `candidate_controls'
                    local subset_controls `"`subset_controls' `candidate_var'"'
                    local subset_count = `subset_count' + 1
                }
            }
        }
        local control_count = `keep_count' + `subset_count'
        if `control_count' < `mincontrols' continue
        if !`grid_mode' & `mask' > 0 continue
        if `spec_total' >= `maxspecs' continue, break
        local spec_total = `spec_total' + 1
        local base_label "基准-必留控制"
        if `subset_count' > 0 local base_label "基准-控制组合`mask'"
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("`base_label'") model("`model'") depvar("`depvar'")  ///
            indepvars(`"`core'"') controls(`"`subset_controls'"')       ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }

    if strtrim(`"`altx'"') != "" & `spec_total' < `maxspecs' {
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("稳健-替换解释变量") model("`model'") depvar("`depvar'") ///
            indepvars(`"`altx'"') controls(`"`controls_base'"')           ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if strtrim(`"`alty'"') != "" {
        foreach alternate_y of local alty {
            if `spec_total' >= `maxspecs' continue, break
            capture confirm variable `alternate_y'
            if _rc {
                local spec_note `"`spec_note' alternate outcome `alternate_y' does not exist;"'
                local spec_fail = `spec_fail' + 1
                continue
            }
            local spec_total = `spec_total' + 1
            _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
                spec("稳健-替换被解释变量-`alternate_y'") model("`model'") depvar("`alternate_y'") ///
                indepvars(`"`core'"') controls(`"`controls_base'"')       ///
                absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
            if !r(rc) local spec_success = `spec_success' + 1
            else local spec_fail = `spec_fail' + 1
        }
    }
    if strtrim(`"`addcontrols'"') != "" & `spec_total' < `maxspecs' {
        local augmented_controls `"`controls_base' `addcontrols'"'
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("稳健-追加控制变量") model("`model'") depvar("`depvar'") ///
            indepvars(`"`core'"') controls(`"`augmented_controls'"')      ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if strtrim(`"`addfe'"') != "" & `spec_total' < `maxspecs' {
        local augmented_fe `"`fe' `addfe'"'
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("稳健-追加固定效应") model("`model'") depvar("`depvar'") ///
            indepvars(`"`core'"') controls(`"`controls_base'"')           ///
            absorb(`"`augmented_fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if "`altvce_clean'" != "" & `spec_total' < `maxspecs' {
        local alt_cluster "`cluster'"
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("稳健-替换标准误") model("`model'") depvar("`depvar'") ///
            indepvars(`"`core'"') controls(`"`controls_base'"')           ///
            absorb(`"`fe'"') vcetype("`altvce_clean'") cluster("`alt_cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if strtrim(`"`lags'"') != "" {
        foreach lag of numlist `lags' {
            if `spec_total' >= `maxspecs' continue, break
            local spec_total = `spec_total' + 1
            local lag_core "L`lag'.`core_first'"
            _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
                spec("稳健-核心变量滞后`lag'期") model("`model'") depvar("`depvar'") ///
                indepvars(`"`lag_core'"') controls(`"`controls_base'"')      ///
                absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
            if !r(rc) local spec_success = `spec_success' + 1
            else local spec_fail = `spec_fail' + 1
        }
    }
    if strtrim(`"`leads'"') != "" {
        foreach lead of numlist `leads' {
            if `spec_total' >= `maxspecs' continue, break
            local spec_total = `spec_total' + 1
            local lead_core "F`lead'.`core_first'"
            _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
                spec("稳健-核心变量滞前`lead'期") model("`model'") depvar("`depvar'") ///
                indepvars(`"`lead_core'"') controls(`"`controls_base'"')      ///
                absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
            if !r(rc) local spec_success = `spec_success' + 1
            else local spec_fail = `spec_fail' + 1
        }
    }
    if "`altmodel'" != "" & "`altmodel'" != "不更换" & `spec_total' < `maxspecs' {
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("稳健-替换模型") model("`altmodel'") depvar("`depvar'") ///
            indepvars(`"`core'"') controls(`"`controls_base'"')           ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if strtrim(`"`mediator'"') != "" & `spec_total' < `maxspecs' {
        local mediator_first : word 1 of `mediator'
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("机制-中介方程") model("`model'") depvar("`mediator_first'") ///
            indepvars(`"`core'"') controls(`"`controls_base'"')           ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
        if `spec_total' < `maxspecs' {
            local mediation_controls `"`controls_base' `mediator_first'"'
            local spec_total = `spec_total' + 1
            _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
                spec("机制-结果方程含中介") model("`model'") depvar("`depvar'") ///
                indepvars(`"`core'"') controls(`"`mediation_controls'"')     ///
                absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
            if !r(rc) local spec_success = `spec_success' + 1
            else local spec_fail = `spec_fail' + 1
        }
    }
    if strtrim(`"`moderator'"') != "" & `spec_total' < `maxspecs' {
        local moderator_first : word 1 of `moderator'
        local interaction_core "c.`core_first'##c.`moderator_first'"
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("机制-调节交互项") model("`model'") depvar("`depvar'") ///
            indepvars(`"`interaction_core'"') controls(`"`controls_base'"') ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if "`group'" != "" & `spec_total' < `maxspecs' {
        local het_core "c.`core_first'##i.`group'"
        local spec_total = `spec_total' + 1
        _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
            spec("异质性-分组交互") model("`model'") depvar("`depvar'") ///
            indepvars(`"`het_core'"') controls(`"`controls_base'"') ///
            absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
        if !r(rc) local spec_success = `spec_success' + 1
        else local spec_fail = `spec_fail' + 1
    }
    if "`hety'" != "" & strtrim(`"`hetx'"') != "" & `spec_total' < `maxspecs' {
        capture confirm variable `hety'
        if !_rc {
            local hetx_first : word 1 of `hetx'
            capture confirm variable `hetx_first'
            if !_rc {
                local spec_total = `spec_total' + 1
                _journalone_signif_one, handle(`result_post') dohandle(`do_handle') ///
                    spec("异质性-指定方程") model("`model'") depvar("`hety'") ///
                    indepvars(`"`hetx'"') controls(`"`controls_base'"')      ///
                    absorb(`"`fe'"') vcetype("`vce_clean'") cluster("`cluster'") `sample_option' panel("`panel'") time("`time'")
                if !r(rc) local spec_success = `spec_success' + 1
                else local spec_fail = `spec_fail' + 1
            }
        }
    }
    if strtrim(`"`policy' `placebo'"') != "" | "`ptrend'" != "" {
        local spec_note `"`spec_note' requested diagnostics were recorded but require an explicit design; no automatic p-value search was performed."'
    }
    postclose `result_post'
    file write `do_handle' _n "* 以上预先登记的规格估计完成；详细运行信息见同目录的审计文件。" _n
    restore
    capture datasignature
    if !_rc local sig_after `"`r(datasignature)'"'
    capture scalar drop __jo_signif_ci_level
    capture scalar drop __jo_signif_medlevel
    capture scalar drop __jo_signif_modlevel
    file close `do_handle'

    if `spec_success' == 0 {
        capture erase `"`dofile'"'
        display as error "没有成功估计的预设规格；请检查模型、变量类型和面板设定"
        exit 2000
    }

    preserve
    quietly use `result_data', clear
    generate long specification_order = .
    quietly levelsof specification, local(spec_levels)
    local spec_order = 0
    foreach this_spec of local spec_levels {
        local spec_order = `spec_order' + 1
        replace specification_order = `spec_order' if specification == `"`this_spec'"'
    }
    sort specification_order term_order
    generate str80 specification_label = specification
    generate str120 term_label = term
    generate double t_value = estimate/std_error if std_error != 0
    generate str4 significance = cond(p_value<=.01,"***",cond(p_value<=.05,"**",cond(p_value<=.10,"*",""))) if !missing(p_value)
    replace significance = "" if missing(significance)
    generate str20 expected_sign = "`expectxy'"
    replace expected_sign = "`expectxm'" if specification == "机制-中介方程"
    replace expected_sign = "`expectxy'" if specification == "机制-结果方程含中介"
    replace expected_sign = "`expectxwy'" if specification == "机制-调节交互项"
    replace expected_sign = "" if inlist(specification, "机制-调节交互项", "异质性-分组交互") & ///
        !strpos(term, "#")
    generate str20 sign_match = "未预设"
    * Direction diagnostics apply only to the focal X term or an interaction
    * containing X.  Controls, fixed-effect dummies and the intercept are not
    * hypotheses about X and therefore remain unlabelled.
    replace expected_sign = "" if term != "`core_first'" & ///
        !strpos(term, ".`core_first'") & ///
        !(strpos(term, "#") & strpos(term, "`core_first'"))
    replace sign_match = "—" if expected_sign == ""
    replace sign_match = "方向一致" if expected_sign == "促进" & estimate > 0
    replace sign_match = "方向一致" if expected_sign == "抑制" & estimate < 0
    replace sign_match = "方向相反" if expected_sign == "促进" & estimate < 0
    replace sign_match = "方向相反" if expected_sign == "抑制" & estimate > 0
    generate double ci_level = `level'
    replace ci_level = `medlevel' if strpos(specification, "机制-中介")
    replace ci_level = `modlevel' if strpos(specification, "机制-调节")
    generate str12 sig_at = "不显著"
    replace sig_at = "达到CI" if p_value <= (100-ci_level)/100 & !missing(p_value)
    generate str40 analysis_module = "显著组合"
    generate str40 run_key = `"`key'"'
    generate str20 selection_rule = "NONE"
    order analysis_module run_id run_key selection_rule specification_order specification specification_label outcome term_order term term_label estimate std_error t_value p_value ci_low ci_high ci_level N r2 r2_a expected_sign sign_match sig_at
    local csvfile `"`outdir'/`prefix'.csv"'
    local rtffile `"`outdir'/`prefix'.rtf"'
    export delimited using `"`csvfile'"', replace
    capture _journalone_write_reg_rtf, file(`"`rtffile'"') title("显著组合诊断") decimals(3) statistic("se")
    if _rc {
        display as error "RTF输出失败，CSV和DO仍已生成"
    }
    save `"`outdir'/`prefix'_specifications.dta"', replace
    local auditfile `"`outdir'/`prefix'_audit.txt"'
    tempname audit_handle
    file open `audit_handle' using `"`auditfile'"', write text replace
    file write `audit_handle' "JournalOne 显著组合诊断审计" _n
    file write `audit_handle' "selection_rule=NONE" _n
    file write `audit_handle' "run_key=`key'" _n
    file write `audit_handle' "model=`model'" _n
    file write `audit_handle' "depvar=`depvar'" _n
    file write `audit_handle' "core=`core'" _n
    file write `audit_handle' "mincontrols=`mincontrols'" _n
    file write `audit_handle' "specifications_attempted=`spec_total'" _n
    file write `audit_handle' "specifications_success=`spec_success'" _n
    file write `audit_handle' "specifications_failed=`spec_fail'" _n
    file write `audit_handle' "expected_xy=`expectxy'" _n
    file write `audit_handle' "expected_xm=`expectxm'" _n
    file write `audit_handle' "expected_xwy=`expectxwy'" _n
    file write `audit_handle' "base_level=`level'" _n
    file write `audit_handle' "mediator_level=`medlevel'" _n
    file write `audit_handle' "moderator_level=`modlevel'" _n
    file write `audit_handle' "data_signature_before=`sig_before'" _n
    if strtrim(`"`sig_after'"') != "" file write `audit_handle' "data_signature_after=`sig_after'" _n
    if strtrim(`"`spec_note'"') != "" file write `audit_handle' "note=`spec_note'" _n
    file write `audit_handle' "说明：全部预先填写且成功的规格均保留；显著性不等于因果识别。" _n
    file close `audit_handle'
    restore
    capture scalar drop __jo_signif_ci_level
    capture scalar drop __jo_signif_medlevel
    capture scalar drop __jo_signif_modlevel

    return local csv `"`csvfile'"'
    return local rtf `"`rtffile'"'
    return local do `"`dofile'"'
    return scalar specifications = `spec_total'
    return scalar successful = `spec_success'
    return scalar failed = `spec_fail'
end
