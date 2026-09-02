@echo off
setlocal
cd /d "%~dp0"

echo ApexSenseBridge APEX 4 Mini
echo Keep Flydigi Space Station running and the controller in XInput mode.
echo Press Ctrl+C to stop and reset both triggers.
echo.

"%~dp0ApexSenseBridge.exe" bridge-triggers --space-station --xinput-index 0 --virtual-backend integrated
set "ASB_EXIT=%ERRORLEVEL%"
if not "%ASB_EXIT%"=="0" (
  echo.
  echo Bridge exited with error code %ASB_EXIT%.
  pause
)
exit /b %ASB_EXIT%
