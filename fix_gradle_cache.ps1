# Script to fix Gradle cache corruption issue
# Specifically fixes: "Could not read workspace metadata from ...metadata.bin"

Write-Host "Fixing Gradle cache corruption issue..." -ForegroundColor Cyan

# Stop all Gradle daemons first
Write-Host "`nStopping Gradle daemons..." -ForegroundColor Yellow
Push-Location android
if (Test-Path "gradlew.bat") {
    .\gradlew.bat --stop 2>&1 | Out-Null
    Write-Host "   Gradle daemons stopped" -ForegroundColor Green
}
Pop-Location

# Clean Flutter build first
Write-Host "`nCleaning Flutter build..." -ForegroundColor Yellow
flutter clean

# Delete the corrupted kotlin-dsl accessors cache
Write-Host "`nDeleting Gradle kotlin-dsl cache..." -ForegroundColor Yellow
$kotlinDslCache = "$env:USERPROFILE\.gradle\caches\8.11.1\kotlin-dsl"
if (Test-Path $kotlinDslCache) {
    Remove-Item $kotlinDslCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted kotlin-dsl cache" -ForegroundColor Green
} else {
    Write-Host "   kotlin-dsl cache not found" -ForegroundColor Gray
}

# Also clean the entire Gradle 8.11.1 cache if the above doesn't work
Write-Host "`nCleaning Gradle 8.11.1 cache..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches\8.11.1"
if (Test-Path $gradleCache) {
    Remove-Item $gradleCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted Gradle 8.11.1 cache" -ForegroundColor Green
}

# Delete Gradle daemon cache
Write-Host "`nDeleting Gradle daemon cache..." -ForegroundColor Yellow
$daemonCache = "$env:USERPROFILE\.gradle\daemon"
if (Test-Path $daemonCache) {
    Remove-Item $daemonCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted Gradle daemon cache" -ForegroundColor Green
}

# Clean Android build folders
Write-Host "`nCleaning Android build folders..." -ForegroundColor Yellow
if (Test-Path "android\.gradle") {
    Remove-Item "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted android\.gradle" -ForegroundColor Green
}

if (Test-Path "android\build") {
    Remove-Item "android\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted android\build" -ForegroundColor Green
}

if (Test-Path "android\app\build") {
    Remove-Item "android\app\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted android\app\build" -ForegroundColor Green
}

# Clean project-level build folder
if (Test-Path "build") {
    Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted build" -ForegroundColor Green
}

Write-Host "`nFix completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "   flutter pub get" -ForegroundColor White
Write-Host "   flutter run -d SDEDU20115002604" -ForegroundColor White
Write-Host "`nIf the issue persists, try building with --no-daemon flag:" -ForegroundColor Yellow
Write-Host "   cd android" -ForegroundColor Gray
Write-Host "   .\gradlew.bat assembleDebug --no-daemon" -ForegroundColor Gray

