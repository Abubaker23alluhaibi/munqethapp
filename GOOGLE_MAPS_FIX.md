# إصلاح مشكلة الخرائط في APK

## المشكلة
الخرائط تعمل بشكل طبيعي في البناء العادي (Debug) لكن لا تعمل في ملف APK (Release).

## السبب
مفتاح Google Maps API في Google Cloud Console مقيد بإصبع SHA-1 الخاص بالـ Debug keystore فقط، وليس Release keystore.

## الحل

### الخطوة 1: إضافة SHA-1 Fingerprint للإصدار في Google Cloud Console

1. اذهب إلى [Google Cloud Console - APIs & Services - Credentials](https://console.cloud.google.com/apis/credentials)

2. اختر مفتاح API الخاص بك (الذي يحتوي على: `AIzaSyBmY1uIqjlHA3UPRyhzxYqOCr6264nFzjo`)

3. في قسم **"Application restrictions"**، اختر **"Android apps"**

4. اضغط على **"Add an item"** لإضافة تطبيق Android جديد

5. أدخل المعلومات التالية:
   - **Package name**: `com.munqeth.app`
   - **SHA-1 certificate fingerprint**: `FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD`

6. اضغط **"Save"**

### الخطوة 2: التحقق من تفعيل APIs المطلوبة

تأكد من تفعيل الخدمات التالية في [Google Cloud Console - APIs & Services - Library](https://console.cloud.google.com/apis/library):

- ✅ **Maps SDK for Android** - مطلوب لعرض الخرائط
- ✅ **Maps SDK for iOS** - (إذا كان لديك تطبيق iOS)
- ✅ **Geocoding API** - لتحويل العناوين إلى إحداثيات
- ✅ **Directions API** - (إذا كنت تستخدم الاتجاهات)

### الخطوة 3: التحقق من API Restrictions

في صفحة مفتاح API، تأكد من أن **"API restrictions"** تحتوي على:
- Maps SDK for Android
- Geocoding API
- Directions API (إن وجد)

أو يمكنك اختيار **"Don't restrict key"** للاختبار (غير موصى به للإنتاج).

### الخطوة 4: إعادة بناء APK

بعد تحديث الإعدادات في Google Cloud Console:

```bash
cd munqeth
flutter clean
flutter build apk --release
```

**ملاحظة:** قد يستغرق تحديث الإعدادات في Google Cloud Console بضع دقائق حتى تصبح فعالة.

## معلومات SHA-1 Fingerprints

### Release Build (APK):
- **Package name**: `com.munqeth.app`
- **SHA-1**: `FD:94:93:92:A4:3B:77:7A:66:CF:6B:2A:31:CD:1B:63:27:8A:82:CD`

### Debug Build:
- **Package name**: `com.munqeth.app`
- **SHA-1**: `58:47:44:AF:85:E5:38:45:79:99:4A:9F:88:18:C9:B5:9D:98:72:70`

## نصائح إضافية

1. **ProGuard Rules**: تم إضافة ملف `proguard-rules.pro` لحماية فئات Google Maps من التشويش في حالة تفعيل ProGuard.

2. **اختبار API Key**: يمكنك اختبار المفتاح مباشرة من المتصفح:
   ```
   https://maps.googleapis.com/maps/api/staticmap?center=33.3152,44.3661&zoom=14&size=400x400&key=YOUR_API_KEY
   ```

3. **التحقق من Logs**: إذا استمرت المشكلة، تحقق من Logcat لرؤية أخطاء Google Maps:
   ```bash
   adb logcat | grep -i "maps\|google"
   ```

4. **Cache**: بعد تحديث الإعدادات، انتظر 5-10 دقائق قبل إعادة الاختبار.

## مشاكل شائعة أخرى

### الخرائط تظهر ولكنها رمادية/فارغة:
- تأكد من تفعيل **Maps SDK for Android**
- تأكد من أن API key ليس مقيداً بشكل مفرط

### خطأ "API key not valid":
- تأكد من نسخ SHA-1 بشكل صحيح (بدون مسافات)
- تأكد من Package name: `com.munqeth.app`
- انتظر بضع دقائق بعد التحديث

### الخرائط لا تتحمل/بطيئة:
- تحقق من اتصال الإنترنت
- تأكد من تفعيل الإذونات (Location, Internet)





