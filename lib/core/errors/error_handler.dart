import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'app_exception.dart';

/// معالج الأخطاء المركزي
class ErrorHandler {
  static final Logger _logger = Logger();

  /// معالجة الخطأ وعرض رسالة للمستخدم
  static void handleError(
    BuildContext? context,
    dynamic error, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    AppException exception;

    if (error is AppException) {
      exception = error;
    } else {
      exception = AppException.fromError(error, customMessage);
    }

    // تسجيل الخطأ
    _logger.e('Error: ${exception.message}', error: exception.originalError);

    // عرض رسالة للمستخدم
    if (context != null && context.mounted) {
      _showErrorDialog(context, exception, onRetry: onRetry);
    }
  }

  /// عرض رسالة خطأ للمستخدم
  static void _showErrorDialog(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              _getErrorIcon(exception.type),
              color: _getErrorColor(exception.type),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getErrorTitle(exception.type),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          exception.message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('إعادة المحاولة'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  /// عرض رسالة خطأ بسيطة (SnackBar)
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    String? customMessage,
  }) {
    AppException exception;

    if (error is AppException) {
      exception = error;
    } else {
      exception = AppException.fromError(error, customMessage);
    }

    _logger.e('Error: ${exception.message}', error: exception.originalError);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exception.message),
          backgroundColor: _getErrorColor(exception.type),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'حسناً',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// الحصول على أيقونة الخطأ
  static IconData _getErrorIcon(AppExceptionType type) {
    switch (type) {
      case AppExceptionType.network:
        return Icons.wifi_off_rounded;
      case AppExceptionType.server:
        return Icons.cloud_off_rounded;
      case AppExceptionType.authentication:
        return Icons.lock_outline_rounded;
      case AppExceptionType.validation:
        return Icons.error_outline_rounded;
      case AppExceptionType.notFound:
        return Icons.search_off_rounded;
      case AppExceptionType.unauthorized:
      case AppExceptionType.forbidden:
        return Icons.block_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }

  /// الحصول على لون الخطأ
  static Color _getErrorColor(AppExceptionType type) {
    switch (type) {
      case AppExceptionType.network:
        return Colors.orange;
      case AppExceptionType.server:
        return Colors.red;
      case AppExceptionType.authentication:
        return Colors.amber;
      case AppExceptionType.validation:
        return Colors.blue;
      case AppExceptionType.notFound:
        return Colors.grey;
      case AppExceptionType.unauthorized:
      case AppExceptionType.forbidden:
        return Colors.red.shade700;
      default:
        return Colors.red;
    }
  }

  /// الحصول على عنوان الخطأ
  static String _getErrorTitle(AppExceptionType type) {
    switch (type) {
      case AppExceptionType.network:
        return 'مشكلة في الاتصال';
      case AppExceptionType.server:
        return 'خطأ في السيرفر';
      case AppExceptionType.authentication:
        return 'مشكلة في المصادقة';
      case AppExceptionType.validation:
        return 'خطأ في البيانات';
      case AppExceptionType.notFound:
        return 'غير موجود';
      case AppExceptionType.unauthorized:
        return 'غير مصرح';
      case AppExceptionType.forbidden:
        return 'غير مسموح';
      default:
        return 'حدث خطأ';
    }
  }
}









