# قائمة التحقق للإصدار - Release Checklist

## قبل البناء

### Android
- [ ] تحديث `version` و `versionCode` في `pubspec.yaml`
- [ ] التأكد من وجود `keystore.properties` في `android/`
- [ ] التأكد من وجود `google-services.json` في `android/app/`
- [ ] التأكد من إضافة Google Maps API Key
- [ ] اختبار البناء: `flutter build appbundle --release`

### iOS
- [ ] تحديث `version` و `buildNumber` في `pubspec.yaml`
- [ ] التأكد من إعدادات Bundle Identifier
- [ ] التأكد من إضافة Google Maps API Key
- [ ] التأكد من إعدادات الصلاحيات في `Info.plist`
- [ ] اختبار البناء: `flutter build ios --release`

## قبل الرفع

- [ ] اختبار جميع الميزات الرئيسية
- [ ] اختبار على أجهزة مختلفة
- [ ] التأكد من عدم وجود أخطاء في console
- [ ] التأكد من أن جميع الصور والأيقونات موجودة
- [ ] التأكد من أن API URLs صحيحة

## Google Play Store

- [ ] إنشاء App Bundle: `flutter build appbundle --release`
- [ ] إعداد صفحة المتجر (الوصف، الصور، إلخ)
- [ ] رفع APK/Bundle إلى Google Play Console
- [ ] ملء جميع المعلومات المطلوبة
- [ ] إرسال للمراجعة

## Apple App Store

- [ ] إنشاء Archive: `flutter build ios --release`
- [ ] رفع إلى App Store Connect
- [ ] إعداد صفحة المتجر
- [ ] ملء جميع المعلومات المطلوبة
- [ ] إرسال للمراجعة

