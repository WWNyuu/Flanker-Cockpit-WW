Su-27 Radio (WW) 1.3 MFI - radio cartridges, radio panel, channel card and MFD for the Flaming Cliffs Su-27 / J-11A / Su-33
================================================================================================================

Makes the Su-27's radios work from the cockpit, 80s Soviet style:
- a "ВВОД ДАННЫХ" (data input) plate on the right console wall loads radio
  channel cartridges: the mission's presets or one of six cartridge files
- the УКВ / КВ radio panel on the left console works: КАНАЛ knobs pick the
  channel (1-20), ГРОМК knobs set the volume, all tuned in SRS
- the channel card (КАНАЛЫ РАДИОСВЯЗИ) on the right canopy rail is filled in
  by hand, in blue ballpoint, from the loaded channels
- v1.2: a retrofit colour MFD over the HDD (right of the front panel):
  SA, PICTURE, NAV, HSI, COM, FUEL, STORES, RWR, FLIGHT and DTC pages,
  worked with its 20 soft keys and ED's ЦЕЛИ keypad
- the WW DTC Planner (MiG-29A / F-15C / Su-27) writes the cartridges:
  radio channels, and the route, bullseye, bingo and lines for the MFD

Works in the Su-27, the J-11A and the Su-33. Needs SRS (DCS-SimpleRadio Standalone) for
the radios; without it everything works in the cockpit, but nothing is tuned.

