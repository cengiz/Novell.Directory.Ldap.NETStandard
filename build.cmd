@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0InvokeBuild-Bootstrap.ps1' %*"
exit /B %errorlevel%
