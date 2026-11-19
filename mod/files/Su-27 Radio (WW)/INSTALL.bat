@echo off
setlocal
title Su-27 Radio (WW) - install
set "MOD=%~dp0"
if exist "%MOD%Scripts\Hooks\su27radio_hook.lua" goto have_files
echo.
echo  Unzip the whole folder first, then run INSTALL.bat from there.
echo.
pause
exit /b 1
:have_files
for %%I in ("%MOD%.") do set "MODNAME=%%~nxI"
for %%I in ("%MOD%..") do set "P1=%%~nxI"
for %%I in ("%MOD%..\..") do set "P2=%%~nxI"
for %%I in ("%MOD%..\..\..") do set "SG=%%~fI"
if /i not "%P1%"=="tech" goto wrong_place
if /i not "%P2%"=="Mods" goto wrong_place
echo.
echo  Su-27 Radio (WW) 1.2 - Flaming Cliffs Su-27 / J-11A
echo.
echo  Saved Games folder: %SG%
echo.
if not exist "%SG%\Scripts\Hooks" mkdir "%SG%\Scripts\Hooks"
copy /y "%MOD%Scripts\Hooks\su27radio_hook.lua" "%SG%\Scripts\Hooks\su27radio_hook.lua" >nul
if errorlevel 1 goto copy_failed
echo  - hook copied to Scripts\Hooks (the mission's radio presets for MIS)
copy /y "%MOD%Scripts\Hooks\S27MFD_hook.lua" "%SG%\Scripts\Hooks\S27MFD_hook.lua" >nul
if errorlevel 1 goto copy_failed
copy /y "%MOD%Scripts\S27MFD_Export.lua" "%SG%\Scripts\S27MFD_Export.lua" >nul
if errorlevel 1 goto copy_failed
echo  - MFD scripts copied (Scripts\S27MFD_Export.lua, Scripts\Hooks\S27MFD_hook.lua)
if not exist "%SG%\DTC\Su-27" mkdir "%SG%\DTC\Su-27"
if exist "%SG%\DTC\Su-27\1 Example comm plan.dtc" goto example_there
copy /y "%MOD%Examples\1 Example comm plan.dtc" "%SG%\DTC\Su-27\1 Example comm plan.dtc" >nul
echo  - example cartridge copied to DTC\Su-27 (KASSETA 1)
goto done
:example_there
echo  - DTC\Su-27 already has the example cartridge: left as it is
:done
echo  - Export.lua line and controls (Options - Controls - Su-27 / J-11A, category "Su-27 Radio (WW)"):
powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD%installer\su27radio_binds.ps1" -SavedGames "%SG%" %*
echo.
echo  Done. Start DCS: Options - Special - Su-27 Radio has the on/off switch.
echo  Cartridges: DTC Planner\WW DTC Planner.html, save them into
echo  %SG%\DTC\Su-27
echo  After a DCS update or repair the radio controls disappear: run INSTALL.bat again.
echo.
pause
exit /b 0
:wrong_place
echo.
echo  This folder is in the wrong place:
echo    %MOD%
echo  It must be  Saved Games\DCS\Mods\tech\%MODNAME%
echo  Move it there, then run INSTALL.bat again.
echo.
pause
exit /b 1
:copy_failed
echo.
echo  Could not copy the hook into %SG%\Scripts\Hooks.
echo  Close DCS and try again.
echo.
pause
exit /b 1
