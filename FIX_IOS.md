# إصلاح ملفات iOS المفقودة
# Fix Missing iOS Files

## المشكلة
ملف `ios/Runner.xcodeproj/project.pbxproj` مفقود

## الحل على macOS

### الطريقة 1: إعادة إنشاء ملفات iOS (الأسهل)

```bash
cd /path/to/munqeth
flutter create --platforms=ios .
```

### الطريقة 2: نسخ من مشروع جديد

```bash
# إنشاء مشروع مؤقت
cd /tmp
flutter create test_project
cd test_project

# نسخ ملفات xcodeproj
cp -R ios/Runner.xcodeproj/* /path/to/munqeth/ios/Runner.xcodeproj/

# تنظيف
cd /tmp
rm -rf test_project
```

### الطريقة 3: استخدام Codemagic

تم إنشاء ملف `codemagic.yaml` الذي سيقوم بإعادة إنشاء ملفات iOS تلقائياً.

## بعد الإصلاح

1. تأكد من أن `ios/Runner.xcodeproj/project.pbxproj` موجود
2. شغل `pod install` في مجلد `ios/`
3. ارفع التغييرات إلى Git
4. جرب البناء على Codemagic مرة أخرى

