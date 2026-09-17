@echo off
setlocal
pushd "%~dp0"

if not defined DOTNET_ROOT if exist "C:\Program Files\dotnet\dotnet.exe" set "DOTNET_ROOT=C:\Program Files\dotnet"
if defined DOTNET_ROOT set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "DOTNET_ROLL_FORWARD=LatestMajor"

python -X utf8 "%~dp0tools\start_user_living_session.py" %*
set "living_ai_exit=%ERRORLEVEL%"
if not "%living_ai_exit%"=="0" (
  echo.
  echo StartLivingAI failed. Read the message above, then press any key to close.
  pause >nul
)
popd
exit /b %living_ai_exit%
