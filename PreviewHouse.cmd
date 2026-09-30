@echo off
setlocal
set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    echo Open project.godot in Godot to play ExitRoom.
    pause
    exit /b 1
)
start "ExitRoom - House preview" "%GODOT_EXE%" --path "%~dp0." res://prologue_village.tscn -- --preview-house
