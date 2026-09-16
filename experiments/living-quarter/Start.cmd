@echo off
cd /d "%~dp0\..\.."
python -X utf8 tools\play_living_quarter.py
if errorlevel 1 pause
