# 🔐 إعداد ملفات الأسرار (Secrets)

## ملف secrets.xml

قبل بناء التطبيق، يجب إنشاء ملف `secrets.xml` الذي يحتوي على Google Maps API Key.

### الخطوات:

1. **أنشئ ملف `secrets.xml`** في المسار التالي:
   ```
   android/app/src/main/res/values/secrets.xml
   ```

2. **انسخ المحتوى التالي** وضع مفتاح Google Maps API Key الحقيقي:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Google Maps API Key -->
    <!-- ⚠️ هذا ملف حساس - لا ترفعه إلى Git -->
    <!-- ⚠️ تأكد من إضافة secrets.xml إلى .gitignore (تم بالفعل) -->
    <string name="google_maps_api_key">YOUR_GOOGLE_MAPS_API_KEY_HERE</string>
</resources>
```

3. **استبدل `YOUR_GOOGLE_MAPS_API_KEY_HERE`** بمفتاح Google Maps API Key الحقيقي.

### الحصول على Google Maps API Key:

1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
2. أنشئ أو اختر مشروع
3. فعّل **Maps SDK for Android**
4. اذهب إلى **Credentials** → **Create Credentials** → **API Key**
5. قيد API Key بـ package name: `com.munqeth.app`
6. انسخ المفتاح وضعّه في ملف `secrets.xml`

### ⚠️ ملاحظات مهمة:

- ✅ ملف `secrets.xml` موجود في `.gitignore` ولن يُرفع إلى Git
- ✅ لا تشارك هذا الملف مع أي شخص
- ✅ استخدم نفس المفتاح في جميع بيئات التطوير والبناء

## التحقق:

بعد إنشاء الملف، تأكد من أن البناء يعمل:

```bash
cd munqeth
flutter build apk --debug
```

إذا ظهرت رسالة خطأ تفيد بأن `google_maps_api_key` غير موجود، تأكد من:
- الملف موجود في المسار الصحيح
- اسم المفتاح صحيح: `google_maps_api_key`
- الملف بصيغة XML صحيحة







