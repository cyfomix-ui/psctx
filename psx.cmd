@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0psx.ps1" %*
exit /b %ERRORLEVEL%
