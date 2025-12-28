# 🔧 حل مشكلة الإشعارات في Release APK

## المشكلة
الإشعارات تعمل في **Debug mode** (عند الربط بـ USB) لكن **لا تعمل في Release APK**.

## السبب
Firebase Cloud Messaging يحتاج إلى SHA fingerprints من **release keystore** لتحديد هوية التطبيق. عندما تبني APK release، يستخدم keystore مختلف عن debug keystore.

- ✅ **Debug builds** تستخدم `debug.keystore` (SHA fingerprints موجودة في Firebase)
- ❌ **Release builds** تستخدم `munqeth.keystore` (SHA fingerprints **غير موجودة** في Firebase)

## الحل

### الخطوة 1: الحصول على SHA Fingerprints من Release Keystore

#### على Windows (PowerShell):
```powershell
cd android/app
keytool -list -v -keystore munqeth.keystore -alias munqeth -storepass munqeth2024
```

**ستحصل على مخرجات مثل:**
```
Certificate fingerprints:
         SHA1: FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD
         SHA256: DA:79:D0:59:45:C0:2A:3C:DC:58:DD:42:49:4E:EF:EC:86:65:9E:CD:67:FA:1A:35:E6:23:82:D4:79:99:3A:80
```

**انسخ SHA-1 و SHA-256** (الأرقام الكاملة).

### الخطوة 2: إضافة SHA Fingerprints في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك: **munqethnof**
3. اذهب إلى **Project Settings** (⚙️ → Project settings)
4. في قسم **Your apps**، اختر تطبيق Android: **com.munqeth.app**
5. ابحث عن قسم **SHA certificate fingerprints**
6. اضغط على **"Add fingerprint"** أو **"Add SHA certificate fingerprint"**

#### أضف SHA-1:
```
FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD
```

#### أضف SHA-256:
```
DA:79:D0:59:45:C0:2A:3C:DC:58:DD:42:49:4E:EF:EC:86:65:9E:CD:67:FA:1A:35:E6:23:82:D4:79:99:3A:80
```

**مهم:**
- ✅ تأكد من نسخ الـ fingerprints بشكل صحيح (بدون مسافات إضافية)
- ✅ SHA-1 و SHA-256 **كلاهما مطلوبان**
- ✅ لا تنسى إضافة **كلا الـ fingerprints**

### الخطوة 3: تحميل google-services.json الجديد (اختياري)

بعد إضافة SHA fingerprints:
1. في Firebase Console → Project Settings → Your apps → Android app
2. اضغط على **"Download google-services.json"**
3. استبدل الملف الموجود في `android/app/google-services.json`

**ملاحظة:** عادة لا حاجة لتنزيل ملف جديد إذا لم يتغير `project_id` أو `package_name`.

### الخطوة 4: بناء APK Release جديد

```bash
# تنظيف
flutter clean
flutter pub get

# بناء APK Release
flutter build apk --release
```

أو لبناء APK App Bundle (لنشره في Google Play):
```bash
flutter build appbundle --release
```

### الخطوة 5: اختبار الإشعارات

1. **احذف التطبيق القديم** من الجهاز (إن كان مثبتاً)
2. **ثبت APK الجديد** على الجهاز
3. **سجل الدخول** في التطبيق
4. **أنشئ طلب** (taxi, delivery, etc.)
5. **تأكد من وصول الإشعارات**

## التحقق من الإعداد

### التحقق من SHA Fingerprints في Firebase Console:

1. Firebase Console → Project Settings → Your apps → Android app
2. تأكد من وجود **SHA-1** و **SHA-256** fingerprints المضافة
3. يجب أن ترى:
   - ✅ SHA-1: `FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD`
   - ✅ SHA-256: `DA:79:D0:59:45:C0:2A:3C:DC:58:DD:42:49:4E:EF:EC:86:65:9E:CD:67:FA:1A:35:E6:23:82:D4:79:99:3A:80`

