import '../models/driver.dart';
import '../core/api/api_service_improved.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import 'dart:convert';

class DriverService {
  final ApiServiceImproved _apiService = ApiServiceImproved();
  static const String _storageKey = 'driver_data';
  static const String _loggedInKey = 'driver_logged_in';

  // تسجيل الدخول (استخدام API للتحقق من البيانات)
  // يمكن البحث بـ: driverId (المعرف المخصص), code, أو _id من MongoDB
  Future<Driver?> login(String id, String code) async {
    try {
      AppLogger.d('Attempting driver login with ID: $id');
      
      // الحصول على السائق من API (يمكن البحث بـ driverId, code, أو _id)
      final response = await _apiService.get('/drivers/$id');
      
      if (response.statusCode == 200 && response.data != null) {
        final driverData = response.data as Map<String, dynamic>;
        AppLogger.d('Driver found: ${driverData['name']}, driverId: ${driverData['driverId']}');
        
        final driver = Driver.fromJson(driverData);
        
        // التحقق من الكود
        if (driver.code == code.trim()) {
          AppLogger.d('Code matches! Logging in...');
          // التأكد من أن driver.id يحتوي على _id من MongoDB
          final mongoId = driverData['_id']?.toString() ?? driverData['id']?.toString() ?? driver.id;
          if (mongoId != driver.id) {
            // إذا كان _id مختلف، نحدث driver.id
            final updatedDriver = driver.copyWith(id: mongoId);
            
            // حفظ بيانات السائق محلياً مع _id الصحيح
            final driverJson = updatedDriver.toJson();
            await SecureStorageService.setString(_storageKey, jsonEncode(driverJson));
            await SecureStorageService.setBool(_loggedInKey, true);
            
            AppLogger.i('Driver logged in successfully: ${updatedDriver.name}');
            return updatedDriver;
          }
          
          // حفظ بيانات السائق محلياً للمستخدم لاحقاً
          await SecureStorageService.setString(_storageKey, jsonEncode(driver.toJson()));
          await SecureStorageService.setBool(_loggedInKey, true);
          
          AppLogger.i('Driver logged in successfully: ${driver.name}');
          return driver;
        } else {
          AppLogger.w('Driver code mismatch');
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error in driver login', e);
      return null;
    }
  }

  // الحصول على السائق الحالي من التخزين المحلي
  Future<Driver?> getCurrentDriver() async {
    try {
      final data = await SecureStorageService.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        return Driver.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (e) {
      AppLogger.e('Error getting current driver', e);
    }
    return null;
  }

  // التحقق من حالة تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final loggedIn = await SecureStorageService.getBool(_loggedInKey);
    return loggedIn ?? false;
  }

  // تحديث حالة السائق
  Future<bool> updateDriver(Driver driver) async {
    try {
      final response = await _apiService.put('/drivers/${driver.id}', data: driver.toJson());
      if (response.statusCode == 200) {
        // تحديث البيانات المحلية
        await SecureStorageService.setString(_storageKey, jsonEncode(driver.toJson()));
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error updating driver', e);
      return false;
    }
  }

  // تحديث موقع السائق
  Future<bool> updateDriverLocation(String driverId, double latitude, double longitude) async {
    try {
      final response = await _apiService.put('/drivers/$driverId/location', data: {
        'latitude': latitude,
        'longitude': longitude,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Error updating driver location', e);
      return false;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    await SecureStorageService.remove(_storageKey);
    await SecureStorageService.remove(_loggedInKey);
  }

  // الحصول على جميع السائقين
  Future<List<Driver>> getAllDrivers({String? serviceType, bool? isAvailable}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (serviceType != null) queryParams['serviceType'] = serviceType;
      if (isAvailable != null) queryParams['isAvailable'] = isAvailable.toString();

      final response = await _apiService.get('/drivers', queryParameters: queryParams);
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Driver.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      AppLogger.w('getAllDrivers: Response status ${response.statusCode} or null data');
      return [];
    } catch (e, stackTrace) {
      AppLogger.e('Error getting all drivers', e, stackTrace);
      // في release mode، نريد رؤية الأخطاء لكن نعيد قائمة فارغة لتجنب كسر UI
      return [];
    }
  }

  // الحصول على السائقين المتاحين
  Future<List<Driver>> getAvailableDrivers({String? serviceType}) async {
    return await getAllDrivers(serviceType: serviceType, isAvailable: true);
  }

  // الحصول على السائقين حسب نوع الخدمة
  Future<List<Driver>> getDriversByServiceType(String serviceType) async {
    return await getAvailableDrivers(serviceType: serviceType);
  }

  // العثور على أقرب سائق للعميل (استخدام API) - يعيد سائق واحد للتوافق مع الكود القديم
  Future<Driver?> findNearestDriver(double customerLat, double customerLng, String serviceType) async {
    try {
      final response = await _apiService.get('/drivers/nearest', queryParameters: {
        'latitude': customerLat.toString(),
        'longitude': customerLng.toString(),
        'serviceType': serviceType,
        'limit': '4', // طلب 4 سائقين
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // API returns { driver: {...}, drivers: [...], distance: ..., distances: [...] }
        // للتوافق مع الكود القديم، نعيد السائق الأول
        if (data['driver'] != null) {
          return Driver.fromJson(data['driver'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error finding nearest driver', e);
      return null;
    }
  }

  // العثور على أقرب 4 سائقين للعميل (استخدام API)
  Future<List<Driver>> findNearestDrivers(double customerLat, double customerLng, String serviceType, {int limit = 4}) async {
    try {
      final response = await _apiService.get('/drivers/nearest', queryParameters: {
        'latitude': customerLat.toString(),
        'longitude': customerLng.toString(),
        'serviceType': serviceType,
        'limit': limit.toString(),
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // API returns { drivers: [...], distances: [...] }
        if (data['drivers'] != null) {
          final List<dynamic> driversList = data['drivers'];
          return driversList
              .map((json) => Driver.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      AppLogger.e('Error finding nearest drivers', e);
      return [];
    }
  }

  // الحصول على سائق بالـ ID
  Future<Driver?> getDriverById(String id) async {
    try {
      final response = await _apiService.get('/drivers/$id');
      if (response.statusCode == 200 && response.data != null) {
        return Driver.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error getting driver by id', e);
      return null;
    }
  }

  // Backward compatibility - البحث عن سائق بالإيدي فقط
  Future<Driver?> findDriverById(String id) async {
    return await getDriverById(id);
  }

  // تحديث FCM token للسائق بـ MongoDB ID
  Future<bool> updateFcmToken(String driverId, String fcmToken) async {
    try {
      AppLogger.d('Updating FCM token for driver MongoDB ID: $driverId');
      AppLogger.d('FCM token: ${fcmToken.substring(0, 20)}...');
      
      final response = await _apiService.put('/drivers/$driverId/fcm-token', data: {
        'fcmToken': fcmToken,
      });
      
      AppLogger.d('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        AppLogger.i('✅ FCM token updated successfully for driver MongoDB ID: $driverId');
        // تحديث البيانات المحلية إذا كان هذا السائق هو المسجل دخوله
        final currentDriver = await getCurrentDriver();
        if (currentDriver != null && currentDriver.id == driverId) {
          final updatedDriver = currentDriver.copyWith(fcmToken: fcmToken);
          await SecureStorageService.setString(_storageKey, jsonEncode(updatedDriver.toJson()));
          AppLogger.d('Updated local driver data with FCM token');
        }
        return true;
      } else {
        AppLogger.w('Failed to update FCM token: status ${response.statusCode}');
        AppLogger.d('Response data: ${response.data}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error updating FCM token for driver MongoDB ID: $driverId', e, stackTrace);
      return false;
    }
  }

  // تحديث FCM token للسائق بـ Driver ID (المعرف المخصص)
  Future<bool> updateFcmTokenByDriverId(String driverId, String fcmToken) async {
    try {
      AppLogger.i('📤 ===== UPDATING FCM TOKEN FOR DRIVER =====');
      AppLogger.i('   Driver ID: $driverId');
      AppLogger.i('   FCM Token: ${fcmToken.substring(0, 30)}...');
      AppLogger.i('   Token Length: ${fcmToken.length}');
      AppLogger.i('   Endpoint: PUT /drivers/driverId/$driverId/fcm-token');
      
      final response = await _apiService.put('/drivers/driverId/$driverId/fcm-token', data: {
        'fcmToken': fcmToken,
      });
      
      AppLogger.i('📥 Response received - Status: ${response.statusCode}');
      AppLogger.d('   Response data: ${response.data}');
      
      if (response.statusCode == 200) {
        AppLogger.i('✅✅✅ FCM token updated successfully for driver: $driverId');
        // تحديث البيانات المحلية إذا كان هذا السائق هو المسجل دخوله
        final currentDriver = await getCurrentDriver();
        if (currentDriver != null && currentDriver.driverId == driverId.toUpperCase()) {
          final updatedDriver = currentDriver.copyWith(fcmToken: fcmToken);
          await SecureStorageService.setString(_storageKey, jsonEncode(updatedDriver.toJson()));
          AppLogger.d('Updated local driver data with FCM token');
        }
        return true;
      } else {
        AppLogger.w('Failed to update FCM token: status ${response.statusCode}');
        AppLogger.d('Response data: ${response.data}');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error updating FCM token for driver ID: $driverId', e, stackTrace);
      return false;
    }
  }
}