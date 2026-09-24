@echo off
setlocal
set "OLLAMA_EXE=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
if not exist "%OLLAMA_EXE%" set "OLLAMA_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Ollama.Ollama.Portable_Microsoft.Winget.Source_8wekyb3d8bbwe\ollama.exe"
if not exist "%OLLAMA_EXE%" (
  echo Ollama not found. Install Ollama first.
  exit /b 1
)
"%OLLAMA_EXE%" pull qwen3:8b
