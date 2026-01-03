# ============================================
# سكربت بناء APK لأندرويد للتنزيل المباشر
# Build Android APK Script for Direct Download
# ============================================

param(
    [string]$BuildMode = "release",
    [string]$VersionName = "",
    [int]$VersionCode = 0
)

# Set encoding to UTF-8 for Arabic support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "بناء APK لأندرويد - Android APK Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory and navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
Set-Location $ProjectRoot

Write-Host "📁 المجلد الحالي: $ProjectRoot" -ForegroundColor Yellow
Write-Host ""

# Check if Flutter is installed
Write-Host "🔍 التحقق من Flutter..." -ForegroundColor Yellow
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ خطأ: Flutter غير مثبت أو غير موجود في PATH" -ForegroundColor Red
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Flutter موجود" -ForegroundColor Green
Write-Host ""

# Clean previous builds
Write-Host "🧹 تنظيف البناء السابق..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ تحذير: فشل تنظيف البناء السابق" -ForegroundColor Yellow
}
Write-Host ""

# Get dependencies
Write-Host "📦 جلب التبعيات..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ خطأ: فشل جلب التبعيات" -ForegroundColor Red
    exit 1
}
Write-Host "✅ تم جلب التبعيات بنجاح" -ForegroundColor Green
Write-Host ""

# Build arguments
$buildArgs = @("build", "apk", "--$BuildMode")

# Add version name if provided
if ($VersionName -ne "") {
    $buildArgs += "--build-name=$VersionName"
    Write-Host "📝 إصدار التطبيق: $VersionName" -ForegroundColor Cyan
}

# Add version code if provided
if ($VersionCode -gt 0) {
    $buildArgs += "--build-number=$VersionCode"
    Write-Host "🔢 رقم البناء: $VersionCode" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🔨 بدء بناء APK..." -ForegroundColor Yellow
Write-Host "Building APK..." -ForegroundColor Yellow
Write-Host ""

# Build APK
& flutter $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ خطأ: فشل بناء APK" -ForegroundColor Red
    Write-Host "Error: Failed to build APK" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ تم بناء APK بنجاح!" -ForegroundColor Green
Write-Host "APK built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Find the APK file
$apkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-$BuildMode.apk"
if (Test-Path $apkPath) {
    $apkInfo = Get-Item $apkPath
    $fileSizeMB = [math]::Round($apkInfo.Length / 1MB, 2)
    
    Write-Host "📱 معلومات APK:" -ForegroundColor Cyan
    Write-Host "   المسار: $apkPath" -ForegroundColor White
    Write-Host "   الحجم: $fileSizeMB MB" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 يمكنك الآن مشاركة هذا الملف للتنزيل المباشر" -ForegroundColor Yellow
    Write-Host "💡 You can now share this file for direct download" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ تحذير: لم يتم العثور على ملف APK في المسار المتوقع" -ForegroundColor Yellow
    Write-Host "Warning: APK file not found at expected path" -ForegroundColor Yellow
}

Write-Host ""

