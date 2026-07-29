# Tab Monitor 1-Click Installer
# Self-elevate to Administrator if not already running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit
}

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Tab Monitor Installation           " -ForegroundColor Cyan
Write-Host "  (Running as Administrator)              " -ForegroundColor DarkCyan
Write-Host "==========================================" -ForegroundColor Cyan

$InstallDir = "$env:LOCALAPPDATA\TabMonitor"
$ScriptDir = $PSScriptRoot

Write-Host "`n[1/5] Copying files to $InstallDir..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Copy files
Copy-Item -Path "$ScriptDir\*" -Destination $InstallDir -Recurse -Force
Write-Host "  Done." -ForegroundColor Green

# Update manifest path in installation directory
$ManifestPath = "$InstallDir\com.tabmonitor.host.json"
if (Test-Path $ManifestPath) {
    $HostExePath = "$InstallDir\tabmonitor-host.exe"
    $ManifestContent = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $ManifestContent.path = $HostExePath
    $ManifestContent.allowed_origins = @("chrome-extension://lcjcnebnibfdgjglmaojjmbndkcfffki/")
    $ManifestContent | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath
}

Write-Host "[2/5] Registering Native Messaging Host in Windows Registry..." -ForegroundColor Yellow
$RegPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "(default)" -Value $ManifestPath
Write-Host "  Done." -ForegroundColor Green

Write-Host "[3/5] Configuring Chrome Extension Policy..." -ForegroundColor Yellow
# Force-install the unpacked extension via Chrome policy registry keys
$ExtensionDir = "$InstallDir\extension"

# Set Chrome policy to allow --load-extension flag to work reliably
$PolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
if (-not (Test-Path $PolicyPath)) {
    New-Item -Path $PolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $PolicyPath -Name "DeveloperToolsAvailability" -Value 1
Write-Host "  Chrome policy configured." -ForegroundColor Green

Write-Host "[4/5] Updating Chrome Shortcuts with Extension Flag..." -ForegroundColor Yellow
$ShortcutUpdated = $false
$TargetShortcuts = @(
    "$env:USERPROFILE\Desktop\Google Chrome.lnk",
    "$env:PUBLIC\Desktop\Google Chrome.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk",
    "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"
)

foreach ($ShortcutFile in $TargetShortcuts) {
    if (Test-Path $ShortcutFile) {
        try {
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Sc = $WScriptShell.CreateShortcut($ShortcutFile)
            if ($Sc.TargetPath -like "*chrome.exe*") {
                if ($Sc.Arguments -notlike "*--load-extension*") {
                    $Sc.Arguments = "--load-extension=`"$ExtensionDir`" " + $Sc.Arguments
                    $Sc.Save()
                    Write-Host "  Updated: $(Split-Path $ShortcutFile -Leaf)" -ForegroundColor Gray
                    $ShortcutUpdated = $true
                } else {
                    Write-Host "  Already configured: $(Split-Path $ShortcutFile -Leaf)" -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Host "  Could not update: $(Split-Path $ShortcutFile -Leaf) - $_" -ForegroundColor DarkYellow
        }
    }
}

if (-not $ShortcutUpdated) {
    Write-Host "  No Chrome shortcuts found to update." -ForegroundColor DarkYellow
}

# Startup Shortcut for Tray App
$StartupFolder = [Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupFolder\TabMonitor.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "$InstallDir\tray-app.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Tab Monitor Enforcer"
$Shortcut.Save()
Write-Host "  Startup shortcut created." -ForegroundColor Green

Write-Host "[5/5] Launching Tab Monitor App & Chrome..." -ForegroundColor Yellow
if (Get-Process -Name "tray-app" -ErrorAction SilentlyContinue) {
    Stop-Process -Name "tray-app" -Force
    Start-Sleep -Milliseconds 500
}
Start-Process -FilePath "$InstallDir\tray-app.exe" -WorkingDirectory $InstallDir
Write-Host "  Tray app launched." -ForegroundColor Green

# Relaunch Chrome with extension loaded
$ChromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
}

if (Test-Path $ChromePath) {
    Write-Host "`n  Closing Chrome to apply extension..." -ForegroundColor Yellow
    taskkill /F /IM chrome.exe /T 2>$null
    Start-Sleep -Seconds 2
    Write-Host "  Opening Chrome with extension..." -ForegroundColor Yellow
    Start-Process -FilePath $ChromePath -ArgumentList "--load-extension=`"$ExtensionDir`""
    Write-Host "  Chrome relaunched with Tab Monitor extension!" -ForegroundColor Green
} else {
    Write-Host "  Chrome executable not found. Please launch Chrome manually using your shortcut." -ForegroundColor DarkYellow
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "       Installation Complete!             " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Tab Monitor Tray App is running!" -ForegroundColor Cyan
Write-Host "`nIf Chrome doesn't open with the extension automatically:" -ForegroundColor Yellow
Write-Host "Open Chrome using your desktop shortcut, or:" -ForegroundColor White
Write-Host "1. Open chrome://extensions in Chrome" -ForegroundColor White
Write-Host "2. Enable 'Developer mode' (toggle top right)" -ForegroundColor White
Write-Host "3. Click 'Load unpacked' & select folder:" -ForegroundColor White
Write-Host "   $ExtensionDir" -ForegroundColor Cyan

Write-Host "`n"
Read-Host -Prompt "Press Enter to exit..."
