-----------------------------------------------------------------------
-- Su-27 Radio (WW): shared settings of the loader plate (device + indicator)
-----------------------------------------------------------------------
LDR = LDR or {}

LDR.UPDATE     = 0.05      -- device update step (s)
LDR.ARG_SEL    = 801       -- КАССЕТА knob argument (0.0 = МИС, 0.1 .. 0.6 = 1..6)
LDR.SLOTS      = 6
LDR.ARG_UKV    = 803       -- v0.2: УКВ КАНАЛ knob argument (channel n at (n-1) x 0.05)
LDR.ARG_KV     = 804       -- v0.2: КВ КАНАЛ knob argument
LDR.ARG_VOL_UKV = 805      -- v0.4: УКВ ГРОМК knob argument (= SRS volume of radio 1, 0 .. 1)
LDR.ARG_VOL_KV  = 806      -- v0.4: КВ ГРОМК knob argument (radio 2)
LDR.VOL_START  = 0.8       -- v0.4: both ГРОМК knobs at the start of a mission
LDR.VOL_RESEND = 5         -- v0.4: s - the volumes are sent to SRS again this often (SRS resets them on a new aircraft)
LDR.LOAD_S     = 1.2       -- "reading the cassette": window flashes, then the result
LDR.TEST_S     = 1.5       -- lamp test when power comes on (all segments + both lamps)
LDR.RPM_ON     = 50        -- engine RPM (%) that counts as electric power
LDR.POWER_CMD  = 315       -- FC3's electric power switch command (same as the F-15C)
LDR.SRS_PORT   = 9040      -- SRS client UDP command port (SRS setting)
LDR.TUNE_ON_LOAD = true    -- after a load: radio 1 (R-800) and radio 2 (R-864) to the КАНАЛ knobs' channels
LDR.HOOK_PORT  = 42893     -- v0.2: mission presets from Scripts\Hooks\su27radio_hook.lua
LDR.DTC_DIR    = "DTC/Su-27/"   -- in Saved Games\DCS: cartridge "<slot> <name>.dtc", e.g. "3 Caucasus.dtc"

-- v0.1 test: draw a thin frame around the plate edges and a marker in its
-- top-left corner, to check that the indicator sits right (not mirrored,
-- not turned). Set to false once it does.
LDR.ALIGN_TEST = false   -- (checked in 0.1: frame on the edges, triangle top-left)

-- Plate layout (mm, x from the left edge, y from the top edge) - the same
-- numbers as the Blender script. The indicator's units: the anchors span a
-- square with half-size = half the plate width, so 1 unit = 82.5 mm.
LDR.PW, LDR.PH = 165.0, 71.0
LDR.UNIT_MM    = 82.5
LDR.WIN        = {96.0, 27.0, 30.0, 16.0}     -- window centre x, y, width, height
LDR.LAMP_GO    = {145.0, 25.0}
LDR.LAMP_NOGO  = {145.0, 48.5}
LDR.LAMP_R     = 4.2

-- plate mm -> indicator units (x right, y up, from the plate centre)
function LDR.u(x_mm, y_mm)
	return (x_mm - LDR.PW / 2) / LDR.UNIT_MM, (LDR.PH / 2 - y_mm) / LDR.UNIT_MM
end

-- 7-segment font: which segments (a..g) each character lights
LDR.SEGS = {
	["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg",
	["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg",
	["-"] = "g", ["P"] = "abcef", [" "] = "",      -- "P" = Cyrillic П
}
