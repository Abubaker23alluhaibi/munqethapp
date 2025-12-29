# 🔑 إضافة SHA-1 للـ Debug Keystore في Firebase

## SHA-1 للـ Debug Keystore

```
SHA-1: 58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70
```

## الخطوات

### 1. اذهب إلى Firebase Console
https://console.firebase.google.com/project/munqethnof/settings/general

### 2. في قسم "Your apps"
- اضغط على **Android app** (com.munqeth.app)

### 3. في قسم "SHA certificate fingerprints"
- اضغط **"Add fingerprint"**
- أضف هذا SHA-1:
  ```
  58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70
  ```

### 4. بعد الإضافة
يجب أن يكون لديك الآن:
- ✅ SHA-1 للـ Debug: `58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70`
- ✅ SHA-1 للـ Release: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`
- ✅ SHA-256 للـ Release: `da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80`

### 5. تحميل google-services.json الجديد
- بعد إضافة SHA-1 للـ Debug، اضغط **"Download google-services.json"**
- استبدل الملف في `android/app/google-services.json`

## ملاحظة مهمة

**لماذا نحتاج SHA-1 للـ Debug؟**
- عند تشغيل التطبيق عبر USB (Debug mode)، Android يستخدم `debug.keystore`
- عند بناء APK (Release mode)، Android يستخدم `munqeth.keystore`
- Firebase يحتاج SHA-1 لكلاهما ليعمل في كلا الوضعين

## بعد الإضافة

1. ✅ حمّل google-services.json الجديد
2. ✅ استبدله في `android/app/google-services.json`
3. ✅ أعد بناء التطبيق:
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

## اختبار

بعد إضافة SHA-1 للـ Debug وإعادة بناء التطبيق:
- ✅ يجب أن يعمل FCM في Debug mode (USB)
- ✅ يجب أن يعمل FCM في Release mode (APK)
- ✅ يجب أن تصل الإشعارات في كلا الوضعين







