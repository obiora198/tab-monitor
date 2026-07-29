@echo off
title Tab Monitor Uninstaller
echo.
echo ==========================================
echo       Tab Monitor Uninstallation
echo ==========================================
echo.
echo Requesting Administrator privileges...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0uninstall.ps1\"' -Wait"
