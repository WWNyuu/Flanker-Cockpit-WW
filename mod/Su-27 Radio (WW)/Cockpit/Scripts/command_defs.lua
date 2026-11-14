-- Su-27 Radio (WW): commands of the add-on's cockpit device
LDR_CMD = {
	SEL  = 3201,     -- КАССЕТА selector (value = the knob's new argument, 0.0 .. 0.6)
	LOAD = 3202,     -- ЗАГР button (1 = pressed, 0 = released)
}
RAD_CMD = {
	UKV_CH = 3211,   -- УКВ КАНАЛ knob (value = argument, channel n at (n-1) x 0.05)
	KV_CH  = 3212,   -- КВ КАНАЛ knob
	UKV_VOL = 3213,  -- v0.4: УКВ ГРОМК knob (value = argument = volume 0 .. 1)
	KV_VOL  = 3214,  -- v0.4: КВ ГРОМК knob
}
-- v1.1: Options > Controls (Su-27 / J-11A, category "Su-27 Radio (WW)").
-- FC3 does not pass 3xxx through from the controls, so the binds are 62xx
-- (installer\su27radio_binds.lua puts them into the jet's controls files).
RAD_KEY = {
	UKV_CH_UP = 6201, UKV_CH_DN = 6202,
	KV_CH_UP  = 6203, KV_CH_DN  = 6204,
	UKV_VOL_UP = 6205, UKV_VOL_DN = 6206,
	KV_VOL_UP  = 6207, KV_VOL_DN  = 6208,
}
