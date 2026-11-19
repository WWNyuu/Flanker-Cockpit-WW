-----------------------------------------------------------------------
-- Su-27 MFD (WW): the MFD's device (v0.2). Based on the F-15C SIT (WW)
-- add-on's MPCD device: SA (its SIT page), MENU, DTC (its DTM), BIT,
-- TIME, OWN, FLIGHT, SETTINGS; plus the MiG-29 MFD's pages PICTURE, NAV,
-- HSI, COM, FUEL, SMS, RWR and RDR (the radar / EOS picture).
--
-- Own aircraft from get_base_data(); the picture (radar contacts,
-- datalink friendlies / hostiles, route, locked target, ground threats,
-- stores, RWR) from Scripts\S27MFD_Export.lua over UDP 127.0.0.1:42894,
-- the same picture rules as the MiG-29 add-on. The bullseye, map / date,
-- pylons and mission drawings come from Scripts\Hooks\S27MFD_hook.lua.
-- Everything goes to the page (MFD/indicator/mfd_page.lua) as cockpit
-- parameters S27MFD_*. Buttons: see ACTIONS below.
-- Log: Saved Games\DCS\Logs\s27mfd_device.log
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "devices.lua")
dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path .. "MFD/mfd_config.lua")
dofile(LockOn_Options.script_path .. "MFD/mfd_dtm.lua")

local dev = GetSelf()
make_default_activity(SIT.UPDATE)

local TWO_PI = 2 * math.pi
local NM, FT = SIT.RNG_M, 0.3048       -- NM: one range unit (km or NM, mfd_config.lua)
local floor, sqrt, sin, cos, atan2, abs = math.floor, math.sqrt, math.sin, math.cos, math.atan2, math.abs
-- a contact's altitude as the page shows it: km with one decimal / thousands of feet
local function alt_num(m)
	if SIT.METRIC then return floor((m or 0) / 100 + 0.5) / 10 end
	return floor((m or 0) / FT / 1000 + 0.5)
end
local function alt_str(m)
	if SIT.METRIC then return string.format("%.1f KM", (m or 0) / 1000) end
	return string.format("%dK", floor((m or 0) / FT / 1000 + 0.5))
end

