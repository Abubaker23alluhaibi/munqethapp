# ⚡ حل سريع لمشكلة FCM Tokens

## المشكلة
- FCM tokens غير موجودة في قاعدة البيانات
- الإشعارات لا تصل

## الحل المطبق في الكود

### ✅ 1. استخدام FCM Token محفوظ
- إذا فشل الحصول على FCM token جديد، سيستخدم التطبيق token محفوظ
- هذا يسمح للإشعارات بالعمل حتى لو كان هناك مشكلة في Firebase

### ✅ 2. إعادة محاولة تلقائية
- عند فتح التطبيق: إرسال فوري + إعادة محاولة بعد 10 ثوانٍ
- هذا يضمن إرسال FCM token حتى لو فشل في المرة الأولى

## الخطوات المطلوبة منك

### 1️⃣ الحصول على SHA-1 للـ Debug Keystore

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
$env:PATH += ";C:\src\flutter\bin"
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

انسخ **SHA-1** الذي يظهر.

### 2️⃣ إضافة SHA في Firebase Console

1. اذهب إلى: https://console.firebase.google.com
2. مشروع: **munqethnof**
3. **Project Settings** → **Your apps** → Android app
4. في **SHA certificate fingerprints**:
   - ✅ أضف SHA-1 للـ **Debug** (الذي حصلت عليه في الخطوة 1)
   - ✅ تأكد من وجود SHA-1 للـ **Release**: `fd:94:93:92:a4:3b:77:7a:66:cf:6b:2a:31:cd:1b:63:27:8a:82:cd`
   - ✅ تأكد من وجود SHA-256: `da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80`

### 3️⃣ تحميل google-services.json الجديد

بعد إضافة SHA fingerprints:
1. في نفس الصفحة، اضغط **"Download google-services.json"**
2. استبدل الملف في `android/app/google-services.json`

### 4️⃣ إعادة بناء التطبيق

```powershell
cd C:\Users\abubkr\Desktop\monqethAll\munqeth
$env:PATH += ";C:\src\flutter\bin"
flutter clean
flutter pub get
flutter run
```

## اختبار

1. **بعد تسجيل الدخول:**
   - انتظر 15 ثانية (5 ثوانٍ أولية + 10 ثوانٍ لإعادة المحاولة)
   - تحقق من Logs - يجب أن ترى: `✅ FCM token sent successfully`

2. **في Backend Logs:**
   - عند إنشاء طلب، يجب أن ترى: `📱 Drivers with FCM tokens: 1/1`
   - بدلاً من: `⚠️ Found drivers but none have FCM tokens`

## ملاحظة مهمة

إذا كان لديك FCM token محفوظ من قبل (من نسخة سابقة من التطبيق):
- ✅ سيتم استخدامه تلقائياً
- ✅ سيتم إرساله إلى السيرفر
- ✅ الإشعارات ستعمل

إذا لم يكن لديك FCM token محفوظ:
- يجب إصلاح Firebase configuration أولاً (إضافة SHA fingerprints)







