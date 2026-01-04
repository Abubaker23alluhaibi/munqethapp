# Script to check iOS files in Git

Write-Host "=== Checking iOS files in Git ===" -ForegroundColor Cyan
Write-Host ""

$files = @(
    "ios/Runner.xcodeproj/project.pbxproj",
    "ios/Podfile",
    "ios/Runner/Info.plist",
    "ios/Runner/AppDelegate.swift"
)

$allExist = $true

foreach ($file in $files) {
    $gitCheck = git ls-files $file
    $inGit = $gitCheck -ne $null -and $gitCheck.Length -gt 0
    $exists = Test-Path $file
    
    if ($inGit -and $exists) {
        Write-Host "[OK] $file - In Git and locally" -ForegroundColor Green
    }
    elseif ($exists -and -not $inGit) {
        Write-Host "[WARNING] $file - Exists locally but NOT in Git" -ForegroundColor Yellow
        Write-Host "  Add it: git add $file" -ForegroundColor Yellow
        $allExist = $false
    }
    elseif ($inGit -and -not $exists) {
        Write-Host "[WARNING] $file - In Git but NOT locally" -ForegroundColor Yellow
    }
    else {
        Write-Host "[ERROR] $file - NOT FOUND" -ForegroundColor Red
        $allExist = $false
    }
}

Write-Host ""
if ($allExist) {
    Write-Host "[SUCCESS] All files are in Git!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Make sure changes are pushed: git push" -ForegroundColor Cyan
    Write-Host "2. Run new Build on Codemagic" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Some files are missing from Git" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To add files:" -ForegroundColor Cyan
    Write-Host "git add ios/" -ForegroundColor Cyan
    Write-Host "git commit -m 'Add iOS project files'" -ForegroundColor Cyan
    Write-Host "git push" -ForegroundColor Cyan
}
