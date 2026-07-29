# Tab Monitor 1-Click Uninstaller
# Self-elevate to Administrator if not already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "SilentlyContinue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Tab Monitor Uninstallation         " -ForegroundColor Cyan
Write-Host "  (Running as Administrator)              " -ForegroundColor DarkCyan
Write-Host "==========================================" -ForegroundColor Cyan

$InstallDir = "$env:LOCALAPPDATA\TabMonitor"

# 1. Stop processes
Write-Host "`n[1/5] Stopping running processes..." -ForegroundColor Yellow
Stop-Process -Name "tray-app" -Force
Stop-Process -Name "tabmonitor-host" -Force
Write-Host "  Done." -ForegroundColor Green

# 2. Remove Registry Keys
Write-Host "[2/5] Removing Native Messaging Host registry key..." -ForegroundColor Yellow
Remove-Item -Path "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host" -Recurse -Force
Write-Host "  Done." -ForegroundColor Green

# 3. Remove Chrome Policy Keys
Write-Host "[3/5] Removing Chrome policy registry keys..." -ForegroundColor Yellow
$PolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
if (Test-Path $PolicyPath) {
    Remove-ItemProperty -Path $PolicyPath -Name "DeveloperToolsAvailability" -Force -ErrorAction SilentlyContinue
    Write-Host "  Policy key removed." -ForegroundColor Green
} else {
    Write-Host "  No policy keys found." -ForegroundColor DarkGray
}

# 4. Restore Chrome Shortcuts (remove --load-extension flag)
Write-Host "[4/5] Restoring Chrome shortcuts..." -ForegroundColor Yellow
$ShortcutLocations = @(
    "$env:USERPROFILE\Desktop",
    "$env:PUBLIC\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
)

foreach ($Location in $ShortcutLocations) {
    if (Test-Path $Location) {
        Get-ChildItem -Path $Location -Filter "*Chrome*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $WScriptShell = New-Object -ComObject WScript.Shell
                $Sc = $WScriptShell.CreateShortcut($_.FullName)
                if ($Sc.Arguments -like "*--load-extension*") {
                    $Sc.Arguments = ($Sc.Arguments -replace '--load-extension="[^"]*"\s*', '').Trim()
                    $Sc.Save()
                    Write-Host "  Restored: $($_.Name)" -ForegroundColor Gray
                }
            } catch {}
        }
    }
}

# Remove Startup Shortcut
$StartupFolder = [Environment]::GetFolderPath('Startup')
Remove-Item -Path "$StartupFolder\TabMonitor.lnk" -Force
Write-Host "  Startup shortcut removed." -ForegroundColor Green

# 5. Remove Files
Write-Host "[5/5] Removing installation folder..." -ForegroundColor Yellow
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "  Removed $InstallDir" -ForegroundColor Green
} else {
    Write-Host "  Folder not found (already removed)." -ForegroundColor DarkGray
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "     Uninstallation Complete!             " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Tab Monitor has been completely removed." -ForegroundColor Cyan
Write-Host "Chrome shortcuts have been restored to normal." -ForegroundColor Cyan

Write-Host "`n"
Read-Host -Prompt "Press Enter to exit..."
