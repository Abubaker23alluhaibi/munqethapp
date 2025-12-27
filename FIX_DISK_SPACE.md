# 🔧 حل مشكلة نفاد مساحة القرص

## المشكلة
```
OS Error: There is not enough space on the disk, errno = 112
```

القرص الصلب C: ممتلئ ولا يمكن لـ Flutter إنشاء ملفات مؤقتة.

## حلول سريعة

### 1. تنظيف Flutter Cache
```powershell
cd munqeth
flutter clean
flutter pub cache clean
```

### 2. تنظيف مجلد Temp
```powershell
# تنظيف مجلد Flutter Temp
Remove-Item -Path "$env:LOCALAPPDATA\Temp\flutter_tools.*" -Recurse -Force -ErrorAction SilentlyContinue

# تنظيف مجلد Temp العام (احذر: سيحذف جميع الملفات المؤقتة)
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
```

### 3. تنظيف Build Folders
```powershell
cd munqeth
# حذف مجلد build
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\app\build" -Recurse -Force -ErrorAction SilentlyContinue
```

### 4. تنظيف Flutter Pub Cache (اختياري - سيحتاج إعادة تحميل الحزم)
```powershell
flutter pub cache repair
```

### 5. استخدام Disk Cleanup
1. اضغط `Windows + R`
2. اكتب `cleanmgr` واضغط Enter
3. اختر القرص C:
4. حدد جميع الخيارات واضغط OK

### 6. تنظيف Windows Update Files
```powershell
# تشغيل كـ Administrator
Stop-Service -Name wuauserv -Force
Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv
```

## تحقق من المساحة
```powershell
Get-PSDrive C | Select-Object Used,Free,@{Name="UsedPercent";Expression={[math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 2)}}
```

## بعد تنظيف المساحة

1. أعد تشغيل التطبيق:
```powershell
cd munqeth
flutter run
```

2. أو قم ببناء APK مباشرة:
```powershell
flutter build apk --release
```

## نصائح لمنع المشكلة مستقبلاً

1. **حذف ملفات Build القديمة** بشكل دوري
2. **استخدام Disk Cleanup** أسبوعياً
3. **نقل مجلد المشروع** إلى قرص آخر (D:, E:) إذا كان ممكناً
4. **إيقاف التطبيق** بعد الانتهاء من التطوير لتوفير مساحة

## حجم تقريبي لمساحة مطلوبة

- Flutter SDK: ~2 GB
- Android SDK: ~5-10 GB
- Build files: ~1-2 GB لكل مشروع
- Pub cache: ~500 MB - 1 GB
- Temp files: متغير

**الحد الأدنى المطلوب: 10 GB مساحة فارغة على C:**

