-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: the pages and keys of the MiG-29 MFD add-on's
-- MFI edition (after the real MFI-55), on the Su-27's square screen:
-- light screen, cyan frame,
--   top row    (T1-T5) = page groups      ATK TAC NAV COM SYS
--   bottom row (B1-B5) = the group's pages (the one shown lit)
--   sides      (L / R) = the page's own keys, names written downwards
-- Read by MFD/mfd_device.lua + MFD/mfd_mfi_dev.lua (values, keys) and the
-- page (MFD/indicator/mfd_page.lua + mfd_mfi_page.lua).
-- Loaded from mfd_config.lua when SIT.MFI is true.
-----------------------------------------------------------------------
local PG = SIT.PG
-- the MFI edition's own pages (the classic ones keep their numbers)
PG.LOFT, PG.PFD, PG.LND, PG.PNT, PG.BCN, PG.COMK = 23, 24, 25, 26, 27, 28

SIT_MFI = {
	tabs = {
		{name = "ATK", subs = {{"LOFT", PG.LOFT}, {"SMS", PG.SMS}}},
		{name = "TAC", subs = {{"SA", PG.SIT}, {"PIC", PG.PIC}, {"FLT", PG.FLT}, {"RWR", PG.RWR}}},
		{name = "NAV", subs = {{"RTE", PG.NAV}, {"PFD", PG.PFD}, {"LND", PG.LND}, {"PNT", PG.PNT}, {"BCN", PG.BCN}}},
		{name = "COM", subs = {{"UKV", PG.COM}, {"KV", PG.COMK}}},
		{name = "SYS", subs = {{"FUEL", PG.FUEL}, {"DTC", PG.DTM}}},
	},
	-- pages that are not on a bottom key: {group, page whose key is lit}
	extra = {[PG.SETS] = {2, PG.SIT}},
	start_page = PG.SIT,
	-- side key names per page {left 1-5}, {right 1-5}: false = no key; a
	-- table = {name, on = param (black while 1), vis = {param, lo, hi}} or a
	-- list of such variants on one key. At most 5 letters.
	side = {
		[PG.SIT]  = {{{"FPL", on = "S27MFD_RTE"}, "NEXT", {"INTC", on = "S27MFD_M_INTC"}, "MARK", {"DEL", vis = {"S27MFD_M_MK_ANY", 0.5, 1.5}}},
		             {{"EXP", on = "S27MFD_M_EXP"}, "RNG+", "RNG-", "SET", {"GEO", on = "S27MFD_LINES"}}},
		[PG.SETS] = {{{"DL", on = "S27MFD_DL"}, {"RTE", on = "S27MFD_RTE"}, {"THR", on = "S27MFD_THR"}, {"LINE", on = "S27MFD_LINES"}, "SA"},
		             {{"CRS", on = "S27MFD_CRS"}, "DCLT", {"AUTO", on = "S27MFD_AUTOR"}, {"RDR", on = "S27MFD_RDRL"}, {{"NUP", vis = {"S27MFD_NUP", 0.5, 1.5}}, {"HUP", vis = {"S27MFD_NUP", -0.5, 0.5}}}}},
		[PG.PIC]  = {{"RNG+", "RNG-", {"AUTO", on = "S27MFD_M_PIC_AUTO"}, "INTC", "CALL"},
		             {{"G1", vis = {"S27MFD_M_PIC_RV1", 0.5, 1.5}}, {"G2", vis = {"S27MFD_M_PIC_RV2", 0.5, 1.5}}, {"G3", vis = {"S27MFD_M_PIC_RV3", 0.5, 1.5}},
		              {"G4", vis = {"S27MFD_M_PIC_RV4", 0.5, 1.5}}, {"G5", vis = {"S27MFD_M_PIC_RV5", 0.5, 1.5}}}},
		[PG.FLT]  = {{"ADD", "DEL", false, "PREV", "NEXT"}, {false, false, false, false, {"AUTO", on = "S27MFD_FLT_AUTO"}}},
		[PG.LOFT] = {{"W+", "W-", "WPN", false, false}, {"ANG+", "ANG-", "DEF", false, false}},
		[PG.NAV]  = {{"PREV", "NEXT", {{"AUTO", vis = {"S27MFD_M_NAV_AUTO", 0.5, 1.5}}, {"MAN", vis = {"S27MFD_M_NAV_AUTO", -0.5, 0.5}}}, "DIR", "RST"},
		             {"LOAD", "TOT", "PT", "CLR", {"ADD", on = "S27MFD_NAV_ADD"}}},
		[PG.PFD]  = {{{"FD", on = "S27MFD_PFD_FDON"}, {"SPD", on = "S27MFD_PFD_TASON"}, {"AMAX", on = "S27MFD_PFD_AMXON"}, {"AMIN", on = "S27MFD_PFD_AMNON"}, {"RALT", on = "S27MFD_PFD_RSRC"}},
		             {{"VSI", on = "S27MFD_PFD_VSION"}, false, false, false, false}},
		[PG.LND]  = {{"HDG", "CRS", false, "STP", "SYNC"}, {false, false, false, false, false}},
		[PG.PNT]  = {{"UP", "DN", "POS", "ADD", "DEL"}, {false, false, false, false, "STP"}},
		[PG.BCN]  = {{"PREV", "NEXT", false, false, false}, {false, false, false, false, false}},
		[PG.COM]  = {{"CH+", "CH-", "VOL+", "VOL-", {"MAN", on = "S27MFD_COM_MANU"}}, {"FC+", "FC-", false, false, false}},
		[PG.COMK] = {{"CH+", "CH-", "VOL+", "VOL-", {"MAN", on = "S27MFD_COM_MANK"}}, {"FC+", "FC-", false, false, false}},
		[PG.FUEL] = {{{"BNGO", on = "S27MFD_M_BNG_ED"}, "HOME", false, false, false}, {false, false, false, false, false}},
		[PG.DTM]  = {{"READ", "RFSH", false, "PREV", "NEXT"},
		             {{"1", vis = {"S27MFD_M_DTC_V1", 0.5, 9}}, {"2", vis = {"S27MFD_M_DTC_V2", 0.5, 9}}, {"3", vis = {"S27MFD_M_DTC_V3", 0.5, 9}},
		              {"4", vis = {"S27MFD_M_DTC_V4", 0.5, 9}}, {"5", vis = {"S27MFD_M_DTC_V5", 0.5, 9}}}},
	},
	-- frame (page units; the screen is +-0.855 across, +-0.81 up)
	band_x  = 0.785,     -- side bands: from here to the screen edge
	band_y  = 0.725,     -- top / bottom bands: from here to the screen edge
	side_x  = 0.820,     -- side key names (centre)
	row_y   = 0.767,     -- top / bottom key names
	flt_per_page = 4,
	-- colours as they should look (r g b); the page turns them into DCS's
	-- linear values (gamma, as the MiG-29 MFI edition: DCS shows colours lighter)
	gamma   = 2.2,
	paper   = {200, 204, 207},
	frame   = {40, 180, 205},
	label   = {25, 55, 190},
	side_ink = {10, 22, 115},     -- (test 3: MiG round 20 darker side keys)
	sel_bg  = {25, 40, 160},
	-- text colours of the MFI pages (as the MiG-29 MFI edition shows them)
	ink = {
		-- (test 3: the MiG-29 MFI's darker round 20 colours; dkgreen = range
		-- scale / bullseye, dkyellow = LOFT target lines)
		black = {25, 25, 30}, green = {0, 95, 35}, red = {165, 0, 0}, amber = {165, 80, 0},
		blue = {20, 35, 150}, grey = {105, 105, 118}, cyan = {0, 80, 125}, yellow = {130, 90, 0},
		magenta = {145, 0, 130}, orange = {225, 105, 0}, dkgreen = {0, 62, 22}, dkyellow = {95, 60, 0},
	},
	-- day colours of the classic SA page -> their MFI colour (dark on the
	-- light screen). Others: nearest of these within 30, else the lightness flipped.
	pal = {
		{235, 235, 235,  25,  25,  30},   -- white text / symbols
		{170, 185, 175, 105, 105, 118},   -- grey ring
		{150, 160, 155, 105, 105, 118},   -- aircraft outline
		{ 90, 215, 255,  20,  20,  25},   -- ownship (black, as the MiG-29 MFI SA)
		{  0, 220, 255,   0,  80, 125},   -- cyan / own flight
		{ 40, 230,  90,   0,  95,  35},   -- friendly
		{ 40, 200,  80,   0,  95,  35},   -- selected station
		{120, 230, 150,   0,  95,  35},   -- green text
		{245,  60,  60, 165,   0,   0},   -- hostile
		{250,  60,  60, 165,   0,   0},
		{200,  60,  60, 165,   0,   0},
		{200,  70,  70, 165,   0,   0},
		{ 80, 130, 255,  20,  35, 150},   -- line to the target
		{ 80, 160, 255,  20,  35, 150},
		{240, 200,  50, 130,  90,   0},   -- route
		{240, 220,  60, 130,  90,   0},   -- bullseye
		{240, 230,  60, 130,  90,   0},   -- yellow text
		{255, 150,  40, 165,  80,   0},   -- orange
		{230,  70, 230, 145,   0, 130},   -- magenta
	},
	-- SA page (MFI): range arc (green) and its range rings
	sa_arc = {20, 140, 50},
	sa_ring = {120, 122, 132},
	-- every text parameter of the MFI pages (S27MFD_M_<name>): the device
	-- gives each one a string before the page shows (a parameter that is
	-- still the number 0 crashes DCS when a "%s" text prints it)
	texts = {},
}

