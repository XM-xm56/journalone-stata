*! version 0.9.14 18aug2026

capture program drop _journalone_parse_customspecs
program define _journalone_parse_customspecs, rclass
    version 16.0
    * Keep a finite guard against accidental specification explosions while
    * allowing the multi-column robustness and heterogeneity tables used in
    * published empirical work.
    syntax , SPECS(string) [MAX(integer 40) NOCHECK]

    if `max' < 1 exit 198

    * One custom column is Y|X or Y|X|sample-condition.  Semicolons separate
    * columns; the two-field form remains fully backward compatible.
    * Full-width delimiters are normalized because they are common in Chinese input.
    local remaining = subinstr(`"`specs'"', char(34), "", .)
    local remaining = subinstr(`"`remaining'"', "；", ";", .)
    local remaining = subinstr(`"`remaining'"', "｜", "|", .)
    local remaining = strtrim(`"`remaining'"')
    local count = 0

    while `"`remaining'"' != "" {
        gettoken one remaining : remaining, parse(";")
        if substr(`"`remaining'"', 1, 1) == ";" {
            local remaining = substr(`"`remaining'"', 2, .)
        }
        local one = strtrim(`"`one'"')
        if `"`one'"' == "" continue

        gettoken custom_y custom_remainder : one, parse("|")
        if substr(`"`custom_remainder'"', 1, 1) == "|" {
            local custom_remainder = substr(`"`custom_remainder'"', 2, .)
        }
        gettoken custom_x custom_if : custom_remainder, parse("|")
        if substr(`"`custom_if'"', 1, 1) == "|" local custom_if = substr(`"`custom_if'"', 2, .)
        local custom_y = strtrim(`"`custom_y'"')
        local custom_x = strtrim(`"`custom_x'"')
        local custom_if = strtrim(`"`custom_if'"')
        if `"`custom_y'"' == "" | `"`custom_x'"' == "" | ///
            strpos(`"`custom_if'"', "|") {
            display as error "自定义规格格式应为 Y|X 或 Y|X|样本条件；多列用英文分号 ; 分隔"
            exit 198
        }
        if "`nocheck'" == "" {
            capture confirm variable `custom_y'
            if _rc {
                display as error "自定义规格的被解释变量不存在：`custom_y'"
                exit 111
            }
        }

        local ++count
        if `count' > `max' {
            display as error "自定义规格最多允许 `max' 列"
            exit 198
        }
        return local depvar`count' `"`custom_y'"'
        return local indepvars`count' `"`custom_x'"'
        return local ifcond`count' `"`custom_if'"'
    }

    if `count' == 0 {
        display as error "customspecs() 至少需要一列 Y|X"
        exit 198
    }
    return scalar count = `count'
end
