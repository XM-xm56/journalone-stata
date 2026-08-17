*! version 0.9.8 17aug2026

capture program drop _journalone_write_diag_rtf
program define _journalone_write_diag_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3)]

    sort row_order col_order
    quietly count
    if r(N) == 0 exit 2000

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    local header1 "类别"
    local header2 "检验或变量"
    local header3 "对照变量"
    local header4 "数值"
    local header5 "P值"
    local header6 "N"
    forvalues column = 1/6 {
        _journalone_rtf_escape, text(`"`header`column''"')
        local rtf_header`column' `"`r(escaped)'"'
    }

    tempname rtf_handle
    file open `rtf_handle' using `"`file'"', write text replace
    file write `rtf_handle' "{\rtf1\ansi\ansicpg1252\deff0\uc1\viewkind4" _n
    file write `rtf_handle' "{\fonttbl{\f0\fnil\fcharset0 Times New Roman;}}" _n
    file write `rtf_handle' "\paperw11907\paperh16840\margl720\margr720\margt720\margb720" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\b\f0\fs24 `rtf_title'\b0\par" _n
    file write `rtf_handle' "\pard\qc\sb0\sa0\sl360\slmult1\f0\fs18\par" _n
    local tabs "\tqr\tx2450\tqr\tx5550\tqr\tx7350\tqr\tx8650\tqr\tx9700\tqr\tx10400"
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`tabs'\ql\b `rtf_header1'\b0"
    forvalues column = 2/6 {
        file write `rtf_handle' "\tab\b `rtf_header`column''\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    forvalues row = 1/`=_N' {
        local cell1 = analysis_section[`row']
        local cell2 = test[`row']
        if strtrim(variable1[`row']) != "" {
            if strtrim(`"`cell2'"') == "" local cell2 = variable1[`row']
            else local cell2 `"`cell2': `=variable1[`row']'"'
        }
        local cell3 = variable2[`row']
        local cell4 "—"
        if statistic[`row'] < . {
            local cell4 = strtrim(string(statistic[`row'], "`number_format'"))
            if strtrim(stars[`row']) != "" local cell4 `"`cell4'`=stars[`row']'"'
        }
        local cell5 "—"
        if p_value[`row'] < . local cell5 = strtrim(string(p_value[`row'], "%9.4f"))
        local cell6 "—"
        if N[`row'] < . local cell6 = strtrim(string(N[`row'], "%12.0f"))
        forvalues column = 1/6 {
            _journalone_rtf_escape, text(`"`cell`column''"')
            local rtf_cell`column' `"`r(escaped)'"'
        }
        local bottom_border ""
        if `row' == _N local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`tabs'\ql `rtf_cell1'"
        forvalues column = 2/6 {
            file write `rtf_handle' "\tab `rtf_cell`column''"
        }
        file write `rtf_handle' "\par" _n
    }

    local raw_note "注：相关系数报告双侧P值，*、**、***分别表示10%、5%、1%显著性水平；VIF基于未吸收的解释变量；面板检验使用常规协方差重新估计；IV第一阶段统计量用于诊断，不自动证明工具变量有效。变量名保持Stata原名。"
    _journalone_rtf_escape, text(`"`raw_note'"')
    local rtf_note `"`r(escaped)'"'
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `rtf_note'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(diagnostics) ///
        title(`"`title'"') decimals(`decimals')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
