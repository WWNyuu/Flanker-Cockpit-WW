-- Su-27 MFD (WW) 1.3 MFI: the MiG-29 MFD add-on's LOFT ballistics and
-- page values (DL/dl_loft.lua, v1.8.4) with this mod's names (S27_LOFT,
-- S27MFI_CFG, S27_U, S27_PAGES, S27_LOFT_GEO); parameters DLP_LFT_* as in the
-- MiG-29 (page: MFD/indicator/mfd_mfi_loft.lua). Loaded by MFD/mfd_mfi_dev.lua.
-- Vitezovi MiG-29 MFD add-on: LOFT page (v1.8.4, page 17)
--
-- Loft (toss) attack of unguided rockets and bombs on the active
-- steerpoint: steering to it, when to pull up, the climb angle to pull
-- to, SHOOT when a weapon fired NOW would land on the steerpoint (10 times a second), and the
-- trajectory as a side view. Advisory only: nothing goes to the jet.
--
-- Ballistics: point mass in the vertical plane, ISA atmosphere, no wind.
-- The numbers are DCS 2.9.31's own weapon tables, checked on Tacview
-- shots (15 Nov 2026, within 1-3 % of DCS's ranges):
--   * rockets leave along the jet's velocity (flight path angle, not the
--     nose), thrust along the velocity, S-8 drag = DCS's Cx0 table, S-24B
--     drag measured from the shots;
--   * k = drag trim from the shots (model 1.5-2.5 % short without it)
--   * bombs leave with the jet's velocity, constant drag coefficient
--     (FAB-500 measured, the others estimated: "EST" on the page).
-- Runs in the cockpit device (dl_device.lua loads it, dl_pages_dev.lua
-- calls S27_LOFT.update / S27_LOFT.command on page 17); the elements are in
-- dl_pages.lua (root "dlp_lft"), parameters DLP_LFT_*.

S27_LOFT = {}
local L = S27_LOFT
local CFG = S27MFI_CFG or {}

-- drag coefficient (reference area pi d^2 / 4) against Mach -------------
-- S-8: DCS's Cx0 table, Mach 0, 0.2 ... 3.0
local S8_CX = {0.49, 0.49, 0.49, 0.49, 0.52, 0.85, 0.94, 0.89, 0.83, 0.765, 0.72, 0.685, 0.66, 0.63, 0.6, 0.58}
local function cx_s8(m)
	local x = m / 0.2
	local i = math.floor(x)
	if i >= 15 then return S8_CX[16] end
	if i < 0 then return S8_CX[1] end
	return S8_CX[i + 1] + (S8_CX[i + 2] - S8_CX[i + 1]) * (x - i)
