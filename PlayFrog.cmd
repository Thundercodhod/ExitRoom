@echo off
setlocal
set "GODOT_EXE="
if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT_EXE for %%G in (godot.exe godot4.exe) do (
    where %%G >nul 2>&1
    if not errorlevel 1 if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
    echo Open frog_chapter.tscn in Godot and press F6.
    pause
    exit /b 1
)
start "ExitRoom - Frog Chapter" "%GODOT_EXE%" --path "%~dp0." res://frog_chapter.tscn
