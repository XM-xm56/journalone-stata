*! version 0.2.0 16aug2026 JournalOne license reader
capture program drop _journalone_license_read
program define _journalone_license_read, rclass
    version 16.0
    quietly _journalone_license_path
    local path `"`r(path)'"'
    if `"`path'"' == "" {
        return scalar valid = 0
        exit
    }

    capture confirm file `"`path'"'
    if _rc {
        return scalar valid = 0
        exit
    }

    local stored ""
    capture file close __jo_lic_read
    capture file open __jo_lic_read using `"`path'"', read text
    if _rc {
        return scalar valid = 0
        exit
    }
    file read __jo_lic_read __jo_line
    while r(eof) == 0 {
        if substr(`"`__jo_line'"', 1, 7) == "digest=" {
            local stored = substr(`"`__jo_line'"', 8, .)
        }
        file read __jo_lic_read __jo_line
    }
    capture file close __jo_lic_read

    quietly _journalone_license_allowed, digest("`stored'")
    local allowed `"`r(digests)'"'
    local is_valid = r(valid)
    return scalar valid = `is_valid'
    return local digest `"`stored'"'
    return local digests `"`allowed'"'
end
