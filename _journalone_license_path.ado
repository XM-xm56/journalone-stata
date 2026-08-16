*! version 0.1.0 16aug2026 JournalOne license path
capture program drop _journalone_license_path
program define _journalone_license_path, rclass
    version 16.0
    local root `"`c(sysdir_personal)'"'
    if strtrim(`"`root'"') == "" local root `"`c(sysdir_plus)'"'
    if strtrim(`"`root'"') == "" {
        return local path ""
        exit
    }
    return local path `"`root'journalone.lic"'
end
