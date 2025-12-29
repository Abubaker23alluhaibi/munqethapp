# 🔧 حل مشكلة FCM Token في Debug vs Release

## المشكلة
- ✅ الإشعارات كانت تعمل عند الاتصال بـ USB (Debug build)
- ❌ الإشعارات لا تعمل عند بناء APK (Release build)
- ❌ الآن لا تعمل في أي من الحالتين

## السبب
Firebase يحتاج SHA fingerprints مختلفة:
- **Debug build** → يستخدم `debug.keystore` → يحتاج SHA-1 للـ Debug
- **Release build** → يستخدم `munqeth.keystore` → يحتاج SHA-1 للـ Release

## الحل

### الخطوة 1: الحصول على SHA-1 للـ Debug Keystore

افتح PowerShell في مجلد المشروع:

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

ابحث عن:
```
SHA1: XX:XX:XX:XX:...
```

### الخطوة 2: الحصول على SHA-1 للـ Release Keystore

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth\android
keytool -list -v -keystore app\munqeth.keystore -alias munqeth -storepass munqeth2024
```

(أو استخدم SHA الموجود بالفعل: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`)

### الخطوة 3: إضافة SHA Fingerprints في Firebase Console

1. اذهب إلى: https://console.firebase.google.com
2. اختر مشروع: **munqethnof**
3. Project Settings → Your apps → Android app (com.munqeth.app)
4. في قسم **SHA certificate fingerprints**:

#### أضف SHA-1 للـ Debug:
```
SHA-1: [انسخ SHA-1 من Debug keystore]
```

#### تأكد من وجود SHA-1 للـ Release:
```
SHA-1: fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd
```

#### تأكد من وجود SHA-256:
```
SHA-256: da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80
```

### الخطوة 4: تحميل google-services.json الجديد

بعد إضافة SHA fingerprints:
1. في نفس الصفحة، اضغط **"Download google-services.json"**
2. استبدل الملف في `android/app/google-services.json`

### الخطوة 5: تنظيف وإعادة البناء

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
$env:PATH += ";C:\src\flutter\bin"
flutter clean
flutter pub get
flutter run
```

## اختبار

### للاختبار (Debug):
```powershell
flutter run
```

### للبناء (Release APK):
```powershell
flutter build apk --release
```

ثم ثبت APK على الجهاز.

## ملاحظات مهمة

1. **يجب إضافة SHA-1 للـ Debug والـ Release** في Firebase Console
2. **يجب تحميل google-services.json** بعد إضافة SHA fingerprints
3. **احذف التطبيق القديم** قبل تثبيت الجديد
4. **سجل دخول مرة أخرى** بعد التثبيت الجديد

## التحقق

بعد التثبيت، تحقق من Logs:
```
✅ FCM token sent successfully
```

إذا رأيت:
```
❌ FIS_AUTH_ERROR
```
فهذا يعني أن SHA fingerprint غير صحيح للـ keystore المستخدم.







