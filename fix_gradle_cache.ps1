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

# Kill any Java processes that might be holding files
Write-Host "`nKilling Java processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
if ($javaProcesses) {
    $javaProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "   Killed $($javaProcesses.Count) Java process(es)" -ForegroundColor Green
    Start-Sleep -Seconds 2
} else {
    Write-Host "   No Java processes found" -ForegroundColor Gray
}

# Delete Gradle lock files
Write-Host "`nRemoving Gradle lock files..." -ForegroundColor Yellow
$lockFile = "android\.gradle\noVersion\buildLogic.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted buildLogic.lock" -ForegroundColor Green
}

# Delete all lock files in .gradle directory
$gradleLockFiles = Get-ChildItem -Path "android\.gradle" -Recurse -Filter "*.lock" -ErrorAction SilentlyContinue
if ($gradleLockFiles) {
    $gradleLockFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted $($gradleLockFiles.Count) lock file(s)" -ForegroundColor Green
}

# Also check for any Gradle processes by PID (in case they're still running)
Write-Host "`nChecking for remaining Gradle processes..." -ForegroundColor Yellow
$allProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
    $_.ProcessName -like "*gradle*" -or 
    $_.ProcessName -like "*java*" -or
    ($_.Path -and $_.Path -like "*gradle*")
}
if ($allProcesses) {
    $allProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "   Stopped $($allProcesses.Count) additional process(es)" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Clean Flutter build first
Write-Host "`nCleaning Flutter build..." -ForegroundColor Yellow
flutter clean

# Delete the corrupted transforms cache (Gradle 8.13)
Write-Host "`nDeleting Gradle 8.13 transforms cache..." -ForegroundColor Yellow
$transformsCache = "$env:USERPROFILE\.gradle\caches\8.13\transforms"
if (Test-Path $transformsCache) {
    Remove-Item $transformsCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted Gradle 8.13 transforms cache" -ForegroundColor Green
} else {
    Write-Host "   Gradle 8.13 transforms cache not found" -ForegroundColor Gray
}

# Delete the corrupted kotlin-dsl accessors cache (Gradle 8.13)
Write-Host "`nDeleting Gradle 8.13 kotlin-dsl cache..." -ForegroundColor Yellow
$kotlinDslCache = "$env:USERPROFILE\.gradle\caches\8.13\kotlin-dsl"
if (Test-Path $kotlinDslCache) {
    Remove-Item $kotlinDslCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted Gradle 8.13 kotlin-dsl cache" -ForegroundColor Green
} else {
    Write-Host "   Gradle 8.13 kotlin-dsl cache not found" -ForegroundColor Gray
}

# Also clean the entire Gradle 8.13 cache if the above doesn't work
Write-Host "`nCleaning Gradle 8.13 cache..." -ForegroundColor Yellow
$gradleCache813 = "$env:USERPROFILE\.gradle\caches\8.13"
if (Test-Path $gradleCache813) {
    Remove-Item $gradleCache813 -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Deleted Gradle 8.13 cache" -ForegroundColor Green
}

# Also clean Gradle 8.11.1 cache if it exists
Write-Host "`nCleaning Gradle 8.11.1 cache..." -ForegroundColor Yellow
$gradleCache811 = "$env:USERPROFILE\.gradle\caches\8.11.1"
if (Test-Path $gradleCache811) {
    Remove-Item $gradleCache811 -Recurse -Force -ErrorAction SilentlyContinue
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
# First try to delete lock files before deleting the whole directory
$androidGradleLocks = Get-ChildItem -Path "android\.gradle" -Recurse -Filter "*.lock" -ErrorAction SilentlyContinue
if ($androidGradleLocks) {
    $androidGradleLocks | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "   Removed lock files from android\.gradle" -ForegroundColor Green
    Start-Sleep -Seconds 1
}
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

# Clean project-level build folder (with retry for locked files)
Write-Host "`nCleaning project build folder..." -ForegroundColor Yellow
if (Test-Path "build") {
    # Try to delete with retry logic
    $retries = 3
    $deleted = $false
    for ($i = 1; $i -le $retries; $i++) {
        try {
            Remove-Item "build" -Recurse -Force -ErrorAction Stop
            Write-Host "   Deleted build folder" -ForegroundColor Green
            $deleted = $true
            break
        } catch {
            if ($i -lt $retries) {
                Write-Host "   Attempt $i failed, waiting 2 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                # Try to kill any processes that might be locking files
                Get-Process | Where-Object { $_.Path -like "*munqeth*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "   Could not delete build folder (may be locked by another process)" -ForegroundColor Red
                Write-Host "   Try closing any IDEs, file explorers, or antivirus software" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`nFix completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "   flutter pub get" -ForegroundColor White
Write-Host "   flutter run -d SDEDU20115002604" -ForegroundColor White
Write-Host "`nIf the issue persists, try building with --no-daemon flag:" -ForegroundColor Yellow
Write-Host "   cd android" -ForegroundColor Gray
Write-Host "   .\gradlew.bat assembleDebug --no-daemon" -ForegroundColor Gray

