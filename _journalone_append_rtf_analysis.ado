*! version 0.9.22 06sep2026

capture program drop _journalone_append_rtf_analysis
program define _journalone_append_rtf_analysis
    version 16.0
    syntax , HANDLE(name) TYPE(string) [TITLE(string) DECIMALS(integer 3) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)]

    local type = lower(strtrim("`type'"))
    if !inlist("`type'", "descriptive", "regression", "baseline", "diagnostics") {
        display as error "unknown RTF narrative type: `type'"
        exit 198
    }

    forvalues index = 1/6 {
        local paragraph`index' ""
    }
    local summary_text ""

    if "`type'" == "descriptive" {
        local variable_count = _N
        quietly summarize N_nonmissing, meanonly
        local n_min = r(min)
        local n_max = r(max)
        local n_min_display = strtrim(string(`n_min', "%12.0f"))
        local n_max_display = strtrim(string(`n_max', "%12.0f"))

        capture confirm variable N_total
        local has_total = (_rc == 0)
        capture confirm variable N_missing
        local has_missing = (_rc == 0)
        local total_slots = 0
        local total_missing = 0
        local invalid_count = 0
        local zero_sd_count = 0
        local zero_sd_names ""
        local zero_sd_seen ""
        local duplicate_count = 0
        local duplicate_names ""
        local seen_variables ""
        local extreme_count = 0
        local extreme_names ""
        local extreme_seen ""
        local extreme_detail_names ""
        local missing_detail_names ""
        local max_missing_rate = .
        local max_missing_variable ""
        local max_missing_count = 0

        forvalues row = 1/`=_N' {
            if missing(N_nonmissing[`row']) | N_nonmissing[`row'] <= 0 {
                local ++invalid_count
            }
            if !missing(sd[`row']) & sd[`row'] < 0 local ++invalid_count
            if !missing(min[`row']) & !missing(max[`row']) & min[`row'] > max[`row'] {
                local ++invalid_count
            }
            if !missing(mean[`row']) & !missing(min[`row']) & !missing(max[`row']) & ///
                (mean[`row'] < min[`row'] | mean[`row'] > max[`row']) {
                local ++invalid_count
            }
            local this_variable = variable[`row']

            if !missing(sd[`row']) & sd[`row'] == 0 {
                local ++zero_sd_count
                if !strpos(" `zero_sd_seen' ", " `this_variable' ") {
                    local zero_sd_seen "`zero_sd_seen' `this_variable'"
                    if wordcount("`zero_sd_names'") < 6 local zero_sd_names "`zero_sd_names' `this_variable'"
                }
            }

            * A repeated variable row is an output/data construction error,
            * not a substantive finding.  Keep a separate complete seen-list
            * so the count remains correct even when more than six names exist.
            local prior_duplicate = strpos(" `seen_variables' ", " `this_variable' ") > 0
            if `prior_duplicate' {
                local ++duplicate_count
                if !strpos(" `duplicate_names' ", " `this_variable' ") & ///
                    wordcount("`duplicate_names'") < 6 local duplicate_names "`duplicate_names' `this_variable'"
            }
            else local seen_variables "`seen_variables' `this_variable'"

            if `has_total' {
                if !missing(N_total[`row']) & N_total[`row'] > 0 {
                    local total_slots = `total_slots' + N_total[`row']
                    if N_nonmissing[`row'] > N_total[`row'] local ++invalid_count
                    local this_missing = max(N_total[`row']-N_nonmissing[`row'], 0)
                    if `has_missing' {
                        if !missing(N_missing[`row']) {
                            local this_missing = N_missing[`row']
                            if N_missing[`row'] < 0 local ++invalid_count
                            if abs(N_missing[`row'] - (N_total[`row']-N_nonmissing[`row'])) > 1e-8 {
                                local ++invalid_count
                            }
                        }
                    }
                    local total_missing = `total_missing' + `this_missing'
                    local this_missing_rate = 100*`this_missing'/N_total[`row']
                    if `this_missing' > 0 & ///
                        !strpos(" `missing_detail_names' ", " `this_variable'=") {
                        local missing_rate_detail = strtrim(string(`this_missing_rate', "%9.3f"))
                        if "`missing_detail_names'" == "" local missing_detail_names "`this_variable'=`this_missing'个（`missing_rate_detail'%）"
                        else local missing_detail_names "`missing_detail_names'；`this_variable'=`this_missing'个（`missing_rate_detail'%）"
                    }
                    if missing(`max_missing_rate') | `this_missing_rate' > `max_missing_rate' {
                        local max_missing_rate = `this_missing_rate'
                        local max_missing_variable = variable[`row']
                        local max_missing_count = `this_missing'
                    }
                }
            }

            * Flag only variables whose extrema are several SDs from the mean.
            * This is deliberately worded as a potential issue: a legitimate
            * skewed variable can also meet this screen.
            if !missing(mean[`row']) & !missing(sd[`row']) & sd[`row'] > 0 & ///
                !missing(min[`row']) & !missing(max[`row']) {
                local max_z = (max[`row']-mean[`row'])/sd[`row']
                local min_z = (mean[`row']-min[`row'])/sd[`row']
                if `max_z' >= 5 | `min_z' >= 5 {
                    local extreme_is_new = !strpos(" `extreme_seen' ", " `this_variable' ")
                    if `extreme_is_new' {
                        local ++extreme_count
                        local extreme_seen "`extreme_seen' `this_variable'"
                        if wordcount("`extreme_names'") < 6 local extreme_names "`extreme_names' `this_variable'"
                    }
                    if `extreme_is_new' {
                        local extreme_value_detail ""
                        if `max_z' >= 5 {
                            local max_detail = strtrim(string(max[`row'], "%21.`decimals'f"))
                            local mean_detail = strtrim(string(mean[`row'], "%21.`decimals'f"))
                            local sd_detail = strtrim(string(sd[`row'], "%21.`decimals'f"))
                            local extreme_value_detail "`this_variable'最大值=`max_detail'（均值=`mean_detail'，SD=`sd_detail'）"
                        }
                        if `min_z' >= 5 {
                            local min_detail = strtrim(string(min[`row'], "%21.`decimals'f"))
                            local mean_detail = strtrim(string(mean[`row'], "%21.`decimals'f"))
                            local sd_detail = strtrim(string(sd[`row'], "%21.`decimals'f"))
                            if "`extreme_value_detail'" == "" local extreme_value_detail "`this_variable'最小值=`min_detail'（均值=`mean_detail'，SD=`sd_detail'）"
                            else local extreme_value_detail "`extreme_value_detail'；`this_variable'最小值=`min_detail'（均值=`mean_detail'，SD=`sd_detail'）"
                        }
                        if "`extreme_value_detail'" != "" {
                            if "`extreme_detail_names'" == "" local extreme_detail_names "`extreme_value_detail'"
                            else local extreme_detail_names "`extreme_detail_names'；`extreme_value_detail'"
                        }
                    }
                }
            }
        }
        local zero_sd_names = strtrim("`zero_sd_names'")
        local duplicate_names = strtrim("`duplicate_names'")
        local extreme_names = strtrim("`extreme_names'")
        local missing_detail_names = strtrim("`missing_detail_names'")
        local extreme_detail_names = strtrim("`extreme_detail_names'")

        local sample_detail "本表报告`variable_count'个变量，非缺失观测数介于`n_min_display'至`n_max_display'"
        if `total_slots' > 0 {
            local missing_rate = 100*`total_missing'/`total_slots'
            local missing_display = strtrim(string(`missing_rate', "%9.3f"))
            if `total_missing' > 0 {
                local max_missing_display = strtrim(string(`max_missing_rate', "%9.3f"))
                local missing_detail "总体缺失`total_missing'个观测，占变量-样本单元的`missing_display'%；`max_missing_variable'缺失`max_missing_count'个（`max_missing_display'%），为表内最高"
                if "`missing_detail_names'" != "" local missing_detail "`missing_detail'；缺失分布：`missing_detail_names'"
            }
            else local missing_detail ""
        }
        else local missing_detail "表中没有统一总样本量，无法核对缺失规模"

        local missing_issues ""
        local missing_impacts ""
        local missing_recommendations ""
        if `total_slots' > 0 & `total_missing' > 0 {
            local missing_issues "`missing_detail'"
            local missing_impacts "缺失可能改变各模型的有效样本，并在非随机缺失时产生样本选择偏差"
            local missing_recommendations "检查缺失机制，统一估计样本并核对回归表各列N"
        }
        else if `total_slots' == 0 {
            local missing_issues "`missing_detail'"
            local missing_impacts "无法判断变量是否使用了不同有效样本"
            local missing_recommendations "补充每个变量的总样本数并统一估计样本"
        }

        * The second issue/impact pair covers data-quality problems visible in
        * the table itself: duplicated rows, no variation, suspicious extrema,
        * and impossible statistic relationships.
        local desc_issues ""
        local desc_impacts ""
        local desc_recommendations ""
        if `duplicate_count' > 0 {
            local desc_issues "变量`duplicate_names'重复出现`duplicate_count'行，属于重复选择或重复输出"
            local desc_impacts "重复行会夸大变量数量并造成后续结果的对应关系混乱"
            local desc_recommendations "删除变量选择列表中的重复项，并在生成CSV前按首次出现顺序去重"
        }
        if `zero_sd_count' > 0 {
            local zero_issue "`zero_sd_names'的标准差为0，当前样本没有可识别的变异"
            if "`desc_issues'" == "" local desc_issues "`zero_issue'"
            else local desc_issues "`desc_issues'；`zero_issue'"
            local zero_impact "无变异变量无法识别斜率，可能在回归中被省略或引发共线性"
            if "`desc_impacts'" == "" local desc_impacts "`zero_impact'"
            else local desc_impacts "`desc_impacts'；`zero_impact'"
            local zero_recommendation "核对变量是否误读、编码错误或被样本筛选固定；确认无误后从回归式移除"
            if "`desc_recommendations'" == "" local desc_recommendations "`zero_recommendation'"
            else local desc_recommendations "`desc_recommendations'；`zero_recommendation'"
        }
        if `extreme_count' > 0 {
            local extreme_issue "`extreme_names'的最大值或最小值距均值至少5个标准差，存在潜在极端值"
            if "`extreme_detail_names'" != "" local extreme_issue "`extreme_issue'（`extreme_detail_names'）"
            if "`desc_issues'" == "" local desc_issues "`extreme_issue'"
            else local desc_issues "`desc_issues'；`extreme_issue'"
            local extreme_impact "潜在极端值可能拉动均值、标准差和回归系数，影响显著性；仅凭本表不能断定这些值是错误"
            if "`desc_impacts'" == "" local desc_impacts "`extreme_impact'"
            else local desc_impacts "`desc_impacts'；`extreme_impact'"
            local extreme_recommendation "回查原始记录、单位和录入口径，再看分位数/箱线图；确认异常后按预先规则缩尾或变换，并报告处理前后的稳健性结果"
            if "`desc_recommendations'" == "" local desc_recommendations "`extreme_recommendation'"
            else local desc_recommendations "`desc_recommendations'；`extreme_recommendation'"
        }
        if `invalid_count' > 0 {
            local invalid_issue "另有`invalid_count'处样本量、缺失数或取值范围关系异常"
            if "`desc_issues'" == "" local desc_issues "`invalid_issue'"
            else local desc_issues "`desc_issues'；`invalid_issue'"
            local invalid_impact "统计量关系异常会使表中结论无法复核"
            if "`desc_impacts'" == "" local desc_impacts "`invalid_impact'"
            else local desc_impacts "`desc_impacts'；`invalid_impact'"
            local invalid_recommendation "先回到原始数据核对异常记录，再运行后续模型"
            if "`desc_recommendations'" == "" local desc_recommendations "`invalid_recommendation'"
            else local desc_recommendations "`desc_recommendations'；`invalid_recommendation'"
        }
        local all_desc_issues "`missing_issues'"
        local all_desc_impacts "`missing_impacts'"
        local all_desc_recommendations "`missing_recommendations'"
        if "`desc_issues'" != "" {
            if "`all_desc_issues'" == "" local all_desc_issues "`desc_issues'"
            else local all_desc_issues "`all_desc_issues'；`desc_issues'"
            if "`all_desc_impacts'" == "" local all_desc_impacts "`desc_impacts'"
            else local all_desc_impacts "`all_desc_impacts'；`desc_impacts'"
            if "`all_desc_recommendations'" == "" local all_desc_recommendations "`desc_recommendations'"
            else local all_desc_recommendations "`all_desc_recommendations'；`desc_recommendations'"
        }
        local descriptive_text "结果解读：`sample_detail'。"
        if "`all_desc_issues'" == "" local descriptive_text "`descriptive_text'未发现缺失、重复变量、无变异变量、潜在极端值或统计量异常；处理建议：回归前核对各列N和变量单位。"
        else local descriptive_text "`descriptive_text'发现的问题：`all_desc_issues'；可能影响：`all_desc_impacts'；处理建议：`all_desc_recommendations'。"
        local paragraph1 = strtrim("`descriptive_text'")
        forvalues clear_index = 2/6 {
            local paragraph`clear_index' ""
        }
        local summary_text ""
    }

    if inlist("`type'", "regression", "baseline") {
        local specifications ""
        forvalues row = 1/`=_N' {
            local this_specification = specification[`row']
            if !strpos(" `specifications' ", " `this_specification' ") {
                local specifications "`specifications' `this_specification'"
            }
        }
        local specifications = strtrim("`specifications'")
        local specification_count : word count `specifications'

        local iv_stage_count 0
        local heckman_stage_count 0
        forvalues stage_row = 1/`=_N' {
            if substr(specification[`stage_row'],1,9) == "iv_first_" | ///
                specification[`stage_row'] == "iv_2sls" local iv_stage_count = 1
            if inlist(specification[`stage_row'], "heckman_selection", "heckman_twostep") local heckman_stage_count = 1
        }

        local focus_count = 0
        local positive_count = 0
        local negative_count = 0
        local zero_count = 0
        local sig1_count = 0
        local sig2_count = 0
        local sig3_count = 0
        local focus_details ""
        local p1_display = strtrim(string(100*`pstar1', "%9.3g"))
        local p2_display = strtrim(string(100*`pstar2', "%9.3g"))
        local p3_display = strtrim(string(100*`pstar3', "%9.3g"))
        capture confirm variable specification_label
        local has_specification_label = (_rc == 0)

        foreach this_specification of local specifications {
            local focus_row = 0
            local focus_order = .
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" & ///
                    term[`row'] != "_cons" & !missing(estimate[`row']) {
                    if missing(`focus_order') | term_order[`row'] < `focus_order' {
                        local focus_order = term_order[`row']
                        local focus_row = `row'
                    }
                }
            }

            if `focus_row' > 0 {
                local ++focus_count
                local direction_text "系数为0"
                if estimate[`focus_row'] > 0 {
                    local ++positive_count
                    local direction_text "呈正向关系"
                }
                else if estimate[`focus_row'] < 0 {
                    local ++negative_count
                    local direction_text "呈负向关系"
                }
                else local ++zero_count

                local significance_text "未报告显著性"
                if !missing(p_value[`focus_row']) {
                    if p_value[`focus_row'] <= `pstar1' {
                        local ++sig1_count
                        local significance_text "在`p1_display'%水平上显著"
                    }
                    else if p_value[`focus_row'] <= `pstar2' {
                        local significance_text "在`p2_display'%水平上显著"
                    }
                    else if p_value[`focus_row'] <= `pstar3' {
                        local significance_text "在`p3_display'%水平上显著"
                    }
                    else local significance_text "未达到`p3_display'%显著性水平"
                    if p_value[`focus_row'] <= `pstar2' local ++sig2_count
                    if p_value[`focus_row'] <= `pstar3' local ++sig3_count
                }

                if `focus_count' <= 6 {
                    local focus_label "`this_specification'"
                    if `has_specification_label' {
                        if strtrim(specification_label[`focus_row']) != "" {
                            local focus_label = specification_label[`focus_row']
                        }
                    }
                    local focus_outcome = outcome[`focus_row']
                    local focus_term = term[`focus_row']
                    local beta_display = strtrim(string(estimate[`focus_row'], ///
                        "%21.`decimals'f"))
                    local p_display "未报告"
                    if !missing(p_value[`focus_row']) {
                        local p_display = strtrim(string(p_value[`focus_row'], "%9.4f"))
                    }
                    local one_detail "`focus_label'：`focus_term'系数为`beta_display'（P=`p_display'）"
                    if "`focus_details'" == "" local focus_details "`one_detail'"
                    else local focus_details "`focus_details'；`one_detail'"
                }
            }
        }
        if `focus_count' > 6 {
            local remaining_focus = `focus_count' - 6
            local focus_details "`focus_details'；其余`remaining_focus'个规格的主要系数见表中对应结果"
        }

        local invalid_count = 0
        local zero_se_count = 0
        local missing_focus_count = `specification_count' - `focus_count'
        local missing_p_count = 0
        local coefficient_min = .
        local coefficient_max = .
        local fit_min = .
        local fit_max = .
        local fit_count = 0
        capture confirm variable ci_low
        local has_ci = (_rc == 0)
        capture confirm variable r2
        local has_r2 = (_rc == 0)
        capture confirm variable r2_a
        local has_r2_a = (_rc == 0)

        forvalues row = 1/`=_N' {
            if !missing(std_error[`row']) & std_error[`row'] < 0 local ++invalid_count
            if !missing(p_value[`row']) & (p_value[`row'] < 0 | p_value[`row'] > 1) {
                local ++invalid_count
            }
            if !missing(N[`row']) & N[`row'] <= 0 local ++invalid_count
            if `has_ci' {
                if !missing(ci_low[`row']) & !missing(ci_high[`row']) & ///
                    ci_low[`row'] > ci_high[`row'] local ++invalid_count
            }
            if !missing(std_error[`row']) & std_error[`row'] == 0 & ///
                !missing(estimate[`row']) local ++zero_se_count

            local fit_value = .
            if `has_r2' local fit_value = r2[`row']
            if "`type'" == "baseline" & `has_r2_a' {
                if !missing(r2_a[`row']) local fit_value = r2_a[`row']
            }
            if !missing(`fit_value') {
                local ++fit_count
                if missing(`fit_min') | `fit_value' < `fit_min' local fit_min = `fit_value'
                if missing(`fit_max') | `fit_value' > `fit_max' local fit_max = `fit_value'
                if `fit_value' > 1+1e-8 local ++invalid_count
            }
        }

        * Count missing P values only for the automatically selected focal
        * coefficient in each specification.  A missing P value is a report
        * problem because the stars and the significance comparison cannot be
        * reproduced from the table.
        foreach this_specification of local specifications {
            local p_focus_row = 0
            local p_focus_order = .
            forvalues row = 1/`=_N' {
                if specification[`row'] == "`this_specification'" & ///
                    term[`row'] != "_cons" & !missing(estimate[`row']) {
                    if missing(`p_focus_order') | term_order[`row'] < `p_focus_order' {
                        local p_focus_order = term_order[`row']
                        local p_focus_row = `row'
                    }
                }
            }
            if `p_focus_row' > 0 & missing(p_value[`p_focus_row']) local ++missing_p_count
        }

        quietly summarize N if N < ., meanonly
        local n_observed = r(N)
        local n_min = r(min)
        local n_max = r(max)
        local sample_note "表中没有可用的规格样本量N，无法核对跨模型样本是否一致"
        if `n_observed' > 0 {
            local n_min_display = strtrim(string(`n_min', "%12.0f"))
            local n_max_display = strtrim(string(`n_max', "%12.0f"))
            local sample_note "各规格使用相同样本量，为`n_min_display'"
            if `n_min' != `n_max' local sample_note "各规格样本量介于`n_min_display'至`n_max_display'，跨模型比较存在样本变化"
        }

        local stability_note "只有一个可识别的主要系数，暂不能判断跨规格稳定性"
        if `focus_count' > 1 & (`positive_count' == `focus_count' | ///
            `negative_count' == `focus_count' | `zero_count' == `focus_count') {
            local stability_note "主要系数在各规格中的方向一致"
            if `sig3_count' == `focus_count' local stability_note "主要系数在各规格中的方向和10%显著性均保持一致"
            else local stability_note "主要系数方向一致，但显著性在不同规格间有所变化"
        }
        else if `focus_count' > 1 local stability_note "主要系数在不同规格中的方向不完全一致，结论可能对模型或样本设定较敏感"
        if `focus_count' == 0 local stability_note "当前表未识别到可用于自动比较的非常数主要系数"

        local fit_note ""
        if `fit_count' > 0 {
            local fit_min_display = strtrim(string(`fit_min', "%21.`decimals'f"))
            local fit_max_display = strtrim(string(`fit_max', "%21.`decimals'f"))
            local fit_note "；拟合优度介于`fit_min_display'至`fit_max_display'"
        }
        * Paragraph 1 reports what is actually in the table: each focal
        * coefficient, its P value/sign, the model sample range, and fit range.
        local result_detail "本表报告`specification_count'个估计规格"
        if "`focus_details'" != "" local result_detail "`result_detail'；核心结果：`focus_details'"
        else local result_detail "`result_detail'；未识别到非常数系数"
        if `n_observed' > 0 {
            if `n_min' == `n_max' local result_detail "`result_detail'；N=`n_min_display'"
            else local result_detail "`result_detail'；N介于`n_min_display'至`n_max_display'"
        }
        else local result_detail "`result_detail'；未报告N"
        if "`fit_note'" != "" local result_detail "`result_detail'`fit_note'"
        local paragraph1 "结果解读：`result_detail'。"

        * Pair 1 is the comparability problem: sign, significance, and sample
        * changes across specifications are reported together and tied to
        * their empirical consequences.
        local comparability_issue ""
        if `missing_focus_count' > 0 local comparability_issue "有`missing_focus_count'个规格没有可比较的主要系数"
        if `positive_count' > 0 & `negative_count' > 0 {
            if "`comparability_issue'" == "" local comparability_issue "主要系数在规格间变号"
            else local comparability_issue "`comparability_issue'；主要系数在规格间变号"
        }
        if `focus_count' > 1 & `sig3_count' < `focus_count' {
            if "`comparability_issue'" == "" local comparability_issue "主要系数的10%显著性未在所有规格保持"
            else local comparability_issue "`comparability_issue'；主要系数的10%显著性未在所有规格保持"
        }
        if `n_observed' == 0 | (`n_observed' > 1 & `n_min' != `n_max') {
            if "`comparability_issue'" == "" local comparability_issue "`sample_note'"
            else local comparability_issue "`comparability_issue'；`sample_note'"
        }
        if "`comparability_issue'" == "" local paragraph2 "发现的问题：主要系数在各规格中均可识别，方向、显著性和样本量没有触发可直接识别的比较风险。"
        else local paragraph2 "发现的问题：`comparability_issue'。"

        local comparability_impact ""
        if `positive_count' > 0 & `negative_count' > 0 local comparability_impact "变号会使方向性结论依赖具体规格，不能把所有列概括为同一方向"
        if `focus_count' > 1 & `sig3_count' < `focus_count' {
            if "`comparability_impact'" == "" local comparability_impact "显著性变化意味着统计证据对设定较敏感"
            else local comparability_impact "`comparability_impact'；显著性变化意味着统计证据对设定较敏感"
        }
        if `n_observed' > 1 & `n_min' != `n_max' {
            if "`comparability_impact'" == "" local comparability_impact "样本变化会把模型设定差异与样本差异混在一起"
            else local comparability_impact "`comparability_impact'；样本变化会把模型设定差异与样本差异混在一起"
        }
        if `missing_focus_count' > 0 {
            if "`comparability_impact'" == "" local comparability_impact "缺少主要系数时无法判断该规格是否支持研究假设"
            else local comparability_impact "`comparability_impact'；缺少主要系数时无法判断该规格是否支持研究假设"
        }
        if "`comparability_impact'" == "" local paragraph3 "可能影响：各规格的主要系数可以直接核对；仍需结合效应大小和识别设计解释结果。"
        else local paragraph3 "可能影响：`comparability_impact'。"

        * Pair 2 is the table-integrity problem, kept separate so that a
        * missing P value or zero standard error is not hidden by a substantive
        * sign/significance discussion.
        local integrity_issue ""
        if `missing_p_count' > 0 local integrity_issue "有`missing_p_count'个主要系数缺少P值"
        if `zero_se_count' > 0 {
            if "`integrity_issue'" == "" local integrity_issue "有`zero_se_count'个非缺失系数的标准误为0"
            else local integrity_issue "`integrity_issue'；有`zero_se_count'个非缺失系数的标准误为0"
        }
        if `invalid_count' > 0 {
            if "`integrity_issue'" == "" local integrity_issue "表内有`invalid_count'处统计量关系异常"
            else local integrity_issue "`integrity_issue'；表内有`invalid_count'处统计量关系异常"
        }
        if "`integrity_issue'" == "" local paragraph4 "发现的问题：表内主要系数的P值、标准误、置信区间和拟合统计量没有发现明显缺报或范围错误。"
        else local paragraph4 "发现的问题：`integrity_issue'。"

        local integrity_impact ""
        if `missing_p_count' > 0 local integrity_impact "缺少P值时无法复核显著性判断"
        if `zero_se_count' > 0 {
            if "`integrity_impact'" == "" local integrity_impact "零标准误可能来自完全共线、被省略项或不可识别参数"
            else local integrity_impact "`integrity_impact'；零标准误可能来自完全共线、被省略项或不可识别参数"
        }
        if `invalid_count' > 0 {
            if "`integrity_impact'" == "" local integrity_impact "数值关系异常会使表中结论无法复现"
            else local integrity_impact "`integrity_impact'；数值关系异常会使表中结论无法复现"
        }
        if "`integrity_impact'" == "" local paragraph5 "可能影响：当前表未触发表内统计量缺报或范围风险；仍应保留置信区间和实际效应大小。"
        else local paragraph5 "可能影响：`integrity_impact'。"

        local recommendation_text ""
        if `positive_count' > 0 & `negative_count' > 0 local recommendation_text "逐列核对控制变量、固定效应、样本和标准误，先解释变号来源，再决定哪一规格对应研究设计"
        if `focus_count' > 1 & `sig3_count' < `focus_count' {
            if "`recommendation_text'" == "" local recommendation_text "报告各列系数和置信区间，不要只保留显著列"
            else local recommendation_text "`recommendation_text'；报告各列系数和置信区间，不要只保留显著列"
        }
        if `n_observed' > 1 & `n_min' != `n_max' {
            if "`recommendation_text'" == "" local recommendation_text "用相同估计样本重跑一组对照规格，区分样本变化与模型变化"
            else local recommendation_text "`recommendation_text'；用相同估计样本重跑一组对照规格，区分样本变化与模型变化"
        }
        if `missing_focus_count' > 0 {
            if "`recommendation_text'" == "" local recommendation_text "补齐缺失规格的主要系数，或从比较中明确剔除并说明原因"
            else local recommendation_text "`recommendation_text'；补齐缺失规格的主要系数，或从比较中明确剔除并说明原因"
        }
        if `missing_p_count' > 0 {
            if "`recommendation_text'" == "" local recommendation_text "补齐P值或由系数和标准误重新计算显著性"
            else local recommendation_text "`recommendation_text'；补齐P值或由系数和标准误重新计算显著性"
        }
        if `zero_se_count' > 0 {
            if "`recommendation_text'" == "" local recommendation_text "检查完全共线、参考组和被省略项"
            else local recommendation_text "`recommendation_text'；检查完全共线、参考组和被省略项"
        }
        if `invalid_count' > 0 {
            if "`recommendation_text'" == "" local recommendation_text "回到原始估计命令核对异常行"
            else local recommendation_text "`recommendation_text'；回到原始估计命令核对异常行"
        }
        if strpos("`title'", "异质") {
            if "`recommendation_text'" == "" local recommendation_text "补充正式组间系数差异检验，不只比较两组星号"
            else local recommendation_text "`recommendation_text'；补充正式组间系数差异检验，不只比较两组星号"
        }
        if strpos("`title'", "机制") {
            if "`recommendation_text'" == "" local recommendation_text "按各方程的实际路径系数核对机制链条"
            else local recommendation_text "`recommendation_text'；按各方程的实际路径系数核对机制链条"
        }
        if strpos("`title'", "内生") & (`iv_stage_count' | `heckman_stage_count') {
            if "`recommendation_text'" == "" local recommendation_text "分别核对第一阶段/选择方程与结构方程"
            else local recommendation_text "`recommendation_text'；分别核对第一阶段/选择方程与结构方程"
        }
        if "`recommendation_text'" == "" local recommendation_text "按研究设计报告各列系数、置信区间和实际效应大小"
        local paragraph6 "处理建议：`recommendation_text'。"

        local summary_text "`result_detail'。"
        if "`comparability_issue'" != "" local summary_text "`summary_text'主要比较问题：`comparability_issue'。"
        if "`integrity_issue'" != "" local summary_text "`summary_text'表内核对问题：`integrity_issue'。"
        if "`comparability_issue'" == "" & "`integrity_issue'" == "" local summary_text "`summary_text'未发现可由本表直接识别的明显问题。"

        * All module explanations are emitted as one compact paragraph.  Keep
        * only triggered issue/impact pairs; do not repeat generic no-risk text.
        local regression_issues "`comparability_issue'"
        if "`integrity_issue'" != "" {
            if "`regression_issues'" == "" local regression_issues "`integrity_issue'"
            else local regression_issues "`regression_issues'；`integrity_issue'"
        }
        local regression_impacts "`comparability_impact'"
        if "`integrity_impact'" != "" {
            if "`regression_impacts'" == "" local regression_impacts "`integrity_impact'"
            else local regression_impacts "`regression_impacts'；`integrity_impact'"
        }
        local regression_text "结果解读：`result_detail'。"
        if "`regression_issues'" == "" local regression_text "`regression_text'未发现表内可由当前结果直接识别的明显问题；"
        else local regression_text "`regression_text'发现的问题：`regression_issues'；可能影响：`regression_impacts'；"
        local regression_text "`regression_text'处理建议：`recommendation_text'。"
        local paragraph1 = strtrim("`regression_text'")
        forvalues clear_index = 2/6 {
            local paragraph`clear_index' ""
        }
        local summary_text ""
    }

    if "`type'" == "diagnostics" {
        quietly count if analysis_section == "相关性分析"
        local corr_rows = r(N)
        quietly count if analysis_section == "多重共线性"
        local vif_rows = r(N)
        quietly count if analysis_section == "面板模型选择"
        local panel_rows = r(N)
        quietly count if analysis_section == "工具变量诊断"
        local iv_rows = r(N)

        local high_corr = 0
        local corr_pairs = 0
        local low_corr = 0
        local max_corr_abs = .
        local max_corr_value = .
        local max_corr_var1 ""
        local max_corr_var2 ""
        local high_vif = 0
        local moderate_vif = 0
        local max_vif = .
        local max_vif_variable ""
        local mean_vif = .
        local first_stage_f = .
        local first_stage_partial_r2 = .
        local panel_text ""
        local invalid_count = 0
        local failed_count = 0
        local failed_notes ""
        capture confirm variable note
        local has_note = (_rc == 0)
        local p1_display = strtrim(string(100*`pstar1', "%9.3g"))
        local p2_display = strtrim(string(100*`pstar2', "%9.3g"))
        local p3_display = strtrim(string(100*`pstar3', "%9.3g"))

        forvalues row = 1/`=_N' {
            if analysis_section[`row'] == "相关性分析" & ///
                variable1[`row'] != variable2[`row'] & !missing(statistic[`row']) {
                local this_abs_corr = abs(statistic[`row'])
                local ++corr_pairs
                if `this_abs_corr' >= .8 local ++high_corr
                else local ++low_corr
                if missing(`max_corr_abs') | `this_abs_corr' > `max_corr_abs' {
                    local max_corr_abs = `this_abs_corr'
                    local max_corr_value = statistic[`row']
                    local max_corr_var1 = variable1[`row']
                    local max_corr_var2 = variable2[`row']
                }
            }
            if analysis_section[`row'] == "多重共线性" & test[`row'] == "VIF" & ///
                !missing(statistic[`row']) {
                if statistic[`row'] >= 10 local ++high_vif
                else if statistic[`row'] >= 5 local ++moderate_vif
                if missing(`max_vif') | statistic[`row'] > `max_vif' {
                    local max_vif = statistic[`row']
                    local max_vif_variable = variable1[`row']
                }
            }
            if test[`row'] == "平均VIF" & !missing(statistic[`row']) {
                local mean_vif = statistic[`row']
            }
            if test[`row'] == "第一阶段部分R2" & !missing(statistic[`row']) {
                local first_stage_partial_r2 = statistic[`row']
            }
            if test[`row'] == "排除工具变量F统计量" & !missing(statistic[`row']) {
                local first_stage_f = statistic[`row']
            }

            if analysis_section[`row'] == "面板模型选择" & !missing(p_value[`row']) {
                local p_display = strtrim(string(p_value[`row'], "%9.4f"))
                local panel_decision "未拒绝相应原假设"
                if p_value[`row'] < .05 local panel_decision "在5%水平拒绝相应原假设"
                if test[`row'] == "固定效应与混合OLS的F检验" {
                    if p_value[`row'] < .05 local panel_decision "拒绝个体效应共同为0，固定效应相对混合OLS获得统计支持"
                    else local panel_decision "未拒绝个体效应共同为0，未显示必须采用固定效应的统计证据"
                }
                if test[`row'] == "Breusch-Pagan随机效应LM检验" {
                    if p_value[`row'] < .05 local panel_decision "拒绝随机效应方差为0，随机效应相对混合OLS获得统计支持"
                    else local panel_decision "未拒绝随机效应方差为0，未显示必须采用随机效应的统计证据"
                }
                if test[`row'] == "Hausman检验" {
                    if p_value[`row'] < .05 local panel_decision "拒绝随机效应估计一致的原假设，常规比较通常倾向固定效应"
                    else local panel_decision "未拒绝随机效应估计一致的原假设，统计上未排斥随机效应"
                }
                local one_panel "`=test[`row']'的P值为`p_display'，`panel_decision'"
                if "`panel_text'" == "" local panel_text "`one_panel'"
                else local panel_text "`panel_text'；`one_panel'"
            }

            if analysis_section[`row'] == "相关性分析" & !missing(statistic[`row']) & ///
                abs(statistic[`row']) > 1+1e-8 local ++invalid_count
            if !missing(p_value[`row']) & (p_value[`row'] < 0 | p_value[`row'] > 1) {
                local ++invalid_count
            }
            if !missing(N[`row']) & N[`row'] <= 0 local ++invalid_count
            if `has_note' {
                if strpos(lower(note[`row']), "失败") | strpos(lower(note[`row']), "错误") {
                    local ++failed_count
                    if strtrim("`failed_notes'") == "" local failed_notes = test[`row']
                    else local failed_notes "`failed_notes'；`=test[`row']'"
                }
            }
        }

        local max_vif_display "未报告"
        if !missing(`max_vif') local max_vif_display = strtrim(string(`max_vif', "%21.`decimals'f"))
        local mean_vif_text ""
        if !missing(`mean_vif') {
            local mean_vif_display = strtrim(string(`mean_vif', "%21.`decimals'f"))
            local mean_vif_text "，平均VIF为`mean_vif_display'"
        }
        local max_corr_display "未报告"
        if !missing(`max_corr_abs') local max_corr_display = strtrim(string(`max_corr_value', "%21.`decimals'f"))
        local f_display "未报告"
        local partial_display "未报告"
        local iv_detail ""
        if `iv_rows' > 0 {
            if !missing(`first_stage_partial_r2') {
                local partial_display = strtrim(string(`first_stage_partial_r2', "%21.`decimals'f"))
                local iv_detail "第一阶段部分R²为`partial_display'"
            }
            if !missing(`first_stage_f') {
                local f_display = strtrim(string(`first_stage_f', "%21.`decimals'f"))
                if "`iv_detail'" == "" local iv_detail "排除工具变量F为`f_display'"
                else local iv_detail "`iv_detail'，排除工具变量F为`f_display'"
            }
            if "`iv_detail'" == "" local iv_detail "表中没有可用的第一阶段F或部分R²"
        }

        * Paragraph 1 reports the observed diagnostic statistics, rather than
        * explaining what correlation/VIF/F tests mean in general.
        local diagnostic_results ""
        if `corr_rows' > 0 {
            local one_result "相关性：`corr_pairs'组变量对"
            if !missing(`max_corr_abs') local one_result "`one_result'，最大r=`max_corr_display'（`max_corr_var1'与`max_corr_var2'）"
            else local one_result "`one_result'，未报告可用r"
            local diagnostic_results "`one_result'"
        }
        if `vif_rows' > 0 {
            local one_result "VIF：最大值=`max_vif_display'（`max_vif_variable'）`mean_vif_text'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if `panel_rows' > 0 & "`panel_text'" != "" {
            local one_result "面板检验：`panel_text'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if `iv_rows' > 0 {
            local one_result "工具变量：`iv_detail'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if "`diagnostic_results'" == "" local diagnostic_results "当前表没有可用的相关性、VIF、面板或第一阶段统计量"
        local paragraph1 "结果解读：`diagnostic_results'。"

        * Pair 1: substantive warnings visible in the diagnostic values.
        local diagnostic_issues ""
        if `high_corr' > 0 {
            local corr_issue "有`high_corr'组变量对的|r|达到0.8"
            if !missing(`max_corr_abs') local corr_issue "`corr_issue'，最大值为`max_corr_display'（`max_corr_var1'与`max_corr_var2'）"
            local diagnostic_issues "`corr_issue'"
        }
        if `high_vif' > 0 {
            local vif_issue "有`high_vif'个变量的VIF不低于10"
            if "`diagnostic_issues'" == "" local diagnostic_issues "`vif_issue'"
            else local diagnostic_issues "`diagnostic_issues'；`vif_issue'"
        }
        if `first_stage_f' < 10 & !missing(`first_stage_f') {
            local iv_issue "第一阶段F为`f_display'，存在弱工具变量风险"
            if "`diagnostic_issues'" == "" local diagnostic_issues "`iv_issue'"
            else local diagnostic_issues "`diagnostic_issues'；`iv_issue'"
        }
        if "`diagnostic_issues'" == "" local paragraph2 "发现的问题：当前诊断表未触发高相关、高VIF或弱第一阶段预警。"
        else local paragraph2 "发现的问题：`diagnostic_issues'。"

        local diagnostic_impacts ""
        if `high_corr' > 0 local diagnostic_impacts "高相关变量可能重复携带信息，使回归系数和标准误不稳定"
        if `high_vif' > 0 {
            if "`diagnostic_impacts'" == "" local diagnostic_impacts "高VIF可能放大标准误，使单个系数难以显著"
            else local diagnostic_impacts "`diagnostic_impacts'；高VIF可能放大标准误，使单个系数难以显著"
        }
        if `first_stage_f' < 10 & !missing(`first_stage_f') {
            if "`diagnostic_impacts'" == "" local diagnostic_impacts "弱工具变量会使IV二阶段估计偏误并放大不确定性"
            else local diagnostic_impacts "`diagnostic_impacts'；弱工具变量会使IV二阶段估计偏误并放大不确定性"
        }
        if "`diagnostic_impacts'" == "" local paragraph3 "可能影响：当前诊断值没有显示上述共线性或工具变量强度风险；仍需结合变量定义和识别假设解释。"
        else local paragraph3 "可能影响：`diagnostic_impacts'。"

        * Pair 2: report rows that cannot be checked or were not produced.
        local integrity_issue ""
        if `failed_count' > 0 {
            local integrity_issue "有`failed_count'行检验未成功生成"
            if strtrim("`failed_notes'") != "" local integrity_issue "`integrity_issue'（`failed_notes'）"
        }
        if `invalid_count' > 0 {
            local invalid_issue "有`invalid_count'处相关系数、P值或N超出可解释范围"
            if "`integrity_issue'" == "" local integrity_issue "`invalid_issue'"
            else local integrity_issue "`integrity_issue'；`invalid_issue'"
        }
        if `corr_rows' == 0 & `vif_rows' == 0 & `panel_rows' == 0 & `iv_rows' == 0 {
            if "`integrity_issue'" == "" local integrity_issue "表中没有可用的诊断行"
            else local integrity_issue "`integrity_issue'；表中没有可用的诊断行"
        }
        if "`integrity_issue'" == "" local paragraph4 "发现的问题：表内相关系数、P值和样本量没有发现明显缺报或范围错误。"
        else local paragraph4 "发现的问题：`integrity_issue'。"

        local integrity_impact ""
        if `failed_count' > 0 local integrity_impact "检验失败会使相应模型选择或识别判断无法复核"
        if `invalid_count' > 0 {
            if "`integrity_impact'" == "" local integrity_impact "数值错误会使诊断结论无法复核"
            else local integrity_impact "`integrity_impact'；数值错误会使诊断结论无法复核"
        }
        if `corr_rows' == 0 & `vif_rows' == 0 & `panel_rows' == 0 & `iv_rows' == 0 {
            if "`integrity_impact'" == "" local integrity_impact "没有诊断统计量就无法判断共线性、面板设定或工具变量强度"
            else local integrity_impact "`integrity_impact'；没有诊断统计量就无法判断共线性、面板设定或工具变量强度"
        }
        if "`integrity_impact'" == "" local paragraph5 "可能影响：当前表未触发诊断结果缺报或数值范围风险；模型选择仍需结合研究设计。"
        else local paragraph5 "可能影响：`integrity_impact'。"

        local diagnostic_recommendations ""
        if `high_corr' > 0 local diagnostic_recommendations "核对高相关变量的定义，分别估计、合并或按理论保留其一，并比较系数变化"
        if `high_vif' > 0 {
            if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "检查控制变量组合和固定效应，报告替代设定下的系数与标准误"
            else local diagnostic_recommendations "`diagnostic_recommendations'；检查控制变量组合和固定效应，报告替代设定下的系数与标准误"
        }
        if `first_stage_f' < 10 & !missing(`first_stage_f') {
            if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "补充弱工具稳健推断或更换/增加工具变量，并论证排除限制"
            else local diagnostic_recommendations "`diagnostic_recommendations'；补充弱工具稳健推断或更换/增加工具变量，并论证排除限制"
        }
        if `failed_count' > 0 | `invalid_count' > 0 {
            if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "回到原始命令核对失败或异常行后再作模型选择"
            else local diagnostic_recommendations "`diagnostic_recommendations'；回到原始命令核对失败或异常行后再作模型选择"
        }
        if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "结合识别设计确认模型选择和标准误设定"
        local paragraph6 "处理建议：`diagnostic_recommendations'。"

        local summary_text "`diagnostic_results'。"
        if "`diagnostic_issues'" != "" local summary_text "`summary_text'主要问题：`diagnostic_issues'。"
        if "`integrity_issue'" != "" local summary_text "`summary_text'表内核对问题：`integrity_issue'。"
        if "`diagnostic_issues'" == "" & "`integrity_issue'" == "" local summary_text "`summary_text'未发现可由本表直接识别的明显问题。"

        * Emit one result-driven paragraph in the same order as the
        * descriptive and regression modules.
        local diagnostics_issues "`diagnostic_issues'"
        if "`integrity_issue'" != "" {
            if "`diagnostics_issues'" == "" local diagnostics_issues "`integrity_issue'"
            else local diagnostics_issues "`diagnostics_issues'；`integrity_issue'"
        }
        local diagnostics_impacts "`diagnostic_impacts'"
        if "`integrity_impact'" != "" {
            if "`diagnostics_impacts'" == "" local diagnostics_impacts "`integrity_impact'"
            else local diagnostics_impacts "`diagnostics_impacts'；`integrity_impact'"
        }
        local diagnostics_text "结果解读：`diagnostic_results'。"
        if "`diagnostics_issues'" == "" local diagnostics_text "`diagnostics_text'未发现表内可由当前诊断值直接识别的明显问题；"
        else local diagnostics_text "`diagnostics_text'发现的问题：`diagnostics_issues'；可能影响：`diagnostics_impacts'；"
        local diagnostics_text "`diagnostics_text'处理建议：`diagnostic_recommendations'。"
        local paragraph1 = strtrim("`diagnostics_text'")
        forvalues clear_index = 2/6 {
            local paragraph`clear_index' ""
        }
        local summary_text ""
    }

    * Append one compact, result-driven paragraph after the table.  The table
    * remains untouched; all issue/impact/recommendation text is kept together
    * so the output can be read without a long template-style appendix.
    forvalues index = 1/6 {
        if strtrim(`"`paragraph`index''"') != "" {
            local narrative_text "`paragraph`index''"
            file write `handle' "\pard\qj\fi420\sb120\sa0\sl360\slmult1\f0\fs18 "
            local remaining_text `"`narrative_text'"'
            while ustrlen(`"`remaining_text'"') > 0 {
                local text_chunk = usubstr(`"`remaining_text'"', 1, 160)
                _journalone_rtf_escape, text(`"`text_chunk'"')
                file write `handle' "`r(escaped)'"
                local remaining_text = usubstr(`"`remaining_text'"', 161, .)
            }
            file write `handle' "\par" _n
        }
    }
end
