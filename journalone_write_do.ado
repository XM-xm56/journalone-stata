*! version 0.8.0 15aug2026

capture program drop journalone_write_do
program define journalone_write_do, rclass
    version 16.0
    _journalone_require_license
    syntax , FILE(string) TITLE(string) MODULE(string) RUNID(string)     ///
        [ SOURCECOMMAND(string) DATAFILE(string) OUTPUTDIR(string)      ///
          MODEL(string) DEPVAR(string) INDEPVARS(string) CONTROLS(string) ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE              ///
          VCETYPE(string) CLUSTER(string) TREAT(string)                 ///
          MODEL2(string) DEPVAR2(string) INDEPVARS2(string) CONTROLS2(string) ///
          PANEL2(string) TIME2(string) ABSORB2(string) TIMEFE2          ///
          VCETYPE2(string) CLUSTER2(string) IFCOND2(string)            ///
          MODEL3(string) DEPVAR3(string) INDEPVARS3(string) CONTROLS3(string) ///
          PANEL3(string) TIME3(string) ABSORB3(string) TIMEFE3          ///
          VCETYPE3(string) CLUSTER3(string) IFCOND3(string)            ///
          MODEL4(string) DEPVAR4(string) INDEPVARS4(string) CONTROLS4(string) ///
          PANEL4(string) TIME4(string) ABSORB4(string) TIMEFE4          ///
          VCETYPE4(string) CLUSTER4(string) IFCOND4(string)            ///
          POSTVAR(string) ENDOG(string) INSTRUMENTS(string)             ///
          IFCOND(string) DESCVARS(string) DESCSAMPLE(string)            ///
          SPECS(string) ALTY(string) ALTX(string) ADDCONTROLS(string)   ///
          ADDFE(string) LAGS(string) LEADS(string) SUBSAMPLE(string)    ///
          ALTVCE(string) ALTCLUSTER(string) MEDIATORS(string)           ///
          MODERATORS(string) GROUP(string) PSMMETHOD(string)            ///
          PSMCOVARS(string) PSMTIME(string)                              ///
          PSMNEIGHBOR(integer 1) HECKMANSEL(string)                     ///
          HECKMANCOVARS(string) HECKMANFE GMMMETHOD(string)             ///
          GMMEXTRA(string) GMMLAGS(integer 1) GMMTWOSTEP                ///
          DMLMETHOD(string) DMLINSTRUMENTS(string)                      ///
          DMLCONTROLS(string) DMLFOLDS(integer 5)                       ///
          REPS(integer 1) SEED(integer 20260814)                        ///
          ADJUSTMETHOD(string) WINSORLOW(real 1) WINSORHIGH(real 99)   ///
          PTREND PTBASE(integer -1) GROUPBINS(integer 0) GROUPTEST     ///
          DECIMALS(integer 3) STATISTIC(string) LEVEL(real 95)         ///
          PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10) ]

    local module = lower(strtrim("`module'"))
    if "`model'" == "" local model "ols"
    if "`vcetype'" == "" local vcetype "conventional"
    forvalues baseline_index = 2/4 {
        local baseline_model_name "model`baseline_index'"
        local baseline_vce_name "vcetype`baseline_index'"
        local baseline_model `"``baseline_model_name''"'
        local baseline_vce `"``baseline_vce_name''"'
        if "`baseline_model'" == "" local model`baseline_index' "ols"
        if "`baseline_vce'" == "" local vcetype`baseline_index' "conventional"
    }
    if "`descsample'" == "" local descsample "main"
    if "`statistic'" == "" local statistic "se"
    if "`datafile'" == "" local datafile "数据.dta"
    if "`outputdir'" == "" local outputdir "."
    local datafile = subinstr(`"`datafile'"', "\", "/", .)
    local outputdir = subinstr(`"`outputdir'"', "\", "/", .)
    local workdir = subinstr(`"`c(pwd)'"', "\", "/", .)
    local rtf_file `"`outputdir'/`title'.rtf"'
    local csv_file `"`outputdir'/`title'.csv"'
    local txt_file `"`outputdir'/`title'.txt"'

    * Use one readable control-variable macro when the active baseline columns
    * share a control set, including the common case in which model 1 has none.
    local macro_controls `"`controls'"'
    if "`module'" == "baseline" & strtrim(`"`macro_controls'"') == "" {
        local candidate_controls ""
        local controls_consistent = 1
        forvalues baseline_index = 2/4 {
            local candidate_depvar_name "depvar`baseline_index'"
            local candidate_controls_name "controls`baseline_index'"
            local candidate_depvar `"``candidate_depvar_name''"'
            local this_candidate_controls `"``candidate_controls_name''"'
            if strtrim(`"`candidate_depvar'"') != "" & ///
                strtrim(`"`this_candidate_controls'"') != "" {
                if strtrim(`"`candidate_controls'"') == "" {
                    local candidate_controls `"`this_candidate_controls'"'
                }
                else if strtrim(`"`candidate_controls'"') != ///
                    strtrim(`"`this_candidate_controls'"') local controls_consistent = 0
            }
        }
        if `controls_consistent' local macro_controls `"`candidate_controls'"'
    }

    tempname do_handle
    file open `do_handle' using `"`file'"', write text replace
    file write `do_handle' "**数据导入**" _n
    file write `do_handle' `"cd "`workdir'"    // 原分析工作目录"' _n
    file write `do_handle' `"use "`datafile'", clear    // 导入分析数据"' _n
    file write `do_handle' "" _n
    file write `do_handle' "**变量设定**" _n
    if "`depvar'" != "" file write `do_handle' "* 被解释变量：`depvar'" _n
    if strtrim(`"`indepvars'"') != "" file write `do_handle' "* 核心解释变量：`indepvars'" _n
    if strtrim(`"`endog'"') != "" file write `do_handle' "* 内生解释变量：`endog'" _n
    if strtrim(`"`instruments'"') != "" file write `do_handle' "* 工具变量：`instruments'" _n
    if strtrim(`"`macro_controls'"') != "" {
        file write `do_handle' `"global controls "`macro_controls'"    // 控制变量，后续回归使用 "' _char(36) "controls" _n
    }
    if "`panel'" != "" file write `do_handle' "* 个体/企业ID：`panel'" _n
    if "`time'" != "" file write `do_handle' "* 时间变量：`time'" _n
    if strtrim(`"`absorb'"') != "" file write `do_handle' "* 固定效应：`absorb'" _n
    if "`cluster'" != "" file write `do_handle' "* 聚类变量：`cluster'" _n
    if "`treat'" != "" file write `do_handle' "* 处理组变量：`treat'" _n
    if "`postvar'" != "" file write `do_handle' "* 政策后变量：`postvar'" _n
    if strtrim(`"`ifcond'"') != "" file write `do_handle' "* 样本条件：`ifcond'" _n
    forvalues baseline_index = 2/4 {
        local baseline_depvar_name "depvar`baseline_index'"
        local baseline_model_name "model`baseline_index'"
        local baseline_indepvars_name "indepvars`baseline_index'"
        local baseline_controls_name "controls`baseline_index'"
        local baseline_absorb_name "absorb`baseline_index'"
        local baseline_ifcond_name "ifcond`baseline_index'"
        local baseline_depvar `"``baseline_depvar_name''"'
        if strtrim("`baseline_depvar'") != "" {
            local baseline_model `"``baseline_model_name''"'
            local baseline_indepvars `"``baseline_indepvars_name''"'
            local baseline_controls `"``baseline_controls_name''"'
            local baseline_absorb `"``baseline_absorb_name''"'
            local baseline_ifcond `"``baseline_ifcond_name''"'
            file write `do_handle' "* 模型`baseline_index'：`baseline_model'；被解释变量：`baseline_depvar'" _n
            if strtrim(`"`baseline_indepvars'"') != "" file write `do_handle' "* 模型`baseline_index'核心解释变量：`baseline_indepvars'" _n
            if strtrim(`"`baseline_controls'"') != "" file write `do_handle' "* 模型`baseline_index'控制变量：`baseline_controls'" _n
            if strtrim(`"`baseline_absorb'"') != "" file write `do_handle' "* 模型`baseline_index'固定效应：`baseline_absorb'" _n
            if strtrim(`"`baseline_ifcond'"') != "" file write `do_handle' "* 模型`baseline_index'样本条件：`baseline_ifcond'" _n
        }
    }
    if "`panel'" != "" {
        if "`time'" != "" file write `do_handle' "xtset `panel' `time'" _n
        else file write `do_handle' "xtset `panel'" _n
    }
    file write `do_handle' "" _n

    if "`module'" == "descriptive" {
        file write `do_handle' "**描述性统计分析**" _n
        local descriptive_if ""
        local descriptive_sample_created = 0
        if "`descsample'" == "full" {
            if strtrim(`"`ifcond'"') != "" local descriptive_if "if `ifcond'"
        }
        else if "`depvar'" != "" & "`model'" != "none" {
            _journalone_do_build_command, model("`model'") depvar("`depvar'") ///
                indepvars(`"`indepvars'"') controls(`"`controls'"')         ///
                panel("`panel'") time("`time'") absorb(`"`absorb'"')     ///
                vcetype("`vcetype'") cluster("`cluster'")                 ///
                treat("`treat'") postvar("`postvar'") endog(`"`endog'"') ///
                instruments(`"`instruments'"') ifcond(`"`ifcond'"') `timefe'
            local sample_command `"`r(command)'"'
            file write `do_handle' "* 先复现基准模型，用 e(sample) 固定描述性统计样本" _n
            file write `do_handle' "quietly `sample_command'" _n
            file write `do_handle' "generate byte sample_baseline = e(sample)    // 固定基准回归样本" _n
            local descriptive_if "if sample_baseline"
            local descriptive_sample_created = 1
        }
        else if strtrim(`"`ifcond'"') != "" local descriptive_if "if `ifcond'"

        local descriptive_clause ""
        if "`descriptive_if'" != "" local descriptive_clause " `descriptive_if'"
        file write `do_handle' `"tabstat `descvars'`descriptive_clause', statistics(N mean sd min max) format(%12.`decimals'f) columns(statistics)    // 按被解释变量、核心解释变量、控制变量的设定顺序统计"' _n
        file write `do_handle' "" _n
        file write `do_handle' "**结果导出**" _n
        file write `do_handle' `"logout, save("`rtf_file'") word replace: tabstat `descvars'`descriptive_clause', statistics(N mean sd min max) format(%12.`decimals'f) columns(statistics)"' _n
        file write `do_handle' `"capture erase "`txt_file'"    // logout同时生成的文本底稿不保留"' _n
        file write `do_handle' `"estpost tabstat `descvars'`descriptive_clause', statistics(N mean sd min max) columns(statistics)"' _n
        file write `do_handle' `"esttab using "`csv_file'", replace cells("count(fmt(0)) mean(fmt(`decimals')) sd(fmt(`decimals')) min(fmt(`decimals')) max(fmt(`decimals'))") nonumber nomtitle noobs"' _n
        if `descriptive_sample_created' file write `do_handle' "drop sample_baseline" _n
        file close `do_handle'
        return local file `"`file'"'
        return scalar models = 0
        exit
    }

    local section_title "`title'"
    if "`module'" == "baseline" local section_title "基准回归"
    file write `do_handle' "***实证分析部分***" _n
    file write `do_handle' "**`section_title'**" _n
    file write `do_handle' "*表1 `section_title'结果" _n
    file write `do_handle' "est clear" _n
    local model_index = 0
    local stored ""
    local stored_specs ""
    local exportable = 1
    local timefeopt ""
    if "`timefe'" != "" local timefeopt "timefe"

    if "`module'" == "baseline" {
        local ++model_index
        _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
            comment("基准回归：按界面设定加入核心变量、控制变量及固定效应") ///
            model("`model'") depvar("`depvar'") indepvars(`"`indepvars'"') ///
            controls(`"`controls'"') panel("`panel'") time("`time'")       ///
            absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
            treat("`treat'") postvar("`postvar'") endog(`"`endog'"')     ///
            instruments(`"`instruments'"') ifcond(`"`ifcond'"') `timefeopt' controlsmacro
        local stored "m`model_index'"
        local stored_specs "main"

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
            local baseline_timefe_name "timefe`baseline_index'"
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
                local baseline_timefe ""
                local baseline_timefe_value `"``baseline_timefe_name''"'
                if "`baseline_timefe_value'" != "" local baseline_timefe "timefe"
                local baseline_controlsmacro ""
                if strtrim(`"`baseline_controls'"') == strtrim(`"`macro_controls'"') & ///
                    strtrim(`"`macro_controls'"') != "" local baseline_controlsmacro "controlsmacro"

                if "`baseline_panel'" != "" {
                    if "`baseline_time'" != "" file write `do_handle' "xtset `baseline_panel' `baseline_time'" _n
                    else file write `do_handle' "xtset `baseline_panel'" _n
                }
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("基准回归模型`baseline_index'")                      ///
                    model("`baseline_model'") depvar("`baseline_depvar'")      ///
                    indepvars(`"`baseline_indepvars'"') controls(`"`baseline_controls'"') ///
                    panel("`baseline_panel'") time("`baseline_time'")          ///
                    absorb(`"`baseline_absorb'"') vcetype("`baseline_vce'")  ///
                    cluster("`baseline_cluster'") treat("`treat'")             ///
                    postvar("`postvar'") endog(`"`endog'"')                    ///
                    instruments(`"`instruments'"') ifcond(`"`baseline_ifcond'"') ///
                    `baseline_timefe' `baseline_controlsmacro'
                local stored "`stored' m`model_index'"
                local stored_specs "`stored_specs' baseline_`baseline_index'"
            }
        }
    }

    else if "`module'" == "robustness" {
        local firstx : word 1 of `indepvars'
        local restx : list indepvars - firstx
        local event_variables_created = 0
        foreach specification of local specs {
            local this_y "`depvar'"
            local this_x `"`indepvars'"'
            local this_controls `"`controls'"'
            local this_absorb `"`absorb'"'
            local this_vce "`vcetype'"
            local this_cluster "`cluster'"
            local this_if `"`ifcond'"'
            local comment "稳健性规格：`specification'"

            if substr("`specification'",1,6) == "alt_y_" {
                local this_y = substr("`specification'",7,.)
                local comment "替换被解释变量为 `this_y'"
            }
            else if substr("`specification'",1,6) == "alt_x_" {
                local this_x = substr("`specification'",7,.)
                local comment "替换核心解释变量为 `this_x'"
            }
            else if "`specification'" == "additional_controls" {
                local this_controls `"`controls' `addcontrols'"'
                local comment "增加控制变量"
            }
            else if "`specification'" == "additional_fe" {
                local this_absorb `"`absorb' `addfe'"'
                local comment "增加固定效应"
            }
            else if "`specification'" == "subsample" {
                local this_if `"`subsample'"'
                if strtrim(`"`ifcond'"') != "" local this_if `"(`ifcond') & (`subsample')"'
                local comment "替代样本检验"
            }
            else if substr("`specification'",1,4) == "lag_" {
                local period = substr("`specification'",5,.)
                local this_x `"L`period'.`firstx' `restx'"'
                local comment "核心解释变量滞后`period'期"
            }
            else if substr("`specification'",1,5) == "lead_" {
                local period = substr("`specification'",6,.)
                local this_x `"F`period'.`firstx' `restx'"'
                local comment "核心解释变量超前`period'期"
            }
            else if "`specification'" == "alternative_vce" {
                local this_vce "`altvce'"
                local this_cluster "`altcluster'"
                if "`this_cluster'" == "" local this_cluster "`cluster'"
                local comment "替换标准误估计方式"
            }

            local this_controlsmacro ""
            if strtrim(`"`this_controls'"') == strtrim(`"`controls'"') & ///
                strtrim(`"`controls'"') != "" local this_controlsmacro "controlsmacro"

            if "`specification'" == "parallel_trend" {
                local event_variables_created = 1
                file write `do_handle' "* 平行趋势事件研究：根据处理组首次进入政策后时期构造相对时间" _n
                local policy_if "`treat'==1 & `postvar'==1"
                if strtrim(`"`ifcond'"') != "" local policy_if "(`ifcond') & (`policy_if')"
                file write `do_handle' "summarize `time' if `policy_if', meanonly" _n
                file write `do_handle' "scalar __jo_policy_time = r(min)" _n
                file write `do_handle' "capture drop __jo_event_time __jo_event_index" _n
                file write `do_handle' "generate double __jo_event_time = `time' - scalar(__jo_policy_time)" _n
                file write `do_handle' "summarize __jo_event_time, meanonly" _n
                file write `do_handle' "scalar __jo_event_min = r(min)" _n
                file write `do_handle' "generate long __jo_event_index = __jo_event_time - scalar(__jo_event_min)" _n
                file write `do_handle' "local __jo_base_index = `ptbase' - scalar(__jo_event_min)" _n
                file write `do_handle' "fvset base " _char(96) "__jo_base_index" _char(39) " __jo_event_index    // 将相对期`ptbase'设为基期" _n
                local event_vce ""
                if "`vcetype'" == "robust" local event_vce ", vce(robust)"
                if "`vcetype'" == "cluster" local event_vce ", vce(cluster `cluster')"
                local event_fe_terms "i.`panel' i.`time'"
                foreach fevar of local absorb {
                    if "`fevar'" != "`panel'" & "`fevar'" != "`time'" {
                        local event_fe_terms "`event_fe_terms' i.`fevar'"
                    }
                }
                local event_if ""
                if strtrim(`"`ifcond'"') != "" local event_if "if `ifcond'"
                file write `do_handle' "regress `depvar' i.__jo_event_index#1.`treat' `indepvars' `controls' `event_fe_terms' `event_if' `event_vce'" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
                local stored "`stored' m`model_index'"
                local stored_specs "`stored_specs' `specification'"
            }
            else if substr("`specification'",1,7) == "winsor_" {
                file write `do_handle' "* 分位缩尾稳健性：使用内置centile，不改动原变量" _n
                file write `do_handle' "preserve" _n
                local winsor_y "__jo_wy"
                file write `do_handle' "centile `depvar', centile(`winsorlow' `winsorhigh')" _n
                file write `do_handle' "generate double `winsor_y' = min(max(`depvar',r(c_1)),r(c_2)) if !missing(`depvar')" _n
                local winsor_x ""
                local winsor_number = 0
                foreach variable of local indepvars {
                    local ++winsor_number
                    local newvar "__jo_wx`winsor_number'"
                    file write `do_handle' "centile `variable', centile(`winsorlow' `winsorhigh')" _n
                    file write `do_handle' "generate double `newvar' = min(max(`variable',r(c_1)),r(c_2)) if !missing(`variable')" _n
                    local winsor_x "`winsor_x' `newvar'"
                }
                local winsor_controls ""
                local winsor_number = 0
                foreach variable of local controls {
                    local ++winsor_number
                    local newvar "__jo_wc`winsor_number'"
                    file write `do_handle' "centile `variable', centile(`winsorlow' `winsorhigh')" _n
                    file write `do_handle' "generate double `newvar' = min(max(`variable',r(c_1)),r(c_2)) if !missing(`variable')" _n
                    local winsor_controls "`winsor_controls' `newvar'"
                }
                _journalone_do_build_command, model("`model'") depvar("`winsor_y'") ///
                    indepvars(`"`winsor_x'"') controls(`"`winsor_controls'"')       ///
                    panel("`panel'") time("`time'") absorb(`"`absorb'"')         ///
                    vcetype("`vcetype'") cluster("`cluster'") treat("`treat'")   ///
                    postvar("`postvar'") ifcond(`"`ifcond'"') `timefeopt'
                file write `do_handle' `"`r(command)'    // 缩尾后重新估计"' _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n
                file write `do_handle' "restore" _n _n
                local stored "`stored' m`model_index'"
                local stored_specs "`stored_specs' `specification'"
            }
            else {
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("`comment'") model("`model'") depvar("`this_y'")       ///
                    indepvars(`"`this_x'"') controls(`"`this_controls'"')          ///
                    panel("`panel'") time("`time'") absorb(`"`this_absorb'"')    ///
                    vcetype("`this_vce'") cluster("`this_cluster'")               ///
                    treat("`treat'") postvar("`postvar'") endog(`"`endog'"')    ///
                    instruments(`"`instruments'"') ifcond(`"`this_if'"')       ///
                    `timefeopt' `this_controlsmacro'
                local stored "`stored' m`model_index'"
                local stored_specs "`stored_specs' `specification'"
            }
        }
        if `event_variables_created' {
            file write `do_handle' "capture drop __jo_event_time __jo_event_index    // 清理事件研究临时变量" _n
            file write `do_handle' "capture scalar drop __jo_policy_time __jo_event_min" _n _n
        }
    }

    else if "`module'" == "mechanism" {
        local firstx : word 1 of `indepvars'
        local restx : list indepvars - firstx
        foreach specification of local specs {
            if substr("`specification'",1,6) == "med_a_" {
                local mediator = substr("`specification'",7,.)
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("机制路径A：核心变量对中介变量 `mediator' 的影响")       ///
                    model("`model'") depvar("`mediator'") indepvars(`"`indepvars'"') ///
                    controls(`"`controls'"') panel("`panel'") time("`time'")       ///
                    absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                    ifcond(`"`ifcond'"') `timefeopt' controlsmacro
            }
            else if substr("`specification'",1,6) == "med_b_" {
                local mediator = substr("`specification'",7,.)
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("机制路径B：在结果方程中加入中介变量 `mediator'")       ///
                    model("`model'") depvar("`depvar'") indepvars(`"`indepvars'"') ///
                    controls(`"`controls' `mediator'"') panel("`panel'") time("`time'") ///
                    absorb(`"`absorb'"') vcetype("`vcetype'") cluster("`cluster'") ///
                    ifcond(`"`ifcond'"') `timefeopt'
            }
            else if substr("`specification'",1,10) == "moderator_" {
                local moderator = substr("`specification'",11,.)
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("调节效应：核心变量与 `moderator' 的交互项")             ///
                    model("`model'") depvar("`depvar'")                           ///
                    indepvars(`"c.`firstx'##c.`moderator' `restx'"') controls(`"`controls'"') ///
                    panel("`panel'") time("`time'") absorb(`"`absorb'"')         ///
                    vcetype("`vcetype'") cluster("`cluster'") ifcond(`"`ifcond'"') ///
                    `timefeopt' controlsmacro
            }
            local stored "`stored' m`model_index'"
            local stored_specs "`stored_specs' `specification'"
        }
    }

    else if "`module'" == "heterogeneity" {
        local quantile_ready = 0
        foreach specification of local specs {
            local this_if ""
            local comment "异质性分组：`specification'"
            if substr("`specification'",1,6) == "group_" &             ///
                substr("`specification'",1,15) != "group_quantile_" {
                local group_prefix "group_`group'_"
                local group_value = substr("`specification'",strlen("`group_prefix'")+1,.)
                local this_if "`group' == `group_value'"
                if strtrim(`"`ifcond'"') != "" local this_if `"(`ifcond') & (`this_if')"'
                local comment "按 `group'=`group_value' 分组回归"
            }
            else if substr("`specification'",1,15) == "group_quantile_" {
                local quantile_value = substr("`specification'",16,.)
                if !`quantile_ready' {
                    file write `do_handle' "capture drop __jo_qgroup" _n
                    file write `do_handle' "xtile __jo_qgroup = `group', nq(`groupbins')" _n
                    local quantile_ready = 1
                }
                local this_if "__jo_qgroup == `quantile_value'"
                if strtrim(`"`ifcond'"') != "" local this_if `"(`ifcond') & (`this_if')"'
                local comment "按 `group' 的第`quantile_value'分位组回归"
            }
            local ++model_index
            _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                comment("`comment'") model("`model'") depvar("`depvar'")     ///
                indepvars(`"`indepvars'"') controls(`"`controls'"')          ///
                panel("`panel'") time("`time'") absorb(`"`absorb'"')       ///
                vcetype("`vcetype'") cluster("`cluster'") treat("`treat'") ///
                postvar("`postvar'") endog(`"`endog'"')                     ///
                instruments(`"`instruments'"') ifcond(`"`this_if'"')       ///
                `timefeopt' controlsmacro
            local stored "`stored' m`model_index'"
            local stored_specs "`stored_specs' `specification'"
        }
        if `quantile_ready' file write `do_handle' "capture drop __jo_qgroup    // 清理分位分组临时变量" _n _n
    }

    else if "`module'" == "endogeneity" {
        local psm_covars = strtrim(`"`psmcovars'"')
        if "`psm_covars'" == "" local psm_covars = strtrim(`"`indepvars' `controls'"')
        if "`psmtime'" != "" local psm_covars `"`psm_covars' i.`psmtime'"'
        foreach specification of local specs {
            if "`specification'" == "main" & "`model'" == "iv" {
                local ++model_index
                _journalone_do_emit_model, handle(`do_handle') index(`model_index') ///
                    comment("两阶段最小二乘法（2SLS-IV）") model("iv") depvar("`depvar'") ///
                    indepvars(`"`indepvars'"') controls(`"`controls'"') absorb(`"`absorb'"') ///
                    time("`time'") vcetype("`vcetype'") cluster("`cluster'")            ///
                    endog(`"`endog'"') instruments(`"`instruments'"') ifcond(`"`ifcond'"') ///
                    `timefeopt' controlsmacro
            }
            else if "`specification'" == "psm_nearest" {
                local psm_vce ""
                if inlist("`vcetype'", "robust", "cluster") local psm_vce "vce(robust)"
                local ifqual ""
                if strtrim(`"`ifcond'"') != "" local ifqual "if `ifcond'"
                file write `do_handle' "* 倾向得分近邻匹配（ATT）" _n
                file write `do_handle' "teffects psmatch (`depvar') (`treat' `psm_covars') `ifqual', atet nneighbor(`psmneighbor') `psm_vce'" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
            }
            else if inlist("`specification'", "psm_radius", "psm_kernel") {
                local method = substr("`specification'",5,.)
                file write `do_handle' "* PSM `method'匹配；需要先安装：ssc install psmatch2" _n
                local psm_option "kernel common"
                if "`method'" == "radius" local psm_option "radius caliper(.1) common"
                file write `do_handle' "psmatch2 `treat' `psm_covars', outcome(`depvar') `psm_option'" _n
                file write `do_handle' "return list    // ATT及标准误见r()返回值" _n _n
                local exportable = 0
            }
            else if "`specification'" == "heckman_twostep" {
                local selection_covars `"`heckmancovars'"'
                if strtrim(`"`selection_covars'"') == "" local selection_covars `"`instruments' `controls'"'
                local heckman_fe_terms ""
                if "`heckmanfe'" != "" {
                    foreach fevar of local absorb {
                        local heckman_fe_terms "`heckman_fe_terms' i.`fevar'"
                    }
                    if "`timefe'" != "" & "`time'" != "" local heckman_fe_terms "`heckman_fe_terms' i.`time'"
                }
                local ifqual ""
                if strtrim(`"`ifcond'"') != "" local ifqual "if `ifcond'"
                file write `do_handle' "* Heckman两步样本选择模型" _n
                file write `do_handle' "heckman `depvar' `indepvars' `controls' `heckman_fe_terms' `ifqual', select(`heckmansel' = `selection_covars') twostep" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
            }
            else if substr("`specification'",1,4) == "gmm_" {
                local method = substr("`specification'",5,.)
                local gmm_command "xtabond"
                if "`method'" == "system" local gmm_command "xtdpdsys"
                local gmm_options "lags(`gmmlags')"
                if "`gmmtwostep'" != "" local gmm_options "`gmm_options' twostep"
                if inlist("`vcetype'", "robust", "cluster") local gmm_options "`gmm_options' vce(robust)"
                file write `do_handle' "* 动态面板`method' GMM" _n
                file write `do_handle' "`gmm_command' `depvar' `indepvars' `controls' `gmmextra', `gmm_options'" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
            }
            else if "`specification'" == "dml_partial" {
                local dml_controls_all = strtrim(`"`controls' `dmlcontrols'"')
                local dml_controls_option ""
                if "`dml_controls_all'" != "" local dml_controls_option "controls(`dml_controls_all')"
                file write `do_handle' "* 部分线性双重机器学习（交叉拟合）" _n
                file write `do_handle' "xporegress `depvar' `indepvars', `dml_controls_option' xfolds(`dmlfolds') resample(`reps') rseed(`seed')" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
            }
            else if "`specification'" == "dml_iv" {
                local dml_endog `"`endog'"'
                local dml_exog `"`indepvars'"'
                if "`dml_endog'" == "" {
                    local dml_endog : word 1 of `indepvars'
                    local dml_exog : list indepvars - dml_endog
                }
                local dml_iv `"`dmlinstruments'"'
                if "`dml_iv'" == "" local dml_iv `"`instruments'"'
                local dml_controls_all = strtrim(`"`controls' `dmlcontrols'"')
                local dml_controls_option ""
                if "`dml_controls_all'" != "" local dml_controls_option "controls(`dml_controls_all')"
                file write `do_handle' "* 工具变量双重机器学习（交叉拟合）" _n
                file write `do_handle' "xpoivregress `depvar' `dml_exog' (`dml_endog' = `dml_iv'), `dml_controls_option' xfolds(`dmlfolds') resample(`reps') rseed(`seed')" _n
                local ++model_index
                file write `do_handle' "est store m`model_index'" _n _n
            }
            if !inlist("`specification'", "psm_radius", "psm_kernel") {
                local stored "`stored' m`model_index'"
                local stored_specs "`stored_specs' `specification'"
            }
        }
    }

    local stored = strtrim("`stored'")
    local stored_specs = strtrim("`stored_specs'")
    if "`stored'" != "" & `exportable' {
        local esttab_stat "se"
        local esttab_format "se(%9.`decimals'f)"
        if "`statistic'" == "t" {
            local esttab_stat "t"
            local esttab_format "t(%9.`decimals'f)"
        }
        file write `do_handle' "**结果导出**" _n
        file write `do_handle' `"esttab `stored' using "`rtf_file'", replace `esttab_stat' compress nogaps b(%9.`decimals'f) `esttab_format' stats(N r2 r2_a) star(* `pstar3' ** `pstar2' *** `pstar1') title("`title'")"' _n
        file write `do_handle' `"esttab `stored' using "`csv_file'", replace `esttab_stat' compress nogaps b(%9.`decimals'f) `esttab_format' stats(N r2 r2_a) star(* `pstar3' ** `pstar2' *** `pstar1')"' _n
    }
    else if !`exportable' {
        file write `do_handle' "* 本部分为r-class匹配结果，ATT及标准误见上方return list。" _n
    }
    file close `do_handle'
    return local file `"`file'"'
    return scalar models = `model_index'
end


capture program drop _journalone_do_emit_model
program define _journalone_do_emit_model, rclass
    version 16.0
    syntax , HANDLE(name) INDEX(integer) COMMENT(string) MODEL(string)  ///
        DEPVAR(string) [ INDEPVARS(string) CONTROLS(string)            ///
        PANEL(string) TIME(string) ABSORB(string) TIMEFE               ///
        VCETYPE(string) CLUSTER(string) TREAT(string) POSTVAR(string)  ///
        ENDOG(string) INSTRUMENTS(string) IFCOND(string) CONTROLSMACRO ]

    local command_controls `"`controls'"'
    if "`controlsmacro'" != "" & strtrim(`"`controls'"') != "" {
        local command_controls "__JOURNALONE_CONTROLS__"
    }
    _journalone_do_build_command, model("`model'") depvar("`depvar'") ///
        indepvars(`"`indepvars'"') controls(`"`command_controls'"')  ///
        panel("`panel'") time("`time'") absorb(`"`absorb'"')      ///
        vcetype("`vcetype'") cluster("`cluster'") treat("`treat'") ///
        postvar("`postvar'") endog(`"`endog'"')                    ///
        instruments(`"`instruments'"') ifcond(`"`ifcond'"') `timefe'
    local command `"`r(command)'"'
    local control_marker "__JOURNALONE_CONTROLS__"
    local control_pos = strpos(`"`command'"', "`control_marker'")
    if `control_pos' > 0 {
        local command_before = substr(`"`command'"', 1, `control_pos' - 1)
        local command_after = substr(`"`command'"', `control_pos' + strlen("`control_marker'"), .)
        file write `handle' `"`command_before'"' _char(36) `"controls`command_after'    // `comment'"' _n
    }
    else file write `handle' `"`command'    // `comment'"' _n
    file write `handle' "est store m`index'" _n _n
    return local command `"`command'"'
    return local estimate "m`index'"
end


capture program drop _journalone_do_build_command
program define _journalone_do_build_command, rclass
    version 16.0
    syntax , MODEL(string) DEPVAR(string)                              ///
        [ INDEPVARS(string) CONTROLS(string)                            ///
          PANEL(string) TIME(string) ABSORB(string) TIMEFE             ///
          VCETYPE(string) CLUSTER(string) TREAT(string)               ///
          POSTVAR(string) ENDOG(string) INSTRUMENTS(string) IFCOND(string) ]

    if "`vcetype'" == "" local vcetype "conventional"
    local ifqual ""
    if strtrim(`"`ifcond'"') != "" local ifqual `"if `ifcond'"'

    local fe_terms ""
    foreach fevar of local absorb {
        local fe_terms "`fe_terms' i.`fevar'"
    }
    local time_terms ""
    if "`timefe'" != "" & "`time'" != "" local time_terms "i.`time'"

    local vceopt ""
    if "`vcetype'" == "robust" local vceopt "vce(robust)"
    else if "`vcetype'" == "cluster" local vceopt "vce(cluster `cluster')"

    local command ""
    local rhs = strtrim(itrim(`"`indepvars' `controls' `fe_terms' `time_terms'"'))
    if "`model'" == "ols" {
        local command "regress `depvar'"
        if "`rhs'" != "" local command `"`command' `rhs'"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        if "`vceopt'" != "" local command `"`command', `vceopt'"'
    }
    else if "`model'" == "hdfe" {
        local hdfe_rhs = strtrim(itrim(`"`indepvars' `controls'"'))
        local hdfe_absorb = strtrim(`"`absorb'"')
        if "`timefe'" != "" & "`time'" != "" & ///
            !strpos(" `hdfe_absorb' ", " `time' ") {
            local hdfe_absorb = strtrim("`hdfe_absorb' `time'")
        }
        local hdfe_absorbopt "noabsorb"
        if strtrim(`"`hdfe_absorb'"') != "" local hdfe_absorbopt "absorb(`hdfe_absorb')"
        local command "reghdfe `depvar'"
        if "`hdfe_rhs'" != "" local command `"`command' `hdfe_rhs'"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        local command `"`command', `hdfe_absorbopt'"'
        if "`vceopt'" != "" local command `"`command' `vceopt'"'
    }
    else if "`model'" == "fe" {
        local command "xtreg `depvar'"
        if "`rhs'" != "" local command `"`command' `rhs'"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        local command `"`command', fe"'
        if "`vceopt'" != "" local command `"`command' `vceopt'"'
    }
    else if "`model'" == "re" {
        local command "xtreg `depvar'"
        if "`rhs'" != "" local command `"`command' `rhs'"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        local command `"`command', re"'
        if "`vceopt'" != "" local command `"`command' `vceopt'"'
    }
    else if "`model'" == "did" {
        local rhs = strtrim(itrim(`"i.`treat'##i.`postvar' `indepvars' `controls' i.`panel' i.`time' `fe_terms'"'))
        local command `"regress `depvar' `rhs'"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        if "`vceopt'" != "" local command `"`command', `vceopt'"'
    }
    else if "`model'" == "iv" {
        local command "ivregress 2sls `depvar'"
        if "`rhs'" != "" local command `"`command' `rhs'"'
        local command `"`command' (`endog' = `instruments')"'
        if "`ifqual'" != "" local command `"`command' `ifqual'"'
        if "`vceopt'" != "" local command `"`command', `vceopt'"'
    }
    else exit 198
    local command = strtrim(`"`command'"')
    return local command `"`command'"'
end
