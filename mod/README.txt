Su-27 Radio (WW) 1.3 MFI - install package
==========================================

1. Close DCS.
2. Unzip this whole folder anywhere (Desktop, Downloads, ...).
3. Double-click INSTALL.bat.

The installer finds your Saved Games\DCS folder itself (also DCS.openbeta)
and copies the mod to Saved Games\DCS\Mods\tech\Su-27 Radio (WW). You do not
have to put anything into Mods\tech by hand. Then it does what the mod's own
INSTALL.bat did: hooks, MFD export, Export.lua line, example cartridge and the
radio / MFD controls (Options - Controls - Su-27 / J-11A / Su-33).

Updating: run INSTALL.bat of the new package. It copies the new files over the
installed mod. Your DTC Planner pages, the controls backup and the remembered
DCS folder stay.

After a DCS update or repair the radio controls disappear: run INSTALL.bat again.

UNINSTALL.bat takes everything out again and deletes the mod folder in
Mods\tech. Your cartridges in Saved Games\DCS\DTC\Su-27 stay.

Options (from a command prompt in this folder):
  INSTALL.bat -SavedGames "D:\Saved Games\DCS"   your DCS folder, if it is not found
  INSTALL.bat -DcsPath "D:\DCS World"             your DCS install, for the controls

Works in the Su-27, the J-11A and the Su-33 (Flaming Cliffs). The Su-27 and
J-11A use ED's keypad and radio panel; in the Su-33 the keypad, radio knobs
and loader sit on a control unit on top of the MFD.

The DTC Planner pages come with the package (DTC Planner folder in the mod).

The mod's notes: files\Su-27 Radio (WW)\README.txt
