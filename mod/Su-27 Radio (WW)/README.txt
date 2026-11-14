Su-27 Radio (WW) 1.0 - radio cartridges, radio panel and channel card for the Flaming Cliffs Su-27 / J-11A
=========================================================================================================

Makes the Su-27's radios work from the cockpit, 80s Soviet style:
- a "ВВОД ДАННЫХ" (data input) plate on the right console wall loads radio
  channel cartridges: the mission's presets or one of six cartridge files
- the УКВ / КВ radio panel on the left console works: КАНАЛ knobs pick the
  channel (1-20), ГРОМК knobs set the volume, all tuned in SRS
- the channel card (КАНАЛЫ РАДИОСВЯЗИ) on the right canopy rail is filled in
  by hand, in blue ballpoint, from the loaded channels
- the WW DTC Planner (MiG-29A / F-15C / Su-27) writes the cartridges

Works in the Su-27 and the J-11A. Needs SRS (DCS-SimpleRadio Standalone) for
the radios; without it everything works in the cockpit, but nothing is tuned.

Install
-------
1. This folder goes to  Saved Games\DCS\Mods\tech\Su-27 Radio (WW)\
2. Run INSTALL.bat (in this folder). It copies
   - Scripts\Hooks\su27radio_hook.lua to Saved Games\DCS\Scripts\Hooks
     (it hands the mission's radio presets to the cockpit: МИС)
   - the example cartridge to Saved Games\DCS\DTC\Su-27 (only if it is not
     there yet)
3. Options > Special > Su-27 Radio: the add-on on/off, and a debug log.
Nothing in the DCS install folder is changed, so a DCS update does not undo it.

Uninstall
---------
UNINSTALL.bat takes the hook out again. Then delete this folder. Your
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
J-11A at the top. Write the channels (УКВ and КВ, with station and callsign
for the card), click an airfield for its DCS tower frequencies (VHF / UHF
to УКВ, HF to КВ), or import a Su-27 flight's presets from a .miz. The
КАРТОЧКА tab shows the card as the cockpit will write it. The same planner
makes MiG-29A(WW) and F-15C SIT (WW) cartridges.

Format (for writing one by hand):
  { "type": "Su-27 DTC", "version": 1, "name": "...", "terrain": "Caucasus",
    "ukv": [ {"ch": 1, "f": 251.000, "station": "...", "call": "..."}, ... ],
    "kv":  [ {"ch": 1, "f": 3.500,   "station": "...", "call": "..."}, ... ] }
  ukv: R-800, 100-399.975 MHz; kv: R-864, 3-10 MHz; ch 1-20.

Problems
--------
Saved Games\DCS\Logs\su27radio.log (turn on the debug log in Options for
more), and su27radio_hook.log for the mission presets.

Credits
-------
DCS World and the Su-27 / J-11A cockpit: Eagle Dynamics (the cockpit model
is used for positions only; airfield frequencies in the planner come from
DCS's own map data). Planner maps: Natural Earth, NOAA DEM.
Bad Script font: Copyright 2011 The Bad Script Project Authors, SIL Open
Font License 1.1 (Fonts\BadScript-OFL.txt).
A fan-made add-on, not affiliated with Eagle Dynamics.
