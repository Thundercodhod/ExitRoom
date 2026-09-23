@echo off
setlocal
set "GODOT_EXE="
if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE for %%G in (godot.exe godot4.exe) do (
    where %%G >nul 2>&1
    if not errorlevel 1 if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
    echo Godot was not found. Open project.godot in Godot instead.
    pause
    exit /b 1
)
start "ExitRoom" "%GODOT_EXE%" --path "%~dp0."
