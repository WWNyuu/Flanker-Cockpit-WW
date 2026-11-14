-----------------------------------------------------------------------
-- Su-27 Radio (WW): data cartridges for the loader plate
--
-- Saved Games\DCS\DTC\Su-27\<slot> <name>.dtc   (slot 1..6 = КАССЕТА 1..6)
--   e.g. "1 Vitezovi training.dtc", "3 Caucasus ops.dtc"
-- JSON:
--   { "type": "Su-27 DTC", "version": 1, "name": "...", "terrain": "Caucasus",
--     "ukv": [ {"ch": 1, "f": 124.000, "station": "Кутаиси", "call": "Ласточка"}, ... ],   R-800, 100-399.975 MHz, max 20
--     "kv":  [ {"ch": 1, "f": 3.500,   "station": "...",     "call": "..."}, ... ] }      R-864, 3-10 MHz, max 20
-- "station" and "call" are for the channel card (later); only "f" is needed.
-----------------------------------------------------------------------
LDR_DTC = {}

local function lfs_mod()
	local ok, l = pcall(require, "lfs")
	return (ok and type(l) == "table") and l or nil
end

-- DCS's Scripts\JSON.lua (as the F-15C SIT add-on loads it)
local JSON = nil
local function json()
	if JSON then return JSON end
	local roots = {"", "./"}
	local l = lfs_mod()
	if l and l.currentdir then
		local r = l.currentdir()
		if r:sub(-1) ~= "/" and r:sub(-1) ~= "\\" then r = r .. "/" end
		roots[#roots + 1] = r
		roots[#roots + 1] = r .. "../"
	end
	for _, r in ipairs(roots) do
		local f = loadfile(r .. "Scripts/JSON.lua")
		if f then
			local ok, j = pcall(f)
			if ok and j then JSON = j; return JSON end
		end
	end
	return nil
end

local BOM = "\239\187\191"
local BANDS = {ukv = {100.0, 399.975}, kv = {3.0, 10.0}}

-- the file for a slot: the first *.dtc in the folder whose name starts with
-- the slot's digit (then a space, "_" or "-")
function LDR_DTC.find(slot, dir_rel)
	local l = lfs_mod()
	if not l then return nil, "no lfs" end
	local dir = l.writedir() .. dir_rel
	local found = {}
	pcall(function()
		for name in l.dir(dir) do
			if type(name) == "string" and name:lower():match("%.dtc$") and name:match("^" .. slot .. "[ _%-]") then
				found[#found + 1] = name
			end
		end
	end)
	table.sort(found)
	if not found[1] then return nil, "no file for slot " .. slot end
	return dir .. found[1], found[1]
end

-- read + check a cartridge. Returns {name, ukv = {[ch] = {f, station, call}}, kv = {...}} or nil, reason
function LDR_DTC.read(path)
	local fh = io.open(path, "r")
	if not fh then return nil, "cannot be opened" end
	local txt = fh:read("*a") or ""
	fh:close()
	if txt:sub(1, 3) == BOM then txt = txt:sub(4) end
	local J = json()
	if not J then return nil, "no JSON.lua" end
	local ok, d = pcall(function() return J:decode(txt) end)
	if not ok or type(d) ~= "table" then return nil, "not readable as JSON" end
	if not tostring(d.type or ""):find("Su%-27") then return nil, "not a Su-27 cartridge" end
	local out = {name = tostring(d.name or ""), terrain = d.terrain, ukv = {}, kv = {}, n = 0}
	for band, lim in pairs(BANDS) do
		for _, c in ipairs(type(d[band]) == "table" and d[band] or {}) do
			local ch, f = tonumber(c.ch), tonumber(c.f)
			if ch and f and ch >= 1 and ch <= 20 and f >= lim[1] and f <= lim[2] then
				out[band][ch] = {f = f, station = tostring(c.station or ""), call = tostring(c.call or "")}
				out.n = out.n + 1
			end
		end
	end
	if out.n == 0 then return nil, "no usable channels" end
	return out
end
