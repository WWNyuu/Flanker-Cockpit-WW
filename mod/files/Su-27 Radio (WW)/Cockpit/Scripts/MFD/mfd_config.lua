-----------------------------------------------------------------------
-- Su-27 MFD (WW) 0.2: settings of the MFD over the HDD (forked from the
-- F-15C SIT (WW) add-on's sit_config.lua; the table keeps the name SIT).
-- Read by MFD/mfd_device.lua and the page (MFD/indicator/mfd_page.lua).
-----------------------------------------------------------------------
SIT = SIT or {}

-- units of the whole MFD: true = metric (km, m, km/h: the Su-27's own),
-- false = imperial (NM, ft, kt)
SIT.METRIC        = true
SIT.RNG_M         = SIT.METRIC and 1000 or 1852       -- one range unit, metres
SIT.RNG_LBL       = SIT.METRIC and "KM" or "NM"
SIT.ALT_M         = SIT.METRIC and 1000 or 304.8      -- contact altitudes in km (one decimal) / thousands of feet
SIT.SPD_K         = SIT.METRIC and 3.6 or 1.94384     -- m/s -> km/h / kt
SIT.SPD_LBL       = SIT.METRIC and "KMH" or "KT"
-- range steps (range units, ownship to the top edge of the SA circle)
SIT.RANGES_NM     = SIT.METRIC and {10, 20, 40, 80, 160, 320} or {5, 10, 20, 40, 80, 160}
SIT.RANGES_DC_NM  = SIT.METRIC and {15, 30, 60, 120, 240, 480} or {7, 15, 30, 60, 120, 240}   -- decentred
SIT.RANGE_DEFAULT = 4                          -- 80 km / 40 NM

SIT.MAX_CONTACTS  = 40      -- must match max_contacts in S27MFD_Export.lua
SIT.MAX_WPTS      = 20
SIT.MAX_THREATS   = 12
SIT.RING_SEGS     = 24      -- segments of a threat ring

-- page layout (page units, 1 = 88.9 mm: the screen is 152 x 144 mm, so it
-- runs from -0.855 to +0.855 across and -0.81 to +0.81 up)
SIT.EDGE          = 0.81    -- screen edge (top / bottom)
SIT.EDGE_X        = 0.855   -- screen edge (left / right)
SIT.BOX           = 0.70    -- symbols are hidden outside this square (labels live outside it)
SIT.CENTER_Y      = 0.0     -- centred: ownship in the middle ...
SIT.CENTER_R      = 0.60    -- ... compass rose radius = selected range
SIT.DECENTER_Y    = -0.45   -- decentred: ownship low (about 12 NM behind on the 40 scale) ...
SIT.HALF_RING     = true    -- centred: thin solid ring at half range (manual); false = off
SIT.ROSE_R        = 0.20    -- decentred: small compass rose around the ownship
-- radar coverage (cyan lines): scan centre / width / range from the radar
-- (LoGetSightingSystemInfo in the export). RADAR_SIZE_HALF: the scan width
-- the radar reports is the half width (+-); false = full width
SIT.RADAR_SIZE_HALF = false   -- v0.5: DCS reports the full width (2.094 = 120 deg)

-- page font: "texture" = the add-on's stroke font (Textures/IndicationTextures/
-- s27mfd_font.dds), "arial" = DCS's Arial
SIT.FONT_STYLE    = "texture"
SIT.FONT_SCALE    = 1.0     -- all text bigger / smaller
SIT.FONT_WIDTH    = 1.0     -- letter width (lower = narrower)
SIT.FONT_CELL_W   = 68      -- texture: glyph cell width (px of 128)
SIT.FONT_CAP      = 77 / 128  -- texture: capital height / cell height

-- controller gain: DCS moves elements by controllers (moving symbols,
-- route / threat lines) in METRES on the screen, while the drawn shapes use
-- page units (-1..1). So the gain = metres per page unit = the screen's
-- half-size: 0.0606 m glass + 0.014 m margin (Blender script SCREEN_MARGIN).
-- Measured in v0.3.4 (1/30 put the N/E/S/W letters at 47 % of their place).
SIT.G             = 0.0889  -- Su-27 MFD: the anchors MFD_C / B / R are 88.9 mm apart
SIT.PORT          = 42894   -- UDP from Scripts\S27MFD_Export.lua (and the hook)
SIT.STALE_S       = 8       -- datalink picture older than this = NO DL
SIT.UPDATE        = 0.05    -- device update step (s)

-- contact codes (from the export, same as the MiG-29 add-on):
--   1 friendly  2 hostile  3 unknown  4 AWACS  5 own flight  6 datalink fighter
--   +10 = the own radar holds it (solid symbol); 13 = own radar only

-- MFD pages (SIT = the SA page)
SIT.PG = {SIT = 1, MENU = 2, DTM = 3, BIT = 7, TIME = 8, OWN = 9, FLT = 10, SETS = 13,
          PIC = 15, RDR = 16, NAV = 17, HSI = 18, COM = 19, FUEL = 20, SMS = 21, RWR = 22}

-- DCS Su-27 weapon stations 1..10 (LoGetPayloadInfo order): 1 / 10 wing
-- tips ... 5 / 6 the centre line
SIT.STATIONS = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}