-- test 3: the SA scope as the MiG-29 MFI's (dl_page.lua MFI rounds 13-27),
-- page units. Jet in the middle: green ring = the range, ticks inside it,
-- grey rings at 1/4 - 3/4. Decentred: the jet low, a big green arc = the
-- range with ticks and heading numbers outside it, the heading box on its
-- top, grey rings, lubber and beam lines. Orange arrow on the arc = the way
-- to the active steerpoint.
SIT_MFI.sa = {
	rc = 0.52,            -- centred ring radius (= selected range)
	rd = 0.86, dy = -0.42, -- decentred: arc radius (= range), where the jet sits
	arc_w = 0.011,        -- ring / arc line width
	ticks = {0.044, 0.030, 0.017},   -- every 30 / 10 / 5 deg
	num_r = 0.075,        -- heading numbers: this far beyond the arc's outer edge
	sym_k = 1.45,         -- contact symbols x this (MiG round 17)
	diamond = 1.15,       -- hostile diamond size (x symbol size)
	course = 0.075,       -- course line length (MiG round 24 / 27: x 1.5 for all)
	course_gap = 0.009,
	wpt_r = 0.040,        -- steerpoint disc
	af_r = 0.027, af_max = 12,   -- airfields (blue disc, white runway line)
	own_k = 1.45,         -- ownship symbol x this (black, filled)
	hdg_w = 0.115, hdg_h = 0.085,  -- heading box on the arc (half width, height)
	fdv_w = 0.08,         -- the FD V outside the arc (half width)
	fd_w = 0.045,         -- FD arrow half width
	ptr_x = 0.72, ptr_top = 0.52, ptr_bot = -0.62,   -- arc pointers stay inside these
	txt_k = 1.35,         -- the SA page's texts x this (MiG-sized on this screen)
}
-- brightness (the MiG-29 MFI's standard): light of BRT 1 and BRT 10 (part
-- of full light), the steps between them even; day and night start at brt_start
SIT_MFI.brt_min = 0.04
SIT_MFI.brt_max = 0.56
SIT_MFI.brt_start = 5
SIT_MFI.txt_k = 1.35      -- every MFI page's texts x this (test 3: were too small)

