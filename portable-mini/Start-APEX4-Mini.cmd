@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo ApexSenseBridge APEX 4 Mini 便携版
echo 请保持飞智空间站运行，并确认手柄处于 XInput 模式。
echo 按 Ctrl+C 可安全停止并复位左右扳机。
echo.

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-APEX4-Mini.ps1"
set "ASB_EXIT=%ERRORLEVEL%"
if not "%ASB_EXIT%"=="0" (
  echo.
  echo 桥接器异常退出，错误代码：%ASB_EXIT%。
  pause
)
exit /b %ASB_EXIT%
