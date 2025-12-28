# 🔧 حل مشكلة عدم إرسال FCM Token

## المشكلة
بعد تسجيل الدخول، FCM token لا يتم إرساله إلى السيرفر. لا توجد logs في التطبيق تظهر محاولة إرسال FCM token.

## الأعراض
- ✅ تسجيل الدخول يعمل بشكل صحيح
- ❌ لا توجد logs تظهر `🔄 _sendFcmTokenToServer called`
- ❌ لا توجد logs تظهر `📤 Attempting to send FCM token`
- ❌ FCM token غير موجود في قاعدة البيانات

## الأسباب المحتملة

### 1. NotificationService غير مهيأ
**التحقق:**
- ابحث في logs عن: `NotificationService initialized successfully`
- إذا لم تجدها، Firebase لم يتم تهيئته بشكل صحيح

**الحل:**
- تحقق من `google-services.json` موجود في `android/app/`
- تحقق من `GoogleService-Info.plist` موجود في `ios/Runner/` (لـ iOS)

### 2. FCM Token غير موجود
**التحقق:**
- ابحث في logs عن: `FCM Token obtained successfully`
- إذا لم تجدها، FCM token لم يتم الحصول عليه

**الحل:**
- تحقق من صلاحيات الإشعارات ممنوحة
- تحقق من Firebase configuration صحيح
- أعد تثبيت التطبيق

### 3. _sendFcmTokenToServer لا يتم استدعاؤها
**التحقق:**
- ابحث في logs عن: `🔄 _sendFcmTokenToServer called`
- إذا لم تجدها، الدالة لا يتم استدعاؤها

**الحل:**
- تحقق من أن `loginAsUser` أو `loginAsDriver` يتم استدعاؤها
- تحقق من أن `_sendFcmTokenToServer` موجودة في الكود

## خطوات التشخيص

### 1. تحقق من Logs التطبيق

بعد تسجيل الدخول، ابحث عن:

```
🔄 _sendFcmTokenToServer called - userId: ..., phone: ..., driverId: ...
⏰ Starting FCM token send after delay...
📱 NotificationService instance created
   isInitialized: true/false
   fcmToken: .../null
```

**إذا لم تر هذه الرسائل:**
- `_sendFcmTokenToServer` لا يتم استدعاؤها
- تحقق من أن `loginAsUser` أو `loginAsDriver` يتم استدعاؤها

### 2. تحقق من Firebase Configuration

```bash
# تحقق من google-services.json موجود
ls android/app/google-services.json

# تحقق من محتوى الملف
cat android/app/google-services.json | grep project_id
```

### 3. تحقق من FCM Token في التطبيق

أضف في أي مكان في التطبيق:

```dart
final notificationService = NotificationService();
print('FCM Token: ${notificationService.fcmToken}');
print('Is Initialized: ${notificationService.isInitialized}');
```

## الحلول

### الحل 1: إرسال FCM Token يدوياً

أضف زر في التطبيق لإرسال FCM token يدوياً:

```dart
ElevatedButton(
  onPressed: () async {
    final notificationService = NotificationService();
    if (!notificationService.isInitialized) {
      await notificationService.initialize();
    }
    
    final fcmToken = notificationService.fcmToken;
    if (fcmToken != null) {
      // للمستخدم
      final userService = UserService();
      final phone = await SecureStorageService.getString('user_phone');
      if (phone != null) {
        await userService.updateFcmTokenByPhone(phone, fcmToken);
      }
      
      // أو للسائق
      final driverService = DriverService();
      final driver = await driverService.getCurrentDriver();
      if (driver != null) {
        await driverService.updateFcmTokenByDriverId(driver.driverId, fcmToken);
      }
    }
  },
  child: Text('إرسال FCM Token'),
)
```

### الحل 2: إرسال FCM Token عند فتح التطبيق

في `loadSavedAuth` في `auth_provider.dart`:

```dart
Future<void> loadSavedAuth() async {
  // ... الكود الحالي ...
  
  // إرسال FCM token بعد تحميل الحالة
  Future.delayed(const Duration(seconds: 5), () {
    _sendFcmTokenToServer(
      userId: _currentUser?.id,
      phone: await SecureStorageService.getString('user_phone'),
      driverId: _driver?.driverId,
    );
  });
}
```

### الحل 3: زيادة وقت الانتظار

في `_sendFcmTokenToServer`:

```dart
Future.delayed(const Duration(seconds: 5), () async { // بدلاً من 2
  // ...
});
```

### الحل 4: إرسال FCM Token مباشرة بعد تسجيل الدخول

بدلاً من `Future.delayed`، أرسل FCM token مباشرة:

```dart
// في loginAsUser
_sendFcmTokenToServerImmediately(userId: user.id, phone: phone);

// أضف دالة جديدة
Future<void> _sendFcmTokenToServerImmediately({String? userId, String? phone, String? driverId}) async {
  final notificationService = NotificationService();
  if (!notificationService.isInitialized) {
    await notificationService.initialize();
  }
  
  if (notificationService.fcmToken != null) {
    await notificationService.sendFcmTokenToServer(userId, phone, driverId: driverId);
  } else {
    // إعادة المحاولة بعد تأخير
    Future.delayed(const Duration(seconds: 3), () {
      _sendFcmTokenToServerImmediately(userId: userId, phone: phone, driverId: driverId);
    });
  }
}
```

## التحقق من النجاح

بعد تطبيق الحل، ابحث في logs عن:

```
✅ FCM token sent to server for user: ...
✅ FCM token sent to server for driver: ...
```

وفي logs السيرفر:

```
📱 Received FCM token update request for phone: ...
✅ Updated FCM token for user ...
```

## ملخص

| المشكلة | السبب | الحل |
|---------|-------|------|
| لا توجد logs | `_sendFcmTokenToServer` لا يتم استدعاؤها | تحقق من `loginAsUser`/`loginAsDriver` |
| FCM token null | Firebase غير مهيأ | تحقق من `google-services.json` |
| فشل الإرسال | Network error | تحقق من الاتصال بالإنترنت |
| Token لا يتم حفظه | خطأ في السيرفر | تحقق من logs السيرفر |

---

**ملاحظة:** بعد كل تغيير، أعد تشغيل التطبيق واختبر تسجيل الدخول مرة أخرى.




