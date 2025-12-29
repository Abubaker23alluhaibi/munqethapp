# Script to remove all print() statements from Dart files
# This script removes print statements but keeps the code structure

$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Remove print statements (single line)
    $content = $content -replace '(?m)^\s*print\([^)]*\);\s*\r?\n', ''
    
    # Remove print statements with multiline strings (basic)
    $content = $content -replace '(?m)^\s*print\([^)]*\);\s*\r?\n', ''
    
    # Remove print statements that span multiple lines (more complex)
    $content = $content -replace '(?s)print\s*\([^)]*\)\s*;', ''
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Cleaned: $($file.FullName)"
    }
}

Write-Host "Done cleaning print statements!"

