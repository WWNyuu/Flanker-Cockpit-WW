-- Su-27 Radio (WW): radio channel card (КАНАЛЫ РАДИОСВЯЗИ)
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")

indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}

BASE = 1
page_subsets = {
	[BASE] = LockOn_Options.script_path .. "LDR/indicator/crd_page.lua",
}
pages        = {{BASE}}
init_pageID  = 1
