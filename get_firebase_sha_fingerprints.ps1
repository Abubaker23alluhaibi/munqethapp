# ============================================
# Get SHA Fingerprints for Firebase Console
# ============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firebase SHA Fingerprints Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Package Name
$packageName = "com.munqeth.app"
Write-Host "Package Name: $packageName" -ForegroundColor Green
Write-Host ""

# ============================================
# Get SHA Fingerprints from Release Keystore
# ============================================
Write-Host "[1/2] Getting SHA Fingerprints from Release Keystore..." -ForegroundColor Yellow
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
        # Extract SHA-1
        $sha1Match = $result | Select-String -Pattern "SHA1:\s*([A-F0-9:]+)"
        # Extract SHA-256
        $sha256Match = $result | Select-String -Pattern "SHA256:\s*([A-F0-9:]+)"
        
        if ($sha1Match) {
            $sha1Release = $sha1Match.Matches[0].Groups[1].Value
            Write-Host "✅ Release SHA-1:" -ForegroundColor Green
            Write-Host "   $sha1Release" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-1" -ForegroundColor Red
        }
        
        if ($sha256Match) {
            $sha256Release = $sha256Match.Matches[0].Groups[1].Value
            Write-Host "✅ Release SHA-256:" -ForegroundColor Green
            Write-Host "   $sha256Release" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-256" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Error running keytool" -ForegroundColor Red
        Write-Host "   Make sure Java is installed and keytool is in PATH" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Release keystore not found: $releaseKeystore" -ForegroundColor Red
}

Write-Host ""

# ============================================
# Get SHA Fingerprints from Debug Keystore
# ============================================
Write-Host "[2/2] Getting SHA Fingerprints from Debug Keystore..." -ForegroundColor Yellow
Write-Host ""

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    Write-Host "Keystore: $debugKeystore" -ForegroundColor Gray
    Write-Host ""
    
    $result = keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        # Extract SHA-1
        $sha1Match = $result | Select-String -Pattern "SHA1:\s*([A-F0-9:]+)"
        # Extract SHA-256
        $sha256Match = $result | Select-String -Pattern "SHA256:\s*([A-F0-9:]+)"
        
        if ($sha1Match) {
            $sha1Debug = $sha1Match.Matches[0].Groups[1].Value
            Write-Host "✅ Debug SHA-1:" -ForegroundColor Green
            Write-Host "   $sha1Debug" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-1" -ForegroundColor Red
        }
        
        if ($sha256Match) {
            $sha256Debug = $sha256Match.Matches[0].Groups[1].Value
            Write-Host "✅ Debug SHA-256:" -ForegroundColor Green
            Write-Host "   $sha256Debug" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Could not find SHA-256" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Error running keytool" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  Debug keystore not found: $debugKeystore" -ForegroundColor Yellow
    Write-Host "   Run the app once to create debug.keystore" -ForegroundColor Gray
    Write-Host ""
}

# ============================================
# Firebase Console Instructions
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firebase Console Setup Instructions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to: https://console.firebase.google.com" -ForegroundColor White
Write-Host "2. Select project: munqethnof" -ForegroundColor White
Write-Host "3. Go to: Project Settings (⚙️ → Project settings)" -ForegroundColor White
Write-Host "4. In 'Your apps' section, select Android app: com.munqeth.app" -ForegroundColor White
Write-Host "5. Find 'SHA certificate fingerprints' section" -ForegroundColor White
Write-Host "6. Click 'Add fingerprint' or 'Add SHA certificate fingerprint'" -ForegroundColor White
Write-Host ""
Write-Host "Add these fingerprints:" -ForegroundColor Yellow
Write-Host ""

if ($sha1Release) {
    Write-Host "📱 RELEASE SHA-1 (Required for APK):" -ForegroundColor Cyan
    Write-Host "   $sha1Release" -ForegroundColor Yellow
    Write-Host ""
}

if ($sha256Release) {
    Write-Host "📱 RELEASE SHA-256 (Required for APK):" -ForegroundColor Cyan
    Write-Host "   $sha256Release" -ForegroundColor Yellow
    Write-Host ""
}

if ($sha1Debug) {
    Write-Host "🔧 DEBUG SHA-1 (For USB debugging):" -ForegroundColor Cyan
    Write-Host "   $sha1Debug" -ForegroundColor Yellow
    Write-Host ""
}

if ($sha256Debug) {
    Write-Host "🔧 DEBUG SHA-256 (For USB debugging):" -ForegroundColor Cyan
    Write-Host "   $sha256Debug" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  IMPORTANT: Add ALL fingerprints to Firebase Console!" -ForegroundColor Red
Write-Host "   - Release SHA-1 and SHA-256 (for APK)" -ForegroundColor Yellow
Write-Host "   - Debug SHA-1 and SHA-256 (for USB debugging)" -ForegroundColor Yellow
Write-Host ""
Write-Host "After adding fingerprints:" -ForegroundColor Green
Write-Host "   1. flutter clean" -ForegroundColor White
Write-Host "   2. flutter build apk --release" -ForegroundColor White
Write-Host "   3. Install APK and test notifications" -ForegroundColor White
Write-Host ""