-- BIT page rows: name, failure flags (LoGetMCPState) that make it NO GO
SIT.BIT_ROWS = {
	{"MFD"},
	{"RADAR", "RadarFailure"},
	{"SPO-15", "RWSFailure"},
	{"ECM", "ECMFailure"},
	{"HUD", "HUDFailure"},
	{"HDD", "MFDFailure"},
	{"GUN", "CannonFailure"},
	{"L ENGINE", "LeftEngineFailure"},
	{"R ENGINE", "RightEngineFailure"},
	{"HYDRAULICS", "HydraulicsFailure"},
	{"CAS", "ACSFailure"},
	{"AUTOPILOT", "AutopilotFailure"},
	{"FUEL", "FuelTankDamage", "LeftMainPumpFailure", "RightMainPumpFailure", "LeftWingPumpFailure", "RightWingPumpFailure"},
	{"GEAR", "GearFailure", "StuckGear"},
}

-- Zulu time: map (mission theatre) -> hours ahead of UTC of its mission time
SIT.UTC_OFFSET = {
	Caucasus = 4, PersianGulf = 4, Syria = 3, Nevada = -8, MarianaIslands = 10, MarianasWWII = 10,
	Normandy = 1, TheChannel = 1, Falklands = -3, SinaiMap = 2, Kola = 3, Afghanistan = 4.5,
	Iraq = 3, GermanyCW = 1,
}
SIT.ZULU_DEFAULT  = true    -- SIT / MENU time in Zulu (where the map's offset is known)


-- drawings on SIT (cartridge .geo.txt / mission drawings, MENU: LINES)
SIT.GEO_SEGS      = 160     -- line pieces
SIT.GEO_LABELS    = 12      -- names
SIT.EXP_NM        = 10      -- EXP: range around the cursor
SIT.HOOK_R        = 0.07    -- a contact this close to the cursor (page units) is hooked

-- a friendly / unknown contact this close (m) to a flight member is that
-- member (radar track and datalink report of one aircraft drawn once)
SIT.FLT_MATCH_M   = 150

-- SIT cursor (castle up): speed of the TDC slew / SIT cursor binds
SIT.SLEW_SCALE    = 1.0     -- SIT cursor speed: 1 = as fast across the SIT display as the radar cursor across the radar display; 2 = twice that
SIT.SLEW_DEADZONE = 0.08
SIT.SLEW_INVERT_Y = false   -- true if up/down on the slew comes out reversed
-- while SIT has the cursor: the radar's TDC slew is held at ~0 by the export
-- (the radar cursor stays where it is)
SIT.SQUELCH_RADAR = true

-- declutter steps (keybind "SIT Declutter" / SIT SETTINGS right 2)
SIT.DCL_NAMES = {"FULL", "NO LINES", "NO DATA", "NO RINGS", "MIN"}

-- EWR picture reports (server text messages) drawn when there is no datalink
-- picture (export blocked or off): on/off, kept for, moved along for (s)
SIT.EWR_ON        = true
SIT.EWR_KEEP_S    = 180
SIT.EWR_EXTRAP_S  = 120

-- (radios: the УКВ / КВ panel and the loader plate of Su-27 Radio (WW); the
-- COM page shows them and steps them through that device)
SIT.SRS_PORT = 9040

-- own missiles in flight shown at once (export: S27MFDW), mark points kept
-- power: the MFD comes on with the jet's power and its ВКЛ button, after a
-- self test of BOOT_S seconds. ЯРК + / - steps the brightness, ДЕНЬ / НОЧЬ
-- the day / night level.
--   POWER_CMD   FC3's electric power switch command (Logs\s27mfd_icmd.lua has
--               the number when the controls block knows it; else this)
--   RPM_ON      engine RPM (%) that counts as power without the switch
--   BRT_STEPS   brightness steps of the rocker; NIGHT = NIGHT_K of DAY
SIT.BOOT_S    = 4.0
SIT.POWER_CMD = 315
SIT.RPM_ON    = 50
SIT.BRT_STEPS = 10
SIT.NIGHT_K   = 0.35
SIT.MAX_MSL   = 4
-- own missile in flight: a circle on the flashing fly-out line, an X once an
-- active missile (R-77) is this close to its target (range units)
SIT.MSL_MPRF_NM = SIT.METRIC and 13 or 7
SIT.MSL_FLASH_S = 0.5     -- fly-out line: on this long, then off as long
SIT.MAX_MARKS = 8


