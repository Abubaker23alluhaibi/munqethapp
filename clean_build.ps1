# Script to clean Flutter and Gradle build files to free up disk space

Write-Host "🧹 تنظيف ملفات البناء لتحرير المساحة..." -ForegroundColor Cyan

# Clean Flutter build files
Write-Host "`n📱 تنظيف Flutter build..." -ForegroundColor Yellow
flutter clean

# Clean Gradle cache (optional - frees more space but takes longer)
Write-Host "`n🔧 تنظيف Gradle cache..." -ForegroundColor Yellow
if (Test-Path "$env:USERPROFILE\.gradle\caches") {
    $gradleCacheSize = (Get-ChildItem "$env:USERPROFILE\.gradle\caches" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "   حجم Gradle cache: $([math]::Round($gradleCacheSize, 2)) GB" -ForegroundColor Gray
    
    $response = Read-Host "   هل تريد حذف Gradle cache؟ (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Remove-Item "$env:USERPROFILE\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "   ✅ تم حذف Gradle cache" -ForegroundColor Green
    }
}

# Clean build folder
Write-Host "`n🗑️  تنظيف مجلد build..." -ForegroundColor Yellow
if (Test-Path "build") {
    $buildSize = (Get-ChildItem "build" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "   حجم مجلد build: $([math]::Round($buildSize, 2)) MB" -ForegroundColor Gray
    Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ تم حذف مجلد build" -ForegroundColor Green
}

# Clean Android build folder
Write-Host "`n🤖 تنظيف Android build..." -ForegroundColor Yellow
if (Test-Path "android\build") {
    Remove-Item "android\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ تم تنظيف android\build" -ForegroundColor Green
}

if (Test-Path "android\app\build") {
    Remove-Item "android\app\build" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ تم تنظيف android\app\build" -ForegroundColor Green
}

# Get pub cache size
Write-Host "`n📦 فحص Flutter pub cache..." -ForegroundColor Yellow
if (Test-Path "$env:USERPROFILE\.pub-cache") {
    $pubCacheSize = (Get-ChildItem "$env:USERPROFILE\.pub-cache" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "   حجم pub cache: $([math]::Round($pubCacheSize, 2)) GB" -ForegroundColor Gray
}

# Check disk space
Write-Host "`n💾 فحص المساحة المتاحة..." -ForegroundColor Yellow
$drive = (Get-Location).Drive.Name
$disk = Get-PSDrive $drive
$freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
$usedSpaceGB = [math]::Round($disk.Used / 1GB, 2)
$totalSpaceGB = [math]::Round(($disk.Free + $disk.Used) / 1GB, 2)

Write-Host "   القرص: $drive" -ForegroundColor Gray
Write-Host "   المساحة الحرة: $freeSpaceGB GB" -ForegroundColor $(if ($freeSpaceGB -lt 5) { "Red" } else { "Green" })
Write-Host "   المساحة المستخدمة: $usedSpaceGB GB / $totalSpaceGB GB" -ForegroundColor Gray

if ($freeSpaceGB -lt 5) {
    Write-Host "`n⚠️  تحذير: المساحة الحرة قليلة جداً!" -ForegroundColor Red
    Write-Host "   يرجى حذف ملفات غير ضرورية أو تحرير مساحة إضافية" -ForegroundColor Yellow
}

Write-Host "`n✅ اكتمل التنظيف!" -ForegroundColor Green
Write-Host "`n💡 نصيحة: قم بتشغيل 'flutter pub get' قبل البناء مرة أخرى" -ForegroundColor Cyan






