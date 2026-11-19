-----------------------------------------------------------------------
-- Su-27 Radio (WW): click spots of the loader plate. The boxes are the
-- LDR_SEL_CLICK and LDR_LOAD_CLICK connectors of Shapes\SU27_LDR.edm.
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path .. "devices.lua")

local gettext = require("i_18n")
_ = gettext.translate

-- (the Flaming Cliffs Su-27 may not load ED's clickable definitions)
class_type = class_type or {NULL = 0, BTN = 1, TUMB = 2, SNGBTN = 3, LEV = 4, MOVABLE_LEV = 5}

cursor_mode = {
	CUMODE_CLICKABLE = 0,
	CUMODE_CLICKABLE_AND_CAMERA = 1,
	CUMODE_CAMERA = 2,
}
clickable_mode_initial_status = cursor_mode.CUMODE_CLICKABLE
use_pointer_name = true

elements = {}

-- КАССЕТА: 7 positions, МИС (0.0) and 1..6 (0.1 .. 0.6). Left click turns
-- it anticlockwise (toward МИС), right click clockwise. DCS turns the knob
-- (argument 801) and sends the new value with LDR_CMD.SEL.
elements["LDR_SEL_CLICK"] = {
	class       = {class_type.TUMB, class_type.TUMB},
	hint        = _("КАССЕТА - cartridge (МИС = mission presets, 1-6)"),
	device      = devices.LDR,
	action      = {LDR_CMD.SEL, LDR_CMD.SEL},
	arg         = {801, 801},
	arg_value   = {-0.1, 0.1},
	arg_lim     = {{0.0, 0.6}, {0.0, 0.6}},
	updatable   = true,
	use_OBB     = true,
}

-- ЗАГР: push button (argument 802 = pressed in)
elements["LDR_LOAD_CLICK"] = {
	class               = {class_type.BTN},
	hint                = _("ЗАГР - load the selected cartridge"),
	device              = devices.LDR,
	action              = {LDR_CMD.LOAD},
	stop_action         = {LDR_CMD.LOAD},
	arg                 = {802},
	arg_value           = {1},
	arg_lim             = {{0, 1}},
	updatable           = true,
	use_release_message = {true},
}

-- v0.2: КАНАЛ knobs on the УКВ / КВ radio panel (left console): 20
-- channels, the knob turns round and round (argument 803 / 804, channel n at
-- (n-1) x 0.05). Left click = anticlockwise (channel down), right click =
-- clockwise (channel up). Boxes: RAD_UKV_CLICK / RAD_KV_CLICK.
local function channel_knob(hint, cmd, arg)
	return {
		class       = {class_type.TUMB, class_type.TUMB},
		hint        = hint,
		device      = devices.LDR,
		action      = {cmd, cmd},
		arg         = {arg, arg},
		arg_value   = {-0.05, 0.05},
		arg_lim     = {{0.0, 0.95}, {0.0, 0.95}},
		cycle       = true,
		updatable   = true,
		use_OBB     = true,
	}
end
elements["RAD_UKV_CLICK"] = channel_knob(_("УКВ КАНАЛ - R-800 channel (SRS radio 1)"), RAD_CMD.UKV_CH, 803)
elements["RAD_KV_CLICK"]  = channel_knob(_("КВ КАНАЛ - R-864 channel (SRS radio 2)"), RAD_CMD.KV_CH, 804)

-- v0.4: ГРОМК (volume) knobs next to each КАНАЛ knob: argument 805 (УКВ) /
-- 806 (КВ) = SRS volume of radio 1 / 2, 0 .. 1 in 20 steps; the knob turns
-- 270 deg, from 7:30 (silent) clockwise to 4:30 (full). Left click = quieter,
-- right click = louder. Boxes: RAD_VUKV_CLICK / RAD_VKV_CLICK.
local function volume_knob(hint, cmd, arg)
	return {
		class       = {class_type.TUMB, class_type.TUMB},
		hint        = hint,
		device      = devices.LDR,
		action      = {cmd, cmd},
		arg         = {arg, arg},
		arg_value   = {-0.05, 0.05},
		arg_lim     = {{0.0, 1.0}, {0.0, 1.0}},
		cycle       = false,
		updatable   = true,
		use_OBB     = true,
	}
end
elements["RAD_VUKV_CLICK"] = volume_knob(_("УКВ ГРОМК - R-800 volume (SRS radio 1)"), RAD_CMD.UKV_VOL, 805)
elements["RAD_VKV_CLICK"]  = volume_knob(_("КВ ГРОМК - R-864 volume (SRS radio 2)"), RAD_CMD.KV_VOL, 806)

-- MFD (WIP): 20 soft keys (arguments 811-830 press them in), ВКЛ (831),
-- the ЯРК and ДЕНЬ / НОЧЬ rockers (each half its own spot). Boxes:
-- MFD_OSB_<L|B|R|T><1-5>_CLICK, MFD_PWR_CLICK, MFD_BRT_UP/DN_CLICK,
-- MFD_DN_D/N_CLICK.
local function mfd_button(hint, cmd, arg)
	return {
		class               = {class_type.BTN},
		hint                = hint,
		device              = devices.MFD,
		action              = {cmd},
		stop_action         = {cmd},
		arg                 = {arg},
		arg_value           = {1},
		arg_lim             = {{0, 1}},
		updatable           = true,
		use_release_message = {true},
		use_OBB             = true,
	}
end
local OSB_SIDES = {{"L", _("left")}, {"B", _("bottom")}, {"R", _("right")}, {"T", _("top")}}
for s_, side in ipairs(OSB_SIDES) do
	for i = 1, 5 do
		local n = (s_ - 1) * 5 + i
		elements["MFD_OSB_" .. side[1] .. i .. "_CLICK"] =
			mfd_button(_("MFD") .. " " .. side[2] .. " " .. i, MFD_CMD.OSB0 + n, 810 + n)
	end
end
elements["MFD_PWR_CLICK"]    = mfd_button(_("MFD ВКЛ - power (press: on, hold 2 s: off)"), MFD_CMD.PWR, 831)
elements["MFD_BRT_UP_CLICK"] = mfd_button(_("MFD ЯРК + (brighter)"), MFD_CMD.BRT_UP, 832)
elements["MFD_BRT_DN_CLICK"] = mfd_button(_("MFD ЯРК - (dimmer)"), MFD_CMD.BRT_DN, 833)
elements["MFD_DN_D_CLICK"]   = mfd_button(_("MFD ДЕНЬ (day)"), MFD_CMD.DAY, 834)
elements["MFD_DN_N_CLICK"]   = mfd_button(_("MFD НОЧЬ (night)"), MFD_CMD.NIGHT, 835)

-- MFD (WIP): ED's ЦЕЛИ / ИСТРЕБИТЕЛИ keypad (right console) types into the
-- MFD. ED's keys do not move; arguments 841-857 are spare.
local KP_KEYS = {
	{"C1", _("1")}, {"C2", _("2")}, {"C3", _("3")}, {"C4", _("4")}, {"C5", _("5")},
	{"C6", _("6")}, {"C7", _("7")}, {"C8", _("8")}, {"C9", _("9")}, {"C10", _("10 (0)")},
	{"ENT", _("ВВОД (enter)")}, {"RST", _("СБРОС (clear)")},
	{"F1", _("ИСТРЕБИТЕЛИ 1")}, {"F2", _("ИСТРЕБИТЕЛИ 2")}, {"F3", _("ИСТРЕБИТЕЛИ 3")}, {"F4", _("ИСТРЕБИТЕЛИ 4")},
	{"GR", _("ГР")},
}
-- v1.3 test 16: in the Su-33 these are the keys of the MFD's own side unit
-- (12 keys: no ИСТРЕБИТЕЛИ 1-4 / ГР)
local ok_t, ac_t = pcall(function() return get_aircraft_type and get_aircraft_type() end)
local SU33_KEYS = ok_t and ac_t == "Su-33"
for k, key in ipairs(KP_KEYS) do
	if not (SU33_KEYS and k > 12) then
		local e = mfd_button(_("MFD keypad") .. " " .. key[2], KP_CMD[key[1]], 840 + k)
		elements["KP_" .. key[1] .. "_CLICK"] = e
	end
end
