-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: SMS page additions. The jet from behind with
-- its stores is mfd_page.lua's STORES page (both editions); the MFI page
-- (as the MiG-29 MFI's) adds the selected weapon, gun, countermeasures
-- and the total under it.
-----------------------------------------------------------------------
function S27MFI_SMS(D, U)
	local r = "mf_sm"
	U.root(r, SIT.PG.SMS)
	U.hline(r, "sep", -0.435)
	U.T(r, "sel", U.LX, -0.485, "SMS_SEL", U.K.amber, U.TXC)
	U.T(r, "gun", U.LX, -0.545, "SMS_GUN", U.K.black, U.TXC)
	U.T(r, "cm", U.LX, -0.605, "SMS_CM", U.K.black, U.TXC)
	U.T(r, "tot", U.LX, -0.665, "SMS_TOT", U.K.grey, U.TXC)
end
