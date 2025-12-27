# ============================================
# Script to Change Package Name and Create Keystore
# ============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$NewPackageName = "com.munqeth.app",
    
    [Parameter(Mandatory=$false)]
    [string]$KeystoreName = "munqeth.keystore",
    
    [Parameter(Mandatory=$false)]
    [string]$KeystoreAlias = "munqeth",
    
    [Parameter(Mandatory=$false)]
    [string]$KeystorePassword = "munqeth2024",
    
    [Parameter(Mandatory=$false)]
    [string]$OrganizationName = "Munqeth",
    
    [Parameter(Mandatory=$false)]
    [string]$City = "Baghdad",
    
    [Parameter(Mandatory=$false)]
    [string]$Country = "IQ"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Change Package Name and Create Keystore" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Current package name
$OldPackageName = "com.example.flutter_app"
$OldPackagePath = $OldPackageName.Replace(".", "\")
$NewPackagePath = $NewPackageName.Replace(".", "\")

Write-Host "Old Package Name: $OldPackageName" -ForegroundColor Yellow
Write-Host "New Package Name: $NewPackageName" -ForegroundColor Green
Write-Host ""

# ============================================
# Step 1: Check if keytool is available
# ============================================
Write-Host "[1/6] Checking keytool..." -ForegroundColor Yellow
try {
    $keytoolVersion = keytool -version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ERROR: keytool not found!" -ForegroundColor Red
        Write-Host "   Please install JDK first:" -ForegroundColor Yellow
        Write-Host "   choco install openjdk -y" -ForegroundColor White
        Write-Host "   Then restart PowerShell as Administrator" -ForegroundColor White
        exit 1
    }
    Write-Host "   OK: keytool is available" -ForegroundColor Green
    Write-Host "   $keytoolVersion" -ForegroundColor Gray
} catch {
    Write-Host "   ERROR: keytool not found!" -ForegroundColor Red
    Write-Host "   Please install JDK first:" -ForegroundColor Yellow
    Write-Host "   choco install openjdk -y" -ForegroundColor White
    exit 1
}

# ============================================
# Step 2: Update Package Name in build.gradle
# ============================================
Write-Host "[2/6] Updating Package Name in build.gradle..." -ForegroundColor Yellow
$buildGradlePath = "android\app\build.gradle"
if (Test-Path $buildGradlePath) {
    $content = Get-Content $buildGradlePath -Raw -Encoding UTF8
    $content = $content -replace "namespace `"$OldPackageName`"", "namespace `"$NewPackageName`""
    $content = $content -replace "applicationId `"$OldPackageName`"", "applicationId `"$NewPackageName`""
    Set-Content -Path $buildGradlePath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "   OK: build.gradle updated" -ForegroundColor Green
} else {
    Write-Host "   ERROR: build.gradle not found!" -ForegroundColor Red
    exit 1
}

# ============================================
# Step 3: Move MainActivity.kt to new path
# ============================================
Write-Host "[3/6] Moving MainActivity.kt to new path..." -ForegroundColor Yellow
$oldMainActivityPath = "android\app\src\main\kotlin\$OldPackagePath\MainActivity.kt"
$newMainActivityDir = "android\app\src\main\kotlin\$NewPackagePath"
$newMainActivityPath = "$newMainActivityDir\MainActivity.kt"

if (Test-Path $oldMainActivityPath) {
    # Create new directory structure
    if (-not (Test-Path $newMainActivityDir)) {
        New-Item -ItemType Directory -Path $newMainActivityDir -Force | Out-Null
    }
    
    # Read and update MainActivity.kt
    $mainActivityContent = Get-Content $oldMainActivityPath -Raw -Encoding UTF8
    $mainActivityContent = $mainActivityContent -replace "package $OldPackageName", "package $NewPackageName"
    Set-Content -Path $newMainActivityPath -Value $mainActivityContent -Encoding UTF8 -NoNewline
    
    # Delete old directory
    $oldDir = Split-Path $oldMainActivityPath
    if (Test-Path $oldDir) {
        Remove-Item -Path $oldDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "   OK: MainActivity.kt moved and updated" -ForegroundColor Green
} else {
    Write-Host "   WARNING: MainActivity.kt not found at expected path" -ForegroundColor Yellow
}

# ============================================
# Step 4: Update AndroidManifest.xml if needed
# ============================================
Write-Host "[4/6] Checking AndroidManifest.xml..." -ForegroundColor Yellow
$manifestPath = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
    $manifestContent = Get-Content $manifestPath -Raw -Encoding UTF8
    # AndroidManifest usually doesn't need package name update in modern Flutter
    Write-Host "   OK: AndroidManifest.xml checked" -ForegroundColor Green
} else {
    Write-Host "   WARNING: AndroidManifest.xml not found" -ForegroundColor Yellow
}

# ============================================
# Step 5: Create Keystore
# ============================================
Write-Host "[5/6] Creating Keystore..." -ForegroundColor Yellow
$keystorePath = "android\app\$KeystoreName"

if (Test-Path $keystorePath) {
    Write-Host "   WARNING: Keystore already exists: $KeystoreName" -ForegroundColor Yellow
    $overwrite = Read-Host "   Do you want to overwrite it? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "   SKIPPED: Keystore creation cancelled" -ForegroundColor Yellow
    } else {
        Remove-Item -Path $keystorePath -Force
        Write-Host "   Creating new keystore..." -ForegroundColor Yellow
    }
}

