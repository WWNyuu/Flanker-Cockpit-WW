-----------------------------------------------------------------------
-- Su-27 MFD (WW): the MFD's pages (v0.2). SA, MENU, DTC, BIT, TIME, OWN,
-- FLIGHT and SA SETTINGS from the F-15C SIT (WW) add-on's MPCD pages (the
-- SA page = its SIT page: cyan ownship / own flight, green friendlies, red
-- hostiles, white unknowns, yellow route and bullseye; solid = own radar,
-- dotted = datalink only); PICTURE, RDR, NAV, HSI, COM, FUEL, SMS and RWR
-- after the Vitezovi MiG-29 MFD. One page at a time (S27MFD_PAGE).
-- All values come from MFD/mfd_device.lua as cockpit parameters S27MFD_*.
-- Units: 1 = 88.9 mm (SIT.G), the screen is +-0.855 across, +-0.81 up.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "MFD/mfd_config.lua")
SetScale(FOV)

local G   = SIT.G
local BOX = SIT.BOX
local LW  = 0.006            -- line width of rings and symbols
local S   = 0.035            -- contact symbol size

---------------------------------------------------------------------------
-- colours and fonts
---------------------------------------------------------------------------
local function col(r, g, b, a) return MakeMaterial(nil, {r, g, b, a or 255}) end
-- page font: the add-on's stroke font (a texture: monospaced, glyph in the
-- left FONT_CELL_W px of each 128 px cell, codes 32..126 row-major), or
-- DCS's Arial (SIT.FONT_STYLE = "arial")
local TEXF = SIT.FONT_STYLE ~= "arial"
local FONT_DESC = nil
if TEXF then
	local cw = SIT.FONT_CELL_W
	FONT_DESC = {
		texture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/s27mfd_font.dds",
		size       = {16, 16},
		resolution = {2048, 2048},
		default    = {cw, 128},
		chars      = {},
	}
	for code = 32, 126 do FONT_DESC.chars[#FONT_DESC.chars + 1] = {code, cw, 128} end
end
local function fnt(r, g, b)
	if TEXF then return MakeFont(FONT_DESC, {r, g, b, 255}) end
	return MakeFont({used_DXUnicodeFontData = "font_arial_13"}, {r, g, b, 255})
end
local M = {
	black   = col(0, 0, 0),
	ring    = col(170, 185, 175),
	own     = col(90, 215, 255),
	friend  = col(40, 230, 90),
	hostile = col(245, 60, 60),
	unknown = col(235, 235, 235),        -- unknown identity: white
	wing    = col(0, 220, 255),          -- own flight: cyan
	pdt     = col(80, 130, 255),         -- line to the primary designated target
	planf   = col(150, 160, 155),        -- aircraft outline (A/A, CBT JETT pages)
	sel     = col(40, 200, 80),          -- selected station fill
	route   = col(240, 200, 50),
	cyan    = col(0, 220, 255),
	bull    = col(240, 220, 60),
	white   = col(235, 235, 235),
	label   = col(120, 230, 150),
	-- threat rings: a background layer, dimmer and see-through, so the
	-- contacts on top of them stay readable
	thr_o   = col(200, 60, 60, 140),     -- MEZ ring, we are outside
	thr_i   = col(250, 60, 60, 230),     -- MEZ ring, we are inside
}
local F = {
	green  = fnt(120, 230, 150),
	white  = fnt(235, 235, 235),
	grey   = fnt(170, 185, 175),
	red    = fnt(245, 60, 60),
	yellow = fnt(240, 230, 60),
	blue   = fnt(80, 160, 255),
	orange = fnt(255, 150, 40),
	cfriend = fnt(40, 230, 90),
	thr_o  = fnt(200, 70, 70),
	thr_i  = fnt(250, 60, 60),
	cyan   = fnt(0, 220, 255),
	magenta = fnt(230, 70, 230),
	route  = fnt(240, 200, 50),
}
-- text sizes, given as capital height in page units (the screen is -1..1).
-- Texture font: DCS makes a glyph cell defs[1] metres tall and
-- defs[2] x (cell width / height) wide, so defs[2] = defs[1] keeps the
-- letters' own proportions; metres -> page units: / G.
-- Arial (v0.4): ~15 x defs[1] tall, ~19 x defs[1] per character at width 0.5.
local FK, FW = SIT.FONT_SCALE or 1, SIT.FONT_WIDTH or 1
local ASPECT = (SIT.FONT_CELL_W or 68) / 128
local function tsize(cap)
	cap = cap * FK
	if TEXF then
		local h = cap * G / SIT.FONT_CAP
		return {h, h * FW, 0, 0}
	end
	local h = cap / 15.3
	return {h, h * 0.5 * FW, 0, 0}
end
-- advance of one character / capital height, in page units
local function char_w(d) if TEXF then return d[2] * ASPECT / G end return d[2] * 38.7 end
local function char_h(d) if TEXF then return d[1] * SIT.FONT_CAP / G end return d[1] * 15.3 end
local TXT_BIG   = tsize(0.064)   -- range scale
local TXT       = tsize(0.050)   -- time, cyan readout
local TXT_SMALL = tsize(0.040)   -- data blocks, compass rose
local TXT_BTN   = tsize(0.040)   -- button labels
local TXT_TINY  = tsize(0.031)   -- steerpoint numbers, status
local TXT_DATA  = tsize(0.033)   -- SIT corner data blocks (v0.8.1: smaller, less clutter)
local TXT_ROSE  = tsize(0.026)   -- compass rose numbers

---------------------------------------------------------------------------
-- element helpers
---------------------------------------------------------------------------
local function prm(e, params, ctrls)
	if params then e.element_params = params end
	if ctrls then e.controllers = ctrls end
end
local function simple(name, parent, pos, params, ctrls)
	local e = CreateElement "ceSimple"
	e.name = name
	e.init_pos = pos or {0, 0, 0}
	if parent then e.parent_element = parent end
	prm(e, params, ctrls)
	Add(e)
	return e
end
local function mesh(name, parent, prim, v, idx, mat, pos, params, ctrls)
	local e = CreateElement "ceMeshPoly"
	e.name = name
	e.primitivetype = prim
	e.vertices = v
	e.indices = idx
	e.material = mat
	e.init_pos = pos or {0, 0, 0}
	if parent then e.parent_element = parent end
	e.use_mipfilter = true
	e.additive_alpha = false
	prm(e, params, ctrls)
	Add(e)
	return e
end
-- many line pieces in ONE mesh (performance: DCS checks every element each
-- frame; a static drawing of 150 lines costs one element this way)
local function batch(name, parent, mat, pos)
	local B = {v = {}, i = {}}
	function B.add(pts, closed)
		local base, n = #B.v, #pts
		for _, q in ipairs(pts) do B.v[#B.v + 1] = {q[1], q[2]} end
		for k = 0, (closed and n or n - 1) - 1 do B.i[#B.i + 1] = base + k; B.i[#B.i + 1] = base + (k + 1) % n end
	end
	function B.done() if #B.i > 0 then mesh(name, parent, "lines", B.v, B.i, mat, pos) end end
	return B
end
-- fmt: a number format ("%.0f") for a parameter that holds a NUMBER. Text
-- parameters use "%s" and must never hold something number-like: DCS
-- stores "40" as the number 40, and "%s" with a number crashes DCS
-- (access violation in ceStringPoly, v0.3.0 - v0.3.2)
local function text(name, parent, pos, font, defs, align, value, param, vis, fmt)
	local e = CreateElement "ceStringPoly"
	e.name = name
	e.material = font
	e.init_pos = pos
	e.alignment = align or "CenterCenter"
	e.stringdefs = defs or TXT
	if parent then e.parent_element = parent end
	local params, ctrls = {}, {}
	if param then
		e.formats = {fmt or "%s"}
		params[#params + 1] = param
	else
		e.value = value
	end
	-- (the visibility check first: a hidden text is not formatted)
	if vis then
		params[#params + 1] = vis[1]
		ctrls[#ctrls + 1] = {"parameter_in_range", #params - 1, vis[2], vis[3]}
	end
	if param then ctrls[#ctrls + 1] = {"text_using_parameter", 0, 0} end
	if #params > 0 then prm(e, params, ctrls) end
	Add(e)
	return e
end
local function line_obj(name, parent, mat, width, params, ctrls)
	local e = CreateElement "ceSimpleLineObject"
	e.name = name
	e.material = mat
	e.width = width
	e.vertices = {{0, 0}, {0, 0}}
	e.init_pos = {0, 0, 0}
	e.parent_element = parent
	e.use_mipfilter = true
	e.additive_alpha = false
	prm(e, params, ctrls)
	Add(e)
	return e
end
local function vis(idx, lo, hi) return {"parameter_in_range", idx, lo, hi} end
local function at(param_x, param_y, extra)
	local p = {param_x, param_y}
	local c = {}
	-- (the visibility checks first: a hidden group is not moved)
	if extra then
		for _, x in ipairs(extra) do
			p[#p + 1] = x[1]
			c[#c + 1] = {"parameter_in_range", #p - 1, x[2], x[3]}
		end
	end
	c[#c + 1] = {"move_left_right_using_parameter", 0, G}
	c[#c + 1] = {"move_up_down_using_parameter", 1, G}
	return p, c
end

---------------------------------------------------------------------------
-- geometry helpers
---------------------------------------------------------------------------
local function circle_pts(r, n)
	local v = {}
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n
		v[#v + 1] = {r * math.cos(a), r * math.sin(a)}
	end
	return v
end
local function band(outer, inner)
	local v, idx, n = {}, {}, #outer
	for k = 1, n do v[k] = outer[k]; v[n + k] = inner[k] end
	for k = 0, n - 1 do
		local a, b = k, (k + 1) % n
		idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = n + b
		idx[#idx + 1] = a; idx[#idx + 1] = n + b; idx[#idx + 1] = n + a
	end
	return v, idx
end
local function dashed(outer, inner, sub)
	local v, idx, n = {}, {}, #outer
	local O, I = {}, {}
	for k = 1, n do
		local a, b = outer[k], outer[k % n + 1]
		local c, d = inner[k], inner[k % n + 1]
		for j = 0, sub - 1 do
			local t = j / sub
			O[#O + 1] = {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t}
			I[#I + 1] = {c[1] + (d[1] - c[1]) * t, c[2] + (d[2] - c[2]) * t}
		end
	end
	local m = #O
	for k = 1, m do v[k] = O[k]; v[m + k] = I[k] end
	for k = 0, m - 1, 2 do
		local a, b = k, (k + 1) % m
		idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = m + b
		idx[#idx + 1] = a; idx[#idx + 1] = m + b; idx[#idx + 1] = m + a
	end
	return v, idx
end
local function scaled(pts, f)
	local v = {}
	for k, p in ipairs(pts) do v[k] = {p[1] * f, p[2] * f} end
	return v
end
local function inradius(pts)
	local best = 1e9
	for k = 1, #pts do
		local a, b = pts[k], pts[k % #pts + 1]
		local ex, ey = b[1] - a[1], b[2] - a[2]
		local d = math.abs(a[1] * ey - a[2] * ex) / math.sqrt(ex * ex + ey * ey)
		if d < best then best = d end
	end
	return best
end
local function outline(pts, w, dash, sub)
	local inner = scaled(pts, 1 - w / inradius(pts))
	if dash then return dashed(pts, inner, sub) end
	return band(pts, inner)
end
local function circle_fill(r, n)
	local v, idx = {{0, 0}}, {}
	for i = 0, n - 1 do
		local a = 2 * math.pi * i / n
		v[#v + 1] = {r * math.cos(a), r * math.sin(a)}
	end
	for i = 1, n do idx[#idx + 1] = 0; idx[#idx + 1] = i; idx[#idx + 1] = (i % n) + 1 end
	return v, idx
end
local function poly_lines(pts, closed)
	local idx = {}
	local last = closed and #pts or #pts - 1
	for i = 0, last - 1 do idx[#idx + 1] = i; idx[#idx + 1] = (i + 1) % #pts end
	return pts, idx
end
-- a thick arc of radius r around (0, 0), only the parts inside the box
-- (the box is in page coordinates; oy = where the ownship sits)
local function clipped_ring(r, w, oy, n, dash, cy)
	cy = cy or 0     -- centre of the ring above the frame origin
	local v, idx = {}, {}
	local function ok(x, y) return math.abs(x) <= BOX and math.abs(y + oy) <= BOX end
	for k = 0, n - 1, (dash and 2 or 1) do
		local a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
		local p0 = {r * math.cos(a0), cy + r * math.sin(a0)}
		local p1 = {r * math.cos(a1), cy + r * math.sin(a1)}
		if ok(p0[1], p0[2]) and ok(p1[1], p1[2]) then
			local q0 = {(r - w) * math.cos(a0), cy + (r - w) * math.sin(a0)}
			local q1 = {(r - w) * math.cos(a1), cy + (r - w) * math.sin(a1)}
			local b = #v
			v[b + 1] = p0; v[b + 2] = p1; v[b + 3] = q1; v[b + 4] = q0
			idx[#idx + 1] = b; idx[#idx + 1] = b + 1; idx[#idx + 1] = b + 2
			idx[#idx + 1] = b; idx[#idx + 1] = b + 2; idx[#idx + 1] = b + 3
		end
	end
	return v, idx
end
local function ticks(r, len, w, oy)
	local v, idx = {}, {}
	for deg = 0, 330, 30 do
		if deg % 90 ~= 0 then
			local a = math.rad(90 - deg)
			local ca, sa = math.cos(a), math.sin(a)
			local px, py = -sa * w / 2, ca * w / 2
			local r0, r1 = r - len, r
			local x1, y1 = r1 * ca, r1 * sa
			if oy == nil or (math.abs(x1) <= BOX and math.abs(y1 + oy) <= BOX) then
				local k = #v
				v[k + 1] = {r0 * ca + px, r0 * sa + py}; v[k + 2] = {r1 * ca + px, r1 * sa + py}
				v[k + 3] = {r1 * ca - px, r1 * sa - py}; v[k + 4] = {r0 * ca - px, r0 * sa - py}
				idx[#idx + 1] = k; idx[#idx + 1] = k + 1; idx[#idx + 1] = k + 2
				idx[#idx + 1] = k; idx[#idx + 1] = k + 2; idx[#idx + 1] = k + 3
			end
		end
	end
	return v, idx
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
-- v0.3.2: hidden until the device has given every text parameter a string
simple("sit_root", nil, {0, 0, 0}, {"S27MFD_READY"}, {{"parameter_in_range", 0, 0.5, 1.5}})
mesh("sit_bg", "sit_root", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3}, M.black)

-- pages: 1 SIT, 2 MENU, 3 DTM
simple("sit_pg", "sit_root", {0, 0, 0}, {"S27MFD_PAGE"}, {{"parameter_in_range", 0, 0.5, 1.5}})

-- ownship frame (moves down in the decentred view)
simple("sit_own", "sit_pg", {0, 0, 0}, {"S27MFD_OWN_Y", "S27MFD_OWN_X"},
	{{"move_up_down_using_parameter", 0, G}, {"move_left_right_using_parameter", 1, G}})

-- range references (as the real SIT page):
--   centred:   the compass rose IS the range ring (ownship to the top of the
--              compass = selected range), plus a thin solid ring at half range
--   decentred: ownship low; a large solid circle in the middle of the
--              display, its top = the range shown; small compass rose
--              around the ownship, no half-range ring
simple("sit_sc_c", "sit_own", {0, 0, 0}, {"S27MFD_CENTER"}, {vis(0, 0.5, 1.5)})
simple("sit_sc_d", "sit_own", {0, 0, 0}, {"S27MFD_CENTER"}, {vis(0, -0.5, 0.5)})
-- the large circle sits in the middle of the display (the ownship below its
-- centre); its top is the range shown top right
local v, i = clipped_ring(SIT.BOX - 0.005, LW * 0.6, SIT.DECENTER_Y, 160, false, -SIT.DECENTER_Y)
mesh("sit_ring_d", "sit_sc_d", "triangles", v, i, M.white)
if SIT.HALF_RING then
	v, i = clipped_ring(SIT.CENTER_R / 2, LW * 0.5, SIT.CENTER_Y, 72)
	mesh("sit_half_c", "sit_sc_c", "triangles", v, i, M.white)
end
-- course line to the active steerpoint (MENU: CRS STR), line to the
-- primary designated target (blue)
local function seg_line(name, prefix, mat, w)
	line_obj(name, "sit_own", mat, w,
		{prefix .. "AX", prefix .. "AY", prefix .. "BX", prefix .. "BY", prefix .. "VIS"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
end
seg_line("sit_crs", "S27MFD_CRS_", M.white, 0.003)
seg_line("sit_pdt", "S27MFD_PDT_", M.pdt, 0.003)

-- compass rose around the ownship: ticks every 10 deg, 3 6 E 12 ... every
-- 30 deg. Turns with the heading (heading-up); the numbers stay upright.
local function rose(name, parent, R, len, numr)
	simple(name, parent, {0, 0, 0}, {"S27MFD_ROT"}, {{"rotate_using_parameter", 0, 1}})
	local tv, ti = {}, {}
	local w = LW * 0.6
	for deg = 10, 350, 10 do
		if deg % 30 ~= 0 then
			local a = math.rad(90 - deg)
			local ca, sa = math.cos(a), math.sin(a)
			local px, py = -sa * w / 2, ca * w / 2
			local r0, r1 = R - len / 2, R + len / 2
			local k = #tv
			tv[k + 1] = {r0 * ca + px, r0 * sa + py}; tv[k + 2] = {r1 * ca + px, r1 * sa + py}
			tv[k + 3] = {r1 * ca - px, r1 * sa - py}; tv[k + 4] = {r0 * ca - px, r0 * sa - py}
			ti[#ti + 1] = k; ti[#ti + 1] = k + 1; ti[#ti + 1] = k + 2
			ti[#ti + 1] = k; ti[#ti + 1] = k + 2; ti[#ti + 1] = k + 3
		end
	end
	mesh(name .. "_t", name, "triangles", tv, ti, M.white)
	local names = {[0] = "N", [30] = "3", [60] = "6", [90] = "E", [120] = "12", [150] = "15",
	               [180] = "S", [210] = "21", [240] = "24", [270] = "W", [300] = "30", [330] = "33"}
	for deg = 0, 330, 30 do
		local a = math.rad(deg)
		local nm = name .. "_" .. deg
		simple(nm, name, {numr * math.sin(a), numr * math.cos(a), 0})
		simple(nm .. "_u", nm, {0, 0, 0}, {"S27MFD_ROT"}, {{"rotate_using_parameter", 0, -1}})
		text(nm .. "_t", nm .. "_u", {0, 0, 0}, F.white, TXT_ROSE, "CenterCenter", names[deg])
	end
end
-- centred: the compass on the range ring; decentred: a small one
rose("sit_rose", "sit_sc_c", SIT.CENTER_R, 0.022, SIT.CENTER_R)
rose("sit_rose_d", "sit_sc_d", SIT.ROSE_R, 0.016, SIT.ROSE_R)

-- radar coverage: two cyan lines from the ownship along the edges of the
-- radar's scan, as long as the radar's range scale (end points from the
-- device, clipped to the box)
for k = 1, 2 do
	local p = "S27MFD_AZ" .. k .. "_"
	line_obj("sit_az" .. k, "sit_own", M.cyan, 0.004,
		{p .. "AX", p .. "AY", p .. "BX", p .. "BY", p .. "VIS"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
end

-- drawings (cartridge / mission: lines, areas, rings), MENU: LINES ----------
do
	local gm = {M.cyan, M.thr_i, col(242, 160, 160, 200)}
	local gf = {F.cyan, F.thr_i, F.red}
	-- (v0.9 perf: in blocks of 16 pieces; a block is shown only while one of
	-- its pieces is used)
	for b = 1, math.ceil(SIT.GEO_SEGS / 16) do
		simple("sit_gb" .. b, "sit_own", {0, 0, 0}, {"S27MFD_GB" .. b}, {vis(0, 0.5, 1.5)})
	end
	for j = 1, SIT.GEO_SEGS do
		local s = "S27MFD_GS" .. j .. "_"
		for ci, cm in ipairs(gm) do
			line_obj("sit_gs" .. j .. "_" .. ci, "sit_gb" .. math.ceil(j / 16), cm, 0.003,
				{s .. "AX", s .. "AY", s .. "BX", s .. "BY", s .. "VIS"},
				{{"parameter_in_range", 4, ci - 0.5, ci + 0.5},
				 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
				 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
		end
	end
	for k = 1, SIT.GEO_LABELS do
		local s = "S27MFD_GL" .. k .. "_"
		local pp, cc = at(s .. "X", s .. "Y", {{s .. "VIS", 0.5, 3.5}})
		simple("sit_gl" .. k, "sit_own", {0, 0, 0}, pp, cc)
		for ci, cf in ipairs(gf) do
			text("sit_gl" .. k .. "_" .. ci, "sit_gl" .. k, {0, 0.035, 0}, cf, TXT_TINY, "CenterCenter", nil, s .. "TXT",
				{s .. "VIS", ci - 0.5, ci + 0.5})
		end
	end
end

-- ground threats: MEZ rings, a background layer (dim red outside the ring,
-- bright red inside it) ---------------------------------------------------
-- (v0.9 perf: each ring's pieces in a group of their own, shown only while
-- the ring is drawn: hidden groups cost nothing per frame)
for g = 1, SIT.MAX_THREATS do
	local p = "S27MFD_G" .. g .. "_"
	for ci, cm in ipairs({M.thr_o, M.thr_i}) do
		local grp = "sit_gr" .. g .. "_" .. ci
		simple(grp, "sit_own", {0, 0, 0}, {p .. "RV"}, {vis(0, ci - 0.5, ci + 0.5)})
		for j = 1, SIT.RING_SEGS do
			local s = p .. "S" .. j .. "_"
			line_obj("sit_g" .. g .. "_" .. j .. "_" .. ci, grp, cm, 0.003,
				{s .. "AX", s .. "AY", s .. "BX", s .. "BY", s .. "VIS"},
				{{"parameter_in_range", 4, 0.5, 1.5},
				 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
				 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
		end
	end
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_g" .. g, "sit_own", {0, 0, 0}, pp, cc)
	-- site: small cross, label just below it (not on top of a contact there)
	for ci, cm in ipairs({M.thr_o, M.thr_i}) do
		local lo, hi = (ci == 1) and -0.5 or 1.5, (ci == 1) and 1.5 or 2.5
		v, i = poly_lines({{-0.012, 0}, {0.012, 0}}, false)
		mesh("sit_g" .. g .. "_x1_" .. ci, "sit_g" .. g, "lines", v, i, cm, nil, {p .. "RING"}, {vis(0, lo, hi)})
		v, i = poly_lines({{0, -0.012}, {0, 0.012}}, false)
		mesh("sit_g" .. g .. "_x2_" .. ci, "sit_g" .. g, "lines", v, i, cm, nil, {p .. "RING"}, {vis(0, lo, hi)})
		text("sit_g" .. g .. "_t" .. ci, "sit_g" .. g, {0, -0.04, 0}, (ci == 1) and F.thr_o or F.thr_i, TXT_TINY,
			"CenterCenter", nil, p .. "TXT", {p .. "RING", lo, hi})
	end
end

-- route: yellow line, steerpoints = triangles with the number inside;
-- the active one gets a second, larger triangle ------------------------------
local TRI = {{0, 0.065}, {0.056, -0.035}, {-0.056, -0.035}}
for n = 1, SIT.MAX_WPTS do
	local p = "S27MFD_W" .. n .. "_"
	line_obj("sit_leg" .. n, "sit_own", M.route, 0.004,
		{p .. "AX", p .. "AY", p .. "BX", p .. "BY", p .. "SEG"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 2.5}})
	simple("sit_w" .. n, "sit_own", {0, 0, 0}, pp, cc)
	v, i = outline(TRI, LW * 0.8, false)
	mesh("sit_w" .. n .. "_t", "sit_w" .. n, "triangles", v, i, M.route)
	v, i = outline(scaled(TRI, 1.35), LW * 0.8, false)
	mesh("sit_w" .. n .. "_a", "sit_w" .. n, "triangles", v, i, M.route, nil, {p .. "VIS"}, {vis(0, 1.5, 2.5)})
	text("sit_w" .. n .. "_n", "sit_w" .. n, {0, -0.006, 0}, F.route, TXT_TINY, "CenterCenter", nil, p .. "NUM", nil, "%.0f")
end

-- bullseye: yellow double circle ---------------------------------------------
do
	local pp, cc = at("S27MFD_BE_X", "S27MFD_BE_Y", {{"S27MFD_BE_VIS", 0.5, 1.5}})
	simple("sit_be", "sit_own", {0, 0, 0}, pp, cc)
	v, i = band(circle_pts(0.032, 28), circle_pts(0.032 - LW * 0.8, 28))
	mesh("sit_be_o", "sit_be", "triangles", v, i, M.bull)
	v, i = band(circle_pts(0.015, 16), circle_pts(0.015 - LW * 0.8, 16))
	mesh("sit_be_i", "sit_be", "triangles", v, i, M.bull)
end

-- contacts (foreground) -------------------------------------------------------
local tri  = {{0, S * 1.1}, {S * 0.85, -S * 0.7}, {-S * 0.85, -S * 0.7}}
local sqr  = {{-S * 0.7, S * 0.7}, {S * 0.7, S * 0.7}, {S * 0.7, -S * 0.7}, {-S * 0.7, -S * 0.7}}
local circ = circle_pts(S * 0.8, 24)
local circa = circle_pts(S * 1.0, 28)
-- [code] = {points, dotted, turns with course}
local shapes = {
	[1]  = {circ, true, false},  [11] = {circ, false, false},
	[2]  = {tri, true, true},    [12] = {tri, false, true},
	[3]  = {sqr, true, false},   [13] = {sqr, false, false},
	[4]  = {circa, true, false}, [14] = {circa, false, false},
	[5]  = {circ, false, false}, [15] = {circ, false, false},
	[6]  = {circ, true, false},  [16] = {circ, false, false},
}
local mats = {[1] = M.friend, [2] = M.hostile, [3] = M.unknown, [4] = M.friend, [5] = M.wing, [6] = M.friend}
local dot_v, dot_i = circle_fill(S * 0.22, 10)
local lv = {{-LW / 2, S * 0.85}, {LW / 2, S * 0.85}, {LW / 2, S * 0.85 + 0.05}, {-LW / 2, S * 0.85 + 0.05}}
local cmats = {M.friend, M.hostile, M.unknown, M.wing}
local cfonts = {F.cfriend, F.red, F.white, F.cyan}
-- (v0.9.x: grouped by colour - COL is set together with TYPE - so a shown
-- contact costs DCS ~11-19 elements a frame instead of 27; same picture)
local col_of = {[1] = 1, [2] = 2, [3] = 3, [4] = 1, [5] = 4, [6] = 1}    -- code % 10 -> colour group (= device CONTACT_COL)
for n = 1, SIT.MAX_CONTACTS do
	local p = "S27MFD_C" .. n .. "_"
	local base = "sit_c" .. n
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "TYPE", 0.5, 99}})
	simple(base, "sit_own", {0, 0, 0}, pp, cc)
	for ci, cm in ipairs(cmats) do
		local grp, rot = base .. "_k" .. ci, base .. "_r" .. ci
		simple(grp, base, {0, 0, 0}, {p .. "COL"}, {vis(0, ci - 0.1, ci + 0.1)})
		simple(rot, grp, {0, 0, 0}, {p .. "HDG"}, {{"rotate_using_parameter", 0, 1}})
		for code = 1, 16 do
			local sh = shapes[code]
			if sh and col_of[code % 10] == ci then
				local sv, si = outline(sh[1], LW, sh[2], (#sh[1] > 8) and 1 or 3)
				mesh(base .. "_s" .. code, sh[3] and rot or grp, "triangles", sv, si, mats[code % 10], nil,
					{p .. "TYPE"}, {vis(0, code - 0.1, code + 0.1)})
			end
		end
		for _, code in ipairs({4, 14, 6, 16}) do
			if col_of[code % 10] == ci then
				mesh(base .. "_dot" .. code, grp, "triangles", dot_v, dot_i, M.friend, nil, {p .. "TYPE"}, {vis(0, code - 0.1, code + 0.1)})
			end
		end
		mesh(base .. "_crs" .. ci, rot, "triangles", lv, {0, 1, 2, 0, 2, 3}, cm, nil,
			{p .. "MOV"}, {vis(0, 0.5, 1.5)})
		text(base .. "_alt" .. ci, grp, {0, -S * 1.25, 0}, cfonts[ci], TXT_TINY, "CenterCenter", nil, p .. "ALT", nil, SIT.METRIC and "%.1f" or "%.0f")
	end
	text(base .. "_num", base, {S * 1.15, S * 1.15, 0}, F.cyan, TXT_TINY, "LeftCenter", nil, p .. "NUM",
		{p .. "NUM", 0.5, 99}, "%.0f")
end

-- locked target: white brackets either side (the "hooked" mark) ------------
do
	local pp, cc = at("S27MFD_LK_X", "S27MFD_LK_Y", {{"S27MFD_LK_VIS", 0.5, 1.5}})
	simple("sit_lk", "sit_own", {0, 0, 0}, pp, cc)
	local b = S * 1.6
	for k, sx in ipairs({-1, 1}) do
		v, i = poly_lines({{sx * b * 0.6, b}, {sx * b, b}, {sx * b, -b}, {sx * b * 0.6, -b}}, false)
		mesh("sit_lk_b" .. k, "sit_lk", "lines", v, i, M.white)
	end
end

-- cursor / capture window: two cyan strokes, dashed while it follows the
-- VSD cursor --------------------------------------------------------------
do
	local pp, cc = at("S27MFD_CUR_X", "S27MFD_CUR_Y", {{"S27MFD_CUR_VIS", 0.5, 1.5}})
	simple("sit_cur", "sit_own", {0, 0, 0}, pp, cc)
	local cv, ci = {}, {}
	for _, sx in ipairs({-0.022, 0.022}) do
		for k = 0, 2 do
			local y0 = -0.036 + k * 0.027
			local b = #cv
			cv[b + 1] = {sx - 0.0025, y0}; cv[b + 2] = {sx + 0.0025, y0}
			cv[b + 3] = {sx + 0.0025, y0 + 0.018}; cv[b + 4] = {sx - 0.0025, y0 + 0.018}
			ci[#ci + 1] = b; ci[#ci + 1] = b + 1; ci[#ci + 1] = b + 2
			ci[#ci + 1] = b; ci[#ci + 1] = b + 2; ci[#ci + 1] = b + 3
		end
	end
	mesh("sit_cur_s", "sit_cur", "triangles", cv, ci, M.cyan, nil, {"S27MFD_CUR_SIT"}, {vis(0, -0.5, 0.5)})
	-- solid while the SIT page has the cursor (castle up)
	local sv, si = {}, {}
	for _, sx in ipairs({-0.022, 0.022}) do
		local b = #sv
		sv[b + 1] = {sx - 0.0025, -0.036}; sv[b + 2] = {sx + 0.0025, -0.036}
		sv[b + 3] = {sx + 0.0025, 0.036}; sv[b + 4] = {sx - 0.0025, 0.036}
		si[#si + 1] = b; si[#si + 1] = b + 1; si[#si + 1] = b + 2
		si[#si + 1] = b; si[#si + 1] = b + 2; si[#si + 1] = b + 3
	end
	mesh("sit_cur_sol", "sit_cur", "triangles", sv, si, M.cyan, nil, {"S27MFD_CUR_SIT"}, {vis(0, 0.5, 1.5)})
end
-- hooked contact: white corners around it (v0.8.2: were cyan, read as own flight)
do
	local pp, cc = at("S27MFD_HKM_X", "S27MFD_HKM_Y", {{"S27MFD_HKM_VIS", 0.5, 1.5}})
	simple("sit_hkm", "sit_own", {0, 0, 0}, pp, cc)
	local b, q = S * 1.5, S * 0.6
	for k, c in ipairs({{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}) do
		v, i = poly_lines({{c[1] * b, c[2] * (b - q)}, {c[1] * b, c[2] * b}, {c[1] * (b - q), c[2] * b}}, false)
		mesh("sit_hkm_" .. k, "sit_hkm", "lines", v, i, M.white)
	end
end

-- own missiles in flight (v0.9): missile (small diamond), a thin line to
-- its target and the target's time to impact ("A 23", magenta, left of
-- the target); up to 4
for k = 1, SIT.MAX_MSL do
	local p = "S27MFD_MSL" .. k .. "_"
	seg_line("sit_msll" .. k, p .. "L", M.white, 0.002)
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_msl" .. k, "sit_own", {0, 0, 0}, pp, cc)
	-- (v1.1: a circle until MPRF, then an X - MSLk_SYM 1 / 2)
	local d = S * 0.5
	simple("sit_msl" .. k .. "_c", "sit_msl" .. k, {0, 0, 0}, {p .. "SYM"}, {vis(0, 0.5, 1.5)})
	v, i = poly_lines(circle_pts(d, 16), true)
	mesh("sit_msl" .. k .. "_cm", "sit_msl" .. k .. "_c", "lines", v, i, M.white)
	simple("sit_msl" .. k .. "_x", "sit_msl" .. k, {0, 0, 0}, {p .. "SYM"}, {vis(0, 1.5, 2.5)})
	v, i = poly_lines({{-d, -d}, {d, d}}, false)
	mesh("sit_msl" .. k .. "_xa", "sit_msl" .. k .. "_x", "lines", v, i, M.white)
	v, i = poly_lines({{-d, d}, {d, -d}}, false)
	mesh("sit_msl" .. k .. "_xb", "sit_msl" .. k .. "_x", "lines", v, i, M.white)
	pp, cc = at(p .. "TX", p .. "TY", {{p .. "TVIS", 0.5, 1.5}})
	simple("sit_mtg" .. k, "sit_own", {0, 0, 0}, pp, cc)
	-- (v1.1: left of the contact, outside the hook corners, small and
	-- magenta - a colour the SIT page uses for nothing else)
	text("sit_mtg" .. k .. "_t", "sit_mtg" .. k, {-S * 1.9, 0, 0}, F.magenta, TXT_TINY, "RightCenter", nil, p .. "TXT")
end
-- mark points (keybind): an x and its number, bearing / range from us
for k = 1, SIT.MAX_MARKS do
	local p = "S27MFD_MK" .. k .. "_"
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_mk" .. k, "sit_own", {0, 0, 0}, pp, cc)
	local d = S * 0.6
	v, i = poly_lines({{-d, -d}, {d, d}}, false)
	mesh("sit_mk" .. k .. "_a", "sit_mk" .. k, "lines", v, i, M.bull)
	v, i = poly_lines({{-d, d}, {d, -d}}, false)
	mesh("sit_mk" .. k .. "_b", "sit_mk" .. k, "lines", v, i, M.bull)
	text("sit_mk" .. k .. "_t", "sit_mk" .. k, {d * 1.4, -d * 1.6, 0}, F.route, TXT_TINY, "LeftCenter", nil, p .. "TXT")
end

-- ownship, on top --------------------------------------------------------------
simple("sit_own_r", "sit_own", {0, 0, 0}, {"S27MFD_OWN_ROT"}, {{"rotate_using_parameter", 0, 1}})
v, i = poly_lines(scaled({{0, 0.06}, {0.010, 0.026}, {0.048, 0.0}, {0.048, -0.010}, {0.009, 0.0},
	{0.007, -0.034}, {0.022, -0.047}, {0, -0.043}, {-0.022, -0.047}, {-0.007, -0.034},
	{-0.009, 0.0}, {-0.048, -0.010}, {-0.048, 0.0}, {-0.010, 0.026}}, 0.8), true)
mesh("sit_ownship", "sit_own_r", "lines", v, i, M.own)

---------------------------------------------------------------------------
-- fixed texts (corners, as on the real page)
---------------------------------------------------------------------------
-- top left: time, datalink status (small)
text("sit_time", "sit_pg", {-0.773, 0.70, 0}, F.white, TXT_SMALL, "LeftCenter", nil, "S27MFD_TIME")
-- (the datalink status line is on the SIT SETTINGS page, top left)
-- top right: range scale (big), cyan bearing-range to the active steerpoint
text("sit_rng", "sit_pg", {0.773, 0.70, 0}, F.white, TXT, "RightCenter", nil, "S27MFD_RNG", {"S27MFD_RNG_MODE", -0.5, 0.5}, "%.0f")
text("sit_rngt", "sit_pg", {0.773, 0.70, 0}, F.white, TXT, "RightCenter", nil, "S27MFD_RNG_TXT", {"S27MFD_RNG_MODE", 0.5, 1.5})
text("sit_stpt", "sit_pg", {0.773, 0.63, 0}, F.cyan, TXT_SMALL, "RightCenter", nil, "S27MFD_STPT_TXT")
-- locked target data block (top left, below the status)
simple("sit_lkb", "sit_pg", {0, 0, 0}, {"S27MFD_LK_BLK"}, {vis(0, 0.5, 1.5)})
text("sit_lk1", "sit_lkb", {-0.773, 0.641, 0}, F.white, TXT_DATA, "LeftCenter", nil, "S27MFD_LK_T1")
text("sit_lk2", "sit_lkb", {-0.773, 0.591, 0}, F.white, TXT_DATA, "LeftCenter", nil, "S27MFD_LK_T2")
text("sit_lk3", "sit_lkb", {-0.773, 0.541, 0}, F.white, TXT_DATA, "LeftCenter", nil, "S27MFD_LK_T3")
-- hooked contact data (top left, below the lock block)
simple("sit_hkb", "sit_pg", {0, 0, 0}, {"S27MFD_HK_VIS", "S27MFD_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
for k = 1, 4 do
	-- in the hooked contact's colour (HK_COL: 1 green, 2 red, 3 white, 4 cyan)
	for ci, cf in ipairs({F.cfriend, F.red, F.white, F.cyan}) do
		text("sit_hk" .. k .. "_" .. ci, "sit_hkb", {-0.773, 0.452 - (k - 1) * 0.050, 0}, cf, TXT_DATA, "LeftCenter", nil,
			"S27MFD_HK" .. k .. "_TXT", {"S27MFD_HK_COL", ci - 0.5, ci + 0.5})
	end
end
-- bottom left: ownship weapon inventory in one line: R-77, R-27, R-73
-- counts, G = gun rounds; the selected one boxed
simple("sit_sto", "sit_pg", {0, 0, 0}, {"S27MFD_ST_VIS", "S27MFD_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
do
	local cw, ch = char_w(TXT_DATA), char_h(TXT_DATA)
	local x0, y, step, pad = -0.751, -0.607, 6.5 * char_w(TXT_DATA), 0.010
	for k = 1, 4 do
		local x = x0 + (k - 1) * step
		text("sit_inv" .. k, "sit_sto", {x, y, 0}, F.white, TXT_DATA, "LeftCenter", nil, "S27MFD_INV" .. k .. "_TXT")
		-- the box: INV_SEL = slot * 10 + characters
		for n = 2, 5 do
			local bv, bi = poly_lines({{x - pad, y + ch / 2 + pad}, {x + n * cw + pad, y + ch / 2 + pad},
				{x + n * cw + pad, y - ch / 2 - pad}, {x - pad, y - ch / 2 - pad}}, true)
			mesh("sit_invb" .. k .. "_" .. n, "sit_sto", "lines", bv, bi, M.white, nil, {"S27MFD_INV_SEL"}, {vis(0, k * 10 + n - 0.5, k * 10 + n + 0.5)})
		end
	end
end
-- bottom right: chaff / flares, bullseye readout, master mode
text("sit_cm_c", "sit_sto", {0.773, -0.442, 0}, F.cfriend, TXT_DATA, "RightCenter", nil, "S27MFD_CHAFF", nil, "C %.0f")
text("sit_cm_f", "sit_sto", {0.773, -0.497, 0}, F.cfriend, TXT_DATA, "RightCenter", nil, "S27MFD_FLARE", nil, "F %.0f")
simple("sit_bet", "sit_pg", {0, 0, 0}, {"S27MFD_BE_ON", "S27MFD_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
text("sit_be_t", "sit_bet", {0.773, -0.552, 0}, F.route, TXT_DATA, "RightCenter", nil, "S27MFD_BE_TXT")
text("sit_master", "sit_pg", {0.773, -0.607, 0}, F.white, TXT_DATA, "RightCenter", nil, "S27MFD_MASTER_TXT")

---------------------------------------------------------------------------
-- soft key legends: SA side legends as stacked letters (as the real SIT
-- page), every other page in words; bottom row: page shortcuts
---------------------------------------------------------------------------
local SIDE_X = 0.815
local BOT_Y = -0.765
local Y5 = MFD.Y5                                -- L1..L5 / R1..R5, top to bottom
local X5 = MFD.X5                                -- B1..B5 / T1..T5, left to right
local CW, CH = char_w(TXT_BTN), char_h(TXT_BTN) -- one character in page units
local CWT, CHT = char_w(TXT_TINY), char_h(TXT_TINY)
local LH = CH * 1.45                            -- line step of multi-line labels
local LHV = CH * 1.15                           -- line step of stacked letters (SA side legends)
local PAD = 0.012
local function box_mesh(name, x0, y0, x1, y1, param)
	local bv, bi = poly_lines({{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, true)
	mesh(name, "sit_pg", "lines", bv, bi, M.white, nil, {param}, {vis(0, 0.5, 1.5)})
end
-- a word next to a side button, one letter under the other.
-- visp = {param, lo, hi}: shown only while param is in that range
local function side_label(side, k, word, onparam, visp)
	local x = (side == "L") and -SIDE_X or SIDE_X
	local name = "sit_lbl_" .. side .. k .. "_" .. word:gsub("%W", "_")
	if visp then
		simple(name, "sit_pg", {x, Y5[k], 0}, {visp[1]}, {vis(0, visp[2], visp[3])})
	else
		simple(name, "sit_pg", {x, Y5[k], 0})
	end
	local n = #word
	for j = 1, n do
		text(name .. "_" .. j, name, {0, (n - 1) / 2 * LHV - (j - 1) * LHV, 0}, F.white, TXT_BTN, "CenterCenter", word:sub(j, j))
	end
	if onparam then
		local h = (n - 1) * LHV + CH
		box_mesh(name .. "_box", x - CW / 2 - PAD, Y5[k] - h / 2 - PAD, x + CW / 2 + PAD, Y5[k] + h / 2 + PAD, onparam)
	end
end
side_label("L", 1, "RNG+")
side_label("L", 2, "RNG-")
side_label("L", 3, "CTR", nil, {"S27MFD_CENTER", 0.5, 1.5})
side_label("L", 3, "DCTR", nil, {"S27MFD_CENTER", -0.5, 0.5})
side_label("L", 4, "NUP", nil, {"S27MFD_NUP", 0.5, 1.5})
side_label("L", 4, "HUP", nil, {"S27MFD_NUP", -0.5, 0.5})
side_label("L", 5, "SET")
side_label("R", 1, "WP+")
side_label("R", 2, "WP-")
side_label("R", 3, "AUTO", nil, {"S27MFD_AUTOR", 0.5, 1.5})
side_label("R", 3, "MAN", nil, {"S27MFD_AUTOR", -0.5, 0.5})
side_label("R", 4, "FORM", "S27MFD_FORM")
side_label("R", 5, "PIC")
text("sit_lbl_T1", "sit_pg", {X5[1], 0.765, 0}, F.white, TXT_BTN, "CenterCenter", "DCLT")
-- declutter step: shown for a moment after it changes
simple("sit_dclp", "sit_pg", {0, 0, 0}, {"S27MFD_DCL_POP"}, {vis(0, 0.5, 1.5)})
text("sit_dclp_t", "sit_dclp", {0, 0.60, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "S27MFD_DCL_TXT")

---------------------------------------------------------------------------
-- the other pages: legends in words, as on the MiG-29 MFD
---------------------------------------------------------------------------
local TOP_Y, BOT_Y1 = 0.765, -0.765
local function page_group(name, n)
	simple(name, "sit_root", {0, 0, 0}, {"S27MFD_PAGE"}, {vis(0, n - 0.5, n + 0.5)})
end
-- param: a parameter (box while it is 1) or {parameter, lo, hi}
local function box_in(parent, name, x0, y0, x1, y1, param, mat)
	local bv, bi = poly_lines({{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, true)
	local pn, lo, hi = param, 0.5, 1.5
	if type(param) == "table" then pn, lo, hi = param[1], param[2], param[3] end
	mesh(name, parent, "lines", bv, bi, mat or M.white, nil, {pn}, {vis(0, lo, hi)})
end
-- a label of one or more lines; (x, y) = its anchor at the middle line
local function lbl(parent, name, x, y, lines, align, onparam, font)
	local n, wmax = #lines, 0
	for j, s in ipairs(lines) do
		text(name .. "_" .. j, parent, {x, y + (n - 1) / 2 * LH - (j - 1) * LH, 0}, font or F.white, TXT_BTN, align, s)
		if #s > wmax then wmax = #s end
	end
	if onparam then
		local w, h = wmax * CW, (n - 1) * LH + CH
		local x0, x1 = x - w / 2, x + w / 2
		if align == "LeftCenter" then x0, x1 = x, x + w elseif align == "RightCenter" then x0, x1 = x - w, x end
		box_in(parent, name .. "_box", x0 - PAD, y - h / 2 - PAD, x1 + PAD, y + h / 2 + PAD, onparam)
	end
end
local SX = 0.835
local function L(parent, k, lines, on) lbl(parent, parent .. "_L" .. k, -SX, Y5[k], lines, "LeftCenter", on) end
local function R(parent, k, lines, on) lbl(parent, parent .. "_R" .. k, SX, Y5[k], lines, "RightCenter", on) end
local function T(parent, k, lines, on) lbl(parent, parent .. "_T" .. k, X5[k], TOP_Y - (#lines - 1) / 2 * LH, lines, "CenterCenter", on) end
local function B(parent, k, lines, on) lbl(parent, parent .. "_B" .. k, X5[k], BOT_Y1 + (#lines - 1) / 2 * LH, lines, "CenterCenter", on) end
local PG = SIT.PG
-- the page shortcuts (bottom row); the page shown boxed
local SHORT = {{"SA", PG.SIT}, {"RDR", PG.RDR}, {"MENU", PG.MENU}, {"NAV", PG.NAV}, {"RWR", PG.RWR}}
local function shortcuts(parent, pg)
	for k, s in ipairs(SHORT) do B(parent, k, {s[1]}, (s[2] == pg) and "S27MFD_READY" or nil) end
end
-- the SA page's own bottom row
shortcuts("sit_pg", PG.SIT)
local function title(parent, s, y)
	text(parent .. "_title", parent, {0, y or 0.66, 0}, F.white, TXT_BTN, "CenterCenter", s)
end
local function rows(parent, prefix, n, x, y0, step, defs, font, align)
	for k = 1, n do
		text(parent .. "_r" .. k, parent, {x, y0 - (k - 1) * step, 0}, font or F.white, defs or TXT_SMALL, align or "LeftCenter",
			nil, "S27MFD_" .. prefix .. k .. "_TXT")
	end
end

-- MENU ---------------------------------------------------------------------
page_group("mnu", PG.MENU)
L("mnu", 1, {"SA"}); L("mnu", 2, {"RDR"}); L("mnu", 3, {"NAV"}); L("mnu", 4, {"HSI"}); L("mnu", 5, {"COM"})
R("mnu", 1, {"FUEL"}); R("mnu", 2, {"SMS"}); R("mnu", 3, {"FLT"}); R("mnu", 4, {"RWR"}); R("mnu", 5, {"DTC"})
T("mnu", 1, {"BIT"}); T("mnu", 2, {"TIME"}); T("mnu", 4, {"OWN"}); T("mnu", 5, {"PIC"})
B("mnu", 1, {"CH-"}); B("mnu", 3, {"MENU"}, "S27MFD_READY"); B("mnu", 5, {"CH+"})
do
	-- squadron badge: the 4477th TAES "Red Eagles" emblem (Tools/badge_texture.py)
	local half, cy = 0.35, 0.25
	local e = CreateElement "ceTexPoly"
	e.name = "mnu_badge"
	e.primitivetype = "triangles"
	e.vertices = {{-half, cy + half}, {half, cy + half}, {half, cy - half}, {-half, cy - half}}
	e.indices = {0, 1, 2, 0, 2, 3}
	e.tex_coords = {{0, 0}, {1, 0}, {1, 1}, {0, 1}}
	e.material = MakeMaterial(LockOn_Options.script_path .. "../Textures/IndicationTextures/s27mfd_badge.dds", {255, 255, 255, 255})
	e.init_pos = {0, 0, 0}
	e.parent_element = "mnu"
	e.use_mipfilter = true
	e.additive_alpha = false
	prm(e)
	Add(e)
	text("mnu_t1", "mnu", {0, -0.15, 0}, F.white, TXT_SMALL, "CenterCenter", "4477TH TAES")
	text("mnu_t2", "mnu", {0, -0.22, 0}, F.grey, TXT_TINY, "CenterCenter", "SU-27 MFD 1.2")
	text("mnu_time", "mnu", {0, -0.33, 0}, F.white, TXT_SMALL, "CenterCenter", nil, "S27MFD_TIME")
	text("mnu_net", "mnu", {0, -0.40, 0}, F.white, TXT_TINY, "CenterCenter", nil, "S27MFD_NET_TXT")
	text("mnu_fc1", "mnu", {0, -0.62, 0}, F.white, TXT_TINY, "CenterCenter", "FIGHTER CHANNEL")
	text("mnu_fcn", "mnu", {0, -0.68, 0}, F.cyan, TXT_SMALL, "CenterCenter", nil, "S27MFD_FCH", nil, "%03.0f")
end

-- DTC (cartridges) -----------------------------------------------------------
page_group("dtm", PG.DTM)
title("dtm", "DATA CARTRIDGE", 0.66)
L("dtm", 1, {"READ"})
L("dtm", 2, {"CART", "-"})
L("dtm", 3, {"CART", "+"})
R("dtm", 5, {"MENU"})
B("dtm", 3, {"MENU"})
text("dtm_st", "dtm", {0, 0.57, 0}, F.white, TXT_BTN, "CenterCenter", nil, "S27MFD_DTM_TXT")
text("dtm_cart", "dtm", {0, -0.50, 0}, F.cyan, TXT_SMALL, "CenterCenter", nil, "S27MFD_DTM_CART_TXT")
text("dtm_ld", "dtm", {0, -0.58, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "S27MFD_DTM_LOADED_TXT")

-- BIT ----------------------------------------------------------------------
page_group("bt", PG.BIT)
text("bt_hdr", "bt", {0, 0.64, 0}, F.white, TXT_BTN, "CenterCenter", nil, "S27MFD_BIT_TXT")
for n, rw in ipairs(SIT.BIT_ROWS) do
	local y = 0.54 - (n - 1) * 0.082
	local pn = "S27MFD_BIT" .. n
	text("bt_n" .. n, "bt", {-0.45, y, 0}, F.white, TXT_SMALL, "LeftCenter", rw[1])
	text("bt_go" .. n, "bt", {0.45, y, 0}, F.cfriend, TXT_SMALL, "RightCenter", "GO", nil, {pn, 0.5, 1.5})
	text("bt_ng" .. n, "bt", {0.45, y, 0}, F.red, TXT_SMALL, "RightCenter", "NO GO", nil, {pn, 1.5, 2.5})
	text("bt_ts" .. n, "bt", {0.45, y, 0}, F.white, TXT_SMALL, "RightCenter", "TEST", nil, {pn, -0.5, 0.5})
end
L("bt", 1, {"CBIT"}, {"S27MFD_BIT_MODE", 0.5, 1.5})
L("bt", 2, {"IBIT"}, {"S27MFD_BIT_MODE", 1.5, 2.5})
shortcuts("bt", PG.BIT)

-- TIME / DATE --------------------------------------------------------------
page_group("td", PG.TIME)
title("td", "TIME / DATE")
rows("td", "TD", 6, -0.45, 0.42, 0.10)
R("td", 1, {"ZULU"}, {"S27MFD_ZULU", 0.5, 1.5})
R("td", 2, {"LOCAL"}, {"S27MFD_ZULU", -0.5, 0.5})
shortcuts("td", PG.TIME)

-- OWN DATA -----------------------------------------------------------------
page_group("od", PG.OWN)
title("od", "OWN DATA")
rows("od", "OWN", 11, -0.58, 0.54, 0.09)
shortcuts("od", PG.OWN)

-- FLIGHT: left the friendly aircraft (L1..L5, slot number in front, boxed =
-- picked), right the flight as four cards on R1..R4 (the ownship's card
-- green); UP / DN page the list, CLR empties a slot, AUTO (boxed while on)
-- orders the own group by name
page_group("fd", PG.FLT)
title("fd", "FLIGHT", 0.70)
do
	local XL, XD = -SX, -0.33           -- list, divider
	local X0, X1 = -0.27, 0.66          -- cards
	local CH2 = 0.105                   -- card half height
	text("fd_hl", "fd", {XL, 0.65, 0}, F.grey, TXT_TINY, "LeftCenter", "DATALINK")
	text("fd_hr", "fd", {X0, 0.65, 0}, F.grey, TXT_TINY, "LeftCenter", "FLIGHT")
	v, i = poly_lines({{XD, 0.66}, {XD, -0.66}}, false)
	mesh("fd_div", "fd", "lines", v, i, M.planf)
	for k = 1, 5 do
		local nm = "fd_c" .. k
		text(nm, "fd", {XL, Y5[k], 0}, F.white, TXT_TINY, "LeftCenter", nil, "S27MFD_FC" .. k .. "_TXT")
		box_in("fd", nm .. "_box", XL - PAD, Y5[k] - CHT / 2 - PAD, XL + 16 * CWT + PAD, Y5[k] + CHT / 2 + PAD,
			"S27MFD_FC" .. k .. "_ON", M.cyan)
	end
	text("fd_pg", "fd", {XL, -0.68, 0}, F.grey, TXT_TINY, "LeftCenter", nil, "S27MFD_FC_PG_TXT")
	for k = 1, 4 do
		local y, p = Y5[k], "S27MFD_FS" .. k .. "_"
		v, i = poly_lines({{X0, y + CH2}, {X1, y + CH2}, {X1, y - CH2}, {X0, y - CH2}}, true)
		mesh("fd_s" .. k .. "_f", "fd", "lines", v, i, M.planf)
		box_in("fd", "fd_s" .. k .. "_sel", X0 - 0.012, y - CH2 - 0.012, X1 + 0.012, y + CH2 + 0.012, p .. "SEL", M.cyan)
		text("fd_s" .. k .. "_no", "fd", {X0 + 0.035, y, 0}, F.cyan, TXT, "LeftCenter", tostring(k))
		text("fd_s" .. k .. "_n", "fd", {X0 + 0.13, y + 0.035, 0}, F.white, TXT_SMALL, "LeftCenter", nil, p .. "N_TXT", {p .. "OWN", -0.5, 0.5})
		text("fd_s" .. k .. "_no2", "fd", {X0 + 0.13, y + 0.035, 0}, F.cfriend, TXT_SMALL, "LeftCenter", nil, p .. "N_TXT", {p .. "OWN", 0.5, 1.5})
		text("fd_s" .. k .. "_d", "fd", {X0 + 0.13, y - 0.045, 0}, F.cyan, TXT_TINY, "LeftCenter", nil, p .. "D_TXT")
		text("fd_s" .. k .. "_ot", "fd", {X1 - 0.02, y + 0.035, 0}, F.cfriend, TXT_TINY, "RightCenter", "OWN", nil, {p .. "OWN", 0.5, 1.5})
		R("fd", k, {tostring(k)})
	end
	text("fd_hint", "fd", {(X0 + X1) / 2, -0.47, 0}, F.yellow, TXT_TINY, "CenterCenter", nil, "S27MFD_FLT_HINT_TXT")
end
B("fd", 1, {"UP"})
B("fd", 2, {"CLR"})
B("fd", 3, {"MENU"})
B("fd", 4, {"DN"})
B("fd", 5, {"AUTO"}, "S27MFD_FLT_AUTO")
R("fd", 5, {"MENU"})

-- SA SETTINGS (SA page left 5): what the SA page shows. Boxed = shown.
page_group("ss", PG.SETS)
title("ss", "SA SETTINGS", 0.66)
text("ss_status", "ss", {0, 0.57, 0}, F.white, TXT_SMALL, "CenterCenter", nil, "S27MFD_STATUS")
L("ss", 1, {"DL"}, "S27MFD_DL")
L("ss", 2, {"ROUTE"}, "S27MFD_RTE")
L("ss", 3, {"THREAT", "RINGS"}, "S27MFD_THR")
L("ss", 4, {"LINES"}, "S27MFD_LINES")
L("ss", 5, {"SA"})
R("ss", 1, {"CRS", "LINE"}, "S27MFD_CRS")
R("ss", 2, {"DCLT"})
text("ss_dcl", "ss", {SX - 5.5 * CW, Y5[2], 0}, F.cfriend, TXT_BTN, "RightCenter", nil, "S27MFD_DCL_TXT")
R("ss", 3, {"AUTO", "RANGE"}, "S27MFD_AUTOR")
R("ss", 4, {"RADAR"}, "S27MFD_RDRL")
shortcuts("ss", PG.SETS)
text("ss_n1", "ss", {0, 0.02, 0}, F.white, TXT_TINY, "CenterCenter", "KEYPAD (TSELI): NUMBER + VVOD")
text("ss_n2", "ss", {0, -0.06, 0}, F.white, TXT_TINY, "CenterCenter", "SA / NAV / HSI: STEERPOINT")
text("ss_n3", "ss", {0, -0.14, 0}, F.white, TXT_TINY, "CenterCenter", "FUEL: BINGO   DTC: CARTRIDGE")
text("ss_n4", "ss", {0, -0.22, 0}, F.white, TXT_TINY, "CenterCenter", "ISTREBITELI 1-4: SA RDR NAV RWR   GR: MENU")

---------------------------------------------------------------------------
-- the MiG-29 MFD's pages (v0.2): PICTURE, RDR, NAV, HSI, COM, FUEL, SMS, RWR
---------------------------------------------------------------------------
-- text rows, shared by these pages (and DTC): ROWn_TXT, colour ROWn_COL
-- (1 white 2 green 3 red 4 amber 5 cyan 6 grey 7 yellow), ROWn_BOX
local ROW_X, ROW_Y0, ROW_DY = -0.66, 0.66, 0.098
do
	local fonts = {F.white, F.cfriend, F.red, F.orange, F.cyan, F.grey, F.yellow}
	local CHD = char_h(TXT_DATA)
	-- pages 15..22 (PICTURE .. RWR) and 3 (DTC)
	for gi, rg in ipairs({{PG.PIC - 0.5, PG.RWR + 0.5}, {PG.DTM - 0.5, PG.DTM + 0.5}}) do
		local g = "rows" .. gi
		simple(g, "sit_root", {0, 0, 0}, {"S27MFD_PAGE"}, {vis(0, rg[1], rg[2])})
		for r = 1, 14 do
			local y = ROW_Y0 - (r - 1) * ROW_DY
			local p = "S27MFD_ROW" .. r .. "_"
			-- an empty row (colour 0) is one hidden group, not 8 elements to check
			local gr = g .. "_row" .. r
			simple(gr, g, {0, 0, 0}, {p .. "COL"}, {vis(0, 0.5, 7.5)})
			for ci, f in ipairs(fonts) do
				text(gr .. "_" .. ci, gr, {ROW_X, y, 0}, f, TXT_DATA, "LeftCenter", nil, p .. "TXT", {p .. "COL", ci - 0.5, ci + 0.5})
			end
			box_in(gr, gr .. "_b", ROW_X - PAD, y - CHD / 2 - PAD, -ROW_X + PAD, y + CHD / 2 + PAD, p .. "BOX")
		end
	end
end
local function row_y(r) return ROW_Y0 - (r - 1) * ROW_DY end

-- PICTURE ------------------------------------------------------------------
page_group("pic", PG.PIC)
L("pic", 1, {"BULL"}, "S27MFD_PIC_BULL")
L("pic", 5, {"SA"})
for k = 1, 5 do R("pic", k, {tostring(k)}) end
shortcuts("pic", PG.PIC)

-- RDR: B-scope, azimuth +-60 deg across, range up -------------------------
page_group("rdr", PG.RDR)
shortcuts("rdr", PG.RDR)
do
	local W2, Y0R, HR = 0.55, -0.42, 0.96          -- half width, bottom, height
	v, i = poly_lines({{-W2, Y0R}, {W2, Y0R}, {W2, Y0R + HR}, {-W2, Y0R + HR}}, true)
	mesh("rdr_fr", "rdr", "lines", v, i, M.ring)
	local GR = batch("rdr_grid", "rdr", M.planf)
	for k = 1, 3 do
		local y = Y0R + HR * k / 4
		for s = 0, 19 do
			local x0 = -W2 + (2 * W2) * s / 20
			GR.add({{x0, y}, {x0 + W2 / 25, y}})
		end
	end
	for _, a in ipairs({-30, 0, 30}) do
		local x = W2 * a / 60
		for s = 0, 19 do
			local y0 = Y0R + HR * s / 20
			GR.add({{x, y0}, {x, y0 + HR / 50}})
		end
	end
	GR.done()
	for k = 1, 4 do
		text("rdr_rl" .. k, "rdr", {-W2 - 0.02, Y0R + HR * k / 4, 0}, F.grey, TXT_TINY, "RightCenter", nil, "S27MFD_RDR_R" .. k, nil, "%.0f")
	end
	text("rdr_u", "rdr", {-W2 - 0.02, Y0R, 0}, F.grey, TXT_TINY, "RightCenter", SIT.RNG_LBL)
	-- scan line (antenna azimuth)
	simple("rdr_scg", "rdr", {0, Y0R, 0}, {"S27MFD_RDR_SCAN", "S27MFD_RDR_ON"}, {vis(1, 0.5, 1.5), {"move_left_right_using_parameter", 0, W2 * G}})
	v, i = poly_lines({{0, 0}, {0, HR}}, false)
	mesh("rdr_sc", "rdr_scg", "lines", v, i, M.friend)
	-- contacts: bars, altitude under them; colour 1 green (friend / unknown), 2 red, 3 white
	local bar = {{-0.022, -0.009}, {0.022, -0.009}, {0.022, 0.009}, {-0.022, 0.009}}
	local cm = {M.friend, M.hostile, M.unknown}
	local cf = {F.cfriend, F.red, F.white}
	for n = 1, 16 do
		local p = "S27MFD_RB" .. n .. "_"
		simple("rdr_b" .. n, "rdr", {0, Y0R, 0}, {p .. "X", p .. "Y", p .. "VIS"},
			{vis(2, 0.5, 1.5), {"move_left_right_using_parameter", 0, W2 * G}, {"move_up_down_using_parameter", 1, HR * G}})
		for ci = 1, 3 do
			local g = "rdr_b" .. n .. "_" .. ci
			simple(g, "rdr_b" .. n, {0, 0, 0}, {p .. "COL"}, {vis(0, ci - 0.5, ci + 0.5)})
			mesh(g .. "_m", g, "triangles", bar, {0, 1, 2, 0, 2, 3}, cm[ci])
			text(g .. "_a", g, {0, -0.045, 0}, cf[ci], TXT_TINY, "CenterCenter", nil, p .. "ALT", nil, SIT.METRIC and "%.1f" or "%.0f")
		end
	end
	-- lock: amber circle on the locked contact
	simple("rdr_lk", "rdr", {0, Y0R, 0}, {"S27MFD_RLK_X", "S27MFD_RLK_Y", "S27MFD_RLK_VIS"},
		{vis(2, 0.5, 1.5), {"move_left_right_using_parameter", 0, W2 * G}, {"move_up_down_using_parameter", 1, HR * G}})
	local lv, li = outline(circle_pts(0.045, 24), 0.007)
	mesh("rdr_lk_c", "rdr_lk", "triangles", lv, li, M.route)
	-- ownship at the bottom middle
	v, i = poly_lines({{-0.03, Y0R - 0.035}, {0, Y0R - 0.005}, {0.03, Y0R - 0.035}}, false)
	mesh("rdr_own", "rdr", "lines", v, i, M.own)
end

-- NAV ----------------------------------------------------------------------
page_group("nav", PG.NAV)
L("nav", 1, {"STP+"}); L("nav", 2, {"STP-"}); L("nav", 3, {"LIST", "UP"}); L("nav", 4, {"LIST", "DN"}); L("nav", 5, {"JET", "WP"})
R("nav", 1, {"LOAD"}); R("nav", 2, {"ADD"}, "S27MFD_NAV_ADD"); R("nav", 3, {"DEL"}); R("nav", 4, {"RTE", "RST"}); R("nav", 5, {"HSI"})
shortcuts("nav", PG.NAV)

-- HSI ----------------------------------------------------------------------
page_group("hsi", PG.HSI)
L("hsi", 1, {"CRS+"}); L("hsi", 2, {"CRS-"}); L("hsi", 3, {"HDG+"}); L("hsi", 4, {"HDG-"}); L("hsi", 5, {"AUTO"})
R("hsi", 1, {"STP+"}); R("hsi", 2, {"STP-"}); R("hsi", 5, {"NAV"})
shortcuts("hsi", PG.HSI)
do
	local CY, RR = 0.02, 0.42
	simple("hsi_c", "hsi", {0, CY, 0})
	-- the rose turns with the heading (heading up)
	simple("hsi_rose", "hsi_c", {0, 0, 0}, {"S27MFD_HSI_ROT"}, {{"rotate_using_parameter", 0, 1}})
	local rv, ri = outline(circle_pts(RR, 72), 0.006)
	mesh("hsi_ring", "hsi_rose", "triangles", rv, ri, M.ring)
	local TK = batch("hsi_ticks", "hsi_rose", M.ring)
	for d = 0, 355, 5 do
		local a = math.rad(90 - d)
		local l = (d % 10 == 0) and 0.04 or 0.022
		TK.add({{RR * math.cos(a), RR * math.sin(a)}, {(RR - l) * math.cos(a), (RR - l) * math.sin(a)}})
		if d % 30 == 0 then
			local lab = ({[0] = "N", [90] = "E", [180] = "S", [270] = "W"})[d] or tostring(d / 10)
			local nm = "hsi_l" .. d
			simple(nm, "hsi_rose", {(RR - 0.085) * math.cos(a), (RR - 0.085) * math.sin(a), 0})
			simple(nm .. "_u", nm, {0, 0, 0}, {"S27MFD_HSI_ROT"}, {{"rotate_using_parameter", 0, -1}})
			text(nm .. "_t", nm .. "_u", {0, 0, 0}, F.white, TXT_SMALL, "CenterCenter", lab)
		end
	end
	TK.done()
	-- course arrow (cyan) with the deviation bar; bearing pointer (green); heading bug (amber)
	simple("hsi_crs", "hsi_c", {0, 0, 0}, {"S27MFD_HSI_CRS"}, {{"rotate_using_parameter", 0, -1}})
	mesh("hsi_crs_h", "hsi_crs", "triangles", {{0, RR - 0.05}, {-0.03, RR - 0.11}, {0.03, RR - 0.11}}, {0, 1, 2}, M.cyan)
	mesh("hsi_crs_a", "hsi_crs", "triangles", {{-0.006, RR - 0.11}, {0.006, RR - 0.11}, {0.006, 0.17}, {-0.006, 0.17}}, {0, 1, 2, 0, 2, 3}, M.cyan)
	mesh("hsi_crs_b", "hsi_crs", "triangles", {{-0.006, -0.17}, {0.006, -0.17}, {0.006, -(RR - 0.05)}, {-0.006, -(RR - 0.05)}}, {0, 1, 2, 0, 2, 3}, M.cyan)
	for _, dx in ipairs({-0.16, -0.08, 0.08, 0.16}) do
		local dv, di = circle_fill(0.012, 10)
		mesh("hsi_dot" .. dx, "hsi_crs", "triangles", dv, di, M.ring, {dx, 0, 0})
	end
	simple("hsi_dev", "hsi_crs", {0, 0, 0}, {"S27MFD_HSI_DEV"}, {{"move_left_right_using_parameter", 0, 0.16 * G}})
	mesh("hsi_dev_b", "hsi_dev", "triangles", {{-0.008, 0.15}, {0.008, 0.15}, {0.008, -0.15}, {-0.008, -0.15}}, {0, 1, 2, 0, 2, 3}, M.cyan)
	simple("hsi_brg", "hsi_c", {0, 0, 0}, {"S27MFD_HSI_BRG", "S27MFD_HSI_BVIS"}, {vis(1, 0.5, 1.5), {"rotate_using_parameter", 0, -1}})
	mesh("hsi_brg_h", "hsi_brg", "triangles", {{0, RR + 0.005}, {-0.025, RR - 0.04}, {0.025, RR - 0.04}}, {0, 1, 2}, M.friend)
	mesh("hsi_brg_t", "hsi_brg", "triangles", {{-0.004, -RR}, {0.004, -RR}, {0.004, -RR + 0.06}, {-0.004, -RR + 0.06}}, {0, 1, 2, 0, 2, 3}, M.friend)
	simple("hsi_hb", "hsi_c", {0, 0, 0}, {"S27MFD_HSI_HB"}, {{"rotate_using_parameter", 0, -1}})
	mesh("hsi_hb_m", "hsi_hb", "triangles", {{-0.03, RR + 0.005}, {0.03, RR + 0.005}, {0.03, RR + 0.03}, {0.012, RR + 0.03}, {0, RR + 0.012}, {-0.012, RR + 0.03}, {-0.03, RR + 0.03}},
		{0, 1, 3, 0, 3, 4, 0, 4, 5, 0, 5, 6, 1, 2, 3}, M.route)
	-- lubber line and the ownship
	mesh("hsi_lub", "hsi_c", "triangles", {{0, RR + 0.008}, {-0.02, RR + 0.045}, {0.02, RR + 0.045}}, {0, 1, 2}, M.white)
	v, i = poly_lines({{0, 0.05}, {0.04, -0.03}, {0, -0.01}, {-0.04, -0.03}}, true)
	mesh("hsi_own", "hsi_c", "lines", v, i, M.white)
end

-- COM ----------------------------------------------------------------------
page_group("com", PG.COM)
L("com", 1, {"UKV", "CH+"}); L("com", 2, {"UKV", "CH-"}); L("com", 3, {"VOL+"}); L("com", 4, {"VOL-"})
R("com", 1, {"KV", "CH+"}); R("com", 2, {"KV", "CH-"}); R("com", 3, {"VOL+"}); R("com", 4, {"VOL-"})
L("com", 5, {"UKV", "MAN"}, "S27MFD_COM_MANU"); R("com", 5, {"KV", "MAN"}, "S27MFD_COM_MANK")
shortcuts("com", PG.COM)

-- FUEL ---------------------------------------------------------------------
page_group("fu", PG.FUEL)
L("fu", 1, {"BNG+"}); L("fu", 2, {"BNG-"})
shortcuts("fu", PG.FUEL)
do
	local X0, X1, Y0F, HF = 0.44, 0.56, -0.40, 0.92
	v, i = poly_lines({{X0, Y0F}, {X1, Y0F}, {X1, Y0F + HF}, {X0, Y0F + HF}}, true)
	mesh("fu_fr", "fu", "lines", v, i, M.ring)
	for k = 1, 20 do
		local y0, y1 = Y0F + HF * (k - 1) / 20 + 0.004, Y0F + HF * k / 20 - 0.004
		mesh("fu_s" .. k, "fu", "triangles", {{X0 + 0.01, y0}, {X1 - 0.01, y0}, {X1 - 0.01, y1}, {X0 + 0.01, y1}}, {0, 1, 2, 0, 2, 3},
			M.friend, nil, {"S27MFD_FUEL_FRAC"}, {vis(0, (k - 0.5) / 20, 1.5)})
	end
	simple("fu_bg", "fu", {0, Y0F, 0}, {"S27MFD_FUEL_BINGO"}, {{"move_up_down_using_parameter", 0, HF * G}})
	mesh("fu_bgl", "fu_bg", "triangles", {{X0 - 0.04, -0.005}, {X1 + 0.04, -0.005}, {X1 + 0.04, 0.005}, {X0 - 0.04, 0.005}}, {0, 1, 2, 0, 2, 3}, M.route)
	text("fu_bgt", "fu_bg", {X1 + 0.05, 0, 0}, F.orange, TXT_TINY, "LeftCenter", "B")
	text("fu_lbl", "fu", {(X0 + X1) / 2, Y0F - 0.05, 0}, F.grey, TXT_TINY, "CenterCenter", "INT")
end

-- SMS: the Su-27 seen from behind (as the MiG-29 MFD's STORES page), the
-- stores hanging under it on leader lines: white loaded, amber selected
page_group("sms", PG.SMS)
shortcuts("sms", PG.SMS)
do
	local AIR = batch("sms_air", "sms", M.planf)            -- the whole airframe: one element
	local function L(name, pts, closed) AIR.add(pts, closed) end
	local function mirror(pts) local m = {}; for k, q in ipairs(pts) do m[k] = {-q[1], q[2]} end; return m end
	local function both(name, pts, closed) L(name .. "_l", pts, closed); L(name .. "_r", mirror(pts), closed) end
	text("sms_title", "sms", {0, 0.70, 0}, F.white, TXT_BTN, "CenterCenter", "STORES")
	box_in("sms", "sms_title_box", -3.5 * CW - PAD, 0.70 - CH / 2 - PAD, 3.5 * CW + PAD, 0.70 + CH / 2 + PAD, {"S27MFD_PAGE", -1, 99})
	-- traced from a photo of the jet from behind (Tools/sms_trace.py):
	-- {name, closed, mirrored, {x, y, ...}}
	local SHAPES = {
		{"wing", true, true, {-0.2123, 0.3012, -0.7964, 0.2988, -0.7988, 0.2928, -0.2123, 0.2940}},
		{"flap", true, true, {-0.2399, 0.2940, -0.5685, 0.2940, -0.5685, 0.2544, -0.3982, 0.2472, -0.2399, 0.2616}},
		{"flap_h", false, true, {-0.5685, 0.2784, -0.2399, 0.2808}},
		{"tip", true, true, {-0.8012, 0.3036, -0.7124, 0.2976, -0.7124, 0.2820, -0.7316, 0.2664, -0.7700, 0.2772, -0.8012, 0.2916}},
		{"tip_n", false, true, {-0.8012, 0.2976, -0.7124, 0.2904}},
		{"stab", true, true, {-0.2327, 0.2736, -0.5661, 0.1981, -0.5205, 0.1585, -0.2543, 0.1609, -0.2039, 0.1957}},
		{"stab_h", false, true, {-0.5517, 0.1873, -0.2183, 0.2136}},
		{"fin", true, true, {-0.2363, 0.2748, -0.2315, 0.6514, -0.2279, 0.6634, -0.2231, 0.6466, -0.2159, 0.2748}},
		{"fin_tip", false, true, {-0.2315, 0.6094, -0.2231, 0.6094}},
		{"fin_rud", false, true, {-0.2207, 0.4607, -0.2183, 0.2808}},
		{"fin_a1", false, true, {-0.2315, 0.5903, -0.2399, 0.5831, -0.2315, 0.5735}},
		{"fin_a2", false, true, {-0.2315, 0.5663, -0.2387, 0.5603, -0.2315, 0.5531}},
		{"vfin", true, true, {-0.2423, 0.2568, -0.2339, 0.2568, -0.2351, 0.1429, -0.2411, 0.1513}},
		{"boom", true, true, {-0.2495, 0.2808, -0.2327, 0.2808, -0.2327, 0.2172, -0.2471, 0.2232}},
		{"hump", false, true, {-0.2123, 0.3012, -0.1103, 0.3024, -0.0900, 0.3060, -0.0708, 0.3204, -0.0540, 0.3432, -0.0468, 0.3516}},
		{"rail", false, true, {-0.0468, 0.3516, -0.0468, 0.3936, -0.0372, 0.3984}},
		{"hump_top", false, true, {-0.0468, 0.3516, 0.0000, 0.3540}},
		{"dorsal", true, false, {0.0240, 0.3264, 0.0228, 0.3253, 0.0194, 0.3243, 0.0141, 0.3235, 0.0074, 0.3230, 0.0000, 0.3228, -0.0074, 0.3230, -0.0141, 0.3235, -0.0194, 0.3243, -0.0228, 0.3253, -0.0240, 0.3264, -0.0228, 0.3275, -0.0194, 0.3285, -0.0141, 0.3293, -0.0074, 0.3298, 0.0000, 0.3300, 0.0074, 0.3298, 0.0141, 0.3293, 0.0194, 0.3285, 0.0228, 0.3275, 0.0240, 0.3264}},
		{"canopy", false, false, {-0.0360, 0.3828, -0.0360, 0.4115, -0.0360, 0.4115, -0.0354, 0.4168, -0.0338, 0.4218, -0.0312, 0.4265, -0.0276, 0.4308, -0.0231, 0.4345, -0.0180, 0.4375, -0.0123, 0.4397, -0.0062, 0.4411, 0.0000, 0.4415, 0.0062, 0.4411, 0.0123, 0.4397, 0.0180, 0.4375, 0.0231, 0.4345, 0.0276, 0.4308, 0.0312, 0.4265, 0.0338, 0.4218, 0.0354, 0.4168, 0.0360, 0.4115, 0.0360, 0.3828}},
		{"hoop", false, false, {-0.0312, 0.3696, -0.0312, 0.3792, -0.0312, 0.3792, -0.0306, 0.3850, -0.0288, 0.3906, -0.0259, 0.3958, -0.0221, 0.4004, -0.0173, 0.4041, -0.0119, 0.4069, -0.0061, 0.4086, 0.0000, 0.4091, 0.0061, 0.4086, 0.0119, 0.4069, 0.0173, 0.4041, 0.0221, 0.4004, 0.0259, 0.3958, 0.0288, 0.3906, 0.0306, 0.3850, 0.0312, 0.3792, 0.0312, 0.3696}},
		{"seat", true, false, {-0.0072, 0.3912, -0.0072, 0.4007, 0.0072, 0.4007, 0.0072, 0.3912}},
		{"bay", true, true, {-0.0828, 0.2964, -0.0648, 0.2964, -0.0648, 0.2640, -0.0828, 0.2640}},
		{"beam", true, true, {-0.0648, 0.2772, -0.0408, 0.2772, -0.0408, 0.2400, -0.0648, 0.2400}},
		{"green", true, true, {-0.0408, 0.2604, -0.0168, 0.2604, -0.0168, 0.2448, -0.0408, 0.2448}},
		{"cone", true, false, {-0.0216, 0.2748, 0.0216, 0.2748, 0.0324, 0.2568, 0.0192, 0.2304, 0.0000, 0.2196, -0.0192, 0.2304, -0.0324, 0.2568}},
		{"cone_c", true, false, {0.0108, 0.2496, 0.0100, 0.2455, 0.0076, 0.2420, 0.0041, 0.2397, 0.0000, 0.2388, -0.0041, 0.2397, -0.0076, 0.2420, -0.0100, 0.2455, -0.0108, 0.2496, -0.0100, 0.2538, -0.0076, 0.2573, -0.0041, 0.2596, 0.0000, 0.2604, 0.0041, 0.2596, 0.0076, 0.2573, 0.0100, 0.2538, 0.0108, 0.2496}},
		{"mast", false, false, {0.0000, 0.2748, 0.0000, 0.3072}},
		{"mast_t", false, false, {-0.0060, 0.2928, 0.0060, 0.2928}},
		{"py2", true, true, {-0.6513, 0.2928, -0.6369, 0.2928, -0.6393, 0.2592, -0.6489, 0.2592}},
		{"py3", true, true, {-0.4642, 0.2496, -0.4522, 0.2484, -0.4546, 0.2304, -0.4618, 0.2304}},
		{"py4", true, true, {-0.1343, 0.1537, -0.1223, 0.1537, -0.1235, 0.1309, -0.1331, 0.1309}},
		{"py5", true, true, {-0.0360, 0.2172, -0.0240, 0.2172, -0.0252, 0.1969, -0.0348, 0.1969}},
		{"nac_f", false, true, {-0.1607, 0.1573, -0.1223, 0.1537, -0.1103, 0.1573}},
	}
	local NOZ = {-0.1415, 0.2244}   -- left nozzle centre
	for _, sh in ipairs(SHAPES) do
		local pts = {}
		for k = 1, #sh[4], 2 do pts[#pts + 1] = {sh[4][k], sh[4][k + 1]} end
		if sh[3] then both(sh[1], pts, sh[2]) else L(sh[1], pts, sh[2]) end
	end
	-- nozzles: shroud (two lines), petals, throat, flame holder
	local function ellp(cx, cy, rx, ry, n)
		local v = {}
		for k = 0, n - 1 do local a = 2 * math.pi * k / n; v[#v + 1] = {cx + rx * math.cos(a), cy + ry * math.sin(a)} end
		return v
	end
	for _, sx in ipairs({-1, 1}) do
		local cx, cy = sx * -NOZ[1], NOZ[2]
		L("noz_o" .. sx, ellp(cx, cy, 0.0696, 0.0744, 48), true)
		L("noz_i" .. sx, ellp(cx, cy, 0.0612, 0.0648, 48), true)
		L("noz_t" .. sx, ellp(cx, cy + 0.003, 0.0396, 0.0408, 40), true)
		L("noz_f" .. sx, ellp(cx, cy + 0.003, 0.0144, 0.0144, 20), true)
		for k = 0, 23 do
			local a = 2 * math.pi * k / 24
			L("noz_p" .. sx .. "_" .. k, {{cx + 0.0396 * math.cos(a), cy + 0.003 + 0.0408 * math.sin(a)}, {cx + 0.0612 * math.cos(a), cy + 0.0648 * math.sin(a)}}, false)
		end
	end
	AIR.done()
	-- the stations: pylon point, store symbol, label side. 5 / 6 = the
	-- tunnel between the engines (5 front, 6 rear)
	local ST = {
		{-0.752, 0.269, -0.72, -0.30, "CenterCenter"},
		{-0.644, 0.259, -0.56, -0.17, "CenterCenter"},
		{-0.458, 0.230, -0.40, -0.06, "CenterCenter"},
		{-0.128, 0.131, -0.15, 0.03, "CenterCenter"},
		{-0.030, 0.197, -0.06, -0.22, "RightCenter"},
		{0.030, 0.197, 0.06, -0.22, "LeftCenter"},
		{0.128, 0.131, 0.15, 0.03, "CenterCenter"},
		{0.458, 0.230, 0.40, -0.06, "CenterCenter"},
		{0.644, 0.259, 0.56, -0.17, "CenterCenter"},
		{0.752, 0.269, 0.72, -0.30, "CenterCenter"},
	}
	-- the stores from behind, by type (S27MFD_SMSn_TYP): 1 R-27 (big, X fins),
	-- 2 R-73 / R-60 (small), 3 R-77 (grid fins), 4 bomb (box tail), 5 rocket pod
	local function ring(r, n) local v = {}; for k = 0, n - 1 do local a = 2 * math.pi * k / n; v[#v + 1] = {r * math.cos(a), r * math.sin(a)} end; return v end
	local SYM = {
		{body = 0.020, fin = 0.052, bar = 0.010},
		{body = 0.013, fin = 0.034, bar = 0.006},
		{body = 0.016, fin = 0.030, grid = 0.008},
		{body = 0.024, fin = 0.034, box = 0.032},
		{body = 0.032, pod = true},
	}
	local function store_sym(g, sx, sy, mat)
		for t, sd in ipairs(SYM) do
			local gt = g .. "_y" .. t
			simple(gt, g, {sx, sy, 0}, {"S27MFD_SMS" .. g:match("^sms_s(%d+)") .. "_TYP"}, {vis(0, t - 0.5, t + 0.5)})
			local B = batch(gt .. "_m", gt, mat)                 -- the symbol: one element
			B.add(ring(sd.body, 20), true)
			if sd.pod then
				B.add(ring(sd.body - 0.006, 20), true)
				for k = 0, 6 do
					local r = (k == 0) and 0 or 0.016
					local a = 2 * math.pi * k / 6
					local cx, cy = r * math.cos(a), r * math.sin(a)
					local dot = {}
					for j = 0, 5 do dot[#dot + 1] = {cx + 0.004 * math.cos(j * math.pi / 3), cy + 0.004 * math.sin(j * math.pi / 3)} end
					B.add(dot, true)
				end
			else
				for k = 0, 3 do
					local a = math.pi / 4 + k * math.pi / 2
					local c, sn = math.cos(a), math.sin(a)
					B.add({{sd.body * c, sd.body * sn}, {sd.fin * c, sd.fin * sn}})
					if sd.bar then
						B.add({{sd.fin * c - sd.bar * sn, sd.fin * sn + sd.bar * c}, {sd.fin * c + sd.bar * sn, sd.fin * sn - sd.bar * c}})
					elseif sd.grid then
						local gx, gy, h = sd.fin * c, sd.fin * sn, sd.grid
						B.add({{gx - h, gy - h}, {gx + h, gy - h}, {gx + h, gy + h}, {gx - h, gy + h}}, true)
					end
				end
				if sd.box then
					local h = sd.box
					B.add({{-h, -h}, {h, -h}, {h, h}, {-h, h}}, true)
				end
			end
			B.done()
		end
	end
	for n, q in ipairs(ST) do
		local px, py, sx, sy, al = q[1], q[2], q[3], q[4], q[5]
		local p = "S27MFD_SMS" .. n .. "_ST"
		-- leader: down from the pylon, then to the store
		local ym = py - 0.40 * (py - (sy + 0.055))
		for ci, c in ipairs({{M.white, F.white, 0.5, 1.5}, {M.route, F.orange, 1.5, 2.5}}) do
			local g = "sms_s" .. n .. "_" .. ci
			simple(g, "sms", {0, 0, 0}, {p}, {vis(0, c[3], c[4])})
			local lv, li = poly_lines({{px, py}, {px, ym}, {sx, sy + 0.055}}, false)
			mesh(g .. "_ld", g, "lines", lv, li, c[1])
			store_sym(g, sx, sy, c[1])
			local lx = sx
			if al == "RightCenter" then lx = sx + 0.03 elseif al == "LeftCenter" then lx = sx - 0.03 end
			text(g .. "_t", g, {lx, sy - 0.08, 0}, c[2], TXT_SMALL, al, nil, "S27MFD_SMS" .. n .. "_TXT")
		end
		text("sms_n" .. n, "sms", {px, py - 0.035, 0}, F.grey, TXT_ROSE, "CenterCenter", tostring(n), nil, {p, -0.5, 0.5})
	end
end

-- RWR (SPO-15 on the MFD) ---------------------------------------------------
page_group("rwr", PG.RWR)
shortcuts("rwr", PG.RWR)
do
	local CY, RR = 0.13, 0.48
	simple("rwr_c", "rwr", {0, CY, 0})
	local rv, ri = outline(circle_pts(RR, 72), 0.006)
	mesh("rwr_ring", "rwr_c", "triangles", rv, ri, M.ring)
	for _, r in ipairs({RR * 0.66, RR * 0.33}) do
		local dv, di = outline(circle_pts(r, 48), 0.004, true, 1)
		mesh("rwr_r" .. math.floor(r * 100), "rwr_c", "triangles", dv, di, M.planf)
	end
	local TK = batch("rwr_ticks", "rwr_c", M.ring)
	for d = 0, 330, 30 do
		local a = math.rad(90 - d)
		TK.add({{RR * math.cos(a), RR * math.sin(a)}, {(RR + 0.03) * math.cos(a), (RR + 0.03) * math.sin(a)}})
	end
	TK.done()
	local QD = batch("rwr_quad", "rwr_c", M.planf)
	for _, d in ipairs({45, 135, 225, 315}) do
		local a = math.rad(90 - d)
		QD.add({{0.05 * math.cos(a), 0.05 * math.sin(a)}, {RR * math.cos(a), RR * math.sin(a)}})
	end
	QD.done()
	mesh("rwr_nose", "rwr_c", "triangles", {{0, RR - 0.005}, {-0.02, RR - 0.04}, {0.02, RR - 0.04}}, {0, 1, 2}, M.white)
	v, i = poly_lines({{0, 0.04}, {0.03, -0.025}, {0, -0.01}, {-0.03, -0.025}}, true)
	mesh("rwr_own", "rwr_c", "lines", v, i, M.white)
	local lv, li = outline(circle_pts(0.055, 24), 0.006)
	for k = 1, 10 do
		local p = "S27MFD_RW" .. k .. "_"
		simple("rwr_e" .. k, "rwr_c", {0, 0, 0}, {p .. "X", p .. "Y", p .. "VIS"},
			{vis(2, 0.5, 1.5), {"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}})
		text("rwr_e" .. k .. "_a", "rwr_e" .. k, {0, 0, 0}, F.orange, TXT_SMALL, "CenterCenter", nil, p .. "TXT", {p .. "COL", 0.5, 1.5})
		text("rwr_e" .. k .. "_r", "rwr_e" .. k, {0, 0, 0}, F.red, TXT_SMALL, "CenterCenter", nil, p .. "TXT", {p .. "COL", 1.5, 2.5})
		mesh("rwr_e" .. k .. "_l", "rwr_e" .. k, "triangles", lv, li, M.hostile, nil, {p .. "LCK"}, {vis(0, 0.5, 1.5)})
	end
end

-- keypad entry line (every page) --------------------------------------------
text("entry", "sit_root", {0, -0.68, 0}, F.yellow, TXT_SMALL, "CenterCenter", nil, "S27MFD_ENTRY_TXT")

---------------------------------------------------------------------------
-- alignment test (Options: MFD alignment test): frame on the screen edges,
-- triangle top-left, centre cross, a box by every soft key (green while
-- pressed), a row of 17 boxes for the keypad keys. Shown whenever the MFD
-- is on, over everything.
---------------------------------------------------------------------------
simple("aln", nil, {0, 0, 0}, {"S27MFD_ON", "S27MFD_ALIGN"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, 0.5, 1.5}})
do
	local ex, ey, w = SIT.EDGE_X - 0.01, SIT.EDGE - 0.01, 0.008
	local function bar(name, x0, y0, x1, y1, mat, prm_, lo, hi)
		mesh(name, "aln", "triangles", {{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}}, {0, 1, 2, 0, 2, 3}, mat, nil,
			prm_ and {prm_} or nil, prm_ and {vis(0, lo or 0.5, hi or 1.5)} or nil)
	end
	local MG = col(255, 0, 255, 230)
	bar("aln_t", -ex, ey - w, ex, ey, MG); bar("aln_b", -ex, -ey, ex, -ey + w, MG)
	bar("aln_l", -ex, -ey, -ex + w, ey, MG); bar("aln_r", ex - w, -ey, ex, ey, MG)
	mesh("aln_tri", "aln", "triangles", {{-ex, ey}, {-ex + 0.14, ey}, {-ex, ey - 0.14}}, {0, 1, 2}, MG)
	bar("aln_cx", -0.08, -w / 2, 0.08, w / 2, MG); bar("aln_cy", -w / 2, -0.08, w / 2, 0.08, MG)
	local DIM = col(70, 80, 75, 220)
	for n = 1, 20 do
		local side, k = math.floor((n - 1) / 5), (n - 1) % 5 + 1
		local x, y
		if side == 0 then x, y = -0.76, Y5[k] elseif side == 1 then x, y = X5[k], -0.70
		elseif side == 2 then x, y = 0.76, Y5[k] else x, y = X5[k], 0.70 end
		bar("aln_o" .. n, x - 0.035, y - 0.025, x + 0.035, y + 0.025, DIM)
		bar("aln_ol" .. n, x - 0.035, y - 0.025, x + 0.035, y + 0.025, M.friend, "S27MFD_OSB" .. n .. "_LIT")
	end
	for k = 1, 17 do
		local x = -0.64 + (k - 1) * 0.08
		bar("aln_k" .. k, x - 0.028, -0.52, x + 0.028, -0.46, DIM)
		bar("aln_kl" .. k, x - 0.028, -0.52, x + 0.028, -0.46, M.friend, "S27MFD_KP" .. k .. "_LIT")
	end
end


---------------------------------------------------------------------------
-- start-up screen (power on, or the knob out of OFF): S27MFD_BOOT 2 = test
-- pattern, 3 = GO, then the page. Outside sit_root: it shows while the page
-- is still hidden.
---------------------------------------------------------------------------
simple("sit_boot", nil, {0, 0, 0}, {"S27MFD_BOOT"}, {{"parameter_in_range", 0, 1.5, 3.5}})
mesh("sit_boot_bg", "sit_boot", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3}, M.black)
do
	local b, bx = 0.78, 0.82
	local v, i = poly_lines({{-bx, b}, {bx, b}, {bx, -b}, {-bx, -b}}, true)
	mesh("sit_boot_frame", "sit_boot", "lines", v, i, M.label)
	v, i = poly_lines({{-0.06, 0}, {0.06, 0}}, false)
	mesh("sit_boot_x1", "sit_boot", "lines", v, i, M.label)
	v, i = poly_lines({{0, -0.06}, {0, 0.06}}, false)
	mesh("sit_boot_x2", "sit_boot", "lines", v, i, M.label)
	-- colour bar: the page's colours, a test pattern
	local cols = {M.friend, M.hostile, M.unknown, M.cyan, M.route, M.pdt}
	for k, m in ipairs(cols) do
		local x0 = -0.36 + (k - 1) * 0.12
		mesh("sit_boot_c" .. k, "sit_boot", "triangles", {{x0, -0.42}, {x0 + 0.10, -0.42}, {x0 + 0.10, -0.50}, {x0, -0.50}},
			{0, 1, 2, 0, 2, 3}, m)
	end
	text("sit_boot_t1", "sit_boot", {0, 0.30, 0}, F.green, TXT_BTN, "CenterCenter", "MFD")
	simple("sit_boot_p2", "sit_boot", {0, 0, 0}, {"S27MFD_BOOT"}, {{"parameter_in_range", 0, 1.5, 2.5}})
	text("sit_boot_t2", "sit_boot_p2", {0, 0.18, 0}, F.green, TXT_SMALL, "CenterCenter", "SELF TEST")
	simple("sit_boot_p3", "sit_boot", {0, 0, 0}, {"S27MFD_BOOT"}, {{"parameter_in_range", 0, 2.5, 3.5}})
	text("sit_boot_t3", "sit_boot_p3", {0, 0.18, 0}, F.green, TXT_SMALL, "CenterCenter", "SELF TEST  GO")
end

---------------------------------------------------------------------------
-- brightness (ЯРК + / -, ДЕНЬ / НОЧЬ): a black
-- see-through cover over everything, S27MFD_DIM 1..19 = 5..95 % dark.
-- Last in the list, so it is drawn over the page.
---------------------------------------------------------------------------
simple("sit_dim", nil, {0, 0, 0}, {"S27MFD_DIM"}, {{"parameter_in_range", 0, 0.5, 19.5}})
for k = 1, 19 do
	mesh("sit_dim" .. k, "sit_dim", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3},
		col(0, 0, 0, math.floor(k * 255 / 20 + 0.5)), nil, {"S27MFD_DIM"}, {vis(0, k - 0.5, k + 0.5)})
end
