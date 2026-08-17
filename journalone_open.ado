*! version 0.9.7 17aug2026

capture program drop journalone_open
program define journalone_open, rclass
    version 16.0
    _journalone_require_license
    syntax using/ [, DRYRUN ]

    local filepath `"`using'"'
    if strtrim(`"`filepath'"') == "" {
        display as error "没有指定需要打开的结果文件"
        exit 198
    }
    local openpath `"`filepath'"'
    if "`c(os)'" == "Windows" & substr(`"`openpath'"', 2, 1) != ":" & ///
        substr(`"`openpath'"', 1, 2) != "\\" {
        local openpath `"`c(pwd)'/`openpath'"'
    }
    else if "`c(os)'" != "Windows" & substr(`"`openpath'"', 1, 1) != "/" {
        local openpath `"`c(pwd)'/`openpath'"'
    }
    if "`c(os)'" == "Windows" {
        local openpath = subinstr(`"`openpath'"', "/", char(92), .)
    }

    capture confirm file `"`openpath'"'
    if _rc {
        display as error "结果文件不存在：`filepath'"
        exit 601
    }

    local path_length = strlen(`"`filepath'"')
    local extension3 = lower(substr(`"`filepath'"', max(1, `path_length' - 2), .))
    local extension4 = lower(substr(`"`filepath'"', max(1, `path_length' - 3), .))
    local extension ""
    if "`extension3'" == ".do" local extension ".do"
    if inlist("`extension4'", ".rtf", ".csv") local extension "`extension4'"
    if "`extension'" == "" {
        display as error "只允许打开插件生成的 RTF、DO 或 CSV 文件"
        exit 198
    }

    return local file `"`openpath'"'
    return local extension "`extension'"
    if "`dryrun'" != "" exit

    if "`extension'" == ".do" {
        capture noisily doedit `"`openpath'"'
    }
    else if "`c(os)'" == "Windows" {
        local fileurl = subinstr(`"`openpath'"', "%", "%25", .)
        local fileurl = subinstr(`"`fileurl'"', char(92), "/", .)
        local fileurl = subinstr(`"`fileurl'"', " ", "%20", .)
        local fileurl = subinstr(`"`fileurl'"', "#", "%23", .)
        local fileurl = subinstr(`"`fileurl'"', "?", "%3F", .)
        local fileurl = subinstr(`"`fileurl'"', "&", "%26", .)
        if substr(`"`openpath'"', 1, 2) == "\\" {
            local fileurl `"file:`fileurl'"'
        }
        else {
            local fileurl `"file:///`fileurl'"'
        }
        capture winexec rundll32.exe url.dll,FileProtocolHandler `fileurl'
    }
    else {
        capture noisily view `"`openpath'"'
    }
    local open_rc = _rc
    if `open_rc' {
        display as error "无法打开结果文件：`filepath'"
        exit `open_rc'
    }
    return scalar opened = 1
end
