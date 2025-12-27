# سكريبت لتحديث API Base URL في Flutter App
# استخدم: .\update_api_url.ps1

Write-Host "🔍 جاري البحث عن IP address..." -ForegroundColor Cyan

# الحصول على IP address
$ipAddress = $null
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }

if ($adapters) {
    $ipAddress = $adapters[0].IPAddress
    Write-Host "✅ تم العثور على IP address: $ipAddress" -ForegroundColor Green
} else {
    Write-Host "❌ لم يتم العثور على IP address" -ForegroundColor Red
    exit 1
}

# قراءة ملف constants.dart
$constantsFile = "lib\utils\constants.dart"
if (-not (Test-Path $constantsFile)) {
    Write-Host "❌ لم يتم العثور على ملف constants.dart" -ForegroundColor Red
    exit 1
}

$content = Get-Content $constantsFile -Raw

# تحديث baseUrl
$newBaseUrl = "http://$ipAddress:3000/api"
$pattern = "static const String baseUrl = 'http://[^']+';"

if ($content -match $pattern) {
    $content = $content -replace $pattern, "static const String baseUrl = '$newBaseUrl';"
    
    Set-Content -Path $constantsFile -Value $content -NoNewline
    
    Write-Host "✅ تم تحديث baseUrl إلى: $newBaseUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 الخطوات التالية:" -ForegroundColor Yellow
    Write-Host "   1. تأكد من تشغيل السيرفر: cd backend && npm start" -ForegroundColor White
    Write-Host "   2. تأكد من أن الهاتف والكمبيوتر على نفس الشبكة" -ForegroundColor White
    Write-Host "   3. اختبر الاتصال: http://$ipAddress:3000/api/health" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ لم يتم العثور على baseUrl في الملف" -ForegroundColor Red
    Write-Host "   يرجى تحديث الملف يدوياً:" -ForegroundColor Yellow
    Write-Host "   static const String baseUrl = '$newBaseUrl';" -ForegroundColor White
}






