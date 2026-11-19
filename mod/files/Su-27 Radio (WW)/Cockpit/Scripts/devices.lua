-- Su-27 Radio (WW): device ids for this plugin's own devices
local count = 0
local function counter()
	count = count + 1
	return count
end

devices = {}
devices["LDR"] = counter()
devices["MFD"] = counter()       -- v1.2 (WIP): the MFD over the HDD
devices["FIT"] = counter()       -- v1.3 test 9: Su-33 live fit of the model (fit_device.lua)
