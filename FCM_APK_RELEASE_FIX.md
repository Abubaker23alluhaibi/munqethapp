# 🔧 حل مشكلة FCM في APK Release

## المشكلة
عند بناء التطبيق كـ APK Release، الإشعارات لا تصل (FCM tokens غير مسجلة). بينما تعمل بشكل طبيعي في Debug builds.

**الخطأ:**
```
messaging/registration-token-not-registered
Requested entity was not found.
```

## السبب
Firebase Cloud Messaging يحتاج إلى SHA-1 و SHA-256 fingerprints من **release keystore** لتحديد هوية التطبيق. عندما تبني APK release، يستخدم keystore مختلف عن debug keystore، و Firebase لا يعرف هذا الـ keystore.

## الحل

### الخطوة 1: الحصول على SHA-1 و SHA-256 من Release Keystore

#### على Windows (PowerShell):
```powershell
cd android/app
keytool -list -v -keystore munqeth.keystore -alias munqeth
```

أو إذا كان keystore في مكان آخر:
```powershell
keytool -list -v -keystore "path\to\munqeth.keystore" -alias munqeth
```

**عند المطالبة بكلمة المرور، أدخل كلمة مرور keystore** (من `keystore.properties`).

#### على macOS/Linux:
```bash
cd android/app
keytool -list -v -keystore munqeth.keystore -alias munqeth
```

**ستحصل على مخرجات مثل:**
```
Alias name: munqeth
Creation date: ...
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: ...
Issuer: ...
Serial number: ...
Valid from: ... until: ...
Certificate fingerprints:
         SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
         SHA256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
Signature algorithm name: SHA256withRSA
...
```

**انسخ SHA1 و SHA256 fingerprints** (الأرقام التي تكون بعد SHA1: و SHA256:).

### الخطوة 2: إضافة SHA Fingerprints في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك (`munqethnof`)
3. اذهب إلى **Project Settings** (⚙️ → Project settings)
4. في تبويب **General**، ابحث عن قسم **Your apps**
5. اختر تطبيق Android (`com.munqeth.app`)
6. اضغط على **"Add fingerprint"** أو **"SHA certificate fingerprints"**
7. أضف **SHA-1 fingerprint** (انسخ الصف الذي يبدأ بـ SHA1:)
8. أضف **SHA-256 fingerprint** (انسخ الصف الذي يبدأ بـ SHA256:)
9. احفظ التغييرات

**مهم:** 
- تأكد من نسخ الـ fingerprints بشكل صحيح (بدون مسافات إضافية)
- SHA-1 و SHA-256 كلاهما مطلوبان
- لا تنسى إضافة كلا الـ fingerprints

### الخطوة 3: تنزيل google-services.json الجديد (اختياري)

بعد إضافة الـ fingerprints، قد تحتاج إلى:
1. تنزيل `google-services.json` الجديد من Firebase Console
2. استبدال الملف الموجود في `android/app/google-services.json`

**ملاحظة:** عادة لا حاجة لتنزيل ملف جديد إذا لم يتغير project_id أو package_name.

### الخطوة 4: بناء APK Release جديد

```bash
flutter clean
flutter pub get
flutter build apk --release
```

أو لبناء APK App Bundle (لنشره في Google Play):
```bash
flutter build appbundle --release
```

### الخطوة 5: اختبار الإشعارات

1. ثبت APK على جهاز
2. سجل الدخول
3. اختبر إنشاء طلب
4. تأكد من وصول الإشعارات

## التحقق من الإعداد

### التحقق من SHA Fingerprints في Firebase Console:
1. Firebase Console → Project Settings → Your apps → Android app
2. تأكد من وجود SHA-1 و SHA-256 fingerprints المضافة

### التحقق من google-services.json:
تأكد من وجود الملف في `android/app/google-services.json` وأنه يحتوي على:
- `project_id`: munqethnof
- `package_name`: com.munqeth.app

## حلول إضافية

### 1. إذا استمرت المشكلة - تحقق من package name
تأكد من أن `package_name` في:
- `android/app/build.gradle` (applicationId)
- `google-services.json`
- Firebase Console

كلها تطابق: `com.munqeth.app`

### 2. تنظيف البناء
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### 3. التحقق من Logcat
عند تشغيل التطبيق، تحقق من Logcat للأخطاء:
```bash
adb logcat | grep -i firebase
```

ابحث عن:
- أخطاء في تهيئة Firebase
- أخطاء في الحصول على FCM token
- رسائل مثل "FirebaseApp initialization successful"

## ملاحظات مهمة

1. **Debug vs Release Keystore:**
   - Debug builds تستخدم debug keystore (يتم إنشاؤه تلقائياً)
   - Release builds تستخدم release keystore (`munqeth.keystore`)
   - **يجب إضافة SHA fingerprints لكلا الـ keystores في Firebase Console**

2. **Google Play App Signing:**
   - إذا كنت تستخدم Google Play App Signing، قد تحتاج إلى إضافة SHA-256 من Google Play Console أيضاً
   - Google Play Console → Your app → Release → Setup → App signing
   - انسخ SHA-256 certificate fingerprint وأضفه في Firebase Console

3. **تحديث Token تلقائياً:**
   - التطبيق يستمع لتحديثات FCM token تلقائياً (`onTokenRefresh`)
   - عند تغيير الـ keystore أو تحديث Firebase settings، قد يحتاج المستخدم لإعادة تسجيل الدخول

## الدعم

إذا استمرت المشكلة بعد اتباع هذه الخطوات:
1. تحقق من Logcat للأخطاء
2. تأكد من صحة SHA fingerprints المضافة
3. تأكد من تطابق package name في جميع الأماكن
4. جرب إعادة تثبيت التطبيق بعد تحديث Firebase settings