if (-not (Test-Path $keystorePath)) {
    $dname = "CN=$OrganizationName, OU=Development, O=$OrganizationName, L=$City, ST=$City, C=$Country"
    
    Write-Host "   Keystore Name: $KeystoreName" -ForegroundColor Gray
    Write-Host "   Alias: $KeystoreAlias" -ForegroundColor Gray
    Write-Host "   Password: $KeystorePassword" -ForegroundColor Gray
    Write-Host "   Validity: 10000 days (~27 years)" -ForegroundColor Gray
    Write-Host ""
    
    try {
        keytool -genkey -v `
            -keystore $keystorePath `
            -alias $KeystoreAlias `
            -keyalg RSA `
            -keysize 2048 `
            -validity 10000 `
            -storepass $KeystorePassword `
            -keypass $KeystorePassword `
            -dname $dname
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   OK: Keystore created successfully!" -ForegroundColor Green
            Write-Host "   Location: $keystorePath" -ForegroundColor Gray
        } else {
            Write-Host "   ERROR: Failed to create keystore" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "   ERROR: Failed to create keystore: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================================
# Step 6: Update build.gradle with signing config
# ============================================
Write-Host "[6/6] Updating build.gradle with signing config..." -ForegroundColor Yellow
$buildGradlePath = "android\app\build.gradle"
if (Test-Path $buildGradlePath) {
    $content = Get-Content $buildGradlePath -Raw -Encoding UTF8
    
    # Check if signing configs already exist
    if ($content -notmatch "signingConfigs") {
        # Add signing configs before android block
        $signingConfig = @"

    signingConfigs {
        release {
            storeFile file('$KeystoreName')
            storePassword '$KeystorePassword'
            keyAlias '$KeystoreAlias'
            keyPassword '$KeystorePassword'
        }
    }

"@
        $content = $content -replace "(android \{)", "`$1`n$signingConfig"
    }
    
    # Update release buildType to use release signing
    if ($content -match "buildTypes \{") {
        $content = $content -replace "signingConfig signingConfigs\.debug", "signingConfig signingConfigs.release"
    }
    
    Set-Content -Path $buildGradlePath -Value $content -Encoding UTF8 -NoNewline
    Write-Host "   OK: Signing config added to build.gradle" -ForegroundColor Green
} else {
    Write-Host "   ERROR: build.gradle not found!" -ForegroundColor Red
    exit 1
}

# ============================================
# Summary
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Package Name: $OldPackageName -> $NewPackageName" -ForegroundColor Green
Write-Host "Keystore: $keystorePath" -ForegroundColor Green
Write-Host "Alias: $KeystoreAlias" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter clean" -ForegroundColor White
Write-Host "2. Run: flutter pub get" -ForegroundColor White
Write-Host "3. Build release APK: flutter build apk --release" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT: Keep your keystore file safe!" -ForegroundColor Red
Write-Host "          If you lose it, you cannot update your app on Play Store!" -ForegroundColor Red
Write-Host ""






