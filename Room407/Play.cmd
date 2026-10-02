@echo off
set "GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" (
 start "ROOM 407" "%GODOT%" --path "%~dp0.." res://Room407/main.tscn
) else (
 echo Please open ..\project.godot in Godot 4 to play ROOM 407.
 pause
)
