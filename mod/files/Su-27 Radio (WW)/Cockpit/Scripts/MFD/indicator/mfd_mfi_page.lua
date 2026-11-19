-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: the pages of the MiG-29 MFD add-on's MFI
-- edition, laid out for the Su-27's square screen (152 x 144 mm; the
-- MiG-29's is tall, so lists run in two columns where the MiG has one).
-- Loaded from mfd_page.lua (before the frame) with its helpers in S27PH.
-- Values: MFD/mfd_mfi_dev.lua, as S27MFD_M_* parameters.
--   ATK  LOFT  SMS          TAC  SA  PIC  FLT  RWR
--   NAV  RTE  PFD  LND  PNT  BCN    COM  UKV  KV    SYS  FUEL  DTC
-- Page units: the screen is +-0.855 across, +-0.81 up; the frame's
-- bands leave +-0.755 x +-0.695 for the page.
-----------------------------------------------------------------------
local D = S27PH
local text, simple, mesh, line_obj = D.text, D.simple, D.mesh, D.line_obj
local poly_lines, circle_pts, circle_fill, band, outline = D.poly_lines, D.circle_pts, D.circle_fill, D.band, D.outline
local vis, col, fnt, tsize, char_w, char_h = D.vis, D.col, D.fnt, D.tsize, D.char_w, D.char_h
local G, LW, Y5, X5, PG, MFI = D.G, D.LW, D.Y5, D.X5, D.PG, D.MFI

-- text parameters: only the ones the device fills (SIT_MFI.texts)
local KNOWN = {}
for _, n in ipairs(MFI.texts) do KNOWN[n] = true end
S27MFI_PAGE_TEXTS = {}
local function tp(n)
	if not KNOWN[n] then error("MFI text parameter not in SIT_MFI.texts: " .. n) end
	S27MFI_PAGE_TEXTS[n] = true
	return "S27MFD_M_" .. n
end

-- inks (raw: the MFI colours themselves, made linear by col / fnt)
local I = MFI.ink
local function ink(c) return fnt(c[1], c[2], c[3], true) end
local function mat(c, a) return col(c[1], c[2], c[3], a or 255, true) end
local K = {black = ink(I.black), green = ink(I.green), red = ink(I.red), amber = ink(I.amber), blue = ink(I.blue),
           grey = ink(I.grey), cyan = ink(I.cyan), yellow = ink(I.yellow), magenta = ink(I.magenta), orange = ink(I.orange),
           paper = ink(MFI.paper)}
