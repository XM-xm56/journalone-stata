*! version 0.1.0 16aug2026 JournalOne license digest
capture program drop _journalone_license_digest
program define _journalone_license_digest, rclass
    version 16.0
    syntax, TEXT(string asis)

    local raw = strtrim(`"`text'"')
    local raw = subinstr(`"`raw'"', char(34), "", .)
    if `"`raw'"' == "" {
        return local digest ""
        exit
    }

    local s1 "JournalOne|license|v1|A|`raw'"
    local s2 "JournalOne|license|v1|B|`raw'"
    local s3 "JournalOne|license|v1|C|`raw'"
    local s4 "JournalOne|license|v1|D|`raw'"
    mata: st_local("__jo_h1", sprintf("%010.0f", hash1(st_local("s1"), .)))
    mata: st_local("__jo_h2", sprintf("%010.0f", hash1(st_local("s2"), .)))
    mata: st_local("__jo_h3", sprintf("%010.0f", hash1(st_local("s3"), .)))
    mata: st_local("__jo_h4", sprintf("%010.0f", hash1(st_local("s4"), .)))
    return local digest "`__jo_h1'-`__jo_h2'-`__jo_h3'-`__jo_h4'"
end
