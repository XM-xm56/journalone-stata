*! version 0.9.20 06sep2026

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
        local duplicate_count = 0
        local duplicate_names ""
        local extreme_count = 0
        local extreme_names ""
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
            if !missing(sd[`row']) & sd[`row'] == 0 {
                local ++zero_sd_count
                if `zero_sd_count' <= 5 local zero_sd_names "`zero_sd_names' `=variable[`row']'"
            }

            * A repeated variable row is an output/data construction error, not
            * a substantive finding.  Keep the first occurrence in the list so
            * the explanation names the duplicated variables only once.
            local this_variable = variable[`row']
            local prior_duplicate = 0
            if `row' > 1 {
                forvalues prior = 1/`=`row'-1' {
                    if variable[`prior'] == "`this_variable'" local prior_duplicate = 1
                }
            }
            if `prior_duplicate' {
                local ++duplicate_count
                if !strpos(" `duplicate_names' ", " `this_variable' ") & ///
                    wordcount("`duplicate_names'") < 6 local duplicate_names "`duplicate_names' `this_variable'"
            }

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
                    if missing(`max_missing_rate') | `this_missing_rate' > `max_missing_rate' {
                        local max_missing_rate = `this_missing_rate'
                        local max_missing_variable = variable[`row']
                        local max_missing_count = `this_missing'
                    }
                }
            }

            * Flag only observations whose extrema are several SDs from the
            * mean.  This is deliberately worded as a potential issue: a
            * legitimate skewed variable can also meet this screen.
            if !missing(mean[`row']) & !missing(sd[`row']) & sd[`row'] > 0 & ///
                !missing(min[`row']) & !missing(max[`row']) {
                local max_z = (max[`row']-mean[`row'])/sd[`row']
                local min_z = (mean[`row']-min[`row'])/sd[`row']
                if `max_z' >= 5 | `min_z' >= 5 {
                    local ++extreme_count
                    if !strpos(" `extreme_names' ", " `this_variable' ") & ///
                        wordcount("`extreme_names'") < 6 local extreme_names "`extreme_names' `this_variable'"
                }
            }
        }
        local zero_sd_names = strtrim("`zero_sd_names'")
        local duplicate_names = strtrim("`duplicate_names'")
        local extreme_names = strtrim("`extreme_names'")

        local sample_detail "结果表明，本表报告`variable_count'个变量，非缺失观测数介于`n_min_display'至`n_max_display'。"
        if `total_slots' > 0 {
            local missing_rate = 100*`total_missing'/`total_slots'
            local missing_display = strtrim(string(`missing_rate', "%9.3f"))
            local max_missing_display = strtrim(string(`max_missing_rate', "%9.3f"))
            local missing_detail "总体缺失`total_missing'个观测，占变量-样本单元的`missing_display'%；`max_missing_variable'缺失`max_missing_count'个（`max_missing_display'），为表内最高。"
        }
        else local missing_detail "表中没有统一总样本量，无法从当前表核对缺失规模；请先补充每个变量的总样本数。"

        local variation_detail ""
        if `zero_sd_count' > 0 {
            local zero_sd_summary "`zero_sd_names'的标准差为0，当前样本没有可识别的变异"
            if `zero_sd_count' > 5 local zero_sd_summary "共有`zero_sd_count'个变量的标准差为0，包括`zero_sd_names'等，在当前样本中没有变化，进入回归前应复核。"
            else local variation_detail "`zero_sd_summary'"
        }
        if `extreme_count' > 0 {
            local extreme_detail "`extreme_names'的最大值或最小值距均值至少5个标准差，存在潜在极端值"
            if "`variation_detail'" == "" local variation_detail "`extreme_detail'"
            else local variation_detail "`variation_detail'；`extreme_detail'"
        }
        if "`variation_detail'" == "" {
            local variation_detail "按均值、标准差与极值的基本关系未发现可直接确认的异常。"
        }

        local paragraph1 "结果解读：`sample_detail'"
        local paragraph2 "发现的问题：`missing_detail'"
        local paragraph3 "可能影响："
        if `total_slots' > 0 & `total_missing' > 0 local paragraph3 "可能影响：缺失会使不同变量进入回归的有效样本不同，若缺失不是随机的，系数可能产生样本选择偏差；请在回归表中核对各列N。"
        else if `total_slots' > 0 local paragraph3 "可能影响：当前表没有缺失观测，未因缺失触发样本变化预警。"
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
            local invalid_recommendation "先回到原始数据核对异常记录，再运行后续模型"
            if "`desc_recommendations'" == "" local desc_recommendations "`invalid_recommendation'"
            else local desc_recommendations "`desc_recommendations'；`invalid_recommendation'"
        }
        if "`desc_issues'" == "" {
            local paragraph4 "发现的问题：按当前表的样本量、均值、标准差和极值关系，未发现重复行、无变异变量或潜在极端值预警。"
            local paragraph5 "可能影响：当前表不能排除变量定义、缺失机制或未显示分位数方面的问题。"
            local paragraph6 "处理建议：继续核对变量单位和原始数据，并在回归结果中比较各列有效样本量。"
        }
        else {
            local paragraph4 "发现的问题：`desc_issues'。"
            local paragraph5 "可能影响：`desc_impacts'。"
            local paragraph6 "处理建议：`desc_recommendations'。"
        }
        if `invalid_count' > 0 local paragraph6 "`paragraph6'另有`invalid_count'处统计量关系异常，先核对原始数据后再估计。"
        local summary_text "综合结论：`missing_detail'"
        if `duplicate_count' > 0 local summary_text "`summary_text'发现重复变量`duplicate_names'，应先去重。"
        if `extreme_count' > 0 local summary_text "`summary_text'`extreme_names'存在潜在极端值，需核验后决定是否处理。"
        if `zero_sd_count' > 0 local summary_text "`summary_text'`zero_sd_names'无变异，进入回归前应复核。"
        if `invalid_count' > 0 local summary_text "`summary_text'另有`invalid_count'处数值关系异常。"
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
                    local one_detail "`focus_label'：`focus_term'系数为`beta_display'（P=`p_display'，`direction_text'，`significance_text'）"
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
            local fit_note "；表中拟合优度介于`fit_min_display'至`fit_max_display'"
        }
        local paragraph1 "结果解读：本表报告`specification_count'个估计规格。"
        if "`focus_details'" != "" local paragraph1 "`paragraph1'主要关注项的表内系数为：`focus_details'。"
        else local paragraph1 "`paragraph1'表中没有可识别的非常数系数。"

        local issue_text ""
        if `missing_focus_count' > 0 local issue_text "有`missing_focus_count'个规格没有可比较的主要系数"
        if `positive_count' > 0 & `negative_count' > 0 {
            if "`issue_text'" == "" local issue_text "主要系数在规格间变号"
            else local issue_text "`issue_text'；主要系数在规格间变号"
        }
        if `focus_count' > 1 & `sig3_count' < `focus_count' {
            if "`issue_text'" == "" local issue_text "主要系数的10%显著性未在所有规格保持"
            else local issue_text "`issue_text'；主要系数的10%显著性未在所有规格保持"
        }
        if `n_observed' == 0 | (`n_observed' > 1 & `n_min' != `n_max') {
            if "`issue_text'" == "" local issue_text "规格样本量无法统一核对或发生变化"
            else local issue_text "`issue_text'；`sample_note'"
        }
        if `missing_p_count' > 0 {
            if "`issue_text'" == "" local issue_text "有`missing_p_count'个主要系数缺少P值"
            else local issue_text "`issue_text'；有`missing_p_count'个主要系数缺少P值"
        }
        if `zero_se_count' > 0 {
            if "`issue_text'" == "" local issue_text "有`zero_se_count'个非缺失系数的标准误为0"
            else local issue_text "`issue_text'；有`zero_se_count'个非缺失系数的标准误为0"
        }
        if `invalid_count' > 0 {
            if "`issue_text'" == "" local issue_text "表内有`invalid_count'处统计量关系异常"
            else local issue_text "`issue_text'；表内有`invalid_count'处统计量关系异常"
        }
        if "`issue_text'" == "" local paragraph2 "发现的问题：按当前表的系数、P值、标准误和N，未发现可直接识别的明显异常。"
        else local paragraph2 "发现的问题：`issue_text'。"

        local impact_text ""
        if `positive_count' > 0 & `negative_count' > 0 local impact_text "变号会使方向性结论依赖具体规格，不能把所有列概括为同一方向"
        if `focus_count' > 1 & `sig3_count' < `focus_count' {
            if "`impact_text'" == "" local impact_text "显著性变化意味着统计证据对设定较敏感"
            else local impact_text "`impact_text'；显著性变化意味着统计证据对设定较敏感"
        }
        if `n_observed' > 1 & `n_min' != `n_max' {
            if "`impact_text'" == "" local impact_text "样本变化会把模型设定差异与样本差异混在一起"
            else local impact_text "`impact_text'；样本变化会把模型设定差异与样本差异混在一起"
        }
        if `missing_p_count' > 0 {
            if "`impact_text'" == "" local impact_text "缺少P值时无法复核显著性判断"
            else local impact_text "`impact_text'；缺少P值时无法复核显著性判断"
        }
        if `zero_se_count' > 0 {
            if "`impact_text'" == "" local impact_text "零标准误可能来自完全共线、被省略项或不可识别参数"
            else local impact_text "`impact_text'；零标准误可能来自完全共线、被省略项或不可识别参数"
        }
        if `invalid_count' > 0 {
            if "`impact_text'" == "" local impact_text "数值关系异常会使表中结论无法复现"
            else local impact_text "`impact_text'；数值关系异常会使表中结论无法复现"
        }
        if "`impact_text'" == "" local paragraph3 "可能影响：当前表未触发上述风险；仍应结合变量单位和研究设计解释系数。"
        else local paragraph3 "可能影响：`impact_text'。"

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
        if `missing_p_count' > 0 local recommendation_text "`recommendation_text'补齐P值或由系数/标准误重新计算显著性；"
        if `zero_se_count' > 0 local recommendation_text "`recommendation_text'检查完全共线、参考组和被省略项；"
        if `invalid_count' > 0 local recommendation_text "`recommendation_text'回到原始估计命令核对异常行；"
        if "`recommendation_text'" == "" local recommendation_text "保留当前全部规格，并结合变量单位、置信区间和实际效应大小报告结果。"
        else local recommendation_text "`recommendation_text'"
        local paragraph4 "处理建议：`recommendation_text'"

        local paragraph5 "规格概况：`sample_note'`fit_note'。"
        local paragraph6 "结论："
        if "`issue_text'" == "" local paragraph6 "结论：当前表的主要系数方向和统计量没有触发自动风险提示，可以继续结合理论和识别设计写结果。"
        else local paragraph6 "结论：当前表存在上述可定位的结果风险，修正或解释前不宜把结论写成对所有规格都成立。"
        if strpos("`title'", "异质") local paragraph6 "`paragraph6'异质性还需报告正式组间系数检验，不能只比较两组星号。"
        if strpos("`title'", "机制") local paragraph6 "`paragraph6'机制路径应按各方程的实际系数和识别假设表述，不把单个显著中介项直接写成已证实因果机制。"
        if strpos("`title'", "内生") & (`iv_stage_count' | `heckman_stage_count') local paragraph6 "`paragraph6'多阶段结果应分别核对第一阶段/选择方程与结构方程，不能直接比较不同被解释变量的系数大小。"

        local summary_text "综合结论：`paragraph2'`paragraph3'`paragraph4'"
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

        local diagnostic_results ""
        if `corr_rows' > 0 & !missing(`max_corr_abs') local diagnostic_results "最大相关系数为`max_corr_display'（`max_corr_var1'与`max_corr_var2'）"
        if `vif_rows' > 0 {
            local one_result "最大VIF为`max_vif_display'（`max_vif_variable'）`mean_vif_text'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if `panel_rows' > 0 & "`panel_text'" != "" {
            local one_result "面板检验：`panel_text'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if `iv_rows' > 0 {
            local one_result "工具变量诊断：`iv_detail'"
            if "`diagnostic_results'" == "" local diagnostic_results "`one_result'"
            else local diagnostic_results "`diagnostic_results'；`one_result'"
        }
        if "`diagnostic_results'" == "" local diagnostic_results "当前表没有可用的相关性、VIF、面板或第一阶段统计量。"
        local paragraph1 "结果解读：`diagnostic_results'。"

        local diagnostic_issues ""
        if `high_corr' > 0 local diagnostic_issues "有`high_corr'组变量对的|r|达到0.8"
        if `high_vif' > 0 {
            if "`diagnostic_issues'" == "" local diagnostic_issues "有`high_vif'个变量的VIF不低于10"
            else local diagnostic_issues "`diagnostic_issues'；有`high_vif'个变量的VIF不低于10"
        }
        if `first_stage_f' < 10 & !missing(`first_stage_f') {
            if "`diagnostic_issues'" == "" local diagnostic_issues "第一阶段F为`f_display'，存在弱工具变量风险"
            else local diagnostic_issues "`diagnostic_issues'；第一阶段F为`f_display'，存在弱工具变量风险"
        }
        if `invalid_count' > 0 {
            if "`diagnostic_issues'" == "" local diagnostic_issues "有`invalid_count'处相关系数、P值或N超出可解释范围"
            else local diagnostic_issues "`diagnostic_issues'；有`invalid_count'处数值超出可解释范围"
        }
        if "`diagnostic_issues'" == "" local paragraph2 "发现的问题：当前诊断表未触发高相关、高VIF、弱第一阶段或明显数值错误预警。"
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
        if `invalid_count' > 0 {
            if "`diagnostic_impacts'" == "" local diagnostic_impacts "数值错误会使诊断结论无法复核"
            else local diagnostic_impacts "`diagnostic_impacts'；数值错误会使诊断结论无法复核"
        }
        if "`diagnostic_impacts'" == "" local paragraph3 "可能影响：当前诊断值没有显示上述风险，但这不替代对变量定义和识别假设的核验。"
        else local paragraph3 "可能影响：`diagnostic_impacts'。"

        local diagnostic_recommendations ""
        if `high_corr' > 0 local diagnostic_recommendations "核对高相关变量的定义，分别估计、合并或按理论保留其一，并比较系数变化"
        if `high_vif' > 0 {
            if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "检查控制变量组合和固定效应，报告替代设定下的系数与标准误"
            else local diagnostic_recommendations "`diagnostic_recommendations'；检查控制变量组合和固定效应，报告替代设定下的系数与标准误"
        }
        if `first_stage_f' < 10 & !missing(`first_stage_f') local diagnostic_recommendations "`diagnostic_recommendations'补充弱工具稳健推断或更换/增加工具变量，并论证排除限制；"
        if `invalid_count' > 0 local diagnostic_recommendations "`diagnostic_recommendations'回到原始命令核对异常行后再作模型选择；"
        if "`diagnostic_recommendations'" == "" local diagnostic_recommendations "保留当前诊断结果，结合研究设计核对模型选择和标准误设定。"
        local paragraph4 "处理建议：`diagnostic_recommendations'"
        local paragraph5 "数值核对："
        if `invalid_count' == 0 local paragraph5 "数值核对：表内相关系数、P值和样本量没有触发范围错误。"
        else local paragraph5 "数值核对：表内有`invalid_count'处统计量范围异常，必须先复核数据和估计命令。"
        local paragraph6 "结论："
        if "`diagnostic_issues'" == "" local paragraph6 "结论：当前诊断表未显示直接的共线性或工具变量强度风险，可以进入结合理论的模型判断。"
        else local paragraph6 "结论：当前诊断表已经显示上述风险，相关模型结论应在处理或解释这些风险后再报告。"
        local summary_text "综合结论：`paragraph2'`paragraph3'`paragraph4'"
    }

    * Write every generated explanation as its own numbered paragraph.  The
    * table remains untouched; only the narrative block appended after it is
    * formatted here.  Keeping the summary as a final paragraph preserves a
    * concise machine-checkable conclusion while the numbered paragraphs give
    * readers the detailed interpretation shown in the publication example.
    local narrative_number = 0
    forvalues index = 1/6 {
        if strtrim(`"`paragraph`index''"') != "" {
            local ++narrative_number
            local narrative_text "`narrative_number'. `paragraph`index''"
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
    if strtrim(`"`summary_text'"') != "" {
        file write `handle' "\pard\qj\fi420\sb120\sa0\sl360\slmult1\f0\fs18\b "
        local summary_label "综合判断："
        _journalone_rtf_escape, text(`"`summary_label'"')
        file write `handle' "`r(escaped)'\b0 "
        local remaining_text `"`summary_text'"'
        while ustrlen(`"`remaining_text'"') > 0 {
            local text_chunk = usubstr(`"`remaining_text'"', 1, 160)
            _journalone_rtf_escape, text(`"`text_chunk'"')
            file write `handle' "`r(escaped)'"
            local remaining_text = usubstr(`"`remaining_text'"', 161, .)
        }
        file write `handle' "\par" _n
    }
end
