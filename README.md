# Su-27 Radio (WW)

Working radios for the Flaming Cliffs Su-27 and J-11A in DCS World, 80s Soviet style: a ВВОД ДАННЫХ plate that loads radio channel cartridges, the УКВ / КВ radio panel with working КАНАЛ (channel) and ГРОМК (volume) knobs tuned in SRS, and a handwritten channel card on the canopy rail. Since 1.2: a retrofit colour MFD over the HDD with SA, NAV, COM, STORES, RWR and more.

**Website and pilot manual:** the GitHub Pages site of this repository (`index.html`, `manual.html`). The WW DTC Planner (MiG-29A, F-15C and Su-27 / J-11A) runs online at `planner/`.

## Requirements

- DCS World with the Su-27 or J-11A (Flaming Cliffs)
- SRS (DCS-SimpleRadio Standalone) for the radios

## Install

1. Download `Su-27_Radio_WW_v1.2.zip` from the 1.2 release (also in `downloads/`) and unzip it so the folder sits at `Saved Games\DCS\Mods\tech\Su-27 Radio (WW)`.
2. Double-click `INSTALL.bat` in that folder. It copies the hooks (mission radio presets, MFD map data) and an example cartridge, adds the MFD's export to `Saved Games\DCS\Scripts\Export.lua`, and adds the controls (Options > Controls > Su-27 / J-11A, categories "Su-27 Radio (WW)" and "Su-27 MFD (WW)") to the Su-27's controls files in the DCS install. Run it again after a DCS update or repair.
3. Options > Special > Su-27 Radio: on / off, a debug log, and the MFD's datalink picture, RWR page and alignment test.

`UNINSTALL.bat` takes the hooks, the MFD export and the controls out again.

## What's new in 1.2

**The MFD.** A colour MFD retrofitted over the HDD, right of the front panel: modern against the worn 80s cockpit. 20 soft keys, ВКЛ power (press on, hold off), ЯРК brightness, ДЕНЬ / НОЧЬ, and ED's ЦЕЛИ keypad on the right console for typing. The 4477th TAES badge on MENU.

- **SA**: own radar and datalink contacts, your flight, threat rings, route and bullseye; range, centred / decentred, north / heading up, declutter.
- **PICTURE**: threat groups with bearing, range and altitude.
- **NAV**: steering, ETA and times on target; add your own waypoints (lat / long or bearing / range) and delete steerpoints.
- **HSI**, **FUEL** (bingo line, time and range to bingo), **RWR** (the SPO-15 on the MFD), **FLIGHT**, **BIT**, **TIME**, **OWN DATA**.
- **COM**: both radios from the MFD, the panel knobs turn with it; MAN sets a typed frequency on the channel in use.
- **STORES**: the jet from behind with what hangs on each of the ten stations.
- **DTC**: route, bullseye, bingo and lines from the same cartridges as the radios.
- Controls for every MFD key (category "Su-27 MFD (WW)"), including folding it away to show the original HDD.

**DTC Planner**: ROUTE tab (steerpoints with altitude and time on target, bullseye, bingo) and LINES tab, and the Su-27 part is now in English.

**Fixes**: a cartridge with only a route loads on the plate. Updated zip (16 Nov): fixes a crash to desktop when locking a target with the SA page up.

## Repository

- `downloads/` - the release zip
- `mod/Su-27 Radio (WW)/` - the same add-on as source (cockpit device, indicators, hook, options, model, textures, installer, planner)
- `planner/` - the WW DTC Planner for the browser
- `index.html`, `manual.html`, `img/` - the website

## Credits

DCS World and the Su-27 / J-11A: Eagle Dynamics. Planner maps: Natural Earth, NOAA DEM. Handwriting: Bad Script font, Copyright 2011 The Bad Script Project Authors, SIL Open Font License 1.1. A fan-made add-on, not affiliated with Eagle Dynamics.
