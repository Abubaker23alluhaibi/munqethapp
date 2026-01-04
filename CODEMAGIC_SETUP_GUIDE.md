# دليل إعداد Codemagic لبناء iOS
# Codemagic Setup Guide for iOS Build

## الإعدادات المطلوبة في Codemagic

### 1. Build for platforms (منصات البناء)
✅ **اختر: iOS فقط**
- قم بتفعيل iOS فقط
- لا تفعل Android أو Web أو غيرها (إلا إذا كنت تريد بناءها أيضاً)

### 2. Run tests only (تشغيل الاختبارات فقط)
❌ **اتركه غير مفعّل**
- أنت تريد بناء التطبيق، ليس فقط تشغيل الاختبارات

### 3. Publish updates to user devices using Shorebird
❌ **اتركه Disabled**
- هذا لـ OTA updates، غير مطلوب الآن

### 4. Release / Patch
✅ **اختر: Release**
- Release للبناء النهائي للإنتاج
- Patch فقط للترقيعات الصغيرة

### 5. Run build on (نوع الجهاز)
✅ **اختر: macOS M2**
- Mac mini M2 / 8-Core CPU / 8GB
- هذا ضروري لبناء iOS (iOS يحتاج macOS)

### 6. Build triggers (مشغلات البناء)
**الإعدادات الموصى بها:**
- ✅ Push to branch: `main` (أو `master`)
- ✅ Pull request: مفعّل (اختياري)
- ❌ Scheduled builds: غير مفعّل (إلا إذا كنت تريد builds تلقائية)

### 7. Environment variables (متغيرات البيئة)
**غير مطلوب الآن** - يمكنك إضافتها لاحقاً إذا احتجت:
- API keys
- Secrets
- إلخ

### 8. Dependency caching (تخزين التبعيات)
✅ **فعّله**
- يساعد في تسريع البناء
- يحفظ الوقت في الـ builds القادمة

### 9. Tests (الاختبارات)
**اختياري:**
- إذا كان لديك tests، فعّلها
- إذا لم يكن لديك، اتركها غير مفعّلة

### 10. Build (البناء)
**يجب أن يكون:**
- ✅ Use codemagic.yaml: **مفعّل**
- هذا يستخدم ملف `codemagic.yaml` الذي أنشأناه

### 11. Distribution (التوزيع)
**الإعدادات:**
- ✅ Email: **مفعّل**
  - Email: `bake16t@gmail.com`
- ❌ App Store Connect: غير مفعّل (إلا إذا كنت تريد الرفع التلقائي)
- ❌ TestFlight: غير مفعّل (إلا إذا كنت تريد الرفع التلقائي)

### 12. Notifications (الإشعارات)
✅ **فعّل:**
- ✅ Email notifications: **مفعّل**
- ✅ Build status: Success + Failure

## ملخص الإعدادات الموصى بها:

```
✅ Build for platforms: iOS فقط
❌ Run tests only: غير مفعّل
❌ Shorebird: Disabled
✅ Release: Release
✅ Run build on: macOS M2
✅ Build triggers: Push to main
✅ Dependency caching: مفعّل
✅ Use codemagic.yaml: مفعّل
✅ Email distribution: مفعّل (bake16t@gmail.com)
✅ Notifications: مفعّل
```

## بعد الإعداد:

1. **احفظ الإعدادات**
2. **اضغط "Start new build"**
3. **اختر Branch: `main` (أو `master`)**
4. **اضغط "Start build"**

## ملاحظات مهمة:

- تأكد من أن ملف `codemagic.yaml` موجود في جذر المشروع
- تأكد من رفع جميع ملفات iOS إلى Git (project.pbxproj, scheme, إلخ)
- بعد البناء الناجح، سيتم إرسال ملف IPA إلى بريدك

## إذا واجهت مشاكل:

1. تحقق من logs في Codemagic
2. تأكد من أن جميع الملفات موجودة في Git
3. تحقق من أن `codemagic.yaml` صحيح

