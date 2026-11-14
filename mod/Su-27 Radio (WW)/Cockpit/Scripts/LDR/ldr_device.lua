-----------------------------------------------------------------------
-- Su-27 Radio (WW) 0.3: the add-on's cockpit device
--
-- Data loader plate (ВВОД ДАННЫХ, right console):
--   КАССЕТА  МИС = the mission's presets, 1..6 = cartridge files
--            (Saved Games\DCS\DTC\Su-27\<slot> <name>.dtc)
--   ЗАГР     loads the selected one: the window flashes for a moment, then
--            ГОТОВ (loaded, the window shows П<slot>) or ОТКАЗ (no file /
--            bad file; the window keeps the cartridge loaded before)
-- УКВ / КВ radio panel (left console), v0.2:
--   КАНАЛ    channels 1-20 of the loaded presets; each step tunes SRS
--            (УКВ = R-800 = radio 1, КВ = R-864 = radio 2); the window
--            shows the channel number
-- Channel card (КАНАЛЫ РАДИОСВЯЗИ, right canopy rail), v0.3: written by
--   hand from the loaded presets - the channels that have a frequency, УКВ
--   first, then КВ; channel, frequency, station, callsign. Paper: shown with
--   or without power.
-- Power: dark without electric power; a short lamp test when it comes on.
-- Log: Saved Games\DCS\Logs\su27radio.log
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "devices.lua")
dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path .. "LDR/ldr_config.lua")
dofile(LockOn_Options.script_path .. "LDR/ldr_dtc.lua")

local dev = GetSelf()
make_default_activity(LDR.UPDATE)

local floor = math.floor

