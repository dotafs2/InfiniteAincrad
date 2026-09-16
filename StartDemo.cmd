@echo off
pushd "%~dp0"
python tools\play_pcg_trial.py --demo %*
set "demo_exit=%ERRORLEVEL%"
popd
exit /b %demo_exit%