-- thick font inks (test 3: the MiG-29 MFI's bold texts)
local FB = D.fntb or fnt
local function inkb(c) return FB(c[1], c[2], c[3], true) end
local KB = {black = inkb(I.black), green = inkb(I.green), red = inkb(I.red), dkgreen = inkb(I.dkgreen), dkyellow = inkb(I.dkyellow),
            blue = inkb(I.blue), cyan = inkb(I.cyan), amber = inkb(I.amber), grey = inkb(I.grey)}
local MK = {black = mat(I.black), green = mat(I.green), red = mat(I.red), amber = mat(I.amber), blue = mat(I.blue),
            grey = mat(I.grey), cyan = mat(I.cyan), yellow = mat(I.yellow), magenta = mat(I.magenta), orange = mat(I.orange),
            paper = mat(MFI.paper), dim = mat({70, 75, 85}), ring = mat(MFI.sa_ring), arc = mat(MFI.sa_arc)}

-- sizes (capital height, page units)
-- (test 3: x SIT_MFI.txt_k, MiG-sized on this screen; were too small in DCS)
local TK = MFI.txt_k or 1
local TX  = tsize(0.031 * TK)     -- rows
local TXC = tsize(0.028 * TK)     -- two-column rows
local TXL = tsize(0.048 * TK)     -- big readouts
local TXM = tsize(0.038 * TK)     -- titles
local TXT_T = tsize(0.025 * TK)   -- small notes
local LX, RXE = -0.74, 0.74  -- left / right edge of the page's text
local TOP = 0.655            -- title line
local LWM = 0.005            -- line width

local function cw(d) return char_w(d) end
local function ch(d) return char_h(d) end
local function root(name, pg)
	simple(name, "sit_root", {0, 0, 0}, {"S27MFD_PAGE"}, {vis(0, pg - 0.5, pg + 0.5)})
end
local function sub(name, parent, param, lo, hi)
	simple(name, parent, {0, 0, 0}, {param}, {vis(0, lo, hi)})
end
-- a parameter text (S27MFD_M_<p>): vis = {param, lo, hi}
local function T(par, n, x, y, p, f, d, al, v, fmt)
	return text(par .. "_" .. n, par, {x, y, 0}, f or K.black, d or TX, al or "LeftCenter", nil, tp(p), v, fmt)
end
-- a number parameter (S27MFD_M_<p>, not a text one) with its format
local function N(par, n, x, y, p, f, d, al, v, fmt)
	return text(par .. "_" .. n, par, {x, y, 0}, f or K.black, d or TX, al or "LeftCenter", nil, "S27MFD_M_" .. p, v, fmt or "%.0f")
end
-- a parameter text in one of several inks: cparam 1..#fonts picks it
local function TC(par, n, x, y, p, fonts, cparam, d, al)
	for c, f in ipairs(fonts) do T(par, n .. "_" .. c, x, y, p, f, d, al, {cparam, c - 0.5, c + 0.5}) end
end
local function S(par, n, x, y, s, f, d, al, v)
	return text(par .. "_" .. n, par, {x, y, 0}, f or K.black, d or TX, al or "LeftCenter", s, nil, v)
end
local function rect(par, n, x0, y0, x1, y1, m, params, ctrls)
	mesh(par .. "_" .. n, par, "triangles", {{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, {0, 1, 2, 0, 2, 3}, m, nil, params, ctrls)
end
local function hline(par, n, y, x0, x1, m)
	rect(par, n, x0 or LX, y - LWM / 2, x1 or RXE, y + LWM / 2, m or MK.blue)
end
local function vline(par, n, x, y0, y1, m)
	rect(par, n, x - LWM / 2, y0, x + LWM / 2, y1, m or MK.blue)
end
-- outlined box, centre (cx, cy)
local function box(par, n, cx, cy, w, h, m, lw)
	local t = lw or LWM
	local x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
	local v = {{x0, y1}, {x1, y1}, {x1, y1 - t}, {x0, y1 - t}, {x0, y0 + t}, {x1, y0 + t}, {x1, y0}, {x0, y0},
	           {x0, y1}, {x0 + t, y1}, {x0 + t, y0}, {x0, y0}, {x1 - t, y1}, {x1, y1}, {x1, y0}, {x1 - t, y0}}
	local idx = {}
	for q = 0, 3 do local b = q * 4; for _, k in ipairs({0, 1, 2, 0, 2, 3}) do idx[#idx + 1] = b + k end end
	mesh(par .. "_" .. n, par, "triangles", v, idx, m or MK.black)
end
-- a text in a box; x = centre (or the box's left edge with "LeftCenter")
local function boxed(par, n, x, y, s, f, d, m, al)
	d = d or TX
	local w = #s * cw(d) + 0.05
	local cx = (al == "LeftCenter") and (x + w / 2) or x
	S(par, n, cx, y, s, f, d, "CenterCenter")
	box(par, n .. "_box", cx, y, w, ch(d) + 0.035, m)
end
local function title(par, s) boxed(par, "title", 0, TOP, s, K.black, TXM, MK.black) end
-- amber section header in a box with a blue line after it
local function head(par, n, x, y, s, x1, d)
	d = d or TXC
	boxed(par, n, x, y, s, K.amber, d, MK.amber, "LeftCenter")
	hline(par, n .. "_hl", y, x + #s * cw(d) + 0.07, x1 or RXE)
end
local function ring(r, w, n) return band(circle_pts(r, n), circle_pts(r - w, n)) end
-- the aircraft symbol (black, as the MiG-29 MFI)
local OWN = {{0, 0.06}, {0.010, 0.026}, {0.048, 0.0}, {0.048, -0.010}, {0.009, 0.0},
	{0.007, -0.034}, {0.022, -0.047}, {0, -0.043}, {-0.022, -0.047}, {-0.007, -0.034},
	{-0.009, 0.0}, {-0.048, -0.010}, {-0.048, 0.0}, {-0.010, 0.026}}
local function own_sym(par, n, f, m)
	local pts = {}
	for k, p in ipairs(OWN) do pts[k] = {p[1] * f, p[2] * f} end
	local v, i = poly_lines(pts, true)
	mesh(par .. "_" .. n, par, "lines", v, i, m or MK.black)
end
-- compass rose (ticks every 5 / 10 / 30 deg) turned by rparam, upright
-- labels N 3 6 E ... at radius lr
local function rose(par, n, R, rparam, lr, d)
	simple(par .. "_" .. n, par, {0, 0, 0}, {rparam}, {{"rotate_using_parameter", 0, 1}})
	local tv, ti = {}, {}
	for deg = 0, 355, 5 do
		local len = (deg % 30 == 0) and 0.055 or ((deg % 10 == 0) and 0.038 or 0.022)
		local a = math.rad(90 - deg)
		local ca, sa = math.cos(a), math.sin(a)
		local px, py = -sa * LWM / 2, ca * LWM / 2
		local r0, r1 = R - len, R
		local k = #tv
		tv[k + 1] = {r0 * ca + px, r0 * sa + py}; tv[k + 2] = {r1 * ca + px, r1 * sa + py}
		tv[k + 3] = {r1 * ca - px, r1 * sa - py}; tv[k + 4] = {r0 * ca - px, r0 * sa - py}
		for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
	end
	mesh(par .. "_" .. n .. "_t", par .. "_" .. n, "triangles", tv, ti, MK.black)
	local names = {[0] = "N", [30] = "3", [60] = "6", [90] = "E", [120] = "12", [150] = "15",
	               [180] = "S", [210] = "21", [240] = "24", [270] = "W", [300] = "30", [330] = "33"}
	for deg = 0, 330, 30 do
		local a = math.rad(deg)
		local nm = par .. "_" .. n .. "_" .. deg
		simple(nm, par .. "_" .. n, {lr * math.sin(a), lr * math.cos(a), 0})
		simple(nm .. "_u", nm, {0, 0, 0}, {rparam}, {{"rotate_using_parameter", 0, -1}})
		text(nm .. "_x", nm .. "_u", {0, 0, 0}, (deg % 90 == 0) and K.black or K.grey, d or TX, "CenterCenter", names[deg])
	end
end

---------------------------------------------------------------------------
-- FUEL: FPAS (fuel, flow, at the next steerpoint, best range / endurance,
-- bingo and home), two columns. Left 1 BNGO (keypad + ВВОД), left 2 HOME.
---------------------------------------------------------------------------
do
	local TXF = tsize(0.028 * 1.12)   -- (two full columns: a little smaller than the other pages)
	local r = "mf_fu"
	root(r, PG.FUEL)
	title(r, "FPAS")
	T(r, "tot", LX, 0.555, "FU_TOT", K.black, TXL)
	T(r, "int", LX, 0.465, "FU_INT", K.grey, TXF)
	T(r, "flow", 0.03, 0.465, "FU_FLOW", K.black, TXF)
	T(r, "eng", RXE, 0.585, "FU_ENG", K.black, TXF, "RightCenter")
	T(r, "egt", RXE, 0.525, "FU_EGT", K.black, TXF, "RightCenter", {"S27MFD_M_FU_EGTW", -0.5, 0.5})
	T(r, "egtr", RXE, 0.525, "FU_EGT", K.red, TXF, "RightCenter", {"S27MFD_M_FU_EGTW", 0.5, 1.5})
	local XL, XR, X1 = LX, 0.03, -0.03
	head(r, "cur", XL, 0.37, "CURRENT", X1, TXF)
	T(r, "to", XL, 0.29, "FU_TO", K.amber, TXF)
	T(r, "torng", XL, 0.22, "FU_TORNG", K.black, TXF)
	T(r, "sr", XL, 0.15, "FU_SR", K.black, TXF)
	head(r, "best", XL, 0.05, "BEST RANGE (EST)", X1, TXF)
	T(r, "b1", XL, -0.03, "FU_B1", K.black, TXF)
	T(r, "b2", XL, -0.10, "FU_B2", K.black, TXF)
	T(r, "b4", XL, -0.17, "FU_B4", K.grey, TXF)
	head(r, "end", XR, 0.37, "BEST ENDURANCE", nil, TXF)
	T(r, "b3", XR, 0.29, "FU_B3", K.black, TXF)
	T(r, "res", XR, 0.22, "FU_RES", K.grey, TXF)
	head(r, "bngh", XR, 0.05, "BINGO / HOME", nil, TXF)
	T(r, "bng", XR, -0.03, "FU_BNG", K.black, TXF, nil, {"S27MFD_M_FU_BW", -0.5, 0.5})
	T(r, "bngr", XR, -0.03, "FU_BNG", K.red, TXF, nil, {"S27MFD_M_FU_BW", 0.5, 1.5})
	T(r, "home", XR, -0.10, "FU_HOME", K.black, TXF)
	T(r, "need", XR, -0.17, "FU_NEED", K.black, TXF)
	T(r, "harr", XR, -0.24, "FU_HARR", K.grey, TXF)
	-- fuel bar (total, 0 .. full) with the bingo mark
	local Y0, H0, X0, X9 = -0.42, 0.06, -0.70, 0.70
	S(r, "bart", X0, Y0 + 0.075, "TOTAL", K.blue, TXT_T)
	box(r, "barf", 0, Y0, X9 - X0 + 0.02, H0 + 0.02, MK.black)
	for k = 1, 20 do
		local a, b = X0 + (X9 - X0) * (k - 1) / 20 + 0.004, X0 + (X9 - X0) * k / 20 - 0.004
		rect(r, "bar" .. k, a, Y0 - H0 / 2, b, Y0 + H0 / 2, MK.green, {"S27MFD_FUEL_FRAC"}, {vis(0, (k - 0.5) / 20, 1.5)})
	end
	simple(r .. "_bg", r, {X0, Y0, 0}, {"S27MFD_FUEL_BINGO"}, {{"move_left_right_using_parameter", 0, (X9 - X0) * G}})
	rect(r .. "_bg", "m", -0.005, -H0 / 2 - 0.03, 0.005, H0 / 2 + 0.03, MK.red)
	S(r .. "_bg", "t", 0, -H0 / 2 - 0.06, "B", K.red, TXT_T, "CenterCenter")
end

---------------------------------------------------------------------------
-- COM: one radio a page (UKV R-800 / KV R-864, as the MiG-29 MFI's R862 /
-- VHF / UHF): channel and frequency, the 20 presets, the other radio and
-- the fighter channel. Left CH+ CH- VOL+ VOL- MAN, right FC+ FC-.
---------------------------------------------------------------------------
do
	local r = "mf_rd"
	simple(r, "sit_root", {0, 0, 0}, {"S27MFD_M_RDO"}, {vis(0, 0.5, 2.5)})
	T(r, "title", 0, TOP, "RD_TITLE", K.black, TXM, "CenterCenter")
	hline(r, "tl", TOP - 0.05, -0.40, 0.40, MK.black)
	T(r, "freq", LX, 0.545, "RD_FREQ", K.green, TXL)
	T(r, "vol", RXE, 0.545, "RD_VOL", K.black, TX, "RightCenter")
	T(r, "src", LX, 0.465, "RD_SRC", K.grey, TXC, nil, {"S27MFD_M_RD_MSGON", -0.5, 0.5})
	T(r, "msg", LX, 0.465, "RD_MSG", K.amber, TXC, nil, {"S27MFD_M_RD_MSGON", 0.5, 1.5})
	hline(r, "sep", 0.42)
	for i = 1, 20 do
		local x = (i <= 10) and -0.70 or 0.06
		local y = 0.37 - ((i - 1) % 10) * 0.068
		T(r, "c" .. i, x, y, "RD_C" .. i, K.black, TXC, nil, {"S27MFD_M_RD_S" .. i, -0.5, 0.5})
		T(r, "cy" .. i, x, y, "RD_C" .. i, K.amber, TXC, nil, {"S27MFD_M_RD_S" .. i, 0.5, 1.5})
	end
	hline(r, "sep2", -0.33)
	T(r, "oth", LX, -0.40, "RD_OTHER", K.black, TXC)
	S(r, "fch", LX, -0.48, "FIGHTER CHANNEL", K.blue, TXC)
	T(r, "fcn", -0.20, -0.48, "RD_FC", K.cyan, TX)
end

---------------------------------------------------------------------------
-- DTC: the data cartridges for this map (MSN = the mission's own), right
-- 1-5 read one, left BACK RFSH PREV NEXT; the one in use amber.
---------------------------------------------------------------------------
do
	local r = "mf_dt"
	root(r, PG.DTM)
	T(r, "title", 0, TOP, "DTC_TITLE", K.black, TX, "CenterCenter")
	hline(r, "tl", TOP - 0.05)
	for k = 1, 5 do
		T(r, "i" .. k, 0.70, Y5[k], "DTC_I" .. k, K.black, TX, "RightCenter", {"S27MFD_M_DTC_V" .. k, 0.5, 1.5})
		T(r, "iy" .. k, 0.70, Y5[k], "DTC_I" .. k, K.amber, TX, "RightCenter", {"S27MFD_M_DTC_V" .. k, 1.5, 2.5})
		S(r, "ar" .. k, 0.745, Y5[k], "<", K.black, TX, "RightCenter", {"S27MFD_M_DTC_V" .. k, 0.5, 2.5})
	end
	hline(r, "bl", -0.47)
	T(r, "d1", LX, -0.53, "DTC_D1", K.amber, TXC)
	T(r, "d2", LX, -0.60, "DTC_D2", K.black, TXC)
	T(r, "d3", LX, -0.67, "DTC_D3", K.black, TXC)
	T(r, "pg", RXE, -0.67, "DTC_PAGE", K.grey, TXC, "RightCenter")
end

---------------------------------------------------------------------------
-- FLIGHT: the flight (slots 1-4) on R1-R4, details of the picked one on the
-- left; ADD lists the friendly aircraft on R1-R5 (press = in / out of the
-- flight), PREV / NEXT page it, DEL takes the picked one out, AUTO = the
-- own group in name order
---------------------------------------------------------------------------
do
	local r = "mf_fl"
	root(r, PG.FLT)
	T(r, "title", 0, TOP, "FLT_TITLE", K.black, TX, "CenterCenter")
	hline(r, "tl", TOP - 0.05)
	for k = 1, 5 do
		local y = Y5[k]
		T(r, "r" .. k, 0.70, y + 0.025, "FLT_R" .. k, K.black, TX, "RightCenter", {"S27MFD_M_FLT_M" .. k, 0.5, 1.5})
		T(r, "ry" .. k, 0.70, y + 0.025, "FLT_R" .. k, K.amber, TX, "RightCenter", {"S27MFD_M_FLT_M" .. k, 1.5, 2.5})
		T(r, "rg" .. k, 0.70, y + 0.025, "FLT_R" .. k, K.green, TX, "RightCenter", {"S27MFD_M_FLT_M" .. k, 2.5, 3.5})
		T(r, "rs" .. k, 0.70, y - 0.045, "FLT_S" .. k, K.grey, TXT_T, "RightCenter", {"S27MFD_M_FLT_M" .. k, 0.5, 3.5})
		S(r, "ar" .. k, 0.745, y + 0.025, "<", K.black, TX, "RightCenter", {"S27MFD_M_FLT_M" .. k, 0.5, 3.5})
	end
	for i = 1, 12 do
		TC(r, "d" .. i, LX, 0.56 - (i - 1) * 0.085, "FLT_D" .. i, {K.black, K.green, K.red, K.amber, K.grey, K.blue}, "S27MFD_M_FLT_C" .. i, TXC)
	end
	T(r, "pg", LX, -0.67, "FLT_PG", K.grey, TXC)
end

---------------------------------------------------------------------------
-- PICTURE: hostile groups (BULLS / BRAA, altitude, aspect), the call for
-- the picked one, a north-up plot round the bullseye (CALL BULL) or the
-- jet (CALL BRAA). Left RNG+ RNG- AUTO INTC CALL, right G1-G5.
---------------------------------------------------------------------------
do
	local r = "mf_pc"
	root(r, PG.PIC)
	T(r, "hdr", LX, 0.65, "PIC_HDR", K.green, TX)
	T(r, "sort", RXE, 0.65, "PIC_SORT", K.black, TX, "RightCenter")
	S(r, "cols", LX, 0.575, "GRP BULLS    BRAA      ALT   ASP", K.blue, TX)
	hline(r, "cl", 0.535)
	local RS = 0.085
	for k = 1, 5 do
		local y = 0.48 - (k - 1) * RS
		T(r, "row" .. k, LX, y, "PIC_R" .. k, KB.red, TX, nil, {"S27MFD_M_PIC_C" .. k, 0.5, 1.5})
		T(r, "rowf" .. k, LX, y, "PIC_R" .. k, KB.green, TX, nil, {"S27MFD_M_PIC_C" .. k, 1.5, 2.5})
		sub(r .. "_sb" .. k, r, "S27MFD_M_PIC_S" .. k, 0.5, 1.5)
		box(r .. "_sb" .. k, "b", 0, y, 1.50, 0.075, MK.black)
	end
	hline(r, "cl2", 0.035)
	-- the call (left, under the list) and the plot (right)
	S(r, "callh", LX, -0.03, "CALL", K.blue, TX)
	T(r, "call1", LX, -0.11, "PIC_K1", K.black, TXC)
	T(r, "call2", LX, -0.18, "PIC_K2", K.black, TXC)
	local PX, PY, PR = 0.40, -0.36, 0.30
	simple(r .. "_plot", r, {PX, PY, 0})
	local RW = LWM * 1.2
	local cv, ci = ring(PR, RW, 64)
	mesh(r .. "_ring1", r .. "_plot", "triangles", cv, ci, MK.dim)
	cv, ci = ring(PR / 2, RW, 48)
	mesh(r .. "_ring2", r .. "_plot", "triangles", cv, ci, MK.dim)
	T(r, "scale", PX - PR - 0.02, PY + PR - 0.02, "PIC_PR", K.black, TXT_T, "RightCenter")
	simple(r .. "_be", r .. "_plot", {0, 0, 0}, {"S27MFD_M_PIC_BX", "S27MFD_M_PIC_BY", "S27MFD_M_PIC_BE"},
		{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 1.5)})
	do
		local bv, bi = ring(0.016, LWM * 0.8, 16)
		mesh(r .. "_be_c", r .. "_be", "triangles", bv, bi, MK.green)
		mesh(r .. "_be_x", r .. "_be", "lines", {{-0.03, 0}, {0.03, 0}, {0, -0.03}, {0, 0.03}}, {0, 1, 2, 3}, MK.green)
		S(r .. "_be", "l", 0.025, -0.04, "BE", K.green, TXT_T)
	end
	simple(r .. "_own", r .. "_plot", {0, 0, 0}, {"S27MFD_M_PIC_OX", "S27MFD_M_PIC_OY", "S27MFD_M_PIC_OV"},
		{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 1.5)})
	simple(r .. "_own_r", r .. "_own", {0, 0, 0}, {"S27MFD_M_PIC_OH"}, {{"rotate_using_parameter", 0, 1}})
	own_sym(r .. "_own_r", "s", 0.6)
	-- groups: 1 hostile, 2 hostile picked; red diamond + track line
	for k = 1, 5 do
		local g = r .. "_g" .. k
		local gv = "S27MFD_M_PIC_G" .. k .. "_V"
		simple(g, r .. "_plot", {0, 0, 0}, {"S27MFD_M_PIC_G" .. k .. "_X", "S27MFD_M_PIC_G" .. k .. "_Y", gv},
			{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 2.5)})
		simple(g .. "_r", g, {0, 0, 0}, {"S27MFD_M_PIC_G" .. k .. "_H"}, {{"rotate_using_parameter", 0, 1}})
		local d, w = 0.032, LWM * 1.4
		local dv, di = band({{0, d}, {d, 0}, {0, -d}, {-d, 0}}, {{0, d - w}, {d - w, 0}, {0, -d + w}, {-d + w, 0}})
		mesh(g .. "_s", g .. "_r", "triangles", dv, di, MK.red)
		rect(g .. "_r", "hl", -LWM / 2, d + 0.008, LWM / 2, d + 0.06, MK.red)
		local sv, si = ring(0.055, LWM * 0.8, 24)
		mesh(g .. "_sel", g, "triangles", sv, si, MK.black, nil, {gv}, {vis(0, 1.5, 2.5)})
		S(g, "n", 0.045, 0.035, tostring(k), K.red, TXT_T)
	end
end

---------------------------------------------------------------------------
-- RWR (SPO-15): emitters round the jet (stronger = nearer the middle),
-- green search, red lock (ring), launch (second ring, blinking); compass
-- rose turned with the heading; the emitters listed on the right
---------------------------------------------------------------------------
do
	local r = "mf_rw"
	root(r, PG.RWR)
	local CX, CY, R = -0.25, -0.02, 0.50
	simple(r .. "_c", r, {CX, CY, 0})
	local v, i = ring(R, LWM, 96)
	mesh(r .. "_ring", r .. "_c", "triangles", v, i, MK.black)
	v, i = ring(R * 0.5, LWM, 64)
	mesh(r .. "_ring2", r .. "_c", "triangles", v, i, MK.blue)
	rose(r .. "_c", "rose", R, "S27MFD_M_RW_ROT", R - 0.10, TXT_T)
	mesh(r .. "_lub", r .. "_c", "triangles", {{-0.025, R + 0.045}, {0.025, R + 0.045}, {0, R + 0.005}}, {0, 1, 2}, MK.black)
	own_sym(r .. "_c", "ac", 1.0)
	-- heading box over the rose
	box(r, "hbox", CX, 0.645, 0.20, 0.075, MK.black)
	N(r, "hdg", CX, 0.645, "RW_HDG", K.black, TX, "CenterCenter", nil, "%03.0f")
	for k = 1, 12 do
		local n = r .. "_e" .. k
		local p = "S27MFD_M_RW" .. k .. "_"
		simple(n, r .. "_c", {0, 0, 0}, {p .. "X", p .. "Y", p .. "S"},
			{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 3.5)})
		-- symbol: a number ("27", with %.0f) or letters ("U", "AW"): _K picks
		sub(n .. "_num", n, p .. "K", 0.5, 1.5)
		sub(n .. "_str", n, p .. "K", -0.5, 0.5)
		for c, cf in ipairs({{K.green, 0.5, 1.5}, {K.red, 1.5, 3.5}}) do
			local vv = {p .. "S", cf[2], cf[3]}
			T(n .. "_str", "t" .. c, 0, 0, "RWR_T" .. k, cf[1], TX, "CenterCenter", vv)
			text(n .. "_n" .. c, n .. "_num", {0, 0, 0}, cf[1], TX, "CenterCenter", nil, p .. "N", vv, "%.0f")
		end
		v, i = ring(0.055, LWM, 24)
		mesh(n .. "_lk", n, "triangles", v, i, MK.red, nil, {p .. "S"}, {vis(0, 1.5, 3.5)})
		v, i = ring(0.080, LWM * 1.4, 28)
		mesh(n .. "_ln", n, "triangles", v, i, MK.red, nil, {p .. "S"}, {vis(0, 2.5, 3.5)})
	end
	S(r, "lh", 0.29, 0.64, "EMITTERS", K.blue, TXC)
	hline(r, "lsep", 0.595, 0.29, RXE)
	for k = 1, 6 do
		local y = 0.53 - (k - 1) * 0.075
		TC(r, "l" .. k, 0.29, y, "RWR_L" .. k, {K.green, K.amber, K.red}, "S27MFD_M_RWR_C" .. k, TXT_T)
	end
	T(r, "cm", RXE, -0.66, "RWR_CM", K.grey, TXC, "RightCenter")
end

---------------------------------------------------------------------------
-- SMS: the classic page's airframe and stations stay (drawn by
-- mfd_page.lua for the classic edition only), so the MFI page draws its
-- own: the jet from behind, stores under it, selected / gun / CM lines
---------------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "MFD/indicator/mfd_mfi_sms.lua")
S27MFI_SMS(D, {root = root, T = T, S = S, title = title, hline = hline, K = K, MK = MK, TX = TX, TXC = TXC, LX = LX})

---------------------------------------------------------------------------
-- NAV: RTE (steering to the steerpoint, the route list, time on target),
-- BCN (airfields / beacons nearest), PNT (route editor), LND (HSI)
---------------------------------------------------------------------------
do
	local r = "mf_nv"
	root(r, PG.NAV)
	title(r, "NAV")
	T(r, "src", RXE, TOP, "NAV_SRC", K.grey, TXC, "RightCenter")
	T(r, "stp", LX, 0.57, "NAV_STP", KB.green, TX)
	T(r, "brg", LX, 0.50, "NAV_BRG", K.black, TX)
	T(r, "time", 0.02, 0.57, "NAV_TIME", K.black, TX)
	T(r, "leg", 0.02, 0.50, "NAV_LEG", K.cyan, TX)
	-- steering bar: +-45 deg from the nose, diamond = command track
	local SY, SW = 0.385, 0.50
	rect(r, "sbar", -SW, SY - LWM / 2, SW, SY + LWM / 2, MK.black)
	do
		local tv, ti = {}, {}
		for k = -4, 4 do
			local x = SW * k / 4
			local hh = (k == 0) and 0.05 or ((k % 2 == 0) and 0.032 or 0.02)
			local b = #tv
			tv[b + 1] = {x - LWM / 2, SY - hh}; tv[b + 2] = {x + LWM / 2, SY - hh}; tv[b + 3] = {x + LWM / 2, SY}; tv[b + 4] = {x - LWM / 2, SY}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = b + q end
		end
		mesh(r .. "_sticks", r, "triangles", tv, ti, MK.black)
	end
	mesh(r .. "_snose", r, "triangles", {{0, SY - 0.055}, {0.03, SY - 0.095}, {-0.03, SY - 0.095}}, {0, 1, 2}, MK.black)
	simple(r .. "_sdia", r, {0, SY, 0}, {"S27MFD_M_NAV_STEER", "S27MFD_M_NAV_SV"},
		{{"move_left_right_using_parameter", 0, G * SW}, vis(1, 0.5, 1.5)})
	mesh(r .. "_sdiam", r .. "_sdia", "triangles", {{0, 0.08}, {0.03, 0.045}, {0, 0.01}, {-0.03, 0.045}}, {0, 1, 2, 0, 2, 3}, MK.green)
	S(r, "sl", -SW - 0.03, SY, "L", K.grey, TXT_T, "RightCenter")
	S(r, "sr", SW + 0.03, SY, "R", K.grey, TXT_T, "LeftCenter")
	T(r, "cmd", 0, 0.265, "NAV_CMD", K.green, TX, "CenterCenter")
	hline(r, "sep1", 0.215)
	S(r, "hd", LX, 0.165, "PT   NAME      BRG    DIST   ETA", K.blue, TX)
	for i = 1, 5 do
		local y = 0.095 - (i - 1) * 0.07
		TC(r, "w" .. i, LX, y, "NAV_L" .. i, {KB.black, KB.green, KB.cyan, KB.grey}, "S27MFD_M_NAV_C" .. i, TX)   -- (thick: MiG round 27)
		-- _T: 1 = has a TOT, 2 = TOT point cursor, 3 = both
		S(r, "tot" .. i, 0.50, y, "TOT", K.red, TXT_T, nil, {"S27MFD_M_NAV_T" .. i, 0.5, 1.5})
		S(r, "totc" .. i, 0.50, y, "TOT", K.red, TXT_T, nil, {"S27MFD_M_NAV_T" .. i, 2.5, 3.5})
		S(r, "cur" .. i, 0.64, y, "<", K.black, TX, nil, {"S27MFD_M_NAV_T" .. i, 1.5, 3.5})
	end
	-- time on target
	local P = r .. "_tb"
	simple(P, r, {0, 0, 0})
	hline(P, "tsep", -0.27)
	T(P, "thint", LX, -0.33, "TOT_HINT", K.grey, TXC, nil, {"S27MFD_M_TOT_ON", -0.5, 0.5})
	sub(r .. "_tot", P, "S27MFD_M_TOT_ON", 0.5, 1.5)
	local Q = r .. "_tot"
	T(Q, "l1", LX, -0.33, "TOT_L1", K.red, TXC)
	TC(Q, "st", RXE, -0.33, "TOT_ST", {K.green, K.amber, K.red}, "S27MFD_M_TOT_C", TXC, "RightCenter")
	T(Q, "spd", LX, -0.40, "TOT_SPD", K.black, TXC)
	do
		local x0, x1, yb = -0.60, 0.60, -0.52
		rect(Q, "scale", x0, yb - LWM / 2, x1, yb + LWM / 2, MK.black)
		local tv, ti = {}, {}
		for k = 0, 8 do
			local x = x0 + (x1 - x0) * k / 8
			local h = (k % 2 == 0) and 0.035 or 0.02
			local b = #tv
			tv[b + 1] = {x - LWM / 2, yb}; tv[b + 2] = {x + LWM / 2, yb}; tv[b + 3] = {x + LWM / 2, yb + h}; tv[b + 4] = {x - LWM / 2, yb + h}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = b + q end
		end
		mesh(Q .. "_ticks", Q, "triangles", tv, ti, MK.black)
		S(Q, "slow", x0 - 0.02, yb, "SLOW", K.grey, TXT_T, "RightCenter")
		S(Q, "fast", x1 + 0.02, yb, "FAST", K.grey, TXT_T, "LeftCenter")
		simple(Q .. "_req", Q, {0, 0, 0}, {"S27MFD_M_TOT_RX", "S27MFD_M_TOT_RV"}, {{"move_left_right_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
		box(Q .. "_req", "b", 0, yb + 0.04, 0.04, 0.05, MK.green)
		simple(Q .. "_gs", Q, {0, 0, 0}, {"S27MFD_M_TOT_GX", "S27MFD_M_TOT_GV"}, {{"move_left_right_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
		mesh(Q .. "_caret", Q .. "_gs", "triangles", {{0, yb - 0.008}, {0.025, yb - 0.055}, {-0.025, yb - 0.055}}, {0, 1, 2}, MK.cyan)
	end
	T(Q, "then", LX, -0.60, "TOT_THEN", K.black, TXC)
	T(Q, "fuel", LX, -0.67, "TOT_FUEL", K.black, TXC, nil, {"S27MFD_M_TOT_FC", 0.5, 1.5})
	T(Q, "fuela", LX, -0.67, "TOT_FUEL", K.amber, TXC, nil, {"S27MFD_M_TOT_FC", 1.5, 2.5})
	-- sequencing / the ADD entry / a message (over the TOT block's last line while it shows)
	T(r, "seq", RXE, -0.235, "NAV_SEQ", K.grey, TXT_T, "RightCenter", {"S27MFD_M_NAV_ADDM", -0.5, 0.5})
	T(r, "seqa", RXE, -0.235, "NAV_SEQ", K.amber, TXT_T, "RightCenter", {"S27MFD_M_NAV_ADDM", 0.5, 1.5})
end

do
	-- BCN: the nearest airfields of the map (the Su-27's ARK-22 homes on
	-- their beacons), bearing / range; left PREV / NEXT page
	local r = "mf_bc"
	root(r, PG.BCN)
	title(r, "BCN")
	T(r, "hd", LX, 0.565, "BCN_HD", K.blue, TX)
	hline(r, "hl", 0.525)
	for i = 1, 8 do
		TC(r, "l" .. i, LX, 0.46 - (i - 1) * 0.08, "BCN_L" .. i, {K.black, K.green, K.grey}, "S27MFD_M_BCN_C" .. i, TX)
	end
	hline(r, "hl2", -0.22)
	T(r, "sel", LX, -0.29, "BCN_SEL", K.green, TX)
	T(r, "pg", RXE, -0.67, "BCN_PG", K.grey, TXC, "RightCenter")
end

do
	-- PNT (route editor, the MiG-29's EDIT): its own cursor on the working
	-- route; right 1-5 put it on a point, left UP / DN move the point one
	-- place, POS a new position (lat / long on the keypad), ADD a point
	-- after it, DEL (twice); right 5 STP: fly to it
	local r = "mf_pn"
	root(r, PG.PNT)
	T(r, "title", 0, TOP, "PNT_TITLE", K.black, TX, "CenterCenter")
	hline(r, "tl", TOP - 0.05)
	T(r, "sel", LX, 0.56, "PNT_SEL", K.green, TX)
	T(r, "ll", LX, 0.49, "PNT_LL", K.black, TXC)
	for k = 1, 4 do
		TC(r, "r" .. k, 0.70, Y5[k] - 0.035, "PNT_R" .. k, {K.black, K.green, K.cyan}, "S27MFD_M_PNT_C" .. k, TX, "RightCenter")
		S(r, "ar" .. k, 0.745, Y5[k] - 0.035, "<", K.black, TX, "RightCenter", {"S27MFD_M_PNT_C" .. k, 1.5, 9})
	end
	TC(r, "r5", 0.70, -0.43, "PNT_R5", {K.black, K.green, K.cyan}, "S27MFD_M_PNT_C5", TX, "RightCenter")
	hline(r, "bl", -0.50)
	T(r, "msg", LX, -0.57, "PNT_MSG", K.grey, TXC, nil, {"S27MFD_M_PNT_MSGC", -0.5, 0.5})
	T(r, "msga", LX, -0.57, "PNT_MSG", K.amber, TXC, nil, {"S27MFD_M_PNT_MSGC", 0.5, 1.5})
	T(r, "pg", RXE, -0.67, "PNT_PG", K.grey, TXC, "RightCenter")
end

do
	-- LND: the HSI alone (MiG-29 MFI LND): CRS / heading box / HDG on top,
	-- speeds and wind under them, the rose with heading bug, course arrow
	-- and deviation bar, steerpoint pointer (orange); the steerpoint bottom
	-- left. Left HDG CRS (keypad + ВВОД), STP (leg / direct), SYNC (bug = heading)
	local r = "mf_ln"
	root(r, PG.LND)
	local CY, R = -0.13, 0.50
	simple(r .. "_c", r, {0, CY, 0})
	local v, i = ring(R, LWM, 96)
	mesh(r .. "_ring", r .. "_c", "triangles", v, i, MK.black)
	rose(r .. "_c", "rose", R, "S27MFD_M_LND_ROT", R - 0.10, TX)
	mesh(r .. "_lub", r .. "_c", "triangles", {{-0.025, R + 0.045}, {0.025, R + 0.045}, {0, R + 0.005}}, {0, 1, 2}, MK.black)
	own_sym(r .. "_c", "ac", 1.2)
	-- heading bug (blue notch)
	simple(r .. "_bug", r .. "_c", {0, 0, 0}, {"S27MFD_M_LND_BUGR"}, {{"rotate_using_parameter", 0, 1}})
	mesh(r .. "_bugm", r .. "_bug", "triangles",
		{{-0.04, R + 0.008}, {-0.015, R + 0.008}, {-0.015, R - 0.03}, {0.015, R - 0.03}, {0.015, R + 0.008}, {0.04, R + 0.008}, {0.04, R - 0.055}, {-0.04, R - 0.055}},
		{0, 1, 7, 1, 2, 7, 2, 6, 7, 2, 3, 6, 3, 5, 6, 3, 4, 5}, MK.blue)
	-- course arrow and deviation bar (green)
	simple(r .. "_crs", r .. "_c", {0, 0, 0}, {"S27MFD_M_LND_CRSR"}, {{"rotate_using_parameter", 0, 1}})
	local w = LWM * 1.2
	rect(r .. "_crs", "h", -w, 0.25, w, R - 0.09, MK.green)
	mesh(r .. "_crs_a", r .. "_crs", "triangles", {{0, R - 0.03}, {0.035, R - 0.10}, {-0.035, R - 0.10}}, {0, 1, 2}, MK.green)
	rect(r .. "_crs", "t", -w, -(R - 0.09), w, -0.25, MK.green)
	for _, dx in ipairs({-0.20, -0.10, 0.10, 0.20}) do
		local dv, di = ring(0.013, LWM, 12)
		for _, p in ipairs(dv) do p[1] = p[1] + dx end
		mesh(r .. "_dot" .. tostring(dx), r .. "_crs", "triangles", dv, di, MK.black)
	end
	simple(r .. "_cdi", r .. "_crs", {0, 0, 0}, {"S27MFD_M_LND_CDI"}, {{"move_left_right_using_parameter", 0, G * 0.20}})
	rect(r .. "_cdi", "b", -w, -0.23, w, 0.23, MK.green)
	-- steerpoint pointer (orange)
	simple(r .. "_p1", r .. "_c", {0, 0, 0}, {"S27MFD_M_LND_B1R", "S27MFD_M_LND_B1V"}, {{"rotate_using_parameter", 0, 1}, vis(1, 0.5, 1.5)})
	rect(r .. "_p1", "h", -LWM / 2, R - 0.22, LWM / 2, R - 0.05, MK.orange)
	rect(r .. "_p1", "t", -LWM / 2, -(R - 0.05), LWM / 2, -(R - 0.18), MK.orange)
	mesh(r .. "_p1_a", r .. "_p1", "triangles", {{0, R - 0.015}, {0.035, R - 0.075}, {-0.035, R - 0.075}}, {0, 1, 2}, MK.orange)
	-- readouts: heading box with a pointer down to the lubber line, CRS left, HDG (bug) right
	local HY = 0.625
	box(r, "hbox", 0, HY, 0.22, 0.085, MK.black)
	mesh(r .. "_hptr", r, "triangles", {{-0.03, HY - 0.045}, {0.03, HY - 0.045}, {0, HY - 0.075}}, {0, 1, 2}, MK.black)
	N(r, "hdgv", 0, HY, "LND_HDGN", K.black, TXL, "CenterCenter", nil, "%03.0f")
	S(r, "crsl", -0.33, HY + 0.035, "CRS", K.black, TXT_T, "CenterCenter")
	S(r, "bugl", 0.33, HY + 0.035, "HDG", K.black, TXT_T, "CenterCenter")
	N(r, "crsv", -0.33, HY - 0.03, "LND_CRSN", K.green, TX, "CenterCenter", nil, "%03.0f")
	N(r, "bugv", 0.33, HY - 0.03, "LND_BUGN", K.blue, TX, "CenterCenter", nil, "%03.0f")
	T(r, "crsm", LX, HY + 0.035, "LND_CRSM", K.green, TXT_T)
	T(r, "spd", LX, 0.505, "LND_SPD", K.black, TXC)
	T(r, "wind", RXE, 0.505, "LND_WIND", K.green, TXC, "RightCenter")
	hline(r, "sep", 0.465, LX, RXE, MK.black)
	T(r, "stp1", LX, -0.60, "LND_STP1", K.black, TXC)
	T(r, "stp2", LX, -0.67, "LND_STP2", K.black, TXC)
	T(r, "entry", LX, 0.42, "LND_ENTRY", K.amber, TXC)
end

---------------------------------------------------------------------------
-- PFD (MiG-29 MFI's dl_pfd.lua, its own Su-27 layout) and LOFT
---------------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "MFD/indicator/mfd_mfi_pfd.lua")
S27MFI_PFD_PAGE(D, {root = root, T = T, S = S, K = K, MK = MK, TX = TX, TXC = TXC, TXL = TXL, TXT_T = TXT_T, tp = tp, rect = rect, box = box, hline = hline})
dofile(LockOn_Options.script_path .. "MFD/indicator/mfd_mfi_loft.lua")
S27MFI_LOFT_PAGE(D, {KB = KB, root = root, T = T, S = S, K = K, MK = MK, TX = TX, TXC = TXC, TXL = TXL, TXT_T = TXT_T, tp = tp, rect = rect, box = box, hline = hline, title = title})

---------------------------------------------------------------------------
-- SA additions (MFI SA): IAS / GS box top left, heading box, H= box top
-- right, the range under it, intercept block, steerpoint block, and the
-- page's short messages
---------------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "MFD/indicator/mfd_mfi_sa.lua")
S27MFI_SA_PAGE(D, {T = T, S = S, N = N, K = K, KB = KB, MK = MK, TX = TX, TXC = TXC, TXL = TXL, TXM = TXM, TXT_T = TXT_T, box = box, rect = rect, ring = ring,
	TRNG = tsize(0.048 * TK)})

-- every page: short alerts (BINGO / ALT MAX / MIN) over the page, red, flashing
do
	local r = "mf_al"
	simple(r, "sit_root", {0, 0, 0}, {"S27MFD_M_ALERT_ON"}, {vis(0, 0.5, 1.5)})
	-- (red and flashing: the device blinks S27MFD_M_ALERT_ON)
	rect(r, "bg", -0.55, 0.12, 0.55, 0.24, MK.paper)
	box(r, "box", 0, 0.18, 1.10, 0.12, MK.red, 0.008)
	T(r, "t", 0, 0.18, "ALERT", K.red, TXM, "CenterCenter")
end
