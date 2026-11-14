-----------------------------------------------------------------------
-- Su-27 Radio (WW) 0.2: the mission's radio presets for the Su-27 cockpit
--
-- The cockpit can't see the mission. This hook (Saved Games\DCS\Scripts\
-- Hooks) finds the player's Su-27 / J-11A in the mission and sends its
-- radio presets to the add-on every 2 s (UDP 127.0.0.1:42893):
--   SU27R|<group frequency>|<radio 1 ch1>,<ch2>...|<radio 2 ch1>,...   (MHz)
-- Radio 1 = R-800 (УКВ), radio 2 = R-864 (КВ). With no presets for radio 1
-- in the mission, УКВ channel 1 = the group's frequency.
-- Log: Saved Games\DCS\Logs\su27radio_hook.log
-----------------------------------------------------------------------
local H = {}
local PORT = 42893
local udp, msg, last, mission = nil, nil, -100, nil
local unit_seen, searched = nil, false
local enabled = true
local TYPES = {["Su-27"] = true, ["J-11A"] = true}

local function log(s)
	pcall(function()
		local l = lfs or require("lfs")
		local f = io.open(l.writedir() .. "Logs/su27radio_hook.log", "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(s) .. "\n"); f:close() end
	end)
end

local function read_options()
	enabled = true
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		local p = env.options and env.options.plugins and env.options.plugins["su27_radio"]
		if type(p) == "table" and p.su27_radio_enabled == false then enabled = false end
	end)
end

local function sock()
	if udp then return udp end
	pcall(function()
		package.path = package.path .. ";.\\LuaSocket\\?.lua"
		package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll"
		local socket = require("socket")
		udp = socket.udp()
		udp:settimeout(0)
	end)
	return udp
end

local function mhz(f)
	f = tonumber(f) or 0
	if f > 1e5 then f = f / 1e6 end          -- Hz -> MHz
	return f
end

-- the player's unit in the mission -> its presets
local function read_presets()
	local ok, err = pcall(function()
		local uid = DCS.getPlayerUnit and DCS.getPlayerUnit()
		if uid == unit_seen and (msg or searched) then return end
		unit_seen, searched = uid, uid ~= nil
		msg = nil
		if not uid or not mission or type(mission.coalition) ~= "table" then return end
		uid = tonumber(uid)
		for _, side in pairs(mission.coalition) do
			for _, c in pairs(type(side) == "table" and side.country or {}) do
				local gs = type(c.plane) == "table" and c.plane.group or {}
				for _, g in pairs(gs) do
					for _, u in pairs(type(g.units) == "table" and g.units or {}) do
						if tonumber(u.unitId) == uid then
							if not TYPES[tostring(u.type)] then
								log("player unit " .. uid .. " is a " .. tostring(u.type) .. ": nothing to send")
								return
							end
							local parts = {string.format("%.3f", mhz(g.frequency))}
							for k = 1, 2 do
								local rd = type(u.Radio) == "table" and u.Radio[k]
								local list = {}
								if type(rd) == "table" and type(rd.channels) == "table" then
									for ch = 1, 20 do
										local f = rd.channels[ch]
										list[#list + 1] = f and string.format("%.3f", mhz(f)) or ""
									end
								end
								parts[#parts + 1] = table.concat(list, ",")
							end
							msg = "SU27R|" .. table.concat(parts, "|")
							log("presets of unit " .. uid .. " (" .. tostring(u.type) .. "): " .. msg)
							return
						end
					end
				end
			end
		end
		log("player unit " .. tostring(uid) .. " not found in the mission (dynamic slot?)")
	end)
	if not ok then log("presets: " .. tostring(err)) end
end

function H.onSimulationStart()
	last, msg, unit_seen, searched, mission = -100, nil, nil, false, nil
	read_options()
	if not enabled then return end
	pcall(function()
		local m = DCS.getCurrentMission()
		mission = (type(m) == "table" and m.mission) or m
	end)
end

function H.onSimulationStop()
	msg, unit_seen, searched, mission = nil, nil, false, nil
end

function H.onSimulationFrame()
	if not enabled or not mission then return end
	local t = DCS.getRealTime()
	if t - last < 2 then return end
	last = t
	read_presets()
	local u = msg and sock()
	if u then pcall(u.sendto, u, msg, "127.0.0.1", PORT) end
end

DCS.setUserCallbacks(H)
log("loaded")
