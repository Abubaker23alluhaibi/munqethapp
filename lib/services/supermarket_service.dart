import '../models/supermarket.dart';
import '../core/api/api_service_improved.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import 'dart:convert';

class SupermarketService {
  final ApiServiceImproved _apiService = ApiServiceImproved();
  static const String _storageKey = 'supermarket_data';
  static const String _loggedInKey = 'supermarket_logged_in';

  // تسجيل الدخول (استخدام API للتحقق من البيانات)
  Future<Supermarket?> login(String id, String code) async {
    try {
      AppLogger.d('Supermarket login attempt: id=$id');
      
      // الحصول على السوبر ماركت من API
      final response = await _apiService.get('/supermarkets/$id');
      
      AppLogger.d('Supermarket login response status: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final supermarket = Supermarket.fromJson(response.data as Map<String, dynamic>);
        
        AppLogger.d('Parsed supermarket: id=${supermarket.id}, name=${supermarket.name}');
        
        // التحقق من الكود
        if (supermarket.code == code.trim()) {
          // حفظ بيانات السوبر ماركت محلياً
          final supermarketJson = supermarket.toJson();
          
          await SecureStorageService.setString(_storageKey, jsonEncode(supermarketJson));
          await SecureStorageService.setBool(_loggedInKey, true);
          
          AppLogger.i('Supermarket logged in successfully: ${supermarket.name}');
          return supermarket;
        } else {
          AppLogger.w('Code mismatch');
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error in supermarket login', e);
      return null;
    }
  }

  // الحصول على السوبر ماركت الحالي من التخزين المحلي
  Future<Supermarket?> getCurrentSupermarket() async {
    try {
      final data = await SecureStorageService.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final supermarket = Supermarket.fromJson(jsonDecode(data) as Map<String, dynamic>);
        AppLogger.d('Current supermarket from storage: ${supermarket.name}');
        return supermarket;
      } else {
        AppLogger.d('No supermarket data found in storage');
      }
    } catch (e) {
      AppLogger.e('Error getting current supermarket', e);
    }
    return null;
  }

  // التحقق من حالة تسجيل الدخول
  Future<bool> isLoggedIn() async {
    final loggedIn = await SecureStorageService.getBool(_loggedInKey);
    return loggedIn ?? false;
  }

  // تحديث بيانات السوبر ماركت
  Future<bool> updateSupermarket(Supermarket supermarket) async {
    try {
      final response = await _apiService.put('/supermarkets/${supermarket.id}', data: supermarket.toJson());
      if (response.statusCode == 200) {
        // تحديث البيانات المحلية
        await SecureStorageService.setString(_storageKey, jsonEncode(supermarket.toJson()));
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error updating supermarket', e);
      return false;
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    await SecureStorageService.remove(_storageKey);
    await SecureStorageService.remove(_loggedInKey);
  }

  // الحصول على جميع السوبر ماركتات
  Future<List<Supermarket>> getAllSupermarkets() async {
    try {
      final response = await _apiService.get('/supermarkets');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Supermarket.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting all supermarkets', e);
      return [];
    }
  }

  // العثور على أقرب سوبر ماركت للعميل (استخدام API)
  Future<Supermarket?> findNearestSupermarket(double customerLat, double customerLng) async {
    try {
      // التحقق من صحة الإحداثيات
      if (customerLat.isNaN || customerLng.isNaN || 
          !customerLat.isFinite || !customerLng.isFinite) {
        AppLogger.w('Invalid coordinates: lat=$customerLat, lng=$customerLng');
        return null;
      }

      final response = await _apiService.get('/supermarkets/nearest', queryParameters: {
        'latitude': customerLat.toString(),
        'longitude': customerLng.toString(),
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // API returns { supermarket: {...}, distance: ..., location: {...} }
        if (data['supermarket'] != null) {
          final supermarket = Supermarket.fromJson(data['supermarket'] as Map<String, dynamic>);
          AppLogger.d('Found supermarket: ${supermarket.name}, locations: ${supermarket.locations?.length ?? 0}');
          return supermarket;
        } else {
          AppLogger.d('No supermarket found in response');
        }
      } else {
        AppLogger.w('API returned status: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      AppLogger.e('Error finding nearest supermarket', e);
      return null;
    }
  }

  // الحصول على سوبر ماركت بالـ ID
  Future<Supermarket?> getSupermarketById(String id) async {
    try {
      final response = await _apiService.get('/supermarkets/$id');
      if (response.statusCode == 200 && response.data != null) {
        return Supermarket.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error getting supermarket by id', e);
      return null;
    }
  }

  // تحديث ID و Code (للاستخدام المحلي فقط - يجب إضافة endpoint في الباكند)
  Future<bool> updateCredentials(String newId, String newCode) async {
    try {
      final current = await getCurrentSupermarket();
      if (current != null) {
        final updated = current.copyWith(id: newId, code: newCode);
        await SecureStorageService.setString(_storageKey, jsonEncode(updated.toJson()));
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error updating credentials', e);
      return false;
    }
  }
}