# سكريبت تنظيف وإعادة بناء المشروع
Write-Host "🧹 تنظيف المشروع..." -ForegroundColor Yellow

# تنظيف Flutter
Write-Host "  - تنظيف Flutter cache..." -ForegroundColor Cyan
flutter clean

# حذف مجلدات build
Write-Host "  - حذف مجلدات build..." -ForegroundColor Cyan
if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path "android\build") { Remove-Item -Path "android\build" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path "android\.gradle") { Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path "android\app\build") { Remove-Item -Path "android\app\build" -Recurse -Force -ErrorAction SilentlyContinue }

# تنظيف .dart_tool (سيتم إعادة إنشاؤه)
Write-Host "  - تنظيف .dart_tool..." -ForegroundColor Cyan
if (Test-Path ".dart_tool") { Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue }

# إعادة تحميل الحزم
Write-Host "📦 إعادة تحميل الحزم..." -ForegroundColor Yellow
flutter pub get

Write-Host "✅ اكتمل التنظيف!" -ForegroundColor Green
Write-Host ""
Write-Host "يمكنك الآن تشغيل:" -ForegroundColor Cyan
Write-Host "  flutter run" -ForegroundColor White




