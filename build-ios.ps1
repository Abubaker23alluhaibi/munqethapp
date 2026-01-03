# ============================================
# سكربت بناء iOS للرفع على App Store
# Build iOS Script for App Store Upload
# ============================================

param(
    [string]$BuildMode = "release",
    [string]$VersionName = "",
    [int]$VersionCode = 0,
    [string]$ExportMethod = "app-store"
)

# Set encoding to UTF-8 for Arabic support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "بناء iOS - iOS Build" -ForegroundColor Cyan
Write-Host "للرفع على App Store" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running on macOS
if ($IsMacOS -eq $false -and $env:OS -ne "Darwin") {
    Write-Host "❌ خطأ: بناء iOS يتطلب macOS" -ForegroundColor Red
    Write-Host "Error: iOS builds require macOS" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 يجب تشغيل هذا السكربت على جهاز Mac" -ForegroundColor Yellow
    Write-Host "💡 This script must be run on a Mac" -ForegroundColor Yellow
    exit 1
}

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

# Check if Xcode is installed
Write-Host "🔍 التحقق من Xcode..." -ForegroundColor Yellow
$xcodeCheck = xcodebuild -version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ خطأ: Xcode غير مثبت" -ForegroundColor Red
    Write-Host "Error: Xcode is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 قم بتثبيت Xcode من App Store" -ForegroundColor Yellow
    Write-Host "💡 Install Xcode from App Store" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Xcode موجود" -ForegroundColor Green
Write-Host ""

# Check if CocoaPods is installed
Write-Host "🔍 التحقق من CocoaPods..." -ForegroundColor Yellow
$podCheck = pod --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ تحذير: CocoaPods غير مثبت" -ForegroundColor Yellow
    Write-Host "Warning: CocoaPods is not installed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 تثبيت CocoaPods..." -ForegroundColor Cyan
    Write-Host "Installing CocoaPods..." -ForegroundColor Cyan
    sudo gem install cocoapods
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ خطأ: فشل تثبيت CocoaPods" -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ CocoaPods موجود" -ForegroundColor Green
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

# Install CocoaPods dependencies
Write-Host "📦 تثبيت تبعيات CocoaPods..." -ForegroundColor Yellow
Set-Location ios
pod install
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ خطأ: فشل تثبيت تبعيات CocoaPods" -ForegroundColor Red
    exit 1
}
Set-Location ..
Write-Host "✅ تم تثبيت تبعيات CocoaPods بنجاح" -ForegroundColor Green
Write-Host ""

# Build arguments
$buildArgs = @("build", "ios", "--$BuildMode", "--no-codesign")

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
Write-Host "🔨 بدء بناء iOS..." -ForegroundColor Yellow
Write-Host "Building iOS for App Store..." -ForegroundColor Yellow
Write-Host ""

# Build iOS
& flutter $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ خطأ: فشل بناء iOS" -ForegroundColor Red
    Write-Host "Error: Failed to build iOS" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ تم بناء iOS بنجاح!" -ForegroundColor Green
Write-Host "iOS built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Find the IPA file or provide instructions
$ipaPath = Join-Path $ProjectRoot "build\ios\ipa\app.ipa"
$runnerPath = Join-Path $ProjectRoot "build\ios\iphoneos\Runner.app"

Write-Host "📱 الخطوات التالية للرفع على App Store:" -ForegroundColor Yellow
Write-Host "Next steps to upload to App Store:" -ForegroundColor Yellow
Write-Host ""
Write-Host "الطريقة 1: استخدام Xcode" -ForegroundColor Cyan
Write-Host "Method 1: Using Xcode" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. افتح Xcode" -ForegroundColor White
Write-Host "   Open Xcode" -ForegroundColor White
Write-Host ""
Write-Host "2. افتح المشروع:" -ForegroundColor White
Write-Host "   Open project:" -ForegroundColor White
Write-Host "   ios/Runner.xcworkspace" -ForegroundColor Gray
Write-Host ""
Write-Host "3. اختر Product > Archive" -ForegroundColor White
Write-Host "   Select Product > Archive" -ForegroundColor White
Write-Host ""
Write-Host "4. بعد الانتهاء، اختر Distribute App" -ForegroundColor White
Write-Host "   After completion, select Distribute App" -ForegroundColor White
Write-Host ""
Write-Host "5. اختر App Store Connect" -ForegroundColor White
Write-Host "   Select App Store Connect" -ForegroundColor White
Write-Host ""
Write-Host "6. اتبع التعليمات لإكمال الرفع" -ForegroundColor White
Write-Host "   Follow instructions to complete upload" -ForegroundColor White
Write-Host ""
Write-Host "الطريقة 2: استخدام Transporter" -ForegroundColor Cyan
Write-Host "Method 2: Using Transporter" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. قم بإنشاء IPA من Xcode (Product > Archive > Distribute)" -ForegroundColor White
Write-Host "   Create IPA from Xcode (Product > Archive > Distribute)" -ForegroundColor White
Write-Host ""
Write-Host "2. افتح تطبيق Transporter" -ForegroundColor White
Write-Host "   Open Transporter app" -ForegroundColor White
Write-Host ""
Write-Host "3. اسحب وأفلت ملف IPA" -ForegroundColor White
Write-Host "   Drag and drop IPA file" -ForegroundColor White
Write-Host ""
Write-Host "4. اضغط Deliver" -ForegroundColor White
Write-Host "   Press Deliver" -ForegroundColor White
Write-Host ""

if (Test-Path $runnerPath) {
    Write-Host "✅ تم العثور على Runner.app في:" -ForegroundColor Green
    Write-Host "   $runnerPath" -ForegroundColor Gray
} else {
    Write-Host "⚠️ تحذير: لم يتم العثور على Runner.app" -ForegroundColor Yellow
}

Write-Host ""

