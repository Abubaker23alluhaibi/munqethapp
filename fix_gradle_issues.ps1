# Script to fix Gradle cache and disk space issues

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "تنظيف الملفات المؤقتة لتحرير مساحة القرص" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Calculate space before
$beforeSpace = (Get-PSDrive C).Free
Write-Host "المساحة الحرة قبل التنظيف: $([math]::Round($beforeSpace/1GB, 2)) GB" -ForegroundColor Yellow
Write-Host ""

# 1. Clean Gradle cache and transforms
Write-Host "[1/6] تنظيف Gradle cache..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCache) {
    $size = (Get-ChildItem -Path $gradleCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Remove-Item -Path $gradleCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   تم حذف: $([math]::Round($size/1GB, 2)) GB" -ForegroundColor Green
}

# 2. Clean Gradle transforms (the problematic one)
Write-Host "[2/6] تنظيف Gradle transforms..." -ForegroundColor Yellow
$gradleTransforms = "$env:USERPROFILE\.gradle\caches\transforms-*"
Get-ChildItem -Path "$env:USERPROFILE\.gradle" -Filter "transforms-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   تم حذف transforms: $([math]::Round($size/1GB, 2)) GB" -ForegroundColor Green
}

# 3. Clean Gradle daemon
Write-Host "[3/6] تنظيف Gradle daemon..." -ForegroundColor Yellow
$gradleDaemon = "$env:USERPROFILE\.gradle\daemon"
if (Test-Path $gradleDaemon) {
    $size = (Get-ChildItem -Path $gradleDaemon -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Remove-Item -Path $gradleDaemon -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   تم حذف: $([math]::Round($size/1GB, 2)) GB" -ForegroundColor Green
}

# 4. Clean Flutter temp files
Write-Host "[4/6] تنظيف Flutter temp files..." -ForegroundColor Yellow
$flutterTempDirs = Get-ChildItem -Path "$env:LOCALAPPDATA\Temp" -Filter "flutter_tools.*" -Directory -ErrorAction SilentlyContinue
$totalSize = 0
foreach ($dir in $flutterTempDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}
if ($totalSize -gt 0) {
    Write-Host "   تم حذف: $([math]::Round($totalSize/1GB, 2)) GB" -ForegroundColor Green
}

# 5. Clean Windows temp files
Write-Host "[5/6] تنظيف Windows temp files..." -ForegroundColor Yellow
$tempFiles = Get-ChildItem -Path $env:TEMP -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) }
$tempSize = ($tempFiles | Measure-Object -Property Length -Sum).Sum
$tempFiles | Remove-Item -Force -ErrorAction SilentlyContinue
if ($tempSize -gt 0) {
    Write-Host "   تم حذف: $([math]::Round($tempSize/1GB, 2)) GB" -ForegroundColor Green
}

# 6. Clean project build files
Write-Host "[6/6] تنظيف ملفات البناء في المشروع..." -ForegroundColor Yellow
$projectDirs = @(".\build", ".\android\.gradle", ".\android\app\build", ".\android\build")
$projectSize = 0
foreach ($dir in $projectDirs) {
    if (Test-Path $dir) {
        $size = (Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $projectSize += $size
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($projectSize -gt 0) {
    Write-Host "   تم حذف: $([math]::Round($projectSize/1MB, 2)) MB" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
$afterSpace = (Get-PSDrive C).Free
$freedSpace = $afterSpace - $beforeSpace
Write-Host "المساحة الحرة بعد التنظيف: $([math]::Round($afterSpace/1GB, 2)) GB" -ForegroundColor Green
Write-Host "تم تحرير: $([math]::Round($freedSpace/1GB, 2)) GB" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "الآن قم بتشغيل:" -ForegroundColor Yellow
Write-Host "  flutter clean" -ForegroundColor White
Write-Host "  flutter pub get" -ForegroundColor White
Write-Host "  flutter run -d SDEDU20115002604" -ForegroundColor White
Write-Host ""