---------------------------------------------------------------------------
-- log
---------------------------------------------------------------------------
local log_n = 0
local function log(msg)
	if log_n > 300 then return end
	log_n = log_n + 1
	pcall(function()
		local lfs = require("lfs")
		local f = io.open(lfs.writedir() .. "Logs/s27mfd_device.log", log_n == 1 and "w" or "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
	end)
end

---------------------------------------------------------------------------
-- parameters
---------------------------------------------------------------------------
-- v0.9: parameters are written only when their value changes (most of
-- the page stays the same from one update to the next)
local PH = {}
PH.__index = PH
function PH:set(v) if v ~= self.v then self.v = v; self.h:set(v) end end
function PH:get() return self.h:get() end
local function P(n) return setmetatable({h = get_param_handle("S27MFD_" .. n)}, PH) end
-- a text for a "%s" field: never number-like ("40", "8.6", "1e5", " 7"),
-- else DCS stores it as a number and crashes on the "%s" (access violation
-- in ceStringPoly::set_strcat_by_predefined_format)
local function safe_text(v)
	v = tostring(v or "")
	if tonumber(v) then v = "'" .. v end
	return v
end
-- text parameter: created and given a string in the same step (the page
-- draws on DCS's render thread while this file is still loading; a text
-- parameter that still holds the number 0 crashes DCS). v1.2: every
-- value set on a text parameter goes through safe_text, whatever the page
local PHT = {}
PHT.__index = PHT
function PHT:set(v) v = safe_text(v); if v ~= self.v then self.v = v; self.h:set(v) end end
function PHT:get() return self.h:get() end
local function PT(n)
	local h = setmetatable({h = get_param_handle("S27MFD_" .. n)}, PHT)
	h:set("")
	return h
end
-- the page stays hidden until this is 1 (set when everything is ready)
local READY = get_param_handle("S27MFD_READY")
READY:set(0)
local H = {
	own_y = P("OWN_Y"), center = P("CENTER"), rng = P("RNG"),
	page = P("PAGE"), dclt = P("DCLT"), lines = P("LINES"), fch = P("FCH"),
	net = PT("NET_TXT"), dtm = PT("DTM_TXT"),
	dl = P("DL"), rte = P("RTE"), thr = P("THR"),
	time = PT("TIME"), status = PT("STATUS"), stpt = PT("STPT_TXT"),
	rot = P("ROT"), own_rot = P("OWN_ROT"),
	st_vis = P("ST_VIS"), inv = {PT("INV1_TXT"), PT("INV2_TXT"), PT("INV3_TXT"), PT("INV4_TXT")}, inv_sel = P("INV_SEL"),
	chaff = P("CHAFF"), flare = P("FLARE"), master = PT("MASTER_TXT"),
	be = {x = P("BE_X"), y = P("BE_Y"), vis = P("BE_VIS"), on = P("BE_ON"), txt = PT("BE_TXT")},
	az = {},
	lk = {x = P("LK_X"), y = P("LK_Y"), vis = P("LK_VIS"), t1 = PT("LK_T1"), t2 = PT("LK_T2"), t3 = PT("LK_T3"), blk = P("LK_BLK")},
}
for k = 1, 2 do
	local p = "AZ" .. k .. "_"
	H.az[k] = {ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY"), vis = P(p .. "VIS")}
end
-- MPCD pages
H.crs = P("CRS"); H.zulu = P("ZULU")
H.rng_mode = P("RNG_MODE"); H.rngt = PT("RNG_TXT")
H.cur = {x = P("CUR_X"), y = P("CUR_Y"), vis = P("CUR_VIS")}
H.cur_sit = P("CUR_SIT"); H.autor = P("AUTOR")
H.pdt = {ax = P("PDT_AX"), ay = P("PDT_AY"), bx = P("PDT_BX"), by = P("PDT_BY"), vis = P("PDT_VIS")}
H.ics_fail = P("ICS_FAIL")
H.own_x = P("OWN_X")
H.geo = {}
for j = 1, SIT.GEO_SEGS do
	local p = "GS" .. j .. "_"
	H.geo[j] = {ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY"), vis = P(p .. "VIS")}
end
H.gb = {}
for b = 1, math.ceil(SIT.GEO_SEGS / 16) do H.gb[b] = P("GB" .. b) end      -- blocks of 16 pieces (page: hidden blocks cost nothing)
H.gl = {}
for k = 1, SIT.GEO_LABELS do
	local p = "GL" .. k .. "_"
	H.gl[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT")}
end
H.dtm_cart = PT("DTM_CART_TXT"); H.dtm_loaded = PT("DTM_LOADED_TXT")
H.hk = {PT("HK1_TXT"), PT("HK2_TXT"), PT("HK3_TXT"), PT("HK4_TXT")}
H.hk_vis = P("HK_VIS"); H.hk_col = P("HK_COL"); H.hkm = {x = P("HKM_X"), y = P("HKM_Y"), vis = P("HKM_VIS")}
H.aa_b = {PT("AA_B1_TXT"), PT("AA_B2_TXT"), PT("AA_B3_TXT")}
H.aa = {selvis = P("AA_SEL_VIS"), sel = PT("AA_SEL_TXT"), gun = P("AA_GUN"), chf = P("AA_CHF"), flr = P("AA_FLR"), ics = PT("AA_ICS_TXT")}
H.crs_l = {ax = P("CRS_AX"), ay = P("CRS_AY"), bx = P("CRS_BX"), by = P("CRS_BY"), vis = P("CRS_VIS")}
H.cmd = PT("CMD_TXT"); H.pf = PT("PF_TXT")
H.sta = {}
for n = 1, #SIT.STATIONS do H.sta[n] = {txt = PT("STA" .. n .. "_TXT"), vis = P("STA" .. n .. "_VIS")} end
H.trng = P("TRNG"); H.icsd = P("ICSD")
H.jg = {}
for g = 1, 5 do H.jg[g] = P("JG" .. g) end
H.jprog = P("JPROG"); H.jett = PT("JETT_TXT")
H.cm = {}; for k = 1, 6 do H.cm[k] = PT("CM" .. k .. "_TXT") end
H.msl = {}
for k = 1, SIT.MAX_MSL do
	local p = "MSL" .. k .. "_"
	H.msl[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), sym = P(p .. "SYM"), tx = P(p .. "TX"), ty = P(p .. "TY"), tvis = P(p .. "TVIS"),
		txt = PT(p .. "TXT"), l = {ax = P(p .. "LAX"), ay = P(p .. "LAY"), bx = P(p .. "LBX"), by = P(p .. "LBY"), vis = P(p .. "LVIS")}}
end
H.mk = {}
for k = 1, SIT.MAX_MARKS do
	local p = "MK" .. k .. "_"
	H.mk[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT")}
end
H.dcl_lv = PT("DCL_TXT"); H.dcl_pop = P("DCL_POP")
H.jpwr = P("JPWR")                           -- jet power 1/0, for the helmet device
H.boot = P("BOOT"); H.dim = P("DIM")          -- start-up screen phase, brightness cover (0..19)
if SIT.MFI then H.brt_pop = P("BRT_POP"); H.brt_txt = PT("BRT_TXT") end   -- (MFI: brightness shown after a change)
H.rad = {{}, {}}; H.rad_act = {}; H.rad_cur = {}; H.rad_vol = {}
for r = 1, 2 do
	for k = 1, 20 do H.rad[r][k] = PT("RAD" .. r .. "_" .. k .. "_TXT") end
	H.rad_act[r] = P("RAD" .. r .. "_ACT"); H.rad_cur[r] = PT("RAD" .. r .. "_CUR_TXT"); H.rad_vol[r] = PT("RAD" .. r .. "_VOL_TXT")
end
H.rad_edit = P("RAD_EDIT"); H.rad_etxt = PT("RAD_E_TXT"); H.rad_ecar = PT("RAD_EC_TXT"); H.rad_emsg = PT("RAD_EM_TXT")
H.rad_src = PT("RAD_SRC_TXT")
H.cm_row = P("CM_ROW"); H.cm_fld = P("CM_FLD"); H.cm_sel = PT("CM_SEL_TXT")
H.load = {}
for n = 1, #SIT.STATIONS + 2 do H.load[n] = PT("LOAD" .. n .. "_TXT") end
H.bit = {}
for n = 1, #SIT.BIT_ROWS do H.bit[n] = P("BIT" .. n) end
H.bit_mode = P("BIT_MODE"); H.bit_txt = PT("BIT_TXT")
H.td = {}
for n = 1, 6 do H.td[n] = PT("TD" .. n .. "_TXT") end
H.own = {}
for n = 1, 11 do H.own[n] = PT("OWN" .. n .. "_TXT") end
H.fs = {}
for k = 1, 4 do
	local p = "FS" .. k .. "_"
	H.fs[k] = {n = PT(p .. "N_TXT"), d = PT(p .. "D_TXT"), own = P(p .. "OWN"), sel = P(p .. "SEL"), empty = P(p .. "EMPTY")}
end
H.fmode = P("FLT_AUTO"); H.fhint = PT("FLT_HINT_TXT")
H.fc = {}
for k = 1, 5 do H.fc[k] = {txt = PT("FC" .. k .. "_TXT"), on = P("FC" .. k .. "_ON")} end
H.fc_pg = PT("FC_PG_TXT")
local ALL_TEXT = {}         -- every page text parameter, set to "" before the first frame
for _, h in ipairs({H.cmd, H.pf, H.jett, H.bit_txt, H.rngt, H.aa.sel, H.aa.ics, H.dtm_cart, H.dtm_loaded}) do ALL_TEXT[#ALL_TEXT + 1] = h end
for _, t in ipairs({H.load, H.td, H.own}) do for _, h in ipairs(t) do ALL_TEXT[#ALL_TEXT + 1] = h end end
for _, s in ipairs(H.sta) do ALL_TEXT[#ALL_TEXT + 1] = s.txt end
for _, s in ipairs(H.fc) do ALL_TEXT[#ALL_TEXT + 1] = s.txt end
for _, s in ipairs(H.fs) do ALL_TEXT[#ALL_TEXT + 1] = s.n; ALL_TEXT[#ALL_TEXT + 1] = s.d end
ALL_TEXT[#ALL_TEXT + 1] = H.fhint
ALL_TEXT[#ALL_TEXT + 1] = H.fc_pg
for _, t in ipairs({H.hk, H.aa_b}) do for _, h in ipairs(t) do ALL_TEXT[#ALL_TEXT + 1] = h end end
for _, g in ipairs(H.gl) do ALL_TEXT[#ALL_TEXT + 1] = g.txt end

local HC = {}
for n = 1, SIT.MAX_CONTACTS do
	local p = "C" .. n .. "_"
	HC[n] = {x = P(p .. "X"), y = P(p .. "Y"), typ = P(p .. "TYPE"), hdg = P(p .. "HDG"), col = P(p .. "COL"),
	         mov = P(p .. "MOV"), alt = P(p .. "ALT"), num = P(p .. "NUM")}
	-- MFI test 3: the label above the symbol (A<alt> R<range> / M<mach>)
	if SIT.MFI then HC[n].lbl = PT(p .. "LBL"); HC[n].lbm = PT(p .. "LBM") end
end
local HW = {}
for n = 1, SIT.MAX_WPTS do
	local p = "W" .. n .. "_"
	HW[n] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), num = P(p .. "NUM"), seg = P(p .. "SEG"),
	         ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY")}
end
local HG = {}
for g = 1, SIT.MAX_THREATS do
	local p = "G" .. g .. "_"
	local h = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT"), ring = P(p .. "RING"), rv = P(p .. "RV"), seg = {}}
	for j = 1, SIT.RING_SEGS do
		h.seg[j] = {ax = P(p .. "S" .. j .. "_AX"), ay = P(p .. "S" .. j .. "_AY"),
		            bx = P(p .. "S" .. j .. "_BX"), by = P(p .. "S" .. j .. "_BY"), vis = P(p .. "S" .. j .. "_VIS")}
	end
	HG[g] = h
end
-- Su-27 MFD: the unit, the alignment test, the keypad entry
H.on = P("ON"); H.align = P("ALIGN"); H.entry = PT("ENTRY_TXT")
H.mfi_tab = P("MFI_TAB"); H.mfi_sub = P("MFI_SUB"); H.flt_sel = P("FLT_SEL")   -- v1.3 MFI frame, FLIGHT R5 AUTO / CLR
H.nav_add = P("NAV_ADD"); H.manu = P("COM_MANU"); H.mank = P("COM_MANK"); H.nup = P("NUP"); H.form = P("FORM"); H.pic_bull = P("PIC_BULL"); H.rdrl = P("RDRL")
H.osb_lit, H.kp_lit = {}, {}
for n = 1, 20 do H.osb_lit[n] = P("OSB" .. n .. "_LIT") end
for k = 1, #MFD.KP_NAMES do H.kp_lit[k] = P("KP" .. k .. "_LIT") end
-- text rows of the PICTURE / NAV / HSI / COM / FUEL / SMS / RWR / RDR pages
H.row = {}
for i = 1, 14 do H.row[i] = {txt = PT("ROW" .. i .. "_TXT"), col = P("ROW" .. i .. "_COL"), box = P("ROW" .. i .. "_BOX")} end
-- RDR
H.rb = {}
for k = 1, 16 do local p = "RB" .. k .. "_"; H.rb[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), alt = P(p .. "ALT"), col = P(p .. "COL")} end
H.rdr_on = P("RDR_ON"); H.rdr_scan = P("RDR_SCAN"); H.rdr_r = {}
for k = 1, 4 do H.rdr_r[k] = P("RDR_R" .. k) end
H.rlk = {x = P("RLK_X"), y = P("RLK_Y"), vis = P("RLK_VIS")}
-- HSI
H.hsi = {rot = P("HSI_ROT"), crs = P("HSI_CRS"), dev = P("HSI_DEV"), brg = P("HSI_BRG"), bvis = P("HSI_BVIS"), hb = P("HSI_HB")}
-- FUEL
H.fuel = {frac = P("FUEL_FRAC"), bingo = P("FUEL_BINGO")}
-- SMS
H.sms = {}
for n = 1, 10 do H.sms[n] = {st = P("SMS" .. n .. "_ST"), txt = PT("SMS" .. n .. "_TXT"), typ = P("SMS" .. n .. "_TYP")} end
-- RWR
H.rwr = {}
for k = 1, 10 do local p = "RW" .. k .. "_"; H.rwr[k] = {x = P(p .. "X"), y = P(p .. "Y"), col = P(p .. "COL"), vis = P(p .. "VIS"), lck = P(p .. "LCK"), txt = PT(p .. "TXT")} end
for _, r in ipairs(H.row) do ALL_TEXT[#ALL_TEXT + 1] = r.txt end
for _, r in ipairs(H.sms) do ALL_TEXT[#ALL_TEXT + 1] = r.txt end
for _, r in ipairs(H.rwr) do ALL_TEXT[#ALL_TEXT + 1] = r.txt end
ALL_TEXT[#ALL_TEXT + 1] = H.entry
---------------------------------------------------------------------------
-- page state (changed by the buttons)
---------------------------------------------------------------------------
local ST = {rng = SIT.RANGE_DEFAULT, center = false, nup = false, form = false,   -- (1.3 test 17: SA starts decentred)
            rdr = true, dl = true, rte = true, thr = true,
            page = SIT.MFI and SIT.PG.SIT or 2,   -- 1 SA (SIT), 2 MENU, 3 DTC ... (v1.3 MFI: no MENU, starts on SA)
            mfi_last = {},                -- MFI: the page last shown in each page group
            dclt = false, lines = true, fch = 19,
            dtm_msg = "", dtm_t = -1000, dtm_done = "",
            crs = false, zulu = SIT.ZULU_DEFAULT, net_t = -1000, ipf_t = -1000,
            cmd = 1, pf = 1, trng = false, icsd = false,
            jprog = 1, jg = {[1] = {true, false, true, false, true}, [2] = {true, true, true, true, true}},
            ibit_t = -1000, bit_mode = 1,
            slot = {"OWN"}, slot_man = false, flt_page = 0, fsel = nil,   -- the flight: slots 1-4 (FLIGHT DATA page)
            exp = false,
            soi_sit = false,            -- castle up: the SIT page has the cursor (TDC) instead of the VSD
            autor = false, cm_row = 1, cm_fld = 1, dcl = 1, rch = {1, 1}, vol = {SIT.SRS_VOL_START or 80, SIT.SRS_VOL_START or 80}, marks = {},              -- AUTO RANGE: SIT range follows the VSD range
            mode = 2, brt = SIT.MFI and SIT_MFI.brt_start or SIT.BRT_STEPS,   -- (0 OFF, 1 NIGHT, 2 DAY: from unit_on / night), brightness step
            unit_on = MFD.START_ON, night = false, pwr_down = nil,   -- ВКЛ, ДЕНЬ / НОЧЬ
            stow = 0, stow_to = 0,      -- folded away (1) / in place (0)
            osb_t = {}, kp_t = {},      -- when each key was last pressed (alignment test)
            entry = "", entry_msg = nil, entry_t = nil,   -- keypad entry
            bingo = 1500, pic_bull = false,
            cart = 1, carts = nil,      -- DTM: choice (1 = MSN, 2.. = cartridge files)
            loaded = {name = "MSN"}}    -- the cartridge in use: {name, route, bull, geo} (nil fields = mission's)

local tick = 0                  -- updates so far
local PF = {n = 0, sum = 0, max = 0, t = nil, blocks = 0, on = false}   -- timing log (see update())
-- power: sw = the jet's electric power switch as we know it (nil = not
-- looked at yet), on = powered, disp = powered and knob not OFF, shown =
-- the page is up (start-up over), cmd = the power switch command
local PWR = {sw = nil, on = true, disp = true, shown = true, boot_t = nil, cmd = nil, ready = nil, n_log = 0}
local PGF = {now = true, last = nil}   -- MENU pages: redraw now (button pressed) / page last drawn

-- the flight on the FLIGHT DATA page (v1.1): slots 1-4, each "OWN" (the
-- ownship), a unit name or empty. AUTO: the ownship and its group in
-- unit-name order; any change on the page makes it manual. Kept in
-- Saved Games\DCS\Config\S27MFD_flight.txt:
--   #MODE=MAN / #MODE=AUTO, #SLOT<n>=OWN / #SLOT<n>=<unit name>
-- (before v1.1 the file held unit names, one per line: read as a manual flight)
local function flt_file()
	local ok, l = pcall(require, "lfs")
	return ok and l and (l.writedir() .. "Config/S27MFD_flight.txt") or nil
end
local function flt_load()
	local fn = flt_file()
	local f = fn and io.open(fn, "r")
	if not f then return end
	local old, own, slots, mode = {}, nil, {}, nil
	for raw in f:lines() do
		local line = raw:gsub("\r", "")
		local k, v = line:match("^#SLOT(%d)=(.+)$")
		if k then slots[tonumber(k)] = v
		elseif line:match("^#MODE=") then mode = line:match("^#MODE=(%u+)")
		elseif line:match("^#OWN=%d") then own = tonumber(line:match("^#OWN=(%d)"))
		elseif line ~= "" then old[#old + 1] = line end
	end
	f:close()
	if mode then
		ST.slot_man = mode == "MAN"
		if ST.slot_man then ST.slot = {} for k = 1, 4 do ST.slot[k] = slots[k] end end
	elseif #old > 0 or own then
		ST.slot_man, ST.slot = true, {}
		ST.slot[own or 1] = "OWN"
		table.sort(old)
		for _, nm in ipairs(old) do
			for k = 1, 4 do if not ST.slot[k] then ST.slot[k] = nm; break end end
		end
	end
end
local function flt_save()
	local fn = flt_file()
	local f = fn and io.open(fn, "w")
	if not f then return end
	f:write("#MODE=" .. (ST.slot_man and "MAN" or "AUTO") .. "\n")
	if ST.slot_man then
		for k = 1, 4 do if ST.slot[k] then f:write("#SLOT" .. k .. "=" .. ST.slot[k] .. "\n") end end
	end
	f:close()
end

---------------------------------------------------------------------------
-- own aircraft
---------------------------------------------------------------------------
local SD = nil
local function sensors()
	if SD then return SD end
	if get_base_data then
		local ok, d = pcall(get_base_data)
		if ok and d then SD = d end
	end
	if not SD and sensor_data then SD = sensor_data end
	return SD
end

---------------------------------------------------------------------------
-- feed from the export script
---------------------------------------------------------------------------
local feed = {rx = -1000, list = {}, wpts = {}, active = 0, lock = nil, thr = {}, status = 0,
              packets = 0, coal = 0, master = "", stores = nil, cm = nil,
              bull = nil,     -- bull = {red = {x, z} or nil, blue = {x, z} or nil}, from the hook
              radar = nil,    -- radar = {on, az, size, dist}: scan centre / width (rad), range scale (m)
              date = nil,     -- from the hook: {th, day, mon, year, start}
              own = nil,      -- {lat, lon, id, unit, pilot}
              fail = {},      -- failed systems (LoGetMCPState)
              flight = {},    -- friendly aircraft {x, z, y, vx, vz, unit, type, human, own (same group)}
              sta = {},       -- export stations {n, name, cl}
              pylons = nil,   -- from the hook: [pylon 1..11] = CLSID
              slot_map = {},  -- export station -> pylon (1..11 = 2A 2 2B 3 4 5 6 7 8B 8 8A), kept once found
              cur_sta = 0,
              mgeo = nil, mgeo_ver = nil}  -- mission drawings (hook): shapes {kw, name, x = {}, z = {}}     -- bull = {red = {x, z} or nil, blue = {x, z} or nil}, from the hook
local udp, udp_state = nil, "init"
local function open_udp()
	local ok_lfs, lfs_mod = pcall(require, "lfs")
	local root = (ok_lfs and lfs_mod and lfs_mod.currentdir and lfs_mod.currentdir()) or "."
	if not package.path:find(root .. "/LuaSocket/?.lua", 1, true) then
		package.path  = package.path .. ";" .. root .. "/LuaSocket/?.lua"
		package.cpath = package.cpath .. ";" .. root .. "/LuaSocket/?.dll"
	end
	local ok, socket = pcall(require, "socket")
	if not ok or not socket then udp_state = "no LuaSocket"; return end
	local u = socket.udp()
	u:settimeout(0)
	local r, err = u:setsockname("127.0.0.1", SIT.PORT)
	if not r then
		pcall(function() u:setoption("reuseaddr", true) end)
		r, err = u:setsockname("127.0.0.1", SIT.PORT)
	end
	if not r then udp_state = "port busy: " .. tostring(err); return end
	udp, udp_state = u, "listening"
end

local function now() return get_model_time and get_model_time() or 0 end

-- missiles by weapon name (from LoGetNameByType): a = R-77 (active), s = R-27
-- (medium range, letter M on the SA page), m = R-73 (short range, letter S)
local function store_class(name)
	name = (name or ""):upper()
	if name:find("R.?77") then return "a" end
	if name:find("R.?27") then return "s" end
	if name:find("R.?73") or name:find("R.?60") then return "m" end
	return nil
end
local MASTER = {NAV = "NAV", BVR = "A/A", CAC = "A/A", LNG = "A/A", VS = "A/A", BORE = "A/A",
                FI0 = "A/A", A2G = "A/G", OFF = ""}

---------------------------------------------------------------------------
-- EWR picture from server text messages (as the MiG-29 add-on, v1.7.8/9):
-- servers that block export still send "<server> EWR | Picture Report"
-- texts. The hook forwards them (S27MFDE); their rows become contacts,
-- placed from our position when the report came in, moved along their
-- heading (at most EWR_EXTRAP_S) and dropped after EWR_KEEP_S.
--   "... EWR | Friendly Picture Report" -> friendly, else hostile
--   row: TYPE BRG RNG NM ALT ft SPD Knts HDG [name / aspect] (or km, m, km/h)
---------------------------------------------------------------------------
EWR = {fr = nil, hs = nil, t_fr = nil, t_hs = nil, n = 0}
do
	local KT = 0.514444
	local LINE = "^%s*(.-)%s+(%d+)%s+([%d,%.]+)%s*(%a+)%s+(%-?[%d,%.]+)%s*(%a+)%s+([%d,%.]+)%s*([%a/]+)%s+(%d+)%s*(.-)%s*$"
	local U_RNG = {nm = 1852, km = 1000, m = 1}
	local U_ALT = {ft = 0.3048, feet = 0.3048, m = 1, km = 1000}
	local U_SPD = {kts = KT, knts = KT, knots = KT, kt = KT, kn = KT, kph = 1 / 3.6, kmh = 1 / 3.6, ["km/h"] = 1 / 3.6,
	               kmph = 1 / 3.6, mph = 0.44704, ["m/s"] = 1, mps = 1}
	local function num(s) return tonumber((s:gsub(",", ""))) end
	local function row(line)
		local ty, brg, rng, ur, alt, ua, spd, us, hdg, rest = line:match(LINE)
		if not ty or ty == "" or ty:upper() == "TYPE" then return nil end
		local fr, fa, fs = U_RNG[ur:lower()], U_ALT[ua:lower()], U_SPD[us:lower()]
		if not (fr and fa and fs) then return nil end
		brg, rng, alt, spd, hdg = tonumber(brg), num(rng), num(alt), num(spd), tonumber(hdg)
		if not (brg and rng and alt and spd and hdg) then return nil end
		return {type = ty, brg = brg, rng = rng * fr, alt = alt * fa, spd = spd * fs, hdg = hdg, rest = rest}
	end
	local function contacts(rows, code, t, ox, oz)
		local list = {}
		for _, r in ipairs(rows) do
			-- (a friendly right on top of us is our own jet)
			if not (code == 1 and r.rng < 1000) then
			local b, h = math.rad(r.brg), math.rad(r.hdg)
			list[#list + 1] = {code = code, x = ox + r.rng * math.cos(b), z = oz + r.rng * math.sin(b), y = r.alt,
			                   vx = r.spd * math.cos(h), vz = r.spd * math.sin(h), t = t, mx = SIT.EWR_EXTRAP_S,
			                   nm = r.type:sub(1, 10), ewr = true}
			end
		end
		return list
	end
	function EWR.on_packet(text, t, ox, oz)
		if not ox then return end
		local out, cur = {}, nil
		for line in tostring(text or ""):gmatch("[^\r\n]+") do
			local u = line:upper()
			if u:find("PICTURE", 1, true) and u:find("EWR", 1, true) then
				cur = u:find("FRIENDLY", 1, true) and "fr" or "hs"
				out[cur] = out[cur] or {}
			elseif cur then
				local r = row(line)
				if r then local l = out[cur]; l[#l + 1] = r end
			end
		end
		if out.fr then EWR.fr, EWR.t_fr = contacts(out.fr, 1, t, ox, oz), t end
		if out.hs then EWR.hs, EWR.t_hs = contacts(out.hs, 2, t, ox, oz), t end
		if out.fr or out.hs then EWR.n = EWR.n + 1 end
	end
	local function alive(tt, t) return tt and t >= tt and t - tt <= SIT.EWR_KEEP_S end
	function EWR.fresh(t) return alive(EWR.t_fr, t) or alive(EWR.t_hs, t) end
	-- the contacts to draw: the export's list; with no datalink picture in it
	-- (export blocked / stale) the EWR contacts are added
	local EMPTY, MC = {}, {}
	function EWR.merge(list, t, stale)
		if not SIT.EWR_ON then return stale and EMPTY or list end
		if EWR.t_fr and not alive(EWR.t_fr, t) then EWR.fr, EWR.t_fr = nil, nil end
		if EWR.t_hs and not alive(EWR.t_hs, t) then EWR.hs, EWR.t_hs = nil, nil end
		local base = stale and EMPTY or list
		if not (EWR.fr or EWR.hs) then return base end
		if MC.base == base and MC.fr == EWR.fr and MC.hs == EWR.hs then return MC.out end
		local out = base
		local dl = false
		for _, c in ipairs(base) do if (c.code or 0) < 10 then dl = true; break end end
		if not dl then
			out = {}
			for i, c in ipairs(base) do out[i] = c end
			for _, l in ipairs({EWR.fr or EMPTY, EWR.hs or EMPTY}) do for _, c in ipairs(l) do out[#out + 1] = c end end
		end
		MC.base, MC.fr, MC.hs, MC.out = base, EWR.fr, EWR.hs, out
		return out
	end
end

-- the SIT cursor's own movement while SIT has the cursor: the jet's TDC
-- slew axis (it reaches us) and the add-on's own "SIT Cursor" binds
SLEW = {kx = 0, ky = 0, ax = 0, ay = 0, rx = 0, ry = 0, seen = {}, n_seen = 0, cmds = nil}
function SLEW.dz(v)
	if math.abs(v) < SIT.SLEW_DEADZONE then return 0 end
	return v
end
local CUR_F = {}                                        -- (S27MFDC fields, reused: 20 packets a second)
local C_NAME = "^C" .. string.rep(",[^,]*", 7) .. ",([^,]*)$"   -- (a contact's name: field 8)
local function parse(data)
	if data:sub(1, 7) == "S27MFDV" then                  -- RWR (SPO-15) emitters from the export
		local list = {}
		for line in data:gmatch("[^\n]+") do
			local az, pw, st, l1, nm = line:match("^V,([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
			if tonumber(az) then
				list[#list + 1] = {az = tonumber(az), pw = tonumber(pw) or 0, st = tonumber(st) or 1, l1 = tonumber(l1) or 0, nm = nm or ""}
			end
		end
		feed.rwr, feed.rwr_t = list, now()
		return
	end
	if data:sub(1, 7) == "S27MFDB" then                  -- bullseye from the hook: red x,z, blue x,z
		local f = {}
		for v in data:gmatch(",([^,]*)") do f[#f + 1] = tonumber(v) or false end
		local b = {}
		if f[1] and f[2] then b.red = {f[1], f[2]} end
		if f[3] and f[4] then b.blue = {f[3], f[4]} end
		feed.bull = b
		return
	end
	if data:sub(1, 7) == "S27MFDW" then                  -- own missiles in flight from the export
		local list = {}
		for e in data:gmatch("|([^|]*)") do
			local f = {}
			for v in (e .. ","):gmatch("([^,]*),") do f[#f + 1] = v end
			-- typ, has missile, mx, mz, has target, tx, tz, tti (s, -1 = none)
			list[#list + 1] = {typ = f[1], m = f[2] == "1", mx = tonumber(f[3]), mz = tonumber(f[4]),
				tg = f[5] == "1", tx = tonumber(f[6]), tz = tonumber(f[7]), tti = tonumber(f[8]) or -1}
		end
		feed.msl, feed.msl_t = list, now()
		return
	end
	if data:sub(1, 7) == "S27MFDE" then                  -- EWR picture report text from the hook
		EWR.pending = data:sub(9)            -- placed in update(), from our position then
		return
	end
	if data:sub(1, 7) == "S27MFDR" then                  -- radio presets from the hook
		if data ~= feed.radio_raw then
			local parts = {}
			for s in (data .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = s end
			local r = {grp = parts[2], radios = {}}
			for k = 3, #parts do
				local list = {}
				for f in parts[k]:gmatch("[^,]+") do list[#list + 1] = f end
				r.radios[#r.radios + 1] = list
			end
			feed.radio_raw, feed.radio = data, r
		end
		return
	end
	if data:sub(1, 7) == "S27MFDP" then                  -- the jet's pylons from the hook: pylon=CLSID
		if data ~= feed.pylons_raw then
			local py = {}
			for n, cl in data:gmatch(",(%d+)=([^,]*)") do py[tonumber(n)] = cl end
			feed.pylons_raw, feed.pylons, feed.slot_map = data, py, {}
		end
		return
	end
	if data:sub(1, 7) == "S27MFDC" then                  -- radar cursor, 20 per second (export)
		local f, n = CUR_F, 0
		for v in data:gmatch(",([^,]*)") do n = n + 1; f[n] = tonumber(v) or 0 end
		for i = n + 1, #f do f[i] = nil end
		if n >= 7 then
			local c = feed.cur or {}
			c.on, c.tx, c.ty, c.dist, c.saz, c.az, c.size = f[1] == 1, f[2], f[3], f[4], f[5], f[6], f[7]
			c.chaff, c.flare, c.t = f[8], f[9], now()
			c.acq = f[10] or 0               -- (auto acquisition: 0 none, 1 SS, 2 LR, 3 helmet)
			feed.cur = c
		end
		return
	end
	if data:sub(1, 7) == "S27MFDL" then                  -- mission drawings from the hook
		local ver = data:match("^S27MFDL,([^\n]*)")
		if ver == feed.mgeo_ver then return end
		local shapes = {}
		for line in data:gmatch("[^\n]+") do
			local k = line:sub(1, 1)
			if (k == "A" or k == "L") and line:sub(2, 2) == "," then
				local name, rest = line:match("^.,([^,]*),(.*)$")
				local s = {kw = (k == "A") and "area" or "line", name = name or "", x = {}, z = {}}
				for x, z in (rest or ""):gmatch("([-%d%.]+),([-%d%.]+)") do s.x[#s.x + 1], s.z[#s.z + 1] = tonumber(x), tonumber(z) end
				if #s.x >= 2 then shapes[#shapes + 1] = s end
			end
		end
		feed.mgeo, feed.mgeo_ver = shapes, ver
		log("mission drawings: " .. #shapes)
		return
	end
	if data:sub(1, 7) == "S27MFDD" then                  -- map and date from the hook
		local th, dd, mm, yy, st = data:match("^S27MFDD,([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)")
		if th then feed.date = {th = th, day = tonumber(dd) or 0, mon = tonumber(mm) or 0, year = tonumber(yy) or 0, start = tonumber(st) or 0} end
		return
	end
	if data:sub(1, 8) ~= "S27MFD 1" then return end
	local t = now()
	local list, wpts, thr, lock, active, status = {}, {}, {}, nil, 0, 0
	local stores, cm, master, gun = nil, nil, "", false
	local own, fail, flight, sta, cur_sta = feed.own, {}, {}, {}, feed.cur_sta
	local coal = feed.coal
	local radar = nil
	local f = {}
	for line in data:gmatch("[^\n]+") do
		local k = line:sub(1, 1)
		for i = #f, 1, -1 do f[i] = nil end
		for v in line:gmatch(",([^,]*)") do local x = tonumber(v); if x ~= nil then f[#f + 1] = x end end
		if k == "C" and #f >= 7 then
			local nm = line:match(C_NAME)
			list[#list + 1] = {code = f[1], x = f[2], z = f[3], y = f[4], vx = f[5], vz = f[6], t = t - (f[7] or 0),
			                   nm = (nm and nm ~= "") and nm or nil}
		elseif k == "W" and #f >= 3 then
			wpts[#wpts + 1] = {x = f[1], z = f[2], num = f[3]}
		elseif k == "A" then
			active = f[1] or 0
		elseif k == "S" then
			status = f[1] or 0
		elseif k == "L" and #f >= 5 then
			-- (+ the launch envelope, metres: Raero, Rmin, Rpi, Rtr; 0 = none)
			lock = {x = f[1], z = f[2], y = f[3], vx = f[4], vz = f[5], t = t,
			        ra = f[6] or 0, rm = f[7] or 0, rp = f[8] or 0, rt = f[9] or 0}
		elseif k == "R" and #f >= 4 then
			-- R,on,scan centre az (rad),scan width (rad),range scale (m)[,TDC x,TDC y]
			radar = {on = f[1] == 1, az = f[2], size = f[3], dist = f[4], tx = f[5] or 0, ty = f[6] or 0,
			         ecm = f[7] == 1, scale_az = f[8] or math.rad(60)}
		elseif k == "O" then
			coal = f[1] or coal
		elseif k == "N" then
			local m, sub = line:match("^N,([%w_]*),?([%w_]*)")
			master = MASTER[(m or ""):upper()] or ""
			gun = (sub or ""):upper():find("GUN") ~= nil
		elseif k == "Y" and #f >= 2 then
			-- Y,station,count,CLSID,name
			stores = stores or {a = 0, m = 0, s = 0}
			local clsid, nm = line:match("^Y,[^,]*,[^,]*,([^,]*),(.*)$")
			local cl = store_class(nm)
			if cl then stores[cl] = stores[cl] + f[2] end
			sta[f[1]] = {n = f[2], name = nm or "", cl = clsid or ""}
		elseif k == "Z" and #f >= 3 then
			-- Z,gun shells,chaff,flares,current station
			cm = {gun = f[1], chaff = f[2], flare = f[3]}
			cur_sta = f[4] or 0
		elseif k == "P" then
			local la, lo, id, un, pn = line:match("^P,([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
			if tonumber(la) then own = {lat = tonumber(la), lon = tonumber(lo) or 0, id = tonumber(id) or 0, unit = un or "", pilot = pn or ""} end
		elseif k == "B" then
			for nm in line:gmatch(",([%w_]+)") do fail[nm] = true end
		elseif k == "F" then
			-- F,id,x,z,y,hdg,vx,vz,human,radar,jammer,own flight,type,unit name
			local id, x, z, y, hd, vx, vz, hu, rd, jm, of, ty, un = line:match("^F,([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
			if tonumber(x) then
				flight[#flight + 1] = {x = tonumber(x), z = tonumber(z), y = tonumber(y) or 0, vx = tonumber(vx) or 0,
				                       vz = tonumber(vz) or 0, unit = un or "", type = ty or "", human = hu == "1",
				                       own = of == "1"}
			end
		elseif k == "G" then
			local lbl, gx, gz, gr = line:match("^G,([^,]*),([^,]*),([^,]*),([^,]*)")
			local gy = line:match("^G,[^,]*,[^,]*,[^,]*,[^,]*,([^,]*)")
			if lbl and tonumber(gx) then thr[#thr + 1] = {lbl = lbl, x = tonumber(gx), z = tonumber(gz), ring = tonumber(gr) or 0,
				y = tonumber(gy) or 0} end
		end
	end
	feed.list, feed.wpts, feed.thr, feed.lock, feed.active, feed.status = list, wpts, thr, lock, active, status
	feed.coal, feed.master, feed.radar, feed.gun = coal, master, radar, gun
	if stores then stores.gun = cm and cm.gun or 0 end
	feed.stores, feed.cm = stores, cm
	feed.own, feed.fail, feed.flight, feed.sta, feed.cur_sta = own, fail, flight, sta, cur_sta
	feed.rx = t
	feed.packets = feed.packets + 1
	if feed.packets == 1 then
		log(string.format("first packet: %d contacts, %d waypoints, %d threats, status %d", #list, #wpts, #thr, status))
	end
end

local function read_udp()
	if not udp then return end
	for _ = 1, 20 do
		local data = udp:receive(32768)
		if not data then break end
		local ok, err = pcall(parse, data)
		if not ok and not feed.err then feed.err = true; log("packet error: " .. tostring(err)) end
	end
end

---------------------------------------------------------------------------
-- buttons
--   L1 RNG up   L2 RNG down   L3 CNTR/DCNT   L4 FORM   L5 HUP/NUP
--   R1 RDR      R2 DL         R3 (free)      R4 RTE    R5 MENU (later)
--   B1 THRT     B5 PACS (later)              top row: free (stations, later)
---------------------------------------------------------------------------
local function dtm_msg(busy, done)
	ST.dtm_msg, ST.dtm_done, ST.dtm_t = busy, done, now()
end
local PG = SIT.PG
-- DTM: cartridge choices (1 = MSN) and loading one
local function dtm_choices()
	ST.carts = SIT_DTM.list(feed.date and feed.date.th or "")
	if ST.cart > #ST.carts + 1 then ST.cart = 1 end
end
local function dtm_name(i)
	if i == 1 then return "MSN" end
	local c = ST.carts and ST.carts[i - 1]
	return c and c.name or "MSN"
end
local function dtm_apply()
	ST.work = nil
	if ST.cart == 1 then ST.loaded = {name = "MSN"}; ST.sit_act = nil; return true end
	local c = ST.carts and ST.carts[ST.cart - 1]
	if not c then return false end
	local d = c.data
	local L = {name = c.name}
	local r = SIT_DTM.route(d)
	if #r > 0 then L.route = r end
	L.bull = SIT_DTM.bull(d)
	L.geo = SIT_DTM.read_geo(c.name)
	local j = type(d.jtids) == "table" and d.jtids or {}
	if tonumber(j.fighter_channel) then ST.fch = floor(tonumber(j.fighter_channel)) % 128 end
	if j.own_tn then L.tn = tostring(j.own_tn) end
	if type(j.flight) == "table" then
		SIT_FLT_FROM_LIST(j.flight)
		ST.flt_ver = (ST.flt_ver or 0) + 1
		pcall(flt_save)
	end
	-- fuel: {"bingo": 1500} (kg)
	local fu = type(d.fuel) == "table" and d.fuel or {}
	if tonumber(fu.bingo) then ST.bingo = math.max(0, floor(tonumber(fu.bingo))) end
	local s = type(d.sit) == "table" and d.sit or {}
	for k, v in ipairs(SIT.RANGES_NM) do if v == tonumber(s.range) then ST.rng = k end end
	for k, v in ipairs(SIT.RANGES_DC_NM) do if v == tonumber(s.range) then ST.rng = k end end
	if s.center ~= nil then ST.center = s.center == true end
	if s.nup ~= nil then ST.nup = s.nup == true end
	if s.zulu ~= nil then ST.zulu = s.zulu == true end
	ST.loaded = L
	ST.sit_act = nil
	log("cartridge loaded: " .. c.name .. " (" .. #r .. " steerpoints, " .. #L.geo .. " drawings)")
	return true
end
-- FLIGHT DATA (v1.1): the flight in slots 1-4. L1..L5 list the friendly
-- aircraft; pick one, then a slot (R1..R4), or a slot, then an aircraft or
-- another slot (swap). CLR empties the picked slot, AUTO goes back to the
-- ownship and its group in unit-name order.
local function own_name() return feed.own and feed.own.unit or "" end
local AUTO_C = {src = nil, own = nil, slots = {"OWN"}}
local function slots_now()
	if ST.slot_man then return ST.slot end
	if AUTO_C.src == feed.flight and AUTO_C.own == own_name() then return AUTO_C.slots end
	local names = {{n = own_name(), own = true}}
	for _, a in ipairs(feed.flight or {}) do
		if a.own and a.unit ~= "" then names[#names + 1] = {n = a.unit} end
	end
	table.sort(names, function(p, q) return p.n < q.n end)
	local sl = {}
	for k = 1, math.min(4, #names) do sl[k] = names[k].own and "OWN" or names[k].n end
	AUTO_C.src, AUTO_C.own, AUTO_C.slots = feed.flight, own_name(), sl
	return sl
end
local function slot_of(unit)
	local sl = slots_now()
	for k = 1, 4 do if sl[k] == unit then return k end end
	return nil
end
local function flt_find(unit)
	for _, a in ipairs(feed.flight or {}) do if a.unit == unit then return a end end
	return nil
end
local function flt_changed(hint)
	ST.flt_ver = (ST.flt_ver or 0) + 1
	ST.fsel = nil
	if hint then ST.fhint, ST.fhint_t = hint, now() end
	flt_save()
end
-- any change by hand: the page's flight becomes manual (starting from what is shown)
local function freeze()
	if ST.slot_man then return end
	local sl = slots_now()
	ST.slot = {}
	for k = 1, 4 do ST.slot[k] = sl[k] end
	ST.slot_man = true
end
local function put_in_slot(unit, k)
	freeze()
	local j = slot_of(unit)
	local cur = ST.slot[k]
	ST.slot[k] = unit
	if j and j ~= k then ST.slot[j] = cur end
	flt_changed()
end
-- a cartridge's flight list (DTM READ): the ownship stays where it is
function SIT_FLT_FROM_LIST(list)
	local own = slot_of("OWN") or 1
	ST.slot, ST.slot_man = {}, true
	ST.slot[own] = "OWN"
	for _, nm in ipairs(list) do
		if type(nm) == "string" and nm ~= "" then
			for k = 1, 4 do if not ST.slot[k] then ST.slot[k] = nm; break end end
		end
	end
	flt_changed()
end
local FLT_CACHE = {src = nil, ver = -1, list = {}}
local function flt_members()
	if FLT_CACHE.src == feed.flight and FLT_CACHE.ver == (ST.flt_ver or 0) and FLT_CACHE.own == own_name() and not (not ST.slot_man and AUTO_C.src ~= feed.flight) then return FLT_CACHE.list end
	local m, sl = {}, slots_now()
	for k = 1, 4 do
		local v = sl[k]
		if v and v ~= "OWN" then
			local a = flt_find(v)
			if a then a.num = k; m[#m + 1] = a end
		end
	end
	FLT_CACHE.src, FLT_CACHE.ver, FLT_CACHE.own, FLT_CACHE.list = feed.flight, ST.flt_ver or 0, own_name(), m
	return m
end
local function flt_candidates() return feed.flight or {} end
local FLT_N = SIT.MFI and SIT_MFI.flt_per_page or 5     -- aircraft per FLIGHT page (MFI: L1-L4, L5 = MORE)
local function flt_pick(k)
	if k > FLT_N then return end
	local a = flt_candidates()[ST.flt_page * FLT_N + k]
	if not a or a.unit == "" then return end
	local sel = ST.fsel
	if sel and sel.s then put_in_slot(a.unit, sel.s)
	elseif sel and sel.c == a.unit then ST.fsel = nil
	else ST.fsel = {c = a.unit} end
end
local function flt_slot(k)
	local sel = ST.fsel
	if sel and sel.c then put_in_slot(sel.c, k)
	elseif sel and sel.s then
		if sel.s ~= k then
			freeze()
			ST.slot[k], ST.slot[sel.s] = ST.slot[sel.s], ST.slot[k]
			flt_changed()
		else ST.fsel = nil end
	elseif slots_now()[k] then ST.fsel = {s = k} end
end
local function flt_clr()
	local sel = ST.fsel
	local k = sel and (sel.s or slot_of(sel.c))
	if not k then ST.fsel = nil; return end
	if slots_now()[k] == "OWN" then ST.fsel = nil; ST.fhint, ST.fhint_t = "THE OWNSHIP STAYS IN THE FLIGHT", now(); return end
	freeze()
	ST.slot[k] = nil
	flt_changed()
end
local function flt_auto()
	ST.slot_man = false
	AUTO_C.src = nil
	flt_changed("AUTO: OWN GROUP IN NAME ORDER")
end
local function go(p) return function() ST.page = p end end
local function cycle(key, list) return function() ST[key] = ST[key] % #list + 1 end end
-- declutter: 1 FULL, 2 no lines / route / course line, 3 no data blocks,
-- 4 no threat rings, 5 also no radar coverage; shown for a moment on the SA page
local function dcl_step()
	ST.dcl = ST.dcl % #SIT.DCL_NAMES + 1
	ST.dcl_t = now()
end
-- SA range one step
local function sit_range(dir)
	local r0 = ST.rng
	ST.rng = math.max(1, math.min(#SIT.RANGES_NM, ST.rng + dir))
	if ST.rng ~= r0 then ST.autor = false; ST.form = false; ST.exp = false end
end
-- the bottom row of most pages: page shortcuts (as on the MiG-29 MFD)
local SHORT = {B1 = go(PG.SIT), B2 = go(PG.RDR), B3 = go(PG.MENU), B4 = go(PG.NAV), B5 = go(PG.RWR)}
local function with_short(t)
	for k, f in pairs(SHORT) do if t[k] == nil then t[k] = f end end
	return t
end
local pic_pick, nav_step, hsi_set, com_key, bingo_step    -- (pages, below)
local nav_add, nav_del, nav_rst, com_man
local ACTIONS = {
	[PG.SIT] = with_short({
		L1 = function() sit_range(1) end, L2 = function() sit_range(-1) end,
		L3 = function() ST.center = not ST.center; ST.form = false; ST.exp = false end,
		L4 = function() ST.nup = not ST.nup end,
		L5 = go(PG.SETS),
		R1 = function() wp_step(1) end, R2 = function() wp_step(-1) end,
		R3 = function() ST.autor = not ST.autor end,
		R4 = function() ST.form = not ST.form end,
		R5 = go(PG.PIC),
		T1 = function() dcl_step() end,
	}),
	[PG.SETS] = with_short({
		L1 = function() ST.dl = not ST.dl end,
		L2 = function() ST.rte = not ST.rte end,
		L3 = function() ST.thr = not ST.thr end,
		L4 = function() ST.lines = not ST.lines end,
		L5 = go(PG.SIT),
		R1 = function() ST.crs = not ST.crs end,
		R2 = function() dcl_step() end,
		R3 = function() ST.autor = not ST.autor end,
		R4 = function() ST.rdr = not ST.rdr end,
	}),
	[PG.MENU] = {
		L1 = go(PG.SIT), L2 = go(PG.RDR), L3 = go(PG.NAV), L4 = go(PG.HSI), L5 = go(PG.COM),
		R1 = go(PG.FUEL), R2 = go(PG.SMS), R3 = go(PG.FLT), R4 = go(PG.RWR),
		R5 = function() dtm_choices(); ST.page = PG.DTM end,
		T1 = go(PG.BIT), T2 = go(PG.TIME), T4 = go(PG.OWN), T5 = go(PG.PIC),
		B1 = function() ST.fch = (ST.fch + 127) % 128 end,
		B5 = function() ST.fch = (ST.fch + 1) % 128 end,
	},
	[PG.DTM] = {
		L1 = function()
			if dtm_apply() then dtm_msg("READ IN PROGRESS", "READ COMPLETE: " .. dtm_name(ST.cart):upper():sub(1, 16))
			else dtm_msg("READ IN PROGRESS", "READ FAIL") end
		end,
		L2 = function() dtm_choices(); ST.cart = (ST.cart - 2) % (#ST.carts + 1) + 1 end,
		L3 = function() dtm_choices(); ST.cart = ST.cart % (#ST.carts + 1) + 1 end,
		B3 = go(PG.MENU),
		R5 = go(PG.MENU),
	},
	[PG.BIT] = with_short({
		L1 = function() ST.bit_mode = 1 end,
		L2 = function() ST.bit_mode = 2; ST.ibit_t = now() end,
	}),
	[PG.TIME] = with_short({
		R1 = function() ST.zulu = true end,
		R2 = function() ST.zulu = false end,
	}),
	[PG.OWN] = with_short({}),
	[PG.FLT] = {
		L1 = function() flt_pick(1) end, L2 = function() flt_pick(2) end, L3 = function() flt_pick(3) end,
		L4 = function() flt_pick(4) end, L5 = function() flt_pick(5) end,
		R1 = function() flt_slot(1) end, R2 = function() flt_slot(2) end,
		R3 = function() flt_slot(3) end, R4 = function() flt_slot(4) end,
		B1 = function() ST.flt_page = math.max(0, ST.flt_page - 1) end,
		B2 = flt_clr,
		B3 = go(PG.MENU),
		B4 = function() ST.flt_page = ST.flt_page + 1 end,
		B5 = flt_auto,
		R5 = go(PG.MENU),
	},
	[PG.PIC] = with_short({
		L1 = function() ST.pic_bull = not ST.pic_bull end,
		L5 = go(PG.SIT),
		R1 = function() pic_pick(1) end, R2 = function() pic_pick(2) end, R3 = function() pic_pick(3) end,
		R4 = function() pic_pick(4) end, R5 = function() pic_pick(5) end,
	}),
	[PG.RDR] = with_short({}),
	[PG.NAV] = with_short({
		L1 = function() wp_step(1) end, L2 = function() wp_step(-1) end,
		L3 = function() nav_step(-1) end, L4 = function() nav_step(1) end,     -- list up / down
		L5 = function() ST.sit_act = nil end,                                  -- back to the jet's waypoint
		R1 = function() dtm_choices(); ST.page = PG.DTM end,
		R2 = function() nav_add() end, R3 = function() nav_del() end, R4 = function() nav_rst() end,
		R5 = go(PG.HSI),
	}),
	[PG.HSI] = with_short({
		L1 = function() hsi_set("crs", 1) end, L2 = function() hsi_set("crs", -1) end,
		L3 = function() hsi_set("hdg", 1) end, L4 = function() hsi_set("hdg", -1) end,
		L5 = function() hsi_set("auto", 0) end,
		R1 = function() wp_step(1) end, R2 = function() wp_step(-1) end,
		R5 = go(PG.NAV),
	}),
	[PG.COM] = with_short({
		L1 = function() com_key("UKV_CH_UP") end, L2 = function() com_key("UKV_CH_DN") end,
		L3 = function() com_key("UKV_VOL_UP") end, L4 = function() com_key("UKV_VOL_DN") end,
		R1 = function() com_key("KV_CH_UP") end, R2 = function() com_key("KV_CH_DN") end,
		R3 = function() com_key("KV_VOL_UP") end, R4 = function() com_key("KV_VOL_DN") end,
		L5 = function() com_man("ukv") end, R5 = function() com_man("kv") end,
	}),
	[PG.FUEL] = with_short({
		L1 = function() bingo_step(1) end, L2 = function() bingo_step(-1) end,
	}),
	[PG.SMS] = with_short({}),
	[PG.RWR] = with_short({}),
}
-- v1.3 MFI (MFD/mfd_mfi.lua): the top keys pick the page group, the bottom
-- keys the group's page, so the pages' own top / bottom functions move to
-- the sides: SA DCLT -> R5 (PIC is a bottom key), FLIGHT UP / DN -> L5 MORE
-- (4 aircraft per page), CLR / AUTO -> R5 (CLR while one is picked); the
-- fighter channel (was MENU) -> OWN DATA L1 / L2. Side keys that only went
-- to another page are gone.
if SIT.MFI then
	local A = ACTIONS
	A[PG.SIT].R5 = function() dcl_step() end
	A[PG.PIC].L5 = nil; A[PG.NAV].R5 = nil; A[PG.HSI].R5 = nil; A[PG.DTM].R5 = nil
	A[PG.FLT].L5 = function()
		local pages = math.max(1, math.ceil(#flt_candidates() / FLT_N))
		ST.flt_page = (ST.flt_page + 1) % pages
	end
	A[PG.FLT].R5 = function() if ST.fsel then flt_clr() else flt_auto() end end
	A[PG.OWN].L1 = function() ST.fch = (ST.fch + 1) % 128 end
	A[PG.OWN].L2 = function() ST.fch = (ST.fch + 127) % 128 end
end
-- MFI: a top / bottom key (name "T1".."T5" / "B1".."B5")
local function mfi_key(b)
	local M = SIT_MFI
	local n = tonumber(b:sub(2)) or 0
	local tab = M.where(ST.page)
	if b:sub(1, 1) == "T" then
		local tb = M.tabs[n]
		if not tb then return end
		if n == tab then
			ST.page = tb.subs[1][2]                         -- the group's key again: its first page
		else
			ST.page = ST.mfi_last[n] or tb.subs[1][2]
		end
		return
	end
	-- bottom: the page of the group shown; SA's 5th key: centre / decentre
	if ST.page == PG.SIT and n == 5 then ACTIONS[PG.SIT].L3(); return end
	local tb = tab and M.tabs[tab]
	local sub = tb and tb.subs[n]
	if sub then ST.page = sub[2] end
end
local to_export    -- (defined below)
local entry_key    -- (keypad, below)

-- the unit's own controls and the soft keys
local OSB_OF = {}       -- command -> soft key name (clicks and binds)
for n = 1, 20 do
	OSB_OF[MFD_CMD.OSB0 + n] = MFD.OSB_NAMES[n]
	OSB_OF[MFD_KEY.OSB0 + n] = MFD.OSB_NAMES[n]
end
local KP_OF = {}        -- command -> keypad key name
for _, name in ipairs(MFD.KP_NAMES) do KP_OF[KP_CMD[name]] = name end
local ARG_UP = {}       -- model argument -> when a bound key lets it come back out
local function press_arg(a)
	pcall(function() GetDevice(0):set_argument_value(a, 1) end)
	ARG_UP[a] = now() + 0.15
end
local function osb_index(name)
	for n, nm in ipairs(MFD.OSB_NAMES) do if nm == name then return n end end
	return 0
end

function SetCommand(command, value)
	PGF.now = true
	local v = tonumber(value) or 0
	-- the jet's electric power switch (a toggle; FC3 has no state for it)
	if PWR.cmd and command == PWR.cmd then
		if PWR.sw ~= nil then PWR.sw = not PWR.sw end
		if PWR.n_log < 10 then PWR.n_log = PWR.n_log + 1; log("electric power switch: " .. (PWR.sw and "on" or "off")) end
		return
	end
	-- ВКЛ: press = on, hold MFD.PWR_HOLD s = off (works without the jet's power)
	if command == MFD_CMD.PWR or command == MFD_KEY.PWR then
		if v > 0 then
			ST.pwr_down = now()
			if not ST.unit_on then ST.unit_on = true; log("MFD switched on") end
			if command == MFD_KEY.PWR then press_arg(MFD.ARG_PWR) end
		else
			ST.pwr_down = nil
		end
		return
	end
	if command == MFD_CMD.BRT_UP or command == MFD_KEY.BRT_UP then
		if v > 0 then ST.brt = math.min(SIT.BRT_STEPS, ST.brt + 1); ST.brt_t = now() end
		return
	end
	if command == MFD_CMD.BRT_DN or command == MFD_KEY.BRT_DN then
		if v > 0 then ST.brt = math.max(1, ST.brt - 1); ST.brt_t = now() end
		return
	end
	-- (MFI: day and night keep their own level, as the MiG-29 MFI)
	if command == MFD_CMD.DAY or command == MFD_KEY.DAY then
		if v > 0 then
			if SIT.MFI and ST.night then ST.brt_n = ST.brt; ST.brt = ST.brt_d or SIT_MFI.brt_start end
			ST.night = false; ST.brt_t = now()
		end
		return
	end
	if command == MFD_CMD.NIGHT or command == MFD_KEY.NIGHT then
		if v > 0 then
			if SIT.MFI and not ST.night then ST.brt_d = ST.brt; ST.brt = ST.brt_n or SIT_MFI.brt_start end
			ST.night = true; ST.brt_t = now()
		end
		return
	end
	if command == MFD_KEY.STOW then
		if v > 0 then
			ST.stow_to = (ST.stow_to > 0.5) and 0 or 1
			log(ST.stow_to > 0.5 and "MFD folded away (ED's HDD shows)" or "MFD back in place")
		end
		return
	end
	local b = OSB_OF[command]
	if b then
		if v > 0 then
			ST.osb_t[osb_index(b)] = now()
			if command > MFD_KEY.OSB0 and command <= MFD_KEY.OSB0 + 20 then press_arg(MFD.ARG_OSB0 + (command - MFD_KEY.OSB0)) end
		end
		if v <= 0 or not PWR.shown then return end      -- act on press, with the page up
		if SIT.MFI and (b:sub(1, 1) == "T" or b:sub(1, 1) == "B") then
			mfi_key(b)
			if log_n < 80 then log("MFI key " .. b .. " -> page " .. ST.page) end
			return
		end
		if SIT.MFI and MFIDEV and MFIDEV.key(ST.page, b) then
			if log_n < 80 then log("MFI button " .. b .. " on page " .. ST.page) end
			return
		end
		local a = ACTIONS[ST.page] and ACTIONS[ST.page][b]
		if a then a() end
		if log_n < 80 then log("button " .. b .. " on page " .. ST.page) end
		return
	end
	local k = KP_OF[command]
	if k then
		if v > 0 then
			for i, nm in ipairs(MFD.KP_NAMES) do if nm == k then ST.kp_t[i] = now() end end
			if PWR.shown then entry_key(k) end
		end
		return
	end
end
---------------------------------------------------------------------------
-- geometry
---------------------------------------------------------------------------
local G = {hdg = 0, k = 1, own_y = 0, ox = 0, oz = 0, c = 1, s = 0}
-- world offset (north, east, metres) -> page position relative to the ownship
-- (G.c / G.s: cos / sin of the heading, once per update; 1 / 0 north-up)
local function to_screen(dN, dE)
	local c, s, k = G.c, G.s, G.k
	return (dE * c - dN * s) * k, (dN * c + dE * s) * k
end
local function inside(sx, sy)
	return abs(sx + (G.own_x or 0)) <= SIT.BOX and abs(sy + G.own_y) <= SIT.BOX
end
-- clip a segment (relative to the ownship) to the box; nil if outside
-- (Liang-Barsky; no tables: it runs a few hundred times per update)
local function lb(p, q, t0, t1)
	if p == 0 then
		if q < 0 then return nil end
		return t0, t1
	end
	local r = q / p
	if p < 0 then
		if r > t1 then return nil elseif r > t0 then t0 = r end
	else
		if r < t0 then return nil elseif r < t1 then t1 = r end
	end
	return t0, t1
end
local function clip(x1, y1, x2, y2)
	local oy, ox = G.own_y, (G.own_x or 0)
	local B = SIT.BOX
	local ax, ay, bx, by = x1 + ox, y1 + oy, x2 + ox, y2 + oy
	-- both ends inside (the usual case): nothing to cut
	if abs(ax) <= B and abs(ay) <= B and abs(bx) <= B and abs(by) <= B then return x1, y1, x2, y2 end
	-- both beyond the same edge: nothing to draw
	if (ax < -B and bx < -B) or (ax > B and bx > B) or (ay < -B and by < -B) or (ay > B and by > B) then return nil end
	local dx, dy = bx - ax, by - ay
	local t0, t1 = 0, 1
	t0, t1 = lb(-dx, ax + B, t0, t1); if not t0 then return nil end
	t0, t1 = lb(dx, B - ax, t0, t1); if not t0 then return nil end
	t0, t1 = lb(-dy, ay + B, t0, t1); if not t0 then return nil end
	t0, t1 = lb(dy, B - ay, t0, t1); if not t0 then return nil end
	return ax + t0 * dx - ox, ay + t0 * dy - oy, ax + t1 * dx - ox, ay + t1 * dy - oy
end

local function brg_rng(dN, dE)
	local b = (floor(math.deg(atan2(dE, dN)) + 0.5) + 359) % 360 + 1
	return b, sqrt(dN * dN + dE * dE)
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local CONTACT_COL = {[1] = 1, [2] = 2, [3] = 3, [4] = 1, [5] = 4, [6] = 1}   -- 1 green 2 red 3 yellow 4 blue

local IDENT = {[1] = "FRIEND", [2] = "HOSTILE", [3] = "UNKNOWN", [4] = "AWACS", [5] = "FLIGHT", [6] = "FRIEND"}
local TAKE, SKIP, NOMEM = {}, {}, {}
-- MFI test 3: contact label as the MiG-29 MFI's (round 23): altitude and
-- range on top, Mach under them; never number-like (starts with A)
local function mfi_lbl(h, alt_m, dN, dE, vx, vz)
	if not h.lbl then return end
	local a
	if SIT.METRIC then a = string.format("A%.1f", (alt_m or 0) / 1000)
	else a = string.format("A%dK", floor((alt_m or 0) / FT / 1000 + 0.5)) end
	local hh = math.max(0, math.min(alt_m or 0, 11000))
	local m = sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2) / sqrt(401.874 * (288.15 - 0.0065 * hh))
	h.lbl:set(string.format("%s R%d", a, floor(sqrt(dN * dN + dE * dE) / NM + 0.5)))
	h.lbm:set(string.format("M%.2f", m))
end
local function draw_contacts(t, stale)
	local used = 0
	local list = EWR.merge(feed.list, t, stale)
	local members = stale and NOMEM or flt_members()
	-- flight members (v0.9): each takes the nearest friendly / unknown contact
	-- within FLT_MATCH_M; any other such contact that close is the same aircraft
	-- again (radar track + datalink report) and is not drawn. A member with
	-- no contact at all is drawn from its own position.
	for k in pairs(TAKE) do TAKE[k] = nil end
	for k in pairs(SKIP) do SKIP[k] = nil end
	for _, a in ipairs(members) do
		local best, bd = nil, SIT.FLT_MATCH_M
		for i, c in ipairs(list) do
			local b = (c.code or 0) % 10
			if b ~= 2 and b ~= 4 then
				local age = math.min(math.max(t - (c.t or t), 0), c.mx or 20)
				local d = math.max(abs(c.x + (c.vx or 0) * age - a.x), abs(c.z + (c.vz or 0) * age - a.z))
				if d < SIT.FLT_MATCH_M then
					SKIP[i] = true
					if d < bd then best, bd = i, d end
				end
			end
		end
		a.shown = best ~= nil
		if best then TAKE[best] = a; SKIP[best] = nil end
	end
	-- hook: the contact nearest the cursor, within HOOK_R of it
	local hook, hook_d = nil, SIT.HOOK_R          -- (the hooked contact and its place, no table per update)
	local hk_x, hk_z, hk_sx, hk_sy, hk_code, hk_num
	do
		for ci, c in ipairs(list) do
			if used >= SIT.MAX_CONTACTS then break end
			local code = c.code or 0
			if SKIP[ci] then code = 0 end
			local own_radar = code >= 10
			local show = (own_radar and ST.rdr) or (code ~= 13 and ST.dl)
			if code == 15 or TAKE[ci] then show = true end          -- own flight always
			if code == 0 then show = false end
			if show then
				local age = math.min(math.max(t - (c.t or t), 0), c.mx or 20)
				local cx, cz = c.x + (c.vx or 0) * age, c.z + (c.vz or 0) * age
				-- a flight member: drawn as own flight (cyan), with its number
				local num = 0
				local mem = TAKE[ci]
				if mem then code, num = own_radar and 15 or 5, mem.num end
				local sx, sy = to_screen(cx - G.ox, cz - G.oz)
				if inside(sx, sy) then
					-- a contact only in the datalink while the DL layer is off,
					-- but held by the radar: draw it as a radar contact
					if not mem then
						if own_radar and not ST.dl then code = 13 end
						if not own_radar and not ST.dl then code = 0 end
					end
					if code > 0 then
						used = used + 1
						local h = HC[used]
						h.typ:set(code)
						h.x:set(sx)
						h.y:set(sy)
						local dx, dy = to_screen(c.vx or 0, c.vz or 0)
						h.hdg:set(atan2(-dx, dy))
						h.mov:set((((c.vx or 0) ^ 2 + (c.vz or 0) ^ 2) > 25) and 1 or 0)
						h.col:set(CONTACT_COL[code % 10] or 3)
						h.alt:set(alt_num(c.y))
						h.num:set(num)
						mfi_lbl(h, c.y, cx - G.ox, cz - G.oz, c.vx, c.vz)
						if G.cur_sx then
							local dd = sqrt((sx - G.cur_sx) ^ 2 + (sy - G.cur_sy) ^ 2)
							if dd < hook_d then
								hook_d = dd
								hook, hk_x, hk_z, hk_sx, hk_sy, hk_code, hk_num = c, cx, cz, sx, sy, code, num
							end
						end
					end
				end
			end
		end
	end
	-- members with no contact: from their own position (F lines)
	for _, a in ipairs(members) do
		if not a.shown and used < SIT.MAX_CONTACTS then
			local sx, sy = to_screen(a.x - G.ox, a.z - G.oz)
			if inside(sx, sy) then
				used = used + 1
				local h = HC[used]
				h.typ:set(5); h.x:set(sx); h.y:set(sy)
				local dx, dy = to_screen(a.vx, a.vz)
				h.hdg:set(atan2(-dx, dy))
				h.mov:set(((a.vx ^ 2 + a.vz ^ 2) > 25) and 1 or 0)
				h.col:set(4); h.alt:set(alt_num(a.y)); h.num:set(a.num)
				mfi_lbl(h, a.y, a.x - G.ox, a.z - G.oz, a.vx, a.vz)
			end
		end
	end
	for n = used + 1, SIT.MAX_CONTACTS do HC[n].typ:set(0) end
	-- hooked contact: data block (top left) and a cyan mark
	if hook then
		local c = hook
		local b, r = brg_rng(hk_x - G.ox, hk_z - G.oz)
		local v = sqrt((c.vx or 0) ^ 2 + (c.vz or 0) ^ 2)
		local id = IDENT[hk_code % 10] or "TRACK"
		if hk_num > 0 then id = "FLIGHT " .. hk_num end
		H.hk[1]:set(safe_text(id .. ((c.nm and c.nm ~= "") and ("  " .. c.nm:sub(1, 10)) or "")))
		H.hk[2]:set(string.format("%03d/%d %s", b, floor(r / NM + 0.5), SIT.RNG_LBL))
		H.hk[3]:set(string.format("%s  %d %s", alt_str(c.y), floor(v * SIT.SPD_K + 0.5), SIT.SPD_LBL))
		local asp = "ASP ---"
		if v > 5 then
			local a = (math.deg(atan2(G.oz - hk_z, G.ox - hk_x) - atan2(c.vz, c.vx)) + 540) % 360 - 180
			asp = string.format("ASP %03d%s", floor(abs(a) + 0.5), a >= 0 and "R" or "L")
		end
		H.hk[4]:set(asp)
		H.hk_vis:set(1)
		H.hk_col:set(CONTACT_COL[hk_code % 10] or 3)
		H.hkm.x:set(hk_sx); H.hkm.y:set(hk_sy); H.hkm.vis:set(1)
	else
		H.hk_vis:set(0); H.hkm.vis:set(0)
	end
end

local function draw_lock(t, stale)
	local L = (not stale) and feed.lock or nil
	if not L then H.lk.vis:set(0); H.lk.blk:set(0); H.pdt.vis:set(0); return end
	local age = math.min(math.max(t - L.t, 0), 5)
	local lx, lz = L.x + L.vx * age, L.z + L.vz * age
	local sx, sy = to_screen(lx - G.ox, lz - G.oz)
	H.lk.vis:set(inside(sx, sy) and 1 or 0)
	H.lk.x:set(sx); H.lk.y:set(sy)
	-- line from the ownship to the primary designated target
	local ax, ay, bx, by = clip(0, 0, sx, sy)
	if ax then
		-- (flashes with the fly-out line while a missile is in flight)
		H.pdt.vis:set((G.msl_fly and not G.msl_flash) and 0 or 1); H.pdt.ax:set(ax); H.pdt.ay:set(ay); H.pdt.bx:set(bx); H.pdt.by:set(by)
	else
		H.pdt.vis:set(0)
	end
	local dN, dE = lx - G.ox, lz - G.oz
	local b, r = brg_rng(dN, dE)
	-- aspect: angle between the target's course and the line target -> us
	local asp = "---"
	local v = sqrt(L.vx * L.vx + L.vz * L.vz)
	if v > 5 then
		local crs = atan2(L.vz, L.vx)
		local back = atan2(-dE, -dN)
		local a = (math.deg(back - crs) + 540) % 360 - 180
		asp = string.format("%03d%s", floor(abs(a) + 0.5), a >= 0 and "R" or "L")
	end
	H.lk.blk:set(1)
	H.lk.t1:set(string.format("%03d/%d", b, floor(r / NM + 0.5)))
	H.lk.t2:set(alt_str(L.y))
	H.lk.t3:set("ASP " .. asp)
end

-- the route in use: the loaded cartridge's, else the mission's (MSN). The
-- jet's active waypoint (mission route) also selects the cartridge's.
-- v0.3: ST.work = the route edited on the NAV page (ADD / DEL), a copy
-- of the cartridge's or the mission's; until a cartridge is read or RTE RST
local function route_now() return ST.work or ST.loaded.route or feed.wpts end
-- a cartridge route the jet also flies (Route Tool preset): every
-- cartridge point has a jet waypoint within 1 NM. map: jet index -> cartridge index
local LINK = {r = nil, w = nil, map = nil}
local function route_link()
	local r, w = ST.loaded.route, feed.wpts
	if not r then return nil end
	if LINK.r == r and LINK.w == w then return LINK.map end
	local map, hit = {}, 0
	for i, p in ipairs(r) do
		for j, q in ipairs(w or {}) do
			if not map[j] and (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < 1852 * 1852 then map[j] = i; hit = hit + 1; break end
		end
	end
	LINK.r, LINK.w, LINK.map = r, w, (#r > 0 and hit == #r) and map or nil
	return LINK.map
end
-- the jet's active waypoint on the route the SIT shows
local function jet_active()
	local r = route_now()
	local a = feed.active or 0
	if r == ST.work then
		-- the edited route: the point at the jet's waypoint, else the first
		local w = (feed.wpts or {})[a]
		if w then for i, p in ipairs(r) do if (p.x - w.x) ^ 2 + (p.z - w.z) ^ 2 < 1852 * 1852 then return i end end end
		return (#r > 0) and 1 or 0
	end
	if r == feed.wpts then return a end
	local map = route_link()
	if map then return map[a] or 0 end
	return math.max(math.min(a, #r), #r > 0 and 1 or 0)
end
-- the SIT's active steerpoint: the jet's until WP+ / WP- (SIT page L1 / L2)
-- is pressed, then the SIT's own (the jet's waypoint is not touched);
-- back to the jet's when a cartridge (or MSN) is read
function active_now()
	local r = route_now()
	if not ST.sit_act then return jet_active() end
	if ST.sit_act > #r then ST.sit_act = #r end
	return ST.sit_act
end
function wp_step(dir)
	local r = route_now()
	if #r == 0 then return end
	local a = active_now()
	if a < 1 then a = (dir > 0) and 0 or 1 end
	ST.sit_act = (a - 1 + dir) % #r + 1
end
local ACT = {0, 0}
local function draw_route()
	G.act, G.act_txt = nil, ""
	local wpts, act = route_now(), active_now()
	local n = math.min(#wpts, SIT.MAX_WPTS)
	local px, py = nil, nil
	for i = 1, SIT.MAX_WPTS do
		local h = HW[i]
		local w = (ST.rte and ST.dcl < 2 and i <= n) and wpts[i] or nil
		if w then
			local sx, sy = to_screen(w.x - G.ox, w.z - G.oz)
			local active = (i == act)
			h.vis:set(inside(sx, sy) and (active and 2 or 1) or 0)
			h.x:set(sx); h.y:set(sy)
			h.num:set(floor(w.num or i))
			if px then
				local ax, ay, bx, by = clip(px, py, sx, sy)
				if ax then
					h.seg:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
				else
					h.seg:set(0)
				end
			else
				h.seg:set(0)
			end
			px, py = sx, sy
			if active then
				ACT[1], ACT[2] = sx, sy
				G.act = ACT
				local b, r = brg_rng(w.x - G.ox, w.z - G.oz)
				G.act_txt = string.format("%03d-%d", b, floor(r / NM + 0.5))
			end
		else
			h.vis:set(0); h.seg:set(0)
		end
	end
end

local RING_C, RING_S = {}, {}
for j = 0, SIT.RING_SEGS do
	local a = TWO_PI * j / SIT.RING_SEGS
	RING_C[j], RING_S[j] = cos(a), sin(a)
end
local function draw_threats(stale)
	local used = 0
	if ST.thr and ST.dcl < 4 and not stale then
		for _, g in ipairs(feed.thr) do
			if used >= SIT.MAX_THREATS then break end
			used = used + 1
			local h = HG[used]
			local dN, dE = g.x - G.ox, g.z - G.oz
			local sx, sy = to_screen(dN, dE)
			h.vis:set(inside(sx, sy) and 1 or 0)
			h.x:set(sx); h.y:set(sy)
			h.txt:set(safe_text(g.lbl))
			local inring = g.ring > 0 and (dN * dN + dE * dE) < g.ring * g.ring
			h.ring:set(g.ring > 0 and (inring and 2 or 1) or 0)
			-- the ring's line only when some of it is on the SIT area: not when
			-- it lies all outside the area, nor when it goes all around it
			local draw = false
			if g.ring > 0 then
				local B, R = SIT.BOX, g.ring * G.k
				local cx, cy = abs(sx + (G.own_x or 0)), abs(sy + G.own_y)
				local nx, ny = math.max(cx - B, 0), math.max(cy - B, 0)
				draw = (nx * nx + ny * ny <= R * R) and ((cx + B) ^ 2 + (cy + B) ^ 2 >= R * R)
			end
			h.rv:set(draw and (inring and 2 or 1) or 0)
			if draw then
				local px, py = to_screen(dN + g.ring * RING_C[0], dE + g.ring * RING_S[0])
				for j = 1, SIT.RING_SEGS do
					local qx, qy = to_screen(dN + g.ring * RING_C[j], dE + g.ring * RING_S[j])
					local s = h.seg[j]
					local ax, ay, bx, by = clip(px, py, qx, qy)
					if ax then
						s.vis:set(1); s.ax:set(ax); s.ay:set(ay); s.bx:set(bx); s.by:set(by)
					else
						s.vis:set(0)
					end
					px, py = qx, qy
				end
			end
		end
	end
	for g = used + 1, SIT.MAX_THREATS do
		HG[g].vis:set(0); HG[g].ring:set(0); HG[g].rv:set(0)
	end
end

local function draw_scope()
	-- (scale: G.k)
	-- radar coverage: the edges of the radar's scan, out to its range scale
	local rd = feed.radar
	if (now() - feed.rx) > SIT.STALE_S then rd = nil end
	local fc = feed.cur
	if fc and now() - fc.t < 1 then rd = fc end          -- (same field names: on, az, size, dist)
	local half = rd and (SIT.RADAR_SIZE_HALF and rd.size or rd.size / 2) or 0
	for k = 1, 2 do
		local s = (k == 1) and -1 or 1
		local h = H.az[k]
		local ax = nil
		local ay, bx, by
		if rd and rd.on and ST.rdr and ST.dcl < 5 and (rd.dist or 0) > 0 then
			local b = G.hdg + (rd.az or 0) + s * half
			local x, y = to_screen(cos(b) * rd.dist, sin(b) * rd.dist)
			ax, ay, bx, by = clip(0, 0, x, y)
		end
		if ax then
			h.vis:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
		else
			h.vis:set(0)
		end
	end
	-- the compass rose turns with the heading (heading-up)
	H.rot:set(ST.nup and 0 or G.hdg)
	-- north-up: the ownship symbol turns instead
	H.own_rot:set(ST.nup and -G.hdg or 0)
end

local function bull_now()
	if ST.loaded.bull then return ST.loaded.bull end
	local b = feed.bull
	return b and ((feed.coal == 1) and b.red or b.blue) or nil
end
local function draw_bull()
	local p = bull_now()
	if not p then
		H.be.vis:set(0); H.be.on:set(0); H.be.txt:set("")
		return
	end
	local sx, sy = to_screen(p[1] - G.ox, p[2] - G.oz)
	H.be.x:set(sx); H.be.y:set(sy)
	H.be.vis:set(inside(sx, sy) and 1 or 0)
	-- readout: the cursor from the bullseye (no cursor: own position from it)
	local cx, cz = G.cur_x or G.ox, G.cur_z or G.oz
	local brg, r = brg_rng(cx - p[1], cz - p[2])
	H.be.on:set(1)
	H.be.txt:set(string.format("%03d-%d", brg, floor(r / NM + 0.5)))
end

local INV_CL, INV_LETTER = {"a", "s", "m"}, {"R77:", "R27:", "R73:"}
local function draw_stores(stale)
	local s, cm = feed.stores, feed.cm
	if stale or not s or not cm then H.st_vis:set(0); H.master:set(""); return end
	H.st_vis:set(1)
	-- weapon inventory: R-77, R-27 and R-73 counts, G = gun rounds.
	-- The selected one boxed.
	local cur = feed.sta and feed.sta[feed.cur_sta or 0]
	local cur_cl = cur and cur.n > 0 and store_class(cur.name)
	local sel = 0
	for k, cl in ipairs(INV_CL) do
		local n = s[cl] or 0
		local txt = INV_LETTER[k] .. n
		H.inv[k]:set(txt)
		if not feed.gun and cur_cl == cl then sel = k * 10 + math.min(5, math.max(2, #txt)) end
	end
	local g = "G" .. floor(cm.gun or 0)
	H.inv[4]:set(g)
	if feed.gun then sel = 40 + math.min(4, math.max(2, #g)) end
	H.inv_sel:set(sel)
	H.chaff:set(cm.chaff or 0); H.flare:set(cm.flare or 0)
	H.master:set(safe_text(feed.master))
end

-- cursor: follows the VSD cursor (TDC). TDC y -1..1 = 0..range scale,
-- TDC x -1..1 = -+ the VSD's azimuth scale. Cyan readout = cursor from
-- the ownship (no cursor: active steerpoint), yellow = cursor from the bullseye
local function draw_cursor(stale)
	G.cur_x, G.cur_z, G.cur_sx, G.cur_sy = nil, nil, nil, nil
	if ST.soi_sit and ST.sc then
		-- SIT has the cursor: it moves on its own (TDC slew axis / binds)
		local dt = math.min(math.max(G.dt or 0.05, 0), 0.2)
		local rx, ry = SLEW.dz(SLEW.rx), SLEW.dz(SLEW.ry)
		-- SLEW_SCALE 1: crosses the SIT display as fast as the radar cursor
		-- crosses the radar display (about 0.93 of it per second at full stick)
		local spd = (SIT.SLEW_SCALE or 1) * 0.93 * 2 * SIT.BOX
		local px = (SLEW.kx + SLEW.dz(SLEW.ax) + rx) * spd * dt
		local py = (SLEW.ky + SLEW.dz(SLEW.ay) + ry) * spd * dt
		if px ~= 0 or py ~= 0 then
			-- page movement -> map movement (inverse of to_screen)
			local dE, dN
			if ST.nup then dE, dN = px, py
			else
				local c, s = cos(G.hdg), sin(G.hdg)
				dE, dN = px * c + py * s, py * c - px * s
			end
			ST.sc.n, ST.sc.e = ST.sc.n + dN / G.k, ST.sc.e + dE / G.k
		end
		local sx, sy = to_screen(ST.sc.n, ST.sc.e)
		-- keep it on the page
		local ax, ay = sx + (G.own_x or 0), sy + G.own_y
		local B = SIT.BOX - 0.03
		-- the range steps when the cursor is pushed into the top (out) or the
		-- bottom (in) edge, as the radar's range does
		if (ay > B and py > 0) or (ay < -B and py < 0) then
			local t = now()
			if t - (ST.bump_t or -10) > 0.7 then
				ST.bump_t = t
				local n = #SIT.RANGES_NM
				local r0 = ST.rng
				ST.rng = math.max(1, math.min(n, ST.rng + ((py > 0) and 1 or -1)))
				if ST.rng ~= r0 then ST.autor = false; ST.form = false; ST.exp = false end
			end
		end
		if abs(ax) > B or abs(ay) > B then
			ax, ay = math.max(-B, math.min(B, ax)), math.max(-B, math.min(B, ay))
			sx, sy = ax - (G.own_x or 0), ay - G.own_y
			local dE, dN
			if ST.nup then dE, dN = sx, sy
			else
				local c, s = cos(G.hdg), sin(G.hdg)
				dE, dN = sx * c + sy * s, sy * c - sx * s
			end
			ST.sc.n, ST.sc.e = dN / G.k, dE / G.k
		end
		G.cur_x, G.cur_z, G.cur_sx, G.cur_sy = G.ox + ST.sc.n, G.oz + ST.sc.e, sx, sy
		H.cur.x:set(sx); H.cur.y:set(sy); H.cur.vis:set(1); H.cur_sit:set(1)
		local brg, rr = brg_rng(ST.sc.n, ST.sc.e)
		H.stpt:set(string.format("%03d-%d", brg, floor(rr / NM + 0.5)))
		return
	end
	-- the 20 Hz cursor packet when it is fresh, else the once-a-second picture
	local fc = feed.cur
	local rd
	if fc and now() - fc.t < 1 then
		fc.scale_az = fc.saz            -- (the packet's names, as the picture's R line)
		rd = fc
	else rd = (not stale) and feed.radar or nil end
	if not rd or not rd.on or (rd.dist or 0) <= 0 then H.cur.vis:set(0); G.cur_s = nil; H.stpt:set(G.act_txt or ""); return end
	-- a little smoothing between packets (the window glides, no steps)
	local s = G.cur_s
	if s and abs(s.tx - rd.tx) < 0.3 and abs(s.ty - rd.ty) < 0.3 and s.dist == rd.dist then
		s.tx, s.ty = s.tx + (rd.tx - s.tx) * 0.6, s.ty + (rd.ty - s.ty) * 0.6
	else
		s = {tx = rd.tx, ty = rd.ty, dist = rd.dist}
		G.cur_s = s
	end
	local r = (s.ty + 1) / 2 * rd.dist
	local b = G.hdg + s.tx * rd.scale_az
	local cx, cz = G.ox + cos(b) * r, G.oz + sin(b) * r
	G.cur_x, G.cur_z = cx, cz
	local sx, sy = to_screen(cx - G.ox, cz - G.oz)
	G.cur_sx, G.cur_sy = sx, sy
	H.cur.x:set(sx); H.cur.y:set(sy)
	H.cur_sit:set(ST.soi_sit and 1 or 0)
	H.cur.vis:set(inside(sx, sy) and 1 or 0)
	local brg, rr = brg_rng(cx - G.ox, cz - G.oz)
	H.stpt:set(string.format("%03d-%d", brg, floor(rr / NM + 0.5)))
end

-- drawings (MENU: LINES): the loaded cartridge's .geo.txt, else the
-- mission's drawings of our side (MSN). 1 cyan (lines, areas), 2 red
-- (threat rings), 3 pink (suspected threat rings)
local GEO_C = {}
for j = 0, 24 do GEO_C[j] = {cos(TWO_PI * j / 24), sin(TWO_PI * j / 24)} end
-- (one piece: its two ends already on the page; n = pieces used so far)
local GEO = {n = 0, nl = 0}
local function geo_seg(ax, ay, bx, by, col)
	if GEO.n >= SIT.GEO_SEGS then return end
	local a1, a2, b1, b2 = clip(ax, ay, bx, by)
	if a1 then
		GEO.n = GEO.n + 1
		local h = H.geo[GEO.n]
		h.vis:set(col); h.ax:set(a1); h.ay:set(a2); h.bx:set(b1); h.by:set(b2)
	end
end
local function geo_label(x, z, txt, col)
	if GEO.nl >= SIT.GEO_LABELS or not txt or txt == "" then return end
	local sx, sy = to_screen(x - G.ox, z - G.oz)
	if not inside(sx, sy) then return end
	GEO.nl = GEO.nl + 1
	local h = H.gl[GEO.nl]
	h.x:set(sx); h.y:set(sy); h.vis:set(col); h.txt:set(safe_text(txt:upper():sub(1, 12)))
end
-- a shape's extent (metres), once: shapes far off the SIT area are skipped
local function geo_box(s)
	if s.bb then return s.bb end
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for j = 1, #s.x do
		local x, z = s.x[j], s.z[j]
		if x < x0 then x0 = x end; if x > x1 then x1 = x end
		if z < z0 then z0 = z end; if z > z1 then z1 = z end
	end
	if s.kw == "ring" then x0, x1, z0, z1 = x0 - s.r, x1 + s.r, z0 - s.r, z1 + s.r end
	s.bb = {x0, x1, z0, z1}
	return s.bb
end
local function draw_geo()
	local shapes = (ST.lines and ST.dcl < 2) and (ST.loaded.geo or feed.mgeo) or nil
	GEO.n, GEO.nl = 0, 0
	if shapes then
		-- the SIT area in metres around its centre (a circle around the square)
		local vr = SIT.BOX * 1.42 / G.k
		-- page centre (0,0) is -own_x, -own_y from the ownship on the page: back to metres
		local px, py = -(G.own_x or 0), -G.own_y
		local cN, cE = G.ox + (py * G.c - px * G.s) / G.k, G.oz + (px * G.c + py * G.s) / G.k
		for _, s in ipairs(shapes) do
			local bb = geo_box(s)
			local nx = math.max(bb[1] - cN, 0, cN - bb[2])
			local nz = math.max(bb[3] - cE, 0, cE - bb[4])
			if nx * nx + nz * nz <= vr * vr then
				if s.kw == "ring" then
					local col = s.dashed and 3 or 2
					local x0, z0, r = s.x[1], s.z[1], s.r
					local ax, ay = to_screen(x0 + r * GEO_C[0][1] - G.ox, z0 + r * GEO_C[0][2] - G.oz)
					for j = 1, 24 do
						local bx, by = to_screen(x0 + r * GEO_C[j][1] - G.ox, z0 + r * GEO_C[j][2] - G.oz)
						geo_seg(ax, ay, bx, by, col)
						ax, ay = bx, by
					end
					geo_label(x0, z0, s.name, col)
				else
					local fx, fy = to_screen(s.x[1] - G.ox, s.z[1] - G.oz)
					local ax, ay = fx, fy
					for j = 2, #s.x do
						local bx, by = to_screen(s.x[j] - G.ox, s.z[j] - G.oz)
						geo_seg(ax, ay, bx, by, 1)
						ax, ay = bx, by
					end
					if s.kw == "area" and #s.x > 2 then geo_seg(ax, ay, fx, fy, 1) end
					geo_label(s.x[1], s.z[1], s.name, 1)
				end
			end
		end
	end
	local n, nl = GEO.n, GEO.nl
	for j = n + 1, SIT.GEO_SEGS do H.geo[j].vis:set(0) end
	for b = 1, #H.gb do H.gb[b]:set((n >= (b - 1) * 16 + 1) and 1 or 0) end
	for k = nl + 1, SIT.GEO_LABELS do H.gl[k].vis:set(0) end
end

-- course line to the active steerpoint (MENU: CRS STR)
local function draw_crs()
	local h = H.crs_l
	local a = (ST.crs and ST.dcl < 2) and G.act or nil
	local ax, ay, bx, by = nil, nil, nil, nil
	if a then ax, ay, bx, by = clip(0, 0, a[1], a[2]) end
	if ax then
		h.vis:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
	else
		h.vis:set(0)
	end
end

---------------------------------------------------------------------------
-- MENU pages
---------------------------------------------------------------------------
-- which pylon each export station is on. The export's station order is
-- not the jet's: matched by CLSID against the mission's pylons (hook), else
-- by store type (tanks 5 / 2 / 8, AIM-9 on the rails, AIM-120 / AIM-7 on
-- the fuselage first). A station keeps its pylon once found, so a station
-- that has fired (no name any more) stays where it was.
local FILL = {FUEL = {5, 6}, SRM = {1, 10, 2, 9, 3, 8}, AMRM = {3, 8, 4, 7, 5, 6, 2, 9}, MRM = {3, 8, 4, 7, 5, 6, 2, 9},
              STORE = {5, 6, 4, 7, 3, 8, 2, 9}}
local category
local function slots()
	local map, used = feed.slot_map, {}
	if #feed.sta == 0 then return {}, {} end
	if feed.sta_n ~= #feed.sta then feed.sta_n = #feed.sta; feed.slot_map = {}; map = feed.slot_map end
	for _, n in pairs(map) do used[n] = true end
	local py = feed.pylons
	if py then
		for i, s in ipairs(feed.sta) do
			if not map[i] and s.cl ~= "" then
				for n = 1, #SIT.STATIONS do
					if not used[n] and py[n] == s.cl then map[i] = n; used[n] = true; break end
				end
			end
		end
	end
	-- Su-27: without the mission's pylons (hook) the export's 10 stations are
	-- taken as pylons 1..10
	if not py and #feed.sta == #SIT.STATIONS then
		for i = 1, #feed.sta do if not map[i] and not used[i] then map[i] = i; used[i] = true end end
	end
	for i, s in ipairs(feed.sta) do
		if not map[i] and s.n > 0 and s.name ~= "" then
			for _, n in ipairs(FILL[category(s.name)] or {}) do
				if not used[n] then map[i] = n; used[n] = true; break end
			end
		end
	end
	local out, of = {}, {}
	for i, n in pairs(map) do out[n] = feed.sta[i]; of[i] = n end
	return out, of
end


local MON = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}
-- store names (LoGetNameByType) -> PACS labels: AIM-120B -> 120B, AIM-9M -> 9M, tank -> FUEL
local function short_name(nm)
	nm = (nm or ""):upper()
	if nm == "" then return "" end
	if nm:find("FUEL") or nm:find("TANK") or nm:find("GAL") then return "FUEL" end
	local s = nm:match("AIM[%-_ ]?(%d+%a*)")
	if s then return s end
	s = nm:gsub("[^%w%-]", "")
	return s:sub(1, 6)
end
function category(nm)
	nm = (nm or ""):upper()
	if nm:find("R.?77") then return "AMRM" end
	if nm:find("R.?27") then return "MRM" end
	if nm:find("R.?73") or nm:find("R.?60") then return "SRM" end
	if nm:find("FUEL") or nm:find("TANK") or nm:find("GAL") then return "FUEL" end
	return "STORE"
end
local function fmt_ll(v, pos, neg, degw)
	local hemi = (v >= 0) and pos or neg
	v = abs(v)
	local dg = floor(v)
	return string.format("%s %0" .. degw .. "d %06.3f", hemi, dg, (v - dg) * 60)
end
local function hms(s)
	s = math.max(0, floor(s))
	return string.format("%02d:%02d:%02d", floor(s / 3600) % 100, floor(s / 60) % 60, s % 60)
end
local function sd_val(name)
	local sd = sensors()
	local f = sd and sd[name]
	if not f then return nil end
	local ok, v = pcall(f)
	return ok and tonumber(v) or nil
end

local function page_bit(t, stale)
	local testing = ST.bit_mode == 2 and (t - ST.ibit_t) < 6
	local bad = 0
	for n, row in ipairs(SIT.BIT_ROWS) do
		local nogo = false
		for k = 2, #row do if feed.fail[row[k]] then nogo = true end end
		if nogo then bad = bad + 1 end
		H.bit[n]:set(testing and 0 or (nogo and 2 or 1))
	end
	H.bit_mode:set(ST.bit_mode)
	if testing then H.bit_txt:set("IBIT IN PROGRESS")
	elseif stale then H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": NO DATA")
	elseif bad == 0 then H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": ALL GO")
	else H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": " .. bad .. " NO GO") end
end

local function page_time(t)
	local tod = G.tod or 0
	local dt = feed.date
	local off = dt and SIT.UTC_OFFSET[dt.th]
	H.td[1]:set("LOCAL    " .. hms(tod % 86400))
	H.td[2]:set(off and ("ZULU     " .. hms((tod - off * 3600) % 86400) .. "Z") or "ZULU     --:--:--")
	local date_txt = "DATE     ----"
	if dt and dt.year > 0 then
		local ok, s = pcall(function()
			local d = os.date("*t", os.time({year = dt.year, month = dt.mon, day = dt.day + floor(tod / 86400), hour = 12}))
			return string.format("DATE     %02d %s %04d", d.day, MON[d.month] or "---", d.year)
		end)
		if ok and s then date_txt = s end
	end
	H.td[3]:set(date_txt)
	H.td[4]:set("ELAPSED  " .. hms(t))
	H.td[5]:set("MAP      " .. ((dt and dt.th ~= "") and dt.th:upper() or "----"))
	H.td[6]:set(off and string.format("UTC %+.1f H", off) or "")
	H.zulu:set(ST.zulu and 1 or 0)
end

local function page_own()
	local o = feed.own
	local fuel = sd_val("getTotalFuelWeight")
	local alt = sd_val("getBarometricAltitude")
	local ias = sd_val("getIndicatedAirSpeed")
	local mach = sd_val("getMachNumber")
	local okm, mh = pcall(function() return sensors().getMagneticHeading() end)
	local rows = {
		"CALLSIGN " .. ((o and o.unit ~= "") and o.unit:sub(1, 18) or "----"),
		"PILOT    " .. ((o and o.pilot ~= "") and o.pilot:sub(1, 18) or "----"),
		"TN       " .. ((ST.loaded.tn and ST.loaded.tn:sub(1, 5)) or (o and string.format("%05o", (floor(o.id) % 32749 + floor(o.id / 32768) * 7 + 1) % 32768)) or "-----"),
		"LAT      " .. (o and fmt_ll(o.lat, "N", "S", 2) or "----"),
		"LON      " .. (o and fmt_ll(o.lon, "E", "W", 3) or "----"),
		"ALT      " .. (alt and (SIT.METRIC and string.format("%d M", floor(alt + 0.5)) or string.format("%d FT", floor(alt / FT + 0.5))) or "----"),
		"HDG      " .. ((okm and mh) and string.format("%03d M", (floor(math.deg(mh) + 0.5) - 1) % 360 + 1) or "----"),
		"IAS      " .. (ias and string.format("%d %s", floor(ias * SIT.SPD_K + 0.5), SIT.SPD_LBL) or "----") ..
			(mach and string.format("   M %.2f", mach) or ""),
		"FUEL     " .. (fuel and string.format("%d KG", floor(fuel + 0.5)) or "----"),
		"BULL     " .. ((H.be.on:get() or 0) > 0 and "" or "----"),
		"STPT     " .. "",
	}
	local b = bull_now()
	if b then
		local brg, r = brg_rng(G.ox - b[1], G.oz - b[2])
		rows[10] = string.format("BULL     %03d/%d", brg, floor(r / NM + 0.5))
	end
	local w = route_now()[active_now()]
	if w then
		local brg, r = brg_rng(w.x - G.ox, w.z - G.oz)
		rows[11] = string.format("STPT %-3d %03d/%d", floor(w.num or 0), brg, floor(r / NM + 0.5))
	else
		rows[11] = "STPT     ----"
	end
	for n = 1, #H.own do H.own[n]:set(safe_text(rows[n] or "")) end
end

local function page_flt()
	local sl, sel = slots_now(), ST.fsel
	-- L1..L5: friendly aircraft, their slot number in front, boxed = picked
	local cand = flt_candidates()
	local pages = math.max(1, math.ceil(#cand / FLT_N))
	if ST.flt_page >= pages then ST.flt_page = pages - 1 end
	for k = 1, 5 do
		local a = (k <= FLT_N) and cand[ST.flt_page * FLT_N + k] or nil
		local n = a and slot_of(a.unit)
		H.fc[k].txt:set(a and safe_text((n and tostring(n) or "-") .. " " .. a.unit:sub(1, 13) .. (a.human and "*" or "")) or "")
		H.fc[k].on:set((a and sel and sel.c == a.unit) and 1 or 0)
	end
	H.fc_pg:set(#cand == 0 and "NO FRIENDLIES" or safe_text(string.format("PAGE %d/%d", ST.flt_page + 1, pages)))
	-- R1..R4: the slots
	for k = 1, 4 do
		local v, h = sl[k], H.fs[k]
		h.own:set(v == "OWN" and 1 or 0)
		h.sel:set((sel and sel.s == k) and 1 or 0)
		h.empty:set(v and 0 or 1)
		if v == "OWN" then
			local nm = own_name()
			h.n:set(safe_text(nm ~= "" and nm:sub(1, 18) or "OWNSHIP"))
			local alt, ias = sd_val("getBarometricAltitude"), sd_val("getIndicatedAirSpeed")
			h.d:set(safe_text("OWNSHIP   " .. (alt and alt_str(alt) or "") ..
				(ias and string.format("   %d %s", floor(ias * SIT.SPD_K + 0.5), SIT.SPD_LBL) or "")))
		elseif v then
			h.n:set(safe_text(v:sub(1, 18)))
			local a = flt_find(v)
			if a then
				local b, r = brg_rng(a.x - G.ox, a.z - G.oz)
				local gs = sqrt(a.vx * a.vx + a.vz * a.vz) * SIT.SPD_K
				h.d:set(safe_text(string.format("%03d/%d %s   %s   %d %s", b, floor(r / NM + 0.5), SIT.RNG_LBL, alt_str(a.y), floor(gs + 0.5), SIT.SPD_LBL)))
			else
				h.d:set("NOT ON THE DATALINK")
			end
		else
			h.n:set("EMPTY"); h.d:set("")
		end
	end
	H.fmode:set(ST.slot_man and 0 or 1)
	local hint
	if sel and sel.c then hint = safe_text(sel.c:sub(1, 14) .. ": PRESS A SLOT")
	elseif sel and sel.s then hint = "SLOT " .. sel.s .. ": SLOT OR AIRCRAFT, CLR"
	elseif ST.fhint and now() - (ST.fhint_t or -10) < 3 then hint = ST.fhint
	else hint = "PICK AN AIRCRAFT, THEN A SLOT" end
	H.fhint:set(hint)
end

---------------------------------------------------------------------------
-- Su-27 pages after the MiG-29 MFD's: PICTURE, RDR, NAV, HSI, COM, FUEL,
-- SMS, RWR. Text pages use the page's 14 rows (ROWn_TXT, colour ROWn_COL:
-- 1 white 2 green 3 red 4 amber 5 cyan 6 grey 7 yellow; ROWn_BOX = boxed).
---------------------------------------------------------------------------
local ROWS_N = 14
local function rows_clear(from)
	for i = from or 1, ROWS_N do local r = H.row[i]; r.txt:set(""); r.col:set(0); r.box:set(0) end   -- colour 0 = row hidden
end
local function row(i, txt, col, box)
	local r = H.row[i]
	if not r then return end
	r.txt:set(safe_text(txt)); r.col:set(col or 1); r.box:set(box and 1 or 0)
end
local function rng_txt(m) return string.format("%d", floor(m / NM + 0.5)) end
-- altitude inside a longer row (no unit: the rows say it)
local function alt_txt(m)
	if SIT.METRIC then return string.format("%.1f", (m or 0) / 1000) end
	return alt_str(m)
end
local function spd_txt(ms) return string.format("%d", floor((ms or 0) * SIT.SPD_K + 0.5)) end
local function clock_txt(s)
	if not s then return "--:--:--" end
	s = floor(s) % 86400
	return string.format("%02d:%02d:%02d", floor(s / 3600), floor(s / 60) % 60, s % 60)
end
local function mmss(s)
	if not s or s < 0 then return "--:--" end
	s = floor(s + 0.5)
	if s >= 6000 then return string.format("%dH%02d", floor(s / 3600), floor(s / 60) % 60) end
	return string.format("%02d:%02d", floor(s / 60), s % 60)
end
local function aspect_word(a)       -- a = 0 (nose on) .. 180 (tail)
	a = abs(a)
	if a <= 30 then return "HOT" elseif a <= 70 then return "FLANK" elseif a <= 110 then return "BEAM" end
	return "DRAG"
end

-- own ground speed and track from the change of position (smoothed)
local KIN = {t = nil, x = nil, z = nil, gs = 0, vx = 0, vz = 0, fuel = nil, ft = nil, flow = nil}
local function kin_tick(t)
	if KIN.t and t > KIN.t + 0.45 then
		local dt = t - KIN.t
		local vx, vz = (G.ox - KIN.x) / dt, (G.oz - KIN.z) / dt
		if vx * vx + vz * vz < 1500 * 1500 then
			KIN.vx, KIN.vz = KIN.vx + (vx - KIN.vx) * 0.5, KIN.vz + (vz - KIN.vz) * 0.5
			KIN.gs = sqrt(KIN.vx * KIN.vx + KIN.vz * KIN.vz)
		end
		KIN.t, KIN.x, KIN.z = t, G.ox, G.oz
	elseif not KIN.t then
		KIN.t, KIN.x, KIN.z = t, G.ox, G.oz
	end
	-- fuel flow (kg/s) from the fuel weight over 10 s
	local f = sd_val("getTotalFuelWeight")
	if f then
		if not KIN.ft then KIN.ft, KIN.fuel = t, f
		elseif t - KIN.ft >= 10 then
			local fl = (KIN.fuel - f) / (t - KIN.ft)
			if fl >= 0 and fl < 20 then KIN.flow = KIN.flow and (KIN.flow * 0.5 + fl * 0.5) or fl end
			KIN.ft, KIN.fuel = t, f
		end
	end
end

-- PICTURE: hostile groups (contacts within GROUP_M of each other), by range
local GROUP_M = 5000
local PIC = {groups = {}, sel = 1}
local function pic_groups(t, stale)
	local list = EWR.merge(feed.list, t, stale)
	local hs = {}
	for _, c in ipairs(list) do
		if (c.code or 0) % 10 == 2 then
			local age = math.min(math.max(t - (c.t or t), 0), c.mx or 20)
			hs[#hs + 1] = {x = c.x + (c.vx or 0) * age, z = c.z + (c.vz or 0) * age, y = c.y or 0,
			               vx = c.vx or 0, vz = c.vz or 0, nm = c.nm, radar = (c.code or 0) >= 10, g = nil}
		end
	end
	local groups = {}
	for i, a in ipairs(hs) do
		if not a.g then
			local g = {a}
			a.g = g
			local k = 1
			while k <= #g do
				local p = g[k]
				for _, b in ipairs(hs) do
					if not b.g and abs(b.x - p.x) < GROUP_M and abs(b.z - p.z) < GROUP_M then b.g = g; g[#g + 1] = b end
				end
				k = k + 1
			end
			groups[#groups + 1] = g
		end
	end
	local out = {}
	for _, g in ipairs(groups) do
		local lead, ld, top = nil, 1e12, -1e9
		for _, c in ipairs(g) do
			local d = (c.x - G.ox) ^ 2 + (c.z - G.oz) ^ 2
			if d < ld then lead, ld = c, d end
			if c.y > top then top = c.y end
		end
		local b, r = brg_rng(lead.x - G.ox, lead.z - G.oz)
		local v = sqrt(lead.vx ^ 2 + lead.vz ^ 2)
		local asp = 0
		if v > 5 then asp = (math.deg(atan2(G.oz - lead.z, G.ox - lead.x) - atan2(lead.vz, lead.vx)) + 540) % 360 - 180 end
		out[#out + 1] = {b = b, r = r, top = top, n = #g, nm = lead.nm or "", v = v, asp = asp, radar = lead.radar, x = lead.x, z = lead.z}
	end
	table.sort(out, function(p, q) return p.r < q.r end)
	return out
end
pic_pick = function(k) if PIC.groups[k] then PIC.sel = k end end
local function page_pic(t, stale)
	local gs = pic_groups(t, stale)
	PIC.groups = gs
	if PIC.sel > #gs then PIC.sel = 1 end
	rows_clear()
	local bull = bull_now()
	row(1, (#gs == 0) and "PICTURE  CLEAN" or string.format("PICTURE  %d GROUP%s", #gs, #gs == 1 and "" or "S"), (#gs == 0) and 2 or 3)
	row(2, ST.pic_bull and "FROM BULLSEYE" or "BRAA FROM OWNSHIP", 6)
	row(3, string.format("  # %-8s %5s %-5s %2s %s", ST.pic_bull and "BULL" or "BRAA", "ALT", "ASP", "N", "TYPE"), 6)
	for k = 1, 5 do
		local g = gs[k]
		local i = 2 + k * 2
		if g then
			local pos
			if ST.pic_bull and bull then
				local bb, br = brg_rng(g.x - bull[1], g.z - bull[2])
				pos = string.format("%03d/%s", bb, rng_txt(br))
			else
				pos = string.format("%03d/%s", g.b, rng_txt(g.r))
			end
			row(i, string.format("%d %-9s %5s %-5s %2d %s", k, pos, alt_txt(g.top), aspect_word(g.asp), g.n, tostring(g.nm):upper():sub(1, 7)),
				g.radar and 3 or 4, k == PIC.sel)
			row(i + 1, string.format("     %s %s  %s", spd_txt(g.v), SIT.SPD_LBL, g.radar and "RADAR" or "DATALINK"), 6)
		end
	end
	if #gs > 5 then row(14, string.format("+%d MORE", #gs - 5), 6) end
end

-- RDR: the own radar's picture (B-scope), azimuth +-60 deg, range = the
-- radar's range scale. Own radar contacts (code >= 10) and the lock.
local RDR_N = 16
local function page_rdr(t, stale)
	rows_clear()
	local rd = feed.radar
	local scale = (rd and (rd.dist or 0) > 0) and rd.dist or 100 * 1000
	local on = rd and rd.on and not stale
	local n = 0
	if on then
		for _, c in ipairs(feed.list) do
			if (c.code or 0) >= 10 and n < RDR_N then
				local age = math.min(math.max(t - (c.t or t), 0), 6)
				local dN, dE = c.x + (c.vx or 0) * age - G.ox, c.z + (c.vz or 0) * age - G.oz
				local r = sqrt(dN * dN + dE * dE)
				local az = (atan2(dE, dN) - G.hdg + 3 * math.pi) % TWO_PI - math.pi
				if abs(az) <= math.rad(60) and r <= scale then
					n = n + 1
					local h = H.rb[n]
					h.x:set(az / math.rad(60)); h.y:set(r / scale); h.vis:set(1)
					h.alt:set(alt_num(c.y))
					h.col:set(((c.code or 0) % 10 == 2) and 2 or (((c.code or 0) % 10 == 3) and 3 or 1))
				end
			end
		end
	end
	for k = n + 1, RDR_N do H.rb[k].vis:set(0) end
	H.rdr_on:set(on and 1 or 0)
	local s = scale / NM
	for k = 1, 4 do H.rdr_r[k]:set(floor(s * k / 4 + 0.5)) end
	-- scan line: the antenna's azimuth (export: scan centre)
	local scx = rd and (rd.az or 0) / math.rad(60) or 0
	H.rdr_scan:set(math.max(-1, math.min(1, scx)))
	-- lock
	local L = (not stale) and feed.lock or nil
	if L then
		local age = math.min(math.max(t - L.t, 0), 5)
		local lx, lz = L.x + L.vx * age, L.z + L.vz * age
		local dN, dE = lx - G.ox, lz - G.oz
		local r = sqrt(dN * dN + dE * dE)
		local az = (atan2(dE, dN) - G.hdg + 3 * math.pi) % TWO_PI - math.pi
		H.rlk.x:set(math.max(-1, math.min(1, az / math.rad(60)))); H.rlk.y:set(math.min(1, r / scale)); H.rlk.vis:set(1)
		local ux, uz = dN / math.max(r, 1), dE / math.max(r, 1)
		local vc = (KIN.vx - L.vx) * ux + (KIN.vz - L.vz) * uz
		local v = sqrt(L.vx * L.vx + L.vz * L.vz)
		local asp = "---"
		if v > 5 then
			local a = (math.deg(atan2(-dE, -dN) - atan2(L.vz, L.vx)) + 540) % 360 - 180
			asp = string.format("%03d%s", floor(abs(a) + 0.5), a >= 0 and "R" or "L")
		end
		row(13, string.format("LOCK  R %s %s  H %s", rng_txt(r), SIT.RNG_LBL, alt_txt(L.y)), 4)
		row(14, string.format("Vc %s %s  ASP %s", spd_txt(vc), SIT.SPD_LBL, asp), 4)
	else
		H.rlk.vis:set(0)
		row(14, on and string.format("%d CONTACT%s", n, n == 1 and "" or "S") or (stale and "NO RADAR DATA" or "RADAR OFF"), on and 2 or 6)
	end
	row(1, on and ((feed.master ~= "" and feed.master or "A/A") .. "  " .. (rd.ecm and "ECM" or "")) or "", 2)
end

-- NAV: steering to the selected steerpoint and the route list
local NAV = {top = 1}
nav_step = function(d) NAV.top = math.max(1, NAV.top + d) end
-- time to fly from here along the route to point i (s), at the ground speed
local function eta_s(route, act, i, gs)
	if gs < 30 or not route[act] then return nil end
	local d = sqrt((route[act].x - G.ox) ^ 2 + (route[act].z - G.oz) ^ 2)
	for k = act + 1, i do
		local p, q = route[k - 1], route[k]
		if not (p and q) then return nil end
		d = d + sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
	end
	return d / gs
end
-- NAV ADD / DEL (v0.3, as the MiG-29 MFD): own waypoints. ADD: type the
-- latitude (DDMMm) ВВОД, the longitude (DDDMMm) ВВОД; ADD again: bearing
-- (true, 3 digits) ВВОД and range ВВОД from the jet; ADD a third time or
-- СБРОС: cancel. The point goes in after the selected steerpoint and is
-- selected. DEL: the selected steerpoint out. RTE RST: the route as loaded.
local ADD_STEP = {LAT = {5, "LAT N DDMMm"}, LON = {6, "LON E DDDMMm"}, BRG = {3, "BRG DEG T"}, RNG = {4, "RNG " .. SIT.RNG_LBL}}
local function msg(m) ST.entry_msg, ST.entry_t = m, now() end
local function work_copy()
	if ST.work then return ST.work end
	local a = active_now()
	local w = {}
	for i, p in ipairs(route_now()) do
		w[i] = {x = p.x, z = p.z, name = p.name, alt = p.alt, tot = p.tot, num = i, user = p.user}
	end
	ST.work = w
	ST.sit_act = (a >= 1) and a or nil
	return w
end
local function renumber(w) for i, p in ipairs(w) do p.num = i end end
local function add_point(x, z)
	local a = active_now()
	local w = work_copy()
	ST.user_n = (ST.user_n or 0) + 1
	local i = math.max(0, math.min(a, #w)) + 1
	table.insert(w, i, {x = x, z = z, name = "U" .. ST.user_n, user = true})
	renumber(w)
	ST.sit_act = i
	msg("WAYPOINT ADDED " .. i)
	log(string.format("waypoint U%d added at %.0f %.0f (point %d)", ST.user_n, x, z, i))
end
nav_add = function()
	if not ST.add then ST.add = {mode = "LL", step = "LAT"}
	elseif ST.add.mode == "LL" then ST.add = {mode = "BR", step = "BRG"}
	else ST.add = nil; msg("ADD CANCELLED"); ST.entry = ""; return end
	ST.entry, ST.entry_msg = "", nil
	ST.page = PG.NAV
end
nav_del = function()
	local r = route_now()
	local a = active_now()
	if not r[a] then msg("DEL: NO STEERPOINT"); return end
	local w = work_copy()
	local nm = w[a] and w[a].name or ""
	table.remove(w, a)
	renumber(w)
	ST.sit_act = (#w > 0) and math.min(a, #w) or nil
	msg("WAYPOINT DELETED " .. tostring(nm):upper():sub(1, 8))
	log("waypoint " .. tostring(nm) .. " deleted (point " .. a .. ")")
end
nav_rst = function()
	if not ST.work then msg("ROUTE NOT EDITED"); return end
	ST.work, ST.sit_act, ST.add = nil, nil, nil
	msg("ROUTE AS LOADED")
end
-- ВВОД while ADD runs; returns true when it took the entry
local function add_enter(e)
	local A = ST.add
	if not A then return false end
	local need = ADD_STEP[A.step][1]
	if A.step ~= "RNG" and #e ~= need then msg(ADD_STEP[A.step][2] .. ": " .. need .. " DIGITS"); return true end
	local n = tonumber(e)
	if not n then return true end
	if A.step == "LAT" then
		local dd, mm = floor(n / 1000), (n % 1000) / 10
		if dd > 89 or mm >= 60 then msg("NO SUCH LATITUDE"); return true end
		local sgn = (feed.own and feed.own.lat < 0) and -1 or 1
		A.lat, A.step = sgn * (dd + mm / 60), "LON"
	elseif A.step == "LON" then
		local dd, mm = floor(n / 1000), (n % 1000) / 10
		if dd > 179 or mm >= 60 then msg("NO SUCH LONGITUDE"); return true end
		local sgn = (feed.own and feed.own.lon < 0) and -1 or 1
		local x, z = SIT_DTM.to_world(A.lat, sgn * (dd + mm / 60))
		ST.add = nil
		if not x then msg("NO MAP POSITION"); return true end
		if G.ox and (x - G.ox) ^ 2 + (z - G.oz) ^ 2 > 1500e3 ^ 2 then msg("TOO FAR (OTHER MAP?)"); return true end
		add_point(x, z)
	elseif A.step == "BRG" then
		if n > 360 then msg("BRG 000-360"); return true end
		A.brg, A.step = n % 360, "RNG"
	else
		if n < 1 or not G.ox then msg("NO RANGE"); return true end
		local b, d = math.rad(A.brg), n * NM
		ST.add = nil
		add_point(G.ox + d * math.cos(b), G.oz + d * math.sin(b))
	end
	return true
end
local function page_nav(t)
	rows_clear()
	if ST.add then
		row(3, "ADD " .. ADD_STEP[ST.add.step][2] .. "  ENT" .. ((ST.add.mode == "LL") and "   ADD: BRG/RNG" or "   ADD: CANCEL"), 7)
	end
	local route, act = route_now(), active_now()
	local gs = KIN.gs
	local tod = G.tod or 0
	local w = route[act]
	if not w then
		row(1, "NO ROUTE", 6)
		row(2, "LOAD A CARTRIDGE (R1) OR FLY THE MISSION ROUTE", 6)
		return
	end
	local b, r = brg_rng(w.x - G.ox, w.z - G.oz)
	local nm = (w.name and w.name ~= "") and w.name:upper():sub(1, 10) or ""
	row(1, string.format("STPT %d %-10s %03d/%s %s", floor(w.num or act), nm, b, rng_txt(r), SIT.RNG_LBL), 1)
	-- cross-track from the leg (previous point -> steerpoint)
	local p = route[act - 1]
	local xtk = ""
	if p then
		local lx, lz = w.x - p.x, w.z - p.z
		local ll = sqrt(lx * lx + lz * lz)
		if ll > 1 then
			local cr = ((G.ox - p.x) * lz - (G.oz - p.z) * lx) / ll       -- + = left of the leg
			xtk = string.format("XTK %.1f %s", abs(cr) / NM, cr >= 0 and "L" or "R")
		end
	end
	local e = eta_s(route, act, act, gs)
	row(2, string.format("%-12s GS %s  ETA %s", xtk, spd_txt(gs), e and clock_txt(tod + e) or "--:--:--"), 2)
	-- the list: 9 rows, the selected one boxed
	row(4, "  #  NAME       BRG  DIST    ETA    TOT", 6)
	local n = #route
	if act < NAV.top then NAV.top = act end
	if act > NAV.top + 8 then NAV.top = act - 8 end
	if NAV.top > math.max(1, n - 8) then NAV.top = math.max(1, n - 8) end
	for k = 0, 8 do
		local i = NAV.top + k
		local q = route[i]
		if q then
			local qb, qr = brg_rng(q.x - G.ox, q.z - G.oz)
			local qe = (i >= act) and eta_s(route, act, i, gs) or nil
			local tot = ""
			if q.tot then
				local dt = qe and (tod + qe - q.tot) or nil
				tot = clock_txt(q.tot):sub(1, 5) .. (dt and string.format(" %+d", floor(dt + 0.5)) or "")
			end
			row(5 + k, string.format("%3d  %-9s %03d %5s %s %s", floor(q.num or i), (q.name or ""):upper():sub(1, 9), qb, rng_txt(qr),
				qe and clock_txt(tod + qe):sub(1, 5) or "--:--", tot), (i == act) and 1 or ((i < act) and 6 or 2), i == act)
		end
	end
	row(14, string.format("ROUTE %s  %d POINTS%s", tostring(ST.loaded.name):upper():sub(1, 12), n, ST.work and "  EDITED" or ""), ST.work and 4 or 6)
end

-- HSI: rose (heading up), course to the steerpoint (auto: the leg's course,
-- or set with CRS +/-), heading bug, bearing pointer, deviation
local HSI = {crs = nil, hdg = nil}
hsi_set = function(what, d)
	local hdg = floor(math.deg(G.hdg) + 0.5)
	if what == "auto" then HSI.crs = nil; HSI.hdg = nil; return end
	if what == "crs" then HSI.crs = ((HSI.crs or G.crs_auto or hdg) + d * 5) % 360 end
	if what == "hdg" then HSI.hdg = ((HSI.hdg or hdg) + d * 5) % 360 end
end
local function page_hsi(t)
	rows_clear()
	local hdg = math.deg(G.hdg)
	H.hsi.rot:set(G.hdg)
	local route, act = route_now(), active_now()
	local w = route[act]
	local crs = HSI.crs
	if w then
		local p = route[act - 1]
		local b = brg_rng(w.x - G.ox, w.z - G.oz)
		local auto = p and select(1, brg_rng(w.x - p.x, w.z - p.z)) or b
		G.crs_auto = auto
		crs = crs or auto
		-- deviation: our bearing from the steerpoint vs. the course, +-10 deg full scale
		local from = select(1, brg_rng(G.ox - w.x, G.oz - w.z))
		local dev = ((from - (crs + 180)) + 540) % 360 - 180
		H.hsi.dev:set(math.max(-1, math.min(1, -dev / 10)))
		H.hsi.brg:set(math.rad(b) - G.hdg)
		H.hsi.bvis:set(1)
		local _, r = brg_rng(w.x - G.ox, w.z - G.oz)
		local e = eta_s(route, act, act, KIN.gs)
		row(13, string.format("STPT %d  %03d/%s %s", floor(w.num or act), b, rng_txt(r), SIT.RNG_LBL), 1)
		row(14, string.format("ETA %s   GS %s", e and mmss(e) or "--:--", spd_txt(KIN.gs)), 2)
	else
		crs = crs or floor(hdg + 0.5) % 360
		H.hsi.dev:set(0); H.hsi.bvis:set(0)
		row(14, "NO STEERPOINT", 6)
	end
	H.hsi.crs:set(math.rad(crs) - G.hdg)
	local hb = HSI.hdg or floor(hdg + 0.5) % 360
	H.hsi.hb:set(math.rad(hb) - G.hdg)
	row(1, string.format("CRS %03d%s", floor(crs + 0.5) % 360, HSI.crs and "" or " AUTO"), 5)
	row(2, string.format("HDG %03d%s", floor(hb + 0.5) % 360, HSI.hdg and "" or " ---"), 4)
end

-- COM: the УКВ / КВ radios of the radio panel (Su-27 Radio (WW)'s loader
-- device publishes them as SU27R_*); the keys step them through it
local RADP = {}
local function radp(n)
	local h = RADP[n]
	if not h then h = get_param_handle("SU27R_" .. n); RADP[n] = h end
	local ok, v = pcall(function() return h:get() end)
	return ok and tonumber(v) or 0
end
-- COM page keys -> the radio panel (LDR device), as its bound keys (they turn
-- the knobs too). A device cannot call another plugin device's SetCommand,
-- so the request goes through two cockpit parameters: SU27R_REQ = number *
-- 100 + key (1..8 = RAD_KEY 6201..6208), the LDR device answers SU27R_ACK.
local RQ = {q = {}, n = 0, sent = nil, t = 0, p = get_param_handle("SU27R_REQ"), ack = get_param_handle("SU27R_ACK"), f = get_param_handle("SU27R_REQ_F")}
local function rq_tick()
	local tn = get_model_time() or 0
	if RQ.sent and (tonumber(RQ.ack:get()) or 0) ~= RQ.sent and tn - RQ.t < 1 then return end
	RQ.sent = nil
	local c = table.remove(RQ.q, 1)
	if not c then return end
	RQ.n = RQ.n % 9999 + 1
	RQ.sent = RQ.n * 100 + c[1]
	if c[2] then RQ.f:set(c[2]) end
	RQ.p:set(RQ.sent); RQ.t = tn
end
local function rq_push(code, khz)
	if #RQ.q < 10 then RQ.q[#RQ.q + 1] = {code, khz} end
	rq_tick()
end
com_key = function(name)
	local cmd = RAD_KEY and RAD_KEY[name]
	if not cmd then return end
	ST.man_entry = nil
	rq_push(cmd - 6200)
end
-- manual frequency (v0.3): УКВ MAN / КВ MAN, then the frequency on the
-- keypad and ВВОД (УКВ 100-399.975: 251500 = 251.500, 243 = 243.000; КВ
-- 3-10: 35 = 3.500, 6215 = 6.215, 10000 = 10.000): the channel in use gets
-- that frequency from now on (radios, card, this page) until the next
-- ЗАГР on the loader plate. MAN again, СБРОС or ВВОД alone: cancel.
local MAN_LEN = {ukv = 6, kv = 5}
com_man = function(band)
	if ST.man_entry == band then ST.man_entry = nil; ST.entry = ""; return end
	ST.man_entry, ST.entry, ST.entry_msg = band, "", nil
end
local function man_enter(e)
	local band = ST.man_entry
	ST.man_entry = nil
	local code = (band == "ukv") and 9 or 10
	if e == "" then ST.entry_msg, ST.entry_t = band:upper() .. " MAN CANCELLED", now(); return end
	local mhz, frac
	if band == "ukv" then mhz, frac = e:sub(1, 3), e:sub(4)
	else
		local k = (e:sub(1, 2) == "10") and 2 or 1
		mhz, frac = e:sub(1, k), e:sub(k + 1)
	end
	local f = (tonumber(mhz) or 0) + (tonumber("0." .. (frac ~= "" and frac or "0")) or 0)
	local lo, hi = 100, 399.975
	if band == "kv" then lo, hi = 3.0, 10.0 end
	if f < lo or f > hi then
		ST.entry_msg, ST.entry_t = string.format("%s %.3f: %g-%g MHZ", band:upper(), f, lo, hi), now()
		return
	end
	rq_push(code, floor(f * 1000 + 0.5))
	ST.entry_msg, ST.entry_t = string.format("%s CH %02d = %.3f", band:upper(), floor(radp(band:upper() .. "_CH") + 0.5), f), now()
end
local function page_com(t)
	rows_clear()
	local function radio(r, key, title, fmt)
		local ch, vol = radp(key .. "_CH"), radp(key .. "_VOL")
		local f = radp(key .. "_F")
		if ST.man_entry == key:lower() then
			row(r, string.format("%-11s CH %02d  %s_", title, floor(ch + 0.5), ST.entry or ""), 7, true)
		else
			row(r, string.format("%-11s CH %02d  %s", title, floor(ch + 0.5), (f > 0) and string.format(fmt, f) or "  ----  "), 1)
		end
		local bars = floor(vol * 10 + 0.5)
		row(r + 1, string.format("VOL %3d%%  %s%s", floor(vol * 100 + 0.5), string.rep("|", bars), string.rep(".", 10 - bars)), 2)
	end
	radio(1, "UKV", "UKV R-800", "%7.3f")
	radio(4, "KV", "KV  R-864", "%6.3f")
	row(7, "   UKV               KV", 6)
	local cu, ck = floor(radp("UKV_CH") + 0.5), floor(radp("KV_CH") + 0.5)
	local top = math.max(1, math.min(cu, ck) - 2)
	if math.max(cu, ck) > top + 5 then top = math.max(1, math.max(cu, ck) - 5) end
	top = math.min(top, 15)
	for k = 0, 5 do
		local c = top + k
		local fu, fk = radp("UKV_F" .. c), radp("KV_F" .. c)
		local a = (fu > 0) and string.format("%s%02d %7.3f", c == cu and ">" or " ", c, fu) or string.format("%s%02d  ------", c == cu and ">" or " ", c)
		local b = (fk > 0) and string.format("%s%02d %6.3f", c == ck and ">" or " ", c, fk) or string.format("%s%02d  -----", c == ck and ">" or " ", c)
		row(8 + k, a .. "     " .. b, (c == cu or c == ck) and 1 or 2)
	end
	if ST.man_entry then
		local chn = floor(radp(ST.man_entry:upper() .. "_CH") + 0.5)
		row(3, string.format("NEW FREQ FOR CH %02d: %s, ENT", chn, (ST.man_entry == "ukv") and "100.000-399.975" or "3.000-10.000"), 7)
	end
	local slot = floor(radp("CART") + 0.5)
	row(14, (slot == 0) and "PRESETS: MISSION (MIS)" or string.format("PRESETS: CARTRIDGE %d", slot), 5)
end

-- FUEL (as the MiG-29 MFD's FPAS): fuel, bingo, time / range to bingo,
-- fuel at home (the route's first point), engines
local function page_fuel(t)
	rows_clear()
	local f = sd_val("getTotalFuelWeight")
	local flow = KIN.flow
	if not flow then
		local cl, cr = sd_val("getEngineLeftFuelConsumption"), sd_val("getEngineRightFuelConsumption")
		if cl or cr then flow = (cl or 0) + (cr or 0) end
	end
	local bingo = ST.bingo or 1500
	H.fuel.frac:set(f and math.max(0, math.min(1, f / 9400)) or 0)
	H.fuel.bingo:set(math.max(0, math.min(1, bingo / 9400)))
	if not f then row(1, "FUEL  NO DATA", 6); return end
	row(1, string.format("FUEL %6d KG", floor(f + 0.5)), (f < bingo) and 3 or 1)
	row(2, string.format("BINGO %5d KG", bingo), 4)
	if f < bingo then row(3, "BINGO BINGO", 3) end
	local to_b = (flow and flow > 0.01) and (f - bingo) / flow or nil
	row(5, string.format("FLOW     %s KG/MIN", flow and string.format("%d", floor(flow * 60 + 0.5)) or "---"), 2)
	row(6, string.format("TO BINGO %s  %s %s", to_b and mmss(math.max(0, to_b)) or "--:--",
		(to_b and KIN.gs > 30) and rng_txt(math.max(0, to_b) * KIN.gs) or "---", SIT.RNG_LBL), 2)
	local endur = (flow and flow > 0.01) and f / flow or nil
	row(7, string.format("ENDURANCE %s", endur and mmss(endur) or "--:--"), 2)
	local route = route_now()
	local home = route[1]
	if home then
		local b, r = brg_rng(home.x - G.ox, home.z - G.oz)
		local arr = (flow and KIN.gs > 30) and (f - r / KIN.gs * flow) or nil
		row(9, string.format("HOME %03d/%s %s", b, rng_txt(r), SIT.RNG_LBL), 1)
		row(10, string.format("AT HOME  %s KG", arr and string.format("%d", floor(arr + 0.5)) or "----"), (arr and arr < bingo) and 3 or 2)
	end
	local rl, rr = sd_val("getEngineLeftRPM"), sd_val("getEngineRightRPM")
	local tl, tr = sd_val("getEngineLeftTemperatureBeforeTurbine"), sd_val("getEngineRightTemperatureBeforeTurbine")
	local function pct(v) if not v then return "--" end if v <= 1.5 then v = v * 100 end return string.format("%d", floor(v + 0.5)) end
	row(12, string.format("RPM  %3s %3s %%", pct(rl), pct(rr)), 2)
	row(13, string.format("TEMP %3s %3s C", tl and string.format("%d", floor(tl + 0.5)) or "--", tr and string.format("%d", floor(tr + 0.5)) or "--"), 2)
end
bingo_step = function(d) ST.bingo = math.max(0, math.min(9000, (ST.bingo or 1500) + d * 100)) end

-- SMS: the stations (1..10) on a plan view, the selected weapon, gun and
-- countermeasures
local function short_sta(nm)
	nm = (nm or ""):upper()
	if nm == "" then return "" end
	if nm:find("FUEL") or nm:find("TANK") then return "TANK" end
	local s = nm:match("(R%-%d+%a*)")
	if s then return s end
	return (nm:gsub("[^%w%-]", "")):sub(1, 7)
end
-- the symbol on the STORES page: 1 R-27, 2 R-73 / R-60, 3 R-77, 4 bomb / other, 5 rocket pod
local function store_typ(nm)
	nm = (nm or ""):upper()
	if nm:find("R%-27") then return 1 end
	if nm:find("R%-73") or nm:find("R%-60") then return 2 end
	if nm:find("R%-77") then return 3 end
	if nm:find("B%-8") or nm:find("B%-13") or nm:find("UB%-") or nm:find("S%-8") or nm:find("S%-13") or nm:find("ROCKET") or nm:find("POD") then return 5 end
	return 4
end
local function page_sms(stale)
	rows_clear()
	local by, of = slots()
	local cur = feed.cur_sta or 0
	local curp = of[cur]
	local sel_name, sel_n = nil, 0
	for n = 1, 10 do
		local s = by[n]
		local loaded = s and s.n > 0
		H.sms[n].st:set(loaded and ((n == curp) and 2 or 1) or 0)
		H.sms[n].txt:set(safe_text(loaded and short_sta(s.name) or ""))
		H.sms[n].typ:set(loaded and store_typ(s.name) or 0)
		if loaded and n == curp then sel_name = s.name end
	end
	if sel_name then
		for n = 1, 10 do local s = by[n]; if s and s.n > 0 and s.name == sel_name then sel_n = sel_n + s.n end end
	end
	local cm = feed.cm or {}
	local nst, nld = 0, 0
	for n = 1, 10 do local s = by[n]; if s and s.n > 0 then nst = nst + s.n; nld = nld + 1 end end
	row(13, sel_name and string.format("SELECTED  ST%d  %s  (%d)", curp, short_sta(sel_name), sel_n) or (feed.gun and "SELECTED  GUN" or "SELECTED  ----"), 4)
	row(14, string.format("GUN %d  CHAFF %d  FLARE %d  %d ON %d ST", cm.gun or 0, cm.chaff or 0, cm.flare or 0, nst, nld), stale and 6 or 1)
end

-- RWR: the SPO-15's emitters on a ring (nearer the centre = stronger);
-- amber search, red lock, flashing red missile guidance
local RWR_N = 10
local function rwr_label(e)
	local n = (e.nm or ""):upper()
	local s = n:match("SU%-?(%d+)") or n:match("MIG%-?(%d+)") or n:match("F%-(%d+)") or n:match("^S%-(%d+)")
	if n:find("AWACS") or n:find("A%-50") or n:find("E%-3") or n:find("E%-2") then return "AW" end
	if s then return s:sub(1, 3) end
	if e.l1 == 2 or e.l1 == 3 then return "S" end      -- ground / ship
	return "U"
end
local function page_rwr(t)
	rows_clear()
	local list = (feed.rwr and t - (feed.rwr_t or -10) < 2) and feed.rwr or {}
	table.sort(list, function(p, q) return (p.st * 10 + p.pw) > (q.st * 10 + q.pw) end)
	local flash = floor(t * 4) % 2 == 0
	local nl, nk = 0, 0
	for k = 1, RWR_N do
		local e, h = list[k], H.rwr[k]
		if e then
			local r = 0.16 + (1 - math.max(0, math.min(1, e.pw))) * 0.30
			h.x:set(r * math.sin(e.az)); h.y:set(r * math.cos(e.az))
			local col = (e.st >= 2) and 2 or 1
			h.col:set(col)
			h.vis:set((e.st == 3 and not flash) and 0 or 1)
			h.lck:set((e.st >= 2) and 1 or 0)
			h.txt:set(safe_text(rwr_label(e)))
			if e.st >= 2 then nl = nl + 1 end
			if e.st == 3 then nk = nk + 1 end
		else
			h.vis:set(0); h.lck:set(0); h.txt:set("")
		end
	end
	local e1 = list[1]
	if e1 then
		local brg = (floor(math.deg(e1.az) + 0.5) + 360) % 360
		row(12, string.format("%s  %s  %03d", (e1.nm or ""):upper():sub(1, 14), ({"SEARCH", "LOCK", "LAUNCH"})[e1.st] or "", brg), (e1.st >= 2) and 3 or 4)
	end
	row(13, string.format("%d EMITTER%s  %d LOCK  %d LAUNCH", #list, #list == 1 and "" or "S", nl, nk), (nk > 0) and 3 or 2)
	local cm = feed.cm or {}
	row(14, string.format("CHAFF %d  FLARE %d", cm.chaff or 0, cm.flare or 0), 2)
end

-- keypad (ED's ЦЕЛИ / ИСТРЕБИТЕЛИ panel): digits, ВВОД, СБРОС; ИСТРЕБИТЕЛИ
-- 1-4 = SA / RDR / NAV / RWR, ГР = MENU
local KP_DIGIT = {C1 = "1", C2 = "2", C3 = "3", C4 = "4", C5 = "5", C6 = "6", C7 = "7", C8 = "8", C9 = "9", C10 = "0"}
local KP_PAGE = {F1 = PG.SIT, F2 = PG.RDR, F3 = PG.NAV, F4 = PG.RWR, GR = SIT.MFI and PG.SIT or PG.MENU}   -- (MFI: no MENU page)
entry_key = function(k)
	ST.entry_t = now()
	if SIT.MFI and MFIDEV and MFIDEV.keypad(k) then return end
	if KP_DIGIT[k] then
		local mx = (ST.man_entry and ST.page == PG.COM) and MAN_LEN[ST.man_entry] or (ST.add and ADD_STEP[ST.add.step][1]) or 4
		if (ST.man_entry and ST.page == PG.COM) or ST.add then ST.entry = ((ST.entry or "") .. KP_DIGIT[k]):sub(1, mx)
		else ST.entry = ((ST.entry or "") .. KP_DIGIT[k]):sub(-mx) end
		ST.entry_msg = nil
	elseif k == "RST" then
		if ST.add and (ST.entry or "") == "" then ST.add = nil; msg("ADD CANCELLED") end
		if ST.man_entry and (ST.entry or "") == "" then ST.man_entry = nil end
		ST.entry, ST.entry_msg = "", nil
	elseif KP_PAGE[k] then
		ST.page = KP_PAGE[k]; ST.entry = ""
	elseif k == "ENT" then
		local e = ST.entry or ""
		local n = tonumber(e)
		ST.entry = ""
		if ST.add and ST.page == PG.NAV then add_enter(e); return end
		if ST.man_entry and ST.page == PG.COM then man_enter(e); return end
		if not n then return end
		local pg = ST.page
		if pg == PG.NAV or pg == PG.HSI or pg == PG.SIT then
			local r = route_now()
			for i, w in ipairs(r) do if floor(w.num or i) == n then ST.sit_act = i; ST.entry_msg = "STPT " .. n; return end end
			if r[n] then ST.sit_act = n; ST.entry_msg = "STPT " .. n; return end
			ST.entry_msg = "NO STPT " .. n
		elseif pg == PG.FUEL then
			ST.bingo = (n < 100) and n * 100 or n
			ST.entry_msg = "BINGO " .. ST.bingo
		elseif pg == PG.DTM then
			dtm_choices()
			if n >= 1 and n <= #ST.carts + 1 then ST.cart = n; ST.entry_msg = "CART " .. n else ST.entry_msg = "NO CART " .. n end
		elseif pg == PG.SETS or pg == PG.MENU or pg == PG.OWN then
			ST.fch = n % 128; ST.entry_msg = "FIGHTER CH " .. ST.fch
		else
			ST.entry_msg = "NO ENTRY HERE"
		end
	end
end
local function entry_tick(t)
	local txt = ""
	if ST.add and ST.page == PG.NAV then txt = ADD_STEP[ST.add.step][2] .. "  " .. (ST.entry or "") .. "_"
	elseif ST.man_entry and ST.page == PG.COM then txt = ST.man_entry:upper() .. " FREQ  " .. (ST.entry or "") .. "_"
	elseif ST.entry and ST.entry ~= "" then txt = "ENTRY " .. ST.entry .. "_"
	elseif ST.entry_msg and t - (ST.entry_t or -10) < 3 then txt = ST.entry_msg end
	H.entry:set(safe_text(txt))
end
local function draw_pages(t, stale)
	H.crs:set(ST.crs and 1 or 0)
	H.ics_fail:set(feed.fail.ECMFailure and 1 or 0)
	local pg = ST.page
	entry_tick(t)
	if SIT.MFI and MFIDEV and MFIDEV.draw(pg, t, stale) then return end
	-- the moving pages: every update
	if pg == PG.RDR then page_rdr(t, stale); return end
	if pg == PG.HSI then page_hsi(t); return end
	if pg == PG.RWR then page_rwr(t); return end
	-- the text pages 5 times a second (they hardly change); at once after a
	-- button press or a page change
	if not PGF.now and pg == PGF.last and tick % 4 ~= 0 then return end
	PGF.now, PGF.last = false, pg
	if pg == PG.DTM then
		H.dtm_cart:set(safe_text(string.format("CARTRIDGE %s  (%d/%d)", dtm_name(ST.cart):upper():sub(1, 16), ST.cart, #(ST.carts or {}) + 1)))
		H.dtm_loaded:set(safe_text("LOADED " .. tostring(ST.loaded.name):upper():sub(1, 16)))
		-- the choices: MSN and the cartridges for this map (keypad: number + ВВОД picks one)
		rows_clear()
		local n = #(ST.carts or {}) + 1
		local top = math.max(1, math.min(ST.cart - 4, n - 8))
		for k = 0, 8 do
			local c = top + k
			if c <= n then
				local nm = dtm_name(c):upper():sub(1, 28)
				row(4 + k, string.format("%2d  %s", c, nm), (c == ST.cart) and 5 or 1, c == ST.cart)
			end
		end
	elseif pg == PG.BIT then page_bit(t, stale)
	elseif pg == PG.TIME then page_time(t)
	elseif pg == PG.OWN then page_own()
	elseif pg == PG.FLT then page_flt()
	elseif pg == PG.PIC then page_pic(t, stale)
	elseif pg == PG.NAV then page_nav(t)
	elseif pg == PG.COM then page_com(t)
	elseif pg == PG.FUEL then page_fuel(t)
	elseif pg == PG.SMS then page_sms(stale) end
end

-- formation: smallest range step that shows every own-flight member
local function form_range()
	local far = 0
	for _, c in ipairs(feed.list) do
		if (c.code or 0) % 10 == 5 then
			local d = sqrt((c.x - G.ox) ^ 2 + (c.z - G.oz) ^ 2)
			if d > far then far = d end
		end
	end
	if far <= 0 then return nil end
	for i, r in ipairs(SIT.RANGES_NM) do
		if r * NM >= far * 1.15 then return i end
	end
	return #SIT.RANGES_NM
end

---------------------------------------------------------------------------
-- every text parameter must hold a string before the page is drawn: the
-- page prints them with "%s", and DCS crashes (access violation in
-- ceStringPoly) on a parameter that is still the number 0
local function init_texts()
	for _, k in ipairs({"time", "status", "stpt", "master", "net", "dtm"}) do H[k]:set("") end
	H.be.txt:set("")
	for _, h in ipairs(ALL_TEXT) do h:set("") end
	H.lk.t1:set(""); H.lk.t2:set(""); H.lk.t3:set("")
	for g = 1, SIT.MAX_THREATS do HG[g].txt:set("") end
end
init_texts()        -- at load already, before the first frame

function post_initialize()
	init_texts()
	log("=== Su-27 MFD (WW) 1.3" .. (SIT.MFI and " MFI" or "") .. ", aircraft " .. tostring(get_aircraft_type and get_aircraft_type()))
	for n = 1, 20 do dev:listen_command(MFD_CMD.OSB0 + n); dev:listen_command(MFD_KEY.OSB0 + n) end
	for _, c in ipairs({MFD_CMD.PWR, MFD_CMD.BRT_UP, MFD_CMD.BRT_DN, MFD_CMD.DAY, MFD_CMD.NIGHT,
	                    MFD_KEY.PWR, MFD_KEY.BRT_UP, MFD_KEY.BRT_DN, MFD_KEY.DAY, MFD_KEY.NIGHT, MFD_KEY.STOW}) do
		dev:listen_command(c)
	end
	for _, c in pairs(KP_CMD) do dev:listen_command(c) end
	-- the jet's electric power switch
	PWR.cmd = SIT.POWER_CMD
	if PWR.cmd then dev:listen_command(PWR.cmd) end
	open_udp()
	pcall(flt_load)
	-- Options > Special > Su-27 Radio: debug logs, MFD alignment test
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		local p = env.options and env.options.plugins and env.options.plugins["su27_radio"]
		PF.on = type(p) == "table" and p.su27_radio_logs == true
		if type(p) == "table" and p.su27_mfd_align == true then MFD.ALIGN_TEST = true end
	end)
	H.align:set(MFD.ALIGN_TEST and 1 or 0)
	if PF.on then log("timing log on: Logs/s27mfd_perf.log") end
	log("UDP " .. udp_state .. " on " .. SIT.PORT)
end

-- the export (requests: which pages need the picture)
function to_export(msg)
	if udp then pcall(function() udp:sendto(msg, "127.0.0.1", 42895) end) end
end
-- own missiles in flight: missile, line to its target, time to impact
local function draw_missiles(t)
	local list = (feed.msl and t - (feed.msl_t or -10) < 3) and feed.msl or {}
	local el = t - (feed.msl_t or t)
	-- (the fly-out line flashes; the line to the locked target with it while
	-- a missile flies: draw_lock reads G.msl_fly / G.msl_flash)
	local fs = SIT.MSL_FLASH_S or 0.5
	local flash_on = fs <= 0 or floor(t / fs) % 2 == 0
	G.msl_fly, G.msl_flash = false, flash_on
	for k = 1, SIT.MAX_MSL do
		local h, m = H.msl[k], list[k]
		local mv, tv, lv = 0, 0, 0
		local mx, my, tx, ty
		if m and m.tg and m.tx then
			tx, ty = to_screen(m.tx - G.ox, m.tz - G.oz)
			if inside(tx, ty) then
				h.tx:set(tx); h.ty:set(ty); tv = 1
				local s = (m.tti >= 0) and string.format("%s %d", m.typ, math.max(0, floor(m.tti - el + 0.5))) or m.typ
				h.txt:set(safe_text(s))
			end
		end
		if m and m.m and m.mx then
			mx, my = to_screen(m.mx - G.ox, m.mz - G.oz)
			-- at the missile: a circle; an AIM-120 inside the MPRF range of its
			-- target (its own seeker has it): an X
			local sym = 1
			if m.typ == "A" and m.tg and m.tx then
				local dd = sqrt((m.mx - m.tx) ^ 2 + (m.mz - m.tz) ^ 2)
				if dd <= (SIT.MSL_MPRF_NM or 7) * NM then sym = 2 end
			end
			h.sym:set(sym)
			if inside(mx, my) then h.x:set(mx); h.y:set(my); mv = 1 end
		end
		h.vis:set(mv); h.tvis:set(tv)
		if mx and tv == 1 then
			G.msl_fly = true
			if flash_on then
				local a1, a2, b1, b2 = clip(mx, my, tx, ty)
				if a1 then h.l.ax:set(a1); h.l.ay:set(a2); h.l.bx:set(b1); h.l.by:set(b2); lv = 1 end
			end
		end
		h.l.vis:set(lv)
	end
end
-- mark points: an x with its number and bearing / range from us
local function draw_marks()
	for k = 1, SIT.MAX_MARKS do
		local h, m = H.mk[k], ST.marks[k]
		local vis = 0
		if m then
			local sx, sy = to_screen(m.x - G.ox, m.z - G.oz)
			if inside(sx, sy) then
				vis = 1
				h.x:set(sx); h.y:set(sy)
				local b, r = brg_rng(m.x - G.ox, m.z - G.oz)
				h.txt:set((ST.dcl >= 3) and ("M" .. m.n) or string.format("M%d %03d/%d", m.n, b, floor(r / NM + 0.5)))
			end
		end
		h.vis:set(vis)
	end
end

-- power and the display's knob: dark without power or with the knob at OFF,
-- a short start-up when it comes on; the brightness cover. Returns true while
-- the page is up.
local function power_tick(t)
	-- the unit: ВКЛ held MFD.PWR_HOLD s = off; folding away / back
	if ST.pwr_down and ST.unit_on and t - ST.pwr_down >= MFD.PWR_HOLD then
		ST.unit_on = false; ST.pwr_down = nil; log("MFD switched off")
	end
	for a, t_up in pairs(ARG_UP) do
		if t >= t_up then pcall(function() GetDevice(0):set_argument_value(a, 0) end); ARG_UP[a] = nil end
	end
	if ST.stow ~= ST.stow_to then
		local step = MFD.STOW_SPEED * SIT.UPDATE
		if ST.stow < ST.stow_to then ST.stow = math.min(ST.stow_to, ST.stow + step)
		else ST.stow = math.max(ST.stow_to, ST.stow - step) end
		pcall(function() GetDevice(0):set_argument_value(MFD.ARG_STOW, ST.stow) end)
	end
	-- alignment test: the keys pressed lately light their boxes
	if MFD.ALIGN_TEST then
		for n = 1, 20 do H.osb_lit[n]:set((ST.osb_t[n] and t - ST.osb_t[n] < 0.6) and 1 or 0) end
		for k = 1, #MFD.KP_NAMES do H.kp_lit[k]:set((ST.kp_t[k] and t - ST.kp_t[k] < 0.6) and 1 or 0) end
	end
	-- the jet's power: engines running or the electric power switch
	local rl, rr = sd_val("getEngineLeftRPM"), sd_val("getEngineRightRPM")
	local rpm = nil
	if rl or rr then
		rpm = math.max(rl or 0, rr or 0)
		if rpm > 0.3 and rpm <= 1.5 then rpm = rpm * 100 end      -- (in case it comes as a fraction)
	end
	if PWR.sw == nil then
		PWR.sw = (rpm == nil) or rpm >= SIT.RPM_ON
		log(string.format("power at start: engines %s, %s", rpm and string.format("%.0f %%", rpm) or "(no RPM)",
			PWR.sw and "on" or "off (cold start): dark until the electric power switch or an engine"))
	end
	local on = PWR.sw or (rpm ~= nil and rpm >= SIT.RPM_ON)
	PWR.on = on
	ST.mode = ST.unit_on and (ST.night and 1 or 2) or 0
	local disp = on and ST.mode > 0 and ST.stow < 0.01
	-- coming on: self test, then MENU
	if disp and not PWR.disp then PWR.boot_t = t; ST.page = SIT.MFI and PG.SIT or PG.MENU; PGF.now = true end
	PWR.disp = disp
	-- start-up: 1 dark, 2 test pattern, 3 "GO", 0 over
	local phase = 0
	local el = (disp and PWR.boot_t) and (t - PWR.boot_t) or nil
	if el and el >= 0 and el < SIT.BOOT_S then
		phase = (el < 0.35) and 1 or (el < SIT.BOOT_S - 0.8) and 2 or 3
	end
	PWR.shown = disp and phase == 0
	H.boot:set(disp and phase or 0)
	H.on:set(disp and 1 or 0)
	local rd = PWR.shown and 1 or 0
	if rd ~= PWR.ready then PWR.ready = rd; READY:set(rd) end
	-- brightness: a black see-through cover over the screen, 0 (none) .. 19
	local eff = (ST.brt / SIT.BRT_STEPS) * ((ST.mode == 1) and SIT.NIGHT_K or 1)
	local dimv = math.max(0, math.min(19, floor((1 - eff) * 20 + 0.5)))
	if SIT.MFI then
		-- MFI test 5 (the MiG-29 MFI's brightness standard): BRT 10 = SIT_MFI.brt_max
		-- of full light, each step down a tenth of that, start (and start-up
		-- screen) at BRT 5; day and night keep their own level. Dim layers
		-- 21 (BRT 10) .. 30 (BRT 1). The level shown for a moment after a change.
		dimv = 31 - math.max(1, math.min(10, ST.brt))
		local pop = disp and ST.brt_t and (t - ST.brt_t) < 2.5
		H.brt_pop:set(pop and 1 or 0)
		if pop then H.brt_txt:set(string.format("%s  BRT %d/10", ST.night and "NIGHT" or "DAY", ST.brt)) end
	end
	H.dim:set(disp and dimv or 0)
	return PWR.shown
end
local function update_body()
	pcall(rq_tick)
	tick = tick + 1
	read_udp()
	local t = now()
	local sd = sensors()
	if not sd then return end

	local okp, ox, _, oz = pcall(sd.getSelfCoordinates)
	local okh, h = pcall(sd.getHeading)
	if not okp or not ox then return end
	G.ox, G.oz = ox, oz
	if EWR.pending then
		EWR.on_packet(EWR.pending, t, ox, oz); EWR.pending = nil
		if EWR.n <= 3 then log("EWR report " .. EWR.n .. ": " .. #(EWR.fr or {}) .. " friendly, " .. #(EWR.hs or {}) .. " hostile") end
	end
	G.hdg = (okh and h) and ((-h) % TWO_PI) or 0         -- true heading, clockwise from north
	kin_tick(t)
	-- no power / display off / starting up: nothing to draw, no cursor, no scan
	if not power_tick(t) then
		if ST.soi_sit then
			ST.soi_sit = false
			to_export(string.format("S27MFDQ,0,%.4f,%.4f", SLEW.raw_h or 0, SLEW.raw_v or 0))
		end
		if ST.pic_need ~= 0 or t - (ST.pic_t or -10) >= 1 or t < (ST.pic_t or 0) then
			ST.pic_need, ST.pic_t = 0, t
			to_export("S27MFDG,0")
		end
		return
	end
	if ST.nup then G.c, G.s = 1, 0 else G.c, G.s = cos(G.hdg), sin(G.hdg) end

	-- FORM: fixed 5 NM around the formation, shown as "F5";
	-- EXP: 10 NM around the cursor ("E10"), the ownship moves off centre
	-- the range shown = ownship to the top edge of the SIT area; centred and
	-- decentred have their own steps (decentred: 7, 15, 30, 60 ...)
	local RL = ST.center and SIT.RANGES_NM or SIT.RANGES_DC_NM
	if ST.autor and feed.cur and feed.cur.dist and feed.cur.dist > 0 then
		local vsd = feed.cur.dist / NM
		local k = #RL
		for i = #RL, 1, -1 do if RL[i] >= vsd - 0.5 then k = i end end
		ST.rng = k
	end
	local rng = math.min(ST.rng, #RL)
	if ST.form then RL = SIT.RANGES_NM; rng = 1 end   -- formation: fixed F5
	G.own_x, G.own_y = 0, ST.center and SIT.CENTER_Y or SIT.DECENTER_Y
	G.k = (SIT.BOX - G.own_y) / (RL[rng] * NM)
	if SIT.MFI then
		-- MFI test 3 (as the MiG-29 MFI): the green ring / arc is the range
		local Q = SIT_MFI.sa
		G.own_y = ST.center and 0 or Q.dy
		G.k = (ST.center and Q.rc or Q.rd) / (RL[rng] * NM)
	end
	if ST.exp then
		G.k = SIT.BOX / (SIT.EXP_NM * NM)
		local cx, cz = G.cur_x or G.ox, G.cur_z or G.oz
		local sx, sy = to_screen(G.ox - cx, G.oz - cz)
		G.own_x, G.own_y = sx, sy
	end

	local stale = (t - feed.rx) > SIT.STALE_S
	G.dt = t - (G.last_t or t)
	G.last_t = t
	-- SIT has the cursor: the export keeps the TDC slew at ~0 (told twice a
	-- second); leaving the SIT page gives the cursor back to the radar
	if ST.soi_sit and ST.page ~= PG.SIT then
		ST.soi_sit = false; log("SIT page left: cursor back to the radar")
		to_export(string.format("S27MFDQ,0,%.4f,%.4f", SLEW.raw_h or 0, SLEW.raw_v or 0))
	end
	if ST.soi_sit and SIT.SQUELCH_RADAR and t - (ST.q_t or -10) >= 0.5 then ST.q_t = t; to_export("S27MFDQ,1") end
	-- the datalink picture is only shown on these pages: off them the export
	-- skips DCS's world scan (several ms on a busy server). Told on every
	-- change and once a second.
	local need = (ST.page == PG.SIT or ST.page == PG.FLT or ST.page == PG.SETS or ST.page == PG.PIC) and 1 or 0
	if need ~= ST.pic_need or t - (ST.pic_t or -10) >= 1 or t < (ST.pic_t or 0) then
		ST.pic_need, ST.pic_t = need, t
		to_export("S27MFDG," .. need)
	end

	H.own_y:set(G.own_y)
	H.own_x:set(G.own_x)
	H.center:set((ST.center or ST.exp) and 1 or 0)
	H.rng:set(RL[rng])
	H.rng_mode:set((ST.form or ST.exp) and 1 or 0)
	H.rngt:set(ST.exp and ("E" .. SIT.EXP_NM) or (ST.form and ("F" .. RL[1])) or "")
	H.page:set(ST.page)
	if SIT.MFI then
		local tb, sb = SIT_MFI.where(ST.page)
		if tb then ST.mfi_last[tb] = ST.page end
		H.mfi_tab:set(tb or 0); H.mfi_sub:set(sb or 0)
		H.flt_sel:set(ST.fsel and 1 or 0)
	end
	H.dclt:set(ST.dcl >= 3 and 1 or 0); if G.dcl_n ~= ST.dcl then G.dcl_n = ST.dcl; H.dcl_lv:set("DCLT " .. ST.dcl .. " " .. SIT.DCL_NAMES[ST.dcl]) end; H.dcl_pop:set((now() - (ST.dcl_t or -10) < 2.5) and 1 or 0); H.lines:set(ST.lines and 1 or 0); H.fch:set(ST.fch)
	if t - ST.ipf_t < 3 then H.net:set("IPF RESET")
	elseif t - ST.net_t < 2 then H.net:set("NET ENTRY: IN PROGRESS")
	elseif t - ST.net_t < 4 then H.net:set("NET ENTRY: COARSE")
	else H.net:set(stale and "NET ENTRY: NONE" or "NET ENTRY: FINE") end
	if ST.dtm_msg ~= "" and t - ST.dtm_t < 2.5 then H.dtm:set(ST.dtm_msg)
	elseif t - ST.dtm_t < 12 then H.dtm:set(ST.dtm_done)
	else H.dtm:set("") end
	H.autor:set(ST.autor and 1 or 0)
	H.dl:set(ST.dl and 1 or 0)
	H.rte:set(ST.rte and 1 or 0); H.thr:set(ST.thr and 1 or 0)
	H.nav_add:set(ST.add and 1 or 0); H.manu:set(ST.man_entry == "ukv" and 1 or 0); H.mank:set(ST.man_entry == "kv" and 1 or 0); H.nup:set(ST.nup and 1 or 0); H.form:set(ST.form and 1 or 0); H.pic_bull:set(ST.pic_bull and 1 or 0); H.rdrl:set(ST.rdr and 1 or 0)

	local tod = (get_absolute_model_time and get_absolute_model_time()) or t
	local off = feed.date and SIT.UTC_OFFSET[feed.date.th]
	local zt = (ST.zulu and off) and (tod - off * 3600) or nil
	local sec = floor(zt or tod)
	if sec ~= G.t_sec or (zt ~= nil) ~= G.t_z then
		G.t_sec, G.t_z = sec, zt ~= nil
		if zt then
			H.time:set(string.format("%02d:%02d:%02dZ", floor(zt / 3600) % 24, floor(zt / 60) % 60, sec % 60))
		else
			H.time:set(string.format("%02d:%02d:%02d", floor(tod / 3600) % 24, floor(tod / 60) % 60, sec % 60))
		end
	end
	G.tod = tod

	local s = feed.status or 0
	local ewr = EWR.fresh(t) and (stale or s % 2 == 0)
	if ewr then
		H.status:set("DL EWR REPORTS")
	elseif stale then
		H.status:set(udp and "NO DL" or "NO LINK SOCKET")
	elseif s % 2 == 0 then
		H.status:set("DL OFF (SERVER)")
	elseif s ~= G.st_s then
		G.st_s = s
		local a, f = floor(s / 2) % 2 == 1, floor(s / 8) % 2 == 1
		G.st_txt = "DL " .. ((a and f) and "AWACS F2F" or a and "AWACS" or f and "F2F" or "OWN")
		H.status:set(G.st_txt)
	else
		H.status:set(G.st_txt)
	end

	-- the SA scope only while the SA page is on screen (v0.9)
	if ST.page == PG.SIT then
		draw_scope()
		draw_route()
		draw_cursor(stale)
		draw_geo()
		draw_threats(stale)
		draw_contacts(t, stale)
		draw_missiles(t)
		draw_marks()
		draw_lock(t, stale)
		draw_crs()
		draw_bull()
		draw_stores(stale)
		if SIT.MFI and MFIDEV then MFIDEV.sa(t, stale) end
	end
	if SIT.MFI and MFIDEV then MFIDEV.every(t, stale) end
	draw_pages(t, stale)
end

-- v1.3 MFI: the MFI edition's pages (MFD/mfd_mfi_dev.lua) get this file's
-- state and helpers in one table (a separate file: this one is near Lua's
-- 200 locals of a chunk)
if SIT.MFI then
	S27A = {feed = feed, ST = ST, G = G, H = H, HC = HC, P = P, PT = PT, safe_text = safe_text, log = log, now = now,
		brg_rng = brg_rng, to_screen = to_screen, inside = inside, route_now = route_now, active_now = active_now,
		wp_step = wp_step, KIN = KIN, sd_val = sd_val, sensors = sensors, radp = radp, rq_push = rq_push,
		com_key = com_key, com_man = com_man, rng_txt = rng_txt, alt_txt = alt_txt, alt_str = alt_str, alt_num = alt_num,
		spd_txt = spd_txt, mmss = mmss, clock_txt = clock_txt, slots = slots, short_sta = short_sta, store_typ = store_typ,
		bull_now = bull_now, pic_groups = pic_groups, aspect_word = aspect_word, eta_s = eta_s,
		slots_now = slots_now, slot_of = slot_of, flt_find = flt_find, flt_candidates = flt_candidates,
		put_in_slot = put_in_slot, flt_auto = flt_auto, flt_changed = flt_changed, freeze = freeze, own_name = own_name,
		dtm_choices = dtm_choices, dtm_name = dtm_name, dtm_apply = dtm_apply, dtm_msg = dtm_msg,
		msg = msg, work_copy = work_copy, renumber = renumber, add_point = add_point,
		nav_add = nav_add, nav_del = nav_del, nav_rst = nav_rst, add_enter = add_enter, man_enter = man_enter,
		EWR = EWR, PGF = PGF, NM = NM, PG = PG, HSI = HSI, sit_range = sit_range, dcl_step = dcl_step,
		ACTIONS = ACTIONS, PWR = PWR, ADD_STEP = ADD_STEP, MAN_LEN = MAN_LEN, flt_members = flt_members,
		tick = function() return tick end, rwr_label = rwr_label}
	local ok, err = pcall(dofile, LockOn_Options.script_path .. "MFD/mfd_mfi_dev.lua")
	if not ok then log("mfd_mfi_dev.lua: " .. tostring(err)) end
end

need_to_be_closed = false

-- timing log (Options > Special > Su-27 Radio: debug logs, off by
-- default), Logs\s27mfd_perf.log: every 30 s the average and worst time of
-- one update and the Lua memory used (os.clock: 1 ms steps)
function update()
	if not PF.on then
		local ok, err = pcall(update_body)
		if not ok and log_n < 60 then log("update error: " .. tostring(err)) end
		return
	end
	local c0 = os.clock()
	local ok, err = pcall(update_body)
	if not ok and log_n < 60 then log("update error: " .. tostring(err)) end
	local dt = os.clock() - c0
	PF.n, PF.sum = PF.n + 1, PF.sum + dt
	if ST.page == PG.SIT then PF.sn, PF.ssum = (PF.sn or 0) + 1, (PF.ssum or 0) + dt end
	if dt > PF.max then PF.max = dt end
	local t = os.clock()
	PF.t = PF.t or t
	if t - PF.t >= 30 and PF.blocks < 200 then
		PF.blocks = PF.blocks + 1
		pcall(function()
			local l = require("lfs")
			-- (kept over respawns: appended, a header per flight; started anew past 200 KB)
			local path = l.writedir() .. "Logs/s27mfd_perf.log"
			-- (file size from lfs: the cockpit's io has no working seek)
			local size = 0
			pcall(function() size = tonumber(l.attributes(path, "size")) or 0 end)
			local f = io.open(path, (size > 200000) and "w" or "a")
			if f then
				if PF.blocks == 1 then f:write("=== flight " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n") end
				local sn = PF.sn or 0
				f:write(string.format("%s  updates %d  avg %.3f ms  worst %.1f ms  on SIT %d%% (avg %s ms there)  page %d  Lua mem %.0f KB\n",
					os.date("%H:%M:%S"), PF.n, PF.sum / math.max(PF.n, 1) * 1000, PF.max * 1000, floor(100 * sn / math.max(PF.n, 1) + 0.5),
					sn > 0 and string.format("%.3f", (PF.ssum or 0) / sn * 1000) or "-", ST.page, collectgarbage("count")))
				f:close()
			end
		end)
		PF.n, PF.sum, PF.max, PF.t, PF.sn, PF.ssum = 0, 0, 0, t, 0, 0
	end
end
