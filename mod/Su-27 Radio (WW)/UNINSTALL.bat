@echo off
setlocal
title Su-27 Radio (WW) - uninstall
set "MOD=%~dp0"
for %%I in ("%MOD%..\..\..") do set "SG=%%~fI"
echo.
echo  Su-27 Radio (WW): takes the hook out of %SG%\Scripts\Hooks.
echo  Your cartridges in DTC\Su-27 stay. Close DCS before continuing.
echo.
pause
if exist "%SG%\Scripts\Hooks\su27radio_hook.lua" del /q "%SG%\Scripts\Hooks\su27radio_hook.lua"
echo.
echo  Done. Now delete this folder:  %MOD%
echo.
pause
