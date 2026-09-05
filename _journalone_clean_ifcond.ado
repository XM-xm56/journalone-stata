*! version 0.1.0 27aug2026

capture program drop _journalone_clean_ifcond
program define _journalone_clean_ifcond, rclass
    version 16.0
    * Normalize an option passed through one or more compound-quote layers.
    * Double quotes inside a string comparison must survive (for example
    *   是否是制造业=="C"
    *); only transport delimiters at the outside are removed.
    syntax , VALUE(string asis)

    local val : copy local value
    local bt = char(96)
    local ap = char(39)
    local dq = char(34)
    local qmark "__JO_DQ__"
    local bmark "__JO_BT__"
    local amark "__JO_AP__"

    * Replace delimiter characters with safe sentinels before inspecting the
    * first/last characters; this avoids Stata's nested-quote parser.
    local val : subinstr local val `"`dq'"' "`qmark'", all
    local val : subinstr local val "`bt'" "`bmark'", all
    local val : subinstr local val "`ap'" "`amark'", all
    local blen = strlen("`bmark'")
    local alen = strlen("`amark'")
    local qlen = strlen("`qmark'")
    * Remove matching outer transport layers.  Values can be forwarded
    * through several syntax(string asis) calls, so compound and quote layers
    * are peeled repeatedly while internal quote characters remain untouched.
    local changed 1
    while `changed' {
        local changed 0
        local n : length local val
        if `n' >= `blen'+`alen' & substr("`val'",1,`blen') == "`bmark'" & ///
            substr("`val'",-`alen',`alen') == "`amark'" {
            local val = substr("`val'", `blen'+1, `n'-`blen'-`alen')
            local changed 1
        }
        local n : length local val
        if `n' >= 2*`qlen' & substr("`val'",1,`qlen') == "`qmark'" & ///
            substr("`val'",-`qlen',`qlen') == "`qmark'" {
            local val = substr("`val'", `qlen'+1, `n'-2*`qlen')
            local changed 1
        }
    }
    * Restore the literal double quotes used by string-valued variables.
    local val : subinstr local val "`qmark'" `"`dq'"', all
    return local value `"`val'"'
end
