*! version 0.9.13 18aug2026
capture program drop journalone
program define journalone, eclass
    version 16.0

    if strtrim(`"`0'"') == "" {
        db journalone
        exit
    }

    _journalone_require_license

    local source_command `"journalone `0'"'

    syntax [, MODEL(string) DEPVAR(name)                        ///
          INDEPVARS(string asis) CONTROLS(string asis)          ///
          PANEL(string) TIME(string) ABSORB(string asis) TIMEFE ///
          VCETYPE(string) CLUSTER(string) IFCOND(string asis)  ///
          MODEL2(string) DEPVAR2(name) INDEPVARS2(string asis)  ///
          CONTROLS2(string asis) PANEL2(string) TIME2(string)   ///
          ABSORB2(string asis) TIMEFE2 VCETYPE2(string)         ///
          CLUSTER2(string) IFCOND2(string asis)                 ///
          MODEL3(string) DEPVAR3(name) INDEPVARS3(string asis)  ///
          CONTROLS3(string asis) PANEL3(string) TIME3(string)   ///
          ABSORB3(string asis) TIMEFE3 VCETYPE3(string)         ///
          CLUSTER3(string) IFCOND3(string asis)                 ///
          MODEL4(string) DEPVAR4(name) INDEPVARS4(string asis)  ///
          CONTROLS4(string asis) PANEL4(string) TIME4(string)   ///
          ABSORB4(string asis) TIMEFE4 VCETYPE4(string)         ///
          CLUSTER4(string) IFCOND4(string asis)                 ///
          TREAT(string) POST(string) ENDOG(string asis)         ///
          INSTRUMENTS(string asis)                              ///
          DESCVARS(varlist numeric) NODESC                      ///
          CORRVARS(varlist numeric) VIFCHECK PANELTESTS IVTESTS ///
          ALTY(string asis) ALTX(string asis)                   ///
          ADDCONTROLS(string asis) ADDFE(string asis)           ///
          LAGS(numlist integer >=0) LEADS(numlist integer >=0)  ///
          SUBSAMPLE(string asis) ALTVCE(string)                 ///
          ALTCLUSTER(string) MEDIATORS(string asis)             ///
           MODERATORS(string asis) GROUP(string)                 ///
           OUTDIR(string asis) PREFIX(name) LEVEL(cilevel)       ///
           SEED(integer 20260814) REPLACE                      ///
           DESCSAMPLE(string) REPORTMODE(string)               ///
           DECIMALS(integer 3) STATISTIC(string)               ///
           MISSINGMODE(string) PTREND PTLEVEL(real 95)         ///
           PTBASE(integer -1) GROUPBINS(integer 0) GROUPTEST   ///
           SPLITHET MEDMETHOD(string) SPLITMED MODPLOT         ///
           PSMMETHOD(string) PSMCOVARS(string asis)             ///
           PSMTIME(varname) PSMNEIGHBOR(integer 1)             ///
           HECKMANSEL(name) HECKMANCOVARS(string asis) HECKMANFE ///
           GMMMETHOD(string) GMMEXTRA(string asis)             ///
           GMMLAGS(integer 1) GMMTWOSTEP                      ///
           DMLMETHOD(string) DMLINSTRUMENTS(string asis)       ///
           DMLCONTROLS(string asis) DMLFOLDS(integer 5)        ///
           ADJUSTMETHOD(string) WINSORLOW(real 1)              ///
           WINSORHIGH(real 99) PSTAR1(real .01)                ///
           PSTAR2(real .05) PSTAR3(real .10)                  ///
           REPS(integer 1) ]

    local has_base = (strtrim("`depvar'") != "")
    local descriptive_requested = ("`nodesc'" == "")
    local diagnostics_requested = (strtrim(`"`corrvars'"') != "" | ///
        "`vifcheck'" != "" | "`paneltests'" != "" | "`ivtests'" != "")
    local standalone_desc = (`descriptive_requested' & strtrim(`"`descvars'"') != "")
    if !`has_base' & !`standalone_desc' & strtrim(`"`corrvars'"') == "" {
        display as error "未选择可运行模块：请填写描述性统计变量、相关性变量或基准回归被解释变量"
        exit 198
    }
    if !`has_base' & ("`vifcheck'" != "" | "`paneltests'" != "" | "`ivtests'" != "") {
        display as error "VIF、面板模型检验和IV诊断必须以第1组基准回归设定为基础"
        exit 198
    }

    if `has_base' & strtrim("`model'") == "" local model "ols"
    if !`has_base' local model "none"
    local model = lower(strtrim("`model'"))
    if `has_base' & !inlist("`model'", "ols", "hdfe", "fe", "re", "did", "iv") {
        display as error "model() 必须是 ols、hdfe、fe、re、did 或 iv"
        exit 198
    }
    if `has_base' & inlist("`model'", "ols", "hdfe", "fe", "re") & strtrim(`"`indepvars'"') == "" {
        display as error "模型 `model' 必须填写 indepvars()"
        exit 198
    }
    if `has_base' & inlist("`model'", "fe", "re") & ("`panel'" == "" | "`time'" == "") {
        display as error "固定/随机效应模型必须填写 panel() 和 time()"
        exit 198
    }
    if `has_base' & "`model'" == "did" & ("`treat'" == "" | "`post'" == "" | "`panel'" == "" | "`time'" == "") {
        display as error "DID 必须填写 treat()、post()、panel() 和 time()"
        exit 198
    }
    if `has_base' & "`model'" == "iv" & (strtrim(`"`endog'"') == "" | strtrim(`"`instruments'"') == "") {
        display as error "IV 必须填写 endog() 和 instruments()"
        exit 198
    }
    if `has_base' & "`paneltests'" != "" & ("`panel'" == "" | "`time'" == "") {
        display as error "面板模型选择检验必须填写第1组 panel() 和 time()"
        exit 198
    }
    if `has_base' & "`ivtests'" != "" & (strtrim(`"`endog'"') == "" | strtrim(`"`instruments'"') == "") {
        display as error "IV第一阶段诊断必须填写 endog() 和 instruments()"
        exit 198
    }

    if !`has_base' & strtrim("`depvar2' `depvar3' `depvar4'") != "" {
        display as error "多组基准回归必须先填写第1组 depvar()"
        exit 198
    }
    if "`depvar3'" != "" & "`depvar2'" == "" {
        display as error "请先填写第2组，再填写第3组基准回归"
        exit 198
    }
    if "`depvar4'" != "" & "`depvar3'" == "" {
        display as error "请先填写第3组，再填写第4组基准回归"
        exit 198
    }

    forvalues baseline_index = 2/4 {
        local baseline_depvar_name "depvar`baseline_index'"
        local baseline_model_name "model`baseline_index'"
        local baseline_indepvars_name "indepvars`baseline_index'"
        local baseline_panel_name "panel`baseline_index'"
        local baseline_time_name "time`baseline_index'"
        local baseline_vce_name "vcetype`baseline_index'"
        local baseline_cluster_name "cluster`baseline_index'"
        local baseline_depvar `"``baseline_depvar_name''"'
        if strtrim("`baseline_depvar'") != "" {
            local baseline_model `"``baseline_model_name''"'
            if strtrim("`baseline_model'") == "" local baseline_model "ols"
            local baseline_model = lower(strtrim("`baseline_model'"))
            if !inlist("`baseline_model'", "ols", "hdfe", "fe", "re", "did", "iv") {
                display as error "第`baseline_index'组 model`baseline_index'() 必须是 ols、hdfe、fe、re、did 或 iv"
                exit 198
            }

            local baseline_indepvars `"``baseline_indepvars_name''"'
            local baseline_panel `"``baseline_panel_name''"'
            local baseline_time `"``baseline_time_name''"'
            if inlist("`baseline_model'", "ols", "hdfe", "fe", "re") & strtrim(`"`baseline_indepvars'"') == "" {
                display as error "第`baseline_index'组模型必须填写 indepvars`baseline_index'()"
                exit 198
            }
            if inlist("`baseline_model'", "fe", "re") & ("`baseline_panel'" == "" | "`baseline_time'" == "") {
                display as error "第`baseline_index'组 FE/RE 必须填写 panel`baseline_index'() 和 time`baseline_index'()"
                exit 198
            }
            if "`baseline_model'" == "did" & ("`treat'" == "" | "`post'" == "" | "`baseline_panel'" == "" | "`baseline_time'" == "") {
                display as error "第`baseline_index'组 DID 需要共享的 treat()/post()，以及本组 panel`baseline_index'()/time`baseline_index'()"
                exit 198
            }
            if "`baseline_model'" == "iv" & (strtrim(`"`endog'"') == "" | strtrim(`"`instruments'"') == "") {
                display as error "第`baseline_index'组 IV 需要共享的 endog() 和 instruments()"
                exit 198
            }

            local baseline_vce `"``baseline_vce_name''"'
            if strtrim("`baseline_vce'") == "" local baseline_vce "conventional"
            local baseline_vce = lower(strtrim("`baseline_vce'"))
            if !inlist("`baseline_vce'", "conventional", "robust", "cluster") {
                display as error "第`baseline_index'组 vcetype`baseline_index'() 必须是 conventional、robust 或 cluster"
                exit 198
            }
            local baseline_cluster `"``baseline_cluster_name''"'
            if "`baseline_vce'" == "cluster" & "`baseline_cluster'" == "" {
                display as error "第`baseline_index'组聚类标准误必须填写 cluster`baseline_index'()"
                exit 198
            }
            capture confirm variable `baseline_depvar'
            if _rc {
                display as error "第`baseline_index'组被解释变量不存在：`baseline_depvar'"
                exit 111
            }
            local model`baseline_index' "`baseline_model'"
            local vcetype`baseline_index' "`baseline_vce'"
        }
    }

    if "`vcetype'" == "" local vcetype "conventional"
    local vcetype = lower(strtrim("`vcetype'"))
    if !inlist("`vcetype'", "conventional", "robust", "cluster") {
        display as error "vcetype() 必须是 conventional、robust 或 cluster"
        exit 198
    }
    if `has_base' & "`vcetype'" == "cluster" & "`cluster'" == "" {
        display as error "聚类标准误必须填写 cluster()"
        exit 198
    }
    if "`altvce'" != "" {
        local altvce = lower(strtrim("`altvce'"))
        if !inlist("`altvce'", "conventional", "robust", "cluster") {
            display as error "altvce() 必须是 conventional、robust 或 cluster"
            exit 198
        }
        if "`altvce'" == "cluster" & "`altcluster'" == "" & "`cluster'" == "" {
            display as error "替代聚类标准误必须填写 altcluster() 或 cluster()"
            exit 198
        }
    }

    if "`descsample'" == "" local descsample "main"
    local descsample = lower(strtrim("`descsample'"))
    if !inlist("`descsample'", "main", "full") {
        display as error "descsample() 必须是 main 或 full"
        exit 198
    }
    if "`reportmode'" == "" local reportmode "none"
    local reportmode = lower(strtrim("`reportmode'"))
    if !inlist("`reportmode'", "none", "docx", "docx_open") {
        display as error "reportmode() 必须是 none、docx 或 docx_open"
        exit 198
    }
    if `decimals' < 0 | `decimals' > 8 {
        display as error "decimals() 必须介于0和8之间"
        exit 198
    }
    if "`statistic'" == "" local statistic "se"
    local statistic = lower(strtrim("`statistic'"))
    if !inlist("`statistic'", "se", "t") {
        display as error "statistic() 必须是 se 或 t"
        exit 198
    }
    if "`missingmode'" == "" local missingmode "modelwise"
    local missingmode = lower(strtrim("`missingmode'"))
    if !inlist("`missingmode'", "modelwise", "preprocessed") {
        display as error "missingmode() 必须是 modelwise 或 preprocessed"
        exit 198
    }
    if "`medmethod'" == "" local medmethod "three_step"
    local medmethod = lower(strtrim("`medmethod'"))
    if !inlist("`medmethod'", "none", "three_step") {
        display as error "medmethod() 当前支持 none 或 three_step"
        exit 198
    }
    if `ptlevel' <= 50 | `ptlevel' >= 100 {
        display as error "ptlevel() 必须大于50且小于100"
        exit 198
    }
    if `groupbins' != 0 & (`groupbins' < 2 | `groupbins' > 12) {
        display as error "groupbins() 必须为0，或介于2和12之间"
        exit 198
    }
    if "`psmmethod'" == "" local psmmethod "none"
    local psmmethod = lower(strtrim("`psmmethod'"))
    if !inlist("`psmmethod'", "none", "nearest", "radius", "kernel") {
        display as error "psmmethod() 必须是 none、nearest、radius 或 kernel"
        exit 198
    }
    if `psmneighbor' < 1 | `psmneighbor' > 20 {
        display as error "psmneighbor() 必须介于1和20之间"
        exit 198
    }
    if "`gmmmethod'" == "" local gmmmethod "none"
    local gmmmethod = lower(strtrim("`gmmmethod'"))
    if !inlist("`gmmmethod'", "none", "difference", "system") {
        display as error "gmmmethod() 必须是 none、difference 或 system"
        exit 198
    }
    if `gmmlags' < 1 | `gmmlags' > 5 {
        display as error "gmmlags() 必须介于1和5之间"
        exit 198
    }
    if "`dmlmethod'" == "" local dmlmethod "none"
    local dmlmethod = lower(strtrim("`dmlmethod'"))
    if !inlist("`dmlmethod'", "none", "partial", "iv") {
        display as error "dmlmethod() 必须是 none、partial 或 iv"
        exit 198
    }
    if `dmlfolds' < 2 | `dmlfolds' > 20 {
        display as error "dmlfolds() 必须介于2和20之间"
        exit 198
    }
    if "`adjustmethod'" == "" local adjustmethod "none"
    local adjustmethod = lower(strtrim("`adjustmethod'"))
    if !inlist("`adjustmethod'", "none", "winsor") {
        display as error "adjustmethod() 必须是 none 或 winsor"
        exit 198
    }
    if `winsorlow' <= 0 | `winsorlow' >= 50 | `winsorhigh' <= 50 | `winsorhigh' >= 100 | `winsorlow' >= `winsorhigh' {
        display as error "winsorlow()/winsorhigh() 必须满足0<low<50<high<100"
        exit 198
    }
    if `reps' < 1 | `reps' > 100 {
        display as error "reps() 必须介于1和100之间"
        exit 198
    }
    if `pstar1' <= 0 | `pstar1' >= `pstar2' | `pstar2' >= `pstar3' | `pstar3' >= 1 {
        display as error "显著性阈值必须满足 0<pstar1()<pstar2()<pstar3()<1"
        exit 198
    }

    if `has_base' {
        capture confirm variable `depvar'
        if _rc {
            display as error "被解释变量不存在：`depvar'"
            exit 111
        }
    }
    if c(N) == 0 {
        display as error "当前数据集没有观测值"
        exit 2000
    }

    local source_datafile `"`c(filename)'"'
    if strtrim(`"`source_datafile'"') == "" local source_datafile "数据.dta"

    * string asis preserves command-line quotes; Windows paths cannot contain
    * a literal quote, so normalize optional surrounding quotes here.
    local outdir = subinstr(strtrim(`"`outdir'"'), char(34), "", .)
    if "`outdir'" == "" local outdir "实证分析结果"
    if "`prefix'" == "" local prefix "journalone"
    capture mkdir `"`outdir'"'

    * Remove the four legacy root-level artifacts previously written by this
    * same prefix.  Fixed module folders below remain untouched.
    foreach legacy_pattern in "`prefix'_*.log" "`prefix'_*_audit.txt" ///
        "`prefix'_*_descriptive.csv" "`prefix'_*_descriptive.dta" {
        local legacy_files : dir `"`outdir'"' files "`legacy_pattern'"
        foreach legacy_file of local legacy_files {
            capture erase `"`outdir'/`legacy_file'"'
        }
    }
    capture confirm file `"`outdir'/__journalone_write_test.tmp"'

    local rundate = subinstr("`c(current_date)'", " ", "", .)
    local runtime = subinstr("`c(current_time)'", ":", "", .)
    local runtime = subinstr("`runtime'", ".", "", .)
    local runid "`prefix'_`rundate'_`runtime'"
    local resultbase `"`outdir'/`runid'"'
    * Fixed per-module publication folders live directly under outdir().
    * Run-specific working files are temporary and are not exposed beside them.
    local package_dir `"`outdir'"'

    set seed `seed'
    capture log close journalone_log
    tempfile journalone_run_log
    log using `"`journalone_run_log'"', text replace name(journalone_log)
    noisily display as text "期刊实证分析 | run_id=`runid'"
    if `has_base' noisily display as text "模型=`model'  被解释变量=`depvar'"
    else noisily display as text "模块=仅描述性统计"
    noisily display as text "说明：自动化结果不替代识别假设、变量口径与因果解释审查。"

    local signature_vars ""
    capture unab signature_vars : _all
    local sig_before ""
    capture quietly datasignature
    if !_rc local sig_before "`r(datasignature)'"
    local raw_n = c(N)

    if !`has_base' {
        local standalone_status "PASS"
        local standalone_modules ""
        local standalone_descriptive ""
        local standalone_descriptive_dta ""
        local standalone_report ""
        local standalone_package `"`package_dir'"'
        local standalone_package_dirs ""
        local standalone_descriptive_dir ""
        local standalone_rtf_files ""
        local standalone_do_files ""
        local standalone_csv_files ""
        local standalone_descriptive_rtf ""
        local standalone_descriptive_do ""
        local standalone_pack_csv ""
        local standalone_diagnostics_dir ""
        local standalone_diagnostics_rtf ""
        local standalone_diagnostics_do ""
        local standalone_diagnostics_csv ""
        local standalone_diagnostics_dta ""
        local standalone_count = 0
        local standalone_warnings = 0

        if `standalone_desc' {
            capture noisily journalone_descriptive_only,                   ///
                resultbase(`"`resultbase'"') runid("`runid'")           ///
                descvars(`descvars') ifcond(`"`ifcond'"') rawn(`raw_n')  ///
                sigbefore("`sig_before'") missingmode("`missingmode'")   ///
                reportmode("`reportmode'") decimals(`decimals')          ///
                statistic("`statistic'") pstar1(`pstar1') pstar2(`pstar2') ///
                pstar3(`pstar3') packagedir(`"`package_dir'"')            ///
                sourcecommand(`"`source_command'"') datafile(`"`source_datafile'"')
            local descriptive_only_rc = _rc
            if `descriptive_only_rc' {
                capture log close journalone_log
                exit `descriptive_only_rc'
            }
            local standalone_status "`r(status)'"
            local standalone_modules "descriptive"
            local standalone_descriptive `"`r(descriptive_file)'"'
            local standalone_descriptive_dta `"`r(descriptive_dta)'"'
            local standalone_report `"`r(report_file)'"'
            local standalone_package `"`r(package_dir)'"'
            local standalone_package_dirs `"`r(package_dirs)'"'
            local standalone_descriptive_dir `"`r(descriptive_dir)'"'
            local standalone_rtf_files `"`r(rtf_files)'"'
            local standalone_do_files `"`r(do_files)'"'
            local standalone_csv_files `"`r(csv_files)'"'
            local standalone_descriptive_rtf `"`r(descriptive_rtf)'"'
            local standalone_descriptive_do `"`r(descriptive_do)'"'
            local standalone_pack_csv `"`r(descriptive_package_csv)'"'
            local standalone_count = r(descriptive_count)
            local standalone_warnings = r(warnings)
        }

        if strtrim(`"`corrvars'"') != "" {
            capture noisily journalone_diagnostics,                        ///
                resultbase(`"`resultbase'"') runid("`runid'")           ///
                packagedir(`"`package_dir'"') datafile(`"`source_datafile'"') ///
                corrvars(`corrvars') ifcond(`"`ifcond'"')                 ///
                decimals(`decimals') pstar1(`pstar1') pstar2(`pstar2')    ///
                pstar3(`pstar3')
            local diagnostics_only_rc = _rc
            if `diagnostics_only_rc' {
                capture log close journalone_log
                exit `diagnostics_only_rc'
            }
            local standalone_modules = strtrim(`"`standalone_modules' diagnostics"')
            local standalone_diagnostics_dir `"`r(diagnostics_dir)'"'
            local standalone_diagnostics_rtf `"`r(diagnostics_rtf)'"'
            local standalone_diagnostics_do `"`r(diagnostics_do)'"'
            local standalone_diagnostics_csv `"`r(diagnostics_csv)'"'
            local standalone_diagnostics_dta `"`r(diagnostics_dta)'"'
            local standalone_package_dirs = strtrim(`"`standalone_package_dirs' `standalone_diagnostics_dir'"')
            local standalone_rtf_files = strtrim(`"`standalone_rtf_files' `standalone_diagnostics_rtf'"')
            local standalone_do_files = strtrim(`"`standalone_do_files' `standalone_diagnostics_do'"')
            local standalone_csv_files = strtrim(`"`standalone_csv_files' `standalone_diagnostics_csv'"')
            local standalone_warnings = `standalone_warnings' + r(warnings)
        }

        local standalone_status "PASS"
        if `standalone_warnings' > 0 local standalone_status "PASS_WITH_WARNINGS"
        local standalone_sig_after ""
        capture quietly datasignature
        if !_rc local standalone_sig_after "`r(datasignature)'"
        noisily display as result "正式结果文件（点击文件名打开）："
        if strtrim(`"`standalone_descriptive_rtf'"') != "" {
            noisily display in smcl `"  {stata journalone_open using "`standalone_descriptive_rtf'":描述性统计分析.rtf}"'
            noisily display in smcl `"  {stata journalone_open using "`standalone_descriptive_do'":描述性统计分析.do}"'
            noisily display in smcl `"  {stata journalone_open using "`standalone_pack_csv'":描述性统计分析.csv}"'
        }
        if strtrim(`"`standalone_diagnostics_rtf'"') != "" {
            noisily display in smcl `"  {stata journalone_open using "`standalone_diagnostics_rtf'":相关性与模型诊断.rtf}"'
            noisily display in smcl `"  {stata journalone_open using "`standalone_diagnostics_do'":相关性与模型诊断.do}"'
            noisily display in smcl `"  {stata journalone_open using "`standalone_diagnostics_csv'":相关性与模型诊断.csv}"'
        }
        capture log close journalone_log
        ereturn clear
        ereturn local journalone_runid "`runid'"
        ereturn local journalone_status "`standalone_status'"
        ereturn local journalone_modules "`standalone_modules'"
        ereturn local journalone_results ""
        ereturn local journalone_results_dta ""
        ereturn local journalone_descriptive `"`standalone_descriptive'"'
        ereturn local journalone_descriptive_dta `"`standalone_descriptive_dta'"'
        ereturn local journalone_report `"`standalone_report'"'
        ereturn local journalone_package_dir `"`standalone_package'"'
        ereturn local journalone_package_dirs `"`standalone_package_dirs'"'
        ereturn local journalone_descriptive_dir `"`standalone_descriptive_dir'"'
        ereturn local journalone_rtf_files `"`standalone_rtf_files'"'
        ereturn local journalone_do_files `"`standalone_do_files'"'
        ereturn local journalone_module_csv_files `"`standalone_csv_files'"'
        ereturn local journalone_descriptive_rtf `"`standalone_descriptive_rtf'"'
        ereturn local journalone_descriptive_do `"`standalone_descriptive_do'"'
        ereturn local journalone_descriptive_csv `"`standalone_pack_csv'"'
        ereturn local journalone_diagnostics_dir `"`standalone_diagnostics_dir'"'
        ereturn local journalone_diagnostics_rtf `"`standalone_diagnostics_rtf'"'
        ereturn local journalone_diagnostics_do `"`standalone_diagnostics_do'"'
        ereturn local journalone_diagnostics_csv `"`standalone_diagnostics_csv'"'
        ereturn local journalone_diagnostics_dta `"`standalone_diagnostics_dta'"'
        ereturn local journalone_parallel_test ""
        ereturn local journalone_group_test ""
        ereturn local journalone_moderation_files ""
        ereturn scalar journalone_models = 0
        ereturn scalar journalone_warnings = `standalone_warnings'
        ereturn scalar journalone_descriptive_variables = `standalone_count'
        exit
    }

    tempfile coefficient_data
    tempname result_post
    postfile `result_post' str40 run_id str48 specification str32 outcome  ///
        double term_order str96 term                                      ///
        double estimate std_error p_value ci_low ci_high N r2 r2_a        ///
        using `coefficient_data', replace

    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"
    local timefeopt2 ""
    if "`timefe2'" != "" local timefeopt2 "timefe"
    local timefeopt3 ""
    if "`timefe3'" != "" local timefeopt3 "timefe"
    local timefeopt4 ""
    if "`timefe4'" != "" local timefeopt4 "timefe"
    local warnings = 0
    local models_success = 0
    local descriptive_status "SKIPPED"
    local descriptive_count = 0
    local descriptive_n = .
    local descriptive_file ""
    local descriptive_dta ""
    local report_file ""
    local parallel_test_file ""
    local group_test_file ""
    local moderation_files ""
    local package_output_dir ""
    local package_output_dirs ""
    local rtf_files ""
    local do_files ""
    local module_csv_files ""
    local diagnostics_dir ""
    local diagnostics_rtf ""
    local diagnostics_do ""
    local diagnostics_csv ""
    local diagnostics_dta ""
    local diagnostics_sections = 0
    foreach module_stub in descriptive baseline robustness endogeneity mechanism heterogeneity {
        local `module_stub'_dir ""
        local `module_stub'_rtf ""
        local `module_stub'_do ""
        local `module_stub'_package_csv ""
    }
    local modules_run "baseline"
    if "`nodesc'" == "" local modules_run "descriptive `modules_run'"
    if strtrim(`"`alty' `altx' `addcontrols' `addfe' `lags' `leads' `subsample' `altvce'"') != "" | "`adjustmethod'" == "winsor" {
        local modules_run "`modules_run' robustness"
    }
    if "`model'" == "iv" | "`psmmethod'" != "none" | "`heckmansel'" != "" | "`gmmmethod'" != "none" | "`dmlmethod'" != "none" {
        local modules_run "`modules_run' endogeneity"
    }
    if strtrim(`"`mediators' `moderators'"') != "" local modules_run "`modules_run' mechanism"
    if "`group'" != "" | `groupbins' > 0 | "`grouptest'" != "" local modules_run "`modules_run' heterogeneity"
    if `diagnostics_requested' local modules_run "`modules_run' diagnostics"
    local modules_run = strtrim(`"`modules_run'"')

    _journalone_run_spec, handle(`result_post') runid("`runid'")      ///
        spec("main") model("`model'") depvar("`depvar'")            ///
        indepvars(`"`indepvars'"') controls(`"`controls'"')          ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')        ///
        vcetype("`vcetype'") cluster("`cluster'")                   ///
        treat("`treat'") postvar("`post'") endog(`"`endog'"')      ///
        instruments(`"`instruments'"') ifcond(`"`ifcond'"')         ///
        level(`level') `timefeopt'
    local main_rc = r(rc)
    if `main_rc' != 0 {
        postclose `result_post'
        capture log close journalone_log
        display as error "基准模型估计失败，未生成成功结果；返回码 `main_rc'"
        exit `main_rc'
    }
    local ++models_success
    estimates store journalone_main
    estimates save `"`resultbase'_main.ster"', replace

    * Additional baseline columns are independent models; later modules still use model 1.
    forvalues baseline_index = 2/4 {
        local baseline_depvar_name "depvar`baseline_index'"
        local baseline_model_name "model`baseline_index'"
        local baseline_indepvars_name "indepvars`baseline_index'"
        local baseline_controls_name "controls`baseline_index'"
        local baseline_panel_name "panel`baseline_index'"
        local baseline_time_name "time`baseline_index'"
        local baseline_absorb_name "absorb`baseline_index'"
        local baseline_vce_name "vcetype`baseline_index'"
        local baseline_cluster_name "cluster`baseline_index'"
        local baseline_ifcond_name "ifcond`baseline_index'"
        local baseline_timefeopt_name "timefeopt`baseline_index'"
        local baseline_depvar `"``baseline_depvar_name''"'
        if strtrim("`baseline_depvar'") != "" {
            local baseline_model `"``baseline_model_name''"'
            local baseline_indepvars `"``baseline_indepvars_name''"'
            local baseline_controls `"``baseline_controls_name''"'
            local baseline_panel `"``baseline_panel_name''"'
            local baseline_time `"``baseline_time_name''"'
            local baseline_absorb `"``baseline_absorb_name''"'
            local baseline_vce `"``baseline_vce_name''"'
            local baseline_cluster `"``baseline_cluster_name''"'
            local baseline_ifcond `"``baseline_ifcond_name''"'
            local baseline_timefeopt `"``baseline_timefeopt_name''"'

            _journalone_run_spec, handle(`result_post') runid("`runid'")       ///
                spec("baseline_`baseline_index'") model("`baseline_model'") ///
                depvar("`baseline_depvar'") indepvars(`"`baseline_indepvars'"') ///
                controls(`"`baseline_controls'"') panel("`baseline_panel'") ///
                time("`baseline_time'") absorb(`"`baseline_absorb'"')       ///
                vcetype("`baseline_vce'") cluster("`baseline_cluster'")    ///
                treat("`treat'") postvar("`post'") endog(`"`endog'"')    ///
                instruments(`"`instruments'"') ifcond(`"`baseline_ifcond'"') ///
                level(`level') `baseline_timefeopt'
            local baseline_rc = r(rc)
            if `baseline_rc' != 0 {
                postclose `result_post'
                capture log close journalone_log
                display as error "第`baseline_index'组基准模型估计失败；返回码 `baseline_rc'"
                exit `baseline_rc'
            }
            local ++models_success
            estimates store journalone_base`baseline_index'
            estimates save `"`resultbase'_baseline`baseline_index'.ster"', replace
        }
    }
    estimates restore journalone_main

    * Publication-ready descriptive statistics for the frozen main estimation sample.
    if "`nodesc'" == "" {
        local descriptive_use `"`descvars'"'
        if strtrim(`"`descriptive_use'"') == "" {
            local descriptive_candidates `"`depvar' `indepvars' `endog' `treat' `post' `controls' `instruments' `mediators' `moderators' `group'"'
            local descriptive_use ""
            foreach descriptive_candidate of local descriptive_candidates {
                capture confirm numeric variable `descriptive_candidate'
                if !_rc & !strpos(" `descriptive_use' ", " `descriptive_candidate' ") {
                    local descriptive_use "`descriptive_use' `descriptive_candidate'"
                }
            }
        }
        local descriptive_use = strtrim(`"`descriptive_use'"')

        if strtrim(`"`descriptive_use'"') == "" {
            noisily display as error "没有可用于描述性统计的普通数值变量；已跳过"
            local descriptive_status "SKIPPED_NO_NUMERIC_VARIABLES"
            local ++warnings
        }
        else {
            local descriptive_if "if e(sample)"
            if "`descsample'" == "full" {
                local descriptive_if ""
                if strtrim(`"`ifcond'"') != "" local descriptive_if `"if `ifcond'"'
            }
            quietly count `descriptive_if'
            local descriptive_n = r(N)
            tempfile descriptive_data
            tempname descriptive_post
            postfile `descriptive_post' str40 run_id double variable_order              ///
                str24 variable_role str32 variable str244 variable_label                 ///
                double N_total N_nonmissing N_missing mean sd min max ///
                using `descriptive_data', replace

            local descriptive_order = 0
            foreach descriptive_var of local descriptive_use {
                local ++descriptive_order
                local descriptive_role "additional"
                if "`descriptive_var'" == "`depvar'" {
                    local descriptive_role "dependent"
                }
                else if strpos(" `indepvars' ", " `descriptive_var' ") {
                    local descriptive_role "core"
                }
                else if strpos(" `endog' ", " `descriptive_var' ") {
                    local descriptive_role "endogenous_core"
                }
                else if "`descriptive_var'" == "`treat'" | "`descriptive_var'" == "`post'" {
                    local descriptive_role "did_core"
                }
                else if strpos(" `controls' ", " `descriptive_var' ") {
                    local descriptive_role "control"
                }
                else if strpos(" `instruments' ", " `descriptive_var' ") {
                    local descriptive_role "instrument"
                }
                else if strpos(" `mediators' ", " `descriptive_var' ") {
                    local descriptive_role "mediator"
                }
                else if strpos(" `moderators' ", " `descriptive_var' ") {
                    local descriptive_role "moderator"
                }
                else if "`descriptive_var'" == "`group'" {
                    local descriptive_role "group"
                }
                quietly summarize `descriptive_var' `descriptive_if'
                local descriptive_nonmissing = r(N)
                local descriptive_missing = `descriptive_n' - `descriptive_nonmissing'
                local descriptive_label : variable label `descriptive_var'
                if strtrim(`"`descriptive_label'"') == "" local descriptive_label "`descriptive_var'"
                post `descriptive_post' ("`runid'") (`descriptive_order')              ///
                    ("`descriptive_role'") ("`descriptive_var'") (`"`descriptive_label'"') ///
                    (`descriptive_n') (`descriptive_nonmissing') (`descriptive_missing') ///
                    (r(mean)) (r(sd)) (r(min)) (r(max))
                local ++descriptive_count
            }
            postclose `descriptive_post'

            preserve
            quietly use `descriptive_data', clear
            sort variable_order
            save `"`resultbase'_descriptive.dta"', replace
            export delimited using `"`resultbase'_descriptive.csv"', replace
            clonevar N = N_nonmissing
            clonevar Missing = N_missing
            format variable %-24s
            format N Missing %12.0fc
            format mean sd min max %14.`decimals'f
            local original_linesize = c(linesize)
            quietly set linesize 255
            noisily display as text "描述性统计（基准估计样本）"
            noisily list variable N Missing mean sd min max, ///
                noobs separator(0) abbreviate(24)
            quietly set linesize `original_linesize'
            restore
            estimates restore journalone_main
            local descriptive_status "PASS"
            local descriptive_file `"`resultbase'_descriptive.csv"'
            local descriptive_dta `"`resultbase'_descriptive.dta"'
        }
    }

    foreach y2 of local alty {
        _journalone_run_spec, handle(`result_post') runid("`runid'")  ///
            spec("alt_y_`y2'") model("`model'") depvar("`y2'")      ///
            indepvars(`"`indepvars'"') controls(`"`controls'"')     ///
            panel("`panel'") time("`time'") absorb(`"`absorb'"')   ///
            vcetype("`vcetype'") cluster("`cluster'")              ///
            treat("`treat'") postvar("`post'") endog(`"`endog'"') ///
            instruments(`"`instruments'"') ifcond(`"`ifcond'"')    ///
            level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    foreach x2 of local altx {
        _journalone_run_spec, handle(`result_post') runid("`runid'")  ///
            spec("alt_x_`x2'") model("`model'") depvar("`depvar'") ///
            indepvars("`x2'") controls(`"`controls'"')              ///
            panel("`panel'") time("`time'") absorb(`"`absorb'"')   ///
            vcetype("`vcetype'") cluster("`cluster'")              ///
            treat("`treat'") postvar("`post'") endog(`"`endog'"') ///
            instruments(`"`instruments'"') ifcond(`"`ifcond'"')    ///
            level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    if strtrim(`"`addcontrols'"') != "" {
        _journalone_run_spec, handle(`result_post') runid("`runid'")     ///
            spec("additional_controls") model("`model'")                ///
            depvar("`depvar'") indepvars(`"`indepvars'"')               ///
            controls(`"`controls' `addcontrols'"') panel("`panel'")     ///
            time("`time'") absorb(`"`absorb'"') vcetype("`vcetype'")   ///
            cluster("`cluster'") treat("`treat'") postvar("`post'")   ///
            endog(`"`endog'"') instruments(`"`instruments'"')          ///
            ifcond(`"`ifcond'"') level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    if strtrim(`"`addfe'"') != "" {
        _journalone_run_spec, handle(`result_post') runid("`runid'")   ///
            spec("additional_fe") model("`model'") depvar("`depvar'") ///
            indepvars(`"`indepvars'"') controls(`"`controls'"')       ///
            panel("`panel'") time("`time'")                           ///
            absorb(`"`absorb' `addfe'"') vcetype("`vcetype'")        ///
            cluster("`cluster'") treat("`treat'") postvar("`post'") ///
            endog(`"`endog'"') instruments(`"`instruments'"')        ///
            ifcond(`"`ifcond'"') level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    if strtrim(`"`subsample'"') != "" {
        local combined_if `"`subsample'"'
        if strtrim(`"`ifcond'"') != "" local combined_if `"(`ifcond') & (`subsample')"'
        _journalone_run_spec, handle(`result_post') runid("`runid'") ///
            spec("subsample") model("`model'") depvar("`depvar'")  ///
            indepvars(`"`indepvars'"') controls(`"`controls'"')     ///
            panel("`panel'") time("`time'") absorb(`"`absorb'"')  ///
            vcetype("`vcetype'") cluster("`cluster'")             ///
            treat("`treat'") postvar("`post'") endog(`"`endog'"') ///
            instruments(`"`instruments'"') ifcond(`"`combined_if'"') ///
            level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    local firstx : word 1 of `indepvars'
    local restx : list indepvars - firstx
    if (strtrim("`lags'") != "" | strtrim("`leads'") != "") {
        if "`firstx'" == "" | "`panel'" == "" | "`time'" == "" {
            noisily display as error "滞后/超前稳健性需要普通解释变量以及 panel()、time()；已跳过"
            local ++warnings
        }
        else {
            capture quietly xtset `panel' `time'
            if _rc {
                noisily display as error "xtset 失败，滞后/超前稳健性已跳过"
                local ++warnings
            }
            else {
                if strtrim("`lags'") != "" {
                  foreach lag of numlist `lags' {
                    if `lag' > 0 {
                        _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                            spec("lag_`lag'") model("`model'") depvar("`depvar'") ///
                            indepvars("L`lag'.`firstx' `restx'") controls(`"`controls'"') ///
                            panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                            vcetype("`vcetype'") cluster("`cluster'") treat("`treat'") ///
                            postvar("`post'") endog(`"`endog'"') instruments(`"`instruments'"') ///
                            ifcond(`"`ifcond'"') level(`level') `timefeopt'
                        if r(rc) local ++warnings
                        else local ++models_success
                    }
                  }
                }
                if strtrim("`leads'") != "" {
                  foreach lead of numlist `leads' {
                    if `lead' > 0 {
                        _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                            spec("lead_`lead'") model("`model'") depvar("`depvar'") ///
                            indepvars("F`lead'.`firstx' `restx'") controls(`"`controls'"') ///
                            panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                            vcetype("`vcetype'") cluster("`cluster'") treat("`treat'") ///
                            postvar("`post'") endog(`"`endog'"') instruments(`"`instruments'"') ///
                            ifcond(`"`ifcond'"') level(`level') `timefeopt'
                        if r(rc) local ++warnings
                        else local ++models_success
                    }
                  }
                }
            }
        }
    }

    if "`altvce'" != "" & "`altvce'" != "`vcetype'" {
        local use_altcluster "`altcluster'"
        if "`use_altcluster'" == "" local use_altcluster "`cluster'"
        _journalone_run_spec, handle(`result_post') runid("`runid'") ///
            spec("alternative_vce") model("`model'") depvar("`depvar'") ///
            indepvars(`"`indepvars'"') controls(`"`controls'"') panel("`panel'") ///
            time("`time'") absorb(`"`absorb'"') vcetype("`altvce'") ///
            cluster("`use_altcluster'") treat("`treat'") postvar("`post'") ///
            endog(`"`endog'"') instruments(`"`instruments'"') ifcond(`"`ifcond'"') ///
            level(`level') `timefeopt'
        if r(rc) local ++warnings
        else local ++models_success
    }

    if strtrim(`"`mediators'"') != "" & "`medmethod'" != "none" {
        if !inlist("`model'", "ols", "fe", "re") {
            noisily display as error "中介关联模块仅支持 OLS/FE/RE；当前模型已跳过"
            local ++warnings
        }
        else {
            foreach mediator of local mediators {
                _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                    spec("med_a_`mediator'") model("`model'") depvar("`mediator'") ///
                    indepvars(`"`indepvars'"') controls(`"`controls'"') panel("`panel'") ///
                    time("`time'") absorb(`"`absorb'"') vcetype("`vcetype'") ///
                    cluster("`cluster'") ifcond(`"`ifcond'"') level(`level') `timefeopt'
                if r(rc) local ++warnings
                else local ++models_success
                _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                    spec("med_b_`mediator'") model("`model'") depvar("`depvar'") ///
                    indepvars(`"`indepvars'"') controls(`"`controls' `mediator'"') ///
                    panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                    vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') ///
                    level(`level') `timefeopt'
                if r(rc) local ++warnings
                else local ++models_success
            }
        }
    }

    if strtrim(`"`moderators'"') != "" {
        capture confirm variable `firstx'
        if _rc | !inlist("`model'", "ols", "fe", "re") {
            noisily display as error "调节模块需要首个解释变量为普通数值变量，且模型为 OLS/FE/RE；已跳过"
            local ++warnings
        }
        else {
            foreach moderator of local moderators {
                _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                    spec("moderator_`moderator'") model("`model'") depvar("`depvar'") ///
                    indepvars("c.`firstx'##c.`moderator' `restx'") controls(`"`controls'"') ///
                    panel("`panel'") time("`time'") absorb(`"`absorb'"') ///
                    vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') ///
                    level(`level') `timefeopt'
                if r(rc) local ++warnings
                else local ++models_success
            }
        }
    }

    if "`group'" != "" {
        capture confirm numeric variable `group'
        if _rc {
            noisily display as error "分组变量目前必须是数值型分类变量；已跳过异质性分析"
            local ++warnings
        }
        else {
            local levelif ""
            if strtrim(`"`ifcond'"') != "" local levelif `"if `ifcond'"'
            capture quietly levelsof `group' `levelif', local(group_levels)
            if _rc {
                local ++warnings
            }
            else {
                local group_count : word count `group_levels'
                if `group_count' > 12 {
                    noisily display as error "分组变量有 `group_count' 个取值（上限12）；已跳过，避免机械拆分"
                    local ++warnings
                }
                else {
                    foreach group_value of local group_levels {
                        local group_if "`group' == `group_value'"
                        if strtrim(`"`ifcond'"') != "" local group_if `"(`ifcond') & (`group_if')"'
                        _journalone_run_spec, handle(`result_post') runid("`runid'") ///
                            spec("group_`group'_`group_value'") model("`model'") depvar("`depvar'") ///
                            indepvars(`"`indepvars'"') controls(`"`controls'"') panel("`panel'") ///
                            time("`time'") absorb(`"`absorb'"') vcetype("`vcetype'") ///
                            cluster("`cluster'") treat("`treat'") postvar("`post'") ///
                            endog(`"`endog'"') instruments(`"`instruments'"') ///
                            ifcond(`"`group_if'"') level(`level') `timefeopt'
                        if r(rc) local ++warnings
                        else local ++models_success
                    }
                }
            }
        }
    }

    capture noisily journalone_extra, handle(`result_post') runid("`runid'") ///
        resultbase(`"`resultbase'"') model("`model'") depvar("`depvar'")    ///
        indepvars(`"`indepvars'"') controls(`"`controls'"')                 ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')              ///
        vcetype("`vcetype'") cluster("`cluster'") treat("`treat'")       ///
        postvar("`post'") endog(`"`endog'"') instruments(`"`instruments'"') ///
        ifcond(`"`ifcond'"') level(`level') seed(`seed')                    ///
        psmmethod("`psmmethod'") psmcovars(`"`psmcovars'"')                ///
        psmtime("`psmtime'") psmneighbor(`psmneighbor')                     ///
        heckmansel("`heckmansel'") heckmancovars(`"`heckmancovars'"')     ///
        `heckmanfe'                                                          ///
        gmmmethod("`gmmmethod'") gmmextra(`"`gmmextra'"')                  ///
        gmmlags(`gmmlags') `gmmtwostep' dmlmethod("`dmlmethod'")           ///
        dmlinstruments(`"`dmlinstruments'"') dmlcontrols(`"`dmlcontrols'"') ///
        dmlfolds(`dmlfolds') `ptrend' ptlevel(`ptlevel') ptbase(`ptbase')   ///
        group("`group'") groupbins(`groupbins') `grouptest' `modplot'      ///
        moderators(`"`moderators'"') adjustmethod("`adjustmethod'")       ///
        winsorlow(`winsorlow') winsorhigh(`winsorhigh') reps(`reps')       ///
        `timefeopt'
    local extra_rc = _rc
    if `extra_rc' {
        noisily display as error "高级扩展模块调度失败，返回码 `extra_rc'；基准结果仍保留"
        local ++warnings
    }
    else {
        local extra_models = r(models)
        local extra_warnings = r(warnings)
        local models_success = `models_success' + `extra_models'
        local warnings = `warnings' + `extra_warnings'
        local parallel_test_file `"`r(parallel_test_file)'"'
        local group_test_file `"`r(group_test_file)'"'
        local moderation_files `"`r(moderation_files)'"'
    }

    postclose `result_post'
    estimates restore journalone_main
    local main_n = e(N)
    local main_r2 = .
    capture local main_r2 = e(r2)
    if missing(`main_r2') capture local main_r2 = e(r2_w)

    local cluster_count = .
    if "`cluster'" != "" {
        preserve
        quietly keep if e(sample)
        tempvar cluster_tag
        quietly egen byte `cluster_tag' = tag(`cluster')
        quietly count if `cluster_tag'
        local cluster_count = r(N)
        restore
    }

    if `diagnostics_requested' {
        local corrvarsopt ""
        if strtrim(`"`corrvars'"') != "" local corrvarsopt "corrvars(`corrvars')"
        capture noisily journalone_diagnostics,                          ///
            resultbase(`"`resultbase'"') runid("`runid'")             ///
            packagedir(`"`package_dir'"') datafile(`"`source_datafile'"') ///
            `corrvarsopt' `vifcheck' `paneltests' `ivtests'              ///
            depvar("`depvar'") indepvars(`"`indepvars'"')              ///
            controls(`"`controls'"') panel("`panel'") time("`time'") ///
            absorb(`"`absorb'"') ifcond(`"`ifcond'"')                  ///
            endog(`"`endog'"') instruments(`"`instruments'"')          ///
            vcetype("`vcetype'") cluster("`cluster'")                 ///
            decimals(`decimals') pstar1(`pstar1') pstar2(`pstar2')      ///
            pstar3(`pstar3') `timefeopt'
        local diagnostics_rc = _rc
        if `diagnostics_rc' {
            noisily display as error "相关性与模型诊断生成失败，返回码 `diagnostics_rc'；其他模块结果仍保留"
            local ++warnings
        }
        else {
            local diagnostics_dir `"`r(diagnostics_dir)'"'
            local diagnostics_rtf `"`r(diagnostics_rtf)'"'
            local diagnostics_do `"`r(diagnostics_do)'"'
            local diagnostics_csv `"`r(diagnostics_csv)'"'
            local diagnostics_dta `"`r(diagnostics_dta)'"'
            local diagnostics_sections = r(successful_sections)
            local warnings = `warnings' + r(warnings)
        }
        estimates restore journalone_main
    }

    local sig_after ""
    preserve
    capture quietly keep `signature_vars'
    capture quietly datasignature
    if !_rc local sig_after "`r(datasignature)'"
    restore
    if "`sig_before'" != "" & "`sig_after'" != "" & "`sig_before'" != "`sig_after'" {
        local ++warnings
    }

    preserve
    quietly use `coefficient_data', clear
    generate long __posted_order = _n
    bysort specification: egen long __specification_first = min(__posted_order)
    egen long specification_order = group(__specification_first)
    drop __posted_order __specification_first
    order run_id specification_order specification outcome term_order term
    sort specification_order term_order
    save `"`resultbase'_results.dta"', replace
    export delimited using `"`resultbase'_results.csv"', replace
    noisily list specification outcome term estimate std_error p_value N r2 ///
        if specification == "main", noobs abbreviate(24)
    restore

    capture noisily journalone_format_outputs,                              ///
        results(`"`resultbase'_results.dta"')                              ///
        descriptive(`"`descriptive_dta'"') resultbase(`"`resultbase'"')   ///
        decimals(`decimals') statistic("`statistic'")                      ///
        pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3')                 ///
        reportmode("`reportmode'") `splithet' `splitmed'
    local format_rc = _rc
    if `format_rc' {
        noisily display as error "格式化输出失败，返回码 `format_rc'；原始DTA/CSV仍保留"
        local ++warnings
    }
    else {
        local report_file `"`r(report_file)'"'
    }

    capture noisily journalone_publish_outputs,                           ///
        packagedir(`"`package_dir'"') runid("`runid'")                 ///
        sourcecommand(`"`source_command'"') datafile(`"`source_datafile'"') ///
        results(`"`resultbase'_results.dta"')                            ///
        descriptive(`"`descriptive_dta'"') model("`model'")            ///
        depvar("`depvar'") indepvars(`"`indepvars'"') controls(`"`controls'"') ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')          ///
        vcetype("`vcetype'") cluster("`cluster'") treat("`treat'")   ///
        model2("`model2'") depvar2("`depvar2'") indepvars2(`"`indepvars2'"') ///
        controls2(`"`controls2'"') panel2("`panel2'") time2("`time2'") ///
        absorb2(`"`absorb2'"') vcetype2("`vcetype2'") cluster2("`cluster2'") ///
        ifcond2(`"`ifcond2'"') model3("`model3'") depvar3("`depvar3'") ///
        indepvars3(`"`indepvars3'"') controls3(`"`controls3'"') panel3("`panel3'") ///
        time3("`time3'") absorb3(`"`absorb3'"') vcetype3("`vcetype3'") ///
        cluster3("`cluster3'") ifcond3(`"`ifcond3'"') model4("`model4'") ///
        depvar4("`depvar4'") indepvars4(`"`indepvars4'"') controls4(`"`controls4'"') ///
        panel4("`panel4'") time4("`time4'") absorb4(`"`absorb4'"') ///
        vcetype4("`vcetype4'") cluster4("`cluster4'") ifcond4(`"`ifcond4'"') ///
        postvar("`post'") endog(`"`endog'"') instruments(`"`instruments'"') ///
        ifcond(`"`ifcond'"') descsample("`descsample'")                ///
        alty(`"`alty'"') altx(`"`altx'"') addcontrols(`"`addcontrols'"') ///
        addfe(`"`addfe'"') lags("`lags'") leads("`leads'")           ///
        subsample(`"`subsample'"') altvce("`altvce'")                 ///
        altcluster("`altcluster'") mediators(`"`mediators'"')         ///
        moderators(`"`moderators'"') group("`group'")                 ///
        psmmethod("`psmmethod'") psmcovars(`"`psmcovars'"')           ///
        psmtime("`psmtime'") psmneighbor(`psmneighbor')                 ///
        heckmansel("`heckmansel'") heckmancovars(`"`heckmancovars'"') ///
        gmmmethod("`gmmmethod'") gmmextra(`"`gmmextra'"')             ///
        gmmlags(`gmmlags') dmlmethod("`dmlmethod'")                    ///
        dmlinstruments(`"`dmlinstruments'"') dmlcontrols(`"`dmlcontrols'"') ///
        dmlfolds(`dmlfolds') reps(`reps') seed(`seed')                  ///
        adjustmethod("`adjustmethod'") winsorlow(`winsorlow')          ///
        winsorhigh(`winsorhigh') ptbase(`ptbase') groupbins(`groupbins') ///
        level(`level') decimals(`decimals') statistic("`statistic'")   ///
        pstar1(`pstar1') pstar2(`pstar2') pstar3(`pstar3')              ///
        `timefeopt' `timefe2' `timefe3' `timefe4' `heckmanfe' `gmmtwostep' `ptrend' `grouptest'
    local package_rc = _rc
    if `package_rc' {
        noisily display as error "三件套结果包生成失败，返回码 `package_rc'；原始结果仍保留"
        local ++warnings
    }
    else {
        local package_warnings = r(warnings)
        local package_output_dir `"`r(package_dir)'"'
        local package_output_dirs `"`r(package_dirs)'"'
        local rtf_files `"`r(rtf_files)'"'
        local do_files `"`r(do_files)'"'
        local module_csv_files `"`r(csv_files)'"'
        foreach module_stub in descriptive baseline robustness endogeneity mechanism heterogeneity {
            local `module_stub'_dir `"`r(`module_stub'_dir)'"'
            local `module_stub'_rtf `"`r(`module_stub'_rtf)'"'
            local `module_stub'_do `"`r(`module_stub'_do)'"'
            local `module_stub'_package_csv `"`r(`module_stub'_csv)'"'
        }
        local warnings = `warnings' + `package_warnings'
    }

    if strtrim(`"`diagnostics_dir'"') != "" {
        local package_output_dirs = strtrim(`"`package_output_dirs' `diagnostics_dir'"')
        local rtf_files = strtrim(`"`rtf_files' `diagnostics_rtf'"')
        local do_files = strtrim(`"`do_files' `diagnostics_do'"')
        local module_csv_files = strtrim(`"`module_csv_files' `diagnostics_csv'"')
    }

    local overall "PASS"
    if `warnings' > 0 local overall "PASS_WITH_WARNINGS"

    * The official descriptive CSV already lives in its named module folder.
    * Remove the redundant run-ID CSV/DTA working pair from the output root.
    if strtrim(`"`descriptive_file'"') != "" capture erase `"`descriptive_file'"'
    if strtrim(`"`descriptive_dta'"') != "" capture erase `"`descriptive_dta'"'
    local descriptive_file `"`descriptive_package_csv'"'
    local descriptive_dta ""

    noisily display as result "运行完成：`overall'"
    noisily display as text "结果：`resultbase'_results.csv"
    if "`descriptive_file'" != "" noisily display as text "描述性统计：`descriptive_file'"
    if "`report_file'" != "" noisily display as text "Word报告：`report_file'"
    if "`diagnostics_dir'" != "" noisily display as text "相关性与模型诊断：`diagnostics_dir'"
    if "`package_output_dirs'" != "" noisily display as result "期刊三件套结果文件夹：`package_output_dirs'"
    noisily display as result "正式结果文件（点击文件名打开）："
    foreach module_stub in descriptive baseline robustness endogeneity mechanism heterogeneity {
        local module_title ""
        if "`module_stub'" == "descriptive" local module_title "描述性统计分析"
        if "`module_stub'" == "baseline" local module_title "基准回归分析"
        if "`module_stub'" == "robustness" local module_title "稳健性检验"
        if "`module_stub'" == "endogeneity" local module_title "内生性检验"
        if "`module_stub'" == "mechanism" local module_title "机制检验"
        if "`module_stub'" == "heterogeneity" local module_title "异质性分析"
        local module_rtf `"``module_stub'_rtf'"'
        local module_do `"``module_stub'_do'"'
        local module_csv `"``module_stub'_package_csv'"'
        if strtrim(`"`module_rtf'"') != "" {
            noisily display in smcl `"  {stata journalone_open using "`module_rtf'":`module_title'.rtf}"'
            noisily display in smcl `"  {stata journalone_open using "`module_do'":`module_title'.do}"'
            noisily display in smcl `"  {stata journalone_open using "`module_csv'":`module_title'.csv}"'
        }
    }
    if strtrim(`"`diagnostics_rtf'"') != "" {
        noisily display in smcl `"  {stata journalone_open using "`diagnostics_rtf'":相关性与模型诊断.rtf}"'
        noisily display in smcl `"  {stata journalone_open using "`diagnostics_do'":相关性与模型诊断.do}"'
        noisily display in smcl `"  {stata journalone_open using "`diagnostics_csv'":相关性与模型诊断.csv}"'
    }
    capture log close journalone_log

    estimates restore journalone_main
    forvalues baseline_index = 2/4 {
        capture estimates drop journalone_base`baseline_index'
    }
    capture estimates drop journalone_main
    ereturn local journalone_runid "`runid'"
    ereturn local journalone_status "`overall'"
    ereturn local journalone_modules "`modules_run'"
    ereturn local journalone_results `"`resultbase'_results.csv"'
    ereturn local journalone_results_dta `"`resultbase'_results.dta"'
    ereturn local journalone_descriptive `"`descriptive_file'"'
    ereturn local journalone_descriptive_dta `"`descriptive_dta'"'
    ereturn local journalone_report `"`report_file'"'
    ereturn local journalone_package_dir `"`package_output_dir'"'
    ereturn local journalone_package_dirs `"`package_output_dirs'"'
    ereturn local journalone_rtf_files `"`rtf_files'"'
    ereturn local journalone_do_files `"`do_files'"'
    ereturn local journalone_module_csv_files `"`module_csv_files'"'
    foreach module_stub in descriptive baseline robustness endogeneity mechanism heterogeneity {
        ereturn local journalone_`module_stub'_dir `"``module_stub'_dir'"'
        ereturn local journalone_`module_stub'_rtf `"``module_stub'_rtf'"'
        ereturn local journalone_`module_stub'_do `"``module_stub'_do'"'
        ereturn local journalone_`module_stub'_csv `"``module_stub'_package_csv'"'
    }
    ereturn local journalone_parallel_test `"`parallel_test_file'"'
    ereturn local journalone_group_test `"`group_test_file'"'
    ereturn local journalone_moderation_files `"`moderation_files'"'
    ereturn local journalone_diagnostics_dir `"`diagnostics_dir'"'
    ereturn local journalone_diagnostics_rtf `"`diagnostics_rtf'"'
    ereturn local journalone_diagnostics_do `"`diagnostics_do'"'
    ereturn local journalone_diagnostics_csv `"`diagnostics_csv'"'
    ereturn local journalone_diagnostics_dta `"`diagnostics_dta'"'
    ereturn scalar journalone_diagnostics_sections = `diagnostics_sections'
    ereturn scalar journalone_models = `models_success'
    ereturn scalar journalone_warnings = `warnings'
    ereturn scalar journalone_descriptive_variables = `descriptive_count'
end


capture program drop _journalone_run_spec
program define _journalone_run_spec, rclass
    version 16.0
    syntax , HANDLE(name) RUNID(string) SPEC(string) MODEL(string)       ///
        DEPVAR(string) [ INDEPVARS(string) CONTROLS(string)           ///
        PANEL(string) TIME(string) ABSORB(string) TIMEFE               ///
        VCETYPE(string) CLUSTER(string) TREAT(string) POSTVAR(string)  ///
        ENDOG(string) INSTRUMENTS(string) IFCOND(string)               ///
        LEVEL(real 95) ]

    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"
    capture noisily _journalone_fit, model("`model'") depvar("`depvar'") ///
        indepvars(`"`indepvars'"') controls(`"`controls'"')            ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')          ///
        vcetype("`vcetype'") cluster("`cluster'")                     ///
        treat("`treat'") postvar("`postvar'") endog(`"`endog'"')     ///
        instruments(`"`instruments'"') ifcond(`"`ifcond'"') `timefeopt'
    local rc = _rc
    if `rc' {
        noisily display as error "规格 `spec' 失败，返回码 `rc'"
        return scalar rc = `rc'
        exit
    }
    _journalone_post_current, handle(`handle') runid("`runid'") ///
        spec("`spec'") outcome("`depvar'") level(`level')
    return scalar rc = 0
end


capture program drop _journalone_fit
program define _journalone_fit, eclass
    version 16.0
    syntax , MODEL(string) DEPVAR(string)                              ///
        [ INDEPVARS(string) CONTROLS(string)                           ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE             ///
          VCETYPE(string) CLUSTER(string) TREAT(string)               ///
          POSTVAR(string) ENDOG(string) INSTRUMENTS(string)            ///
          IFCOND(string) ]

    local ifqual ""
    if strtrim(`"`ifcond'"') != "" local ifqual `"if `ifcond'"'

    local fe_terms ""
    foreach fevar of local absorb {
        local fe_terms "`fe_terms' i.`fevar'"
    }
    local time_terms ""
    if "`timefe'" != "" {
        if "`time'" == "" {
            display as error "timefe 需要 time()"
            exit 198
        }
        local time_terms "i.`time'"
    }

    local vceopt ""
    if "`vcetype'" == "robust" local vceopt "vce(robust)"
    else if "`vcetype'" == "cluster" {
        if "`cluster'" == "" {
            display as error "cluster VCE 需要 cluster()"
            exit 198
        }
        local vceopt "vce(cluster `cluster')"
    }
    else if "`vcetype'" != "conventional" {
        display as error "未知 VCE：`vcetype'"
        exit 198
    }

    if "`panel'" != "" {
        if "`time'" != "" quietly xtset `panel' `time'
        else quietly xtset `panel'
    }

    if "`model'" == "ols" {
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        regress `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `comma'
    }
    else if "`model'" == "hdfe" {
        local hdfe_absorb = strtrim(`"`absorb'"')
        if "`timefe'" != "" & !strpos(" `hdfe_absorb' ", " `time' ") {
            local hdfe_absorb = strtrim("`hdfe_absorb' `time'")
        }
        local hdfe_absorbopt "noabsorb"
        if strtrim(`"`hdfe_absorb'"') != "" local hdfe_absorbopt "absorb(`hdfe_absorb')"
        local hdfe_options ", `hdfe_absorbopt'"
        if "`vceopt'" != "" local hdfe_options "`hdfe_options' `vceopt'"
        reghdfe `depvar' `indepvars' `controls' `ifqual' `hdfe_options'
    }
    else if "`model'" == "fe" {
        local opts ", fe"
        if "`vceopt'" != "" local opts "`opts' `vceopt'"
        xtreg `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `opts'
    }
    else if "`model'" == "re" {
        local opts ", re"
        if "`vceopt'" != "" local opts "`opts' `vceopt'"
        xtreg `depvar' `indepvars' `controls' `fe_terms' `time_terms' `ifqual' `opts'
    }
    else if "`model'" == "did" {
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        regress `depvar' i.`treat'##i.`postvar' `indepvars' `controls' ///
            i.`panel' i.`time' `fe_terms' `ifqual' `comma'
    }
    else if "`model'" == "iv" {
        local comma ""
        if "`vceopt'" != "" local comma ", `vceopt'"
        ivregress 2sls `depvar' `indepvars' `controls' `fe_terms' `time_terms' ///
            (`endog' = `instruments') `ifqual' `comma'
    }
end


capture program drop _journalone_post_current
program define _journalone_post_current
    version 16.0
    syntax , HANDLE(name) RUNID(string) SPEC(string) OUTCOME(string) [LEVEL(real 95)]

    tempname bmat vmat
    matrix `bmat' = e(b)
    matrix `vmat' = e(V)
    local terms : colfullnames `bmat'
    local columns = colsof(`bmat')

    scalar __jo_n = e(N)
    scalar __jo_df = .
    capture scalar __jo_df = e(df_r)
    scalar __jo_r2 = .
    capture scalar __jo_r2 = e(r2)
    if missing(__jo_r2) capture scalar __jo_r2 = e(r2_w)
    scalar __jo_r2_a = .
    capture scalar __jo_r2_a = e(r2_a)
    if missing(__jo_r2_a) capture scalar __jo_r2_a = e(r2_a_within)
    scalar __jo_tail = (100-`level')/200

    forvalues column = 1/`columns' {
        local term : word `column' of `terms'
        scalar __jo_beta = `bmat'[1,`column']
        scalar __jo_se = sqrt(`vmat'[`column',`column'])
        scalar __jo_stat = cond(__jo_se>0, __jo_beta/__jo_se, .)
        if missing(__jo_df) {
            scalar __jo_p = 2*normal(-abs(__jo_stat))
            scalar __jo_crit = invnormal(1-__jo_tail)
        }
        else {
            scalar __jo_p = 2*ttail(__jo_df, abs(__jo_stat))
            scalar __jo_crit = invttail(__jo_df, __jo_tail)
        }
        scalar __jo_low = __jo_beta - __jo_crit*__jo_se
        scalar __jo_high = __jo_beta + __jo_crit*__jo_se
        post `handle' ("`runid'") ("`spec'") ("`outcome'") (`column') ("`term'") ///
            (__jo_beta) (__jo_se) (__jo_p) (__jo_low) (__jo_high) (__jo_n) (__jo_r2) (__jo_r2_a)
    }
end