---------------------------------------------------------------------------
-- log
---------------------------------------------------------------------------
local LOG_MAX = 60
local log_n = 0
local function log(msg)
	if log_n > LOG_MAX then return end
	log_n = log_n + 1
	pcall(function()
		local lfs = require("lfs")
		local f = io.open(lfs.writedir() .. "Logs/su27radio.log", log_n == 1 and "w" or "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
	end)
end

---------------------------------------------------------------------------
-- parameters (written only when they change)
---------------------------------------------------------------------------
local PH = {}
PH.__index = PH
function PH:set(v) if v ~= self.v then self.v = v; self.h:set(v) end end
local function P(n) return setmetatable({h = get_param_handle(n)}, PH) end

local SEG_NAMES = {"a", "b", "c", "d", "e", "f", "g"}
local function seg_set(prefix)            -- prefix .. <digit> .. <SEG>
	local t = {}
	for d = 1, 2 do
		t[d] = {}
		for _, s in ipairs(SEG_NAMES) do t[d][s] = P(prefix .. d .. s:upper()) end
	end
	return t
end
local H = {go = P("LDR_GO"), nogo = P("LDR_NOGO"), align = P("LDR_ALIGN"),
           ldr = seg_set("LDR_S"), ukv = seg_set("RAD_U"), kv = seg_set("RAD_K")}

local function show(segs, text)           -- two characters; nil = dark
	for d = 1, 2 do
		local lit = text and LDR.SEGS[text:sub(d, d)] or ""
		for _, s in ipairs(SEG_NAMES) do segs[d][s]:set(lit:find(s, 1, true) and 1 or 0) end
	end
end

---------------------------------------------------------------------------
-- channel card (v0.3)
---------------------------------------------------------------------------
-- text parameter: created and given a string in the same step (a text
-- parameter still holding the number 0 crashes DCS - F-15C SIT add-on notes)
local function PT(n) local h = P(n); h:set(""); return h end
-- a "%s" text must never look like a number (DCS would store it as one and
-- crash on the "%s")
local function safe_text(v)
	v = tostring(v or "")
	if tonumber(v) then v = "~" .. v end
	return v
end
-- first n characters of a UTF-8 string (Cyrillic is 2 bytes a letter)
local function u8sub(s, n)
	local out, k = {}, 0
	for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		k = k + 1
		if k > n then break end
		out[#out + 1] = ch
	end
	return table.concat(out)
end
local CRD_ROWS = 20
local CRD = {title = PT("CRD_TITLE"), title_on = P("CRD_TITLE_ON"), rows = {}}
for n = 1, CRD_ROWS do
	CRD.rows[n] = {on = P("CRD_" .. n .. "_ON"), ch = P("CRD_" .. n .. "_CH"), f = P("CRD_" .. n .. "_F"),
	               st = PT("CRD_" .. n .. "_ST"), cs = PT("CRD_" .. n .. "_CS")}
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local ST = {
	sel = 0,            -- КАССЕТА position: 0 = МИС, 1..6
	loaded = 0,         -- cartridge in use (0 = mission presets)
	data = nil,         -- its channels {name, ukv = {[ch] = {f, ...}}, kv = {...}}
	mis = nil,          -- the mission's presets (from the hook), same layout
	busy_t = nil,       -- ЗАГР pressed: reading until busy_t + LOAD_S
	result = "go",      -- "go" / "nogo" (lamps); at the start the mission presets are in
	ch = {ukv = 1, kv = 1},
	vol = {ukv = LDR.VOL_START, kv = LDR.VOL_START},   -- v0.4: ГРОМК knobs
	vol_t = nil,        -- last time the volumes went to SRS
}
local PWR = {sw = nil, on = false, test_t = nil, tuned = false}
local BAND_RADIO = {ukv = 1, kv = 2}      -- SRS radio numbers

local function now() return get_model_time and get_model_time() or 0 end

local SD = nil
local function sd_val(name)
	if not SD and get_base_data then
		local ok, d = pcall(get_base_data); if ok then SD = d end
	end
	local f = SD and SD[name]
	if not f then return nil end
	local ok, v = pcall(f)
	return ok and tonumber(v) or nil
end

---------------------------------------------------------------------------
-- UDP: SRS commands out, mission presets in (Scripts\Hooks\su27radio_hook.lua)
---------------------------------------------------------------------------
local udp, udp_state = nil, "init"
local function open_udp()
	local ok = pcall(function()
		local ok_lfs, lfs_mod = pcall(require, "lfs")
		local root = (ok_lfs and lfs_mod and lfs_mod.currentdir and lfs_mod.currentdir()) or "."
		if not package.path:find(root .. "/LuaSocket/?.lua", 1, true) then
			package.path  = package.path .. ";" .. root .. "/LuaSocket/?.lua"
			package.cpath = package.cpath .. ";" .. root .. "/LuaSocket/?.dll"
		end
		local socket = require("socket")
		local u = socket.udp()
		u:settimeout(0)
		local r = u:setsockname("127.0.0.1", LDR.HOOK_PORT)
		if not r then
			pcall(function() u:setoption("reuseaddr", true) end)
			r = u:setsockname("127.0.0.1", LDR.HOOK_PORT)
		end
		udp_state = r and "listening" or "send only (port busy)"
		udp = u
	end)
	if not ok then udp_state = "no LuaSocket" end
end
local function srs_set(radio, f)
	if not (udp and f) then return end
	local msg = string.format('{"RadioId":%d,"Frequency":%.3f,"Command":12}', radio, f)
	pcall(function() udp:sendto(msg, "127.0.0.1", LDR.SRS_PORT) end)
	log(string.format("SRS: radio %d -> %.3f MHz", radio, f))
end
-- v0.4: volume of an SRS radio, 0 .. 1 (SRS command 5 = SET_VOLUME; the
-- Su-27's radios are "overlay volume" radios in SRS, so it takes it)
local function srs_vol(radio, v, quiet)
	if not (udp and v) then return end
	local msg = string.format('{"RadioId":%d,"Volume":%.2f,"Command":5}', radio, v)
	pcall(function() udp:sendto(msg, "127.0.0.1", LDR.SRS_PORT) end)
	if not quiet then log(string.format("SRS: radio %d volume %d%%", radio, floor(v * 100 + 0.5))) end
end

---------------------------------------------------------------------------
-- presets and tuning
---------------------------------------------------------------------------
local function presets()
	if ST.loaded == 0 then return ST.mis end
	return ST.data
end

-- the card shows what is loaded: rows for every channel with a frequency
local function card_update()
	local p = presets()
	local list = {}
	for _, band in ipairs({"ukv", "kv"}) do
		local t = p and p[band] or {}
		for ch = 1, 20 do
			if t[ch] then list[#list + 1] = {band = band, ch = ch, c = t[ch]} end
		end
	end
	if #list > CRD_ROWS then log("card: " .. #list .. " channels, only " .. CRD_ROWS .. " rows") end
	for n = 1, CRD_ROWS do
		local r, e = CRD.rows[n], list[n]
		if e then
			r.st:set(safe_text(u8sub(e.c.station, 15)))
			r.cs:set(safe_text(u8sub(e.c.call, 13)))
			r.ch:set(e.ch)
			r.f:set(e.c.f)
			r.on:set(e.band == "ukv" and 1 or 2)
		else
			r.on:set(0)
		end
	end
	local title
	if ST.loaded == 0 then
		title = ST.mis and "МИС - задание" or "МИС - нет данных"
	else
		title = "кассета " .. ST.loaded .. " - " .. u8sub((ST.data and ST.data.name) or "", 28)
	end
	CRD.title:set(safe_text(title))
	CRD.title_on:set(1)
end

local function tune(band)
	local p = presets()
	local c = p and p[band] and p[band][ST.ch[band]]
	if c then
		srs_set(BAND_RADIO[band], c.f)
	else
		log(string.format("%s channel %d: no preset", band, ST.ch[band]))
	end
end
local function tune_all() tune("ukv"); tune("kv") end
local function vol_all(quiet)
	srs_vol(BAND_RADIO.ukv, ST.vol.ukv, quiet); srs_vol(BAND_RADIO.kv, ST.vol.kv, quiet)
	ST.vol_t = now()
end

-- "SU27R|<group freq>|<radio 1: f,f,f...>|<radio 2: ...>" (MHz)
local function read_hook()
	if not udp then return end
	for _ = 1, 5 do
		local data = udp:receive(8192)
		if not data then return end
		if data:sub(1, 6) == "SU27R|" and data ~= ST.mis_raw then
			ST.mis_raw = data
			local parts = {}
			for p in (data .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = p end
			local m = {ukv = {}, kv = {}, n = 0, name = "mission"}
			local function list(s, band, lo, hi)
				local k = 0
				if not s or s == "" then return end
				for f in (s .. ","):gmatch("([^,]*),") do      -- (empty fields keep their channel number)
					k = k + 1
					local v = tonumber(f)
					if v and v >= lo and v <= hi and k <= 20 then m[band][k] = {f = v, station = "", call = ""}; m.n = m.n + 1 end
				end
			end
			list(parts[3], "ukv", 100.0, 399.975)
			list(parts[4], "kv", 3.0, 10.0)
			local g = tonumber(parts[2])
			if not m.ukv[1] and g and g >= 100 and g <= 399.975 then m.ukv[1] = {f = g, station = "своя группа", call = ""}; m.n = m.n + 1 end
			ST.mis = m
			log(string.format("mission presets: %d channels (group %.3f)", m.n, g or 0))
			if ST.loaded == 0 then card_update() end
			if ST.loaded == 0 and PWR.on and not PWR.test_t then tune_all() end
		end
	end
end

---------------------------------------------------------------------------
-- loading
---------------------------------------------------------------------------
local function do_load()
	local slot = ST.sel
	if slot == 0 then
		ST.loaded, ST.data, ST.result = 0, nil, "go"
		log("ЗАГР: МИС (mission presets" .. (ST.mis and "" or ", none received yet") .. ")")
		card_update()
		tune_all()
		return
	end
	local path, why = LDR_DTC.find(slot, LDR.DTC_DIR)
	local data
	if path then data, why = LDR_DTC.read(path) end
	if not data then
		ST.result = "nogo"
		log("ЗАГР: slot " .. slot .. " - ОТКАЗ: " .. tostring(why))
		return
	end
	ST.loaded, ST.data, ST.result = slot, data, "go"
	log(string.format("ЗАГР: slot %d - ГОТОВ: %s (%d channels)", slot, data.name, data.n))
	card_update()
	if LDR.TUNE_ON_LOAD then tune_all() end
end

---------------------------------------------------------------------------
-- DCS callbacks
---------------------------------------------------------------------------
local function arg_now(a)
	local ok, v = pcall(function() return get_cockpit_draw_argument_value and get_cockpit_draw_argument_value(a) end)
	return ok and tonumber(v) or nil
end
local function chan_of(v) return (floor((v or 0) * 20 + 0.5) % 20) + 1 end

-- v0.4.1: turn the ГРОМК knobs to VOL_START at the start. DCS starts every
-- argument at 0, and a click steps from where the knob is, so the knob itself
-- must be at 80 % (0.4.0 only told SRS 80 %: the first click gave 5 %).
-- Three ways DCS offers; each is tried, then checked on the next update.
local VOL_KNOB = {
	ukv = {arg = LDR.ARG_VOL_UKV, cmd = RAD_CMD.UKV_VOL, click = "RAD_VUKV_CLICK", tries = 0},
	kv  = {arg = LDR.ARG_VOL_KV,  cmd = RAD_CMD.KV_VOL,  click = "RAD_VKV_CLICK",  tries = 0},
}
local VOL_WAYS = {
	{"main panel argument", function(k, v) GetDevice(0):set_argument_value(k.arg, v) end},
	{"clickable element", function(k, v) get_clickable_element_reference(k.click):set_value(v) end},
	{"clickable action", function(k, v) GetSelf():performClickableAction(k.cmd, v, false) end},
}
local function knob_init()
	for band, k in pairs(VOL_KNOB) do
		if not k.done then
			local v = arg_now(k.arg)
			if v and math.abs(v - LDR.VOL_START) < 0.02 then
				k.done = true
				log(string.format("ГРОМК %s at %d%% (%s)", band, floor(LDR.VOL_START * 100 + 0.5), k.way or "already"))
			elseif k.tries >= 3 * #VOL_WAYS then
				k.done = true
				log(string.format("ГРОМК %s: could not turn the knob (argument %s); SRS stays at %d%%", band, tostring(v), floor(ST.vol[band] * 100 + 0.5)))
			else
				local w = VOL_WAYS[(k.tries % #VOL_WAYS) + 1]
				k.tries = k.tries + 1
				local ok = pcall(w[2], k, LDR.VOL_START)
				if ok then k.way = w[1] end
			end
		end
	end
end

function post_initialize()
	dev:listen_command(LDR_CMD.SEL)
	dev:listen_command(LDR_CMD.LOAD)
	dev:listen_command(RAD_CMD.UKV_CH)
	dev:listen_command(RAD_CMD.KV_CH)
	dev:listen_command(RAD_CMD.UKV_VOL)
	dev:listen_command(RAD_CMD.KV_VOL)
	dev:listen_command(LDR.POWER_CMD)
	open_udp()
	H.align:set(LDR.ALIGN_TEST and 1 or 0)
	show(H.ldr, nil); show(H.ukv, nil); show(H.kv, nil); H.go:set(0); H.nogo:set(0)
	-- knob positions at the start (DCS keeps the arguments)
	local v = arg_now(LDR.ARG_SEL)
	if v then ST.sel = math.max(0, math.min(LDR.SLOTS, floor(v * 10 + 0.5))) end
	ST.ch.ukv = chan_of(arg_now(LDR.ARG_UKV))
	ST.ch.kv = chan_of(arg_now(LDR.ARG_KV))
	-- v0.4: ГРОМК knobs: a knob already turned (mission restart) keeps its
	-- volume; one at 0 is put to VOL_START once the cockpit runs (knob_init)
	for band, a in pairs(VOL_KNOB) do
		local v = arg_now(a.arg)
		if v and v >= 0.001 then ST.vol[band] = v; a.done = true else ST.vol[band] = LDR.VOL_START end
	end
	-- Options > Special > Su-27 Radio: debug log
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env); f()
		local p = env.options and env.options.plugins and env.options.plugins["su27_radio"]
		if type(p) == "table" and p.su27_radio_logs == true then LOG_MAX = 1000 end
	end)
	card_update()
	log("Su-27 Radio (WW) 1.0 up (" .. tostring(get_aircraft_type and get_aircraft_type()) .. "), UDP " .. udp_state)
end

function SetCommand(command, value)
	if command == LDR.POWER_CMD then
		if PWR.sw ~= nil then PWR.sw = not PWR.sw end
		log("electric power switch: " .. tostring(PWR.sw))
		return
	end
	if command == LDR_CMD.SEL then
		ST.sel = math.max(0, math.min(LDR.SLOTS, floor((value or 0) * 10 + 0.5)))
	elseif command == LDR_CMD.LOAD then
		if (value or 0) > 0 and PWR.on and not ST.busy_t and not PWR.test_t then
			ST.busy_t, ST.result = now(), nil
		end
	elseif command == RAD_CMD.UKV_CH or command == RAD_CMD.KV_CH then
		local band = (command == RAD_CMD.UKV_CH) and "ukv" or "kv"
		local ch = chan_of(value)
		if ch ~= ST.ch[band] then
			ST.ch[band] = ch
			if PWR.on and not PWR.test_t then tune(band) end
		end
	elseif command == RAD_CMD.UKV_VOL or command == RAD_CMD.KV_VOL then
		local band = (command == RAD_CMD.UKV_VOL) and "ukv" or "kv"
		local v = math.max(0, math.min(1, floor((value or 0) * 20 + 0.5) / 20))
		if v ~= ST.vol[band] then
			ST.vol[band] = v
			srs_vol(BAND_RADIO[band], v)
		end
	end
end

local function power_tick(t)
	local rl, rr = sd_val("getEngineLeftRPM"), sd_val("getEngineRightRPM")
	local rpm = nil
	if rl or rr then
		rpm = math.max(rl or 0, rr or 0)
		if rpm > 0.3 and rpm <= 1.5 then rpm = rpm * 100 end
	end
	if PWR.sw == nil then
		PWR.sw = (rpm == nil) or rpm >= LDR.RPM_ON          -- hot / air start: on
		log("power at start: " .. (PWR.sw and "on" or "off (cold start)"))
	end
	local on = PWR.sw or (rpm ~= nil and rpm >= LDR.RPM_ON)
	if on and not PWR.on then PWR.test_t = t; PWR.tuned = false end   -- lamp test
	PWR.on = on
	return on
end

function update()
	local t = now()
	if not (VOL_KNOB.ukv.done and VOL_KNOB.kv.done) then knob_init() end
	read_hook()
	if not power_tick(t) then
		show(H.ldr, nil); show(H.ukv, nil); show(H.kv, nil); H.go:set(0); H.nogo:set(0)
		ST.busy_t = nil
		return
	end
	if PWR.test_t then
		if t - PWR.test_t < LDR.TEST_S then
			show(H.ldr, "88"); show(H.ukv, "88"); show(H.kv, "88"); H.go:set(1); H.nogo:set(1)
			return
		end
		PWR.test_t = nil
	end
	if not PWR.tuned then PWR.tuned = true; tune_all(); vol_all() end
	if not ST.vol_t or t - ST.vol_t >= LDR.VOL_RESEND then vol_all(true) end
	show(H.ukv, string.format("%02d", ST.ch.ukv))
	show(H.kv, string.format("%02d", ST.ch.kv))
	if ST.busy_t then
		local el = t - ST.busy_t
		if el < LDR.LOAD_S then
			show(H.ldr, (floor(el / 0.2) % 2 == 0) and "--" or nil)    -- reading the cassette
			H.go:set(0); H.nogo:set(0)
			return
		end
		ST.busy_t = nil
		do_load()
	end
	show(H.ldr, "P" .. ST.loaded)
	H.go:set(ST.result == "go" and 1 or 0)
	H.nogo:set(ST.result == "nogo" and 1 or 0)
end
