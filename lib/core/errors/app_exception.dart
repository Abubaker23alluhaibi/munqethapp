/// أنواع الأخطاء في التطبيق
enum AppExceptionType {
  network,
  server,
  authentication,
  validation,
  notFound,
  unauthorized,
  forbidden,
  unknown,
}

/// استثناء مخصص للتطبيق
class AppException implements Exception {
  final AppExceptionType type;
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.type,
    required this.message,
    this.code,
    this.originalError,
  });

  /// إنشاء استثناء من DioError
  factory AppException.fromDioError(dynamic error) {
    if (error?.response != null) {
      final statusCode = error.response.statusCode;
      final message = error.response.data?['message'] ?? 
                     error.response.data?['error'] ?? 
                     'حدث خطأ في السيرفر';

      switch (statusCode) {
        case 400:
          return AppException(
            type: AppExceptionType.validation,
            message: message,
            code: '400',
            originalError: error,
          );
        case 401:
          return AppException(
            type: AppExceptionType.authentication,
            message: 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى',
            code: '401',
            originalError: error,
          );
        case 403:
          return AppException(
            type: AppExceptionType.forbidden,
            message: 'ليس لديك صلاحية للوصول إلى هذا المورد',
            code: '403',
            originalError: error,
          );
        case 404:
          return AppException(
            type: AppExceptionType.notFound,
            message: 'المورد المطلوب غير موجود',
            code: '404',
            originalError: error,
          );
        case 500:
        case 502:
        case 503:
          return AppException(
            type: AppExceptionType.server,
            message: 'خطأ في السيرفر. يرجى المحاولة لاحقاً',
            code: statusCode.toString(),
            originalError: error,
          );
        default:
          return AppException(
            type: AppExceptionType.server,
            message: message,
            code: statusCode.toString(),
            originalError: error,
          );
      }
    } else if (error?.type.toString().contains('DioExceptionType.connectTimeout') == true ||
               error?.type.toString().contains('DioExceptionType.receiveTimeout') == true) {
      return AppException(
        type: AppExceptionType.network,
        message: 'انتهت مهلة الاتصال. يرجى التحقق من اتصالك بالإنترنت',
        code: 'TIMEOUT',
        originalError: error,
      );
    } else if (error?.type.toString().contains('DioExceptionType.connectionError') == true) {
      return AppException(
        type: AppExceptionType.network,
        message: 'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك',
        code: 'NO_CONNECTION',
        originalError: error,
      );
    } else {
      return AppException(
        type: AppExceptionType.unknown,
        message: 'حدث خطأ غير متوقع',
        code: 'UNKNOWN',
        originalError: error,
      );
    }
  }

  /// إنشاء استثناء من خطأ عام
  factory AppException.fromError(dynamic error, [String? message]) {
    if (error is AppException) {
      return error;
    }
    
    return AppException(
      type: AppExceptionType.unknown,
      message: message ?? error.toString(),
      originalError: error,
    );
  }

  @override
  String toString() => message;
}









