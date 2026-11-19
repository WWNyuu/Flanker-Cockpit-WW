-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: PFD values and ALT MAX / MIN - the MiG-29 MFD
-- add-on's DL/dl_pfd_dev.lua (round 24) with this mod's names
-- (S27MFD_PFD_*, texts S27MFD_M_PFD_*; S27_PFD, S27MFI_CFG, S27_U).
-- Loaded by MFD/mfd_mfi_dev.lua.
-----------------------------------------------------------------------
S27_PFD_TEXT = {SL = true, SU = true, AL = true, AU = true, BL = true, BR = true, LIM1 = true, LIM2 = true, WIND = true,
	FM1 = true, FM2 = true, FM3 = true}
-----------------------------------------------------------------------
-- MiG-29 DL add-on: flight instruments (PFD) and the barometric altitude
-- limits ALT MAX / ALT MIN - device side (round 21, 18 Nov 2026)
--
-- S27_PFD.st     state (keys and UFCP entries in dl_pages_dev.lua):
--   fd        flight director on; fd_alt = altitude it holds (m)
--   tas       speed tape shows TAS (false = IAS)
--   ralt      altitude tape shows the radar altitude (false = barometric)
--   vsi       VSI scale shown
--   amx, amn  ALT MAX / ALT MIN in metres (nil = off)
-- S27_PFD.update(C, S, geo)  page values (S = {hdg_bug = deg})
-- S27_PFD.check(C)           ALT MAX / MIN warning, every frame, every page
-- Elements: dl_pfd.lua, layout: dl_pfd_geo.lua.
-----------------------------------------------------------------------
S27_PFD = {st = {fd = false, tas = false, ralt = false, vsi = true}}
local CFG = S27MFI_CFG or {}
local H = nil
local W = {mx_armed = false, mn_armed = false, t = -100, txt = nil}
local WIND = {n = 0, e = 0, ok = false}