Install
-------
1. This folder goes to  Saved Games\DCS\Mods\tech\Su-27 Radio (WW)\
2. Run INSTALL.bat (in this folder). It copies
   - Scripts\Hooks\su27radio_hook.lua to Saved Games\DCS\Scripts\Hooks
     (it hands the mission's radio presets to the cockpit: МИС)
   - v1.2, for the MFD: Scripts\S27MFD_Export.lua to Saved Games\DCS\
     Scripts and Scripts\Hooks\S27MFD_hook.lua to ...\Scripts\Hooks, and
     adds one line to Saved Games\DCS\Scripts\Export.lua that loads the
     export (the MFD's radar, datalink and RWR picture; it only runs in
     the Su-27 / J-11A)
   - the example cartridge to Saved Games\DCS\DTC\Su-27 (only if it is not
     there yet)
   and adds the radio controls (see "Controls" below) to the Su-27's
   controls files in the DCS install folder (Mods\aircraft\Su-27\Input\
   su-27\joystick and \keyboard\default.lua: one marked block, ED's lines
   stay as they are; ED's file is kept in backup\). The J-11A uses the
   Su-27's files, so it gets them too.
3. Options > Special > Su-27 Radio: the add-on on/off, a debug log (also
   the MFD's timing log), and for the MFD: datalink picture, RWR page,
   alignment test.
A DCS update or repair puts ED's controls files back and the radio controls
disappear from Options > Controls: run INSTALL.bat again. Your key
assignments are kept by DCS and come back with them.
INSTALL.bat finds the DCS install folder by itself (registry, the usual
places). If it does not: from a command prompt in this folder,
    INSTALL.bat -DcsPath "D:\DCS World"
If Windows does not allow the change (DCS in Program Files): right-click
INSTALL.bat > Run as administrator.

Uninstall
---------
UNINSTALL.bat takes the hooks, the MFD export (and its Export.lua line)
and the controls out again. Then delete
this folder. Your
cartridges in Saved Games\DCS\DTC\Su-27 are left alone.

The plate (right console wall)
------------------------------
- КАССЕТА knob: МИС = the mission's presets, 1-6 = cartridges.
  Left click = anticlockwise (toward МИС), right click = clockwise.
- ЗАГР button: load the selected cartridge. The window flashes "--" for
  a moment, then:
    ГОТОВ (green)  loaded; the В РАБОТЕ window shows П1..П6 (П0 = mission)
    ОТКАЗ (red)    no file for that number, or a bad file; the cartridge
                   loaded before stays in
- After a load both radios go to the channels set on their КАНАЛ knobs.
- Power: dark without electric power; a short lamp test (88, both lamps)
  when power comes on.

The radio panel (left console)
------------------------------
- УКВ КАНАЛ (R-800, SRS radio 1) and КВ КАНАЛ (R-864, SRS radio 2):
  channels 1-20; left click = channel down, right click = channel up; the
  knobs go round and round (20 -> 1). Each step tunes SRS to that channel
  of the loaded presets (cartridge, or МИС = the mission's).
- The window above each knob shows the channel number. A channel with no
  frequency: the window shows it, SRS stays where it was.
- ГРОМК, the small knob beside each КАНАЛ knob: the radio's volume in SRS.
  Left click = quieter, right click = louder, 20 steps; from 7:30 (silent)
  to 4:30 (full). Both start at 80 %. The knob wins over SRS's own volume
  slider for these two radios (it is sent again every 5 s).
- SRS: UDP command port 9040 (SRS client setting, the default).

Su-33 control unit (v1.3)
-------------------------
In the Su-33 nothing sits on ED's panels any more. The MFD has its own
control unit on its top edge, leaning back toward the pilot, with:
- a keypad: 1-9, 0, СБР (clear), ВВОД (enter) - as ED's ЦЕЛИ keypad in the
  Su-27,
- the УКВ / КВ radio: КАНАЛ knob, channel window and ГРОМК knob each,
- the loader plate (КАССЕТА, ЗАГР, ГОТОВ / ОТКАЗ), at half size.
It is part of the MFD: it moves with the MFD's line in Su33_fine_tune.lua
and folds away with it. Blender: Tools\su27_ldr_plate.py with
AIRCRAFT = "Su-33" builds it; it needs Textures\su33_pod.png (in the mod,
made with Tools\pod_texture.py), so install the mod before you export.

Su-33: other notes
------------------
- The Options > Special > Su-27 Radio switch covers the Su-33 too, and
  INSTALL.bat adds the controls to the Su-33 (category "Su-27 Radio (WW)").
- Cartridges: the same Su-27 cartridges (DTC\Su-27).
- The Su-33 model is Shapes\SU33_LDR.edm; without it the Su-33 gets the
  Su-27's model.
- For modders: Su33_fine_tune.lua moves the MFD with its control unit live
  in DCS (MFD line, metres forward / up / right, -0.30 .. 0.30; the log
  Saved Games\DCS\Logs\su27radio_fit.log prints the numbers). To keep
  them, put them into SU33_SHIFT in Tools\su27_ldr_plate.py and export
  SU33_LDR.edm again in Blender 4.2 with ED's EDM exporter
  (AIRCRAFT = "Su-33").

The MFD in the MFI look (v1.3)
------------------------------
Brightness as the MiG-29 MFI: even steps from BRT 1 = 4 % to BRT 10 = 56 %
light, start at BRT 5 (about 27 %); ДЕНЬ and НОЧЬ keep their own level. The
level shows for a moment after a change.
The SA page is drawn as the MiG-29 MFI's and starts decentred: the jet sits
low under a big green arc = the range, with heading numbers outside it and
the heading box on its top (DCTR / CNTR on B5; centred, a green ring = the
range, grey rings at 1/4 to 3/4). Steerpoints are grey-green discs with
their number (the active one red), airfields blue discs with a white runway
line, the ownship black. Hostiles are a red diamond turning with their
course, labels above the contacts in a thick font (A altitude, R range,
M Mach). An orange arrow on the arc points to the active steerpoint.

v1.3 lays the MFD out like the MFI edition of the Vitezovi MiG-29 MFD
(after the real MFI-55): a light screen in a cyan frame, the MFI
edition's pages and keys, laid out for this square screen.
- Top keys T1-T5: the page groups  ATK  TAC  NAV  COM  SYS
- Bottom keys B1-B5: the pages of the group shown (the one up is lit)
    ATK  LOFT, SMS
    TAC  SA, PIC, FLT, RWR  (on SA, B5 = DCTR / CNTR)
    NAV  RTE, PFD, LND, PNT, BCN
    COM  UKV (R-800), KV (R-864)
    SYS  FUEL, DTC
  A group's key takes you back to the page you last had in it; pressed
  again, to its first page.
- Side keys: the page's own functions, names written downwards on the
  frame (black while the function is on):
    SA    L: FPL NEXT INTC MARK DEL     R: EXP RNG+ RNG- SET GEO
    SET   SA settings (DL RTE THR LINE / CRS DCLT AUTO RDR NUP-HUP)
    PIC   L: RNG+ RNG- AUTO INTC CALL   R: G1-G5 (pick a group)
    FLT   L: ADD DEL - PREV NEXT        R1-R4 the slots, R5 AUTO
    LOFT  L: W+ W- WPN                  R: ANG+ ANG- DEF
    RTE   L: PREV NEXT AUTO/MAN DIR RST R: LOAD TOT PT CLR ADD
    PFD   L: FD SPD AMAX AMIN RALT      R1 VSI
    LND   L: HDG CRS - STP SYNC
    PNT   L: UP DN POS ADD DEL          R1-R4 pick a point, R5 STP
    BCN   L: PREV NEXT (the nearest airfields)
    UKV/KV L: CH+ CH- VOL+ VOL- MAN     R: FC+ FC- (fighter channel)
    FUEL  L: BNGO HOME
    DTC   L: READ RFSH - PREV NEXT      R1-R5 read that cartridge
  Entries (BNGO, AMAX / AMIN, HDG / CRS, TOT, POS, MAN, fighter channel
  on the COM pages): the keypad, then ВВОД; СБРОС clears.
- BINGO and ALT MAX / MIN show a red flashing warning on every page.
- The datalink contacts need the export installed: run INSTALL.bat.
Back to the dark v1.2 MFD: in Cockpit\Scripts\MFD\mfd_config.lua set
SIT.MFI = false.

The MFD (v1.2)
--------------
A colour MFD retrofitted over the HDD, right of the front panel: 20 soft
keys round the screen (L1-L5 left, R1-R5 right, B1-B5 bottom, T1-T5 top),
ВКЛ (power: press = on, hold 2 s = off), ЯРК + / - (brightness), ДЕНЬ /
НОЧЬ (day / night). It runs on the jet's electric power and boots in a few
seconds. The bottom row is the same on most pages: SA, RDR, MENU, NAV, RWR.
MENU lists all pages (SA, RDR, NAV, HSI, COM / FUEL, SMS, FLT, RWR, DTC /
BIT, TIME, OWN, PIC).
- SA        the picture: own radar and datalink contacts, flight, threat
            rings, route and bullseye; RNG +/-, centred / decentred,
            north / heading up, steerpoint +/-, declutter, SA settings
- PICTURE   threat groups with bearing, range and altitude (from the
            bullseye or BRAA)
- NAV       steer to the steerpoint, cross-track, ETA, the route list with
            TOT; ADD (R2) a waypoint: latitude DDMMm ВВОД, longitude DDDMMm
            ВВОД (ADD again: bearing / range from the jet), DEL (R3) the
            selected one, RTE RST (R4) the route as loaded
- HSI       compass rose, course and deviation, bearing pointer, heading bug
- COM       both radios: channel and volume (the panel's knobs turn with
            them), the channel lists; UKV MAN / KV MAN: type a frequency,
            ВВОД, and the channel in use gets it (radios, card, page) until
            the next ЗАГР
- FUEL      fuel, bingo line (BNG +/-), time and range to bingo
- STORES    the jet from behind with what is on each of the 10 stations;
            the selected one amber, gun, chaff, flares
- RWR       the SPO-15's emitters round a ring, locks and launches
- FLIGHT    your flight's four slots, from the datalink list
- DTC       the cartridges for this map: CART +/-, READ (route, bullseye,
            bingo, lines). MSN = the mission's
- BIT, TIME, OWN DATA, SA SETTINGS
The ЦЕЛИ keypad (right console): digits + ВВОД enter a steerpoint, bingo,
cartridge, fighter channel or a waypoint / frequency on NAV / COM;
СБРОС clears; ИСТРЕБИТЕЛИ 1-4 = SA / RDR / NAV / RWR, ГР = MENU.
The MFD switches on only when Shapes\SU27_LDR_MFD.txt is there (the model
with the MFD in it). Options > Special: "MFD alignment test" draws a frame
and a box per key, to check the screen and the keys.

Controls (v1.1, MFD v1.2)
-------------------------
Options > Controls > Su-27 (or J-11A), category "Su-27 Radio (WW)":
    UKV radio (R-800, SRS 1) - Channel Up / Channel Down
    KV radio (R-864, SRS 2)  - Channel Up / Channel Down
    UKV radio (R-800, SRS 1) - Volume Up / Volume Down
    KV radio (R-864, SRS 2)  - Volume Up / Volume Down
v1.2, category "Su-27 MFD (WW)": every MFD soft key (left / bottom /
right / top 1-5), power, brightness up / down, day, night, and "fold away
/ back" (puts the MFD away to show the original HDD).
Nothing is bound to start with: bind them to keys or HOTAS buttons. One
press = one step; the knob in the cockpit turns with it and SRS follows,
just as with a click. (The plate on the right has no controls: it is
used on the ground.)

The channel card (right canopy rail)
------------------------------------
- The loaded channels, written by hand: УКВ first (01, 02 ...), then КВ
  marked "К" (К 1, К 2 ...). 20 rows; only channels with a frequency are
  written down, with their numbers, like a real card.
- Columns: channel, frequency (MHz), station, callsign. With МИС they come
  from the mission (the group's own frequency is "своя группа").
- Top right: what is loaded ("кассета 1 - <name>", "МИС - задание").

Cartridges and the DTC Planner
------------------------------
Saved Games\DCS\DTC\Su-27\<number> <name>.dtc   e.g. "1 Example comm plan.dtc"
The first digit is the КАССЕТА position that loads it.

DTC Planner\WW DTC Planner.html (also online, see the website): one HTML
file, runs offline in any browser, with the DCS maps built in. Pick Su-27 /
J-11A at the top. Write the channels (UKV and KV, with station and
callsign for the card), click an airfield for its DCS tower frequencies
(VHF / UHF to UKV, HF to KV), or import a Su-27 flight's presets, route
and drawings from a .miz. ROUTE: steerpoints (altitude m, time on target),
bullseye and bingo for the MFD; LINES: threat rings, front lines, borders
and areas (saved next to the cartridge as <number> <name>.geo.txt). The
CARD tab shows the card as the cockpit will write it. The same planner
makes MiG-29A(WW) and F-15C SIT (WW) cartridges.

Format (for writing one by hand):
  { "type": "Su-27 DTC", "version": 1, "name": "...", "terrain": "Caucasus",
    "ukv": [ {"ch": 1, "f": 251.000, "station": "...", "call": "..."}, ... ],
    "kv":  [ {"ch": 1, "f": 3.500,   "station": "...", "call": "..."}, ... ],
    "route": [ {"lat": 42.1, "lon": 41.6, "name": "IP", "alt": 8000, "tot": 45000}, ... ],
    "bullseye": {"lat": 42.0, "lon": 42.3}, "fuel": {"bingo": 1500} }
  ukv: R-800, 100-399.975 MHz; kv: R-864, 3-10 MHz; ch 1-20. route, bullseye
  and fuel are for the MFD (alt in metres, tot in seconds after midnight);
  every block is optional.

Problems
--------
Saved Games\DCS\Logs\su27radio.log (turn on the debug log in Options for
more), and su27radio_hook.log for the mission presets. The MFD:
s27mfd_device.log, s27mfd_export.log, s27mfd_hook.log (and with the debug
log on, s27mfd_perf.log: the MFD's timing).

Credits
-------
DCS World and the Su-27 / J-11A cockpit: Eagle Dynamics (the cockpit model
is used for positions only; airfield frequencies in the planner come from
DCS's own map data). Planner maps: Natural Earth, NOAA DEM.
Bad Script font: Copyright 2011 The Bad Script Project Authors, SIL Open
Font License 1.1 (Fonts\BadScript-OFL.txt).
A fan-made add-on, not affiliated with Eagle Dynamics.
