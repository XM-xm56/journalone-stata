*! version 0.1.0 16aug2026 JournalOne license gate
capture program drop _journalone_require_license
program define _journalone_require_license
    version 16.0
    syntax [, LOADONLY]
    if `"`loadonly'"' != "" exit

    quietly _journalone_license_read
    if r(valid) != 1 {
        display as error "JournalOne 尚未授权或授权文件无效。"
        display as error `"请先运行：journalone_license, activate("你的授权密钥")"'
        exit 198
    }
end
