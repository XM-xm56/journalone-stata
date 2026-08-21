*! version 0.1.0 19aug2026

capture program drop _journalone_lookup_map
program define _journalone_lookup_map, rclass
    version 16.0
    syntax , MAP(string asis) KEY(string)

    * Mapping syntax: key=value;key2=value2.  Full-width punctuation is
    * accepted because these strings are often entered from a Chinese GUI.
    local remaining = subinstr(strtrim(`"`map'"'), char(34), "", .)
    local remaining = subinstr(`"`remaining'"', "；", ";", .)
    local remaining = subinstr(`"`remaining'"', "＝", "=", .)
    local wanted = strtrim(`"`key'"')
    local found ""

    while `"`remaining'"' != "" {
        gettoken pair remaining : remaining, parse(";")
        if substr(`"`remaining'"', 1, 1) == ";" {
            local remaining = substr(`"`remaining'"', 2, .)
        }
        local pair = strtrim(`"`pair'"')
        if `"`pair'"' == "" continue

        gettoken lhs rhs : pair, parse("=")
        if substr(`"`rhs'"', 1, 1) == "=" {
            local rhs = substr(`"`rhs'"', 2, .)
        }
        local lhs = strtrim(`"`lhs'"')
        local rhs = strtrim(`"`rhs'"')
        if `"`lhs'"' == `"`wanted'"' {
            local found `"`rhs'"'
            continue, break
        }
    }
    return local value `"`found'"'
end
