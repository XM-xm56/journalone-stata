*! version 0.7.0 15aug2026
capture program drop _journalone_rtf_escape
program define _journalone_rtf_escape, rclass
    version 16.0
    syntax [, TEXT(string)]

    local hex = ustrtohex(`"`text'"', 1)
    local escaped ""
    local position = 1
    local total = strlen(`"`hex'"')
    while `position' <= `total' {
        local marker = substr(`"`hex'"', `position', 2)
        if `"`marker'"' == "\u" {
            local digits = substr(`"`hex'"', `position'+2, 4)
            local codepoint = 0
            forvalues digit_index = 1/4 {
                local digit_char = lower(substr(`"`digits'"', `digit_index', 1))
                local digit_value = strpos("0123456789abcdef", `"`digit_char'"') - 1
                local codepoint = `codepoint'*16 + `digit_value'
            }
            local signed_codepoint = `codepoint'
            if `signed_codepoint' >= 32768 local signed_codepoint = `signed_codepoint' - 65536
            local escaped `"`escaped'\u`signed_codepoint'?"'
            local position = `position' + 6
        }
        else if `"`marker'"' == "\U" {
            local digits = substr(`"`hex'"', `position'+2, 8)
            local codepoint = 0
            forvalues digit_index = 1/8 {
                local digit_char = lower(substr(`"`digits'"', `digit_index', 1))
                local digit_value = strpos("0123456789abcdef", `"`digit_char'"') - 1
                local codepoint = `codepoint'*16 + `digit_value'
            }
            local shifted = `codepoint' - 65536
            local high = 55296 + floor(`shifted'/1024)
            local low = 56320 + mod(`shifted',1024)
            if `high' >= 32768 local high = `high' - 65536
            if `low' >= 32768 local low = `low' - 65536
            local escaped `"`escaped'\u`high'?\u`low'?"'
            local position = `position' + 10
        }
        else local position = `position' + 1
    }
    return local escaped `"`escaped'"'
end