### التحقق من google-services.json:

تأكد من وجود الملف في `android/app/google-services.json` وأنه يحتوي على:
- `project_id`: `munqethnof`
- `package_name`: `com.munqeth.app`

## ملخص SHA Fingerprints المطلوبة

| Type | Value | Status |
|------|-------|--------|
| **SHA-1 (Release)** | `FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD` | ✅ يجب إضافتها |
| **SHA-256 (Release)** | `DA:79:D0:59:45:C0:2A:3C:DC:58:DD:42:49:4E:EF:EC:86:65:9E:CD:67:FA:1A:35:E6:23:82:D4:79:99:3A:80` | ✅ يجب إضافتها |
| **Package Name** | `com.munqeth.app` | ✅ موجود |

## استكشاف الأخطاء

### المشكلة: لا تزال الإشعارات لا تصل في Release APK

1. **تحقق من SHA fingerprints:**
   ```bash
   # تأكد من SHA fingerprints الصحيحة
   keytool -list -v -keystore android/app/munqeth.keystore -alias munqeth -storepass munqeth2024
   ```
   - تأكد من أن SHA-1 و SHA-256 موجودان في Firebase Console
   - تأكد من أنهما كاملان وليسا ناقصين

2. **تحقق من Package Name:**
   - `android/app/build.gradle`: `applicationId "com.munqeth.app"`
   - `google-services.json`: `"package_name": "com.munqeth.app"`
   - Firebase Console: `com.munqeth.app`
   - كلها يجب أن تطابق

3. **تحقق من Logcat:**
   ```bash
   adb logcat | grep -i firebase
   ```
   ابحث عن:
   - أخطاء في تهيئة Firebase
   - أخطاء في الحصول على FCM token
   - رسائل مثل "FirebaseApp initialization successful"

4. **جرب إعادة تثبيت التطبيق:**
   - احذف التطبيق بالكامل
   - ثبت APK الجديد
   - سجل الدخول مرة أخرى

### المشكلة: FCM token = null في Release APK

هذا يعني أن Firebase لم يحصل على token. الأسباب المحتملة:

1. **SHA fingerprints غير موجودة** - أضفها في Firebase Console
2. **google-services.json غير صحيح** - حمّل ملف جديد من Firebase Console
3. **صلاحيات الإشعارات غير ممنوحة** - امنح صلاحيات الإشعارات في إعدادات الجهاز

## ملاحظات مهمة

1. **Debug vs Release Keystore:**
   - Debug builds تستخدم `debug.keystore` (يتم إنشاؤه تلقائياً)
   - Release builds تستخدم `munqeth.keystore` (release keystore)
   - **يجب إضافة SHA fingerprints لكلا الـ keystores في Firebase Console**

2. **Google Play App Signing:**
   - إذا كنت تستخدم Google Play App Signing، قد تحتاج إلى إضافة SHA-256 من Google Play Console أيضاً
   - Google Play Console → Your app → Release → Setup → App signing
   - انسخ SHA-256 certificate fingerprint وأضفه في Firebase Console

3. **تحديث Token تلقائياً:**
   - التطبيق يستمع لتحديثات FCM token تلقائياً (`onTokenRefresh`)
   - عند تغيير الـ keystore أو تحديث Firebase settings، قد يحتاج المستخدم لإعادة تسجيل الدخول

## الخطوات السريعة

```bash
# 1. الحصول على SHA fingerprints
cd android/app
keytool -list -v -keystore munqeth.keystore -alias munqeth -storepass munqeth2024

# 2. أضف SHA-1 و SHA-256 في Firebase Console

# 3. نظف وابنِ APK جديد
cd ../..
flutter clean
flutter pub get
flutter build apk --release

# 4. ثبت APK على الجهاز واختبر
```

---

**✅ بعد إضافة SHA fingerprints في Firebase Console، الإشعارات ستعمل في Release APK!**




