*! version 0.8.0 15aug2026

capture program drop _journalone_add_spec_labels
program define _journalone_add_spec_labels
    version 16.0
    capture drop specification_label term_label
    generate str244 specification_label = specification
    replace specification_label = "基准模型" if specification == "main"
    replace specification_label = "基准模型（" + substr(specification,10,.) + "）" ///
        if substr(specification,1,9) == "baseline_"
    replace specification_label = "替换被解释变量：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "alt_y_"
    replace specification_label = "替换核心解释变量：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "alt_x_"
    replace specification_label = "增加控制变量" if specification == "additional_controls"
    replace specification_label = "增加固定效应" if specification == "additional_fe"
    replace specification_label = "替代样本" if specification == "subsample"
    replace specification_label = "核心变量滞后" + substr(specification,5,.) + "期" ///
        if substr(specification,1,4) == "lag_"
    replace specification_label = "核心变量超前" + substr(specification,6,.) + "期" ///
        if substr(specification,1,5) == "lead_"
    replace specification_label = "替代标准误" if specification == "alternative_vce"
    replace specification_label = "分位缩尾：" + substr(specification,8,.) ///
        if substr(specification,1,7) == "winsor_"
    replace specification_label = "平行趋势检验" if specification == "parallel_trend"
    replace specification_label = "PSM：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "psm_"
    replace specification_label = "Heckman两步法" if specification == "heckman_twostep"
    replace specification_label = "动态GMM：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "gmm_"
    replace specification_label = "双重机器学习：" + substr(specification,5,.) ///
        if substr(specification,1,4) == "dml_"
    replace specification_label = "机制路径A：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "med_a_"
    replace specification_label = "机制路径B：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "med_b_"
    replace specification_label = "调节效应：" + substr(specification,11,.) ///
        if substr(specification,1,10) == "moderator_"
    replace specification_label = "异质性分组：" + substr(specification,7,.) ///
        if substr(specification,1,6) == "group_"
    generate str244 term_label = term
end
