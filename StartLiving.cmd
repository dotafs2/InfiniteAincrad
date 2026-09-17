@echo off
setlocal
pushd "%~dp0"

if not defined DOTNET_ROOT if exist "C:\Program Files\dotnet\dotnet.exe" set "DOTNET_ROOT=C:\Program Files\dotnet"
if defined DOTNET_ROOT set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "DOTNET_ROLL_FORWARD=LatestMajor"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StartLiving.ps1" %*
set "living_exit=%ERRORLEVEL%"
popd
exit /b %living_exit%
