*! version 0.3.0 18aug2026 JournalOne license activation

capture program drop journalone_license
program define journalone_license
    version 16.0
    quietly _journalone_require_license, loadonly
    syntax [, ACTIVATE(string asis) STATUS DEACTIVATE]

    local n = (strtrim(`"`activate'"') != "") + ///
        (`"`status'"' != "") + (`"`deactivate'"' != "")
    if `n' > 1 {
        display as error "activate、status 和 deactivate 只能选择一个。"
        exit 198
    }

    quietly _journalone_license_path
    local path `"`r(path)'"'
    if `"`path'"' == "" {
        display as error "无法定位 Stata 个人 ado 目录，授权未写入。"
        exit 198
    }

    if strtrim(`"`activate'"') != "" {
        quietly _journalone_license_digest, text(`activate')
        local supplied_digest `"`r(digest)'"'
        quietly _journalone_license_allowed, digest("`supplied_digest'")
        if r(valid) != 1 {
            quietly _journalone_license_read
            display as error "授权密钥无效，JournalOne 未激活。"
            exit 198
        }

        capture file close __jo_lic_write
        file open __jo_lic_write using `"`path'"', write text replace
        file write __jo_lic_write "journalone_license_v1" _n
        file write __jo_lic_write "digest=`supplied_digest'" _n
        file write __jo_lic_write "activated=`c(current_date)' `c(current_time)'" _n
        file close __jo_lic_write
        global JOURNALONE_LICENSE_VALID 1
        display as result "JournalOne 授权成功。"
        display as text "授权文件：`path'"
        exit
    }

    if `"`deactivate'"' != "" {
        capture erase `"`path'"'
        global JOURNALONE_LICENSE_VALID 0
        if _rc == 0 display as result "JournalOne 授权已移除。"
        else display as text "未找到授权文件。"
        exit
    }

    quietly _journalone_license_read
    if r(valid) == 1 {
        display as result "JournalOne 授权状态：有效。"
        display as text "授权文件：`path'"
    }
    else {
        display as error "JournalOne 授权状态：未激活。"
        display as text `"安装完成后，请运行：journalone_license, activate("你的授权密钥")"'
    }
end