-----------------------------------------------------------------------
-- the unit itself (model arguments, controls)
-----------------------------------------------------------------------
MFD = MFD or {}
MFD.ARG_OSB0  = 810        -- + 1..20: soft key arguments (L1-L5, B1-B5, R1-R5, T1-T5)
MFD.ARG_PWR   = 831
MFD.ARG_STOW  = 840        -- 0 = in place, 1 = folded away (ED's HDD shows)
MFD.PWR_HOLD  = 2.0        -- s: hold ВКЛ this long to switch off
MFD.STOW_SPEED = 2.5       -- argument per second while folding (0.4 s)
MFD.START_ON  = true       -- the MFD's own switch (ВКЛ) starts on: it comes up with the jet's power
-- v0.1 test: frame along the screen edges, corner marker, a box next to every
-- soft key (lit while pressed) and a row for the keypad keys. Options >
-- Special > Su-27 Radio > "MFD alignment test" switches it on.
MFD.ALIGN_TEST = false
MFD.OSB_NAMES = {"L1", "L2", "L3", "L4", "L5", "B1", "B2", "B3", "B4", "B5",
                 "R1", "R2", "R3", "R4", "R5", "T1", "T2", "T3", "T4", "T5"}
MFD.KP_NAMES = {"C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "ENT", "RST", "F1", "F2", "F3", "F4", "GR"}
-- soft key legends (page units): sides top to bottom, top / bottom rows left to right
MFD.Y5 = {0.54, 0.27, 0, -0.27, -0.54}
MFD.X5 = {-0.684, -0.342, 0, 0.342, 0.684}

-----------------------------------------------------------------------
-- v1.3 MFI: the page layout of the MiG-29 MFD's MFI edition (light screen,
-- cyan frame, ATK / TAC / NAV / COM / SYS groups on the top keys, the
-- group's pages on the bottom keys; MFD/mfd_mfi.lua). false = the classic
-- dark MFD of v1.2.
-----------------------------------------------------------------------
SIT.MFI = true
if SIT.MFI then
	-- the MFI font (DejaVu Sans Mono on a coarse raster, as the MiG-29 MFI
	-- edition): glyph in the left 63 px of each 128 px cell, capitals 65 px
	SIT.FONT_FILE   = "s27mfd_font_mfi.dds"
	SIT.FONT_FILE_B = "s27mfd_font_mfi_b.dds"   -- (test 3: the thick copy, MiG-29 MFI mig29_dl_font_b.dds)
	SIT.FONT_CELL_W = 63
	SIT.FONT_CAP    = 65 / 128
	SIT.FONT_WIDTH  = 0.91      -- same letter advance as the classic font (text rows keep their length)
	dofile(LockOn_Options.script_path .. "MFD/mfd_mfi.lua")
end
