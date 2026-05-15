$ErrorActionPreference="Stop"
Set-Location "C:\src\new projects\mon_premye_app"

Write-Host "==== VOUPVAPCASH QUICK CHECK ====" -ForegroundColor Cyan

flutter pub get
flutter analyze

Write-Host ""
Write-Host "Si analyze pa bay error rouge, build la stab." -ForegroundColor Green