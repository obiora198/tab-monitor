# Tab Monitor 1-Click Installer
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Tab Monitor Installation           " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$InstallDir = "$env:LOCALAPPDATA\TabMonitor"
$ScriptDir = $PSScriptRoot

Write-Host "`n[1/5] Copying files to $InstallDir..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Copy files
Copy-Item -Path "$ScriptDir\*" -Destination $InstallDir -Recurse -Force

# Update manifest path in installation directory
$ManifestPath = "$InstallDir\com.tabmonitor.host.json"
if (Test-Path $ManifestPath) {
    $HostExePath = "$InstallDir\tabmonitor-host.exe"
    $ManifestJson = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $ManifestJson.path = $HostExePath
    $ManifestJson | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath
}

Write-Host "[2/5] Registering Native Messaging Host in Windows Registry..." -ForegroundColor Yellow
$RegPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host"
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "(default)" -Value $ManifestPath

Write-Host "[3/5] Configuring Chrome Policy Registry Keys (Option 3)..." -ForegroundColor Yellow
try {
    $PolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    if (-not (Test-Path $PolicyPath)) {
        New-Item -Path $PolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $PolicyPath -Name "DeveloperToolsAvailability" -Value 1 -ErrorAction SilentlyContinue
} catch {
    Write-Host "  (Skipped HKLM Policy key - requires Administrator privileges)" -ForegroundColor Gray
}

Write-Host "[4/5] Updating Chrome Shortcuts (Option 2)..." -ForegroundColor Yellow
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

Write-Host "[5/5] Adding Tray App to Windows Startup & Launching..." -ForegroundColor Yellow
$StartupFolder = [Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupFolder\TabMonitor.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "$InstallDir\tray-app.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Tab Monitor Enforcer"
$Shortcut.Save()

if (Get-Process -Name "tray-app" -ErrorAction SilentlyContinue) {
    Stop-Process -Name "tray-app" -Force
}
Start-Process -FilePath "$InstallDir\tray-app.exe" -WorkingDirectory $InstallDir

# Launch Chrome with extension loaded
$ChromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}

if (Test-Path $ChromePath) {
    Write-Host "`nOpening Chrome with Tab Monitor pre-loaded..." -ForegroundColor Green
    Start-Process -FilePath $ChromePath -ArgumentList "--load-extension=`"$InstallDir\extension`""
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "       Installation Complete!             " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Tab Monitor is running & fully automated in Chrome!" -ForegroundColor Cyan
