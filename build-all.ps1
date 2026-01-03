# ============================================
# سكربت شامل لبناء جميع المنصات
# Comprehensive Build Script for All Platforms
# ============================================

param(
    [switch]$AndroidAPK = $false,
    [switch]$AndroidAAB = $false,
    [switch]$iOS = $false,
    [switch]$All = $false,
    [string]$VersionName = "",
    [int]$VersionCode = 0
)

# Set encoding to UTF-8 for Arabic support
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "سكربت البناء الشامل - Build All Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# If no specific platform is selected, show menu
if (-not $AndroidAPK -and -not $AndroidAAB -and -not $iOS -and -not $All) {
    Write-Host "اختر منصة البناء:" -ForegroundColor Yellow
    Write-Host "Select build platform:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Android APK (للتنزيل المباشر / Direct Download)" -ForegroundColor White
    Write-Host "2. Android AAB (لـ Google Play Store)" -ForegroundColor White
    Write-Host "3. iOS (لـ App Store)" -ForegroundColor White
    Write-Host "4. جميع المنصات / All Platforms" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "اختر رقم (1-4) / Enter number (1-4)"
    
    switch ($choice) {
        "1" { $AndroidAPK = $true }
        "2" { $AndroidAAB = $true }
        "3" { $iOS = $true }
        "4" { $All = $true }
        default {
            Write-Host "❌ اختيار غير صحيح" -ForegroundColor Red
            exit 1
        }
    }
}

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir

# Build parameters
$buildParams = @()
if ($VersionName -ne "") {
    $buildParams += "-VersionName", $VersionName
}
if ($VersionCode -gt 0) {
    $buildParams += "-VersionCode", $VersionCode
}

# Build Android APK
if ($AndroidAPK -or $All) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "بناء Android APK..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    & "$ScriptDir\build-android-apk.ps1" @buildParams
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ فشل بناء Android APK" -ForegroundColor Red
        if (-not $All) { exit 1 }
    }
}

# Build Android AAB
if ($AndroidAAB -or $All) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "بناء Android AAB..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    & "$ScriptDir\build-android-aab.ps1" @buildParams
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ فشل بناء Android AAB" -ForegroundColor Red
        if (-not $All) { exit 1 }
    }
}

# Build iOS
if ($iOS -or $All) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "بناء iOS..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    & "$ScriptDir\build-ios.ps1" @buildParams
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ فشل بناء iOS" -ForegroundColor Red
        if (-not $All) { exit 1 }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ اكتمل البناء!" -ForegroundColor Green
Write-Host "Build completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

