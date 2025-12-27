import 'package:flutter/foundation.dart';

/// Helper class لإدارة Console Logs
/// 
/// هذا الملف يوفر دوال آمنة للطباعة التي تخفي نفسها تلقائياً في release mode
/// 
/// **استخدام:**
/// ```dart
/// import 'package:munqeth/core/utils/console_helper.dart';
/// 
/// // بدلاً من print()
/// safePrint('Debug message');
/// 
/// // للـ debug فقط
/// debugPrint('Debug info');
/// 
/// // للـ errors (تظهر في release أيضاً)
/// errorPrint('Error message');
/// ```

/// طباعة آمنة - تظهر فقط في debug mode
/// استخدم هذه الدالة بدلاً من print() مباشرة
void safePrint(Object? object) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(object);
  }
  // في release mode، لا نطبع أي شيء - مخفي تلقائياً
}

/// طباعة للـ debug فقط - تظهر فقط في debug mode
/// هذه الدالة تستخدم Flutter's debugPrint
void debugOnlyPrint(Object? object) {
  if (kDebugMode) {
    // ignore: avoid_print
    debugPrint(object);
  }
}

/// طباعة للأخطاء - تظهر في debug و release
/// استخدم هذه الدالة للأخطاء المهمة التي يجب أن تظهر في production
void errorPrint(Object? object) {
  // ignore: avoid_print
  print('[ERROR] $object');
}

/// طباعة للتحذيرات - تظهر في debug و release
/// استخدم هذه الدالة للتحذيرات المهمة
void warningPrint(Object? object) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[WARNING] $object');
  } else {
    // في release، يمكن إخفاء warnings أيضاً
    // أو طباعتها إذا أردت
    // ignore: avoid_print
    print('[WARNING] $object');
  }
}

