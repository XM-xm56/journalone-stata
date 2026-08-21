*! version 0.9.8 17aug2026

capture program drop _journalone_write_desc_rtf
program define _journalone_write_desc_rtf
    version 16.0
    syntax , FILE(string) TITLE(string) [DECIMALS(integer 3)]
    sort variable_order
    quietly count
    if r(N) == 0 exit 2000

    * Keep the Chinese table/file names; only the statistical headers are English.
    local output_title `"`title'"'
    if inlist(strtrim(`"`title'"'), "描述性统计分析", "描述性统计") {
        local output_title "表 A1：描述性统计"
    }
    _journalone_rtf_escape, text(`"`output_title'"')
    local rtf_title `"`r(escaped)'"'
    local header1 "Variable"
    local header2 "N"
    local header3 "Mean"
    local header4 "SD"
    local header5 "Min"
    local header6 "Max"
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
    local descriptive_tabs "\tqr\tx4400\tqr\tx5900\tqr\tx7400\tqr\tx8900\tqr\tx10400"
    file write `rtf_handle' "\pard\keepn\sb0\sa0\sl360\slmult1\brdrt\brdrs\brdrw20\brsp20\brdrb\brdrs\brdrw10\brsp20`descriptive_tabs'\ql\b `rtf_header1'\b0"
    forvalues column = 2/6 {
        file write `rtf_handle' "\tab\b `rtf_header`column''\b0"
    }
    file write `rtf_handle' "\par" _n

    local number_format "%21.`decimals'f"
    forvalues row = 1/`=_N' {
        local cell1 = variable[`row']
        local cell2 = strtrim(string(N_nonmissing[`row'], "%12.0f"))
        local cell3 = strtrim(string(mean[`row'], "`number_format'"))
        local cell4 = strtrim(string(sd[`row'], "`number_format'"))
        local cell5 = strtrim(string(min[`row'], "`number_format'"))
        local cell6 = strtrim(string(max[`row'], "`number_format'"))
        forvalues column = 1/6 {
            _journalone_rtf_escape, text(`"`cell`column''"')
            local rtf_cell`column' `"`r(escaped)'"'
        }
        local bottom_border ""
        if `row' == _N local bottom_border "\brdrb\brdrs\brdrw20\brsp20"
        file write `rtf_handle' "\pard\keep\sb0\sa0\sl360\slmult1`bottom_border'`descriptive_tabs'\ql `rtf_cell1'"
        forvalues column = 2/6 {
            file write `rtf_handle' "\tab `rtf_cell`column''"
        }
        file write `rtf_handle' "\par" _n
    }
    local raw_note "注：N为非缺失观测数；变量按用户设定顺序报告，左列使用Stata中的原始变量名，不使用变量标签且不进行翻译。"
    _journalone_rtf_escape, text(`"`raw_note'"')
    local rtf_note `"`r(escaped)'"'
    file write `rtf_handle' "\pard\ql\f0\fs18\sb0\sa0\sl360\slmult1 `rtf_note'\par" _n
    _journalone_append_rtf_analysis, handle(`rtf_handle') type(descriptive) ///
        title(`"`title'"') decimals(`decimals')
    file write `rtf_handle' "}" _n
    file close `rtf_handle'
end
