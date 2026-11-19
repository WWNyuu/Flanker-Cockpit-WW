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

-- MFD (WIP): clickable spots of the MFD (Shapes\SU27_LDR.edm, MFD_*_CLICK)
-- and of ED's ЦЕЛИ / ИСТРЕБИТЕЛИ keypad on the right console (KP_*_CLICK)
MFD_CMD = {
	OSB0  = 3300,   -- + 1..20: soft keys L1-L5, B1-B5, R1-R5, T1-T5 (1 = pressed, 0 = released)
	PWR   = 3321,   -- ВКЛ: press = on, hold 2 s = off
	BRT_UP = 3322, BRT_DN = 3323,   -- ЯРК rocker
	DAY   = 3324, NIGHT = 3325,     -- ДЕНЬ / НОЧЬ rocker
}
KP_CMD = {
	C1 = 3331, C2 = 3332, C3 = 3333, C4 = 3334, C5 = 3335, C6 = 3336, C7 = 3337, C8 = 3338, C9 = 3339, C10 = 3340,
	ENT = 3341, RST = 3342, F1 = 3343, F2 = 3344, F3 = 3345, F4 = 3346, GR = 3347,
}
-- MFD (WIP) binds, Options > Controls (installer\su27radio_binds.lua)
MFD_KEY = {
	OSB0  = 6210,   -- + 1..20: soft keys L1-L5, B1-B5, R1-R5, T1-T5
	PWR   = 6231,
	BRT_UP = 6232, BRT_DN = 6233,
	DAY   = 6234, NIGHT = 6235,
	STOW  = 6236,   -- fold the MFD away / back (ED's HDD shows when it is away)
}
