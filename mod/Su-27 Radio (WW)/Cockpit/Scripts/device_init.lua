-----------------------------------------------
-- Su-27 Radio (WW) 0.1 - the add-on's cockpit device and its indicator
-----------------------------------------------

dofile(LockOn_Options.script_path .. "devices.lua")

-- the indicator (window digits, lamp glow) is anchored on the connectors of
-- the add-on's own model (Shapes/SU27_LDR.edm, loaded by mainpanel_init.lua):
-- centre, bottom and right, as the F-15C SIT add-on does it
local ANCHOR_OWN = {"LDR_C", "LDR_B", "LDR_R"}
-- v0.2: the УКВ / КВ channel windows (anchors on ED's window glass)
local ANCHOR_RAD = {"RAD_C", "RAD_B", "RAD_R"}
-- v0.3: the radio channel card (anchors in front of ED's card)
local ANCHOR_CRD = {"CRD_C", "CRD_B", "CRD_R"}

-- only with the plate's model exported (Tools\su27_ldr_plate.py in Blender):
-- without Shapes\SU27_LDR.edm the add-on stays out and the jet is stock
local function have_model()
	if not (io and io.open) then return true end          -- (can't look: assume it is there)
	local ok, f = pcall(io.open, LockOn_Options.script_path .. "../../Shapes/SU27_LDR.edm", "rb")
	if ok and f then f:close(); return true end
	return not ok
end

local t = get_aircraft_type()
if (t == "Su-27" or t == "J-11A") and have_model() then
	MainPanel = {"ccMainPanel", LockOn_Options.script_path .. "mainpanel_init.lua", {}}

	creators = {}
	creators[devices.LDR] = {"avLuaDevice", LockOn_Options.script_path .. "LDR/ldr_device.lua"}

	indicators = {}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_LDR.lua",
		nil, { ANCHOR_OWN, {} }}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_RAD.lua",
		nil, { ANCHOR_RAD, {} }}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_CRD.lua",
		nil, { ANCHOR_CRD, {} }}
end