-- PFD page (MiG-29 MFI dl_pfd.lua, laid out for this screen; page units)
SIT_MFI.pfd = {
	spd_x0 = -0.745, spd_x1 = -0.575, alt_x0 = 0.375, alt_x1 = 0.545, tape_y0 = -0.34, tape_y1 = 0.52,
	spd_k = 0.00478, spd_step = 50, alt_k = 0.00101, alt_step = 200, alt_kft = 0.000405, alt_step_ft = 500,
	adi_x0 = -0.50, adi_x1 = 0.30, adi_y0 = -0.30, adi_y1 = 0.48, ppd = 0.020, bank_r = 0.30, wing = 0.30,
	fd_max = 0.25, fpm_r = 0.026,
	vsi_x0 = 0.585, vsi_x1 = 0.735, vsi_y0 = -0.28, vsi_y1 = 0.46, vsi_pivot = 0.45,
	fma_x0 = -0.50, fma_x1 = 0.30, fma_y = 0.585,
	arc_x = -0.10, arc_y = -1.02, arc_r = 0.56, arc_clip = {-0.62, -0.695, 0.42, -0.40}, arc_txt_y = -0.655,
	wp_lim = 48,          -- steerpoint pointer on the heading arc: held at the arc's edge past this (deg)
	font_scale = 2.10,    -- the MiG-29 page's text sizes x this (test 3: was 1.85, MiG round 28 tape numbers x 1.15)
}
-- VSI scale: page units from the middle for a vertical speed (m/s, log scale to 50)
function SIT_MFI.vsi_dy(L, v)
	local hh = (L.vsi_y1 - L.vsi_y0) / 2 - 0.06
	local a = math.min(50, math.abs(v or 0))
	return ((v or 0) >= 0 and 1 or -1) * math.log10(1 + a) / math.log10(51) * hh
end
function SIT_MFI.vsi_ang(L, v)
	local d = L.vsi_x1 + (L.vsi_pivot or 0.60) - (L.vsi_x0 + 0.05)
	return -math.atan(SIT_MFI.vsi_dy(L, v) / d)
end
-- LOFT page (MiG-29 dl_loft.lua): its geometry here (page units)
SIT_MFI.loft = {pitch_y0 = 0.0, pitch_h = 0.46, pitch_max = 45, psx = 0.55, rbar_x = -0.55,
	prof_x0 = -0.70, prof_y0 = -0.66, prof_w = 1.40, prof_h = 0.18,
	sy = 0.25, ladder_k = 0.016, ladder_win = 0.14, steer_k = 0.008, tape_y = 0.50, tape_k = 0.012}

