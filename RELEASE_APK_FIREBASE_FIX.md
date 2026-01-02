# 🔧 إصلاح مشكلة Firebase في Release APK

## المشكلة

الإشعارات كانت تعمل في **Debug mode** (من USB) لكن توقفت في **Release APK**.

## السبب الرئيسي

**SHA Fingerprint للـ Release Keystore غير موجود في Firebase Console!**

في Debug mode، Android يستخدم **debug keystore** (SHA fingerprint موجود في Firebase).
في Release APK، Android يستخدم **release keystore** (SHA fingerprint غير موجود في Firebase).

---

## ✅ الحل

### الخطوة 1: الحصول على SHA Fingerprint للـ Release Keystore

#### على Windows (PowerShell):

```powershell
cd munqeth/android
.\get_sha_fingerprints.ps1
```

أو يدوياً:

```powershell
cd munqeth/android
keytool -list -v -keystore app/munqeth.keystore -alias munqeth
```

**أدخل كلمة المرور** عندما يُطلب منك.

ابحث عن:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

#### على Linux/Mac:

```bash
cd munqeth/android
./get_sha_fingerprints.sh
```

أو يدوياً:

```bash
keytool -list -v -keystore app/munqeth.keystore -alias munqeth
```

---

### الخطوة 2: إضافة SHA Fingerprint في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك: **munqethnof**
3. اذهب إلى **Project Settings** (⚙️)
4. اختر تطبيق Android: **com.munqeth.app**
5. في قسم **SHA certificate fingerprints**، اضغط **"Add fingerprint"**
6. أضف **SHA-1** و **SHA-256** من الخطوة السابقة
7. اضغط **"Save"**

---

### الخطوة 3: تحميل `google-services.json` الجديد (اختياري)

بعد إضافة SHA fingerprints، قد تحتاج إلى:
1. تحميل `google-services.json` الجديد من Firebase Console
2. استبدال الملف القديم في `munqeth/android/app/google-services.json`

**ملاحظة:** عادة لا حاجة لهذا إذا كان `google-services.json` موجود بالفعل.

---

### الخطوة 4: إعادة بناء APK

```bash
cd munqeth
flutter clean
flutter pub get
flutter build apk --release
```

أو:

```bash
flutter build appbundle --release
```

---

## 🔍 مشاكل أخرى محتملة

### المشكلة 1: ProGuard يحذف كود Firebase

**الحل:** ProGuard rules موجودة بالفعل في `proguard-rules.pro` ✅

### المشكلة 2: `google-services.json` غير موجود في APK

**الحل:** تأكد من أن الملف موجود في `android/app/google-services.json` ✅

### المشكلة 3: Firebase initialization يفشل

**الحل:** تحقق من Logs في التطبيق - يجب أن ترى:
```
✅ Firebase initialized
✅ FirebaseMessagingService initialized
```

---

## ✅ قائمة التحقق

- [ ] SHA-1 fingerprint للـ release keystore تم إضافته في Firebase Console
- [ ] SHA-256 fingerprint للـ release keystore تم إضافته في Firebase Console
- [ ] `google-services.json` موجود في `android/app/`
- [ ] تم إعادة بناء APK بعد إضافة SHA fingerprints
- [ ] تم تثبيت APK الجديد على الجهاز
- [ ] تم تسجيل الدخول في التطبيق (لإرسال FCM Token)
- [ ] تم اختبار الإشعارات

---

## 📝 ملاحظات مهمة

1. **SHA Fingerprints مختلفة:**
   - Debug keystore: موجود عادة في `~/.android/debug.keystore`
   - Release keystore: موجود في `android/app/munqeth.keystore`
   - **يجب إضافة كليهما** في Firebase Console

2. **إذا كان لديك عدة release keystores:**
   - أضف SHA fingerprints لكل keystore تستخدمه

3. **بعد إضافة SHA fingerprints:**
   - لا حاجة لإعادة تحميل `google-services.json` عادة
   - لكن يجب إعادة بناء APK

---

## 🧪 اختبار بعد الإصلاح

1. **شغّل APK الجديد**
2. **سجّل دخول** (كمستخدم أو سائق)
3. **تحقق من Logs** - يجب أن ترى:
   ```
   ✅ Firebase initialized
   ✅ FirebaseMessagingService initialized
   ✅ FCM Token obtained: ...
   ✅ FCM Token sent to server
   ```
4. **اختبر الإشعارات** - يجب أن تصل حتى عندما يكون التطبيق مغلق

---

**بعد إضافة SHA fingerprints وإعادة بناء APK، الإشعارات يجب أن تعمل! 🎉**


