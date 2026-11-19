-- Su-27 Radio (WW) v1.3 test 9: live fit of the add-on's model in the Su-33.
-- Reads <mod folder>\Su33_fine_tune.lua once a second and drives the fit
-- arguments of SU33_LDR.edm (Tools\su27_ldr_plate.py, FIT_ARGS / FIT_RANGE).
-- Writes Saved Games\DCS\Logs\su27radio_fit.log with the numbers to keep.

local RANGE = 0.30                 -- must match FIT_RANGE in su27_ldr_plate.py
local GROUPS = { {"LDR", 870}, {"RAD", 873}, {"KP", 876}, {"CRD", 879}, {"MFD", 882} }
local AXES = { "forward", "up", "right" }

local STEP = 0.2
make_default_activity(STEP)

local panel = GetDevice(0)
local off = {}
for _, g in ipairs(GROUPS) do off[g[1]] = {0, 0, 0} end
local last_sig = nil
local timer = 1.0
local file_used = nil
local last_err = ""

local function logline(s)
	pcall(function()
		local lfs = require("lfs")
		local f = io.open(lfs.writedir() .. "Logs\\su27radio_fit.log", "a")
		if f then
			f:write(os.date("%Y-%m-%d %H:%M:%S ") .. s .. "\n")
			f:close()
		end
	end)
end

local FILES = {}
if get_dcs_plugin_path then
	local ok, p = pcall(get_dcs_plugin_path, "su27_radio")
	if ok and p then FILES[#FILES + 1] = p .. "/Su33_fine_tune.lua" end
end
FILES[#FILES + 1] = LockOn_Options.script_path .. "../../Su33_fine_tune.lua"

local function clamp(v) if v > 1 then return 1 elseif v < -1 then return -1 end return v end

local function read_file()
	for _, path in ipairs(FILES) do
		local ok, res = pcall(function()
			-- test 13: the cockpit's Lua may have no loadfile / setfenv (test 9-12
			-- read nothing there): then dofile into the globals, as the MFI-55 mod does
			if loadfile and setfenv then
				local env = {}
				local chunk = assert(loadfile(path))
				setfenv(chunk, env)
				chunk()
				return env
			end
			LDR, RAD, KP, CRD, MFD = nil, nil, nil, nil, nil
			dofile(path)
			return {LDR = LDR, RAD = RAD, KP = KP, CRD = CRD, MFD = MFD}
		end)
		if not ok then last_err = tostring(res) end
		if ok and type(res) == "table" then
			if file_used ~= path then
				file_used = path
				logline("reading " .. path)
			end
			for _, g in ipairs(GROUPS) do
				local t = res[g[1]]
				local o = off[g[1]]
				for i = 1, 3 do
					o[i] = (type(t) == "table" and tonumber(t[AXES[i]])) or 0
				end
			end
			return
		end
	end
	if file_used ~= false then
		file_used = false
		logline("Su33_fine_tune.lua not found or has an error (" .. last_err .. "), tried: " .. table.concat(FILES, " | "))
	end
end

local function apply()
	for _, g in ipairs(GROUPS) do
		local o = off[g[1]]
		for i = 1, 3 do
			panel:set_argument_value(g[2] + i - 1, clamp(o[i] / RANGE))
		end
	end
end

local function report()
	local parts = {}
	for _, g in ipairs(GROUPS) do
		local o = off[g[1]]
		parts[#parts + 1] = string.format('    "%s": (%.4f, %.4f, %.4f),', g[1], o[1], o[2], o[3])
	end
	local sig = table.concat(parts, " ")
	if sig == last_sig then return end
	last_sig = sig
	logline("offsets (forward, up, right in metres), ADD them to SU33_SHIFT in su27_ldr_plate.py:")
	for _, l in ipairs(parts) do logline(l) end
end

function post_initialize()
	logline("loaded for " .. tostring(get_aircraft_type and get_aircraft_type() or "?"))
	read_file()
	apply()
	report()
end

function update()
	timer = timer - STEP
	if timer <= 0 then
		timer = 1.0
		read_file()
		report()
	end
	apply()
end

need_to_be_closed = false
