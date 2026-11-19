-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: PFD page (NAV > PFD) - the MiG-29 MFD add-on's
-- MFI edition flight instruments (DL/dl_pfd.lua, round 24), unchanged but
-- for the names (S27MFD_PFD_*) and a layout for this screen
-- (SIT_MFI.pfd in MFD/mfd_mfi.lua). Speed tape, attitude with flight
-- director and flight path marker, altitude tape with ALT MAX / MIN
-- brackets, VSI, mode bar, heading arc (+ the Su-27 edition's steerpoint
-- pointer on the arc). Values: MFD/mfd_mfi_dev.lua (mfi_pfd).
-- Tapes and ball are clipped with the stencil (as the MiG-29 page does).
-----------------------------------------------------------------------
local function PFD_BUILD(root, L, DLH)
	local D = DLH
	local M, F, G, LW = D.M, D.F, D.G, D.LW
	local LVL, CLIP = D.LVL, D.CLIP
	local mesh, simple, text1 = D.mesh, D.simple, D.text1
	local col = D.col
	local MFI = D.MFI
	local TXS = D.TXT_SMALL
	local TXT = D.TXT
	local TT = {0.0026, 0.0008, 0, -0.001}          -- tape / ladder / arc numbers
	local TT2 = {0.0023, 0.0007, 0, -0.0009}
	local TT3 = {0.0020, 0.0006, 0, -0.0008}
	local TW = MFI and F.paper or F.white           -- white text on the grey tapes
	local C = L.colours or {}
	local TAPE  = col(C.tape and C.tape[1] or 112, C.tape and C.tape[2] or 117, C.tape and C.tape[3] or 126, C.tape and C.tape[4] or 255, true)
	local WHITE = col(255, 255, 255, 255, true)
	local BLACK = col(0, 0, 0, 255, true)
	local SKY   = col(C.sky and C.sky[1] or 30, C.sky and C.sky[2] or 140, C.sky and C.sky[3] or 215, 255, true)
	local GND   = col(C.gnd and C.gnd[1] or 140, C.gnd and C.gnd[2] or 75, C.gnd and C.gnd[3] or 20, 255, true)
	local MAG   = col(200, 20, 185, 255, true)        -- (round 24: the SA / LND radio-nav magenta)
	local YEL   = col(255, 205, 0, 255, true)
	local n = root .. "_pf"
	local function quad(x0, y0, x1, y1) return {{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, {0, 1, 2, 0, 2, 3} end
	-- element at a clip level (lvl 1 = inside a clip box)
	local function cel(cls, name, parent, fields, lvl, clip)
		local e = CreateElement(cls)
		e.name = name
		e.parent_element = parent
		e.h_clip_relation = clip or CLIP
		e.level = LVL + (lvl or 0)
		e.init_pos = fields.init_pos or {0, 0, 0}
		for k, v in pairs(fields) do e[k] = v end
		if cls == "ceMeshPoly" then e.isdraw = true; if e.isvisible == nil then e.isvisible = true end end
		Add(e)
		return e
	end
	local function cmesh(name, parent, v, i, mat, lvl, pos, params, ctrls)
		local f = {primitivetype = "triangles", vertices = v, indices = i, material = mat, init_pos = pos}
		if params then f.element_params, f.controllers = params, ctrls end
		return cel("ceMeshPoly", name, parent, f, lvl)
	end
	local function sdefs(d)
		d = d or TXS
		if not D.TEXF then return d end
		local FK, FW = D.CFG.font_scale or 1.25, D.CFG.font_width or 1.0
		return {d[1] * FK, d[1] * FK * FW, d[3] or 0, (d[4] or 0) * FK}
	end
	local function ctext(name, parent, pos, font, defs, align, value, lvl)
		return cel("ceStringPoly", name, parent, {material = font, init_pos = pos, alignment = align or "CenterCenter",
			stringdefs = sdefs(defs), value = value}, lvl)
	end
	-- a number from a parameter (fmt "%.0f": never "%s" on a number), hidden
	-- while the parameter is below hide_below
	local function cnum(name, parent, pos, font, defs, align, param, fmt, lvl, hide_below)
		local f = {material = font, init_pos = pos, alignment = align or "CenterCenter", stringdefs = sdefs(defs), formats = {fmt or "%.0f"},
			element_params = {param}, controllers = {{"text_using_parameter", 0}}}
		if hide_below then f.controllers[2] = {"parameter_in_range", 0, hide_below, 1e9} end
		return cel("ceStringPoly", name, parent, f, lvl)
	end
	local function clip_open(name, parent, x0, y0, x1, y1)
		local v, i = quad(x0, y0, x1, y1)
		cel("ceMeshPoly", name .. "_cl1", parent, {primitivetype = "triangles", vertices = v, indices = i, material = WHITE, isvisible = false},
			0, h_clip_relations.INCREASE_IF_LEVEL)
		return function()
			cel("ceMeshPoly", name .. "_cl2", parent, {primitivetype = "triangles", vertices = v, indices = i, material = WHITE, isvisible = false},
				1, h_clip_relations.DECREASE_IF_LEVEL)
		end
	end
	local function rect(name, parent, x0, y0, x1, y1, mat, lvl, params, ctrls)
		local v, i = quad(x0, y0, x1, y1)
		return cmesh(name, parent, v, i, mat, lvl, nil, params, ctrls)
	end
	local function frame_box(name, parent, x0, y0, x1, y1, mat, t, params, ctrls)
		t = t or LW
		local v = {{x0, y1}, {x1, y1}, {x1, y1 - t}, {x0, y1 - t}, {x0, y0 + t}, {x1, y0 + t}, {x1, y0}, {x0, y0},
		           {x0, y1}, {x0 + t, y1}, {x0 + t, y0}, {x0, y0}, {x1 - t, y1}, {x1, y1}, {x1, y0}, {x1 - t, y0}}
		local idx = {}
		for q = 0, 3 do local b = q * 4; for _, k in ipairs({0, 1, 2, 0, 2, 3}) do idx[#idx + 1] = b + k end end
		return cmesh(name, parent, v, idx, mat, 0, nil, params, ctrls)
	end
	simple(n, root, {0, 0, 0})

	-------------------------------------------------------------- tapes
	-- a tape = grey box with a short scale that only moves between two
	-- numbers: S27MFD_PFD_<id>T = (value mod step) x k, and the numbers
	-- S27MFD_PFD_<id>N-3..3 (the step multiples round the value) change, so a
	-- tape is a few dozen elements whatever its range. Clipped to the box.
	-- Marks moved on their own (ALT MAX / MIN brackets): param = (mark -
	-- value) x k, page units.
	local function tape(id, x0, x1, y0, y1, right, sets, bugs)
		local cy = (y0 + y1) / 2
		rect(n .. id .. "_bg", n, x0, y0, x1, y1, TAPE)
		local close = clip_open(n .. id, n, x0, y0, x1, y1)
		for si, S in ipairs(sets) do
			local g = n .. id .. "_s" .. si
			local sp = S.label * S.k                    -- page units between numbers
			cel("ceSimple", g .. "_v", n, {element_params = {S.vis or "S27MFD_PFD_ON"}, controllers = {{"parameter_in_range", 0, S.lo or 0.5, S.hi or 1.5}}}, 1)
			cel("ceSimple", g, g .. "_v", {init_pos = {0, cy, 0}, element_params = {"S27MFD_PFD_" .. id .. "T"},
				controllers = {{"move_up_down_using_parameter", 0, -G}}}, 1)
			local tv, ti = {}, {}
			local per = math.floor(S.label / S.tick + 0.5)
			local nn = S.n or 3                         -- numbers each side of the value
			for j = -(nn + 1) * per, (nn + 1) * per do
				local y = j * S.tick * S.k
				local big = (j % per == 0)
				local l = big and 0.05 or 0.03
				local xa = right and x0 or (x1 - l)
				local k = #tv
				tv[k + 1] = {xa, y + LW / 2}; tv[k + 2] = {xa + l, y + LW / 2}; tv[k + 3] = {xa + l, y - LW / 2}; tv[k + 4] = {xa, y - LW / 2}
				for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
			end
			cmesh(g .. "_tk", g, tv, ti, WHITE, 1)
			for j = -nn, nn do
				cnum(g .. "_n" .. (j + nn), g, {right and (x0 + 0.06) or (x1 - 0.06), j * sp, 0}, TW, TT2,
					right and "LeftCenter" or "RightCenter", "S27MFD_PFD_" .. id .. "N" .. (j + nn), "%.0f", 1, S.min and (S.min - 0.5))
			end
		end
		for _, B in ipairs(bugs or {}) do
			local b = n .. id .. "_" .. B.id
			cel("ceSimple", b, n, {init_pos = {0, cy, 0}, element_params = {B.param, B.vis},
				controllers = {{"move_up_down_using_parameter", 0, G}, {"parameter_in_range", 1, 0.5, 1.5}}}, 1)
			local bx = right and x0 or x1
			local s = right and 1 or -1
			local t = LW * 1.6
			local up = B.up and 1 or -1
			-- a bracket: the line at the mark, its end bent away from the band
			cmesh(b .. "_m", b, {{bx, -t / 2}, {bx + s * 0.11, -t / 2}, {bx + s * 0.11, t / 2}, {bx, t / 2},
				{bx + s * (0.11 - t), 0}, {bx + s * 0.11, 0}, {bx + s * 0.11, up * 0.07}, {bx + s * (0.11 - t), up * 0.07}},
				{0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7}, MAG, 1)
		end
		close()
		-- readout box with a pointer towards the ADI
		local w = (x1 - x0) + 0.05 + (right and (L.box_ext or 0.03) or 0)
		local bx0 = right and (x0 - 0.05) or x0
		local bx1 = bx0 + w
		local h = 0.085
		local tip = right and bx0 or bx1
		local tin = right and (bx0 + 0.04) or (bx1 - 0.04)
		local v = right and {{tin, cy + h}, {bx1, cy + h}, {bx1, cy - h}, {tin, cy - h}, {tin, cy - 0.03}, {tip, cy}, {tin, cy + 0.03}}
		                or  {{bx0, cy + h}, {tin, cy + h}, {tin, cy + 0.03}, {tip, cy}, {tin, cy - 0.03}, {tin, cy - h}, {bx0, cy - h}}
		local vi = right and {0, 1, 2, 0, 2, 3, 4, 5, 6} or {0, 1, 5, 0, 5, 6, 2, 3, 4}
		cmesh(n .. id .. "_box", n, v, vi, BLACK)
		frame_box(n .. id .. "_boxr", n, right and tin or bx0, cy - h, right and bx1 or tin, cy + h, WHITE, LW * 0.8)
		cnum(n .. id .. "_val", n, {(right and (tin + bx1) or (bx0 + tin)) / 2, cy, 0}, MFI and F.paper or F.white, right and TT or TXS, "CenterCenter", "S27MFD_PFD_" .. id .. "V", "%.0f")
	end
	local ty0, ty1 = L.tape_y0, L.tape_y1
	local SK = L.spd_k or 0.01086                    -- page units per km/h (kt)
	tape("S", L.spd_x0, L.spd_x1, ty0, ty1, false, {{tick = 10, label = L.spd_step or 50, k = SK, min = 0, n = L.spd_n}})
	local AK, AKF = L.alt_k or 0.002262, L.alt_kft or 0.000905
	tape("A", L.alt_x0, L.alt_x1, ty0, ty1, true, {
		{vis = "S27MFD_PFD_IMP", lo = -0.5, hi = 0.5, tick = 50, label = L.alt_step or 200, k = AK, n = L.alt_n},
		{vis = "S27MFD_PFD_IMP", lo = 0.5, hi = 1.5, tick = 100, label = L.alt_step_ft or 500, k = AKF, n = L.alt_n}},
		{{id = "mx", param = "S27MFD_PFD_AMXY", vis = "S27MFD_PFD_AMXON", up = true}, {id = "mn", param = "S27MFD_PFD_AMNY", vis = "S27MFD_PFD_AMNON", up = false}})
	-- the texts round the tapes (Mach, units, radar / baro altitude, ground
	-- speed, source, wind): L.labels = {{param, x, y, align, font, small}}
	for k, T in ipairs(L.labels or {}) do
		text1(n .. "_lb" .. k, n, {T[2], T[3], 0}, T[5] or F.white, T[6] and TT2 or TT, T[4] or "LeftCenter", nil, T[1])
	end

	---------------------------------------------------------------- ADI
	local ax0, ax1, ay0, ay1 = L.adi_x0, L.adi_x1, L.adi_y0, L.adi_y1
	local acx, acy = (ax0 + ax1) / 2, (ay0 + ay1) / 2
	local PPD = L.ppd or 0.032                       -- page units per degree of pitch
	local a = n .. "_adi"
	simple(a, n, {acx, acy, 0})
	do
		local close = clip_open(a, a, ax0 - acx, ay0 - acy, ax1 - acx, ay1 - acy)
		cel("ceSimple", a .. "_roll", a, {element_params = {"S27MFD_PFD_BANK"}, controllers = {{"rotate_using_parameter", 0, 1}}}, 1)
		cel("ceSimple", a .. "_pitch", a .. "_roll", {element_params = {"S27MFD_PFD_PY"}, controllers = {{"move_up_down_using_parameter", 0, -G}}}, 1)
		local p = a .. "_pitch"
		rect(a .. "_sky", p, -2.5, 0, 2.5, 4.0, SKY, 1)
		rect(a .. "_gnd", p, -2.5, -4.0, 2.5, 0, GND, 1)
		rect(a .. "_hor", p, -2.5, -LW / 2, 2.5, LW / 2, WHITE, 1)
		local lv, li = {}, {}
		for p10 = -800, 800, 25 do
			if p10 ~= 0 then
				local y = p10 / 10 * PPD
				local w = (p10 % 100 == 0) and 0.15 or ((p10 % 50 == 0) and 0.08 or 0.035)
				if math.abs(p10) > 200 and p10 % 50 ~= 0 then w = 0 end
				if math.abs(p10) > 300 and p10 % 100 ~= 0 then w = 0 end
				if w > 0 then
					local k = #lv
					lv[k + 1] = {-w, y + LW / 2}; lv[k + 2] = {w, y + LW / 2}; lv[k + 3] = {w, y - LW / 2}; lv[k + 4] = {-w, y - LW / 2}
					for _, q in ipairs({0, 1, 2, 0, 2, 3}) do li[#li + 1] = k + q end
					if p10 % 100 == 0 then
						for _, sx in ipairs({-1, 1}) do
							ctext(a .. "_pn" .. p10 .. "_" .. sx, p, {sx * (w + 0.05), y, 0}, F.paper or F.white, TT2, "CenterCenter", tostring(math.abs(p10 / 10)), 1)
						end
					end
				end
			end
		end
		cmesh(a .. "_lad", p, lv, li, WHITE, 1)
		-- round 24: flight path marker on the pitch ladder (where the jet is
		-- going: flight path angle up / down, drift left / right; S27MFD_PFD_FPX/FPY
		-- page units on the horizon frame), white with a black rim
		if L.fpm ~= false then
			cel("ceSimple", a .. "_fpm", p, {element_params = {"S27MFD_PFD_FPX", "S27MFD_PFD_FPY", "S27MFD_PFD_FPON"},
				controllers = {{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, {"parameter_in_range", 2, 0.5, 1.5}}}, 1)
			local fr, ft = L.fpm_r or 0.032, LW * 1.3
			for k, m in ipairs({{BLACK, LW * 0.9}, {WHITE, 0}}) do
				local gw = m[2]
				local cv, ci = D.circle_ring(fr + gw, ft + 2 * gw, 20)
				cmesh(a .. "_fpm_c" .. k, a .. "_fpm", cv, ci, m[1], 1)
				rect(a .. "_fpm_l" .. k, a .. "_fpm", -fr * 2.4 - gw, -ft / 2 - gw, -fr + gw, ft / 2 + gw, m[1], 1)
				rect(a .. "_fpm_r" .. k, a .. "_fpm", fr - gw, -ft / 2 - gw, fr * 2.4 + gw, ft / 2 + gw, m[1], 1)
				rect(a .. "_fpm_t" .. k, a .. "_fpm", -ft / 2 - gw, fr - gw, ft / 2 + gw, fr * 1.9 + gw, m[1], 1)
			end
		end
		-- bank pointer turns with the horizon (on the roll group, not pitch)
		local R = L.bank_r or ((ay1 - ay0) * 0.40)
		cmesh(a .. "_bp", a .. "_roll", {{0, R - 0.005}, {0.035, R - 0.06}, {-0.035, R - 0.06}}, {0, 1, 2}, YEL, 1)
		close()
		-- fixed bank scale
		local tv, ti = {}, {}
		for _, d in ipairs({-60, -45, -30, -20, -10, 10, 20, 30, 45, 60}) do
			local t = math.rad(90 - d)
			local l = (d % 30 == 0) and 0.06 or 0.035
			local ca, sa = math.cos(t), math.sin(t)
			local px, py = -sa * LW / 2, ca * LW / 2
			local k = #tv
			tv[k + 1] = {R * ca + px, R * sa + py}; tv[k + 2] = {(R + l) * ca + px, (R + l) * sa + py}
			tv[k + 3] = {(R + l) * ca - px, (R + l) * sa - py}; tv[k + 4] = {R * ca - px, R * sa - py}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
		end
		cmesh(a .. "_bs", a, tv, ti, WHITE)
		cmesh(a .. "_b0", a, {{0, R + 0.003}, {0.035, R + 0.065}, {-0.035, R + 0.065}}, {0, 1, 2}, WHITE)
		-- flight director (magenta bars, S27MFD_PFD_FDX / FDY page units)
		local fl = R * 0.85
		cel("ceSimple", a .. "_fdv", a, {element_params = {"S27MFD_PFD_FDX", "S27MFD_PFD_FDON"},
			controllers = {{"move_left_right_using_parameter", 0, G}, {"parameter_in_range", 1, 0.5, 1.5}}})
		rect(a .. "_fdvm", a .. "_fdv", -LW * 0.9, -fl, LW * 0.9, fl, MAG)
		cel("ceSimple", a .. "_fdh", a, {element_params = {"S27MFD_PFD_FDY", "S27MFD_PFD_FDON"},
			controllers = {{"move_up_down_using_parameter", 0, G}, {"parameter_in_range", 1, 0.5, 1.5}}})
		rect(a .. "_fdhm", a .. "_fdh", -fl, -LW * 0.9, fl, LW * 0.9, MAG)
		-- aircraft symbol: black L bars with a white rim, centre square
		local W1 = L.wing or ((ax1 - ax0) * 0.42)
		for _, s in ipairs({-1, 1}) do
			local xa, xb = s * W1 * 0.42, s * W1
			local function bar(nm, grow, mat)
				local x_a, x_b = xa - s * grow, xb + s * grow
				local v = {{x_a, 0.02 + grow}, {x_b, 0.02 + grow}, {x_b, -0.02 - grow}, {x_a + s * 0.04 + s * grow, -0.02 - grow},
				           {x_a + s * 0.04 + s * grow, -0.09 - grow}, {x_a, -0.09 - grow}}
				if s < 0 then for _, q in ipairs(v) do q[1] = q[1] end end
				cmesh(nm, a, v, {0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5}, mat)
			end
			bar(a .. "_acw" .. s, 0.008, (L.ac == "yellow") and BLACK or WHITE)
			bar(a .. "_acb" .. s, 0, (L.ac == "yellow") and YEL or BLACK)
		end
		rect(a .. "_acc_w", a, -0.028, -0.028, 0.028, 0.028, (L.ac == "yellow") and BLACK or WHITE)
		rect(a .. "_acc_b", a, -0.02, -0.02, 0.02, 0.02, (L.ac == "yellow") and YEL or BLACK)
	end

	---------------------------------------------------------------- VSI
	if L.vsi_x0 then
		local x0, x1, y0, y1 = L.vsi_x0, L.vsi_x1, L.vsi_y0, L.vsi_y1
		local cy = (y0 + y1) / 2
		local g = n .. "_vsi"
		simple(g, n, {0, 0, 0}, {"S27MFD_PFD_VSION"}, {{"parameter_in_range", 0, 0.5, 1.5}})
		cmesh(g .. "_bg", g, {{x0, y1 - 0.1}, {x0 + 0.04, y1}, {x1, y1}, {x1, y0}, {x0 + 0.04, y0}, {x0, y0 + 0.1}}, {0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5}, TAPE)
		local tv, ti = {}, {}
		for _, v in ipairs({-50, -20, -10, -5, -2, 0, 2, 5, 10, 20, 50}) do
			local y = cy + SIT_MFI.vsi_dy(L, v)
			local l = (v % 10 == 0) and 0.045 or 0.028
			local k = #tv
			tv[k + 1] = {x0 + 0.05, y + LW / 2}; tv[k + 2] = {x0 + 0.05 + l, y + LW / 2}; tv[k + 3] = {x0 + 0.05 + l, y - LW / 2}; tv[k + 4] = {x0 + 0.05, y - LW / 2}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
			if v ~= 0 and math.abs(v) ~= 2 then text1(g .. "_t" .. v, g, {x0 + 0.105, y, 0}, TW, TT3, "LeftCenter", tostring(math.abs(v))) end
		end
		cmesh(g .. "_tk", g, tv, ti, WHITE)
		-- needle: a line from a pivot far right of the scale (as on airliner
		-- PFDs), turned by S27MFD_PFD_VSA so it crosses the scale at the vertical
		-- speed; clipped to the scale box
		local px = x1 + (L.vsi_pivot or 0.60)
		local close = clip_open(g .. "_ndc", g, x0, y0, x1, y1)
		cel("ceSimple", g .. "_nd", g, {init_pos = {px, cy, 0}, element_params = {"S27MFD_PFD_VSA"}, controllers = {{"rotate_using_parameter", 0, 1}}}, 1)
		rect(g .. "_ndm", g .. "_nd", -2.0, -LW * 0.9, 0, LW * 0.9, WHITE, 1)
		close()
		cnum(g .. "_v", g, {x1 + 0.014, y1 + 0.05, 0}, F.green, TT2, "RightCenter", "S27MFD_PFD_VSV", "%+.0f")
	end

	----------------------------------------------------------- mode bar
	if L.fma_y then
		local x0, x1, y = L.fma_x0, L.fma_x1, L.fma_y
		rect(n .. "_fma", n, x0, y - 0.05, x1, y + 0.05, TAPE)
		local w = (x1 - x0) / 3
		for k = 1, 3 do
			if k > 1 then rect(n .. "_fmas" .. k, n, x0 + (k - 1) * w - LW / 2, y - 0.04, x0 + (k - 1) * w + LW / 2, y + 0.04, WHITE) end
			text1(n .. "_fm" .. k, n, {x0 + (k - 0.5) * w, y, 0}, MFI and F.paper or F.green, TT3, "CenterCenter", nil, "S27MFD_M_PFD_FM" .. k)
		end
	end

	-------------------------------------------------------- heading arc
	if L.arc_r then
		local cx, cy, R = L.arc_x, L.arc_y, L.arc_r
		local close = clip_open(n .. "_arc", n, L.arc_clip[1], L.arc_clip[2], L.arc_clip[3], L.arc_clip[4])
		local v, i = D.circle_fill(R, 72)
		cmesh(n .. "_arcbg", n, v, i, TAPE, 1, {cx, cy, 0})
		cel("ceSimple", n .. "_arcr", n, {init_pos = {cx, cy, 0}, element_params = {"S27MFD_PFD_HDG"}, controllers = {{"rotate_using_parameter", 0, 1}}}, 1)
		local tv, ti = {}, {}
		for b = 0, 355, 5 do
			local t = math.rad(90 - b)
			local l = (b % 10 == 0) and 0.05 or 0.03
			local ca, sa = math.cos(t), math.sin(t)
			local px, py = -sa * LW / 2, ca * LW / 2
			local k = #tv
			tv[k + 1] = {R * ca + px, R * sa + py}; tv[k + 2] = {(R - l) * ca + px, (R - l) * sa + py}
			tv[k + 3] = {(R - l) * ca - px, (R - l) * sa - py}; tv[k + 4] = {R * ca - px, R * sa - py}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
			if b % 10 == 0 then
				-- the number on its own point, turned to its bearing (a compass card)
				local rr = R - 0.10
				cel("ceSimple", n .. "_arcn" .. b, n .. "_arcr", {init_pos = {rr * ca, rr * sa, 0}, element_params = {"S27MFD_PFD_ONE"},
					controllers = {{"rotate_using_parameter", 0, -math.rad(b)}}}, 1)
				ctext(n .. "_arct" .. b, n .. "_arcn" .. b, {0, 0, 0}, TW, (b % 30 == 0) and TT2 or TT3, "CenterCenter", tostring(b / 10), 1)
			end
		end
		cmesh(n .. "_arctk", n .. "_arcr", tv, ti, WHITE, 1)
		-- selected heading bug (HSI's HDG), magenta
		cel("ceSimple", n .. "_arcb", n, {init_pos = {cx, cy, 0}, element_params = {"S27MFD_PFD_BUG"}, controllers = {{"rotate_using_parameter", 0, 1}}}, 1)
		cmesh(n .. "_arcbm", n .. "_arcb", {{-0.035, R + 0.012}, {0.035, R + 0.012}, {0.035, R - 0.035}, {-0.035, R - 0.035}}, {0, 1, 2, 0, 2, 3}, MAG, 1)
		close()
		cmesh(n .. "_arclub", n, {{cx, cy + R - 0.005}, {cx + 0.04, cy + R + 0.07}, {cx - 0.04, cy + R + 0.07}}, {0, 1, 2}, WHITE)
		cnum(n .. "_arcv", n, {cx, L.arc_txt_y or (cy + R - 0.22), 0}, TW, {TT[1] * 1.3, TT[2] * 1.3, 0, TT[4] * 1.3}, "CenterCenter", "S27MFD_PFD_HDGV", "%03.0fT")   -- (test 3: x 1.3 below)
	end
end


function S27MFI_PFD_PAGE(D, U)
	local MK, K = U.MK, U.K
	local GEO = SIT_MFI.pfd
	local FK, FW = GEO.font_scale or 1.85, SIT.FONT_WIDTH or 1
	local function sd(d) return {d[1] * FK, d[1] * FK * FW, d[3] or 0, (d[4] or 0) * FK} end
	-- the MiG-29 page helpers this file needs, on this page's
	local DLH = {
		M = {}, G = D.G, LW = 0.005, LVL = 0, CLIP = h_clip_relations.COMPARE, MFI = true, TEXF = true,
		CFG = {font_scale = FK, font_width = FW},
		TXT_SMALL = {0.0026, 0.0008, 0, -0.001}, TXT = {0.0030, 0.0009, 0, -0.0012},
		F = {paper = K.paper, white = K.paper, green = K.green, magenta = K.magenta, amber = K.amber, black = K.black},
		mesh = D.mesh, simple = D.simple, col = D.col,
		text1 = function(name, parent, pos, font, defs, align, value, param)
			return D.text(name, parent, pos, font, sd(defs), align, value, param)
		end,
		circle_ring = function(r, w, n) return D.band(D.circle_pts(r, n), D.circle_pts(r - w, n)) end,
		circle_fill = D.circle_fill,
	}
	local r = "mf_pf"
	U.root(r, SIT.PG.PFD)
	-- the stencil level of the page area to 0 first, whatever was there
	do
		local e = CreateElement "ceMeshPoly"
		e.name = r .. "_stz"; e.parent_element = r; e.primitivetype = "triangles"
		e.vertices = {{-0.76, 0.70}, {0.76, 0.70}, {0.76, -0.70}, {-0.76, -0.70}}; e.indices = {0, 1, 2, 0, 2, 3}
		e.material = MK.paper; e.init_pos = {0, 0, 0}; e.isvisible = false
		e.h_clip_relation = h_clip_relations.REWRITE_LEVEL; e.level = 0
		Add(e)
	end
	local L = {}
	for k, v in pairs(GEO) do L[k] = v end
	local XL, XR = -0.745, 0.745
	L.labels = {
		{"S27MFD_M_PFD_SL", XL, 0.655, "LeftCenter", K.black},
		{"S27MFD_M_PFD_SU", XL, 0.595, "LeftCenter", K.black, true},
		{"S27MFD_M_PFD_AL", XR, 0.655, "RightCenter", K.magenta, true},
		{"S27MFD_M_PFD_AU", XR, 0.595, "RightCenter", K.black, true},
		{"S27MFD_M_PFD_BL", XL, -0.43, "LeftCenter", K.black},
		{"S27MFD_M_PFD_BR", L.alt_x0, -0.43, "LeftCenter", K.green},
		{"S27MFD_M_PFD_LIM1", XR, -0.515, "RightCenter", K.magenta, true},
		{"S27MFD_M_PFD_LIM2", XR, -0.575, "RightCenter", K.magenta, true},
		{"S27MFD_M_PFD_WIND", XR, -0.655, "RightCenter", K.green, true},
		{"S27MFD_M_PFD_ENTRY", XL, -0.52, "LeftCenter", K.amber, true},
	}
	PFD_BUILD(r, L, DLH)
	-- steerpoint pointer on the heading arc (orange): its bearing, held at
	-- the arc's edge (SIT_MFI.pfd.wp_lim) when it is further round
	local n = r .. "_wp"
	D.simple(n, r, {L.arc_x, L.arc_y, 0}, {"S27MFD_PFD_WPB", "S27MFD_PFD_WPV"}, {{"rotate_using_parameter", 0, 1}, D.vis(1, 0.5, 2.5)})
	local R = L.arc_r
	D.mesh(n .. "_in", n, "triangles", {{0, R + 0.005}, {0.032, R + 0.06}, {-0.032, R + 0.06}}, {0, 1, 2}, MK.orange, nil, {"S27MFD_PFD_WPV"}, {D.vis(0, 0.5, 1.5)})
	D.mesh(n .. "_out", n, "triangles", {{0, R + 0.005}, {0.032, R + 0.06}, {-0.032, R + 0.06}}, {0, 1, 2}, MK.red, nil, {"S27MFD_PFD_WPV"}, {D.vis(0, 1.5, 2.5)})
	D.text(r .. "_wpt", r, {XL, -0.495, 0}, K.orange, U.TXT_T, "LeftCenter", nil, "S27MFD_M_PFD_WPT")
end
