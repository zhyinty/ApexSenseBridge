@echo off
setlocal
cd /d "%~dp0"

echo ApexSenseBridge APEX 4 Mini Portable
echo Keep Flydigi Space Station running and use XInput mode.
echo Press Ctrl+C to stop safely and reset both triggers.
echo.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-APEX4-Mini.ps1" %*
set "ASB_EXIT=%ERRORLEVEL%"
if not "%ASB_EXIT%"=="0" (
  echo.
  echo Bridge exited with error code %ASB_EXIT%.
  pause
)
exit /b %ASB_EXIT%
