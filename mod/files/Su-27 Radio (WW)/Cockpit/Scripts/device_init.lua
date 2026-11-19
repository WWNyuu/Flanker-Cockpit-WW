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
-- MFD (WIP): the MFD page, on the MFD's screen (anchors MFD_C / B / R)
local ANCHOR_MFD = {"MFD_C", "MFD_B", "MFD_R"}

-- only with the plate's model exported (Tools\su27_ldr_plate.py in Blender):
-- without Shapes\SU27_LDR.edm the add-on stays out and the jet is stock
local function have_model(name)
	if not (io and io.open) then return name == "SU27_LDR" end   -- (can't look: only the Su-27 model is sure)
	local ok, f = pcall(io.open, LockOn_Options.script_path .. "../../Shapes/" .. name .. ".edm", "rb")
	if ok and f then f:close(); return true end
	return (not ok) and name == "SU27_LDR"
end

-- MFD (WIP): only with a model that has it (Tools\su27_ldr_plate.py v10
-- writes Shapes\SU27_LDR_MFD.txt next to the model when it exports)
local function have_mfd(name)
	if not (io and io.open) then return false end
	local ok, f = pcall(io.open, LockOn_Options.script_path .. "../../Shapes/" .. name .. "_MFD.txt", "r")
	if ok and f then f:close(); return true end
	return false
end

local t = get_aircraft_type()
-- v1.3 test 9: the Su-33 gets its own model (SU33_LDR.edm: Tools\su27_ldr_plate.py
-- with AIRCRAFT = "Su-33") with live fit arguments; without it, the Su-27's model
local model = "SU27_LDR"
if t == "Su-33" and have_model("SU33_LDR") then model = "SU33_LDR" end
if (t == "Su-27" or t == "J-11A" or t == "Su-33") and have_model(model) then
	MainPanel = {"ccMainPanel", LockOn_Options.script_path .. (model == "SU33_LDR" and "mainpanel_init_su33.lua" or "mainpanel_init.lua"), {}}

	creators = {}
	creators[devices.LDR] = {"avLuaDevice", LockOn_Options.script_path .. "LDR/ldr_device.lua"}

	indicators = {}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_LDR.lua",
		nil, { ANCHOR_OWN, {} }}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_RAD.lua",
		nil, { ANCHOR_RAD, {} }}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "LDR/indicator/init_CRD.lua",
		nil, { ANCHOR_CRD, {} }}
	if model == "SU33_LDR" then
		creators[devices.FIT] = {"avLuaDevice", LockOn_Options.script_path .. "LDR/fit_device.lua"}
	end
	if have_mfd(model) then
		creators[devices.MFD] = {"avLuaDevice", LockOn_Options.script_path .. "MFD/mfd_device.lua"}
		indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "MFD/indicator/init_MFD.lua",
			nil, { ANCHOR_MFD, {} }}
	end
end
