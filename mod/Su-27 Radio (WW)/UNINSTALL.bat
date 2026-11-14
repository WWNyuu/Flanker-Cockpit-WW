@echo off
setlocal
title Su-27 Radio (WW) - uninstall
set "MOD=%~dp0"
for %%I in ("%MOD%..\..\..") do set "SG=%%~fI"
echo.
echo  Su-27 Radio (WW): takes the hook out of %SG%\Scripts\Hooks
echo  and the radio controls out of the Su-27 / J-11A controls.
echo  Your cartridges in DTC\Su-27 stay. Close DCS before continuing.
echo.
pause
if exist "%SG%\Scripts\Hooks\su27radio_hook.lua" del /q "%SG%\Scripts\Hooks\su27radio_hook.lua"
echo.
if exist "%MOD%installer\su27radio_binds.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD%installer\su27radio_binds.ps1" -Uninstall %*
echo.
echo  Done. Now delete this folder:  %MOD%
echo.
pause
