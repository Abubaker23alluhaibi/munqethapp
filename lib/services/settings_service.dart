import '../models/app_settings.dart';
import '../core/api/api_service_improved.dart';
import '../core/utils/app_logger.dart';

/// جلب إعدادات التطبيق (مسافات، أسعار، أوقات) من الـ API.
/// يمكن لأي مستخدم جلبها بدون تسجيل دخول أدمن.
class SettingsService {
  static final SettingsService _instance = SettingsService._();
  factory SettingsService() => _instance;

  SettingsService._();

  final ApiServiceImproved _api = ApiServiceImproved();
  AppSettings? _cached;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 5);

  /// جلب الإعدادات (مع تخزين مؤقت)
  Future<AppSettings> getAppSettings({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null && _cacheTime != null && DateTime.now().difference(_cacheTime!) < _cacheMaxAge) {
      return _cached!;
    }
    try {
      final response = await _api.get('/settings');
      if (response.statusCode == 200 && response.data != null) {
        final map = response.data as Map<String, dynamic>;
        _cached = AppSettings.fromJson(map);
        _cacheTime = DateTime.now();
        return _cached!;
      }
    } catch (e) {
      AppLogger.e('Error fetching app settings', e);
    }
    _cached ??= AppSettings.defaults;
    return _cached!;
  }

  /// إبطال التخزين المؤقت (مثلاً بعد تحديث الأدمن للإعدادات)
  void invalidateCache() {
    _cached = null;
    _cacheTime = null;
  }
}
