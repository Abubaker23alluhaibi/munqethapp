# دليل إدارة Console Logs - تطبيق المنقذ

## 📊 الوضع الحالي

- **عدد print statements**: 318 في 31 ملف
- **المشكلة**: `print()` في Dart تظهر دائماً في console حتى في release mode
- **الحل**: استخدام دوال آمنة تخفي نفسها تلقائياً في release mode

## ✅ الحلول المتاحة

### 1. استخدام `safePrint()` (الأسهل)

```dart
import 'package:munqeth/core/utils/console_helper.dart';

// بدلاً من print()
safePrint('Debug message'); // يظهر فقط في debug mode
```

**المميزات:**
- ✅ سهل الاستخدام
- ✅ يخفي نفسه تلقائياً في release mode
- ✅ لا يحتاج تغيير كبير في الكود

### 2. استخدام `AppLogger` (الأفضل للكود الجديد)

```dart
import 'package:munqeth/core/utils/app_logger.dart';

AppLogger.d('Debug message');      // يظهر فقط في debug
AppLogger.i('Info message');      // يظهر فقط في debug
AppLogger.w('Warning message');    // يظهر في debug و release
AppLogger.e('Error message', e);   // يظهر في debug و release
```

**المميزات:**
- ✅ أكثر احترافية
- ✅ يدعم مستويات مختلفة (debug, info, warning, error)
- ✅ يدعم errors و stack traces
- ✅ يخفي debug/info في release mode تلقائياً

### 3. استخدام `debugPrint` من Flutter

```dart
import 'package:flutter/foundation.dart';

debugPrint('Debug message'); // يظهر فقط في debug mode
```

**المميزات:**
- ✅ مدمج في Flutter
- ✅ يخفي نفسه تلقائياً في release
- ⚠️ قد يكون بطيء في بعض الحالات

## 🎯 الخطة الموصى بها

### المرحلة 1: إخفاء فوري (Quick Fix)
استبدال `print()` بـ `safePrint()` في الملفات المهمة:

```dart
// قبل
print('Error: $e');

// بعد
import 'package:munqeth/core/utils/console_helper.dart';
safePrint('Error: $e');
```

### المرحلة 2: تحسين تدريجي (Long Term)
استبدال `print()` بـ `AppLogger` في الملفات الجديدة والكود المهم:

```dart
// قبل
print('Error: $e');

// بعد
import 'package:munqeth/core/utils/app_logger.dart';
AppLogger.e('Error message', e);
```

## 📝 قواعد الاستخدام

### متى تستخدم `safePrint()`؟
- ✅ للـ debug messages العادية
- ✅ للـ temporary debugging
- ✅ عندما تريد حل سريع

### متى تستخدم `AppLogger`؟
- ✅ للكود الجديد
- ✅ للأخطاء المهمة (errors)
- ✅ للتحذيرات (warnings)
- ✅ عندما تحتاج stack traces

### متى تستخدم `errorPrint()`؟
- ✅ للأخطاء الحرجة التي يجب أن تظهر في production
- ✅ للـ background handlers (مثل Firebase messaging)

## 🔧 أمثلة عملية

### مثال 1: استبدال print في catch blocks

```dart
// قبل
catch (e) {
  print('Error: $e');
}

// بعد - Option 1 (سريع)
catch (e) {
  safePrint('Error: $e');
}

// بعد - Option 2 (أفضل)
catch (e) {
  AppLogger.e('Error message', e);
}
```

### مثال 2: Background Handlers

```dart
// قبل
@pragma('vm:entry-point')
Future<void> backgroundHandler(RemoteMessage message) async {
  print('Message: ${message.messageId}');
}

// بعد
@pragma('vm:entry-point')
Future<void> backgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Message: ${message.messageId}');
  }
  // أو
  safePrint('Message: ${message.messageId}');
}
```

### مثال 3: Debug Information

```dart
// قبل
print('User logged in: $userId');

// بعد
AppLogger.d('User logged in: $userId');
// أو
safePrint('User logged in: $userId');
```

## ⚠️ تحذيرات مهمة

1. **لا تحذف print statements فوراً**
   - استبدلها بـ `safePrint()` أو `AppLogger`
   - الحذف قد يخفي معلومات مهمة للـ debugging

2. **احتفظ بـ error logs في production**
   - استخدم `AppLogger.e()` للأخطاء المهمة
   - أو `errorPrint()` للأخطاء الحرجة

3. **اختبر في release mode**
   - تأكد أن logs مخفية في release
   - تأكد أن errors المهمة لا تزال تظهر

## 🚀 Script للاستبدال التلقائي

يمكن استخدام script PowerShell لاستبدال `print()` بـ `safePrint()`:

```powershell
# في scripts/replace_prints.ps1
# استبدال print بـ safePrint
$content = $content -replace "print\(", "safePrint("
```

## 📊 الإحصائيات

- **الملفات التي تحتاج تحديث**: 31 ملف
- **عدد print statements**: 318
- **الملفات المهمة (أولوية عالية)**:
  - `lib/services/*.dart` (جميع services)
  - `lib/providers/*.dart` (جميع providers)
  - `lib/screens/**/*.dart` (بعض screens)

## ✅ Checklist

- [ ] استبدال print في services
- [ ] استبدال print في providers
- [ ] استبدال print في screens المهمة
- [ ] اختبار في debug mode (يجب أن تظهر logs)
- [ ] اختبار في release mode (يجب أن تكون logs مخفية)
- [ ] التأكد من أن errors المهمة لا تزال تظهر

## 🎯 الخلاصة

**الحل الموصى به:**
1. استخدم `safePrint()` للـ quick fix
2. استخدم `AppLogger` للكود الجديد والمهم
3. لا تحذف print statements - استبدلها
4. اختبر في release mode للتأكد

**النتيجة:**
- ✅ Logs مخفية في release mode
- ✅ Logs تظهر في debug mode
- ✅ Errors المهمة لا تزال تظهر
- ✅ كود أنظف وأكثر احترافية








