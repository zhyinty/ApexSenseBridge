@echo off
setlocal
cd /d "%~dp0"
"%~dp0ApexSenseBridge.exe" stop-active-sessions
exit /b %ERRORLEVEL%
