@echo off
setlocal
title Su-27 Radio (WW) - uninstall
if exist "%~dp0installer\s27_install.ps1" goto have_files
echo.
echo  Unzip the whole folder first, then run UNINSTALL.bat from there.
echo.
pause
exit /b 1
:have_files
echo.
echo  Su-27 Radio (WW): removes the mod from Saved Games\DCS\Mods\tech, the hooks,
echo  the MFD scripts, the Export.lua line and the radio controls.
echo  Your cartridges in DTC\Su-27 stay. Close DCS before continuing.
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\s27_install.ps1" -Uninstall %*
echo.
pause
