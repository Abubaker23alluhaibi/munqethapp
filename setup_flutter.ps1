# Flutter Setup Script

Write-Host "=== Flutter Setup Guide ===" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter exists
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue

if ($flutterPath) {
    Write-Host "Flutter found at: $($flutterPath.Source)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking Flutter status..." -ForegroundColor Yellow
    flutter doctor
} else {
    Write-Host "Flutter is not found in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available options:" -ForegroundColor Yellow
    Write-Host "1. Install Flutter manually:" -ForegroundColor White
    Write-Host "   - Download from: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Gray
    Write-Host "   - Extract to C:\src\flutter (or any other folder)" -ForegroundColor Gray
    Write-Host "   - Add C:\src\flutter\bin to PATH" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Use Chocolatey (if installed):" -ForegroundColor White
    Write-Host "   choco install flutter" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Add Flutter temporarily for this session:" -ForegroundColor White
    Write-Host "   `$env:Path += ';C:\src\flutter\bin'" -ForegroundColor Gray
    Write-Host "   (Replace with your actual Flutter path)" -ForegroundColor Gray
    Write-Host ""
    
    # Ask for path
    $customPath = Read-Host "Do you want to add Flutter path manually for this session? (Enter path or press Enter to skip)"
    
    if ($customPath -and (Test-Path "$customPath\bin\flutter.bat")) {
        $env:Path += ";$customPath\bin"
        Write-Host "Flutter added to PATH for this session" -ForegroundColor Green
        Write-Host ""
        flutter doctor
    } elseif ($customPath) {
        Write-Host "Path is incorrect or Flutter not found at this path" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "After setting up Flutter, run:" -ForegroundColor Cyan
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor White
