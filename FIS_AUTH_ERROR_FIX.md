# 🔴 حل مشكلة FIS_AUTH_ERROR

## المشكلة
```
E/FirebaseMessaging: Failed to get FIS auth token
E/FirebaseMessaging: java.util.concurrent.ExecutionException: 
com.google.firebase.installations.FirebaseInstallationsException: 
Firebase Installations Service is unavailable. Please try again later.
```

## السبب
`FIS_AUTH_ERROR` يعني أن Firebase Installations Service لا يمكنه المصادقة. هذا يحدث عادة عندما:

1. **SHA fingerprints غير موجودة أو غير صحيحة** في Firebase Console
2. **google-services.json غير صحيح** أو غير موجود
3. **Package name mismatch** - package name في Firebase Console لا يطابق التطبيق
4. **Firebase project configuration غير صحيح**

## الحل

### الخطوة 1: التحقق من SHA Fingerprints في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك: **munqethnof**
3. Project Settings → Your apps → Android app (com.munqeth.app)
4. تحقق من **SHA certificate fingerprints**:
   - ✅ SHA-1: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`
   - ✅ SHA-256: `da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80`

**إذا كانت غير موجودة:**
- أضفها من Firebase Console
- حمّل `google-services.json` جديد
- استبدل الملف في `android/app/google-services.json`

### الخطوة 2: التحقق من google-services.json

```bash
# تحقق من وجود الملف
cat android/app/google-services.json | grep project_id

# يجب أن ترى:
# "project_id": "munqethnof"
```

**إذا كان الملف غير موجود أو غير صحيح:**
1. اذهب إلى Firebase Console
2. Project Settings → Your apps → Android app
3. اضغط على **"Download google-services.json"**
4. استبدل الملف في `android/app/google-services.json`

### الخطوة 3: التحقق من Package Name

تأكد من أن package name مطابق في جميع الأماكن:

- ✅ Firebase Console: `com.munqeth.app`
- ✅ `android/app/build.gradle`: `applicationId "com.munqeth.app"`
- ✅ `google-services.json`: `"package_name": "com.munqeth.app"`

### الخطوة 4: تنظيف وإعادة بناء التطبيق

```bash
# تنظيف كامل
flutter clean
cd android
./gradlew clean
cd ..

# إعادة الحصول على dependencies
flutter pub get

# بناء APK جديد
flutter build apk --release
```

### الخطوة 5: إعادة تثبيت التطبيق

```bash
# إلغاء تثبيت التطبيق القديم
adb uninstall com.munqeth.app

# تثبيت APK الجديد
adb install build/app/outputs/flutter-apk/app-release.apk
```

## التحقق من الحل

بعد تطبيق الحلول، ابحث في logs عن:

```
✅ Firebase initialized successfully
✅ FCM token obtained: ...
✅ FCM Token saved successfully: ...
```

**إذا استمر الخطأ:**
1. تحقق من SHA fingerprints مرة أخرى
2. تأكد من أن `google-services.json` صحيح
3. تحقق من package name
4. جرب إعادة بناء التطبيق بالكامل

## ملاحظات مهمة

1. **Debug vs Release:**
   - Debug builds تستخدم debug keystore
   - Release builds تستخدم release keystore (`munqeth.keystore`)
   - **يجب إضافة SHA fingerprints لكلا الـ keystores**

2. **Google Play App Signing:**
   - إذا كنت تستخدم Google Play App Signing، قد تحتاج إلى إضافة SHA-256 من Google Play Console أيضاً

3. **Network Connectivity:**
   - تأكد من أن الجهاز متصل بالإنترنت
   - Firebase يحتاج إلى اتصال بالإنترنت للحصول على FCM token

---

**✅ بعد إصلاح SHA fingerprints و google-services.json، يجب أن يعمل FCM token بشكل صحيح!**