end
-- S-24B: measured from the Tacview shots (Mach, Cd)
local S24_M = {0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5}
local S24_C = {0.41, 0.59, 0.71, 0.83, 0.99, 1.12, 1.30}
local function cx_s24(m)
	if m <= S24_M[1] then return S24_C[1] end
	for i = 1, #S24_M - 1 do
		if m <= S24_M[i + 1] then
			return S24_C[i] + (S24_C[i + 1] - S24_C[i]) * (m - S24_M[i]) / (S24_M[i + 1] - S24_M[i])
		end
	end
	return S24_C[#S24_C]
end

-- the weapons (tag = shown on the page, ang = default release climb angle)
-- mass kg, cal m, motor: fuel kg / Isp s / burn s; bombs: cd (constant)
L.W = {
	{id = "S8KOM",  tag = "S-8KOM",   m = 10.75, cal = 0.08,  fuel = 3.6,  isp = 180, tb = 1.55, cx = cx_s8,  k = 0.985, ang = 20, ir = 500},
	{id = "S8OFP2", tag = "S-8OFP2",  m = 16.7,  cal = 0.08,  fuel = 3.6,  isp = 235, tb = 1.55, cx = cx_s8,  k = 0.985, ang = 20, ir = 500},
	{id = "S24B",   tag = "S-24B",    m = 235,   cal = 0.24,  fuel = 51.8, isp = 170, tb = 1.3,  cx = cx_s24, k = 0.92, ang = 20, win = 50},
	{id = "FAB500", tag = "FAB-500",  m = 499,   cal = 0.40,  cd = 0.14, ang = 25, win = 50},
	{id = "FAB250", tag = "FAB-250",  m = 227,   cal = 0.30,  cd = 0.18, ang = 25, est = true, win = 50},
	{id = "OFAB",   tag = "OFAB-250", m = 266,   cal = 0.325, cd = 0.22, ang = 25, est = true, win = 50},
	{id = "BETAB",  tag = "BETAB-500", m = 476,  cal = 0.35,  cd = 0.20, ang = 25, est = true, win = 50},
	{id = "RBK250", tag = "RBK-250",  m = 260,   cal = 0.325, cd = 0.18, ang = 25, est = true, ir = 500},
	{id = "RBK500", tag = "RBK-500",  m = 427,   cal = 0.40,  cd = 0.17, ang = 25, est = true, ir = 500},
	{id = "RBK500L", tag = "RBK-500-255", m = 253, cal = 0.40, cd = 0.17, ang = 25, est = true, ir = 500},
}
local BY_ID = {}
for i, w in ipairs(L.W) do BY_ID[w.id] = i end

-- store name (as the export sends it, upper case) -> weapon index, or nil
function L.weapon_of(nm)
	nm = string.upper(tostring(nm or ""))
	if nm == "" then return nil end
	local function has(s) return nm:find(s, 1, true) ~= nil end
	if has("KMGU") or has("SHP") or has("SMOKE") then return nil end
	if has("S-24") or has("C_24") or has("S24") then return BY_ID.S24B end
	if has("OFP") then return BY_ID.S8OFP2 end
	if has("S-8") or has("C_8") or has("B-8") or has("B8M1") then return BY_ID.S8KOM end
	if has("OFAB") then return BY_ID.OFAB end
	if has("BETAB") then return BY_ID.BETAB end
	if has("RBK") and has("500") then return (has("255") or has("PTAB-10")) and BY_ID.RBK500L or BY_ID.RBK500 end
	if has("RBK") then return BY_ID.RBK250 end
	if has("FAB-500") or has("FAB_500") then return BY_ID.FAB500 end
	if has("FAB-250") or has("FAB_250") then return BY_ID.FAB250 end
	return nil
end

-- ISA (troposphere, held above 11 km): density kg/m3, speed of sound m/s
local function isa(h)
	if h > 11000 then h = 11000 elseif h < -500 then h = -500 end
	local T = 288.15 - 0.0065 * h
	return 1.225 * (T / 288.15) ^ 4.2559, 20.0468 * math.sqrt(T)
end

-- Fly one weapon. v = speed m/s, gam = flight path angle (rad), h0 = height
-- above sea level, hend = height of the ground at the target. Midpoint
-- steps: 0.05 s while the motor burns, then dt_coast. Returns range (m,
-- horizontal), time of flight, apex (m above sea level) and, when pts is a
-- table, every k-th point {x, h} in it. Nil when it never comes down.
local G0 = 9.80665
function L.fly(w, v, gam, h0, hend, pts, dt_coast)
	dt_coast = dt_coast or 0.25
	local S = math.pi * w.cal * w.cal / 4
	local mdot = (w.fuel and w.tb and w.tb > 0) and (w.fuel / w.tb) or 0
	local thr = mdot * (w.isp or 0) * G0
	local x, h = 0, h0
	local vx, vh = v * math.cos(gam), v * math.sin(gam)
	local t, apex = 0, h0
	local cxf, cd = w.cx, w.cd
	local kx = w.k or 1
	local function acc(tt, hh, ax_vx, ax_vh)
		local sp = math.sqrt(ax_vx * ax_vx + ax_vh * ax_vh)
		if sp < 1 then sp = 1 end
		local rho, a = isa(hh)
		local m = w.m - mdot * math.min(tt, w.tb or 0)
		local c = (cxf and cxf(sp / a) or cd) * kx
		local d = 0.5 * rho * sp * sp * S * c
		local f = ((tt < (w.tb or 0)) and thr or 0) - d
		return f * ax_vx / sp / m, f * ax_vh / sp / m - G0
	end
	if pts then pts[1] = {0, h0} end
	local n = 0
	while t < 150 do
		local dt = (t < (w.tb or 0)) and 0.05 or dt_coast
		local ax, ah = acc(t, h, vx, vh)
		local mx, mh = vx + ax * dt / 2, vh + ah * dt / 2
		local bx, bh = acc(t + dt / 2, h + vh * dt / 2, mx, mh)
		local nx, nh = x + mx * dt, h + mh * dt
		local nvx, nvh = vx + bx * dt, vh + bh * dt
		if nh <= hend and nvh < 0 then
			-- impact between the two steps
			local f = (h - hend) / math.max(h - nh, 1e-6)
			x = x + (nx - x) * f; t = t + dt * f; h = hend
			if pts then pts[#pts + 1] = {x, h} end
			return x, t, apex
		end
		x, h, vx, vh, t = nx, nh, nvx, nvh, t + dt
		if h > apex then apex = h end
		n = n + 1
		if pts and n % 2 == 0 then pts[#pts + 1] = {x, h} end
	end
	return nil
end

-----------------------------------------------------------------------
-- page state and parameters
-----------------------------------------------------------------------
local S = {wsel = nil, ang = nil, ang_w = nil, last = nil, v = nil, plan_t = -1, now_t = -1,
           plan = nil, now = nil, pts = {}, ter = nil}
L.S = S
L.NPTS = 30
local H = nil
local function P(n)
	local h = get_param_handle(n)
	local last = nil
	return {set = function(_, v) if v ~= last then last = v; h:set(v) end end}
end
-- texts: never empty, never a bare number (see dl_pages_dev T())
local function T(h, s)
	s = tostring(s or "")
	s = s:gsub("[^\32-\126]", "?")
	if s:find("nan") or s:find("inf") then s = "--" end
	if s == "" then s = " " elseif tonumber(s) then s = s .. " -" end
	h:set(s)
end
local function handles()
	if H then return H end
	H = {}
	for _, n in ipairs({"WPN", "WPN2", "TGT", "TRNG", "STEER", "CUET", "SUB", "RSC", "RCT", "A1", "A2", "A3", "B1", "B2", "B3",
	                    "PA", "PT", "PS"}) do H[n] = P("DLP_LFT_" .. n) end
	for _, n in ipairs({"SX", "SV", "DX", "DV", "PY", "PV", "AY", "AV", "CUE", "ZV", "IB0", "IB1", "IBX", "IBV", "GB0", "GBV", "MXY", "OPY", "MNY", "RY", "MXV", "MNV", "LY", "LRY", "LRV", "L0V", "L5V", "L10V", "L15V", "L20V", "L25V", "L30V", "L35V", "L40V", "L45V", "OX", "OY", "OV", "TX", "TY", "TV", "IX", "IV", "GV"}) do
		H[n] = P("DLP_LFT_" .. n)
	end
	H.px, H.py, H.pv = {}, {}, {}
	for k = 1, L.NPTS do
		H.px[k] = P("DLP_LFT_P" .. k .. "_X"); H.py[k] = P("DLP_LFT_P" .. k .. "_Y"); H.pv[k] = P("DLP_LFT_P" .. k .. "_V")
	end
	return H
end

-- page geometry (page units, shared with dl_pages.lua through S27_LOFT_GEO)
local GEO = S27_LOFT_GEO or {}
local PSY0, PSH, PSMAX = GEO.pitch_y0 or 0.12, GEO.pitch_h or 0.74, GEO.pitch_max or 45
local PX0, PY0, PW, PH = GEO.prof_x0 or -0.68, GEO.prof_y0 or -1.02, GEO.prof_w or 1.36, GEO.prof_h or 0.52
local STEER_K = GEO.steer_k or 0.012           -- page units per degree of steering error
local TAPE_K = CFG.hdg_tape_scale or 0.0165

-- ground height at a point (terrain module), else nil
local TER = nil
local function ground_at(x, z)
	if TER == nil then
		local ok, t = pcall(require, "terrain")
		TER = (ok and type(t) == "table" and t.GetHeight) and t or false
	end
	if not TER then return nil end
	local ok, hgt = pcall(TER.GetHeight, x, z)
	hgt = ok and tonumber(hgt) or nil
	if hgt and hgt == hgt and hgt > -500 and hgt < 9000 then return hgt end
	return nil
end

-- jet velocity: sensor data if it has it, else from the position change
local function velocity(C)
	local sd = C.sd
	if sd and sd.getSelfVelocity then
		local ok, vx, vy, vz = pcall(sd.getSelfVelocity)
		if ok and type(vx) == "table" then vx, vy, vz = vx.x, vx.y, vx.z end
		vx, vy, vz = tonumber(vx), tonumber(vy), tonumber(vz)
		if vx and vy and vz and vx == vx and (vx ~= 0 or vy ~= 0 or vz ~= 0) then return vx, vy, vz, "SD" end
	end
	-- difference over >= 0.5 s
	local t = C.t or 0
	local p = S.last
	if not p or t - p.t > 3 or t < p.t then S.last = {t = t, x = C.ox, y = C.alt, z = C.oz}; return nil end
	if t - p.t >= 0.5 then
		local dt = t - p.t
		S.v = {(C.ox - p.x) / dt, (C.alt - p.y) / dt, (C.oz - p.z) / dt}
		S.last = {t = t, x = C.ox, y = C.alt, z = C.oz}
	end
	if S.v then return S.v[1], S.v[2], S.v[3], "POS" end
	return nil
end

-- selected weapon: the store on the selected stations (SMS logic), or the
-- one picked with WPN
local function weapon(C)
	local nm, cnt = nil, 0
	if S27_PAGES and S27_PAGES.sel_store then nm, cnt = S27_PAGES.sel_store(C) end
	local auto = nm and L.weapon_of(nm) or nil
	local i = S.wsel or auto
	return i and L.W[i] or nil, nm, cnt, auto
end

local function fmt_dist(m, C)
	local u, l = C.unit_m or 1000, C.unit_lbl or "KM"
	local v = m / u
	if math.abs(v) < 100 then return string.format("%.1f%s", v, l) end
	return string.format("%d%s", math.floor(v + 0.5), l)
end
-- a miss distance: metres (feet with imperial altitudes)
local function fmt_miss(m)
	local v, l = S27_U.alt(math.abs(m))
	return string.format("%d%s", math.floor(v / 10 + 0.5) * 10, l)
end
local RBX = GEO.rbar_x or -0.60                 -- range bar x (dl_pages.lua)
local NICE = {2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40}
local function mmss(s)
	s = math.max(0, math.floor(s + 0.5))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function L.command(b, C)
	if b == "M1" and C.stp_step then C.stp_step(1); return true end
	if b == "M2" and C.stp_step then C.stp_step(-1); return true end
	if b == "M3" then
		-- WPN: AUTO (from the selected stations) -> each weapon -> AUTO
		local n = #L.W
		if S.wsel == nil then S.wsel = 1 elseif S.wsel >= n then S.wsel = nil else S.wsel = S.wsel + 1 end
		S.plan_t, S.now_t = -1, -1
		return true
	end
	local w = weapon(C)
	if not w then return true end
	if S.ang_w ~= w.id then S.ang, S.ang_w = w.ang, w.id end
	if b == "R1" then S.ang = math.min(45, S.ang + 1)
	elseif b == "R2" then S.ang = math.max(5, S.ang - 1)
	elseif b == "R3" then S.ang = w.ang end
	S.plan_t = -1
	return true
end

-- the trajectory picture: own jet at x = 0 (h0), points in pts relative to
-- x0 (where the weapon leaves), target at R
local function draw_profile(h, C, pts, x0, R, h0, hend, apex, imp, ir)
	local xmax = math.max(R, x0 + (imp or 0), 1000) * 1.12
	-- a round scale in the range unit
	local u = C.unit_m or 1000
	local steps = {2, 4, 6, 8, 10, 12, 15, 20, 25, 30, 40, 60}
	local sc = steps[#steps]
	for _, s in ipairs(steps) do if s * u >= xmax then sc = s; break end end
	xmax = sc * u
	local hb = math.min(hend, h0)
	local hmax = math.max(apex or h0, h0) - hb
	hmax = math.max(hmax * 1.15, 500)
	local function sx(x) return PX0 + x / xmax * PW end
	local function sy(alt) return PY0 + (alt - hb) / hmax * PH end
	T(h.PS, string.format("%d%s", sc, C.unit_lbl or "KM"))
	h.OX:set(sx(0)); h.OY:set(sy(h0)); h.OV:set(1)
	h.TX:set(sx(math.min(R, xmax))); h.TY:set(sy(hend)); h.TV:set(1)
	if ir then h.GB0:set(sx(math.max(0, math.min(R, xmax) - ir))); h.GBV:set(1) else h.GBV:set(0) end
	local n = #pts
	local step = math.max(1, n / L.NPTS)
	local k = 0
	local fi = 1
	while k < L.NPTS do
		k = k + 1
		local p = pts[math.min(n, math.floor(fi + 0.5))]
		if p and fi <= n + step * 0.5 then
			h.px[k]:set(sx(x0 + p[1])); h.py[k]:set(sy(p[2])); h.pv[k]:set(1)
		else
			-- unused: on the last point, hidden
			local q = pts[n]
			if q then h.px[k]:set(sx(x0 + q[1])); h.py[k]:set(sy(q[2])) end
			h.pv[k]:set(0)
		end
		fi = fi + step
	end
	if imp then h.IX:set(sx(x0 + imp)); h.IV:set(1) else h.IV:set(0) end
end

local function hide_profile(h)
	for k = 1, L.NPTS do h.pv[k]:set(0) end
	h.OV:set(0); h.TV:set(0); h.IV:set(0); h.GBV:set(0)
	T(h.PA, " "); T(h.PT, " "); T(h.PS, " ")
end

function L.update(C)
	local h = handles()
	local t = C.t or 0
	local w, nm, cnt, auto = weapon(C)
	-- weapon line
	if w then
		T(h.WPN, w.tag .. ((cnt and cnt > 0 and auto == BY_ID[w.id]) and (" X" .. cnt) or ""))
		T(h.WPN2, (S.wsel and "MANUAL" or "AUTO") .. (w.est and "  EST" or ""))
	else
		T(h.WPN, nm and ("NO LOFT DATA") or "NO WEAPON")
		T(h.WPN2, nm and string.upper(nm):sub(1, 14) or (S.wsel and "MANUAL" or "AUTO"))
	end
	if w and S.ang_w ~= w.id then S.ang, S.ang_w = w.ang, w.id end
	local ang = S.ang or 20
	-- target: the active steerpoint
	local a = C.act
	local vx, vy, vz = velocity(C)
	local function blank(cue, sub)
		h.CUE:set(4); h.ZV:set(0); h.IBV:set(0); T(h.CUET, cue); T(h.SUB, sub or " ")
		for p = 0, 45, 5 do h["L" .. p .. "V"]:set(0) end
		h.LRV:set(0)
		T(h.STEER, " "); h.SV:set(0); h.DV:set(0)
		for _, k in ipairs({"A1", "A2", "A3", "B1", "B2", "B3"}) do T(h[k], " ") end
		hide_profile(h)
	end
	if not a or not a.x or not a.z or not C.ox then
		T(h.TGT, "NO STP"); T(h.TRNG, " ")
		h.PV:set(0); h.AV:set(0)
		return blank("NO STEERPOINT", "SELECT ONE: W+ / W-")
	end
	local dx, dz = a.x - C.ox, a.z - C.oz
	local R = math.sqrt(dx * dx + dz * dz)
	T(h.TGT, (a.lbl and tostring(a.lbl) ~= "") and string.upper(tostring(a.lbl)):sub(1, 8) or "STP")
	T(h.TRNG, fmt_dist(R, C))
	-- heading tape diamond: bearing to the target against the nose
	local brg = math.atan2(dz, dx)
	local hdg = C.hdg or 0
	local dn = (math.deg(brg - hdg) + 540) % 360 - 180
	h.DX:set(math.max(-25, math.min(25, dn)) * TAPE_K); h.DV:set(math.abs(dn) > 25 and 2 or 1)
	L.diff = dn
	if not vx then
		h.PV:set(0); h.AV:set(0)
		return blank("MEASURING", "WAIT FOR SPEED")
	end
	local gs = math.sqrt(vx * vx + vz * vz)
	local V = math.sqrt(gs * gs + vy * vy)
	local gam = math.atan2(vy, gs)
	local fpa = math.deg(gam)
	-- steering on the ground track (wind included)
	local trk = math.atan2(vz, vx)
	local se = (math.deg(brg - trk) + 540) % 360 - 180
	h.SX:set(math.max(-20, math.min(20, se)) * STEER_K); h.SV:set(1)
	if math.abs(se) < 1 then T(h.STEER, "ON COURSE")
	else T(h.STEER, string.format("STEER %s %d", se < 0 and "L" or "R", math.floor(math.abs(se) + 0.5))) end
	-- climb angle scale: current flight path angle and the release angle
	h.PY:set(math.max(-0.04, math.min(PSH + 0.03, fpa / PSMAX * PSH))); h.PV:set(1)
	h.AY:set(ang / PSMAX * PSH); h.AV:set(w and 1 or 0)
	-- pitch ladder around the jet reference
	do
		local K, WIN = GEO.ladder_k or 0.024, GEO.ladder_win or 0.21
		h.LY:set(-fpa * K)
		for p = 0, 45, 5 do h["L" .. p .. "V"]:set(math.abs((p - fpa) * K) <= WIN and 1 or 0) end
		local d = (ang - fpa) * K
		h.LRY:set(math.max(-WIN, math.min(WIN, d))); h.LRV:set(w and 1 or 0)
	end
	if not w then return blank(nm and "NO LOFT DATA" or "NO WEAPON", "WPN: PICK ONE BY HAND") end
	-- ground at the target
	if not S.ter or S.ter.x ~= a.x or S.ter.z ~= a.z then
		S.ter = {x = a.x, z = a.z, h = ground_at(a.x, a.z)}
	end
	local hend = S.ter.h or (tonumber(a.y) or 0)
	local h0 = C.alt or 0
	if V < 60 or h0 < hend then return blank("TOO SLOW", " ") end
	-- pull-up: a steady 4 g pull (CFG.loft_pull_g; CFG.loft_pull_dps forces
	-- a fixed rate): turn rate = (n - cos fpa) g / V, about 6.7 deg/s at
	-- 250 m/s. pull_of(a): time, ground covered and height gained from the
	-- current angle up to angle a (the release happens that much higher)
	local rate = CFG.loft_pull_dps or
		math.deg(((CFG.loft_pull_g or 4) - math.cos(math.rad(fpa))) * 9.80665 / math.max(V, 60))
	local function pull_of(a)
		local tp = math.max(0, a - fpa) / rate
		local mid = math.rad((a + fpa) / 2)
		return tp, gs * tp * math.cos(mid), V * tp * math.max(0, math.sin(mid))
	end
	-- the solution at the release angle: once a second (from the current
	-- speed and height); a weapon fired now: 10 times a second
	if t - S.plan_t >= 1 or t < S.plan_t or not S.plan or S.plan.w ~= w.id or S.plan.ang ~= ang then
		S.plan_t = t
		local pts = {}
		local _, _, dh = pull_of(ang)
		local r, tof, ap = L.fly(w, V, math.rad(ang), h0 + dh, hend, pts)
		local rl = L.fly(w, V, math.max(gam, 0), h0, hend)
		local rx = 0
		for _, ta in ipairs({30, 38, 45}) do
			local _, _, dhx = pull_of(ta)
			local rr = L.fly(w, V, math.rad(ta), h0 + dhx, hend)
			if rr and rr > rx then rx = rr end
		end
		S.plan = {w = w.id, ang = ang, r = r, tof = tof, apex = ap, pts = pts, rl = rl, rmax = rx}
	end
	if t - S.now_t >= 0.1 or t < S.now_t or not S.now then
		S.now_t = t
		local pts = {}
		local r, tof, ap = L.fly(w, V, gam, h0, hend, pts)
		local old = S.now
		local rd = 0
		if old and old.r and r and old.t and t > old.t and t - old.t < 1 then rd = (r - old.r) / (t - old.t) end
		S.now = {r = r, tof = tof, apex = ap, pts = pts, t = t, rd = rd,
			dtu = (old and old.t and t > old.t and t - old.t < 1) and (t - old.t) or 0.1}
	end
	local pl, nw = S.plan, S.now
	local dang = ang - fpa
	local tpull, dpull = pull_of(ang)
	-- range bar: MIN = level shot, OPT = start of the pull for the set
	-- angle, MAX = best angle with a 45 deg pull; scale = next round value
	if pl.r and pl.rl and pl.rmax then
		local _, d45 = pull_of(45)
		local rmn, rop, rmx = pl.rl, pl.r + dpull, math.max(pl.rmax + d45, pl.r + dpull)
		local u = C.unit_m or 1000
		local top = NICE[#NICE]
		for _, v in ipairs(NICE) do if v * u >= rmx * 1.15 then top = v; break end end
		local function ry(m) return math.max(0, math.min(1, m / (top * u))) * PSH end
		h.MXY:set(ry(rmx)); h.OPY:set(ry(rop)); h.MNY:set(ry(rmn)); h.RY:set(ry(R))
		h.MXV:set(math.abs(ry(rmx) - ry(rop)) > 0.07 and 1 or 0)
		h.MNV:set(math.abs(ry(rmn) - ry(rop)) > 0.07 and 1 or 0)
		T(h.RSC, string.format("%d%s", top, C.unit_lbl or "KM")); T(h.RCT, fmt_dist(R, C))
		h.ZV:set(1)
		local irb = w.ir and (CFG.loft_inrng_m or w.ir)
		if irb then
			h.IBX:set(RBX + 0.012); h.IB0:set(PSY0 + ry(rop)); h.IB1:set(PSY0 + ry(rop + irb)); h.IBV:set(1)
		else h.IBV:set(0) end
	else
		h.ZV:set(0); h.IBV:set(0)
	end
	-- SHOOT window: from a little short (the pilot's reaction time while
	-- the pull is still adding range) to tol long
	-- precise weapons (bombs, S-24B: w.win) get a fixed +-w.win window
	local tol = w.win or math.max(CFG.loft_tol_m or 150, R * 0.015)
	local early = w.win or math.max(CFG.loft_early_m or 60, R * 0.006)
	-- ripple weapons (S-8 pods, RBK: w.ir) get IN RNG up to w.ir short
	local ir = w.ir and (CFG.loft_inrng_m or w.ir) or nil
	local cue, sub, kind = " ", " ", 1
	local shown = "plan"
	-- optional lead (CFG.loft_lead_s, off): SHOOT already when the shot is
	-- due inside the window within that time
	local lead = CFG.loft_lead_s or 0
	local ahead = nw.r and (nw.r + math.max(0, nw.rd or 0) * lead + gs * lead) or nil
	-- SHOOT stays up at least 0.4 s, and also comes up when one update
	-- jumped across the whole window (a soft pull with the S-24B sweeps
	-- 250 m in a tenth of a second); it drops once the shot is 3 x tol long
	local inwin = nw.r and fpa > -3 and nw.r <= R + tol and (nw.r >= R - early or (ahead and ahead >= R - early))
	-- a fast pull can carry the next solution right over the window: if
	-- the next update is predicted to land further past the window than
	-- this one is short of it, SHOOT now
	if not inwin and nw.r and fpa > -3 and nw.r < R - early and (nw.rd or 0) > 0 then
		local dtu = nw.dtu or 0.1
		local nxt = nw.r + nw.rd * dtu + gs * dtu
		if nxt > R + tol and (R - nw.r) <= (nxt - R) then inwin = true end
	end
	if nw ~= S.win_nw then
		-- a new solution: did it jump from short straight to long?
		if S.win_short and nw.r and nw.r > R + tol then S.shoot_until = t + 0.4 end
		S.win_short = nw.r and nw.r < R - early or false
		S.win_nw = nw
	end
	if inwin then S.shoot_until = t + 0.4 end
	if not inwin and S.shoot_until and t <= S.shoot_until and t >= S.shoot_until - 1 and nw.r
		and nw.r <= R + (w.win and 2 or 3) * tol and nw.r >= R - early and fpa > -3 then inwin = true end
	if inwin then
		cue, kind, shown = "SHOOT", 3, "now"
		sub = string.format("%s %s", fmt_miss(nw.r - R), nw.r < R and "SHORT" or "LONG")
	elseif nw.r and nw.r > R + tol then
		-- a weapon fired now would fly past the target
		shown = "now"
		if dang > 3 then cue, kind, sub = "INSIDE LOFT", 4, "SHOOT LEVEL OR GO AROUND"
		else cue, kind, sub = "PAST RELEASE", 4, string.format("%s LONG", fmt_miss(nw.r - R)) end
	elseif dang <= 3 then
		-- at (or above) the release angle, still short: hold it
		shown = "now"
		cue, kind = "HOLD " .. ang, 2
		sub = nw.r and string.format("%s SHORT", fmt_miss(R - nw.r)) or "NO SOLUTION"
		if ir and nw.r and nw.r >= R - early - ir then
			-- close enough to start a ripple: it walks through the target
			local secs = (R - early - nw.r) / math.max(gs + math.max(0, nw.rd or 0), 50)
			cue, kind = "IN RNG", 5
			sub = (secs >= 1) and string.format("%s SHORT  SHOOT IN %dS", fmt_miss(R - nw.r), math.floor(secs + 0.5))
				or string.format("%s SHORT", fmt_miss(R - nw.r))
		end
	elseif pl.r then
		local rpull = pl.r + dpull
		local togo = R - rpull
		if togo > 0 then
			local secs = togo / math.max(gs, 50)
			if R > (pl.rmax or 0) + dpull + 200 and secs > 60 then
				cue, kind = "OUT OF RANGE", 4
				sub = string.format("MAX %s", fmt_dist((pl.rmax or 0) + dpull, C))
			else
				cue, kind = "PULL IN " .. mmss(secs), 1
				sub = string.format("PULL TO %d DEG AT %s", ang, fmt_dist(rpull, C))
			end
		else
			cue, kind = "PULL", 2
			sub = string.format("%d DEG TO GO", math.floor(dang + 0.5))
		end
	else
		cue, kind, sub = "NO SOLUTION", 4, " "
	end
	h.CUE:set(kind); T(h.CUET, cue); T(h.SUB, sub)
	-- readouts
	local sv, sl = S27_U.spd(gs)
	local av, al = S27_U.alt(h0 - hend)
	local use = (shown == "now") and nw or pl
	T(h.A1, "RNG " .. fmt_dist(R, C))
	T(h.A2, string.format("GS %d%s", math.floor(sv + 0.5), sl))
	T(h.A3, string.format("FPA %d / %d", math.floor(fpa + 0.5), ang))
	T(h.B1, use.tof and string.format("TOF %dS", math.floor(use.tof + 0.5)) or "TOF --")
	T(h.B2, string.format("HT %d%s", math.floor(av / 10 + 0.5) * 10, al))
	T(h.B3, (pl.rl and pl.rmax) and string.format("LVL %s MAX %s", fmt_dist(pl.rl, C), fmt_dist(pl.rmax, C)) or "LVL -- MAX --")
	-- side view
	if use.r and use.pts and #use.pts > 1 then
		local x0 = (shown == "now") and 0 or math.max(0, R - use.r)
		draw_profile(h, C, use.pts, x0, R, h0, hend, use.apex, use.r, ir)
		local apv, apl = S27_U.alt(use.apex or h0)
		T(h.PA, string.format("APEX %d%s", math.floor(apv / 10 + 0.5) * 10, apl))
		T(h.PT, use.tof and string.format("TOF %dS", math.floor(use.tof + 0.5)) or " ")
	else
		hide_profile(h)
	end
end
