*! version 0.2.0 16aug2026 JournalOne license allowlist
capture program drop _journalone_license_allowed
program define _journalone_license_allowed, rclass
    version 16.0
    syntax, DIGEST(string asis)

    * The public package contains only the digest allowlist.  Never compare
    * or persist the plaintext key here.
    local candidate = strtrim(`"`digest'"')
    local candidate = subinstr(`"`candidate'"', char(34), "", .)
    quietly _journalone_license_expected
    local allowed = strtrim(`"`r(digests)'"')

    local valid = 0
    if `"`candidate'"' != "" & `"`allowed'"' != "" {
        local haystack `"|`allowed'|"'
        local needle `"|`candidate'|"'
        if strpos(`"`haystack'"', `"`needle'"') > 0 local valid = 1
    }

    return scalar valid = `valid'
    return local digest `"`candidate'"'
    return local digests `"`allowed'"'
end
