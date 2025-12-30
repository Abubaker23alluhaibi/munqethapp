# 🔔 دليل إعداد Firebase Push Notifications

## ✅ ما تم إنجازه

تم إعداد الكود التطبيق لدعم Firebase Cloud Messaging (FCM) للإشعارات الخارجية. الإشعارات ستصل حتى عندما يكون التطبيق مغلق تماماً.

### الملفات المحدثة:
- ✅ `pubspec.yaml` - تم إضافة `firebase_core` و `firebase_messaging`
- ✅ `lib/services/firebase_messaging_service.dart` - خدمة جديدة لإدارة FCM
- ✅ `lib/main.dart` - تم إضافة تهيئة Firebase
- ✅ `lib/providers/auth_provider.dart` - تم إضافة إرسال FCM tokens بعد تسجيل الدخول
- ✅ `android/app/src/main/AndroidManifest.xml` - جاهز بالفعل (موجود)

---

## 📋 الخطوات التالية (مطلوب منك)

### 1. إعداد Firebase Project

1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. أنشئ مشروع جديد أو استخدم مشروع موجود
3. أضف تطبيق Android:
   - اضغط على "Add app" → Android
   - أدخل Package name: `com.munqeth.app`
   - أدخل App nickname (اختياري): "المنقذ"
   - اضغط "Register app"

4. (اختياري) أضف تطبيق iOS إذا كنت تحتاجه:
   - اضغط على "Add app" → iOS
   - أدخل Bundle ID
   - اتبع الخطوات

### 2. تحميل `google-services.json` (Android)

1. بعد إضافة تطبيق Android، سيظهر لك زر "Download google-services.json"
2. حمّل الملف
3. ضع الملف في: `munqeth/android/app/google-services.json`
   - ⚠️ تأكد من وجوده في المسار الصحيح!

### 3. (لـ iOS فقط) تحميل `GoogleService-Info.plist`

1. بعد إضافة تطبيق iOS، حمّل ملف `GoogleService-Info.plist`
2. ضع الملف في: `munqeth/ios/Runner/GoogleService-Info.plist`

### 4. تثبيت Packages

قم بتشغيل الأمر التالي في Terminal:

```bash
cd munqeth
flutter pub get
```

### 5. بناء التطبيق

```bash
flutter build apk
# أو
flutter run
```

---

## 🔧 إعداد السيرفر (Backend)

السيرفر لديه بالفعل دعم لـ Firebase Cloud Messaging. تحتاج فقط إلى إضافة Environment Variables في Railway (أو أي hosting platform تستخدمه):

### Environment Variables المطلوبة:

```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

### كيفية الحصول على هذه القيم:

1. في Firebase Console → Project Settings → Service Accounts
2. اضغط "Generate New Private Key"
3. سيتم تحميل ملف JSON يحتوي على:
   - `project_id` → استخدمه في `FIREBASE_PROJECT_ID`
   - `private_key` → استخدمه في `FIREBASE_PRIVATE_KEY` (يجب أن يكون بين علامات اقتباس)
   - `client_email` → استخدمه في `FIREBASE_CLIENT_EMAIL`

**مهم:** 
- `FIREBASE_PRIVATE_KEY` يجب أن يكون بين علامات اقتباس (`"`)
- يجب أن يحتوي على `\n` في نهاية كل سطر (أو استخدم سطر واحد)

---

## ✅ التحقق من أن كل شيء يعمل

بعد إعداد Firebase وتشغيل التطبيق:

1. **افتح التطبيق** وسجّل الدخول (كمستخدم أو سائق)
2. **تحقق من Logs** - يجب أن ترى:
   ```
   ✅ Firebase initialized
   ✅ FirebaseMessagingService initialized
   ✅ FCM Token obtained: ...
   ✅ FCM Token sent to server for user/driver: ...
   ```

3. **اختبر الإشعارات:**
   - يمكنك إرسال إشعار تجريبي من Firebase Console:
     - Firebase Console → Cloud Messaging → "Send test message"
     - أدخل FCM Token من Logs
     - أرسل الإشعار

---

## 🔍 استكشاف الأخطاء

### المشكلة: "Firebase not initialized"

**الحل:**
- تأكد من وجود `google-services.json` في `android/app/`
- تأكد من تشغيل `flutter pub get`
- تأكد من أن `package name` في Firebase Console يطابق `com.munqeth.app`

### المشكلة: "FCM Token is null"

**الحل:**
- تأكد من منح صلاحيات الإشعارات عند طلبها من التطبيق
- على Android 13+، يحتاج التطبيق إلى طلب صلاحيات الإشعارات صراحة

### المشكلة: الإشعارات لا تظهر

**الحل:**
- تحقق من أن `google-services.json` موجود وصحيح
- تحقق من Logs في التطبيق لمعرفة إذا كان FCM Token يتم الحصول عليه
- تحقق من Environment Variables في السيرفر

### المشكلة: "FCM Token sent to server failed"

**الحل:**
- تأكد من أن السيرفر يعمل
- تحقق من أن API endpoint `/users/phone/{phone}/fcm-token` أو `/drivers/driverId/{driverId}/fcm-token` يعمل
- تحقق من Logs في السيرفر

---

## 📱 كيف يعمل النظام الآن

1. **عند فتح التطبيق:**
   - Firebase يتم تهيئته
   - FCM Token يتم الحصول عليه
   - Token يتم إرساله للسيرفر بعد تسجيل الدخول

2. **عند إرسال إشعار من السيرفر:**
   - السيرفر يرسل الإشعار عبر Firebase Cloud Messaging
   - الإشعار يصل حتى لو كان التطبيق مغلق
   - `firebaseMessagingBackgroundHandler` يعالج الإشعار عندما يكون التطبيق مغلق
   - `onMessage` يعالج الإشعار عندما يكون التطبيق مفتوح

3. **عند فتح التطبيق من إشعار:**
   - `onMessageOpenedApp` يتم استدعاؤه
   - يمكنك إضافة navigation logic هنا

---

## 📝 ملاحظات مهمة

1. **FCM Tokens تتغير** - يجب تحديثها عند:
   - إعادة تثبيت التطبيق
   - تحديث التطبيق
   - تسجيل الدخول على جهاز جديد
   - (يتم التعامل مع هذا تلقائياً عبر `onTokenRefresh`)

2. **الصلاحيات** - تأكد من أن التطبيق يطلب صلاحيات الإشعارات:
   - Android: تلقائياً عند طلب `requestPermission()`
   - iOS: يحتاج إلى طلب صريح (موجود في الكود)

3. **Background Notifications** - للتطبيق المغل
ق تماماً:
   - `firebaseMessagingBackgroundHandler` يجب أن يكون top-level function ✅
   - تم إعداده في `lib/services/firebase_messaging_service.dart`

---

## ✅ قائمة التحقق النهائية

- [ ] Firebase Project تم إنشاؤه
- [ ] تطبيق Android تم إضافته في Firebase Console
- [ ] `google-services.json` موجود في `android/app/`
- [ ] `flutter pub get` تم تشغيله
- [ ] التطبيق يعمل ويطلب صلاحيات الإشعارات
- [ ] FCM Token يتم الحصول عليه (تحقق من Logs)
- [ ] FCM Token يتم إرساله للسيرفر (تحقق من Logs)
- [ ] Environment Variables تم إضافتها في السيرفر (Railway)
- [ ] تم اختبار الإشعارات من Firebase Console
- [ ] تم اختبار الإشعارات من السيرفر

---

**بعد إكمال هذه الخطوات، الإشعارات الخارجية يجب أن تعمل بشكل صحيح! 🎉**

