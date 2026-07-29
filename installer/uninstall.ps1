# Tab Monitor 1-Click Uninstaller
$ErrorActionPreference = "SilentlyContinue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Tab Monitor Uninstallation         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Stop processes
Write-Host "`n[1/4] Stopping running processes..." -ForegroundColor Yellow
Stop-Process -Name "tray-app" -Force
Stop-Process -Name "tabmonitor-host" -Force

# 2. Remove Registry Keys
Write-Host "[2/4] Removing Native Messaging Host registry key..." -ForegroundColor Yellow
Remove-Item -Path "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host" -Recurse -Force

# 3. Remove Startup Shortcut
Write-Host "[3/4] Removing startup shortcut..." -ForegroundColor Yellow
$StartupFolder = [Environment]::GetFolderPath('Startup')
Remove-Item -Path "$StartupFolder\TabMonitor.lnk" -Force

# 4. Remove Files
Write-Host "[4/4] Removing installation folder..." -ForegroundColor Yellow
$InstallDir = "$env:LOCALAPPDATA\TabMonitor"
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "     Uninstallation Complete!             " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Tab Monitor has been completely removed from this PC." -ForegroundColor Cyan

Write-Host "`n"
Read-Host -Prompt "Press Enter to exit..."
