@echo off
setlocal
pushd "%~dp0"

python -X utf8 "%~dp0tools\start_user_living_session.py" %*
set "living_ai_exit=%ERRORLEVEL%"
if not "%living_ai_exit%"=="0" (
  echo.
  echo StartLivingAI failed. Read the message above, then press any key to close.
  pause >nul
)
popd
exit /b %living_ai_exit%
