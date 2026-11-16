-- Su-27 MFD (WW, WIP): the MFD page
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")

indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}

BASE = 1
page_subsets = {
	[BASE] = LockOn_Options.script_path .. "MFD/indicator/mfd_page.lua",
}
pages        = {{BASE}}
init_pageID  = 1
