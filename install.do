*! JournalOne one-command installer 0.9.14 19aug2026
version 16.0

* The optional first argument is used only by local/release tests.  Ordinary
* users run this file directly from the fixed GitHub Pages address.
args install_source
local install_source = strtrim(`"`install_source'"')
local install_source = subinstr(`"`install_source'"', char(34), "", .)
if `"`install_source'"' == "" {
    local install_source "https://xm-xm56.github.io/journalone-stata"
}
if strpos(`"`install_source'"', char(10)) | ///
    strpos(`"`install_source'"', char(13)) | ///
    strpos(`"`install_source'"', char(34)) {
    display as error "JournalOne 安装地址包含不允许的字符。"
    exit 198
}

display as text "正在安装 JournalOne："
display as text `"`install_source'"'
capture noisily net install journalone, from(`"`install_source'"') replace
local install_rc = _rc
if `install_rc' {
    display as error "JournalOne 安装失败，未修改用户菜单。"
    exit `install_rc'
}

* Reload the newly installed menu command without touching the user's data.
capture program drop journalone_menu
capture noisily journalone_menu
local menu_rc = _rc
if `menu_rc' {
    display as error "插件文件已安装，但用户菜单注册失败。"
    display as text "可先运行 db journalone，并把上述错误信息发给发布者。"
    exit `menu_rc'
}

capture which journalone
local which_rc = _rc
if `which_rc' {
    display as error "安装后未找到 journalone 命令，请检查 adopath。"
    exit `which_rc'
}

display as result "JournalOne 安装及菜单注册完成。"
display as text "现在可从 用户 > 期刊实证工具 打开插件；首次运行时输入授权密钥。"
