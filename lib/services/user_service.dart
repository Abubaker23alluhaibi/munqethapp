import '../models/user.dart';
import '../core/api/api_service_improved.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/app_logger.dart';
import '../utils/phone_utils.dart';

class UserService {
  final ApiServiceImproved _apiService = ApiServiceImproved();

  // التحقق من وجود مستخدم برقم الهاتف
  Future<bool> userExistsByPhone(String phone) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phone);
      final response = await _apiService.get('/users/phone/$normalizedPhone');
      return response.statusCode == 200 && response.data != null;
    } catch (e) {
      // إذا كان الخطأ 404، يعني المستخدم غير موجود
      return false;
    }
  }

  // الحصول على جميع المستخدمين
  Future<List<User>> getAllUsers() async {
    try {
      final response = await _apiService.get('/users');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting all users', e);
      return [];
    }
  }

  // الحصول على مستخدم برقم الهاتف
  Future<User?> getUserByPhone(String phone) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phone);
      final response = await _apiService.get('/users/phone/$normalizedPhone');
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error getting user by phone', e);
      return null;
    }
  }

  // إضافة مستخدم جديد
  // يعيد User عند النجاح، null عند فشل الاتصال، أو يرمي استثناء عند وجود المستخدم
  Future<User?> addUser({
    required String name,
    required String phone,
    required String password,
    String? address,
  }) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phone);
      final response = await _apiService.post('/users', data: {
        'name': name,
        'phone': normalizedPhone,
        'password': password,
        'address': address,
      });
      
      if (response.statusCode == 201 && response.data != null) {
        return User.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error adding user', e);
      
      // إذا كان الخطأ 400 (validation) ورسالة الخطأ تحتوي على "already exists"
      // نرمي استثناء خاص للمستخدم الموجود
      if (e is AppException) {
        if (e.type == AppExceptionType.validation && 
            (e.message.toLowerCase().contains('already exists') || 
             e.message.toLowerCase().contains('مسجل'))) {
          throw AppException(
            type: AppExceptionType.validation,
            message: 'هذا الرقم مسجل بالفعل',
            code: 'USER_EXISTS',
            originalError: e,
          );
        }
        // إذا كان خطأ شبكة، نرمي الاستثناء كما هو
        if (e.type == AppExceptionType.network) {
          rethrow;
        }
      }
      
      return null;
    }
  }

  // تسجيل الدخول (authenticate)
  Future<User?> authenticateUser(String phone, String password) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phone);
      final response = await _apiService.post('/users/authenticate', data: {
        'phone': normalizedPhone,
        'password': password,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error authenticating user', e);
      return null;
    }
  }

  // تحديث مستخدم
  Future<User?> updateUser(String userId, {
    String? name,
    String? phone,
    String? address,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = PhoneUtils.normalizePhone(phone);
      if (address != null) data['address'] = address;

      final response = await _apiService.put('/users/$userId', data: data);
      
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error updating user', e);
      return null;
    }
  }

  // حذف مستخدم
  Future<bool> deleteUser(String userId) async {
    try {
      final response = await _apiService.delete('/users/$userId');
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Error deleting user', e);
      return false;
    }
  }

  // تحديث FCM token للمستخدم برقم الهاتف
  Future<bool> updateFcmTokenByPhone(String phone, String fcmToken) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phone);
      AppLogger.d('Updating FCM token for user phone: $normalizedPhone');
      AppLogger.d('FCM token: ${fcmToken.substring(0, 20)}...');
      
      final response = await _apiService.put('/users/phone/$normalizedPhone/fcm-token', data: {
        'fcmToken': fcmToken,
      });
      
      AppLogger.d('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        AppLogger.i('✅ FCM token updated successfully for user: $normalizedPhone');
        return true;
      } else {
        AppLogger.w('Failed to update FCM token: status ${response.statusCode}');
        AppLogger.d('Response data: ${response.data}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error updating FCM token for user phone: $phone', e, stackTrace);
      return false;
    }
  }

  // تحديث FCM token للمستخدم بـ ID
  Future<bool> updateFcmToken(String userId, String fcmToken) async {
    try {
      AppLogger.d('Updating FCM token for user ID: $userId');
      AppLogger.d('FCM token: ${fcmToken.substring(0, 20)}...');
      
      final response = await _apiService.put('/users/$userId/fcm-token', data: {
        'fcmToken': fcmToken,
      });
      
      AppLogger.d('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        AppLogger.i('✅ FCM token updated successfully for user ID: $userId');
        return true;
      } else {
        AppLogger.w('Failed to update FCM token: status ${response.statusCode}');
        AppLogger.d('Response data: ${response.data}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error updating FCM token for user ID: $userId', e, stackTrace);
      return false;
    }
  }
}