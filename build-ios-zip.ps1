# ============================================
# Script to create ZIP file from iOS files
# ============================================

param(
    [string]$OutputPath = ""
)

# Set encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create iOS ZIP file" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory and navigate to project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
Set-Location $ProjectRoot

Write-Host "Current directory: $ProjectRoot" -ForegroundColor Yellow
Write-Host ""

# Check if iOS directory exists
$iosPath = Join-Path $ProjectRoot "ios"
if (-not (Test-Path $iosPath)) {
    Write-Host "Error: iOS directory not found!" -ForegroundColor Red
    exit 1
}

# Generate output filename with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ($OutputPath -eq "") {
    $OutputPath = Join-Path $ProjectRoot "munqeth-ios-$timestamp.zip"
}

Write-Host "Creating ZIP file..." -ForegroundColor Yellow
Write-Host ""

# Create temporary directory for iOS files
$tempDir = Join-Path $env:TEMP "ios-zip-$timestamp"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Copy important iOS files
    Write-Host "Copying iOS files..." -ForegroundColor Yellow
    
    # Copy entire ios directory structure
    $iosTemp = Join-Path $tempDir "ios"
    Copy-Item -Path $iosPath -Destination $iosTemp -Recurse -Force
    
    # Remove unnecessary files/folders
    $removePaths = @(
        "ios\Flutter\ephemeral",
        "ios\build",
        "ios\Pods",
        "ios\.symlinks",
        "ios\Podfile.lock",
        "ios\DerivedData"
    )
    
    foreach ($removePath in $removePaths) {
        $fullPath = Join-Path $tempDir $removePath
        if (Test-Path $fullPath) {
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed: $removePath" -ForegroundColor Gray
        }
    }
    
    # Add build instructions file
    $instructionsPath = Join-Path $tempDir "BUILD_INSTRUCTIONS.txt"
    $instructions = "========================================`r`n" +
    "iOS Build Instructions`r`n" +
    "========================================`r`n`r`n" +
    "IMPORTANT NOTE:`r`n" +
    "iOS builds require macOS and Xcode`r`n`r`n" +
    "========================================`r`n" +
    "Required Steps:`r`n" +
    "========================================`r`n`r`n" +
    "1. Open Terminal on macOS`r`n`r`n" +
    "2. Navigate to project directory`r`n" +
    "   cd /path/to/munqeth`r`n`r`n" +
    "3. Install CocoaPods dependencies`r`n" +
    "   cd ios`r`n" +
    "   pod install`r`n" +
    "   cd ..`r`n`r`n" +
    "4. Build iOS`r`n`r`n" +
    "   For Simulator:`r`n" +
    "   flutter build ios --simulator --release`r`n`r`n" +
    "   For Device:`r`n" +
    "   flutter build ios --release`r`n`r`n" +
    "5. To upload to App Store:`r`n`r`n" +
    "   - Open Xcode`r`n" +
    "   - Open ios/Runner.xcworkspace`r`n" +
    "   - Product > Archive`r`n" +
    "   - Distribute App > App Store Connect`r`n" +
    "   - Follow instructions`r`n`r`n" +
    "========================================`r`n" +
    "Requirements:`r`n" +
    "========================================`r`n`r`n" +
    "- macOS (Mac or MacBook)`r`n" +
    "- Xcode (latest version)`r`n" +
    "- CocoaPods (sudo gem install cocoapods)`r`n" +
    "- Apple Developer Account (for App Store upload)`r`n" +
    "- Flutter SDK`r`n`r`n" +
    "========================================`r`n" +
    "Project Information:`r`n" +
    "========================================`r`n`r`n" +
    "- App Name: munqeth`r`n" +
    "- Bundle ID: com.munqeth.app (verify in Xcode)`r`n" +
    "- Version: 1.0.0+1`r`n`r`n" +
    "========================================"
    
    Set-Content -Path $instructionsPath -Value $instructions -Encoding UTF8
    Write-Host "Created instructions file" -ForegroundColor Green
    
    # Create ZIP file
    Write-Host ""
    Write-Host "Compressing files..." -ForegroundColor Yellow
    
    if (Test-Path $OutputPath) {
        Remove-Item -Path $OutputPath -Force
    }
    
    Compress-Archive -Path "$tempDir\*" -DestinationPath $OutputPath -Force
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "ZIP file created successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Display file information
    $zipInfo = Get-Item $OutputPath
    $fileSizeMB = [math]::Round($zipInfo.Length / 1MB, 2)
    $fileSizeKB = [math]::Round($zipInfo.Length / 1KB, 2)
    
    Write-Host "File Information:" -ForegroundColor Cyan
    Write-Host "   Path: $OutputPath" -ForegroundColor White
    $sizeMBText = "$fileSizeMB MB"
    $sizeKBText = "$fileSizeKB KB"
    Write-Host "   Size: $sizeMBText ($sizeKBText)" -ForegroundColor White
    Write-Host "   Created: $($zipInfo.CreationTime)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Note: This file contains iOS source files" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To build on macOS:" -ForegroundColor Cyan
    Write-Host "1. Extract ZIP file on macOS" -ForegroundColor White
    Write-Host "2. Follow instructions in BUILD_INSTRUCTIONS.txt" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "Error creating ZIP file:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    # Cleanup temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
