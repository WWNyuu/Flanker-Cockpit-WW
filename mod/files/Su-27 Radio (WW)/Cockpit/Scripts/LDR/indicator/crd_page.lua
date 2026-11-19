-----------------------------------------------------------------------
-- Su-27 Radio (WW) v0.3: the radio channel card (КАНАЛЫ РАДИОСВЯЗИ),
-- filled in by hand (blue ink) from the loaded presets.
-- 20 rows: 1-10 left half, 11-20 right half. Per row (from ldr_device.lua):
--   CRD_<n>_ON  0 = empty, 1 = УКВ channel, 2 = КВ channel ("К" before the number)
--   CRD_<n>_CH  channel number      CRD_<n>_F   frequency, MHz
--   CRD_<n>_ST  station (text)      CRD_<n>_CS  callsign (text)
--   CRD_TITLE   cartridge in use (text, top right)
-- Units: 1 = 74.2 mm (anchors CRD_C/B/R), x right, y up, 0 = card centre.
-- Layout = Tools\crd_layout.py.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "LDR/indicator/hand_font.lua")
SetScale(FOV)

local CW, CH = 148.4, 52.6
local ROW0, ROW_H, ROWS = 12.0, 3.85, 10
local HALF_X = {8.0, 74.2}                         -- (ED's card holder covers ~7 mm at each end)
local COLS = {0.0, 6.8, 21.0, 45.2, 66.2}
local G = 0.0742                                   -- metres per unit (half the card width)
local function u(x_mm, y_mm) return (x_mm - CW / 2) / 74.2, (CH / 2 - y_mm) / 74.2, 0 end

local INK = MakeFont(HAND_FONT, {34, 44, 118, 255})       -- blue ink
-- text size by its lowercase / digit height (mm) -> glyph cell (metres).
-- (In this hand, digits and small letters are about half the capitals.)
local function size(xh_mm)
	local h = xh_mm / 1000 / HAND_FONT_XH
	return {h, h, 0, 0}
end
local TXT = size(1.35)
local TXT_T = size(1.25)

local n_el = 0
-- value text (param) with a visibility parameter checked first, as in the
-- F-15C SIT page; "%s" params never hold number-like text (DCS would crash)
local function text(x, y, align, defs, param, fmt, vis_param, lo, hi)
	n_el = n_el + 1
	local e = CreateElement "ceStringPoly"
	e.name = "crd_" .. n_el
	e.material = INK
	e.init_pos = {u(x, y)}
	e.alignment = align
	e.stringdefs = defs
	e.formats = {fmt}
	e.element_params = {param, vis_param}
	e.controllers = {{"parameter_in_range", 1, lo, hi}, {"text_using_parameter", 0, 0}}
	Add(e)
end
local function fixed(x, y, align, defs, value, vis_param, lo, hi)
	n_el = n_el + 1
	local e = CreateElement "ceStringPoly"
	e.name = "crd_" .. n_el
	e.material = INK
	e.init_pos = {u(x, y)}
	e.alignment = align
	e.stringdefs = defs
	e.value = value
	e.element_params = {vis_param}
	e.controllers = {{"parameter_in_range", 0, lo, hi}}
	Add(e)
end

for n = 1, 2 * ROWS do
	local half = (n <= ROWS) and 1 or 2
	local r = (n - 1) % ROWS
	local hx = HALF_X[half]
	local y = ROW0 + (r + 0.62) * ROW_H                 -- (letters sit on the line below them, like handwriting)
	local p = "CRD_" .. n .. "_"
	-- УКВ: number centred; КВ: "К" + number
	text(hx + (COLS[1] + COLS[2]) / 2, y, "CenterCenter", TXT, p .. "CH", "%02.0f", p .. "ON", 0.5, 1.5)
	fixed(hx + 0.6, y, "LeftCenter", TXT, "К", p .. "ON", 1.5, 2.5)
	text(hx + 4.6, y, "CenterCenter", TXT, p .. "CH", "%.0f", p .. "ON", 1.5, 2.5)
	text(hx + COLS[2] + 1.0, y, "LeftCenter", TXT, p .. "F", "%.3f", p .. "ON", 0.5, 2.5)
	text(hx + COLS[3] + 1.0, y, "LeftCenter", TXT, p .. "ST", "%s", p .. "ON", 0.5, 2.5)
	text(hx + COLS[4] + 1.0, y, "LeftCenter", TXT, p .. "CS", "%s", p .. "ON", 0.5, 2.5)
end
-- cartridge in use, top right (always shown)
text(140.2, 5.6, "RightCenter", TXT_T, "CRD_TITLE", "%s", "CRD_TITLE_ON", 0.5, 1.5)
