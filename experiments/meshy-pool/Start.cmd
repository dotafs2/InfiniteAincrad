@echo off
cd /d "%~dp0\..\.."
if "%~1"=="" goto preview
python -X utf8 tools\meshy_pool.py %*
if errorlevel 1 pause
exit /b %errorlevel%
:preview
python -X utf8 tools\meshy_pool.py estimate
echo.
echo No models submitted. Commands: Start.cmd onboard / doctor / run / status
echo Guide: ART_STYLE.md - Meshy account pool
pause
