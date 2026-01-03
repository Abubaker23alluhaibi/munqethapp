# ============================================
# سكربت بناء AAB لأندرويد للرفع على Google Play Store
# Build Android App Bundle (AAB) Script for Google Play Store
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
Write-Host "بناء AAB لأندرويد - Android AAB Build" -ForegroundColor Cyan
Write-Host "للرفع على Google Play Store" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory and navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
Set-Location $ProjectRoot

Write-Host "المجلد الحالي: $ProjectRoot" -ForegroundColor Yellow
Write-Host ""

# Check if keystore exists
$keystorePath = Join-Path $ProjectRoot "android\app\munqeth.keystore"
$keystorePropsPath = Join-Path $ProjectRoot "android\keystore.properties"

Write-Host "التحقق من Keystore..." -ForegroundColor Yellow

if (-not (Test-Path $keystorePath)) {
    Write-Host "خطأ: ملف Keystore غير موجود!" -ForegroundColor Red
    Write-Host "Error: Keystore file not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "المسار المتوقع: $keystorePath" -ForegroundColor Yellow
    Write-Host "Expected path: $keystorePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "قم بإنشاء Keystore اولا باستخدام:" -ForegroundColor Cyan
    Write-Host "Create keystore first using:" -ForegroundColor Cyan
    Write-Host "   android\create_keystore.ps1" -ForegroundColor White
    exit 1
}

if (-not (Test-Path $keystorePropsPath)) {
    Write-Host "خطأ: ملف keystore.properties غير موجود!" -ForegroundColor Red
    Write-Host "Error: keystore.properties file not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "قم بإنشاء ملف keystore.properties في android\" -ForegroundColor Cyan
    Write-Host "Create keystore.properties file in android\" -ForegroundColor Cyan
    exit 1
}

# Verify keystore properties content
$keystoreProps = Get-Content $keystorePropsPath
$hasStoreFile = $keystoreProps | Select-String -Pattern "storeFile"
$hasStorePassword = $keystoreProps | Select-String -Pattern "storePassword"
$hasKeyAlias = $keystoreProps | Select-String -Pattern "keyAlias"
$hasKeyPassword = $keystoreProps | Select-String -Pattern "keyPassword"

if (-not $hasStoreFile -or -not $hasStorePassword -or -not $hasKeyAlias -or -not $hasKeyPassword) {
    Write-Host "تحذير: ملف keystore.properties قد يكون غير مكتمل" -ForegroundColor Yellow
    Write-Host "Warning: keystore.properties file may be incomplete" -ForegroundColor Yellow
}

Write-Host "تم العثور على Keystore في: $keystorePath" -ForegroundColor Green
Write-Host "تم العثور على keystore.properties في: $keystorePropsPath" -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
Write-Host "التحقق من Flutter..." -ForegroundColor Yellow
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "خطأ: Flutter غير مثبت او غير موجود في PATH" -ForegroundColor Red
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "Flutter موجود" -ForegroundColor Green
Write-Host ""

# Clean previous builds
Write-Host "تنظيف البناء السابق..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "تحذير: فشل تنظيف البناء السابق" -ForegroundColor Yellow
}
Write-Host ""

# Get dependencies
Write-Host "جلب التبعيات..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "خطأ: فشل جلب التبعيات" -ForegroundColor Red
    exit 1
}
Write-Host "تم جلب التبعيات بنجاح" -ForegroundColor Green
Write-Host ""

# Build arguments
$buildArgs = @("build", "appbundle", "--$BuildMode")

# Add version name if provided
if ($VersionName -ne "") {
    $buildArgs += "--build-name=$VersionName"
    Write-Host "اصدار التطبيق: $VersionName" -ForegroundColor Cyan
}

# Add version code if provided
if ($VersionCode -gt 0) {
    $buildArgs += "--build-number=$VersionCode"
    Write-Host "رقم البناء: $VersionCode" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "بدء بناء AAB..." -ForegroundColor Yellow
Write-Host "Building AAB for Google Play Store..." -ForegroundColor Yellow
Write-Host ""

# Build AAB
& flutter $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "خطأ: فشل بناء AAB" -ForegroundColor Red
    Write-Host "Error: Failed to build AAB" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "تم بناء AAB بنجاح!" -ForegroundColor Green
Write-Host "AAB built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Find the AAB file
$aabPath = Join-Path $ProjectRoot "build\app\outputs\bundle\$BuildMode\app-$BuildMode.aab"

# Also check alternative path
if (-not (Test-Path $aabPath)) {
    $aabPathAlt = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPathAlt) {
        $aabPath = $aabPathAlt
    }
}

if (Test-Path $aabPath) {
    $aabInfo = Get-Item $aabPath
    $fileSizeMB = [math]::Round($aabInfo.Length / 1MB, 2)
    $fileSizeKB = [math]::Round($aabInfo.Length / 1KB, 2)
    
    Write-Host "معلومات AAB:" -ForegroundColor Cyan
    Write-Host "   المسار: $aabPath" -ForegroundColor Green
    $sizeText = "$fileSizeMB MB ($fileSizeKB KB)"
    Write-Host "   الحجم: $sizeText" -ForegroundColor White
    Write-Host "   تاريخ الإنشاء: $($aabInfo.CreationTime)" -ForegroundColor White
    Write-Host ""
    Write-Host "الخطوات التالية للرفع على Google Play Store:" -ForegroundColor Yellow
    Write-Host "Next steps to upload to Google Play Store:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. افتح Google Play Console" -ForegroundColor White
    Write-Host "   Open Google Play Console" -ForegroundColor White
    Write-Host "   https://play.google.com/console" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. اذهب الى Production > Create new release" -ForegroundColor White
    Write-Host "   Go to Production > Create new release" -ForegroundColor White
    Write-Host ""
    Write-Host "3. ارفع ملف AAB من المسار اعلاه" -ForegroundColor White
    Write-Host "   Upload the AAB file from the path above" -ForegroundColor White
    Write-Host ""
    Write-Host "نصيحة: احتفظ بنسخة احتياطية من ملف AAB" -ForegroundColor Cyan
    Write-Host "Tip: Keep a backup copy of the AAB file" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "تحذير: لم يتم العثور على ملف AAB في المسار المتوقع" -ForegroundColor Yellow
    Write-Host "Warning: AAB file not found at expected path" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "المسارات المفحوصة:" -ForegroundColor Yellow
    Write-Host "Checked paths:" -ForegroundColor Yellow
    Write-Host "  - $aabPath" -ForegroundColor Gray
    $altPath = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"
    Write-Host "  - $altPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "تحقق من رسائل البناء اعلاه للبحث عن الاخطاء" -ForegroundColor Cyan
    Write-Host "Check build messages above for errors" -ForegroundColor Cyan
}

Write-Host ""

