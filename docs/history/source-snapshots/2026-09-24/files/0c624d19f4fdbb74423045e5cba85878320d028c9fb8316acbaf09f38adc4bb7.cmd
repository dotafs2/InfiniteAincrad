@echo off
setlocal
title InfiniteAincrad - Latest saved world (read only)
set "DOTNET_ROOT=C:\Program Files\dotnet"
set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "DOTNET_ROLL_FORWARD=LatestMajor"
"D:\lucidgloves\InfiniteAincrad\tmp\toolchain\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe" --path "D:\lucidgloves\InfiniteAincrad\tmp\overnight-20260918\delivery\game" res://scenes/town_street.tscn -- --town-save=D:/lucidgloves/InfiniteAincrad/tmp/overnight-20260918/delivery/private/worlds/restart-20260918-01/world.json --town-restore
if errorlevel 1 pause
endlocal
