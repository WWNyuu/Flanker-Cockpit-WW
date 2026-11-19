-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI (test 3): the SA scope as the MiG-29 MFD add-on's
-- MFI edition draws it (dl_page.lua, MFI rounds 13-27), sized for this
-- screen (SIT_MFI.sa). Loaded by mfd_page.lua with its helpers in S27SC;
-- each part is called where the classic page draws its own, so the order
-- (rings under everything, pointers and heading box on top) stays.
--   rings()      green range ring / arc, ticks, heading numbers, grey rings
--   airfields()  blue discs with a white runway line (S27MFD_M_AF<n>_*)
--   wpt(n)       steerpoint n: grey-green disc, red when active, its number
--   own()        the ownship: black, filled
--   top()        FD arrow to the active steerpoint, heading box on the arc
-- Values: MFD/mfd_mfi_dev.lua (sa_scope), mfd_device.lua (scale, contacts).
-----------------------------------------------------------------------
local D = S27SC
local simple, mesh, text, vis = D.simple, D.mesh, D.text, D.vis
local band, circle_pts, tsize, char_w = D.band, D.circle_pts, D.tsize, D.char_w
local Q = SIT_MFI.sa
local LW = D.LW
local function raw(c, a) return D.col(c[1], c[2], c[3], a or 255, true) end
local I = SIT_MFI.ink
local MM = {arc = raw(SIT_MFI.sa_arc), grey = raw(SIT_MFI.sa_ring), black = raw(I.black), paper = raw(SIT_MFI.paper),
	wpt = raw({150, 172, 145}), wact = raw({222, 60, 48}), af = raw({40, 95, 215}), afw = raw({255, 255, 255}),
	afk = raw({0, 0, 0}), fd = raw({245, 120, 10}), fdv = raw({185, 80, 0})}
local FB = D.fntb or D.fnt
local FG = FB(I.green[1], I.green[2], I.green[3], true)
local FK = D.fnt(I.black[1], I.black[2], I.black[3], true)
local TNUM = tsize(0.040)       -- heading numbers
local TWPT = tsize(0.034)       -- steerpoint numbers
local THDG = tsize(0.052)       -- heading in the box on the arc

S27MFI_SCOPE = {}
local SC = S27MFI_SCOPE

-- a ring of radius r (outer edge), width w, around (0, 0)
local function ring(r, w, n)
	return band(circle_pts(r, n), circle_pts(r - w, n))
