-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: LOFT page (ATK > LOFT) - the MiG-29 MFD
-- add-on's loft attack page (v1.8.4) for unguided rockets and bombs on
-- the active steerpoint: bearing scale with the steerpoint diamond, pitch
-- ladder (release angle line), steering bar on the ground track, climb
-- angle scale, range bar (MIN / OPT / MAX), the cue (PULL IN m:ss / PULL /
-- HOLD / SHOOT / IN RNG / warnings), readouts and the trajectory side view.
-- Laid out by SIT_MFI.loft (MFD/mfd_mfi.lua); values from the MiG-29's own
-- ballistics (MFD/mfd_mfi_loft_calc.lua = DL/dl_loft.lua), DLP_LFT_*.
-- Left W+ W- WPN, right ANG+ ANG- DEF.
-----------------------------------------------------------------------
function S27MFI_LOFT_PAGE(D, U)
	local K, MK, G = U.K, U.MK, D.G
	local mesh, simple, text, line_obj = D.mesh, D.simple, D.text, D.line_obj
	local GEO = SIT_MFI.loft
	local LW = 0.005
	local TXS, TXT_T, TXL, TXT = U.TXC, U.TXT_T, U.TXL, U.TX
	local PSX, PSY0, PSH, PSMAX = GEO.psx, GEO.pitch_y0, GEO.pitch_h, GEO.pitch_max
	local PX0, PY0, PW, PH = GEO.prof_x0, GEO.prof_y0, GEO.prof_w, GEO.prof_h
	local SY = GEO.sy
	local LX = -0.745
	local function vis(i, lo, hi) return {"parameter_in_range", i, lo, hi} end
	local function rect(n, par, x0, y0, x1, y1, mat, params, ctrls)
		mesh(n, par, "triangles", {{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, {0, 1, 2, 0, 2, 3}, mat, nil, params, ctrls)
	end
	local function line(par, n, x, y, param, font, defs, align, v)
		return text(par .. "_" .. n, par, {x, y, 0}, font, defs, align or "LeftCenter", nil, param, v)
	end
	local r = "mf_lf"
	U.root(r, SIT.PG.LOFT)
	line(r, "wpn", LX, 0.655, "DLP_LFT_WPN", K.green, TXS)
	line(r, "wpn2", LX, 0.595, "DLP_LFT_WPN2", K.grey, TXT_T)
	line(r, "tgt", -LX, 0.655, "DLP_LFT_TGT", U.KB.dkyellow, U.TX, "RightCenter")   -- (test 3: dark yellow, thick, bigger: MiG round 28)
	line(r, "trng", -LX, 0.585, "DLP_LFT_TRNG", U.KB.dkyellow, TXS, "RightCenter")
	-- bearing scale (+-25 deg) and the steerpoint diamond (amber: further round)
	do
		local TY, TK = GEO.tape_y, GEO.tape_k
		rect(r .. "_hb", r, -25 * TK, TY - LW / 2, 25 * TK, TY + LW / 2, MK.black)
		local tv, ti = {}, {}
		for d = -25, 25, 5 do
			local x, h = d * TK, (d % 10 == 0) and 0.035 or 0.02
			local k = #tv
			tv[k + 1] = {x - LW / 2, TY}; tv[k + 2] = {x + LW / 2, TY}; tv[k + 3] = {x + LW / 2, TY + h}; tv[k + 4] = {x - LW / 2, TY + h}
			for _, q in ipairs({0, 1, 2, 0, 2, 3}) do ti[#ti + 1] = k + q end
		end
		mesh(r .. "_hbt", r, "triangles", tv, ti, MK.black)
		mesh(r .. "_hbn", r, "triangles", {{0, TY - 0.005}, {0.022, TY - 0.045}, {-0.022, TY - 0.045}}, {0, 1, 2}, MK.black)
		simple(r .. "_brg", r, {0, TY + 0.06, 0}, {"DLP_LFT_DX", "DLP_LFT_DV"}, {{"move_left_right_using_parameter", 0, G}, vis(1, 0.5, 2.5)})
		local q = 0.028
		local dv, di = D.band({{0, q}, {q, 0}, {0, -q}, {-q, 0}}, {{0, q - LW * 1.4}, {q - LW * 1.4, 0}, {0, -q + LW * 1.4}, {-q + LW * 1.4, 0}})
		mesh(r .. "_brg_g", r .. "_brg", "triangles", dv, di, MK.black, nil, {"DLP_LFT_DV"}, {vis(0, 0.5, 1.5)})
		mesh(r .. "_brg_a", r .. "_brg", "triangles", dv, di, MK.amber, nil, {"DLP_LFT_DV"}, {vis(0, 1.5, 2.5)})
	end
	-- pitch ladder round the jet reference (every 5 deg), release angle line
	do
		local KL = GEO.ladder_k
		simple(r .. "_lad", r, {0, SY, 0}, {"DLP_LFT_LY"}, {{"move_up_down_using_parameter", 0, G}})
		for p = 0, 45, 5 do
			local n = r .. "_lad" .. p
			simple(n, r .. "_lad", {0, p * KL, 0}, {"DLP_LFT_L" .. p .. "V"}, {vis(0, 0.5, 1.5)})
			local w0, w1 = 0.09, (p % 10 == 0) and 0.22 or 0.16
			rect(n .. "_l", n, -w1, -LW * 0.5, -w0, LW * 0.5, MK.grey)
			rect(n .. "_r", n, w0, -LW * 0.5, w1, LW * 0.5, MK.grey)
			if p % 10 == 0 then text(n .. "_n", n, {0.24, 0, 0}, K.green, TXT_T, "LeftCenter", tostring(p) .. " ") end
		end
		simple(r .. "_lrl", r, {0, SY, 0}, {"DLP_LFT_LRY", "DLP_LFT_LRV"}, {{"move_up_down_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
		rect(r .. "_lrl_l", r .. "_lrl", -0.26, -LW * 0.9, -0.07, LW * 0.9, MK.black)
		rect(r .. "_lrl_r", r .. "_lrl", 0.07, -LW * 0.9, 0.26, LW * 0.9, MK.black)
		local cv, ci = D.band(D.circle_pts(0.04, 24), D.circle_pts(0.04 - LW * 0.8, 24))
		simple(r .. "_ref", r, {0, SY, 0})
		mesh(r .. "_ref_c", r .. "_ref", "triangles", cv, ci, MK.grey)
		rect(r .. "_ref_t", r .. "_ref", -LW * 0.5, 0.04, LW * 0.5, 0.08, MK.grey)
		simple(r .. "_sb", r, {0, SY, 0}, {"DLP_LFT_SX", "DLP_LFT_SV"}, {{"move_left_right_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
		rect(r .. "_sb_l", r .. "_sb", -LW * 0.8, -0.15, LW * 0.8, 0.15, MK.black)
		line(r, "steer", 0, SY - 0.19, "DLP_LFT_STEER", K.black, TXS, "CenterCenter")
	end
	-- climb angle scale (flight path angle), 0..45 deg
	rect(r .. "_pscl", r, PSX - LW * 0.6, PSY0, PSX + LW * 0.6, PSY0 + PSH, MK.black)
	for p = 0, PSMAX, 5 do
		local y = PSY0 + p / PSMAX * PSH
		local l = (p % 15 == 0) and 0.04 or 0.02
		rect(r .. "_pt" .. p, r, PSX, y - LW * 0.4, PSX + l, y + LW * 0.4, MK.black)
		if p % 15 == 0 then text(r .. "_pn" .. p, r, {PSX + 0.055, y, 0}, K.black, TXT_T, "LeftCenter", (p == 0) and "0 DEG" or tostring(p) .. " ") end
	end
	text(r .. "_pl", r, {PSX, PSY0 + PSH + 0.05, 0}, K.grey, TXT_T, "CenterCenter", "FPA")
	simple(r .. "_pc", r, {PSX, PSY0, 0}, {"DLP_LFT_PY", "DLP_LFT_PV"}, {{"move_up_down_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
	mesh(r .. "_pc_t", r .. "_pc", "triangles", {{-0.008, 0}, {-0.05, 0.022}, {-0.05, -0.022}}, {0, 1, 2}, MK.black)
	simple(r .. "_abr", r, {PSX, PSY0, 0}, {"DLP_LFT_AY", "DLP_LFT_AV"}, {{"move_up_down_using_parameter", 0, G}, vis(1, 0.5, 1.5)})
	do
		local bw, bh = 0.035, 0.03
		rect(r .. "_abr_t", r .. "_abr", -bw - 0.06, bh - LW * 0.5, -0.06, bh + LW * 0.5, MK.amber)
		rect(r .. "_abr_b", r .. "_abr", -bw - 0.06, -bh - LW * 0.5, -0.06, -bh + LW * 0.5, MK.amber)
		rect(r .. "_abr_v", r .. "_abr", -bw - 0.06 - LW * 0.5, -bh, -bw - 0.06 + LW * 0.5, bh, MK.amber)
	end
	-- range bar: range to the target against MIN / OPT / MAX
	do
		local RX0 = GEO.rbar_x
		simple(r .. "_rb", r, {0, 0, 0}, {"DLP_LFT_ZV"}, {vis(0, 0.5, 1.5)})
		local rb = r .. "_rb"
		rect(rb .. "_l", rb, RX0 - LW * 0.6, PSY0, RX0 + LW * 0.6, PSY0 + PSH, MK.black)
		for k = 0, 4 do
			local y = PSY0 + k / 4 * PSH
			rect(rb .. "_t" .. k, rb, RX0, y - LW * 0.4, RX0 + ((k % 2 == 0) and 0.035 or 0.02), y + LW * 0.4, MK.black)
		end
		line(rb, "sc", RX0, PSY0 + PSH + 0.05, "DLP_LFT_RSC", K.grey, TXT_T, "CenterCenter")
		for _, m in ipairs({{"MX", "MAX", 0.045, 1}, {"OP", "OPT", 0.07, 2}, {"MN", "MIN", 0.045, 1}}) do
			local n = rb .. "_" .. m[1]
			simple(n, rb, {RX0, PSY0, 0}, {"DLP_LFT_" .. m[1] .. "Y"}, {{"move_up_down_using_parameter", 0, G}})
			rect(n .. "_m", n, -m[3], -LW * 0.7 * m[4], -0.004, LW * 0.7 * m[4], MK.grey)
			if m[1] == "OP" then
				rect(n .. "_f", n, -0.016, -0.03, -0.004, 0.03, MK.grey)
				text(n .. "_t", n, {-m[3] - 0.012, 0, 0}, K.green, TXT_T, "RightCenter", m[2])
			else
				simple(n .. "_lv", n, {0, 0, 0}, {"DLP_LFT_" .. m[1] .. "V"}, {vis(0, 0.5, 1.5)})
				text(n .. "_t", n .. "_lv", {-m[3] - 0.012, 0, 0}, K.green, TXT_T, "RightCenter", m[2])
			end
		end
		simple(rb .. "_c", rb, {RX0, PSY0, 0}, {"DLP_LFT_RY"}, {{"move_up_down_using_parameter", 0, G}})
		mesh(rb .. "_c_t", rb .. "_c", "triangles", {{0.008, 0}, {0.05, 0.022}, {0.05, -0.022}}, {0, 1, 2}, MK.black)
		line(rb .. "_c", "v", 0.06, 0, "DLP_LFT_RCT", K.yellow, TXT_T)
		line_obj(rb .. "_ib", rb, MK.green, 0.012, {"DLP_LFT_IBX", "DLP_LFT_IB0", "DLP_LFT_IBX", "DLP_LFT_IB1", "DLP_LFT_IBV"},
			{{"line_object_set_point_using_parameters", 0, 0, 1, G, G},
			 {"line_object_set_point_using_parameters", 1, 2, 3, G, G},
			 vis(4, 0.5, 1.5)})
	end
	-- the cue: 1 text, 2 boxed, 3 SHOOT (on green), 4 warning (amber), 5 IN RNG (green, boxed)
	local CY = -0.07
	line(r, "cue1", 0, CY, "DLP_LFT_CUET", K.yellow, TXL, "CenterCenter", {"DLP_LFT_CUE", 0.5, 2.5})
	simple(r .. "_cb", r, {0, CY, 0}, {"DLP_LFT_CUE"}, {vis(0, 1.5, 2.5)})
	U.box(r .. "_cb", "f", 0, 0, 0.62, 0.12, MK.black)
	simple(r .. "_cs", r, {0, CY, 0}, {"DLP_LFT_CUE"}, {vis(0, 2.5, 3.5)})
	rect(r .. "_cs_bg", r .. "_cs", -0.32, -0.065, 0.32, 0.065, MK.green)
	line(r .. "_cs", "t", 0, 0, "DLP_LFT_CUET", K.paper, TXL, "CenterCenter")
	line(r, "cue4", 0, CY, "DLP_LFT_CUET", K.amber, TXT, "CenterCenter", {"DLP_LFT_CUE", 3.5, 4.5})
	line(r, "cue5", 0, CY, "DLP_LFT_CUET", K.green, TXL, "CenterCenter", {"DLP_LFT_CUE", 4.5, 5.5})
	simple(r .. "_c5", r, {0, CY, 0}, {"DLP_LFT_CUE"}, {vis(0, 4.5, 5.5)})
	U.box(r .. "_c5", "f", 0, 0, 0.62, 0.12, MK.green)
	line(r, "sub", 0, CY - 0.095, "DLP_LFT_SUB", K.grey, TXT_T, "CenterCenter")
	for k = 1, 3 do
		local y = -0.23 - (k - 1) * 0.055
		line(r, "a" .. k, -0.70, y, "DLP_LFT_A" .. k, K.green, TXT_T)
		line(r, "b" .. k, 0.06, y, "DLP_LFT_B" .. k, K.green, TXT_T)
	end
	-- side view of the trajectory
	U.box(r, "pf", PX0 + PW / 2, PY0 + PH / 2 + 0.02, PW + 0.08, PH + 0.10, MK.dim)
	rect(r .. "_gnd", r, PX0 - 0.02, PY0 - LW * 0.4, PX0 + PW + 0.02, PY0 + LW * 0.4, MK.dim)
	line(r, "pa", PX0, PY0 + PH + 0.025, "DLP_LFT_PA", K.green, TXT_T)
	line(r, "pt", PX0 + PW, PY0 + PH + 0.025, "DLP_LFT_PT", K.green, TXT_T, "RightCenter")
	line(r, "ps", PX0 + PW, PY0 - 0.025, "DLP_LFT_PS", K.grey, TXT_T, "RightCenter")
	for k = 1, 29 do
		local a, b = "DLP_LFT_P" .. k, "DLP_LFT_P" .. (k + 1)
		line_obj(r .. "_arc" .. k, r, MK.grey, 0.005, {a .. "_X", a .. "_Y", b .. "_X", b .. "_Y", b .. "_V"},
			{{"line_object_set_point_using_parameters", 0, 0, 1, G, G},
			 {"line_object_set_point_using_parameters", 1, 2, 3, G, G},
			 vis(4, 0.5, 1.5)})
	end
	line_obj(r .. "_gb", r, MK.green, 0.010, {"DLP_LFT_GB0", "DLP_LFT_TY", "DLP_LFT_TX", "DLP_LFT_TY", "DLP_LFT_GBV"},
		{{"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G},
		 vis(4, 0.5, 1.5)})
	simple(r .. "_own", r, {0, 0, 0}, {"DLP_LFT_OX", "DLP_LFT_OY", "DLP_LFT_OV"},
		{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 1.5)})
	mesh(r .. "_own_s", r .. "_own", "triangles", {{0.03, 0}, {-0.025, 0.018}, {-0.025, -0.018}}, {0, 1, 2}, MK.black)
	simple(r .. "_tg", r, {0, 0, 0}, {"DLP_LFT_TX", "DLP_LFT_TY", "DLP_LFT_TV"},
		{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 1.5)})
	mesh(r .. "_tg_s", r .. "_tg", "triangles", {{0, 0.004}, {0.022, 0.042}, {-0.022, 0.042}}, {0, 1, 2}, MK.red)
	simple(r .. "_ip", r, {0, 0, 0}, {"DLP_LFT_IX", "DLP_LFT_TY", "DLP_LFT_IV"},
		{{"move_left_right_using_parameter", 0, G}, {"move_up_down_using_parameter", 1, G}, vis(2, 0.5, 1.5)})
	mesh(r .. "_ip_x", r .. "_ip", "lines", {{-0.022, -0.022}, {0.022, 0.022}, {-0.022, 0.022}, {0.022, -0.022}}, {0, 1, 2, 3}, MK.black)
end
