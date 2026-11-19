@echo off
setlocal
title Su-27 Radio (WW) - install
rem started from inside the zip, Windows unpacks only this file: the
rem installer next to it is missing then
if exist "%~dp0installer\s27_install.ps1" goto have_files
echo.
echo  Unzip the whole folder first, then run INSTALL.bat from there.
echo  (Windows started INSTALL.bat from inside the zip - the rest of the mod is not next to it.)
echo.
pause
exit /b 1
:have_files
echo.
echo  Su-27 Radio (WW) 1.3 MFI - Flaming Cliffs Su-27 / J-11A / Su-33
echo.
echo  Installs the mod into Saved Games\DCS\Mods\tech (you do not have to put
echo  it there yourself), the hooks, the MFD export and the controls.
echo  Close DCS before continuing.
echo.
pause
rem options are passed on, e.g. INSTALL.bat -SavedGames "D:\Saved Games\DCS"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\s27_install.ps1" %*
echo.
pause
