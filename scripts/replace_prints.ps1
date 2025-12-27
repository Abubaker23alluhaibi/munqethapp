# Script to replace print statements with AppLogger
# Usage: .\scripts\replace_prints.ps1

$files = @(
    "lib/services/supermarket_service.dart",
    "lib/services/user_service.dart",
    "lib/services/product_service.dart",
    "lib/services/driver_service.dart",
    "lib/services/notification_service.dart",
    "lib/services/card_service.dart",
    "lib/services/advertisement_service.dart"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Processing $file..."
        $content = Get-Content $file -Raw
        
        # Add import if not exists
        if ($content -notmatch "import.*app_logger") {
            $content = $content -replace "(import.*errors.*app_exception\.dart';)", "`$1`nimport '../core/utils/app_logger.dart';"
        }
        
        # Replace print statements
        $content = $content -replace "print\('Error ([^']+)': \$e\);", "AppLogger.e('Error `$1', e);"
        $content = $content -replace "print\('([^']+)': \$e\);", "AppLogger.e('`$1', e);"
        $content = $content -replace "print\('✅ ([^']+)'\);", "AppLogger.i('`$1');"
        $content = $content -replace "print\('⚠️ ([^']+)'\);", "AppLogger.w('`$1');"
        $content = $content -replace "print\('❌ ([^']+)'\);", "AppLogger.e('`$1');"
        $content = $content -replace "print\('🔄 ([^']+)'\);", "AppLogger.d('`$1');"
        $content = $content -replace "print\('📋 ([^']+)'\);", "AppLogger.d('`$1');"
        $content = $content -replace "print\('📤 ([^']+)'\);", "AppLogger.d('`$1');"
        $content = $content -replace "print\('([^']+)': \$e\);", "AppLogger.e('`$1', e);"
        $content = $content -replace "print\('([^']+)'\);", "AppLogger.d('`$1');"
        
        Set-Content $file $content
        Write-Host "✅ Updated $file"
    } else {
        Write-Host "⚠️ File not found: $file"
    }
}

Write-Host "`n✅ Done! Please review the changes before committing."


