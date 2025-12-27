# ============================================
# Get SHA-1 Certificate Fingerprint for Google Maps API
# ============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SHA-1 Certificate Fingerprint Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Package Name from build.gradle
$packageName = "com.munqeth.app"
Write-Host "Package Name: $packageName" -ForegroundColor Green
Write-Host ""

# ============================================
# Method 1: Get SHA-1 from Release Keystore
# ============================================
Write-Host "[1/2] Getting SHA-1 from Release Keystore..." -ForegroundColor Yellow
Write-Host ""

$releaseKeystore = "android\app\munqeth.keystore"
$keystoreAlias = "munqeth"
$keystorePassword = "munqeth2024"

if (Test-Path $releaseKeystore) {
    Write-Host "Keystore: $releaseKeystore" -ForegroundColor Gray
    Write-Host "Alias: $keystoreAlias" -ForegroundColor Gray
    Write-Host ""
    
    $result = keytool -list -v -keystore $releaseKeystore -alias $keystoreAlias -storepass $keystorePassword 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $sha1Match = $result | Select-String -Pattern "SHA1:\s*([A-F0-9:]+)"
        
        if ($sha1Match) {
            $sha1Release = $sha1Match.Matches[0].Groups[1].Value
            Write-Host "✅ Release SHA-1 Certificate Fingerprint:" -ForegroundColor Green
            Write-Host $sha1Release -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-1 in output" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Error running keytool" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Release keystore not found: $releaseKeystore" -ForegroundColor Red
}

Write-Host ""

# ============================================
# Method 2: Get SHA-1 from Debug Keystore
# ============================================
Write-Host "[2/2] Getting SHA-1 from Debug Keystore..." -ForegroundColor Yellow
Write-Host ""

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    Write-Host "Keystore: $debugKeystore" -ForegroundColor Gray
    Write-Host ""
    
    $result = keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $sha1Match = $result | Select-String -Pattern "SHA1:\s*([A-F0-9:]+)"
        
        if ($sha1Match) {
            $sha1Debug = $sha1Match.Matches[0].Groups[1].Value
            Write-Host "✅ Debug SHA-1 Certificate Fingerprint:" -ForegroundColor Green
            Write-Host $sha1Debug -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-1 in output" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Error running keytool" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  Debug keystore not found: $debugKeystore" -ForegroundColor Yellow
    Write-Host "   Run the app once to create debug.keystore" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Google Cloud Console Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these to Google Cloud Console:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Go to: https://console.cloud.google.com/apis/credentials" -ForegroundColor White
Write-Host "2. Select your API Key" -ForegroundColor White
Write-Host "3. Application restrictions > Android apps" -ForegroundColor White
Write-Host "4. Click 'Add an item'" -ForegroundColor White
Write-Host ""
Write-Host "For RELEASE build:" -ForegroundColor Cyan
Write-Host "   Package name: $packageName" -ForegroundColor Yellow
if ($sha1Release) {
    Write-Host "   SHA-1: $sha1Release" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "For DEBUG build:" -ForegroundColor Cyan
Write-Host "   Package name: $packageName" -ForegroundColor Yellow
if ($sha1Debug) {
    Write-Host "   SHA-1: $sha1Debug" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""






