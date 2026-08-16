*! version 0.1.0 16aug2026 JournalOne one-click updater

capture program drop journalone_update
program define journalone_update, rclass
    version 16.0
    syntax [, FROM(string asis)]

    local source = strtrim(`"`from'"')
    local source = subinstr(`"`source'"', char(34), "", .)

    * With no override, reuse the source recorded by the latest net install.
    if `"`source'"' == "" {
        local tracker = subinstr("`c(sysdir_plus)'", "\", "/", .)
        if substr("`tracker'", strlen("`tracker'"), 1) != "/" {
            local tracker "`tracker'/"
        }
        local tracker "`tracker'stata.trk"

        capture confirm file "`tracker'"
        if !_rc {
            tempname track_read
            capture file open `track_read' using "`tracker'", read text
            if !_rc {
                local candidate ""
                file read `track_read' line
                while r(eof) == 0 {
                    local trimmed = strtrim(`"`line'"')
                    if substr(`"`trimmed'"', 1, 2) == "S " {
                        local candidate = strtrim(substr(`"`trimmed'"', 3, .))
                    }
                    else if `"`trimmed'"' == "N journalone.pkg" & ///
                        `"`candidate'"' != "" {
                        local source `"`candidate'"'
                    }
                    file read `track_read' line
                }
                file close `track_read'
            }
        }
    }

    if `"`source'"' == "" {
        display as error "无法确定 JournalOne 的更新地址。"
        display as text "请先使用 net install 安装一次，或运行 journalone_update, from(更新地址)。"
        exit 601
    }
    if strpos(`"`source'"', char(10)) | strpos(`"`source'"', char(13)) | ///
        strpos(`"`source'"', char(34)) {
        display as error "更新地址包含不允许的字符。"
        exit 198
    }

    display as text "正在从以下地址更新 JournalOne："
    display as text `"`source'"'
    capture noisily net install journalone, from(`"`source'"') replace
    local install_rc = _rc
    if `install_rc' {
        display as error "JournalOne 更新失败；现有安装未被主动删除。"
        exit `install_rc'
    }

    * Drop cached JournalOne programs so the next command loads updated files.
    foreach command in journalone journalone_prep journalone_signif ///
        journalone_license journalone_menu journalone_extra ///
        journalone_descriptive_only journalone_format_outputs ///
        journalone_publish_outputs journalone_write_do ///
        journalone_export_descriptive journalone_export_stored {
        capture program drop `command'
    }
    capture program drop _journalone_license_expected
    capture program drop _journalone_license_allowed
    capture program drop _journalone_license_read
    capture program drop _journalone_require_license
    capture quietly journalone_menu

    display as result "JournalOne 一键更新完成。"
    display as text "请关闭当前插件窗口后重新打开；无需再次运行 net install。"
    return scalar updated = 1
    return local source `"`source'"'
end