end
-- ticks every 5 deg from r0 (out = true: outwards, else inwards)
local function tick_mesh(r0, out)
	local tv, ti = {}, {}
	for deg = 0, 355, 5 do
		local a = math.rad(90 - deg)
		local ca, sa = math.cos(a), math.sin(a)
		local px, py = -sa * LW / 2, ca * LW / 2
		local len = (deg % 30 == 0) and Q.ticks[1] or (deg % 10 == 0) and Q.ticks[2] or Q.ticks[3]
		local r1 = out and r0 + len or r0 - len
		local k = #tv
		tv[k + 1] = {r0 * ca + px, r0 * sa + py}; tv[k + 2] = {r1 * ca + px, r1 * sa + py}
		tv[k + 3] = {r1 * ca - px, r1 * sa - py}; tv[k + 4] = {r0 * ca - px, r0 * sa - py}
		ti[#ti + 1] = k; ti[#ti + 1] = k + 1; ti[#ti + 1] = k + 2
		ti[#ti + 1] = k; ti[#ti + 1] = k + 2; ti[#ti + 1] = k + 3
	end
	return tv, ti
end
local function rect(n, par, x0, y0, x1, y1, m, params, ctrls)
	mesh(n, par, "triangles", {{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, {0, 1, 2, 0, 2, 3}, m, nil, params, ctrls)
end

-- the scope: under everything else, on the ownship frame (sit_own).
-- Hidden in EXP (as the MiG-29's).
function SC.rings()
	simple("mfs", "sit_own", {0, 0, 0}, {"S27MFD_M_EXP"}, {vis(0, -0.5, 0.5)})
	-- jet in the middle: ring = range, ticks inside it, grey 1/4 - 3/4 rings
	simple("mfs_c", "mfs", {0, 0, 0}, {"S27MFD_CENTER"}, {vis(0, 0.5, 1.5)})
	simple("mfs_cr", "mfs_c", {0, 0, 0}, {"S27MFD_ROT"}, {{"rotate_using_parameter", 0, 1}})
	local RC, AW = Q.rc, Q.arc_w
	local v, i = ring(RC + AW, AW, 180)
	mesh("mfs_c_ring", "mfs_c", "triangles", v, i, MM.arc)
	v, i = tick_mesh(RC, false)
	mesh("mfs_c_ticks", "mfs_cr", "triangles", v, i, MM.arc)
	for k = 1, 3 do
		v, i = ring(RC * k / 4 + LW * 0.3, LW * 0.6, 96)
		mesh("mfs_c_rr" .. k, "mfs_c", "triangles", v, i, MM.grey)
	end
	-- decentred: the big arc = range, ticks and numbers outside it (the
	-- parts off the page are under the frame)
	simple("mfs_d", "mfs", {0, 0, 0}, {"S27MFD_CENTER"}, {vis(0, -0.5, 0.5)})
	simple("mfs_dr", "mfs_d", {0, 0, 0}, {"S27MFD_ROT"}, {{"rotate_using_parameter", 0, 1}})
	local R = Q.rd
	for k = 1, 3 do
		v, i = ring(R * k / 4 + LW * 0.3, LW * 0.6, 120)
		mesh("mfs_d_rr" .. k, "mfs_d", "triangles", v, i, MM.grey)
	end
	v, i = ring(R + AW, AW, 240)
	mesh("mfs_d_ring", "mfs_d", "triangles", v, i, MM.arc)
	v, i = tick_mesh(R + AW, true)
	mesh("mfs_d_ticks", "mfs_dr", "triangles", v, i, MM.arc)
	-- heading numbers 00 03 .. 33, each turned to its bearing (tops out of
	-- the arc, as a compass card; the one at the top reads upright). The
	-- turn is fixed: S27MFD_PAGE is exactly 1 (SA) while this shows.
	local rr = R + AW + Q.ticks[1] + Q.num_r * 0.5
	for deg = 0, 330, 30 do
		local a = math.rad(90 - deg)
		local n = "mfs_hn" .. deg
		simple(n, "mfs_dr", {rr * math.cos(a), rr * math.sin(a), 0}, {"S27MFD_PAGE"},
			{{"rotate_using_parameter", 0, -math.rad(deg)}})
		text(n .. "_t", n, {0, 0, 0}, FG, TNUM, "CenterCenter", string.format("%02d", deg / 10))
	end
	-- lubber and beam lines (thin grey)
	rect("mfs_d_lub", "mfs_d", -LW * 0.3, -0.28, LW * 0.3, R, MM.grey)
	rect("mfs_d_beam", "mfs_d", -1.0, -LW * 0.3, 1.0, LW * 0.3, MM.grey)
	rect("mfs_c_lub", "mfs_c", -LW * 0.3, -RC, LW * 0.3, RC, MM.grey)
	rect("mfs_c_beam", "mfs_c", -RC, -LW * 0.3, RC, LW * 0.3, MM.grey)
end

-- airfields (MiG-29 dl_af.lua): blue disc, a white line per runway (up to 3)
function SC.airfields()
	local R, OK = Q.af_r, 0.003
	for n = 1, Q.af_max do
		local b, p = "mfs_af" .. n, "S27MFD_M_AF" .. n .. "_"
		local pp, cc = D.at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
		simple(b, "sit_own", {0, 0, 0}, pp, cc)
		local v, i = ring(R + OK, OK, 24)
		mesh(b .. "_k", b, "triangles", v, i, MM.afk)
		v, i = ring(R, R, 24)
		mesh(b .. "_d", b, "triangles", v, i, MM.af)
		for r = 1, 3 do
			simple(b .. "_r" .. r, b, {0, 0, 0}, {p .. "N", p .. "R" .. r},
				{vis(0, r - 0.5, 9), {"rotate_using_parameter", 1, 1}})
			local hw, hl = 0.0035, R * 1.3
			local kw, kl = hw + OK * 0.8, hl + OK * 0.8
			rect(b .. "_r" .. r .. "_k", b .. "_r" .. r, -kw, -kl, kw, kl, MM.afk)
			rect(b .. "_r" .. r .. "_l", b .. "_r" .. r, -hw, -hl, hw, hl, MM.afw)
		end
	end
end

-- steerpoint n (its group sit_w<n> is made by the page; VIS 1 / 2 = active)
function SC.wpt(n, p)
	local b = "sit_w" .. n
	local R = Q.wpt_r
	local v, i = ring(R, R, 28)
	mesh(b .. "_mf", b, "triangles", v, i, MM.wpt, nil, {p .. "VIS"}, {vis(0, 0.5, 1.5)})
	mesh(b .. "_ma", b, "triangles", v, i, MM.wact, nil, {p .. "VIS"}, {vis(0, 1.5, 2.5)})
	v, i = ring(R, 0.004, 28)
	mesh(b .. "_mr", b, "triangles", v, i, MM.black)
	text(b .. "_mn", b, {0, 0, 0}, FK, TWPT, "CenterCenter", nil, p .. "NUM", nil, "%.0f")
end

-- ear clipping: triangles of a simple polygon (build time only)
local function triangulate(pts)
	local idx, out = {}, {}
	for k = 1, #pts do idx[k] = k - 1 end
	local function P(k) return pts[k + 1] end
	local area = 0
	for k = 1, #pts do local a, b = pts[k], pts[k % #pts + 1]; area = area + a[1] * b[2] - b[1] * a[2] end
	local sgn = area > 0 and 1 or -1
	local function cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
	local function inside(p, a, b, c)
		return sgn * cross(a, b, p) > 0 and sgn * cross(b, c, p) > 0 and sgn * cross(c, a, p) > 0
	end
	local guard = 0
	while #idx > 3 and guard < 500 do
		guard = guard + 1
		local n = #idx
		for k = 1, n do
			local ia, ib, ic = idx[(k - 2) % n + 1], idx[k], idx[k % n + 1]
			local a, b, c = P(ia), P(ib), P(ic)
			if sgn * cross(a, b, c) > 0 then
				local ear = true
				for _, j in ipairs(idx) do
					if j ~= ia and j ~= ib and j ~= ic and inside(P(j), a, b, c) then ear = false; break end
				end
				if ear then
					out[#out + 1] = ia; out[#out + 1] = ib; out[#out + 1] = ic
					table.remove(idx, k)
					break
				end
			end
		end
	end
	if #idx == 3 then out[#out + 1] = idx[1]; out[#out + 1] = idx[2]; out[#out + 1] = idx[3] end
	return out
end
-- the ownship: the classic outline, bigger, filled black (the MiG-29 MFI's
-- ownship is a black aircraft top view)
function SC.own(shape)
	local pts = D.scaled(shape, Q.own_k)
	mesh("mfs_own", "sit_own_r", "triangles", pts, triangulate(pts), MM.black)
end

-- on top: FD arrow on the arc (way to the active steerpoint), its V at the
-- real bearing outside the arc, the heading box on the arc's top
function SC.top()
	local R, RC, AW = Q.rd, Q.rc, Q.arc_w
	simple("mft", "sit_own", {0, 0, 0}, {"S27MFD_M_EXP"}, {vis(0, -0.5, 0.5)})
	-- arrow: a point on the arc (moved along it to stay on the page), turned
	-- there to the steerpoint's direction; tip on the arc, inside it
	local pp, cc = D.at("S27MFD_M_SA_FDX", "S27MFD_M_SA_FDY", {{"S27MFD_M_SA_FDON", 0.5, 1.5}})
	simple("mft_fd", "mft", {0, 0, 0}, pp, cc)
	simple("mft_fdr", "mft_fd", {0, 0, 0}, {"S27MFD_M_SA_FDA"}, {{"rotate_using_parameter", 0, 1}})
	local tp, hb, hw, sw, sb = -0.007, -0.058, Q.fd_w, 0.019, -0.14
	mesh("mft_fd_s", "mft_fdr", "triangles",
		{{0, tp}, {hw, hb}, {-hw, hb}, {sw, hb}, {sw, sb}, {-sw, sb}, {-sw, hb}}, {0, 1, 2, 3, 4, 5, 3, 5, 6}, MM.fd)
	-- V outside the arc at the real bearing (turns about the jet; goes off
	-- the page with it)
	simple("mft_fdv", "mft", {0, 0, 0}, {"S27MFD_M_SA_FDON", "S27MFD_M_SA_FDT"},
		{vis(0, 0.5, 1.5), {"rotate_using_parameter", 1, 1}})
	local vw = Q.fdv_w
	local vh = 0.4 * vw
	for k, rr in ipairs({R + AW, RC + AW}) do
		mesh("mft_fdv" .. k, "mft_fdv", "triangles", {{-vw, rr}, {0, rr}, {-vw, rr + vh}, {vw, rr}, {vw, rr + vh}},
			{0, 1, 2, 1, 3, 4}, MM.fdv, nil, {"S27MFD_CENTER"}, {vis(0, (k == 1) and -0.5 or 0.5, (k == 1) and 0.5 or 1.5)})
	end
	-- heading box on the top of the arc (decentred; centred: the box at the
	-- top of the page): pointed bottom on the arc, a green V under it
	simple("mft_h", "mft", {0, 0, 0}, {"S27MFD_CENTER"}, {vis(0, -0.5, 0.5)})
	local w, s = Q.hdg_w, 0.4
	local yb = R + AW
	local yc, yt = yb + s * w, yb + s * w + Q.hdg_h
	local vt, vx = 0.014, w
	local y0 = yb - vt
	mesh("mft_hv", "mft_h", "triangles",
		{{-vx, y0 + s * vx}, {0, y0}, {vx, y0 + s * vx}, {vx, yb + s * vx}, {0, yb}, {-vx, yb + s * vx}},
		{0, 1, 4, 0, 4, 5, 1, 2, 3, 1, 3, 4}, MM.arc)
	local t = 0.005
	local kk = t * math.sqrt(1 + s * s)
	local out = {{-w, yt}, {w, yt}, {w, yc}, {0, yb}, {-w, yc}}
	local inn = {{-w + t, yt - t}, {w - t, yt - t}, {w - t, yb + kk + s * (w - t)}, {0, yb + kk}, {-w + t, yb + kk + s * (w - t)}}
	mesh("mft_hbg", "mft_h", "triangles", out, {0, 1, 2, 0, 2, 3, 0, 3, 4}, MM.paper)
	local bv, bi = band(out, inn)
	mesh("mft_hbox", "mft_h", "triangles", bv, bi, MM.black)
	local ty, tx = (yc + yt) / 2, -0.012
	text("mft_ht", "mft_h", {tx, ty, 0}, FK, THDG, "CenterCenter", nil, "S27MFD_M_SA_HDG", nil, "%03.0f")
	local dv, di = ring(0.011, 0.004, 12)
	mesh("mft_hdeg", "mft_h", "triangles", dv, di, MM.black, {tx + 1.5 * char_w(THDG) + 0.016, ty + 0.022, 0})
end
