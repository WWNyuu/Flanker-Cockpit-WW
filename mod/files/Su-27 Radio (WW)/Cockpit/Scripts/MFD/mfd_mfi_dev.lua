-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: values and keys of the MFI edition's pages
-- (after the MiG-29 MFD add-on's MFI edition). Loaded by mfd_device.lua
-- when SIT.MFI is set, with that file's state and helpers in S27A.
-- Defines MFIDEV, called by mfd_device.lua:
--   key(page, button)  side keys (true = handled)
--   draw(page, t, stale)  the page's values (true = done, no classic page)
--   sa(t, stale)       SA page additions (after the classic SA scope)
--   every(t, stale)    every update, every page (alerts, ALT MAX / MIN)
--   keypad(k)          ЦЕЛИ keypad (true = handled)
-- Elements: MFD/indicator/mfd_mfi_page.lua (texts S27MFD_M_*).
-----------------------------------------------------------------------
local A = S27A
local ST, G, feed, PG = A.ST, A.G, A.feed, A.PG
local floor, sqrt, abs, atan2 = math.floor, math.sqrt, math.abs, math.atan2
local fmt = string.format
local NM = A.NM
local RL = SIT.RNG_LBL

-- every text parameter of the pages: a string from the start
local TX = {}
for _, n in ipairs(SIT_MFI.texts) do TX[n] = A.PT("M_" .. n) end
local function ts(n, s) TX[n]:set(s or "") end
-- number parameters S27MFD_<name> (made when first used)
local NP = {}
local function ns(n, v)
	local h = NP[n]
	if not h then h = A.P(n); NP[n] = h end
	h:set(v)
end
-- the LOFT page's texts (MiG-29 names): a string from the start too
for _, n in ipairs({"WPN", "WPN2", "TGT", "TRNG", "STEER", "CUET", "SUB", "RSC", "RCT", "A1", "A2", "A3", "B1", "B2", "B3", "PA", "PT", "PS"}) do
	get_param_handle("DLP_LFT_" .. n):set(" ")
end

-- page state
local M = {
	intc = false, toast = nil, toast_t = -10,
	nav_auto = true, dir = nil, tot_i = nil, entry = nil, buf = "",
	pic_rng = 2, pic_auto = true,
	flt_add = false, flt_pick = nil, fpage = 0,
	dtc_top = 1, bcn_page = 0, bng_ed = false, home_i = 1,
	pnt_i = nil, pnt_del_t = -10, pnt_msg = nil, pnt_msg_t = -10,
	alert_t = -100, alert_txt = nil, bingo_armed = true,
	lnd_direct = false,
}
local function toast(s) M.toast, M.toast_t = s, A.now() end
local function sd() return A.sensors() end
local function sdv(f) return A.sd_val(f) end
local function up(s) return tostring(s or ""):upper() end
local function dist(m) return A.rng_txt(m) .. " " .. RL end
local function alt_u(m) if SIT.METRIC then return floor((m or 0) / 10 + 0.5) * 10, "M" end return floor((m or 0) / 0.3048 / 10 + 0.5) * 10, "FT" end
local function hdg_deg() return (floor(math.deg(G.hdg or 0) + 0.5) + 359) % 360 + 1 end
local function wrap180(d) return (d + 540) % 360 - 180 end
-- units for the MiG-29 files (PFD, LOFT)
S27_U = {
	spd = function(ms) return (ms or 0) * SIT.SPD_K, SIT.SPD_LBL end,
	alt = function(m) if SIT.METRIC then return m or 0, "M" end return (m or 0) / 0.3048, "FT" end,
}
S27MFI_CFG = {alt_units = SIT.METRIC and "m" or "kft", hdg_tape_scale = SIT_MFI.loft.tape_k}
S27_LOFT_GEO = SIT_MFI.loft
-- the steerpoint as the MiG-29 files want it: {x, z, y, lbl}
local function act_pt()
	local r, a = A.route_now(), active_now()
	local w = r[a]
	if not w then return nil, r, a end
	return {x = w.x, z = w.z, y = w.alt, lbl = (w.name and w.name ~= "") and up(w.name):sub(1, 6) or ("STP" .. floor(w.num or a)), num = floor(w.num or a)}, r, a
end
-- the context for the MiG-29 PFD / LOFT code
local function ctx(t)
	local s = sd()
	local alt = s and (A.sd_val("getBarometricAltitude")) or 0
	return {t = t, sd = s, ox = G.ox, oz = G.oz, alt = alt, hdg = G.hdg or 0, act = act_pt(),
		unit_m = NM, unit_lbl = RL, stp_step = function(d) wp_step(d) end}
end
S27_FD_CMD = function(s, a, ox, oz) return atan2(a.z - oz, a.x - ox) end
S27_PAGES = {sel_store = function()
	local st = feed.sta and feed.sta[feed.cur_sta or 0]
	if not st or (st.n or 0) <= 0 then return nil, 0 end
	local n = 0
	for _, s in ipairs(feed.sta) do if s.name == st.name then n = n + (s.n or 0) end end
	return up(st.name), n
end}
do
	local ok, err = pcall(dofile, LockOn_Options.script_path .. "MFD/mfd_mfi_pfd_dev.lua")
	if not ok then A.log("mfd_mfi_pfd_dev.lua: " .. tostring(err)) end
	ok, err = pcall(dofile, LockOn_Options.script_path .. "MFD/mfd_mfi_loft_calc.lua")
	if not ok then A.log("mfd_mfi_loft_calc.lua: " .. tostring(err)) end
	ok, err = pcall(dofile, LockOn_Options.script_path .. "MFD/mfd_mfi_airfields.lua")
	if not ok then A.log("mfd_mfi_airfields.lua: " .. tostring(err)) end
end
-- world metres -> lat / lon (the terrain module; else nil)
local TERR = nil
local function ll_of(x, z)
	if TERR == nil then
		local ok, t = pcall(require, "terrain")
		TERR = (ok and type(t) == "table" and t.convertMetersToLatLon) and t or false
	end
	if not TERR then return nil end
	local ok, la, lo = pcall(TERR.convertMetersToLatLon, x, z)
	if ok and tonumber(la) and tonumber(lo) then return la, lo end
	return nil
end
local function ll_txt(la, lo)
	if not la then return "LAT/LON --" end
	local function p(v, w, pos, neg)
		local a = abs(v)
		local d = floor(a)
		return fmt("%s%0" .. w .. "d %04.1f", v >= 0 and pos or neg, d, (a - d) * 60)
	end
	return p(la, 2, "N", "S") .. "  " .. p(lo, 3, "E", "W")
end

---------------------------------------------------------------------------
-- keypad entries of the MFI pages (own buffer: longer than the device's 4)
---------------------------------------------------------------------------
local KP_DIGIT = {C1 = "1", C2 = "2", C3 = "3", C4 = "4", C5 = "5", C6 = "6", C7 = "7", C8 = "8", C9 = "9", C10 = "0"}
-- M.entry = {what, len, prompt, page}
local function entry_start(what, len, prompt)
	if M.entry and M.entry.what == what then M.entry = nil; M.buf = ""; return end
	M.entry, M.buf = {what = what, len = len, prompt = prompt, page = ST.page}, ""
	ST.entry = ""
end
local function entry_text()
	local e = M.entry
	if not e or e.page ~= ST.page then return " " end
	return e.prompt .. "  " .. M.buf .. "_"
end

---------------------------------------------------------------------------
-- SA
---------------------------------------------------------------------------
local INTC = {g = nil, t = -10}
local function intercept(t, stale)
	-- the picked PICTURE group, else the nearest hostile group
	if t - INTC.t >= 0.25 or t < INTC.t then
		INTC.t = t
		local gs = A.pic_groups(t, stale)
		local want = M.intc_g
		local best = nil
		if want then
			for _, g in ipairs(gs) do
				if (g.x - want.x) ^ 2 + (g.z - want.z) ^ 2 < 8000 ^ 2 then best = g; break end
			end
		end
		best = best or gs[1]
		if best then M.intc_g = {x = best.x, z = best.z} end
		INTC.g = best
	end
	local g = INTC.g
	if not g then ts("SA_INTC1", "INTC  NO HOSTILE"); ts("SA_INTC2", " "); return end
	local b, r = A.brg_rng(g.x - G.ox, g.z - G.oz)
	ts("SA_INTC1", fmt("INTC %03d/%s  %s", b, A.rng_txt(r), A.alt_txt(g.top)))
	-- collision course at our speed (TAS): |P + Vt t| = V t
	local s = sd()
	local V = (s and A.sd_val("getTrueAirSpeed")) or A.KIN.gs or 0
	if V < 50 then V = math.max(A.KIN.gs or 0, 50) end
	local px, pz = g.x - G.ox, g.z - G.oz
	local vx, vz = (g.v or 0) > 0 and (g.vx or 0) or 0, (g.v or 0) > 0 and (g.vz or 0) or 0
	-- (pic_groups keeps no velocity components: from speed and aspect)
	if g.v and g.v > 5 and g.asp then
		local tb = math.rad(b) + math.pi - math.rad(g.asp)     -- target track from its aspect to us
		vx, vz = g.v * math.cos(tb), g.v * math.sin(tb)
	end
	local a2 = vx * vx + vz * vz - V * V
	local b2 = 2 * (px * vx + pz * vz)
	local c2 = px * px + pz * pz
	local tt = nil
	if abs(a2) < 1e-6 then if b2 < 0 then tt = -c2 / b2 end
	else
		local d = b2 * b2 - 4 * a2 * c2
		if d >= 0 then
			local q = sqrt(d)
			local t1, t2 = (-b2 - q) / (2 * a2), (-b2 + q) / (2 * a2)
			if t1 > 0 and (t2 <= 0 or t1 < t2) then tt = t1 elseif t2 > 0 then tt = t2 end
		end
	end
	if tt and tt < 3600 then
		local hx, hz = px + vx * tt, pz + vz * tt
		local h = (floor(math.deg(atan2(hz, hx)) + 0.5) + 359) % 360 + 1
		ts("SA_INTC2", fmt("STEER %03d  TTI %s", h, A.mmss(tt)))
	else
		ts("SA_INTC2", fmt("STEER %03d  PURSUIT", b))
	end
end
local function sa_values(t, stale)
	local s = sd()
	local ias = s and A.sd_val("getIndicatedAirSpeed")
	ts("SA_IAS", ias and fmt("IAS=%d", floor(ias * SIT.SPD_K + 0.5)) or "IAS=---")
	ts("SA_GS", fmt("GS =%d", floor((A.KIN.gs or 0) * SIT.SPD_K + 0.5)))
	ns("M_SA_HDG", hdg_deg())
	local alt = s and A.sd_val("getBarometricAltitude")
	ts("SA_ALT", alt and fmt("A=%d", (alt_u(alt))) or "A=----")
	local H = A.H
	local rng = (H.rng_mode and H.rng_mode.v == 1) and tostring(H.rngt.v or "") or tostring(H.rng.v or "")
	ts("SA_RNG", rng .. RL)
	local w = act_pt()
	if w then
		local b, r = A.brg_rng(w.x - G.ox, w.z - G.oz)
		local e = ((A.KIN.gs or 0) > 30) and r / A.KIN.gs or nil
		ts("SA_WP1", fmt("STP %d %s", w.num, w.lbl))
		ts("SA_WP2", fmt("%03d/%s  %s", b, A.rng_txt(r), e and A.mmss(e) or "--:--"))
	else
		ts("SA_WP1", "NO STP"); ts("SA_WP2", " ")
	end
	ns("M_INTC", M.intc and 1 or 0)
	if M.intc then intercept(t, stale) end
	local on = M.toast and A.now() - M.toast_t < 2
	ns("M_SA_TOASTON", on and 1 or 0)
	if on then ts("SA_TOAST", M.toast) end
end
local function sa_mark()
	local x, z = G.cur_x or G.ox, G.cur_z or G.oz
	if not x then return end
	ST.mark_n = (ST.mark_n or 0) + 1
	table.insert(ST.marks, {x = x, z = z, n = ST.mark_n})
	while #ST.marks > SIT.MAX_MARKS do table.remove(ST.marks, 1) end
	toast(fmt("MARK %d", ST.mark_n))
end

---------------------------------------------------------------------------
-- FUEL (FPAS, as the MiG-29 MFI's)
---------------------------------------------------------------------------
local RES = 1000
local function best_figures(alt_m)
	local a = math.max(0, math.min((alt_m or 0) / 1000, 12))
	local sr = 0.11 + 0.024 * math.min(a, 11)            -- km per kg at best-range speed (Su-27)
	local mach = (a > 8) and 0.80 or (0.62 + 0.0225 * a)
	return sr, mach
end
local function home_opts()
	local o = {}
	local r = A.route_now()
	if r[1] then o[#o + 1] = {x = r[1].x, z = r[1].z, lbl = "STP 1"} end
	if #r > 1 then o[#o + 1] = {x = r[#r].x, z = r[#r].z, lbl = "STP " .. #r} end
	for _, m in ipairs(ST.marks) do o[#o + 1] = {x = m.x, z = m.z, lbl = "MARK " .. m.n} end
	return o
end
local function fuel_flow()
	local fl = A.KIN.flow
	if not fl then
		local cl, cr = sdv("getEngineLeftFuelConsumption"), sdv("getEngineRightFuelConsumption")
		if cl or cr then fl = (cl or 0) + (cr or 0) end
	end
	return fl
end
local function page_fuel(t)
	local f = sdv("getTotalFuelWeight")
	local fl = fuel_flow()
	local bingo = ST.bingo or 1500
	A.H.fuel.frac:set(f and math.max(0, math.min(1, f / 9400)) or 0)
	A.H.fuel.bingo:set(math.max(0, math.min(1, bingo / 9400)))
	ns("M_BNG_ED", (M.entry and M.entry.what == "BNG") and 1 or 0)
	if not f then ts("FU_TOT", "FUEL NO DATA"); return end
	ts("FU_TOT", fmt("%d KG", floor(f + 0.5)))
	ts("FU_INT", fmt("INT %d%%  OF 9400 KG", floor(f / 94 + 0.5)))
	ts("FU_FLOW", fl and fmt("FLOW %d KG/H", floor(fl * 3600 + 0.5)) or "FLOW MEASURING...")
	local gs = A.KIN.gs or 0
	local usable = math.max(0, f - RES)
	local w = act_pt()
	if not w then ts("FU_TO", "AT STP --  (NO STEERPOINT)")
	else
		local d = sqrt((w.x - G.ox) ^ 2 + (w.z - G.oz) ^ 2)
		local ete = gs > 30 and d / gs or nil
		if not fl or not ete then ts("FU_TO", fmt("AT %s  -- KG  %s", w.lbl, fl and "(NO GS)" or "(MEASURING)"))
		else
			local at = math.max(0, f - fl * ete)
			ts("FU_TO", fmt("AT %s  %d KG  %s%s", w.lbl, floor(at + 0.5), A.mmss(ete), (at < RES) and " LOW" or ""))
		end
	end
	local secs = (fl and fl > 0.01) and usable / fl or nil
	ts("FU_TORNG", fmt("TO %d KG  %s  %s", RES, secs and A.mmss(secs) or "--:--", (secs and gs > 30) and dist(secs * gs) or ("-- " .. RL)))
	ts("FU_SR", (fl and fl > 0.01 and gs > 30) and fmt("NOW %.2f %s/KG", gs / fl / NM, RL) or "NOW --")
	local alt = sdv("getBarometricAltitude") or 0
	local sr_h, m_h = best_figures(alt)
	local sr_o, m_o = best_figures(11000)
	ts("FU_B1", fmt("THIS ALT  M%.2f  %s", m_h, dist(usable * sr_h * 1000)))
	ts("FU_B2", fmt("%s  M%.2f  %s", SIT.METRIC and "OPT 11KM" or "OPT 36K FT", m_o, dist(usable * sr_o * 1000)))
	ts("FU_B3", fmt("M0.55 %s  %s", SIT.METRIC and "6-8KM" or "20-26K FT", A.mmss(usable / 2400 * 3600)))
	ts("FU_B4", fmt("THROTTLE ~%d%% RPM", (alt > 8000) and 86 or 82))
	ts("FU_RES", fmt("RESERVE %d KG  ESTIMATES", RES))
	local rl, rr = sdv("getEngineLeftRPM"), sdv("getEngineRightRPM")
	local tl, tr = sdv("getEngineLeftTemperatureBeforeTurbine"), sdv("getEngineRightTemperatureBeforeTurbine")
	local function pct(v) if not v then return "--" end if v <= 1.5 then v = v * 100 end return tostring(floor(v + 0.5)) end
	ts("FU_ENG", fmt("RPM %s / %s %%", pct(rl), pct(rr)))
	ts("FU_EGT", fmt("EGT %s / %s C", tl and tostring(floor(tl + 0.5)) or "--", tr and tostring(floor(tr + 0.5)) or "--"))
	ns("M_FU_EGTW", ((tl or 0) > 950 or (tr or 0) > 950) and 1 or 0)
	if M.entry and M.entry.what == "BNG" then ts("FU_BNG", "BINGO " .. M.buf .. "_ KG  (ENT)")
	else ts("FU_BNG", fmt("BINGO %d KG%s", bingo, (f < bingo) and "  REACHED" or "")) end
	ns("M_FU_BW", (f < bingo) and 1 or 0)
	local o = home_opts()
	if M.home_i > #o then M.home_i = 1 end
	local h = o[M.home_i]
	if h then
		local b, d = A.brg_rng(h.x - G.ox, h.z - G.oz)
		ts("FU_HOME", fmt("HOME %s  %03d/%s", h.lbl, b, dist(d)))
		local need = floor(d / 1000 / sr_h + 150 + 0.5)
		ts("FU_NEED", fmt("TO HOME ~%d KG  (+%d RES)", need, RES))
		ts("FU_HARR", fmt("ARRIVE WITH %d KG", floor(f - need + 0.5)))
	else
		ts("FU_HOME", "HOME --  (NO ROUTE / MARK)"); ts("FU_NEED", " "); ts("FU_HARR", " ")
	end
end

---------------------------------------------------------------------------
-- COM (UKV R-800 = PG.COM, KV R-864 = PG.COMK)
---------------------------------------------------------------------------
local function page_com(t, kv)
	local key = kv and "KV" or "UKV"
	local other = kv and "UKV" or "KV"
	local ffmt = kv and "%6.3f" or "%7.3f"
	ts("RD_TITLE", kv and "KV  R-864" or "UKV  R-800")
	local ch, vol, f = A.radp(key .. "_CH"), A.radp(key .. "_VOL"), A.radp(key .. "_F")
	local chn = floor(ch + 0.5)
	if ST.man_entry == key:lower() then ts("RD_FREQ", fmt("CH %02d  %s_", chn, ST.entry or ""))
	else ts("RD_FREQ", fmt("CH %02d  %s", chn, (f > 0) and fmt(ffmt, f) or "---.---")) end
	ts("RD_VOL", fmt("VOL %d%%", floor(vol * 100 + 0.5)))
	local slot = floor(A.radp("CART") + 0.5)
	ts("RD_SRC", (slot == 0) and "PRESETS: MISSION" or fmt("PRESETS: CARTRIDGE %d", slot))
	local man = ST.man_entry == key:lower()
	ns("M_RD_MSGON", man and 1 or 0)
	if man then ts("RD_MSG", fmt("NEW FREQ CH %02d: %s  ENT", chn, kv and "3.000-10.000" or "100.000-399.975")) end
	for c = 1, 20 do
		local fc = A.radp(key .. "_F" .. c)
		ts("RD_C" .. c, (fc > 0) and fmt("%02d  " .. ffmt, c, fc) or fmt("%02d  ------", c))
		ns("M_RD_S" .. c, (c == chn) and 1 or 0)
	end
	local och, of = floor(A.radp(other .. "_CH") + 0.5), A.radp(other .. "_F")
	ts("RD_OTHER", fmt("%s  CH %02d  %s", other, och, (of > 0) and fmt(kv and "%7.3f" or "%6.3f", of) or "----"))
	ts("RD_FC", fmt("CH %d", ST.fch or 0))
end

---------------------------------------------------------------------------
-- DTC
---------------------------------------------------------------------------
local function page_dtc()
	if not ST.carts then A.dtm_choices() end
	local n = #(ST.carts or {}) + 1
	if ST.cart and ST.cart < M.dtc_top then M.dtc_top = ST.cart end
	if M.dtc_top > n then M.dtc_top = math.max(1, n - 4) end
	ts("DTC_TITLE", "DATA CARTRIDGE")
	local ln = up(ST.loaded and ST.loaded.name)
	for k = 1, 5 do
		local c = M.dtc_top + k - 1
		if c <= n then
			local nm = up(A.dtm_name(c)):sub(1, 22)
			ts("DTC_I" .. k, nm)
			ns("M_DTC_V" .. k, (nm:sub(1, 16) == ln:sub(1, 16)) and 2 or 1)
		else
			ts("DTC_I" .. k, " "); ns("M_DTC_V" .. k, 0)
		end
	end
	local t = A.now()
	local m = (ST.dtm_msg ~= "" and t - ST.dtm_t < 2.5) and ST.dtm_msg or ((t - ST.dtm_t < 12) and ST.dtm_done or "")
	ts("DTC_D1", (m ~= "") and m or "R1-R5: READ ONE")
	ts("DTC_D2", "LOADED " .. ln:sub(1, 18))
	ts("DTC_D3", fmt("%d CARTRIDGES FOR THIS MAP", n - 1))
	ts("DTC_PAGE", fmt("PAGE %d/%d", floor((M.dtc_top - 1) / 5) + 1, math.max(1, math.ceil(n / 5))))
end
local function dtc_read(c)
	ST.cart = c
	if A.dtm_apply() then A.dtm_msg("READ IN PROGRESS", "READ COMPLETE: " .. up(A.dtm_name(c)):sub(1, 16))
	else A.dtm_msg("READ IN PROGRESS", "READ FAIL") end
end

---------------------------------------------------------------------------
-- FLIGHT
---------------------------------------------------------------------------
local function fl_rows(rows, title, pg)
	ts("FLT_TITLE", title)
	for k = 1, 5 do
		local r = rows[k]
		ts("FLT_R" .. k, r and r[1] or " "); ts("FLT_S" .. k, r and r[2] or " ")
		ns("M_FLT_M" .. k, r and r[3] or 0)
	end
	ts("FLT_PG", pg or " ")
end
local function fl_details(lines)
	for i = 1, 12 do
		local l = lines[i]
		ts("FLT_D" .. i, l and l[1] or " "); ns("M_FLT_C" .. i, l and l[2] or 0)
	end
end
local function page_flt()
	local sl = A.slots_now()
	ns("FLT_AUTO", ST.slot_man and 0 or 1)
	local own = A.own_name()
	local function desc(v)
		if v == "OWN" then return (own ~= "" and own or "OWNSHIP"):sub(1, 14), "OWNSHIP" end
		local a = A.flt_find(v)
		if not a then return v:sub(1, 14), "NOT ON THE DATALINK" end
		local b, r = A.brg_rng(a.x - G.ox, a.z - G.oz)
		return v:sub(1, 14), fmt("%03d/%s  %s", b, A.rng_txt(r), A.alt_str(a.y))
	end
	if M.flt_add then
		local cand = A.flt_candidates()
		local pages = math.max(1, math.ceil(#cand / 5))
		if M.fpage >= pages then M.fpage = pages - 1 end
		local rows = {}
		for k = 1, 5 do
			local a = cand[M.fpage * 5 + k]
			if a then
				local n = A.slot_of(a.unit)
				rows[k] = {(n and (n .. " ") or "") .. a.unit:sub(1, 13) .. (a.human and "*" or ""), up(a.type or ""):sub(1, 12), n and 3 or 1}
			end
		end
		fl_rows(rows, "ADD TO FLIGHT", #cand == 0 and "NO FRIENDLIES" or fmt("PAGE %d/%d", M.fpage + 1, pages))
		fl_details({{"R1-R5: IN / OUT OF THE FLIGHT", 6}, {"GREEN = IN THE FLIGHT (SLOT No.)", 2},
			{"PREV / NEXT: MORE AIRCRAFT", 5}, {"ADD: BACK TO THE FLIGHT", 5}})
		return
	end
	local rows = {}
	for k = 1, 4 do
		local v = sl[k]
		if v then
			local n, s = desc(v)
			rows[k] = {k .. " " .. n, s, (M.flt_pick == k) and 2 or ((v == "OWN") and 3 or 1)}
		else
			rows[k] = {k .. " EMPTY", " ", (M.flt_pick == k) and 2 or 1}
		end
	end
	fl_rows(rows, "FLIGHT", ST.slot_man and "MANUAL (R5 AUTO: OWN GROUP)" or "AUTO: OWN GROUP")
	local d = {}
	local v = M.flt_pick and sl[M.flt_pick]
	if v == "OWN" then
		local alt, ias = sdv("getBarometricAltitude"), sdv("getIndicatedAirSpeed")
		d = {{"SLOT " .. M.flt_pick .. "  OWNSHIP", 2}, {(own ~= "" and own or "OWNSHIP"):sub(1, 24), 1},
			{"ALT " .. (alt and A.alt_str(alt) or "--"), 1}, {"IAS " .. (ias and fmt("%d %s", floor(ias * SIT.SPD_K + 0.5), SIT.SPD_LBL) or "--"), 1}}
	elseif v then
		local a = A.flt_find(v)
		d = {{"SLOT " .. M.flt_pick .. "  " .. v:sub(1, 18), 2}}
		if a then
			local b, r = A.brg_rng(a.x - G.ox, a.z - G.oz)
			local gs = sqrt((a.vx or 0) ^ 2 + (a.vz or 0) ^ 2)
			d[#d + 1] = {up(a.type or ""):sub(1, 20), 1}
			d[#d + 1] = {fmt("BRA %03d/%s", b, dist(r)), 1}
			d[#d + 1] = {"ALT " .. A.alt_str(a.y), 1}
			d[#d + 1] = {fmt("GS %d %s", floor(gs * SIT.SPD_K + 0.5), SIT.SPD_LBL), 1}
			d[#d + 1] = {a.human and "PLAYER" or "AI", 5}
		else
			d[#d + 1] = {"NOT ON THE DATALINK", 3}
		end
		d[#d + 2] = {"DEL: OUT OF THE FLIGHT", 6}
	else
		d = {{"R1-R4: PICK A SLOT", 6}, {"ADD: AIRCRAFT INTO THE FLIGHT", 6}, {"R5 AUTO: THE OWN GROUP", 6}}
		local n = 0
		for k = 1, 4 do if sl[k] then n = n + 1 end end
		d[5] = {fmt("%d IN THE FLIGHT", n), 2}
	end
	fl_details(d)
end
local function flt_toggle(k)
	local a = A.flt_candidates()[M.fpage * 5 + k]
	if not a or a.unit == "" then return end
	local n = A.slot_of(a.unit)
	if n then
		if A.slots_now()[n] == "OWN" then return end
		A.freeze(); ST.slot[n] = nil; A.flt_changed()
	else
		local sl = A.slots_now()
		for s = 1, 4 do if not sl[s] then A.put_in_slot(a.unit, s); return end end
		toast("FLIGHT FULL")
	end
end

---------------------------------------------------------------------------
-- PICTURE
---------------------------------------------------------------------------
local PIC_RNG = {20, 40, 80, 160, 320}     -- plot radius, range units
local PIC = {gs = {}, sel = 1}
local function page_pic(t, stale)
	local gs = A.pic_groups(t, stale)
	PIC.gs = gs
	if PIC.sel > #gs then PIC.sel = 1 end
	local bull = A.bull_now()
	local bm = ST.pic_bull and bull ~= nil
	ts("PIC_HDR", (#gs == 0) and "PICTURE CLEAN" or fmt("PICTURE %d GROUP%s", #gs, #gs == 1 and "" or "S"))
	ts("PIC_SORT", bm and "CALL BULLS" or "CALL BRAA")
	for k = 1, 5 do
		local g = gs[k]
		if g then
			local bb = "---/--"
			if bull then local b2, r2 = A.brg_rng(g.x - bull[1], g.z - bull[2]); bb = fmt("%03d/%s", b2, A.rng_txt(r2)) end
			local braa = fmt("%03d/%s", g.b, A.rng_txt(g.r))
			ts("PIC_R" .. k, fmt("%-3d %-8s %-9s %-5s %s", k, bb, braa, A.alt_txt(g.top), A.aspect_word(g.asp)))
			ns("M_PIC_C" .. k, 1)
		else
			ts("PIC_R" .. k, " "); ns("M_PIC_C" .. k, 0)
		end
		ns("M_PIC_S" .. k, (g and k == PIC.sel) and 1 or 0)
		ns("M_PIC_RV" .. k, g and 1 or 0)
	end
	local g = gs[PIC.sel]
	if g then
		local pos
		if bm then local b2, r2 = A.brg_rng(g.x - bull[1], g.z - bull[2]); pos = fmt("BULLSEYE %03d/%s", b2, A.rng_txt(r2))
		else pos = fmt("BRAA %03d/%s", g.b, A.rng_txt(g.r)) end
		ts("PIC_K1", fmt("GROUP %d  %s  %s", PIC.sel, pos, A.alt_txt(g.top)))
		ts("PIC_K2", fmt("%s  %d CONTACT%s  HOSTILE  %s", A.aspect_word(g.asp), g.n, g.n == 1 and "" or "S", up(g.nm):sub(1, 8)))
	else
		ts("PIC_K1", "NO HOSTILE GROUPS"); ts("PIC_K2", " ")
	end
	-- plot: north up round the bullseye (CALL BULLS) or the jet
	local cx, cz = G.ox, G.oz
	if bm then cx, cz = bull[1], bull[2] end
	if M.pic_auto then
		local far = 0
		for _, q in ipairs(gs) do local d = sqrt((q.x - cx) ^ 2 + (q.z - cz) ^ 2); if d > far then far = d end end
		if bm then far = math.max(far, sqrt((G.ox - cx) ^ 2 + (G.oz - cz) ^ 2)) end
		M.pic_rng = #PIC_RNG
		for i, v in ipairs(PIC_RNG) do if v * NM >= far * 1.1 then M.pic_rng = i; break end end
	end
	ns("M_PIC_AUTO", M.pic_auto and 1 or 0)
	local R = PIC_RNG[M.pic_rng] * NM
	ts("PIC_PR", fmt("%d %s", PIC_RNG[M.pic_rng], RL))
	local PR = 0.30
	local function at(x, z)
		local dx, dy = (z - cz) / R * PR, (x - cx) / R * PR
		local d = sqrt(dx * dx + dy * dy)
		if d > PR then dx, dy = dx * PR / d, dy * PR / d end
		return dx, dy
	end
	ns("M_PIC_BE", bm and 1 or 0)
	ns("M_PIC_BX", 0); ns("M_PIC_BY", 0)
	local ox, oy = at(G.ox, G.oz)
	ns("M_PIC_OX", ox); ns("M_PIC_OY", oy); ns("M_PIC_OV", 1); ns("M_PIC_OH", -(G.hdg or 0))
	for k = 1, 5 do
		local q = gs[k]
		local p = "M_PIC_G" .. k .. "_"
		if q then
			local x, y = at(q.x, q.z)
			ns(p .. "X", x); ns(p .. "Y", y); ns(p .. "V", (k == PIC.sel) and 2 or 1)
			local trk = (q.v and q.v > 5 and q.asp) and (math.rad(q.b) + math.pi - math.rad(q.asp)) or 0
			ns(p .. "H", -trk)
		else
			ns(p .. "V", 0)
		end
	end
end

---------------------------------------------------------------------------
-- RWR
---------------------------------------------------------------------------
local function page_rwr(t)
	local list = (feed.rwr and t - (feed.rwr_t or -10) < 2) and feed.rwr or {}
	table.sort(list, function(p, q) return (p.st * 10 + p.pw) > (q.st * 10 + q.pw) end)
	ns("M_RW_ROT", G.hdg or 0)
	ns("M_RW_HDG", hdg_deg())
	local flash = floor(t * 4) % 2 == 0
	local R = 0.50
	for k = 1, 12 do
		local e = list[k]
		local p = "M_RW" .. k .. "_"
		if e then
			-- (positions turned with the rose: the emitter's bearing from north)
			local az = (e.az or 0) + (G.hdg or 0)
			local r = R * (0.25 + (1 - math.max(0, math.min(1, e.pw))) * 0.62)
			ns(p .. "X", r * math.sin(e.az)); ns(p .. "Y", r * math.cos(e.az))
			local st = (e.st >= 3) and 3 or ((e.st >= 2) and 2 or 1)
			ns(p .. "S", (st == 3 and not flash) and 0 or st)
			local lbl = A.rwr_label(e)
			local n = tonumber(lbl)
			if n then ns(p .. "K", 1); ns(p .. "N", n); ts("RWR_T" .. k, " ")
			else ns(p .. "K", 0); ts("RWR_T" .. k, lbl) end
			local _ = az
		else
			ns(p .. "S", 0)
		end
	end
	for k = 1, 6 do
		local e = list[k]
		if e then
			local brg = (floor(math.deg(e.az) + 0.5) + 360) % 360
			ts("RWR_L" .. k, fmt("%-3s %-4s %03d %s", A.rwr_label(e), ({"SRCH", "LOCK", "LNCH"})[e.st] or "", brg, up(e.nm):gsub("[^%w%-]", ""):sub(1, 4)))
			ns("M_RWR_C" .. k, (e.st >= 2) and 3 or 1)
		else
			ts("RWR_L" .. k, " "); ns("M_RWR_C" .. k, 0)
		end
	end
	local cm = feed.cm or {}
	ts("RWR_CM", fmt("CHAFF %d  FLARE %d", cm.chaff or 0, cm.flare or 0))
end

---------------------------------------------------------------------------
-- SMS (the stations: mfd_device.lua's STORES page)
---------------------------------------------------------------------------
local function page_sms()
	local by, of = A.slots()
	local cur = feed.cur_sta or 0
	local st = feed.sta and feed.sta[cur]
	if st and (st.n or 0) > 0 and not feed.gun then
		local n = 0
		for _, s in ipairs(feed.sta) do if s.name == st.name then n = n + (s.n or 0) end end
		ts("SMS_SEL", fmt("SEL ST%d  %s  X%d", of[cur] or cur, A.short_sta(st.name), n))
	else
		ts("SMS_SEL", feed.gun and "SEL GUN" or "SEL ----")
	end
	local cm = feed.cm or {}
	ts("SMS_GUN", fmt("GUN %d", cm.gun or 0))
	ts("SMS_CM", fmt("CHAFF %d  FLARE %d", cm.chaff or 0, cm.flare or 0))
	local nst, nld = 0, 0
	for n = 1, 10 do local s = by[n]; if s and s.n > 0 then nst = nst + s.n; nld = nld + 1 end end
	ts("SMS_TOT", fmt("%d STORES ON %d STATIONS", nst, nld))
end

---------------------------------------------------------------------------
-- NAV: RTE (steering, the route, time on target)
---------------------------------------------------------------------------
local NAVL = {top = 1}
local function clock(s) return A.clock_txt(s) end
local function hhmmss_in(e)
	local n = tonumber(e)
	if not n or #e < 4 then return nil end
	if #e == 4 then e = e .. "00" end
	local h, m, s = tonumber(e:sub(1, 2)), tonumber(e:sub(3, 4)), tonumber(e:sub(5, 6)) or 0
	if not h or h > 23 or m > 59 or s > 59 then return nil end
	return h * 3600 + m * 60 + s
end
local function nav_tot(route, act, gs, tod)
	local i = M.tot_i
	if not i or not route[i] or i < act then
		-- the first point from the steerpoint on with a TOT, else the steerpoint
		i = nil
		for k = math.max(act, 1), #route do if route[k].tot then i = k; break end end
		M.tot_i = i or act
		i = M.tot_i
	end
	local q = route[i]
	ns("M_TOT_ON", (q and q.tot) and 1 or 0)
	if M.entry and M.entry.what == "TOT" then ts("TOT_HINT", "TOT " .. M.buf .. "_  HHMMSS ENT")
	else ts("TOT_HINT", fmt("TOT FOR STP %d: TOT + KEYPAD HHMMSS, PT: NEXT", floor(q and q.num or i or 0))) end
	if not q or not q.tot then return end
	local d = sqrt((route[act].x - G.ox) ^ 2 + (route[act].z - G.oz) ^ 2)
	for k = act + 1, i do d = d + sqrt((route[k].x - route[k - 1].x) ^ 2 + (route[k].z - route[k - 1].z) ^ 2) end
	local left = q.tot - (tod % 86400)
	if left < -43200 then left = left + 86400 end
	ts("TOT_L1", fmt("TOT STP %d  %s", floor(q.num or i), clock(q.tot)))
	local e = (gs > 30) and d / gs or nil
	local dt = e and (e - left) or nil
	if not dt then ts("TOT_ST", "NO GS"); ns("M_TOT_C", 2)
	elseif abs(dt) < 10 then ts("TOT_ST", "ON TIME"); ns("M_TOT_C", 1)
	else ts("TOT_ST", fmt("%s %s", dt > 0 and "LATE" or "EARLY", A.mmss(abs(dt)))); ns("M_TOT_C", abs(dt) > 60 and 3 or 2) end
	local req = (left > 1) and d / left or nil
	ts("TOT_SPD", fmt("REQ GS %s  NOW %d %s", req and tostring(floor(req * SIT.SPD_K + 0.5)) or "---", floor(gs * SIT.SPD_K + 0.5), SIT.SPD_LBL))
	local lo, hi = 400 / 3.6, 1200 / 3.6
	local function sx(v) return -0.60 + math.max(0, math.min(1, (v - lo) / (hi - lo))) * 1.20 end
	ns("M_TOT_RX", req and sx(req) or 0); ns("M_TOT_RV", req and 1 or 0)
	ns("M_TOT_GX", sx(gs)); ns("M_TOT_GV", gs > 30 and 1 or 0)
	local nx = route[i + 1]
	ts("TOT_THEN", nx and fmt("THEN STP %d %s", floor(nx.num or (i + 1)), up(nx.name):sub(1, 8)) or "LAST POINT")
	local fl, f = fuel_flow(), sdv("getTotalFuelWeight")
	if fl and f and left > 0 then
		local at = f - fl * left
		ts("TOT_FUEL", fmt("FUEL AT TOT ~%d KG", floor(at + 0.5))); ns("M_TOT_FC", (at < (ST.bingo or 1500)) and 2 or 1)
	else
		ts("TOT_FUEL", "FUEL AT TOT --"); ns("M_TOT_FC", 1)
	end
end
local function page_nav(t)
	local route, act = A.route_now(), active_now()
	local gs = A.KIN.gs or 0
	local tod = G.tod or 0
	ts("NAV_SRC", ST.work and "EDITED" or up(ST.loaded and ST.loaded.name):sub(1, 12))
	ns("M_NAV_AUTO", M.nav_auto and 1 or 0)
	ns("M_NAV_ADDM", ST.add and 1 or 0)
	if ST.add then ts("NAV_SEQ", "ADD " .. A.ADD_STEP[ST.add.step][2] .. "  " .. (ST.entry or "") .. "_")
	elseif ST.entry_msg and t - (ST.entry_t or -10) < 3 then ts("NAV_SEQ", ST.entry_msg)
	else ts("NAV_SEQ", (M.nav_auto and "AUTO SEQUENCE" or "MANUAL SEQUENCE") .. (M.dir and "  DIRECT" or "")) end
	local w = route[act]
	if not w then
		ts("NAV_STP", "NO ROUTE"); ts("NAV_BRG", "R1 LOAD: A CARTRIDGE"); ts("NAV_TIME", " "); ts("NAV_LEG", " ")
		ts("NAV_CMD", " "); ns("M_NAV_SV", 0)
		for i = 1, 5 do ts("NAV_L" .. i, " "); ns("M_NAV_C" .. i, 0); ns("M_NAV_T" .. i, 0) end
		ns("M_TOT_ON", 0); ts("TOT_HINT", " ")
		return
	end
	local b, r = A.brg_rng(w.x - G.ox, w.z - G.oz)
	ts("NAV_STP", fmt("STP %d %s", floor(w.num or act), up(w.name):sub(1, 10)))
	ts("NAV_BRG", fmt("%03d/%s", b, dist(r)))
	local e = A.eta_s(route, act, act, gs)
	ts("NAV_TIME", fmt("ETE %s  ETA %s", e and A.mmss(e) or "--:--", e and clock(tod + e):sub(1, 5) or "--:--"))
	-- the leg (previous point or the DIR start -> steerpoint): cross track
	local p = route[act - 1]
	if M.dir and M.dir.i == act then p = M.dir else M.dir = nil end
	local xt = "DIRECT"
	if p then
		local lx, lz = w.x - p.x, w.z - p.z
		local ll = sqrt(lx * lx + lz * lz)
		if ll > 1 then
			local cr = ((G.ox - p.x) * lz - (G.oz - p.z) * lx) / ll
			xt = fmt("XTK %.1f %s", abs(cr) / NM, cr >= 0 and "L" or "R")
		end
	end
	ts("NAV_LEG", xt)
	-- steering: bearing against the ground track (+-45 deg on the bar)
	local trk = (gs > 30) and math.deg(atan2(A.KIN.vz, A.KIN.vx)) or math.deg(G.hdg or 0)
	local err = wrap180(b - trk)
	ns("M_NAV_STEER", math.max(-1, math.min(1, err / 45))); ns("M_NAV_SV", 1)
	if abs(err) < 2 then ts("NAV_CMD", "ON COURSE")
	else ts("NAV_CMD", fmt("TURN %s %d", err > 0 and "RIGHT" or "LEFT", floor(abs(err) + 0.5))) end
	-- the list, 5 rows round the steerpoint
	local n = #route
	if act < NAVL.top then NAVL.top = act end
	if act > NAVL.top + 4 then NAVL.top = act - 4 end
	if NAVL.top > math.max(1, n - 4) then NAVL.top = math.max(1, n - 4) end
	nav_tot(route, act, gs, tod)
	for k = 0, 4 do
		local i = NAVL.top + k
		local q = route[i]
		if q then
			local qb, qr = A.brg_rng(q.x - G.ox, q.z - G.oz)
			local qe = (i >= act) and A.eta_s(route, act, i, gs) or nil
			ts("NAV_L" .. (k + 1), fmt("%-4s %-9s %03d    %-6s %s", tostring(floor(q.num or i)), up(q.name):sub(1, 9), qb, A.rng_txt(qr),
				qe and clock(tod + qe):sub(1, 5) or "--:--"))
			ns("M_NAV_C" .. (k + 1), (i == act) and 2 or ((i < act) and 4 or (q.user and 3 or 1)))
			ns("M_NAV_T" .. (k + 1), (q.tot and 1 or 0) + ((i == M.tot_i) and 2 or 0))
		else
			ts("NAV_L" .. (k + 1), " "); ns("M_NAV_C" .. (k + 1), 0); ns("M_NAV_T" .. (k + 1), 0)
		end
	end
end
-- AUTO sequencing: the SIT's own steerpoint steps on within 1.5 km
local function nav_seq()
	if not M.nav_auto or not ST.sit_act then return end
	local r = A.route_now()
	local w = r[ST.sit_act]
	if w and G.ox and (w.x - G.ox) ^ 2 + (w.z - G.oz) ^ 2 < 1500 ^ 2 and ST.sit_act < #r then
		ST.sit_act = ST.sit_act + 1
		toast("STP " .. ST.sit_act)
	end
end

---------------------------------------------------------------------------
-- BCN: the nearest airfields of the map
---------------------------------------------------------------------------
local AF = {th = nil, list = nil}
local function airfields()
	local th = feed.date and feed.date.th
	if AF.list and AF.th == th then return AF.list end
	AF.th, AF.list = th, {}
	local src = S27_AIRFIELDS and th and S27_AIRFIELDS[th]
	if not src then
		-- not named (no hook): the map whose first field converts near us
		for name, l in pairs(S27_AIRFIELDS or {}) do
			local x, z = SIT_DTM.to_world(l[1][2], l[1][3])
			if x and G.ox and (x - G.ox) ^ 2 + (z - G.oz) ^ 2 < 1500e3 ^ 2 then src = l; AF.th = th or name; break end
		end
	end
	for _, a in ipairs(src or {}) do
		local x, z = SIT_DTM.to_world(a[2], a[3])
		if x then AF.list[#AF.list + 1] = {name = a[1], x = x, z = z, rwy = a[4]} end
	end
	return AF.list
end
local function page_bcn()
	local l = airfields()
	local near = {}
	for _, a in ipairs(l) do near[#near + 1] = {a = a, d = (a.x - G.ox) ^ 2 + (a.z - G.oz) ^ 2} end
	table.sort(near, function(p, q) return p.d < q.d end)
	local pages = math.max(1, math.ceil(#near / 8))
	if M.bcn_page >= pages then M.bcn_page = pages - 1 end
	ts("BCN_HD", "AIRFIELD          BRG  DIST    RWY")
	for k = 1, 8 do
		local e = near[M.bcn_page * 8 + k]
		if e then
			local b, r = A.brg_rng(e.a.x - G.ox, e.a.z - G.oz)
			local rw = e.a.rwy and e.a.rwy[1] and fmt("%02d", floor(((e.a.rwy[1] + 5) % 360) / 10 + 0.5)) or "--"
			ts("BCN_L" .. k, fmt("%-17s %03d  %-6s  %s", up(e.a.name):sub(1, 17), b, A.rng_txt(r), rw))
			ns("M_BCN_C" .. k, (M.bcn_page == 0 and k == 1) and 2 or ((r > 300e3) and 3 or 1))
		else
			ts("BCN_L" .. k, " "); ns("M_BCN_C" .. k, 0)
		end
	end
	local e = near[1]
	if e then
		local b, r = A.brg_rng(e.a.x - G.ox, e.a.z - G.oz)
		ts("BCN_SEL", fmt("NEAREST %s  %03d/%s", up(e.a.name):sub(1, 16), b, dist(r)))
	else
		ts("BCN_SEL", #l == 0 and "NO AIRFIELDS FOR THIS MAP" or " ")
	end
	ts("BCN_PG", fmt("PAGE %d/%d", M.bcn_page + 1, pages))
end

---------------------------------------------------------------------------
-- PNT: route editor (its own cursor on the working route)
---------------------------------------------------------------------------
local function pnt_msg(s) M.pnt_msg, M.pnt_msg_t = s, A.now() end
local function page_pnt(t)
	local r = A.route_now()
	local n = #r
	if not M.pnt_i or M.pnt_i > n then M.pnt_i = math.max(1, math.min(active_now(), n)) end
	ts("PNT_TITLE", ST.work and "ROUTE EDIT  (EDITED)" or "ROUTE EDIT")
	local q = r[M.pnt_i]
	if q then
		local b, d = A.brg_rng(q.x - G.ox, q.z - G.oz)
		ts("PNT_SEL", fmt("PT %d %s  %03d/%s", floor(q.num or M.pnt_i), up(q.name):sub(1, 10), b, dist(d)))
		ts("PNT_LL", ll_txt(ll_of(q.x, q.z)))
	else
		ts("PNT_SEL", "NO ROUTE"); ts("PNT_LL", " ")
	end
	-- R1-R4: the points round the cursor, R5 = fly to it (STP)
	local top = math.max(1, math.min(M.pnt_i - 1, n - 3))
	M.pnt_top = top
	local act = active_now()
	for k = 1, 4 do
		local i = top + k - 1
		local p = r[i]
		if p then
			ts("PNT_R" .. k, fmt("%d %s", floor(p.num or i), up(p.name):sub(1, 9)))
			ns("M_PNT_C" .. k, (i == M.pnt_i) and 2 or ((i == act) and 3 or 1))
		else
			ts("PNT_R" .. k, " "); ns("M_PNT_C" .. k, 0)
		end
	end
	ts("PNT_R5", q and ("FLY TO " .. floor(q.num or M.pnt_i)) or " "); ns("M_PNT_C5", q and 1 or 0)
	local e = M.entry
	if e and e.page == PG.PNT then ts("PNT_MSG", entry_text()); ns("M_PNT_MSGC", 1)
	elseif M.pnt_msg and t - M.pnt_msg_t < 3 then ts("PNT_MSG", M.pnt_msg); ns("M_PNT_MSGC", 1)
	else ts("PNT_MSG", "UP/DN MOVE  POS NEW PLACE  ADD AFTER  DEL"); ns("M_PNT_MSGC", 0) end
	ts("PNT_PG", fmt("PT %d/%d", M.pnt_i, n))
end
local function pnt_move(d)
	local r = A.route_now()
	local i, j = M.pnt_i, (M.pnt_i or 0) + d
	if not i or not r[i] or not r[j] then return end
	local w = A.work_copy()
	w[i], w[j] = w[j], w[i]
	A.renumber(w)
	M.pnt_i = j
	pnt_msg("POINT MOVED TO " .. j)
end
local function pnt_pos_done(lat, lon)
	local x, z = SIT_DTM.to_world(lat, lon)
	if not x then pnt_msg("NO MAP POSITION"); return end
	if G.ox and (x - G.ox) ^ 2 + (z - G.oz) ^ 2 > 1500e3 ^ 2 then pnt_msg("TOO FAR (OTHER MAP?)"); return end
	local w = A.work_copy()
	if M.pnt_new then
		ST.user_n = (ST.user_n or 0) + 1
		local i = math.min((M.pnt_i or 0) + 1, #w + 1)
		table.insert(w, i, {x = x, z = z, name = "U" .. ST.user_n, user = true})
		M.pnt_i = i
		pnt_msg("POINT ADDED " .. i)
	elseif w[M.pnt_i] then
		w[M.pnt_i].x, w[M.pnt_i].z = x, z
		pnt_msg("POINT " .. M.pnt_i .. " MOVED")
	end
	A.renumber(w)
end

---------------------------------------------------------------------------
-- LND (HSI alone) and the heading / course both pages share (HSI table)
---------------------------------------------------------------------------
local function page_lnd(t)
	local HSI = A.HSI
	local hdg = G.hdg or 0
	local hd = math.deg(hdg)
	ns("M_LND_ROT", hdg)
	ns("M_LND_HDGN", hdg_deg())
	local w, r, act = act_pt()
	local crs = HSI.crs
	local mode = HSI.crs and "CRS MAN" or "CRS AUTO"
	if w then
		local route = r
		local p = route[act - 1]
		if M.dir and M.dir.i == act then p = M.dir end
		local b = A.brg_rng(w.x - G.ox, w.z - G.oz)
		local auto = (p and not M.lnd_direct) and select(1, A.brg_rng(w.x - p.x, w.z - p.z)) or b
		if M.lnd_direct and not HSI.crs then mode = "CRS DIRECT" end
		crs = crs or auto
		local from = select(1, A.brg_rng(G.ox - w.x, G.oz - w.z))
		local dev = wrap180(from - (crs + 180))
		ns("M_LND_CDI", math.max(-1, math.min(1, -dev / 10)))
		ns("M_LND_B1R", hdg - math.rad(b)); ns("M_LND_B1V", 1)
		local _, d = A.brg_rng(w.x - G.ox, w.z - G.oz)
		local e = ((A.KIN.gs or 0) > 30) and d / A.KIN.gs or nil
		ts("LND_STP1", fmt("STP %d %s", w.num, w.lbl))
		ts("LND_STP2", fmt("%03d/%s  ETE %s", b, dist(d), e and A.mmss(e) or "--:--"))
	else
		crs = crs or floor(hd + 0.5) % 360
		ns("M_LND_CDI", 0); ns("M_LND_B1V", 0)
		ts("LND_STP1", "NO STEERPOINT"); ts("LND_STP2", " ")
	end
	local bug = HSI.hdg or floor(hd + 0.5) % 360
	ns("M_LND_CRSR", hdg - math.rad(crs)); ns("M_LND_CRSN", (floor(crs + 0.5) + 359) % 360 + 1)
	ns("M_LND_BUGR", hdg - math.rad(bug)); ns("M_LND_BUGN", (floor(bug + 0.5) + 359) % 360 + 1)
	ts("LND_CRSM", mode)
	local s1, s2 = "TAS ---  GS ---", " "
	if S27_PFD and S27_PFD.speeds then
		local ok, a, b2 = pcall(S27_PFD.speeds, ctx(t))
		if ok then s1, s2 = a, b2 end
	end
	ts("LND_SPD", s1); ts("LND_WIND", s2)
	ts("LND_ENTRY", entry_text())
end

---------------------------------------------------------------------------
-- PFD (MiG-29 dl_pfd_dev.lua) + the steerpoint pointer on the heading arc
---------------------------------------------------------------------------
local function page_pfd(t)
	if not S27_PFD then return end
	local C = ctx(t)
	local bug = A.HSI.hdg or floor(math.deg(G.hdg or 0) + 0.5) % 360
	local ok, err = pcall(S27_PFD.update, C, {hdg_bug = bug}, SIT_MFI.pfd)
	if not ok and not M.pfd_err then M.pfd_err = true; A.log("PFD: " .. tostring(err)) end
	local w = C.act
	if w then
		local b = math.deg(atan2(w.z - G.oz, w.x - G.ox))
		local rel = wrap180(b - math.deg(G.hdg or 0))
		local lim = SIT_MFI.pfd.wp_lim or 48
		local cl = math.max(-lim, math.min(lim, rel))
		ns("PFD_WPB", -math.rad(cl)); ns("PFD_WPV", (abs(rel) > lim) and 2 or 1)
		local _, d = A.brg_rng(w.x - G.ox, w.z - G.oz)
		ts("PFD_WPT", fmt("STP%d %03d %s%s", w.num, (floor(b + 0.5) + 359) % 360 + 1, A.rng_txt(d), RL))
	else
		ns("PFD_WPV", 0); ts("PFD_WPT", " ")
	end
	ts("PFD_ENTRY", entry_text())
end

---------------------------------------------------------------------------
-- LOFT (MiG-29 dl_loft.lua)
---------------------------------------------------------------------------
local function page_loft(t)
	if not S27_LOFT then return end
	local ok, err = pcall(S27_LOFT.update, ctx(t))
	if not ok and not M.loft_err then M.loft_err = true; A.log("LOFT: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- alerts: BINGO, ALT MAX / MIN (red, flashing, a few seconds; every page)
---------------------------------------------------------------------------
local function alerts(t)
	local f = sdv("getTotalFuelWeight")
	local bingo = ST.bingo or 1500
	if f then
		if f < bingo and M.bingo_armed then M.bingo_armed = false; M.alert_t, M.alert_txt = t, fmt("BINGO FUEL  %d KG", floor(f + 0.5)) end
		if f > bingo + 100 then M.bingo_armed = true end
	end
	if S27_PFD and S27_PFD.check then
		local w0 = S27_PFD.warn_txt
		pcall(S27_PFD.check, ctx(t))
		local w = S27_PFD.warn_txt
		if w and w ~= w0 then M.alert_t, M.alert_txt = t, w end
	end
	local on = M.alert_txt and t - M.alert_t < 8
	ns("M_ALERT_ON", (on and floor((t - M.alert_t) * 2.5) % 2 == 0) and 1 or 0)
	if on then ts("ALERT", M.alert_txt) end
end

---------------------------------------------------------------------------
-- keys
---------------------------------------------------------------------------
local function com_keys(kv)
	local k = kv and "KV" or "UKV"
	return {
		L1 = function() A.com_key(k .. "_CH_UP") end, L2 = function() A.com_key(k .. "_CH_DN") end,
		L3 = function() A.com_key(k .. "_VOL_UP") end, L4 = function() A.com_key(k .. "_VOL_DN") end,
		L5 = function() A.com_man(k:lower()) end,
		R1 = function() ST.fch = (ST.fch + 1) % 128 end, R2 = function() ST.fch = (ST.fch + 127) % 128 end,
	}
end
local function pfd_toggle(f) return function() if S27_PFD then S27_PFD.st[f] = not S27_PFD.st[f] end end end
local function loft_key(b) return function() if S27_LOFT then pcall(S27_LOFT.command, b, ctx(A.now())) end end end
local KEYS = {
	[PG.SIT] = {
		L1 = function() ST.rte = not ST.rte end,
		L2 = function() wp_step(1); local w = act_pt(); toast(w and ("STP " .. w.num .. " " .. w.lbl) or "NO ROUTE") end,
		L3 = function() M.intc = not M.intc; toast(M.intc and "INTERCEPT ON" or "INTERCEPT OFF") end,
		L4 = sa_mark,
		L5 = function() if #ST.marks > 0 then local m = table.remove(ST.marks); toast("MARK " .. m.n .. " DELETED") end end,
		R1 = function() ST.exp = not ST.exp; if ST.exp then ST.form = false end end,
		R2 = function() A.sit_range(1) end, R3 = function() A.sit_range(-1) end,
		R4 = function() ST.page = PG.SETS end,
		R5 = function() ST.lines = not ST.lines end,
	},
	[PG.SETS] = {R5 = function() ST.nup = not ST.nup end},
	[PG.PIC] = {
		L1 = function() M.pic_auto = false; M.pic_rng = math.min(#PIC_RNG, M.pic_rng + 1) end,
		L2 = function() M.pic_auto = false; M.pic_rng = math.max(1, M.pic_rng - 1) end,
		L3 = function() M.pic_auto = not M.pic_auto end,
		L4 = function()
			local g = PIC.gs[PIC.sel]
			if g then M.intc_g = {x = g.x, z = g.z} end
			M.intc = true; ST.page = PG.SIT; toast("INTERCEPT GROUP " .. PIC.sel)
		end,
		L5 = function() ST.pic_bull = not ST.pic_bull end,
	},
	[PG.FLT] = {
		L1 = function() M.flt_add = not M.flt_add; M.fpage = 0 end,
		L2 = function()
			local k = M.flt_pick
			local sl = A.slots_now()
			if k and sl[k] and sl[k] ~= "OWN" then A.freeze(); ST.slot[k] = nil; A.flt_changed(); M.flt_pick = nil end
		end,
		L4 = function() M.fpage = math.max(0, M.fpage - 1) end,
		L5 = function() M.fpage = M.fpage + 1 end,
		R5 = function() if not M.flt_add then A.flt_auto() else flt_toggle(5) end end,
	},
	[PG.LOFT] = {L1 = loft_key("M1"), L2 = loft_key("M2"), L3 = loft_key("M3"), R1 = loft_key("R1"), R2 = loft_key("R2"), R3 = loft_key("R3")},
	[PG.NAV] = {
		L1 = function() wp_step(-1) end, L2 = function() wp_step(1) end,
		L3 = function() M.nav_auto = not M.nav_auto end,
		L4 = function()
			local a = active_now()
			if A.route_now()[a] and G.ox then M.dir = {x = G.ox, z = G.oz, i = a}; ST.sit_act = a; A.msg("DIRECT TO STP " .. a) end
		end,
		L5 = function() M.dir = nil; A.nav_rst() end,
		R1 = function() A.dtm_choices(); ST.page = PG.DTM end,
		R2 = function() entry_start("TOT", 6, "TOT HHMMSS") end,
		R3 = function()
			local r = A.route_now()
			if #r > 0 then M.tot_i = math.max(active_now(), (M.tot_i or 0) % #r + 1) end
		end,
		R4 = function() local q = A.route_now()[M.tot_i or 0]; if q then q.tot = nil; A.msg("TOT CLEARED") end end,
		R5 = function() A.nav_add() end,
	},
	[PG.PFD] = {
		L1 = function()
			if not S27_PFD then return end
			local st = S27_PFD.st
			st.fd = not st.fd
			if st.fd then st.fd_alt = sdv("getBarometricAltitude") end
		end,
		L2 = pfd_toggle("tas"),
		L3 = function() entry_start("AMAX", 5, "ALT MAX (0 OFF)") end,
		L4 = function() entry_start("AMIN", 5, "ALT MIN (0 OFF)") end,
		L5 = pfd_toggle("ralt"),
		R1 = pfd_toggle("vsi"),
	},
	[PG.LND] = {
		L1 = function() entry_start("HDG", 3, "HDG") end,
		L2 = function() entry_start("CRS", 3, "CRS (0 AUTO)") end,
		L4 = function() M.lnd_direct = not M.lnd_direct; A.HSI.crs = nil end,
		L5 = function() A.HSI.hdg = floor(math.deg(G.hdg or 0) + 0.5) % 360 end,
	},
	[PG.PNT] = {
		L1 = function() pnt_move(-1) end, L2 = function() pnt_move(1) end,
		L3 = function() M.pnt_new = false; entry_start("PLAT", 5, "LAT N DDMMm") end,
		L4 = function() M.pnt_new = true; entry_start("PLAT", 5, "NEW PT LAT N DDMMm") end,
		L5 = function()
			local r = A.route_now()
			if not r[M.pnt_i or 0] then return end
			if A.now() - M.pnt_del_t < 3 then
				M.pnt_del_t = -10
				local w = A.work_copy()
				table.remove(w, M.pnt_i); A.renumber(w)
				if ST.sit_act and ST.sit_act > #w then ST.sit_act = (#w > 0) and #w or nil end
				pnt_msg("POINT DELETED")
			else
				M.pnt_del_t = A.now(); pnt_msg("DEL AGAIN TO DELETE PT " .. M.pnt_i)
			end
		end,
		R5 = function() if A.route_now()[M.pnt_i or 0] then ST.sit_act = M.pnt_i; pnt_msg("FLY TO PT " .. M.pnt_i) end end,
	},
	[PG.BCN] = {L1 = function() M.bcn_page = math.max(0, M.bcn_page - 1) end, L2 = function() M.bcn_page = M.bcn_page + 1 end},
	[PG.COM] = com_keys(false),
	[PG.COMK] = com_keys(true),
	[PG.FUEL] = {
		L1 = function() entry_start("BNG", 4, "BINGO") end,
		L2 = function() M.home_i = M.home_i % math.max(1, #home_opts()) + 1 end,
	},
	[PG.DTM] = {
		L1 = function() dtc_read(ST.cart or 1) end,
		L2 = function() ST.carts = nil; A.dtm_choices(); A.dtm_msg("REFRESH", "CARTRIDGES READ AGAIN") end,
		L4 = function() M.dtc_top = math.max(1, M.dtc_top - 5) end,
		L5 = function() if M.dtc_top + 5 <= #(ST.carts or {}) + 1 then M.dtc_top = M.dtc_top + 5 end end,
	},
	[PG.SMS] = {},
}
for k = 1, 4 do
	KEYS[PG.FLT]["R" .. k] = function()
		if M.flt_add then flt_toggle(k) else M.flt_pick = (M.flt_pick == k) and nil or k end
	end
	KEYS[PG.PNT]["R" .. k] = function()
		local i = (M.pnt_top or 1) + k - 1
		if A.route_now()[i] then M.pnt_i = i end
	end
end
for k = 1, 5 do
	KEYS[PG.PIC]["R" .. k] = function() if PIC.gs[k] then PIC.sel = k end end
	KEYS[PG.DTM]["R" .. k] = function()
		local c = M.dtc_top + k - 1
		if c <= #(ST.carts or {}) + 1 then dtc_read(c) end
	end
end

-- keypad ВВОД for the MFI entries
local function entry_enter()
	local e, b = M.entry, M.buf
	M.entry, M.buf = nil, ""
	local n = tonumber(b)
	local w = e.what
	if w == "BNG" then
		if n then ST.bingo = math.min(9400, (n < 100) and n * 100 or n); A.msg("BINGO " .. ST.bingo) end
	elseif w == "TOT" then
		local s = hhmmss_in(b)
		local q = A.route_now()[M.tot_i or 0]
		if s and q then q.tot = s; A.msg("TOT " .. A.clock_txt(s)) else A.msg("TOT: HHMMSS") end
	elseif w == "AMAX" or w == "AMIN" then
		if S27_PFD and n then S27_PFD.set_limit(w, S27_PFD.alt_in(n)) end
	elseif w == "HDG" then
		if n and n <= 360 then A.HSI.hdg = n % 360 end
	elseif w == "CRS" then
		if n and n <= 360 then A.HSI.crs = (n > 0) and n % 360 or nil end
	elseif w == "PLAT" then
		if #b ~= 5 or not n then pnt_msg("LAT: 5 DIGITS DDMMm"); return end
		local dd, mm = floor(n / 1000), (n % 1000) / 10
		if dd > 89 or mm >= 60 then pnt_msg("NO SUCH LATITUDE"); return end
		local sgn = (feed.own and (feed.own.lat or 0) < 0) and -1 or 1
		M.pnt_lat = sgn * (dd + mm / 60)
		M.entry, M.buf = {what = "PLON", len = 6, prompt = "LON E DDDMMm", page = ST.page}, ""
	elseif w == "PLON" then
		if #b ~= 6 or not n then pnt_msg("LON: 6 DIGITS DDDMMm"); return end
		local dd, mm = floor(n / 1000), (n % 1000) / 10
		if dd > 179 or mm >= 60 then pnt_msg("NO SUCH LONGITUDE"); return end
		local sgn = (feed.own and (feed.own.lon or 0) < 0) and -1 or 1
		pnt_pos_done(M.pnt_lat, sgn * (dd + mm / 60))
	end
end

---------------------------------------------------------------------------
-- the calls from mfd_device.lua
---------------------------------------------------------------------------
local PAGES = {
	[PG.FUEL] = function(t) page_fuel(t) end, [PG.COM] = function(t) page_com(t, false) end,
	[PG.COMK] = function(t) page_com(t, true) end, [PG.DTM] = function() page_dtc() end,
	[PG.FLT] = function() page_flt() end, [PG.PIC] = function(t, stale) page_pic(t, stale) end,
	[PG.RWR] = function(t) page_rwr(t) end, [PG.NAV] = function(t) page_nav(t) end,
	[PG.BCN] = function() page_bcn() end, [PG.PNT] = function(t) page_pnt(t) end,
	[PG.LND] = function(t) page_lnd(t) end, [PG.PFD] = function(t) page_pfd(t) end,
	[PG.LOFT] = function(t) page_loft(t) end,
}
-- (every update; the others 5 times a second, at once after a key)
local FAST = {[PG.RWR] = true, [PG.NAV] = true, [PG.LND] = true, [PG.PFD] = true, [PG.LOFT] = true, [PG.PIC] = true}
local LAST = {pg = nil}
---------------------------------------------------------------------------
-- SA scope (test 3, as the MiG-29 MFI): the FD arrow on the arc to the
-- active steerpoint, airfields on the scope
---------------------------------------------------------------------------
local Q = SIT_MFI.sa
local ARC = {}             -- [view] = the arc's directions that are on the page
-- where an arrow sits: on the arc at direction a (clockwise from up, from
-- the jet), or at the nearest point of the arc that is on the page
local function anchor(a, centred)
	local R = centred and Q.rc or Q.rd
	local oy = centred and 0 or Q.dy
	local key = centred and 1 or 2
	local L = ARC[key]
	if not L then
		L = {}
		for d = -180, 179 do
			local c = math.rad(d)
			local x, y = R * math.sin(c), R * math.cos(c) + oy
			if centred or (abs(x) <= Q.ptr_x and y <= Q.ptr_top and y >= Q.ptr_bot) then L[#L + 1] = c end
		end
		ARC[key] = L
	end
	local best, bd = a, nil
	for i = 1, #L do
		local d = abs((L[i] - a + math.pi) % (2 * math.pi) - math.pi)
		if d < math.rad(0.5) then best = a; bd = 0; break end
		if not bd or d < bd then best, bd = L[i], d end
	end
	return R * math.sin(best), R * math.cos(best), best
end
-- runway lines: magnetic designators, turned by the magnetic variation at
-- the jet when the sensors give both headings (else true = magnetic)
local AFS = {t = -10, list = {}, decl = 0}
local function af_handles()
	if AFS.h then return AFS.h end
	AFS.h = {}
	for n = 1, Q.af_max do
		local p = "M_AF" .. n .. "_"
		AFS.h[n] = {x = A.P(p .. "X"), y = A.P(p .. "Y"), vis = A.P(p .. "VIS"), n = A.P(p .. "N"),
			r = {A.P(p .. "R1"), A.P(p .. "R2"), A.P(p .. "R3")}}
	end
	return AFS.h
end
local function by_d(p, q) return p.d < q.d end
local function sa_airfields(t)
	local h = af_handles()
	local on = ST.rte and ST.dcl < 2 and not ST.exp
	if on and t - AFS.t >= 1 then
		AFS.t = t
		local L = {}
		for _, a in ipairs(airfields()) do
			local d = (a.x - G.ox) ^ 2 + (a.z - G.oz) ^ 2
			if d < (4 / G.k) ^ 2 then L[#L + 1] = {a = a, d = d} end
		end
		table.sort(L, by_d)
		AFS.list = L
		local m, hd = A.sd_val("getMagneticHeading"), A.sd_val("getHeading")
		if m and hd then
			local v = ((2 * math.pi - hd) - m + math.pi) % (2 * math.pi) - math.pi
			AFS.decl = (abs(v) < math.rad(40)) and v or 0
		end
	end
	local n = 0
	if on then
		local hdg = ST.nup and 0 or (G.hdg or 0)
		for _, c in ipairs(AFS.list) do
			if n >= Q.af_max then break end
			local sx, sy = A.to_screen(c.a.x - G.ox, c.a.z - G.oz)
			if A.inside(sx, sy) then
				n = n + 1
				local e = h[n]
				e.x:set(sx); e.y:set(sy); e.vis:set(1)
				local rw = c.a.rwy or {}
				e.n:set(#rw)
				for r = 1, 3 do
					if rw[r] then e.r[r]:set(-(math.rad(rw[r]) + AFS.decl - hdg)) end
				end
			end
		end
	end
	for k = n + 1, Q.af_max do h[k].vis:set(0) end
end
local function sa_scope(t)
	local w = (not ST.exp) and act_pt() or nil
	if w then
		local sx, sy = A.to_screen(w.x - G.ox, w.z - G.oz)
		local a = atan2(sx, sy)
		local x, y, c = anchor(a, ST.center)
		ns("M_SA_FDX", x); ns("M_SA_FDY", y); ns("M_SA_FDA", -c); ns("M_SA_FDT", -a); ns("M_SA_FDON", 1)
	else
		ns("M_SA_FDON", 0)
	end
	sa_airfields(t)
end

MFIDEV = {}
function MFIDEV.key(pg, b)
	-- an open keypad entry ends with any other key
	if M.entry and not (pg == M.entry.page) then M.entry = nil end
	local k = KEYS[pg]
	if not k then return false end
	local f = k[b]
	if f then
		local ok, err = pcall(f)
		if not ok then A.log("MFI key " .. b .. ": " .. tostring(err)) end
		A.PGF.now = true
		return true
	end
	-- SA / SETS / SMS: the classic page's own keys for the rest
	if pg == PG.SIT or pg == PG.SETS then return false end
	return true
end
function MFIDEV.draw(pg, t, stale)
	if pg == PG.SMS then page_sms(); return false end
	local f = PAGES[pg]
	if not f then return false end
	if FAST[pg] or A.PGF.now or LAST.pg ~= pg or A.tick() % 4 == 0 then
		A.PGF.now, LAST.pg = false, pg
		local ok, err = pcall(f, t, stale)
		if not ok and (M.err_n or 0) < 20 then M.err_n = (M.err_n or 0) + 1; A.log("MFI page " .. pg .. ": " .. tostring(err)) end
	end
	return true
end
function MFIDEV.sa(t, stale)
	local ok, err = pcall(sa_values, t, stale)
	if not ok and (M.err_n or 0) < 20 then M.err_n = (M.err_n or 0) + 1; A.log("MFI SA: " .. tostring(err)) end
	ok, err = pcall(sa_scope, t)
	if not ok and (M.err_n or 0) < 20 then M.err_n = (M.err_n or 0) + 1; A.log("MFI SA scope: " .. tostring(err)) end
end
function MFIDEV.every(t, stale)
	local pg = ST.page
	ns("M_RDO", (pg == PG.COM) and 1 or ((pg == PG.COMK) and 2 or 0))
	ns("M_EXP", ST.exp and 1 or 0)
	ns("M_MK_ANY", (#ST.marks > 0) and 1 or 0)
	if M.entry and M.entry.page ~= pg then M.entry, M.buf = nil, "" end
	if ST.add and pg ~= PG.NAV then ST.add = nil end          -- (NAV ADD ends off its page)
	pcall(nav_seq)
	local ok, err = pcall(alerts, t)
	if not ok and (M.err_n or 0) < 20 then M.err_n = (M.err_n or 0) + 1; A.log("MFI alerts: " .. tostring(err)) end
end
-- keypad: the MFI entries, the COM pages' manual frequency and fighter
-- channel, ИСТРЕБИТЕЛИ 2 = PICTURE (no RDR page)
function MFIDEV.keypad(k)
	local pg = ST.page
	if k == "F2" then ST.page = PG.PIC; return true end
	if M.entry and M.entry.page == pg then
		if KP_DIGIT[k] then M.buf = (M.buf .. KP_DIGIT[k]):sub(1, M.entry.len); return true end
		if k == "RST" then
			if M.buf == "" then M.entry = nil else M.buf = "" end
			return true
		end
		if k == "ENT" then pcall(entry_enter); return true end
		return false
	end
	if pg == PG.FUEL and k == "ENT" then
		local n = tonumber(ST.entry or "")
		ST.entry = ""
		if n then ST.bingo = math.min(9400, (n < 100) and n * 100 or n); A.msg("BINGO " .. ST.bingo) end
		return true
	end
	if pg == PG.COM or pg == PG.COMK then
		local band = (pg == PG.COM) and "ukv" or "kv"
		if ST.man_entry == band then
			if KP_DIGIT[k] then ST.entry = ((ST.entry or "") .. KP_DIGIT[k]):sub(1, A.MAN_LEN[band]); return true end
			if k == "ENT" then local e = ST.entry or ""; ST.entry = ""; A.man_enter(e); return true end
			return false
		end
		if k == "ENT" then
			local n = tonumber(ST.entry or "")
			ST.entry = ""
			if n then ST.fch = n % 128; A.msg("FIGHTER CH " .. ST.fch) end
			return true
		end
	end
	return false
end
A.log("MFI pages ready")
