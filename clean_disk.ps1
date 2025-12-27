# Clean disk space for Flutter build

Write-Host "Cleaning disk space..." -ForegroundColor Cyan
Write-Host ""

$beforeSpace = (Get-PSDrive C).Free
Write-Host "Free space before: $([math]::Round($beforeSpace/1GB, 2)) GB" -ForegroundColor Yellow

# Clean Gradle cache
Write-Host "[1/5] Cleaning Gradle cache..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCache) {
    Remove-Item -Path $gradleCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Gradle cache cleared!" -ForegroundColor Green
}

# Clean Gradle transforms (including version-specific)
Write-Host "[2/5] Cleaning Gradle transforms..." -ForegroundColor Yellow
Get-ChildItem -Path "$env:USERPROFILE\.gradle\caches" -Filter "transforms-*" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:USERPROFILE\.gradle\caches" -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | ForEach-Object {
    $transformsPath = Join-Path $_.FullName "transforms"
    if (Test-Path $transformsPath) {
        Remove-Item -Path $transformsPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "   Gradle transforms cleared!" -ForegroundColor Green

# Clean Gradle daemon
Write-Host "[3/5] Cleaning Gradle daemon..." -ForegroundColor Yellow
$gradleDaemon = "$env:USERPROFILE\.gradle\daemon"
if (Test-Path $gradleDaemon) {
    Remove-Item -Path $gradleDaemon -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Gradle daemon cleared!" -ForegroundColor Green
}

# Clean Flutter temp files
Write-Host "[4/5] Cleaning Flutter temp files..." -ForegroundColor Yellow
Get-ChildItem -Path "$env:LOCALAPPDATA\Temp" -Filter "flutter_tools.*" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "   Flutter temp files cleared!" -ForegroundColor Green

# Clean project build files
Write-Host "[5/5] Cleaning project build files..." -ForegroundColor Yellow
$projectDirs = @(".\build", ".\android\.gradle", ".\android\app\build")
foreach ($dir in $projectDirs) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "   Project build files cleared!" -ForegroundColor Green

Write-Host ""
$afterSpace = (Get-PSDrive C).Free
$freedSpace = $afterSpace - $beforeSpace
Write-Host "Free space after: $([math]::Round($afterSpace/1GB, 2)) GB" -ForegroundColor Green
Write-Host "Freed space: $([math]::Round($freedSpace/1GB, 2)) GB" -ForegroundColor Green
Write-Host ""
Write-Host "Done! Now run:" -ForegroundColor Cyan
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter run -d SDEDU20115002604" -ForegroundColor White

