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
