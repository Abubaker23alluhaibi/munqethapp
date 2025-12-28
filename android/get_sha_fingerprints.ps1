# PowerShell script to get SHA-1 and SHA-256 fingerprints from keystore
# Usage: .\get_sha_fingerprints.ps1

Write-Host "=== Getting SHA Fingerprints from Release Keystore ===" -ForegroundColor Cyan
Write-Host ""

# Get keystore properties
$keystorePropertiesPath = Join-Path $PSScriptRoot "keystore.properties"

if (Test-Path $keystorePropertiesPath) {
    Write-Host "Reading keystore.properties..." -ForegroundColor Yellow
    $keystoreProps = @{}
    Get-Content $keystorePropertiesPath | ForEach-Object {
        if ($_ -match '^\s*([^=]+)\s*=\s*(.+)$') {
            $keystoreProps[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    
    $keystoreFile = $keystoreProps['storeFile']
    $keyAlias = $keystoreProps['keyAlias'] ?? 'munqeth'
    
    if ($keystoreFile -and -not [System.IO.Path]::IsPathRooted($keystoreFile)) {
        $keystoreFile = Join-Path $PSScriptRoot "app\$keystoreFile"
    }
} else {
    Write-Host "keystore.properties not found, using defaults..." -ForegroundColor Yellow
    $keystoreFile = Join-Path $PSScriptRoot "app\munqeth.keystore"
    $keyAlias = "munqeth"
}

if (-not (Test-Path $keystoreFile)) {
    Write-Host "ERROR: Keystore file not found: $keystoreFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure the keystore file exists or update keystore.properties" -ForegroundColor Yellow
    exit 1
}

Write-Host "Keystore file: $keystoreFile" -ForegroundColor Green
Write-Host "Key alias: $keyAlias" -ForegroundColor Green
Write-Host ""

# Prompt for keystore password
$securePassword = Read-Host "Enter keystore password" -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

Write-Host ""
Write-Host "Running keytool..." -ForegroundColor Yellow
Write-Host ""

# Run keytool
try {
    $output = & keytool -list -v -keystore "$keystoreFile" -alias "$keyAlias" -storepass "$password" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: keytool failed" -ForegroundColor Red
        Write-Host $output
        exit 1
    }
    
    # Extract SHA-1 and SHA-256
    $sha1 = ""
    $sha256 = ""
    
    foreach ($line in $output) {
        if ($line -match 'SHA1:\s+(.+)') {
            $sha1 = $matches[1].Trim()
        }
        if ($line -match 'SHA256:\s+(.+)') {
            $sha256 = $matches[1].Trim()
        }
    }
    
    if ($sha1 -and $sha256) {
        Write-Host "=== SHA Fingerprints ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "SHA-1:" -ForegroundColor Cyan
        Write-Host $sha1 -ForegroundColor White
        Write-Host ""
        Write-Host "SHA-256:" -ForegroundColor Cyan
        Write-Host $sha256 -ForegroundColor White
        Write-Host ""
        Write-Host "=== Instructions ===" -ForegroundColor Yellow
        Write-Host "1. Go to Firebase Console: https://console.firebase.google.com"
        Write-Host "2. Select your project (munqethnof)"
        Write-Host "3. Go to Project Settings (⚙️ → Project settings)"
        Write-Host "4. In 'Your apps' section, select Android app (com.munqeth.app)"
        Write-Host "5. Click 'Add fingerprint'"
        Write-Host "6. Add SHA-1 fingerprint: $sha1"
        Write-Host "7. Add SHA-256 fingerprint: $sha256"
        Write-Host "8. Save changes"
        Write-Host ""
        Write-Host "=== Copy to Clipboard? (Y/N) ===" -ForegroundColor Yellow
        $copyToClipboard = Read-Host
        if ($copyToClipboard -eq 'Y' -or $copyToClipboard -eq 'y') {
            $clipboardText = "SHA-1:`n$sha1`n`nSHA-256:`n$sha256"
            Set-Clipboard -Value $clipboardText
            Write-Host "Fingerprints copied to clipboard!" -ForegroundColor Green
        }
    } else {
        Write-Host "ERROR: Could not extract SHA fingerprints from keytool output" -ForegroundColor Red
        Write-Host ""
        Write-Host "Keytool output:" -ForegroundColor Yellow
        Write-Host $output
        exit 1
    }
    
} catch {
    Write-Host "ERROR: Failed to run keytool" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
} finally {
    # Clear password from memory
    $password = $null
    $securePassword = $null
}




