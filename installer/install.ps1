# Tab Monitor 1-Click Installer
$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Tab Monitor Installation           " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$InstallDir = "$env:LOCALAPPDATA\TabMonitor"
$ScriptDir = $PSScriptRoot

Write-Host "`n[1/4] Copying files to $InstallDir..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Copy files
Copy-Item -Path "$ScriptDir\*" -Destination $InstallDir -Recurse -Force

# Update manifest path in installation directory
$ManifestPath = "$InstallDir\com.tabmonitor.host.json"
if (Test-Path $ManifestPath) {
    $HostExePath = "$InstallDir\tabmonitor-host.exe" -replace '\\', '\\'
    $ManifestContent = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $ManifestContent.path = "$InstallDir\tabmonitor-host.exe"
    $ManifestContent | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath
}

Write-Host "[2/4] Registering Native Messaging Host in Windows Registry..." -ForegroundColor Yellow
$RegPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "(default)" -Value $ManifestPath

Write-Host "[3/4] Updating Chrome Shortcuts & Startup..." -ForegroundColor Yellow
$ShortcutLocations = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktop'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu') + "\Programs"
)

foreach ($Location in $ShortcutLocations) {
    if (Test-Path $Location) {
        Get-ChildItem -Path $Location -Filter "*Chrome*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $WScriptShell = New-Object -ComObject WScript.Shell
                $Sc = $WScriptShell.CreateShortcut($_.FullName)
                if ($Sc.TargetPath -like "*chrome.exe*") {
                    if ($Sc.Arguments -notlike "*--load-extension*") {
                        $Sc.Arguments = "--load-extension=`"$InstallDir\extension`" " + $Sc.Arguments
                        $Sc.Save()
                        Write-Host "  Updated shortcut: $($_.Name)" -ForegroundColor Gray
                    }
                }
            } catch {}
        }
    }
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

Write-Host "[4/4] Launching Tab Monitor App & Chrome..." -ForegroundColor Yellow
if (Get-Process -Name "tray-app" -ErrorAction SilentlyContinue) {
    Stop-Process -Name "tray-app" -Force
}
Start-Process -FilePath "$InstallDir\tray-app.exe" -WorkingDirectory $InstallDir

# Launch Chrome with extension
$ChromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}

if (Test-Path $ChromePath) {
    Write-Host "`nRestarting Chrome to activate extension..." -ForegroundColor Green
    Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    Start-Process -FilePath $ChromePath -ArgumentList "--load-extension=`"$InstallDir\extension`""
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "       Installation Complete!             " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Tab Monitor Tray App is running!" -ForegroundColor Cyan
Write-Host "`nIf the Chrome Extension icon is not visible in Chrome:" -ForegroundColor Yellow
Write-Host "1. Open chrome://extensions in Chrome" -ForegroundColor White
Write-Host "2. Enable 'Developer mode' (toggle top right)" -ForegroundColor White
Write-Host "3. Click 'Load unpacked' & select folder:" -ForegroundColor White
Write-Host "   $InstallDir\extension" -ForegroundColor Cyan
