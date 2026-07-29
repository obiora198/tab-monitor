@echo off
title Tab Monitor Installer
echo.
echo ==========================================
echo        Tab Monitor Installation
echo ==========================================
echo.
echo Requesting Administrator privileges...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0install.ps1\"' -Wait"
