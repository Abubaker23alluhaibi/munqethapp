import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Logger موحد للتطبيق
/// يستخدم Logger في debug mode فقط، ولا يطبع أي شيء في release mode
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Log debug message (يظهر فقط في debug mode)
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log info message (يظهر فقط في debug mode)
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log warning message (يظهر فقط في debug mode)
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
    // في release mode، لا نطبع warnings
  }

  /// Log error message (يظهر فقط في debug mode)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
    // في release mode، لا نطبع errors في console
    // يمكن إرسالها إلى Crashlytics أو خدمة مراقبة الأخطاء بدلاً من ذلك
  }

  /// Log fatal error (يظهر دائماً)
  static void f(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

/// دالة آمنة للطباعة - تخفي print في release mode
/// استخدم هذه الدالة بدلاً من print() مباشرة
/// 
/// مثال:
/// ```dart
/// safePrint('Debug message'); // يظهر فقط في debug mode
/// ```
void safePrint(Object? object) {
  if (kDebugMode) {
    // ignore: avoid_print
    AppLogger.d(object.toString());
  }
  // في release mode، لا نطبع أي شيء
}

