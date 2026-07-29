# Script to build and package Tab Monitor for distribution to another PC
$ErrorActionPreference = "Stop"

$RootDir = "$PSScriptRoot\.."
$DistDir = "$RootDir\dist\TabMonitor-Setup"

Write-Host "Building release binaries and bundling Tab Monitor package..." -ForegroundColor Cyan

# 1. Build Native Host Release
Write-Host "`n[1/3] Building Native Host (Release)..." -ForegroundColor Yellow
Push-Location "$RootDir\native-host"
$env:Path += ";$env:USERPROFILE\.cargo\bin"
cargo build --release
Pop-Location

# 2. Build Tauri App Release
Write-Host "`n[2/3] Building Tauri Tray App (Release)..." -ForegroundColor Yellow
Push-Location "$RootDir\tray-app"
npm run tauri build
Pop-Location

# 3. Create Dist Package Directory
Write-Host "`n[3/3] Assembling distribution package into $DistDir..." -ForegroundColor Yellow
if (Test-Path $DistDir) {
    Remove-Item $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

# Copy Exes
Copy-Item "$RootDir\native-host\target\release\tabmonitor-host.exe" -Destination $DistDir
Copy-Item "$RootDir\tray-app\src-tauri\target\release\tray-app.exe" -Destination $DistDir

# Copy Native Host Manifest
$Manifest = Get-Content "$RootDir\native-host\manifest.json" -Raw | ConvertFrom-Json
$Manifest.path = "tabmonitor-host.exe"
$Manifest | ConvertTo-Json -Depth 5 | Set-Content "$DistDir\com.tabmonitor.host.json"

# Copy Extension
Copy-Item "$RootDir\extension" -Destination "$DistDir\extension" -Recurse -Force

# Copy Install & Uninstall Scripts (PS1 + BAT wrappers)
Copy-Item "$RootDir\installer\install.ps1" -Destination "$DistDir\install.ps1"
Copy-Item "$RootDir\installer\uninstall.ps1" -Destination "$DistDir\uninstall.ps1"
Copy-Item "$RootDir\installer\Install Tab Monitor.bat" -Destination "$DistDir\Install Tab Monitor.bat"
Copy-Item "$RootDir\installer\Uninstall Tab Monitor.bat" -Destination "$DistDir\Uninstall Tab Monitor.bat"

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "   Distribution Package Ready!            " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Folder path: $DistDir" -ForegroundColor White
Write-Host "Double-click 'Install Tab Monitor.bat' on any Windows PC!" -ForegroundColor Cyan