-- group and lit bottom key of a page (nil, nil = none)
function SIT_MFI.where(pg)
	local x = SIT_MFI.extra[pg]
	if x then pg = x[2] end
	for t, tab in ipairs(SIT_MFI.tabs) do
		for s, sub in ipairs(tab.subs) do
			if sub[2] == pg then return t, s end
		end
	end
	return nil, nil
end

-- day colour -> MFI colour (before gamma)
function SIT_MFI.rgb(r, g, b)
	local P = SIT_MFI.paper
	if r + g + b < 30 then return P[1], P[2], P[3] end
	local best, bd = nil, 1e9
	for _, q in ipairs(SIT_MFI.pal) do
		local d = (q[1] - r) ^ 2 + (q[2] - g) ^ 2 + (q[3] - b) ^ 2
		if d < bd then best, bd = q, d end
	end
	if bd <= 900 then return best[4], best[5], best[6] end
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local sh = (255 - (mx + mn) / 2) - (mx + mn) / 2
	local function c(v) return math.max(0, math.min(255, math.floor(v + sh + 0.5))) end
	return c(r), c(g), c(b)
end
function SIT_MFI.lin(v) return math.floor(255 * (v / 255) ^ SIT_MFI.gamma + 0.5) end

-- the text parameters (names without S27MFD_M_), see texts above
do
	local T = SIT_MFI.texts
	local function add(...) for _, n in ipairs({...}) do T[#T + 1] = n end end
	local function rows(p, n) for k = 1, n do T[#T + 1] = p .. k end end
	-- SA
	add("SA_IAS", "SA_GS", "SA_ALT", "SA_RNG", "SA_INTC1", "SA_INTC2", "SA_WP1", "SA_WP2", "SA_TOAST")
	-- FPAS
	add("FU_TOT", "FU_INT", "FU_FLOW", "FU_TO", "FU_TORNG", "FU_SR", "FU_B1", "FU_B2", "FU_B3", "FU_B4", "FU_RES",
	    "FU_BNG", "FU_HOME", "FU_NEED", "FU_HARR", "FU_ENG", "FU_EGT")
	-- COM (both radios on one set: the page shows the radio picked)
	add("RD_TITLE", "RD_FREQ", "RD_VOL", "RD_SRC", "RD_MSG", "RD_FC", "RD_OTHER")
	rows("RD_C", 20)
	-- DTC
	add("DTC_TITLE", "DTC_PAGE", "DTC_D1", "DTC_D2", "DTC_D3")
	rows("DTC_I", 5)
	-- FLIGHT
	add("FLT_TITLE", "FLT_PG")
	rows("FLT_R", 5); rows("FLT_S", 5); rows("FLT_D", 12)
	-- PICTURE
	add("PIC_HDR", "PIC_SORT", "PIC_K1", "PIC_K2", "PIC_PR")
	rows("PIC_R", 5)
	-- RWR, SMS
	add("RWR_CM")
	rows("RWR_L", 6); rows("RWR_T", 12)
	add("SMS_SEL", "SMS_GUN", "SMS_CM", "SMS_TOT")
	-- NAV (RTE), TOT block, BCN, PNT, LND
	add("NAV_SRC", "NAV_STP", "NAV_BRG", "NAV_TIME", "NAV_LEG", "NAV_CMD", "NAV_SEQ")
	rows("NAV_L", 5)
	add("TOT_HINT", "TOT_L1", "TOT_ST", "TOT_SPD", "TOT_THEN", "TOT_FUEL")
	add("BCN_HD", "BCN_SEL", "BCN_PG")
	rows("BCN_L", 8)
	add("PNT_TITLE", "PNT_SEL", "PNT_LL", "PNT_MSG", "PNT_PG")
	rows("PNT_R", 5)
	add("LND_SPD", "LND_WIND", "LND_CRSM", "LND_STP1", "LND_STP2", "LND_ENTRY")
	-- PFD (dl_pfd.lua's texts) and LOFT
	add("PFD_SL", "PFD_SU", "PFD_AL", "PFD_AU", "PFD_BL", "PFD_BR", "PFD_LIM1", "PFD_LIM2", "PFD_WIND", "PFD_ENTRY",
	    "PFD_FM1", "PFD_FM2", "PFD_FM3", "PFD_WPT")
	add("LFT_WPN", "LFT_TGT", "LFT_TRNG", "LFT_STEER", "LFT_SUB", "LFT_A1", "LFT_A2", "LFT_A3", "LFT_B1", "LFT_B2", "LFT_B3",
	    "LFT_PA", "LFT_PT", "LFT_PS", "LFT_WPN2", "LFT_FPA", "LFT_CUE")
	-- every page: alerts
	add("ALERT")
end