local function fin(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
local function num(sd, f)
	if not sd or not sd[f] then return nil end
	local ok, v = pcall(sd[f])
	v = ok and tonumber(v) or nil
	return fin(v) and v or nil
end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end

local function handles()
	if H then return H end
	H = {}
	local function P(n)
		local h = get_param_handle(n)
		local last = nil
		return {set = function(_, v) if v ~= last then last = v; h:set(v) end end}
	end
	for _, n in ipairs({"ON", "ONE", "IMP", "ST", "SV", "AT", "AV", "PY", "BANK", "FDX", "FDY", "FDON", "FPX", "FPY", "FPON",
		"VSION", "VSA", "VSV", "HDG", "HDGV", "BUG", "AMXY", "AMXON", "AMNY", "AMNON", "RSRC",
		"SL", "SU", "AL", "AU", "BL", "BR", "VSS", "LIM", "TASON", "LIM1", "LIM2", "WIND", "FM1", "FM2", "FM3"}) do
		H[n] = P((S27_PFD_TEXT[n] and "S27MFD_M_PFD_" or "S27MFD_PFD_") .. n)
	end
	H.SN, H.AN = {}, {}
	for j = 0, 20 do H.SN[j] = P("S27MFD_PFD_SN" .. j); H.AN[j] = P("S27MFD_PFD_AN" .. j) end
	H.wshow = P("S27MFD_PFD_ALTW_SHOW")
	return H
end
S27_PFD.handles = handles

local function imperial() return CFG.alt_units == "kft" end
local function alt_u(m) return imperial() and m * 3.28084 or m end
-- typed number (m, ft in imperial) -> metres; 0 = off
function S27_PFD.alt_in(v)
	if not v or v <= 0 then return nil end
	return imperial() and v / 3.28084 or v
end

-- a moving tape: scale offset + the numbers round the value
local function tape(hT, hN, v, step, k, n)
	n = n or 3
	local base = math.floor(v / step)
	hT:set((v - base * step) * k)
	for j = 0, 2 * n do hN[j]:set((base + j - n) * step) end
end

-- wind = ground velocity minus air velocity (TAS along the heading, no
-- sideslip), smoothed; nil while slow or on the ground
local function wind(sd, hdg, tas, pitch, t)
	local ok, vx, _, vz = pcall(sd.getSelfVelocity)
	if not ok or not tonumber(vx) or not tonumber(vz) or not tas or tas < 50 or not hdg then WIND.ok = false; return nil end
	local th = tas * math.cos(pitch or 0)
	local wn, we = vx - th * math.cos(hdg), vz - th * math.sin(hdg)
	-- (round 24: by time, the page now updates up to 60 times a second; 0.05 a step at 20 a second)
	local dt = (t and WIND.t) and math.max(0, math.min(1, t - WIND.t)) or 0.05
	WIND.t = t
	local a = 1 - math.exp(-dt)
	if not WIND.ok then WIND.n, WIND.e, WIND.ok = wn, we, true
	else WIND.n, WIND.e = WIND.n + (wn - WIND.n) * a, WIND.e + (we - WIND.e) * a end
	local sp = math.sqrt(WIND.n ^ 2 + WIND.e ^ 2)
	local from = (math.deg(math.atan2(-WIND.e, -WIND.n)) + 360) % 360
	return from, sp
end

function S27_PFD.update(C, S, L)
	local h = handles()
	local st = S27_PFD.st
	local sd = C.sd
	if not sd or not L then h.ON:set(0); return end
	local imp = imperial()
	h.ON:set(1); h.ONE:set(1); h.IMP:set(imp and 1 or 0)
	local pitch = num(sd, "getPitch") or 0
	local roll = (num(sd, "getRoll") or 0) * (CFG.pfd_roll_sign or 1)
	local ias = num(sd, "getIndicatedAirSpeed") or 0
	local tas = num(sd, "getTrueAirSpeed") or 0
	local mach = num(sd, "getMachNumber")
	local baro = num(sd, "getBarometricAltitude") or (C.alt or 0)
	local ra = num(sd, "getRadarAltitude")
	local vs = num(sd, "getVerticalVelocity") or 0
	local hdg = fin(C.hdg) and C.hdg or 0
	-- attitude
	h.PY:set(math.deg(pitch) * (L.ppd or 0.032))
	h.BANK:set(roll)
	-- round 24: flight path marker (flight path angle and drift, degrees x ppd)
	do
		local ok, vx, vy, vz = pcall(sd.getSelfVelocity)
		local gs = ok and tonumber(vx) and tonumber(vz) and math.sqrt(vx * vx + vz * vz) or 0
		if gs > 20 and tonumber(vy) then
			local ppd = L.ppd or 0.032
			local gam = math.deg(math.atan2(vy, gs))
			local dr = math.deg(math.atan2(vz, vx) - hdg)
			dr = (dr + 540) % 360 - 180
			local lim = L.fpm_lim or 18
			h.FPX:set(math.max(-lim, math.min(lim, dr)) * ppd); h.FPY:set(gam * ppd); h.FPON:set(1)
		else
			h.FPON:set(0)
		end
	end
	-- speed tape (km/h or kt)
	local spd_ms = st.tas and tas or ias
	local sv, sl = S27_U.spd(spd_ms)
	tape(h.ST, h.SN, sv, L.spd_step or 50, L.spd_k, L.spd_n)
	h.SV:set(math.floor(sv + 0.5))
	h.SL:set(mach and string.format("M%.2f", mach):gsub("M0%.", "M.") or "M ---")
	h.SU:set((st.tas and "TAS " or "IAS ") .. sl)
	local gsv = nil
	do
		local ok, vx, _, vz = pcall(sd.getSelfVelocity)
		if ok and tonumber(vx) and tonumber(vz) then gsv = math.sqrt(vx * vx + vz * vz) end
	end
	h.BL:set(gsv and string.format("GS %d", math.floor(S27_U.spd(gsv) + 0.5)) or "GS ---")
	-- altitude tape (m or ft): barometric, or radar while RALT is on
	local ra_ok = ra and ra < (CFG.pfd_ralt_max_m or 1500)
	local use_ra = st.ralt and ra_ok
	local am = use_ra and ra or baro
	local av = alt_u(am)
	local ak = imp and L.alt_kft or L.alt_k
	tape(h.AT, h.AN, av, imp and (L.alt_step_ft or 500) or (L.alt_step or 200), ak, L.alt_n)
	h.AV:set(math.floor(av / (imp and 20 or 10) + 0.5) * (imp and 20 or 10))
	h.RSRC:set(st.ralt and 1 or 0)
	h.AU:set(imp and "FT" or "M")
	if use_ra then
		h.AL:set(string.format("BARO %d", math.floor(alt_u(baro) / 10 + 0.5) * 10))
		h.BR:set("RADAR")
	else
		h.AL:set(ra_ok and string.format("RA %d", math.floor(alt_u(ra) + 0.5)) or "RA ----")
		h.BR:set(st.ralt and "BARO  NO RA" or "BARO")
	end
	-- ALT MAX / MIN brackets on the tape (barometric limits: shown on the
	-- baro tape, and on the radar tape at the same height difference)
	local function bug(hy, hon, lim)
		if not lim then hon:set(0); return end
		hon:set(1)
		hy:set(clamp((alt_u(lim) - alt_u(baro)) * ak, -1.5, 1.5))
	end
	bug(h.AMXY, h.AMXON, st.amx)
	bug(h.AMNY, h.AMNON, st.amn)
	h.LIM1:set(st.amx and string.format("MAX %d", math.floor(alt_u(st.amx) + 0.5)) or " ")
	h.LIM2:set(st.amn and string.format("MIN %d", math.floor(alt_u(st.amn) + 0.5)) or " ")
	-- (normal edition: both in one line)
	local l1 = st.amx and string.format("MAX %d", math.floor(alt_u(st.amx) + 0.5))
	local l2 = st.amn and string.format("MIN %d", math.floor(alt_u(st.amn) + 0.5))
	h.LIM:set((l1 and l2) and (l1 .. "  " .. l2) or l1 or l2 or " ")
	h.TASON:set(st.tas and 1 or 0)
	-- VSI (needle on the m/s scale; the number in m/s or ft/min)
	h.VSION:set(st.vsi and 1 or 0)
	h.VSA:set((L.vsi_x0 and SIT_MFI.vsi_ang) and SIT_MFI.vsi_ang(L, vs) or 0)
	h.VSV:set(imp and math.floor(vs * 196.85 / 10 + 0.5) * 10 or math.floor(vs + 0.5))
	-- heading arc
	h.HDG:set(hdg)
	h.HDGV:set((math.floor(math.deg(hdg) + 0.5) + 359) % 360 + 1)
	local bugd = (S and S.hdg_bug) or 0
	h.BUG:set(-(math.rad(bugd) - hdg))
	local wf, ws = wind(sd, hdg, tas, pitch, C.t)
	if wf then
		local wv = imp and ws * 1.94384 or ws
		h.WIND:set(string.format("W %03d/%d", (math.floor(wf + 0.5) + 359) % 360 + 1, math.floor(wv + 0.5)))
	else
		h.WIND:set("W ---")
	end
	-- flight director: lateral = the SA page's steering command to the
	-- steerpoint (else the HDG bug), vertical = climb / descend to the
	-- held altitude (kept inside ALT MIN / MAX)
	h.FDON:set(st.fd and 1 or 0)
	local m1, m2, m3 = st.fd and "FD" or "FD OFF", " ", " "
	if st.fd then
		local cmd, how = nil, nil
		if C.act and S27_FD_CMD then
			local ok, c = pcall(S27_FD_CMD, sd, C.act, C.ox, C.oz, hdg)
			if ok and fin(c) then cmd, how = c, "NAV " .. tostring(C.act.lbl or "STP"):sub(1, 4) end
		end
		if not cmd and C.act and C.nav and C.nav.steer_to then
			local ok, b = pcall(C.nav.steer_to, C.act, C.ox, C.oz)
			if ok and fin(b) then cmd, how = math.rad(b), "NAV " .. tostring(C.act.lbl or "STP"):sub(1, 4) end
		end
		if not cmd then cmd, how = math.rad(bugd), string.format("HDG %03d", bugd % 360) end
		local err = math.deg(wrap(cmd - hdg))
		local fm = L.fd_max or 0.40
		h.FDX:set(clamp(err / (CFG.pfd_fd_full_deg or 20), -1, 1) * fm)
		local tgt = st.fd_alt or baro
		if st.amx and tgt > st.amx - 30 then tgt = st.amx - 30 end
		if st.amn and tgt < st.amn + 30 then tgt = st.amn + 30 end
		local vmax = CFG.pfd_fd_vs_max or 20
		local vcmd = clamp((tgt - baro) * 0.1, -vmax, vmax)
		local v = math.max(tas, 50)
		local gcmd = math.deg(math.asin(clamp(vcmd / v, -0.5, 0.5)))
		local gnow = math.deg(math.asin(clamp(vs / v, -0.99, 0.99)))
		h.FDY:set(clamp((gcmd - gnow) * (L.ppd or 0.032), -fm, fm))
		m2 = how
		m3 = string.format("ALT %d", math.floor(alt_u(tgt) / 10 + 0.5) * 10)
	end
	h.FM1:set(m1); h.FM2:set(m2); h.FM3:set(m3)
	h.VSS:set(string.format("VS %+d", imp and math.floor(vs * 196.85 / 10 + 0.5) * 10 or math.floor(vs + 0.5)))
end

-- LND page (MFI): "TAS 760  GS 812" and the wind
function S27_PFD.speeds(C)
	local sd = C.sd
	if not sd then return "TAS ---  GS ---", " " end
	local tas = num(sd, "getTrueAirSpeed")
	local gs = nil
	local ok, vx, _, vz = pcall(sd.getSelfVelocity)
	if ok and tonumber(vx) and tonumber(vz) then gs = math.sqrt(vx * vx + vz * vz) end
	local function f(v) return v and tostring(math.floor(S27_U.spd(v) + 0.5)) or "---" end
	local wf, ws = wind(sd, fin(C.hdg) and C.hdg or nil, tas, num(sd, "getPitch"), C.t)
	local wt = "W ---"
	if wf then wt = string.format("W %03d/%d", (math.floor(wf + 0.5) + 359) % 360 + 1, math.floor((imperial() and ws * 1.94384 or ws) + 0.5)) end
	return string.format("TAS %s  GS %s", f(tas), f(gs)), wt
end

-- ALT MAX: warn once when climbing above it, again after coming back
-- 50 m below; ALT MIN the same downwards. A new limit only warns after
-- the jet has been on the safe side of it.
function S27_PFD.set_limit(which, m)
	local st = S27_PFD.st
	if which == "AMAX" then st.amx = m; W.mx_armed = false
	else st.amn = m; W.mn_armed = false end
	if not st.amx and not st.amn then W.t = -100 end
end
function S27_PFD.check(C)
	local h = handles()
	local st = S27_PFD.st
	local t = C.t or 0
	local baro = num(C.sd, "getBarometricAltitude")
	if baro and (st.amx or st.amn) then
		local back = CFG.alt_alert_rearm_m or 50
		if st.amx then
			if baro < st.amx - back then W.mx_armed = true end
			if W.mx_armed and baro > st.amx then
				W.mx_armed, W.t = false, t
				W.txt = string.format("ALT MAX  %d %s", math.floor(alt_u(st.amx) + 0.5), imperial() and "FT" or "M")
			end
		end
		if st.amn then
			if baro > st.amn + back then W.mn_armed = true end
			if W.mn_armed and baro < st.amn then
				W.mn_armed, W.t = false, t
				W.txt = string.format("ALT MIN  %d %s", math.floor(alt_u(st.amn) + 0.5), imperial() and "FT" or "M")
			end
		end
	end
	local on = W.txt and (t - W.t) < (CFG.alt_alert_s or 8) and (st.amx or st.amn)
	h.wshow:set(on and 1 or 0)
	
	S27_PFD.warn_txt = on and W.txt or nil
end
-- settings.lua alt_max_m / alt_min_m: limits set from the start (0 = off)
do
	local st = S27_PFD.st
	if (tonumber(CFG.alt_max_m) or 0) > 0 then st.amx = tonumber(CFG.alt_max_m) end
	if (tonumber(CFG.alt_min_m) or 0) > 0 then st.amn = tonumber(CFG.alt_min_m) end
	if CFG.pfd_vsi == false then st.vsi = false end
end
