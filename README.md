# Su-27 Radio (WW) 1.3 MFI

Working radios, radio cartridges and a retrofit MFD for the Flaming Cliffs **Su-27, J-11A and Su-33** in DCS World, 80s Soviet style: a ВВОД ДАННЫХ plate that loads radio channel cartridges, the УКВ / КВ radio panel with working КАНАЛ (channel) and ГРОМК (volume) knobs tuned in SRS, a handwritten channel card on the canopy rail, and a colour MFD in the MFI-55 look.

**Website and pilot manual:** the GitHub Pages site of this repository (`index.html`, `manual.html`). The WW DTC Planner (MiG-29A, F-15C and Su-27 / J-11A / Su-33) runs online at `planner/`.

## Requirements

- DCS World with the Su-27, J-11A or Su-33 (Flaming Cliffs)
- SRS (DCS-SimpleRadio Standalone) for the radios. Without SRS everything works in the cockpit, but nothing is tuned.

## Install

1. Close DCS.
2. Download `downloads/Su-27_Radio_WW_1.3_MFI.zip` and unzip it anywhere.
3. Double-click `INSTALL.bat`. It finds your Saved Games folder (also `DCS.openbeta`), copies the mod into `Mods\tech`, sets up the hooks, the MFD export and the example cartridge, and adds the controls for the Su-27, J-11A and Su-33.

After a DCS update or repair the radio controls disappear from Options > Controls: run `INSTALL.bat` again, your key assignments come back. To update, run `INSTALL.bat` of the new package. `UNINSTALL.bat` takes everything out again; your cartridges stay.

## What's new in 1.3

**MFD in the MFI look.** The MFD looks and works like the MFI edition of the Vitezovi MiG-29 MFD, after the real MFI-55: a light screen in a cyan frame, dark symbols.

| Group | Pages (bottom row) |
|---|---|
| **ATK** | LOFT, SMS |
| **TAC** | SA, PIC, FLT, RWR |
| **NAV** | RTE, PFD, LND, PNT, BCN |
| **COM** | UKV (R-800), KV (R-864) |
| **SYS** | FUEL, DTC |

- SA starts decentred, with numbered steerpoints, airfields with their runway and hostiles as red diamonds turning with their course.
- New pages: PFD (flight director, ALT MAX / MIN, radar altitude), LND (HSI), PNT (route editor), BCN (nearest airfields) and LOFT.
- BINGO and ALT MAX / MIN flash red on every page. Brightness in 10 even steps, DAY and NIGHT each keep their own level.
- The dark v1.2 MFD is still there: `SIT.MFI = false` in `Cockpit\Scripts\MFD\mfd_config.lua`.

**Su-33 support.** The whole mod works in the Su-33: MFD, radios, cartridges, channel card and controls. A control unit on top of the MFD carries the keypad, the УКВ / КВ radio and the cartridge loader; nothing is laid over ED's Su-33 panels, and the unit folds away with the MFD.

**Desktop installer.** Unzip anywhere and run `INSTALL.bat`; no more copying into `Mods\tech` by hand. The DTC Planner pages come with the package.

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
- `mod/` - the same package unzipped: `INSTALL.bat`, `UNINSTALL.bat`, `installer/` and the add-on itself in `files/Su-27 Radio (WW)/` (cockpit device, indicators, hook, options, models, textures, Blender tools, planner)
- `planner/` - the WW DTC Planner for the browser
- `index.html`, `manual.html`, `img/` - the website

## Credits

DCS World and the Su-27 / J-11A / Su-33: Eagle Dynamics. Planner maps: Natural Earth, NOAA DEM. Handwriting: Bad Script font, Copyright 2011 The Bad Script Project Authors, SIL Open Font License 1.1. A fan-made add-on, not affiliated with Eagle Dynamics.
