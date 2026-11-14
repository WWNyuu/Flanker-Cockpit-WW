# Su-27 Radio (WW)

Working radios for the Flaming Cliffs Su-27 and J-11A in DCS World, 80s Soviet style: a ВВОД ДАННЫХ plate that loads radio channel cartridges, the УКВ / КВ radio panel with working КАНАЛ (channel) and ГРОМК (volume) knobs tuned in SRS, and a handwritten channel card on the canopy rail.

**Website and pilot manual:** the GitHub Pages site of this repository (`index.html`, `manual.html`). The WW DTC Planner (MiG-29A, F-15C and Su-27 / J-11A) runs online at `planner/`.

## Requirements

- DCS World with the Su-27 or J-11A (Flaming Cliffs)
- SRS (DCS-SimpleRadio Standalone) for the radios

## Install

1. Download `Su-27_Radio_WW_v1.1.zip` from the 1.1 release (also in `downloads/`) and unzip it so the folder sits at `Saved Games\DCS\Mods\tech\Su-27 Radio (WW)`.
2. Double-click `INSTALL.bat` in that folder. It copies the hook for the mission's radio presets and an example cartridge, and adds the radio controls (Options > Controls > Su-27 / J-11A, category "Su-27 Radio (WW)": channel and volume up / down for both radios) to the Su-27's controls files in the DCS install. Run it again after a DCS update or repair.
3. Options > Special > Su-27 Radio: on / off and a debug log.

`UNINSTALL.bat` takes the hook and the controls out again.

## Repository

- `downloads/` - the release zip
- `mod/Su-27 Radio (WW)/` - the same add-on as source (cockpit device, indicators, hook, options, model, textures, installer, planner)
- `planner/` - the WW DTC Planner for the browser
- `index.html`, `manual.html`, `img/` - the website

## Credits

DCS World and the Su-27 / J-11A: Eagle Dynamics. Planner maps: Natural Earth, NOAA DEM. Handwriting: Bad Script font, Copyright 2011 The Bad Script Project Authors, SIL Open Font License 1.1. A fan-made add-on, not affiliated with Eagle Dynamics.
