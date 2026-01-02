import '../models/admin.dart';
import '../models/supermarket.dart';
import '../models/driver.dart';
import '../models/order.dart';
import '../core/api/api_service_improved.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/app_logger.dart';
import 'storage_service.dart';
import 'supermarket_service.dart';
import 'driver_service.dart';
import 'order_service.dart';
import 'dart:convert';
import 'dart:math' as math;

class AdminService {
  final ApiServiceImproved _apiService = ApiServiceImproved();
  static const String _storageKey = 'admin_data';
  static const String _loggedInKey = 'admin_logged_in';
  static const String _supermarketsKey = 'admin_supermarkets';
  static const String _driversKey = 'admin_drivers';

  // Admin حساب تجريبي
  static final Admin _mockAdmin = Admin(
    id: 'ADMIN001',
    code: 'admin123',
    name: 'مدير النظام',
    email: 'admin@munqeth.com',
    phone: '07700000000',
  );

  // تسجيل الدخول (استخدام API للتحقق من البيانات)
  Future<Admin?> login(String id, String code) async {
    try {
      // إرسال طلب تسجيل الدخول إلى API
      final cleanId = id.trim().toUpperCase();
      final cleanCode = code.trim();
      
      AppLogger.d('Attempting admin login: ID=$cleanId, Code=$cleanCode');
      
      final response = await _apiService.post('/admins/login', data: {
        'id': cleanId,
        'code': cleanCode,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final adminData = response.data as Map<String, dynamic>;
        final admin = Admin.fromJson(adminData);
        
        AppLogger.i('Admin login successful: ${admin.name}');
        
        // حفظ بيانات المدير محلياً
        await SecureStorageService.setString(_storageKey, jsonEncode(admin.toJson()));
        await SecureStorageService.setBool(_loggedInKey, true);
        return admin;
      }
      AppLogger.w('Admin login failed: Status ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.e('Error in admin login', e);
      // إذا كان الخطأ 404 أو 401، يعني admin غير موجود أو الكود خاطئ
      if (e is AppException) {
        if (e.type == AppExceptionType.notFound) {
          AppLogger.w('Admin not found');
        } else if (e.type == AppExceptionType.authentication) {
          AppLogger.w('Invalid admin code');
        }
      }
      return null;
    }
  }

  // الحصول على المدير الحالي
  Future<Admin?> getCurrentAdmin() async {
    try {
      final data = await SecureStorageService.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        return Admin.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (e) {
      AppLogger.e('Error getting current admin: $e');
    }
    return null;
  }

  // التحقق من حالة تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final loggedIn = await SecureStorageService.getBool(_loggedInKey);
    return loggedIn ?? false;
  }

  // تسجيل الخروج
  Future<void> logout() async {
    await SecureStorageService.remove(_storageKey);
    await SecureStorageService.remove(_loggedInKey);
  }

  // التحقق من وجود admin بالكود
  Future<bool> adminExistsById(String id) async {
    try {
      final cleanId = id.trim().toUpperCase();
      final response = await _apiService.get('/admins/exists/$cleanId');
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data['exists'] == true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error checking admin existence: $e');
      return false;
    }
  }

  // ========== إدارة السوبر ماركت ==========

  // الحصول على جميع السوبر ماركت
  Future<List<Supermarket>> getAllSupermarkets() async {
    try {
      // جلب البيانات من API
      final response = await _apiService.get('/supermarkets');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        final supermarkets = jsonList
            .map((json) => Supermarket.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // حفظ البيانات محلياً للاستخدام المؤقت
        await _saveSupermarkets(supermarkets);
        
        return supermarkets;
      }
    } catch (e) {
      AppLogger.e('Error getting supermarkets from API: $e');
      // في حالة فشل API، محاولة جلب البيانات المحلية
      try {
        final data = StorageService.getString(_supermarketsKey);
        if (data != null && data.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(data);
          return jsonList
              .map((json) => Supermarket.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } catch (e2) {
        AppLogger.e('Error getting local supermarkets: $e2');
      }
    }
    return [];
  }

  // إضافة سوبر ماركت جديد
  Future<bool> addSupermarket(Supermarket supermarket) async {
    try {
      // إعداد البيانات للإنشاء (بدون id لأن الـ backend يولد _id تلقائياً)
      final data = supermarket.toJson();
      data.remove('id'); // إزالة id لأن الـ backend يولد _id تلقائياً
      
      // إرسال طلب إنشاء سوبر ماركت إلى API
      final response = await _apiService.post('/supermarkets', data: data);
      
      if (response.statusCode == 201) {
        AppLogger.d('Supermarket created successfully: ${supermarket.name}');
        return true;
      }
      AppLogger.e('Failed to create supermarket: Status ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.e('Error creating supermarket: $e');
      return false;
    }
  }

  // تحديث سوبر ماركت
  Future<bool> updateSupermarket(Supermarket supermarket) async {
    try {
      // إعداد البيانات للتحديث (بدون id لأن الـ backend يستخدم _id من URL)
      final data = supermarket.toJson();
      data.remove('id'); // إزالة id لأن الـ backend يستخدم _id من URL
      
      // إرسال طلب تحديث سوبر ماركت إلى API
      final response = await _apiService.put('/supermarkets/${supermarket.id}', data: data);
      
      if (response.statusCode == 200) {
        AppLogger.d('Supermarket updated successfully: ${supermarket.name}');
        return true;
      }
      AppLogger.e('Failed to update supermarket: Status ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.e('Error updating supermarket: $e');
      return false;
    }
  }

  // حذف سوبر ماركت
  Future<bool> deleteSupermarket(String supermarketId) async {
    try {
      // إرسال طلب حذف سوبر ماركت إلى API
      final response = await _apiService.delete('/supermarkets/$supermarketId');
      
      if (response.statusCode == 200) {
        AppLogger.d('Supermarket deleted successfully: $supermarketId');
        return true;
      }
      AppLogger.e('Failed to delete supermarket: Status ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.e('Error deleting supermarket: $e');
      return false;
    }
  }

  // إضافة موقع لسوبر ماركت
  Future<Supermarket?> addLocationToSupermarket(
    String supermarketId,
    String? name,
    double latitude,
    double longitude,
    String? address,
  ) async {
    try {
      final response = await _apiService.post(
        '/supermarkets/$supermarketId/locations',
        data: {
          if (name != null && name.isNotEmpty) 'name': name,
          'latitude': latitude,
          'longitude': longitude,
          if (address != null && address.isNotEmpty) 'address': address,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Supermarket.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error adding location: $e');
      return null;
    }
  }

  // تحديث موقع لسوبر ماركت
  Future<Supermarket?> updateLocationInSupermarket(
    String supermarketId,
    String locationId,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
  ) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (address != null) data['address'] = address;

      final response = await _apiService.put(
        '/supermarkets/$supermarketId/locations/$locationId',
        data: data,
      );

      if (response.statusCode == 200 && response.data != null) {
        return Supermarket.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error updating location: $e');
      return null;
    }
  }

  // حذف موقع من سوبر ماركت
  Future<Supermarket?> deleteLocationFromSupermarket(
    String supermarketId,
    String locationId,
  ) async {
    try {
      final response = await _apiService.delete(
        '/supermarkets/$supermarketId/locations/$locationId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return Supermarket.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error deleting location: $e');
      return null;
    }
  }

  Future<void> _saveSupermarkets(List<Supermarket> supermarkets) async {
    final json = supermarkets.map((s) => s.toJson()).toList();
    await StorageService.setString(_supermarketsKey, jsonEncode(json));
  }

  // الحصول على أو إنشاء سوبر ماركت المنقذ
  Future<Supermarket> getOrCreateAdminSupermarket() async {
    const String munqethShopCode = 'munqeth123';
    
    try {
      // البحث عن سوبر ماركت المنقذ في قاعدة البيانات
      final allSupermarkets = await getAllSupermarkets();
      
      // البحث بالكود
      try {
        final existingShop = allSupermarkets.firstWhere(
          (s) => s.code.toLowerCase() == munqethShopCode.toLowerCase(),
        );
        AppLogger.d('Found existing Munqeth shop: ${existingShop.name}');
        return existingShop;
      } catch (e) {
        // لم يتم العثور عليه، سيتم إنشاؤه أدناه
        AppLogger.d('Munqeth shop not found, creating new one...');
      }

      // إذا لم يكن موجوداً، إنشاؤه في قاعدة البيانات
      final munqethShop = Supermarket(
        id: '', // سيتم توليده من الـ backend
        code: munqethShopCode,
        name: 'تسوق المنقذ',
        address: 'بغداد',
        phone: '07700000000',
        email: 'shop@munqeth.com',
        image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80',
        latitude: 33.3152,
        longitude: 44.3661,
      );

      // إنشاء سوبر ماركت في قاعدة البيانات
      final success = await addSupermarket(munqethShop);
      
      if (success) {
        // جلب السوبر ماركتات مرة أخرى للحصول على البيانات المحدثة
        final updatedSupermarkets = await getAllSupermarkets();
        try {
          final createdShop = updatedSupermarkets.firstWhere(
            (s) => s.code.toLowerCase() == munqethShopCode.toLowerCase(),
          );
          AppLogger.d('Created Munqeth shop successfully: ${createdShop.name}');
          return createdShop;
        } catch (e) {
          AppLogger.e('Error finding created shop: $e');
          // في حالة الخطأ، إرجاع البيانات الأصلية
          return munqethShop;
        }
      } else {
        AppLogger.d('Failed to create Munqeth shop');
        // في حالة فشل الإنشاء، إرجاع البيانات الأصلية
        return munqethShop;
      }
    } catch (e) {
      AppLogger.e('Error in getOrCreateAdminSupermarket: $e');
      // في حالة الخطأ، إنشاء سوبر ماركت محلياً كـ fallback
      final munqethShop = Supermarket(
        id: 'MUNQETH_SHOP',
        code: munqethShopCode,
        name: 'تسوق المنقذ',
        address: 'بغداد',
        phone: '07700000000',
        email: 'shop@munqeth.com',
        image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80',
        latitude: 33.3152,
        longitude: 44.3661,
      );
      return munqethShop;
    }
  }

  // ========== إدارة السائقين ==========

  // الحصول على جميع السائقين
  Future<List<Driver>> getAllDrivers() async {
    try {
      // جلب البيانات من API
      final response = await _apiService.get('/drivers');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        AppLogger.d('getAllDrivers: Received ${jsonList.length} drivers from API');
        final allDrivers = jsonList
            .map((json) => Driver.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // تصفية السائقين المحذوفين
        final drivers = allDrivers.where((driver) {
          // استبعاد السائقين المحذوفين (isDeleted == true) أو غير النشطين (isActive == false)
          final isDeleted = driver.isDeleted == true;
          final isActive = driver.isActive ?? true; // إذا لم يكن موجود، نعتبره نشط
          return !isDeleted && isActive;
        }).toList();
        
        AppLogger.d('getAllDrivers: Filtered ${allDrivers.length} drivers to ${drivers.length} (removed ${allDrivers.length - drivers.length} deleted/inactive)');
        
        // طباعة تفاصيل السائقين للتأكد
        AppLogger.d('getAllDrivers: Parsed ${drivers.length} drivers');
        for (var driver in drivers) {
          AppLogger.d('  - ${driver.name} (${driver.driverId}): ${driver.serviceType}');
        }
        
        // حفظ البيانات محلياً للاستخدام المؤقت
        await _saveDrivers(drivers);
        
        return drivers;
      } else {
        AppLogger.d('getAllDrivers: API returned status ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('Error getting drivers from API: $e');
      // في حالة فشل API، محاولة جلب البيانات المحلية
      try {
        final data = StorageService.getString(_driversKey);
        if (data != null && data.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(data);
          AppLogger.d('getAllDrivers: Loaded ${jsonList.length} drivers from local storage');
          final allDrivers = jsonList
              .map((json) => Driver.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // تصفية السائقين المحذوفين
          final drivers = allDrivers.where((driver) {
            final isDeleted = driver.isDeleted == true;
            final isActive = driver.isActive ?? true;
            return !isDeleted && isActive;
          }).toList();
          
          AppLogger.d('getAllDrivers: Filtered ${allDrivers.length} drivers to ${drivers.length} from local storage');
          return drivers;
        } else {
          AppLogger.d('getAllDrivers: No local data found');
        }
      } catch (e2) {
        AppLogger.e('Error getting local drivers: $e2');
      }
    }
    AppLogger.d('getAllDrivers: Returning empty list');
    return [];
  }

  // الحصول على السائقين حسب نوع الخدمة
  Future<List<Driver>> getDriversByServiceType(String serviceType) async {
    final drivers = await getAllDrivers();
    return drivers.where((d) => d.serviceType == serviceType).toList();
  }

  // التحقق من وجود سائق بالمعرف أو الهاتف (الكود يمكن أن يتكرر لأنه رمز الدخول)
  Future<Map<String, bool>> checkDriverExists({
    String? driverId,
    String? phone,
  }) async {
    try {
      final allDrivers = await getAllDrivers();
      
      bool driverIdExists = false;
      bool phoneExists = false;
      
      if (driverId != null && driverId.isNotEmpty) {
        driverIdExists = allDrivers.any((d) => 
          d.driverId.toUpperCase() == driverId.toUpperCase()
        );
      }
      
      if (phone != null && phone.isNotEmpty) {
        phoneExists = allDrivers.any((d) => 
          d.phone.trim() == phone.trim()
        );
      }
      
      return {
        'driverId': driverIdExists,
        'phone': phoneExists,
      };
    } catch (e) {
      AppLogger.e('Error checking driver existence: $e');
      return {
        'driverId': false,
        'phone': false,
      };
    }
  }

  // إضافة سائق جديد
  Future<Map<String, dynamic>> addDriver(Driver driver) async {
    try {
      // التحقق من وجود البيانات المكررة أولاً (المعرف والهاتف فقط، الكود يمكن أن يتكرر)
      final exists = await checkDriverExists(
        driverId: driver.driverId,
        phone: driver.phone,
      );
      
      if (exists['driverId'] == true) {
        return {
          'success': false,
          'error': 'المعرف (${driver.driverId}) موجود مسبقاً',
        };
      }
      
      if (exists['phone'] == true) {
        return {
          'success': false,
          'error': 'رقم الهاتف (${driver.phone}) موجود مسبقاً',
        };
      }
      
      // إعداد البيانات للإنشاء (بدون id لأن الـ backend يولد _id تلقائياً)
      final data = driver.toJson();
      data.remove('id'); // إزالة id لأن الـ backend يولد _id تلقائياً
      data.remove('_id'); // إزالة _id أيضاً
      
      // التأكد من وجود driverId
      if (data['driverId'] == null || data['driverId'].toString().isEmpty) {
        AppLogger.e('ERROR: driverId is missing in data!');
        AppLogger.d('Driver driverId: ${driver.driverId}');
        AppLogger.d('Data keys: ${data.keys}');
        return {
          'success': false,
          'error': 'المعرف مطلوب',
        };
      }
      
      // طباعة البيانات المرسلة للتأكد
      AppLogger.d('Sending driver data to API:');
      AppLogger.d('driverId: ${data['driverId']}');
      AppLogger.d('code: ${data['code']}');
      AppLogger.d('name: ${data['name']}');
      AppLogger.d('phone: ${data['phone']}');
      
      // إرسال طلب إنشاء سائق إلى API
      final response = await _apiService.post('/drivers', data: data);
      
      if (response.statusCode == 201) {
        AppLogger.d('Driver created successfully: ${driver.name} with driverId: ${driver.driverId}');
        return {
          'success': true,
          'error': null,
          'driver': response.data, // إرجاع بيانات السائق الكاملة
        };
      }
      
      // محاولة قراءة رسالة الخطأ من الـ backend
      String errorMessage = 'فشل إنشاء الحساب';
      try {
        if (response.data is Map && response.data['error'] != null) {
          errorMessage = response.data['error'].toString();
        }
      } catch (e) {
        // تجاهل خطأ قراءة الرسالة
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      AppLogger.e('Error creating driver: $e');
      
      // محاولة استخراج رسالة الخطأ من الاستثناء
      String errorMessage = 'حدث خطأ أثناء إنشاء الحساب';
      if (e.toString().contains('already exists')) {
        if (e.toString().contains('driverId')) {
          errorMessage = 'المعرف موجود مسبقاً';
        } else if (e.toString().contains('phone')) {
          errorMessage = 'رقم الهاتف موجود مسبقاً';
        }
        // لا نتحقق من الكود لأنه يمكن أن يتكرر
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // تحديث سائق
  // originalCode: الرمز الأصلي قبل التعديل (للمقارنة)
  Future<bool> updateDriver(Driver driver, {String? originalCode}) async {
    try {
      AppLogger.d('updateDriver: Updating driver ${driver.id} (${driver.driverId})');
      AppLogger.d('updateDriver: Original code: $originalCode');
      AppLogger.d('updateDriver: New code: ${driver.code}');
      
      // إعداد البيانات للتحديث (بدون id لأن الـ backend يستخدم _id من URL)
      final data = driver.toJson();
      data.remove('id'); // إزالة id لأن الـ backend يستخدم _id من URL
      
      // السماح بالرمز المكرر - الباكند يدعم ذلك الآن
      // إذا كان الرمز لم يتغير، لا حاجة لإرساله (اختياري)
      if (originalCode != null && originalCode == driver.code) {
        AppLogger.d('updateDriver: Code unchanged, keeping in update data');
        // نترك code في البيانات حتى لو لم يتغير (للتأكد من التحديث)
      } else if (originalCode != null && originalCode != driver.code) {
        AppLogger.d('updateDriver: Code changed from "$originalCode" to "${driver.code}"');
        AppLogger.d('updateDriver: Allowing duplicate code');
      }
      
      AppLogger.d('updateDriver: Sending data with keys: ${data.keys}');
      
      // إرسال طلب تحديث سائق إلى API
      // الباكند يسمح بالرمز المكرر تلقائياً، لا حاجة لمعاملات خاصة
      final queryParams = <String, String>{};
      
      final response = await _apiService.put(
        '/drivers/${driver.id}',
        data: data,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        AppLogger.d('Driver updated successfully: ${driver.name}');
        return true;
      }
      
      AppLogger.d('Failed to update driver: Status ${response.statusCode}');
      if (response.data != null) {
        AppLogger.d('Response data: ${response.data}');
        
        // محاولة قراءة رسالة الخطأ
        try {
          if (response.data is Map) {
            final errorMsg = response.data['error'] ?? response.data['message'];
            if (errorMsg != null) {
              AppLogger.e('Error message from server: $errorMsg');
            }
          }
        } catch (e) {
          AppLogger.d('Could not parse error message: $e');
        }
      }
      return false;
    } catch (e) {
      AppLogger.e('Error updating driver: $e');
      
      // التحقق من نوع الخطأ
      if (e.toString().contains('E11000') || e.toString().contains('duplicate key')) {
        AppLogger.e('ERROR: Duplicate key error. MongoDB has unique constraint on code field.');
        AppLogger.d('The server needs to handle code updates by excluding current driver from unique check.');
        AppLogger.d('Sent originalCode: $originalCode, currentDriverId: ${driver.id}');
      } else if (e.toString().contains('code') || e.toString().contains('رمز')) {
        AppLogger.e('ERROR: Code validation failed. The server may not support skipCodeValidation.');
        AppLogger.d('Please ensure the server allows duplicate codes during updates.');
      }
      
      return false;
    }
  }

  // حذف سائق
  // driverId هنا هو MongoDB _id وليس المعرف المخصص
  Future<bool> deleteDriver(String driverId) async {
    try {
      AppLogger.d('Attempting to delete driver with ID: $driverId');
      
      // محاولة استخدام DELETE endpoint
      try {
        final response = await _apiService.delete('/drivers/$driverId');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          AppLogger.d('Driver deleted successfully: $driverId');
          return true;
        }
        AppLogger.d('Failed to delete driver: Status ${response.statusCode}');
        if (response.data != null) {
          AppLogger.d('Response data: ${response.data}');
        }
      } catch (deleteError) {
        AppLogger.d('DELETE method failed, trying alternative methods...');
        AppLogger.e('Error: $deleteError');
        
        // محاولة استخدام PUT مع data للتعطيل بدلاً من الحذف
        try {
          final response = await _apiService.put(
            '/drivers/$driverId',
            data: {
              'isDeleted': true,
              'isActive': false,
            },
          );
          
          if (response.statusCode == 200) {
            AppLogger.d('Driver marked as deleted successfully: $driverId');
            return true;
          }
        } catch (putError) {
          AppLogger.d('PUT method also failed: $putError');
        }
        
        // محاولة endpoint بديل
        try {
          final response = await _apiService.delete('/drivers/delete/$driverId');
          
          if (response.statusCode == 200 || response.statusCode == 204) {
            AppLogger.d('Driver deleted successfully using alternative endpoint: $driverId');
            return true;
          }
        } catch (altError) {
          AppLogger.d('Alternative endpoint also failed: $altError');
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.e('Error deleting driver: $e');
      // إظهار رسالة خطأ أوضح
      if (e.toString().contains('404')) {
        AppLogger.e('Delete endpoint not found. The server may not support driver deletion.');
        AppLogger.d('Please check if the DELETE /api/drivers/:id endpoint is implemented on the server.');
      }
      return false;
    }
  }

  Future<void> _saveDrivers(List<Driver> drivers) async {
    final json = drivers.map((d) => d.toJson()).toList();
    await StorageService.setString(_driversKey, jsonEncode(json));
  }

  // ========== إحصائيات ==========

  Future<Map<String, int>> getStatistics() async {
    final supermarkets = await getAllSupermarkets();
    final drivers = await getAllDrivers();
    final deliveryDrivers = drivers.where((d) => d.serviceType == 'delivery').length;
    final taxiDrivers = drivers.where((d) => d.serviceType == 'taxi').length;
    final carEmergencyDrivers = drivers.where((d) => d.serviceType == 'car_emergency').length;
    final craneDrivers = drivers.where((d) => d.serviceType == 'crane').length;
    final fuelDrivers = drivers.where((d) => d.serviceType == 'fuel').length;
    final maidDrivers = drivers.where((d) => d.serviceType == 'maid').length;

    return {
      'supermarkets': supermarkets.length,
      'drivers': drivers.length,
      'deliveryDrivers': deliveryDrivers,
      'taxiDrivers': taxiDrivers,
      'carEmergencyDrivers': carEmergencyDrivers,
      'craneDrivers': craneDrivers,
      'fuelDrivers': fuelDrivers,
      'maidDrivers': maidDrivers,
    };
  }

  // حساب إحصائيات العمولات (10%) للفترات المختلفة
  Future<Map<String, double>> getCommissionStatistics() async {
    try {
      final orderService = OrderService();
      final drivers = await getAllDrivers();
      
      // جلب جميع الطلبات المكتملة
      final allOrders = await orderService.getAllOrdersForDriver();
      final completedOrders = allOrders.where((order) => 
        order.status == OrderStatus.completed || order.status == OrderStatus.delivered
      ).toList();
      
      final now = DateTime.now();
      
      // اليومي: من بداية اليوم
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayOrders = completedOrders.where((order) => 
        order.createdAt.isAfter(todayStart)
      ).toList();
      
      // الأسبوعي: من بداية الأسبوع (اليوم الأول من الأسبوع)
      // weekday: 1 = Monday, 7 = Sunday
      final daysToSubtract = now.weekday - 1; // عدد الأيام للرجوع إلى بداية الأسبوع
      final weekStartDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
      final weeklyOrders = completedOrders.where((order) => 
        order.createdAt.isAfter(weekStartDate.subtract(const Duration(seconds: 1)))
      ).toList();
      
      // الشهري: من بداية الشهر
      final monthStart = DateTime(now.year, now.month, 1);
      final monthlyOrders = completedOrders.where((order) => 
        order.createdAt.isAfter(monthStart.subtract(const Duration(days: 1)))
      ).toList();
      
      // حساب المبلغ الكامل و 10% لكل فترة
      double calculateCommission(List<Order> orders) {
        double totalFullAmount = 0.0;
        
        for (var order in orders) {
          if (order.type == 'delivery') {
            // للديلفري: المبلغ الكامل = مبلغ التوصيل + مبلغ الطلبية
            final deliveryFee = (order.deliveryFee ?? 0).toDouble();
            final orderTotal = order.total ?? 0.0;
            final orderAmount = orderTotal - deliveryFee;
            totalFullAmount += deliveryFee + orderAmount;
          } else {
            // للخدمات الأخرى: المبلغ الكامل = إجمالي المبلغ
            final orderTotal = order.total ?? order.fare ?? 0.0;
            totalFullAmount += orderTotal;
          }
        }
        
        // حساب 10% من المبلغ الكامل
        return totalFullAmount * 0.10;
      }
      
      final dailyCommission = calculateCommission(todayOrders);
      final weeklyCommission = calculateCommission(weeklyOrders);
      final monthlyCommission = calculateCommission(monthlyOrders);
      
      return {
        'daily': dailyCommission,
        'weekly': weeklyCommission,
        'monthly': monthlyCommission,
      };
    } catch (e) {
      AppLogger.e('Error calculating commission statistics: $e');
      return {
        'daily': 0.0,
        'weekly': 0.0,
        'monthly': 0.0,
      };
    }
  }

  // تغيير كلمة المرور للإدمن
  Future<bool> changePassword(String adminId, String currentPassword, String newPassword) async {
    try {
      AppLogger.d('Changing password for admin ID: $adminId');
      
      final response = await _apiService.put('/admins/$adminId/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      
      if (response.statusCode == 200) {
        AppLogger.i('✅ Password changed successfully for admin ID: $adminId');
        
        // تحديث البيانات المحلية إذا كان هذا الإدمن هو المسجل دخوله
        final currentAdmin = await getCurrentAdmin();
        if (currentAdmin != null && currentAdmin.id == adminId) {
          // لا نحفظ كلمة المرور في البيانات المحلية، فقط نحدث حالة تسجيل الدخول
          AppLogger.d('Admin password changed, local data will be updated on next login');
        }
        
        return true;
      } else {
        AppLogger.w('Failed to change password: status ${response.statusCode}');
        if (response.data != null && response.data is Map) {
          final error = response.data['error'];
          if (error != null) {
            throw Exception(error.toString());
          }
        }
        return false;
      }
    } catch (e) {
      AppLogger.e('Error changing password for admin ID: $adminId', e);
      rethrow;
    }
  }
}





