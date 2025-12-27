import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../errors/app_exception.dart';
import '../storage/secure_storage_service.dart';
import '../../utils/constants.dart';

/// خدمة API محسّنة مع معالجة أخطاء شاملة
class ApiServiceImproved {
  late final Dio _dio;
  final Logger _logger = Logger();

  ApiServiceImproved() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // إضافة Interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // إضافة Token للطلبات
          final token = await SecureStorageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // إذا كانت البيانات FormData، إزالة Content-Type للسماح لـ Dio بتعيينه تلقائياً
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }

          _logger.d('Request: ${options.method} ${options.path}');
          _logger.d('Headers: ${options.headers}');
          if (options.queryParameters != null && options.queryParameters!.isNotEmpty) {
            _logger.d('Query Parameters: ${options.queryParameters}');
          }
          if (options.data != null) {
            _logger.d('Data: ${options.data}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response: ${response.statusCode}');
          _logger.d('Response headers: ${response.headers}');
          if (response.data != null) {
            _logger.d('Response data type: ${response.data.runtimeType}');
            if (response.data is List) {
              _logger.d('Response data is List with ${(response.data as List).length} items');
            } else if (response.data is Map) {
              _logger.d('Response data is Map with keys: ${(response.data as Map).keys}');
            } else {
              _logger.d('Response data: ${response.data}');
            }
          } else {
            _logger.w('Response data is null');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.e('Error: ${error.message}');
          _logger.e('Error Data: ${error.response?.data}');
          
          // تحويل DioError إلى AppException
          final appException = AppException.fromDioError(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: appException,
            ),
          );
        },
      ),
    );

    // إضافة Retry Interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logger: _logger,
      ),
    );
  }

  /// GET Request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e, 'حدث خطأ غير متوقع');
    }
  }

  /// POST Request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e, 'حدث خطأ غير متوقع');
    }
  }

  /// PUT Request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e, 'حدث خطأ غير متوقع');
    }
  }

  /// DELETE Request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e, 'حدث خطأ غير متوقع');
    }
  }

  /// تحديث Base URL
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  /// تحديث Token
  Future<void> updateToken(String? token) async {
    if (token != null && token.isNotEmpty) {
      await SecureStorageService.setToken(token);
    } else {
      await SecureStorageService.deleteToken();
    }
  }
}

/// Retry Interceptor لإعادة المحاولة عند الفشل
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final Logger logger;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    required this.logger,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = options.extra['retryCount'] ?? 0;

    // إعادة المحاولة فقط للأخطاء الشبكية
    if (retryCount < maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.receiveTimeout ||
         err.type == DioExceptionType.connectionError)) {
      options.extra['retryCount'] = retryCount + 1;

      logger.w('Retrying request (${retryCount + 1}/$maxRetries): ${options.path}');

      await Future.delayed(retryDelay);

      try {
        final response = await dio.fetch(options);
        return handler.resolve(response);
      } catch (e) {
        if (retryCount + 1 >= maxRetries) {
          return handler.reject(err);
        }
      }
    }

    return handler.reject(err);
  }
}








