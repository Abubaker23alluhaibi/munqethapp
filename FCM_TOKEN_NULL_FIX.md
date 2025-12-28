# 🔧 حل مشكلة FCM Token = null

## المشكلة
FCM token هو `null` بعد تهيئة `NotificationService`. هذا يعني أن Firebase لم يحصل على token.

## الأعراض
```
🐛    fcmToken: null
⛔ ❌ FCM token is still null or empty after initialization
```

## الأسباب المحتملة

### 1. google-services.json غير موجود أو غير صحيح
**التحقق:**
```bash
# تحقق من وجود الملف
ls android/app/google-services.json

# تحقق من محتوى الملف
cat android/app/google-services.json | grep project_id
```

**الحل:**
1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك
3. Project Settings → Your apps → Android app
4. حمّل `google-services.json` جديد
5. ضعه في `android/app/google-services.json`
6. أعد بناء التطبيق

### 2. SHA Fingerprint غير مضاف في Firebase Console
**التحقق:**
```bash
# الحصول على SHA fingerprint
cd android
./gradlew signingReport

# أو
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**الحل:**
1. اذهب إلى Firebase Console
2. Project Settings → Your apps → Android app
3. أضف SHA-1 و SHA-256 fingerprints
4. حمّل `google-services.json` جديد
5. أعد بناء التطبيق

### 3. صلاحيات الإشعارات غير ممنوحة
**التحقق:**
- في إعدادات الجهاز → التطبيقات → المنقذ → الإشعارات
- تأكد من أن الإشعارات مفعلة

**الحل:**
- افتح التطبيق وامنح صلاحيات الإشعارات عند الطلب

### 4. Firebase لم يتم تهيئته بشكل صحيح
**التحقق:**
ابحث في logs عن:
```
Firebase initialized successfully
```

**إذا لم تجدها:**
- تحقق من `google-services.json`
- تحقق من `build.gradle` يحتوي على:
  ```gradle
  apply plugin: 'com.google.gms.google-services'
  ```

## خطوات الحل

### الخطوة 1: التحقق من google-services.json

```bash
# في android/app/
cat google-services.json | grep -A 5 "project_info"
```

يجب أن ترى:
```json
"project_info": {
  "project_number": "...",
  "project_id": "...",
  ...
}
```

### الخطوة 2: التحقق من build.gradle

في `android/app/build.gradle`:
```gradle
dependencies {
  // ...
  implementation platform('com.google.firebase:firebase-bom:32.7.0')
  implementation 'com.google.firebase:firebase-messaging'
}

// في نهاية الملف
apply plugin: 'com.google.gms.google-services'
```

في `android/build.gradle`:
```gradle
dependencies {
  classpath 'com.google.gms:google-services:4.4.0'
}
```

### الخطوة 3: إضافة SHA Fingerprints

```bash
# للحصول على SHA-1
keytool -list -v -keystore android/app/debug.keystore -alias androiddebugkey -storepass android -keypass android

# أو للـ release keystore
keytool -list -v -keystore android/app/your-release-key.keystore -alias your-key-alias
```

ثم أضفها في Firebase Console.

### الخطوة 4: إعادة بناء التطبيق

```bash
# تنظيف
flutter clean

# إعادة بناء
flutter build apk --debug
# أو
flutter build apk --release
```

### الخطوة 5: إعادة تثبيت التطبيق

```bash
# إلغاء التثبيت
adb uninstall com.munqeth.app

# تثبيت جديد
flutter install
```

## التحقق من النجاح

بعد تطبيق الحلول، ابحث في logs عن:

```
✅ FCM Token obtained: ...
✅ FCM Token saved successfully: ...
```

## حل بديل: استخدام Token محفوظ

إذا استمرت المشكلة، يمكن استخدام token محفوظ مسبقاً:

```dart
// في notification_service.dart
final savedToken = await SecureStorageService.getString('fcm_token');
if (savedToken != null && savedToken.isNotEmpty) {
  _fcmToken = savedToken;
  AppLogger.w('Using saved FCM token');
}
```

## ملخص

| المشكلة | السبب | الحل |
|---------|-------|------|
| FCM token = null | google-services.json مفقود | حمّل من Firebase Console |
| FCM token = null | SHA fingerprint غير مضاف | أضف في Firebase Console |
| FCM token = null | صلاحيات غير ممنوحة | امنح صلاحيات الإشعارات |
| FCM token = null | Firebase غير مهيأ | تحقق من build.gradle |

---

**ملاحظة:** بعد كل تغيير، يجب إعادة بناء التطبيق بالكامل (`flutter clean` ثم `flutter build`).




