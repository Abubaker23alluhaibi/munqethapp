import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

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

  /// Log warning message (يظهر في debug و release)
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    } else {
      // في release mode، نطبع warnings فقط كـ print بسيط
      // يمكن إزالة هذا السطر إذا أردت إخفاء warnings أيضاً
      // ignore: avoid_print
      print('[WARNING] $message');
    }
  }

  /// Log error message (يظهر في debug و release)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else {
      // في release mode، نطبع errors بشكل محدود (بدون stack traces حساسة)
      // ignore: avoid_print
      print('[ERROR] $message');
      if (error != null) {
        // طباعة نوع الخطأ فقط بدون تفاصيل حساسة
        if (error is DioException) {
          // ignore: avoid_print
          print('[ERROR] Network error: ${error.type}');
          // ignore: avoid_print
          print('[ERROR] Response status: ${error.response?.statusCode}');
          // لا نطبع response data لأنه قد يحتوي على معلومات حساسة
          // ignore: avoid_print
          print('[ERROR] Request path: ${error.requestOptions.path}');
        } else {
          // طباعة نوع الخطأ فقط
          // ignore: avoid_print
          print('[ERROR] Error type: ${error.runtimeType}');
        }
      }
      // لا نطبع Stack Traces في production لأسباب أمنية
      // يمكن إرسالها إلى Crashlytics بدلاً من ذلك
    }
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
    print(object);
  }
  // في release mode، لا نطبع أي شيء
}

