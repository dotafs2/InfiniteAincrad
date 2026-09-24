@echo off
setlocal
if exist "%~dp0build\windows\SinkCity.exe" (
    start "" "%~dp0build\windows\SinkCity.exe"
    exit /b
)
if defined GODOT_BIN (
    start "" "%GODOT_BIN%" --path "%~dp0."
    exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "" godot --path "%~dp0."
    exit /b
)
echo Open project.godot in Godot 4, or set GODOT_BIN to your Godot executable.
pause
