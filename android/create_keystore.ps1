# Script to create keystore non-interactively
# Usage: .\create_keystore.ps1

$keystorePath = "app\munqeth.keystore"
$alias = "munqeth"
$validity = 10000

# Backup old keystore if exists
if (Test-Path $keystorePath) {
    $backupPath = "$keystorePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $keystorePath $backupPath
    Write-Host "Backed up old keystore to: $backupPath"
}

# Prompt for passwords
Write-Host "`n=== Creating Keystore ===" -ForegroundColor Cyan
Write-Host "You will be asked for keystore password and key password."
Write-Host "Use the SAME password for both (recommended) or different passwords."
Write-Host "Remember these passwords - you'll need them for building the app!`n" -ForegroundColor Yellow

# Create keystore with non-interactive mode
# Using -dname to avoid interactive prompts
$dname = "CN=munqeth, OU=Development, O=munqeth, L=Baghdad, ST=Baghdad, C=IQ"

Write-Host "Creating keystore..." -ForegroundColor Green
Write-Host "Keystore path: $keystorePath"
Write-Host "Alias: $alias"
Write-Host "Validity: $validity days`n"

# Run keytool command
$keytoolArgs = @(
    "-genkey",
    "-v",
    "-keystore", $keystorePath,
    "-alias", $alias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", $validity.ToString(),
    "-dname", $dname,
    "-storepass", "changeit",
    "-keypass", "changeit"
)

try {
    & keytool $keytoolArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Keystore created successfully!" -ForegroundColor Green
        Write-Host "`n⚠️  IMPORTANT: Default passwords are 'changeit'" -ForegroundColor Yellow
        Write-Host "Update android/keystore.properties with:" -ForegroundColor Yellow
        Write-Host "  storePassword=changeit"
        Write-Host "  keyPassword=changeit`n"
    } else {
        Write-Host "`n❌ Failed to create keystore" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}

