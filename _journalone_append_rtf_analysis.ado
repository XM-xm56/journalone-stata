*! version 0.9.18 05sep2026

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
        local max_missing_rate = .
        local max_missing_variable ""

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
                    }
                }
            }
        }
        local zero_sd_names = strtrim("`zero_sd_names'")

        local sample_detail "结果表明，本表报告`variable_count'个变量，非缺失观测数介于`n_min_display'至`n_max_display'。"
        if `total_slots' > 0 {
            local missing_rate = 100*`total_missing'/`total_slots'
            local missing_display = strtrim(string(`missing_rate', "%9.1f"))
            local max_missing_display = strtrim(string(`max_missing_rate', "%9.1f"))
            local missing_assessment "整体缺失较少"
            if `missing_rate' > 5 & `missing_rate' <= 20 local missing_assessment "存在一定缺失"
            if `missing_rate' > 20 local missing_assessment "缺失比例较高"
            local missing_detail "总体缺失比例为`missing_display'%（`missing_assessment'），其中`max_missing_variable'的缺失比例最高，为`max_missing_display'%。"
        }
        else local missing_detail "当前表未提供统一总样本量，因此不能直接计算总体缺失比例。"

        local variation_detail "主要统计量未见明显数值异常；极值是否合理仍需结合变量定义和单位判断。"
        if `zero_sd_count' > 0 {
            local zero_sd_summary "变量`zero_sd_names'的标准差为0，在当前样本中没有变化，进入回归前应复核。"
            if `zero_sd_count' > 5 local zero_sd_summary "共有`zero_sd_count'个变量的标准差为0，包括`zero_sd_names'等，在当前样本中没有变化，进入回归前应复核。"
            local variation_detail "`zero_sd_summary'其余均值、标准差和极值仍需结合变量定义判断。"
        }

        local paragraph1 "描述性统计用于概括样本中各变量的中心位置、离散程度和取值范围。`sample_detail'"
        local paragraph2 "样本完整性检查结果为：`missing_detail'缺失处理方式应与研究设计保持一致，不能只根据非缺失样本量直接判断样本代表性。"
        local paragraph3 "变量分布检查结果为：`variation_detail'"
        if `invalid_count' == 0 {
            local paragraph4 "数据质量校验未发现样本量为负、均值超出极值范围或标准差为负等明显数值错误。"
        }
        else local paragraph4 "数据质量校验发现`invalid_count'处样本量、缺失数或取值范围关系需要核对，建议在回归前回到原始数据复查。"
        local paragraph5 "均值和标准差描述的是样本内分布，最小值和最大值用于发现极端取值；它们不能单独说明变量之间的因果关系，也不能替代异常值、缩尾或变换处理的敏感性分析。"
        local paragraph6 "描述性统计的最终解释应结合变量单位、测量口径、样本筛选和缺失处理规则；若变量没有足够变异或极值明显异常，应先完成数据核验再进入后续模型。"

        local summary_text "重点结果为：`sample_detail'`missing_detail'`variation_detail'"
        if `invalid_count' > 0 local summary_text "`summary_text'另有`invalid_count'处数据质量关系需要复核。"
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

        local module_intro "回归分析用于考察解释变量与被解释变量在既定模型中的条件相关关系。"
        if "`type'" == "baseline" {
            local module_intro "基准回归用于考察核心解释变量与被解释变量在既定模型中的关系。表中各列依次对应界面中的模型1至模型6，控制变量、固定效应、样本和标准误设置以实际填写内容为准，而不是自动假定后一列一定比前一列增加控制变量。"
        }
        else if strpos("`title'", "稳健") {
            local module_intro "稳健性检验用于观察核心结论在替换变量、调整样本、改变固定效应或标准误等预先设定的替代规格下是否保持稳定。"
        }
        else if strpos("`title'", "内生") {
            local module_intro "内生性检验用于评估反向因果、遗漏变量或样本选择等问题是否可能影响基准结论；不同方法对应不同识别假设，不能仅凭系数显著就认定内生性已经解决。"
        }
        else if strpos("`title'", "机制") {
            local module_intro "机制检验用于考察核心解释变量影响被解释变量的可能路径。中介、调节或分步回归首先反映变量之间的条件关联，只有在相应识别假设成立时才能进一步作因果机制解释。"
        }
        else if strpos("`title'", "异质") {
            local module_intro "异质性分析用于比较核心关系在不同样本组或不同条件下是否存在差别。单独一组显著、另一组不显著并不等于两组系数显著不同，仍应结合正式的组间系数检验。"
        }
        else if strpos("`title'", "显著组合") {
            local module_intro "规格组合结果用于比较预先登记的不同模型设定，而不是从大量模型中只保留显著结果；显著和不显著规格都应共同报告。"
        }
        local paragraph1 "`module_intro'本表共报告`specification_count'个估计规格，并以每个规格中排序最靠前的非常数项作为主要关注项。"
        if "`focus_details'" != "" local paragraph2 "`focus_details'。"

        local paragraph3 "主要关注项中，分别有`sig1_count'个、`sig2_count'个和`sig3_count'个达到`p1_display'%、`p2_display'%和`p3_display'%显著性水平。正系数表示在其他模型设定保持不变时两者呈正向条件关系，负系数表示负向条件关系；统计显著只反映样本证据强弱，不等同于经济影响一定重要。"

        local invalid_count = 0
        local zero_se_count = 0
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

        quietly summarize N if N < ., meanonly
        local n_min = r(min)
        local n_max = r(max)
        local n_min_display = strtrim(string(`n_min', "%12.0f"))
        local n_max_display = strtrim(string(`n_max', "%12.0f"))
        local sample_note "各规格使用相同样本量，为`n_min_display'"
        if `n_min' != `n_max' local sample_note "各规格样本量介于`n_min_display'至`n_max_display'，跨模型比较时应注意样本变化"

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
            local fit_note "；表中可用拟合优度介于`fit_min_display'至`fit_max_display'，它反映样本内拟合程度，但不能单独证明模型设定正确"
        }
        local paragraph4 "从结果稳定性看，`sample_note'；`stability_note'`fit_note'。"

        if `invalid_count' == 0 {
            local paragraph5 "表内未发现标准误为负、P值超出0至1、样本量非正、置信区间上下限倒置或拟合优度大于1等明显数值错误。"
        }
        else local paragraph5 "表内发现`invalid_count'处需要复核的数值异常，可能涉及标准误、P值、样本量、置信区间或拟合优度；应在形成论文结论前核对估计命令和原始结果。"
        if `zero_se_count' > 0 local paragraph5 "`paragraph5'另有`zero_se_count'个系数的标准误为0，应检查参考组、完全共线、被省略项或参数可识别性。"

        local paragraph6 "系数方向和显著性只有在变量构造、样本选择、固定效应、标准误设定和识别假设合理时才具有可信解释；如果研究设计不能排除内生性，应使用相关关系表述，不直接写成促进、抑制或导致。"
        if strpos("`title'", "稳健") local paragraph6 "稳健性检验只能说明结论对表中已经实施的替代设定是否敏感，不能覆盖所有可能的模型错误；如方向或显著性变化较大，应如实报告并解释变化来源。"
        if strpos("`title'", "内生") local paragraph6 "工具变量、PSM、Heckman、动态GMM和DML分别依赖不同假设；系数显著不能替代工具变量相关性与排除限制、共同支撑、选择方程或正交化条件的检验和论证。"
        if strpos("`title'", "机制") local paragraph6 "机制成立通常需要理论路径和相应方程共同支持；中介变量显著或交互项显著本身不自动证明因果机制，应避免把关联路径写成已经证实的传导机制。"
        if strpos("`title'", "异质") local paragraph6 "解释异质性时应同时报告各组样本量、置信区间和正式组间差异检验，避免仅依据一组有星、另一组无星就认定存在显著差异。"
        if strpos("`title'", "显著组合") local paragraph6 "规格数量越多，多重检验和选择性报告风险越高；应保留全部预先允许的规格，并把该表作为敏感性诊断而不是寻找显著模型的工具。"

        if "`focus_details'" != "" {
            local summary_text "重点结果为：`focus_details'。总体看，`stability_note'；`sample_note'。"
        }
        else {
            local summary_text "本表共报告`specification_count'个规格，但未识别到可自动解读的非常数核心系数。"
        }
        if `invalid_count' > 0 {
            local summary_text "`summary_text'另有`invalid_count'处数值异常需要复核。"
        }
        if `zero_se_count' > 0 {
            local summary_text "`summary_text'其中`zero_se_count'个系数的标准误为0，应检查共线性、省略项或可识别性。"
        }
        local concise_caveat "系数首先表示条件相关，因果解释仍取决于研究设计与识别假设。"
        if strpos("`title'", "稳健") local concise_caveat "若核心系数的方向或显著性发生变化，说明结论对替代设定较敏感。"
        if strpos("`title'", "内生") local concise_caveat "是否缓解内生性仍需结合所用方法的识别假设和诊断检验判断。"
        if strpos("`title'", "机制") local concise_caveat "路径显著只提供机制证据，不能单独证明因果传导机制成立。"
        if strpos("`title'", "异质") local concise_caveat "组间差异应以正式系数检验判断，不能只比较两组是否带星。"
        if strpos("`title'", "显著组合") local concise_caveat "应保留全部预设规格，避免只报告显著结果。"
        local summary_text "`summary_text'`concise_caveat'"
        if inlist("`type'", "baseline", "regression") {
            local design_note "表中的控制变量、时间固定效应和个体固定效应行按各列实际估计设定报告；‘是’仅表示该项进入估计式，不自动等于识别假设成立。"
            local summary_text "`summary_text'`design_note'"
        }
        if strpos("`title'", "稳健") {
            local robustness_note "比较稳健性时应同时观察核心系数的方向、显著性、样本量和调整后R²；若只替换变量、滞后期、样本或固定效应而结论仍稳定，才可表述为对这些已实施替代设定不敏感。"
            local summary_text "`summary_text'`robustness_note'"
        }
        * Append the multi-equation explanation after the main summary is
        * assembled; adding it earlier would be overwritten by focus_details.
        if strpos("`title'", "内生") & (`iv_stage_count' | `heckman_stage_count') {
            local stage_note "本表把多阶段估计按方程分别列出：IV第一阶段报告内生变量对工具变量的回归及排除工具变量联合F值，IV第二阶段报告结构方程；Heckman第一阶段为选择方程Probit，第二阶段为结果方程并保留逆米尔斯比率。第一阶段与第二阶段的被解释变量不同，不能将两列系数直接作大小比较。"
            local summary_text "`summary_text'`stage_note'"
        }
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

        forvalues row = 1/`=_N' {
            if analysis_section[`row'] == "相关性分析" & ///
                variable1[`row'] != variable2[`row'] & !missing(statistic[`row']) {
                local this_abs_corr = abs(statistic[`row'])
                if `this_abs_corr' >= .8 local ++high_corr
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

        if `corr_rows' > 0 {
            if !missing(`max_corr_abs') {
                local max_corr_display = strtrim(string(`max_corr_value', "%21.`decimals'f"))
                local paragraph1 "相关性分析用于观察变量之间的两两线性关系。除变量与自身的相关系数外，绝对值最大的相关系数为`max_corr_display'，出现在`max_corr_var1'与`max_corr_var2'之间；绝对值达到0.8的变量对共有`high_corr'组。表中星号对应双侧检验的10%、5%和1%显著性水平，但相关显著不代表因果关系。"
            }
            else local paragraph1 "相关性表未包含可比较的非对角变量对，因此暂不能判断变量之间的两两线性关系。"
        }

        if `vif_rows' > 0 {
            local max_vif_display = strtrim(string(`max_vif', "%21.`decimals'f"))
            local mean_vif_text ""
            if !missing(`mean_vif') {
                local mean_vif_display = strtrim(string(`mean_vif', "%21.`decimals'f"))
                local mean_vif_text "，平均VIF为`mean_vif_display'"
            }
            local paragraph2 "VIF用于诊断解释变量之间的多重共线性。本表最大VIF为`max_vif_display'，对应变量`max_vif_variable'`mean_vif_text'；VIF不低于10的变量有`high_vif'个，介于5至10的变量有`moderate_vif'个。相关系数低于0.8或VIF较低只能说明未触发常用经验预警，不能据此断言完全不存在共线性。"
        }

        if `panel_rows' > 0 & "`panel_text'" != "" {
            local paragraph3 "面板模型选择结果为：`panel_text'。固定效应F检验、随机效应LM检验和Hausman检验的原假设不同，应逐项解释；模型选择还应结合个体异质性、研究目的和标准误设定，而不是只看某一个P值。"
        }

        if `iv_rows' > 0 {
            local iv_detail ""
            if !missing(`first_stage_partial_r2') {
                local partial_display = strtrim(string(`first_stage_partial_r2', "%21.`decimals'f"))
                local iv_detail "第一阶段部分R²为`partial_display'"
            }
            if !missing(`first_stage_f') {
                local f_display = strtrim(string(`first_stage_f', "%21.`decimals'f"))
                if "`iv_detail'" == "" local iv_detail "排除工具变量的第一阶段F为`f_display'"
                else local iv_detail "`iv_detail'，排除工具变量的第一阶段F为`f_display'"
                if `first_stage_f' < 10 local iv_detail "`iv_detail'，低于常用的10这一经验参考值，存在弱工具变量风险"
                else local iv_detail "`iv_detail'，未低于常用的10这一经验参考值"
            }
            if "`iv_detail'" == "" local iv_detail "当前表未报告可自动概括的第一阶段部分R²或F统计量"
            local paragraph4 "工具变量诊断显示，`iv_detail'。第一阶段较强只说明相关性证据，不能自动证明排除限制和工具变量外生性；恰好识别时也无法使用过度识别检验验证这些假设。"
        }

        if `invalid_count' == 0 {
            local paragraph5 "表内未发现相关系数超出负1至1、P值超出0至1或样本量非正等明显数值错误，诊断结果在统计口径上基本自洽。"
        }
        else local paragraph5 "表内发现`invalid_count'处需要复核的数值异常，可能涉及相关系数、P值或样本量；应先核对原始结果再进行模型判断。"

        local paragraph6 "这些诊断用于发现风险而不是自动选择模型或删除变量。未触发0.8、VIF=10或第一阶段F=10等经验阈值，不代表模型设定、外生性或因果识别已经成立；最终判断仍需结合理论、变量定义和研究设计。"

        local diagnostic_parts ""
        if `corr_rows' > 0 {
            if !missing(`max_corr_abs') {
                local diagnostic_parts "相关性方面，`max_corr_var1'与`max_corr_var2'的相关系数绝对值最大，为`max_corr_display'，|r|达到0.8的变量对有`high_corr'组"
            }
        }
        if `vif_rows' > 0 {
            local one_part "共线性方面，最大VIF为`max_vif_display'（`max_vif_variable'），VIF不低于10的变量有`high_vif'个"
            if "`diagnostic_parts'" == "" local diagnostic_parts "`one_part'"
            else local diagnostic_parts "`diagnostic_parts'；`one_part'"
        }
        if `panel_rows' > 0 & "`panel_text'" != "" {
            local one_part "面板模型检验显示：`panel_text'"
            if "`diagnostic_parts'" == "" local diagnostic_parts "`one_part'"
            else local diagnostic_parts "`diagnostic_parts'；`one_part'"
        }
        if `iv_rows' > 0 {
            local one_part "工具变量诊断显示，`iv_detail'"
            if "`diagnostic_parts'" == "" local diagnostic_parts "`one_part'"
            else local diagnostic_parts "`diagnostic_parts'；`one_part'"
        }
        if "`diagnostic_parts'" == "" {
            local summary_text "当前诊断表没有可自动概括的有效统计量。"
        }
        else local summary_text "重点诊断为：`diagnostic_parts'。"
        if `invalid_count' > 0 {
            local summary_text "`summary_text'另有`invalid_count'处数值异常需要复核。"
        }
        local summary_text "`summary_text'这些阈值仅用于风险提示，不能单独证明模型设定或因果识别成立。"
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
