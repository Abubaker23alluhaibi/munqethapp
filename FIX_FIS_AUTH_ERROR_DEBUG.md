# 🔧 إصلاح خطأ FIS_AUTH_ERROR للـ Debug Build

## 🔍 المشكلة

أنت تبني **Debug build** لكن SHA المضاف في Firebase Console هو للـ **Release keystore** فقط.

## ✅ الحل

### الخطوة 1: إضافة SHA-1 للـ Debug Keystore في Firebase

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر المشروع: **munqethnof**
3. اذهب إلى **Project Settings** (⚙️ الإعدادات)
4. اختر تبويب **Your apps**
5. اضغط على تطبيق **Android** (`com.munqeth.app`)
6. في قسم **SHA certificate fingerprints**، اضغط **"Add fingerprint"**
7. أضف SHA-1 التالي:

```
58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70
```

8. احفظ التغييرات

### الخطوة 2: تحميل google-services.json الجديد

**بعد إضافة SHA، يجب تحميل ملف google-services.json جديد:**

1. في نفس صفحة Firebase Console (Project Settings → Your apps → Android app)
2. اضغط على زر **"Download google-services.json"**
3. استبدل الملف الموجود في `android/app/google-services.json` بالملف الجديد

### الخطوة 3: تنظيف وإعادة بناء التطبيق

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
flutter clean
flutter pub get
flutter run
```

## 📋 قائمة التحقق

- [ ] أضفت SHA-1 للـ Debug keystore في Firebase Console
- [ ] حملت `google-services.json` الجديد بعد إضافة SHA
- [ ] استبدلت الملف القديم بالجديد في `android/app/google-services.json`
- [ ] قمت بـ `flutter clean`
- [ ] قمت بإعادة بناء التطبيق

## ⚠️ ملاحظات مهمة

1. **SHA-1 للـ Debug:**
   ```
   58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70
   ```

2. **SHA-1 للـ Release (موجود بالفعل):**
   ```
   fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd
   ```

3. **Package name:** `com.munqeth.app`

4. **بعد إضافة SHA، يجب تحميل `google-services.json` جديد** - هذا مهم جداً!

## 🔄 إذا استمرت المشكلة

1. **احذف التطبيق** من الجهاز تماماً
2. **نظف المشروع:**
   ```powershell
   flutter clean
   ```
3. **أعد البناء:**
   ```powershell
   flutter pub get
   flutter run
   ```

4. **تحقق من الاتصال بالإنترنت** - Firebase يحتاج اتصال للتحقق من SHA

## 💡 بديل: استخدام Release Build للاختبار

إذا كنت تريد تجنب إضافة Debug SHA، يمكنك بناء Release build للاختبار:

```powershell
flutter build apk --release
```

ثم ثبت APK على الجهاز.




