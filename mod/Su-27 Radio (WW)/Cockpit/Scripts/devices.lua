-- Su-27 Radio (WW): device ids for this plugin's own devices
local count = 0
local function counter()
	count = count + 1
	return count
end

devices = {}
devices["LDR"] = counter()
devices["MFD"] = counter()       -- v1.2 (WIP): the MFD over the HDD
