*! version 0.6.0 16aug2026
capture program drop journalone_menu
program define journalone_menu
    version 16.0

    local profile_dir = subinstr("`c(sysdir_personal)'", "\\", "/", .)
    local profile_path "`profile_dir'profile.do"
    capture mkdir "`profile_dir'"

    local marker_found = 0
    local prep_marker_found = 0
    local signif_marker_found = 0
    local update_marker_found = 0
    local legacy_label_found = 0
    capture confirm file "`profile_path'"
    if !_rc {
        tempname profile_read
        file open `profile_read' using "`profile_path'", read text
        file read `profile_read' line
        while r(eof) == 0 {
            if strpos(`"`line'"', "journalone_menu_marker") {
                local marker_found = 1
            }
            if strpos(`"`line'"', "journalone_prep_menu_marker") {
                local prep_marker_found = 1
            }
            if strpos(`"`line'"', "journalone_signif_menu_marker") {
                local signif_marker_found = 1
            }
            if strpos(`"`line'"', "journalone_update_menu_marker") {
                local update_marker_found = 1
            }
            if strpos(`"`line'"', "一键实证") & strpos(`"`line'"', "db journalone") {
                local legacy_label_found = 1
            }
            file read `profile_read' line
        }
        file close `profile_read'
    }

    if !`marker_found' {
        capture copy "`profile_path'" "`profile_path'.journalone.bak", replace
        tempname profile_write
        file open `profile_write' using "`profile_path'", write text append
        file write `profile_write' _n "* journalone_menu_marker" _n
        file write `profile_write' "if _caller() >= 8 {" _n
        file write `profile_write' `"    capture window menu append submenu "stUser" "期刊实证工具""' _n
        file write `profile_write' `"    capture window menu append item "期刊实证工具" "实证分析" "db journalone""' _n
        file write `profile_write' `"    capture window menu append item "期刊实证工具" "使用帮助" "help journalone""' _n
        file write `profile_write' "    capture window menu refresh" _n
        file write `profile_write' "}" _n
        file close `profile_write'
        display as result "已把“期刊实证工具”菜单安全追加到 `profile_path'"
    }
    else {
        display as text "profile.do 已包含 journalone 菜单配置，未重复写入"
    }

    if `legacy_label_found' {
        capture copy "`profile_path'" "`profile_path'.journalone.analysis.bak", replace
        tempfile migrated_profile
        capture filefilter "`profile_path'" "`migrated_profile'", ///
            from("一键实证") to("实证分析") replace
        if !_rc {
            capture copy "`migrated_profile'" "`profile_path'", replace
            if !_rc display as result "已把旧菜单名称“一键实证”迁移为“实证分析”；新会话生效"
        }
        else display as error "旧菜单名称自动迁移失败，请检查 `profile_path'"
    }

    if !`prep_marker_found' {
        capture copy "`profile_path'" "`profile_path'.journalone.prep.bak", replace
        tempname prep_profile_write
        file open `prep_profile_write' using "`profile_path'", write text append
        file write `prep_profile_write' _n "* journalone_prep_menu_marker" _n
        file write `prep_profile_write' "if _caller() >= 8 {" _n
        file write `prep_profile_write' `"    capture window menu append item "期刊实证工具" "数据预处理" "db journalone_prep""' _n
        file write `prep_profile_write' "    capture window menu refresh" _n
        file write `prep_profile_write' "}" _n
        file close `prep_profile_write'
        display as result "已把“数据预处理”菜单安全追加到 `profile_path'"
    }
    else {
        display as text "profile.do 已包含 journalone 数据预处理菜单，未重复写入"
    }

    if !`signif_marker_found' {
        capture copy "`profile_path'" "`profile_path'.journalone.signif.bak", replace
        tempname signif_profile_write
        file open `signif_profile_write' using "`profile_path'", write text append
        file write `signif_profile_write' _n "* journalone_signif_menu_marker" _n
        file write `signif_profile_write' "if _caller() >= 8 {" _n
        file write `signif_profile_write' `"    capture window menu append item "期刊实证工具" "显著组合" "db journalone_signif""' _n
        file write `signif_profile_write' "    capture window menu refresh" _n
        file write `signif_profile_write' "}" _n
        file close `signif_profile_write'
        display as result "已把“显著组合”菜单安全追加到 `profile_path'"
    }
    else {
        display as text "profile.do 已包含 journalone 显著组合菜单，未重复写入"
    }

    if !`update_marker_found' {
        capture copy "`profile_path'" "`profile_path'.journalone.update.bak", replace
        tempname update_profile_write
        file open `update_profile_write' using "`profile_path'", write text append
        file write `update_profile_write' _n "* journalone_update_menu_marker" _n
        file write `update_profile_write' "if _caller() >= 8 {" _n
        file write `update_profile_write' `"    capture window menu append item "期刊实证工具" "一键更新" "journalone_update""' _n
        file write `update_profile_write' "    capture window menu refresh" _n
        file write `update_profile_write' "}" _n
        file close `update_profile_write'
        display as result "已把“一键更新”追加到 `profile_path'"
    }
    else {
        display as text "profile.do 已包含 JournalOne 一键更新菜单，未重复写入"
    }

    if "$JOURNALONE_MENU_LOADED" != "1" & !`marker_found' {
        capture window menu append submenu "stUser" "期刊实证工具"
        capture window menu append item "期刊实证工具" "实证分析" "db journalone"
        capture window menu append item "期刊实证工具" "使用帮助" "help journalone"
        capture window menu refresh
    }
    global JOURNALONE_MENU_LOADED 1
    if "$JOURNALONE_PREP_MENU_LOADED" != "1" & !`prep_marker_found' {
        capture window menu append item "期刊实证工具" "数据预处理" "db journalone_prep"
        capture window menu refresh
    }
    global JOURNALONE_PREP_MENU_LOADED 1
    if "$JOURNALONE_SIGNIF_MENU_LOADED" != "1" & !`signif_marker_found' {
        capture window menu append item "期刊实证工具" "显著组合" "db journalone_signif"
        capture window menu refresh
    }
    global JOURNALONE_SIGNIF_MENU_LOADED 1
    if "$JOURNALONE_UPDATE_MENU_LOADED" != "1" & !`update_marker_found' {
        capture window menu append item "期刊实证工具" "一键更新" "journalone_update"
        capture window menu refresh
    }
    global JOURNALONE_UPDATE_MENU_LOADED 1
    display as result "可从 用户 > 期刊实证工具 > 实证分析 / 显著组合 / 数据预处理 / 一键更新 打开"
end
