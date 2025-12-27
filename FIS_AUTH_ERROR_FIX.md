# 🔧 حل مشكلة FIS_AUTH_ERROR

## المشكلة
```
FIS_AUTH_ERROR - Firebase Installations Service is unavailable
```

هذا يعني أن Firebase لا يمكنه التحقق من هوية التطبيق.

## ✅ التحقق من Firebase Console

تم التأكد من أن SHA fingerprints موجودة وصحيحة:
- ✅ SHA-1: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`
- ✅ SHA-256: `da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80`
- ✅ Package name: `com.munqeth.app`

## 🔍 الأسباب المحتملة

### 1. Debug vs Release Keystore Mismatch
**المشكلة:** التطبيق مبني بـ Debug keystore لكن SHA المضاف في Firebase هو للـ Release keystore (أو العكس).

**الحل:**
1. **إذا كنت تبني Debug build:**
   ```powershell
   cd munqeth\android
   .\get_sha_fingerprints.ps1
   ```
   - احصل على SHA-1 للـ Debug keystore
   - أضفه في Firebase Console

2. **إذا كنت تبني Release build:**
   - تأكد من استخدام `munqeth.keystore`
   - SHA المضاف صحيح: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`

### 2. google-services.json يحتاج تحديث
**المشكلة:** بعد إضافة SHA fingerprints، قد يحتاج `google-services.json` تحديث.

**الحل:**
1. اذهب إلى Firebase Console → Project Settings → Your apps
2. اضغط على تطبيق Android
3. اضغط **"Download google-services.json"**
4. استبدل الملف في `android/app/google-services.json`
5. أعد بناء التطبيق

### 3. مشكلة في الاتصال بالإنترنت
**المشكلة:** Firebase لا يستطيع الاتصال بالسيرفرات.

**الحل:**
- تحقق من الاتصال بالإنترنت
- جرب على شبكة Wi-Fi بدلاً من البيانات
- تحقق من Firewall أو VPN

## 🔧 الحل السريع

### الخطوة 1: أضف SHA-1 للـ Debug Keystore (للاختبار)

```powershell
cd munqeth\android
.\get_sha_fingerprints.ps1
```

انسخ SHA-1 للـ Debug keystore وأضفه في Firebase Console.

### الخطوة 2: حمل google-services.json الجديد

1. Firebase Console → Project Settings → Your apps → Android app
2. **"Download google-services.json"**
3. استبدل الملف في `android/app/google-services.json`

### الخطوة 3: نظف وأعد البناء

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
$env:PATH += ";C:\src\flutter\bin"
flutter clean
flutter pub get
flutter run
```

## 💡 حل بديل: استخدام FCM Token محفوظ

إذا استمرت المشكلة، الكود الآن يستخدم FCM token محفوظ في Storage:
- إذا فشل الحصول على token جديد، سيستخدم المحفوظ
- هذا يسمح للإشعارات بالعمل حتى لو كان هناك مشكلة في Firebase configuration

## 🧪 اختبار

بعد إصلاح المشكلة:

1. **احذف التطبيق من الجهاز** (إن كان مثبتاً)
2. **ثبت APK جديد**
3. **سجل دخول**
4. **تحقق من Logs:**
   ```
   ✅ FCM token sent successfully
   ```

## 📋 قائمة التحقق

- [ ] SHA-1 للـ Debug keystore مضاف في Firebase (للاختبار)
- [ ] SHA-1 للـ Release keystore مضاف في Firebase (للإنتاج)
- [ ] SHA-256 مضاف في Firebase
- [ ] `google-services.json` محدث بعد إضافة SHA
- [ ] Package name مطابق في جميع الأماكن: `com.munqeth.app`
- [ ] التطبيق مبني بنفس Keystore الذي أضفنا له SHA
- [ ] الاتصال بالإنترنت يعمل
- [ ] تم حذف التطبيق القديم قبل تثبيت الجديد

## ⚠️ ملاحظة مهمة

**للإنتاج (Release Build):**
- استخدم `munqeth.keystore` فقط
- تأكد من أن SHA المضاف في Firebase هو للـ Release keystore
- لا تستخدم Debug keystore في الإنتاج

**للاختبار (Debug Build):**
- يمكنك إضافة SHA للـ Debug keystore أيضاً لتسهيل الاختبار
- أو استخدم Release build للاختبار أيضاً
