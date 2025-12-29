# Script to regenerate app icons
Write-Host "Regenerating app icons from logo.png..." -ForegroundColor Cyan

# Navigate to munqeth directory
Set-Location $PSScriptRoot

# Run flutter pub get to ensure dependencies are installed
Write-Host "`n1. Installing dependencies..." -ForegroundColor Yellow
flutter pub get

# Generate launcher icons
Write-Host "`n2. Generating launcher icons..." -ForegroundColor Yellow
dart run flutter_launcher_icons

# Clean build
Write-Host "`n3. Cleaning build cache..." -ForegroundColor Yellow
flutter clean

Write-Host "`n✓ Icons regenerated successfully!" -ForegroundColor Green
Write-Host "Now run: flutter run" -ForegroundColor Cyan









