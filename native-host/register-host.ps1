# Register the Native Messaging Host for Chrome
$ManifestPath = "C:\Users\USER\Projects\tab-monitor\native-host\manifest.json"
$RegPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.tabmonitor.host"

New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "(default)" -Value $ManifestPath

Write-Host "Registered com.tabmonitor.host successfully!"
Write-Host "Chrome will now look for the host manifest at: $ManifestPath"
