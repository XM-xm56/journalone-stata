*! version 0.7.0 15aug2026

capture program drop _journalone_write_reg_rtf
program define _journalone_write_reg_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3) STATISTIC(string) ///
        PSTAR1(real .01) PSTAR2(real .05) PSTAR3(real .10)]
    if "`statistic'" == "" local statistic "se"
    sort specification_order term_order
    quietly count
    if r(N) == 0 exit 2000

    _journalone_rtf_escape, text(`"`title'"')
    local rtf_title `"`r(escaped)'"'
    local header1 "模型"
    local header2 "因变量"
    local header3 "变量"
    local header4 "系数"
    if "`statistic'" == "t" local header5 "t值"
    else local header5 "标准误"
    local header6 "p值"
    local header7 "N"
    local header8 "R²"
    forvalues column = 1/8 {
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
    local regression_tabs "\tx2200\tx3400\tqr\tx5700\tqr\tx6900\tqr\tx8000\tqr\tx9100\tqr\tx10400"
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`regression_tabs'\ql\b `rtf_header1'\b0"
    file write `rtf_handle' "\tab\b `rtf_header2'\b0"
    file write `rtf_handle' "\tab\b `rtf_header3'\b0"
    forvalues column = 4/8 {
        file write `rtf_handle' "\tab\b `rtf_header`column''\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    forvalues row = 1/`=_N' {
        local cell1 = specification_label[`row']
        local cell2 = outcome[`row']
        local cell3 = term_label[`row']
        local stars ""
        if !missing(p_value[`row']) {
            if p_value[`row'] <= `pstar1' local stars "***"
            else if p_value[`row'] <= `pstar2' local stars "**"
            else if p_value[`row'] <= `pstar3' local stars "*"
        }
        local cell4 = strtrim(string(estimate[`row'], "`number_format'")) + "`stars'"
        if "`statistic'" == "t" {
            local cell5 = strtrim(string(estimate[`row']/std_error[`row'], "`number_format'"))
        }
        else local cell5 = strtrim(string(std_error[`row'], "`number_format'"))
        local cell6 = strtrim(string(p_value[`row'], "`number_format'"))
        local cell7 = strtrim(string(N[`row'], "%12.0f"))
        local cell8 = ""
        if !missing(r2[`row']) local cell8 = strtrim(string(r2[`row'], "`number_format'"))
        forvalues column = 1/8 {
            _journalone_rtf_escape, text(`"`cell`column''"')
            local rtf_cell`column' `"`r(escaped)'"'
        }
        local bottom_border ""
        if `row' == _N local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`regression_tabs'\ql `rtf_cell1'"
        file write `rtf_handle' "\tab `rtf_cell2'"
        file write `rtf_handle' "\tab `rtf_cell3'"
        forvalues column = 4/8 {
            file write `rtf_handle' "\tab `rtf_cell`column''"
        }
        file write `rtf_handle' "\par" _n
    }
    local raw_note "注：***、**、*分别表示p≤`pstar1'、p≤`pstar2'、p≤`pstar3'；变量名称按估计结果原文显示，不进行翻译。"
    _journalone_rtf_escape, text(`"`raw_note'"')
    local rtf_note `"`r(escaped)'"'
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `rtf_note'\par" _n
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
