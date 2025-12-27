import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين الآمن للبيانات الحساسة
class SecureStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // المفاتيح للبيانات الحساسة
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userCodeKey = 'user_code';

  /// حفظ Token بشكل آمن
  static Future<bool> setToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على Token
  static Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// حذف Token
  static Future<bool> deleteToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// حفظ User ID بشكل آمن
  static Future<bool> setUserId(String userId) async {
    try {
      await _secureStorage.write(key: _userIdKey, value: userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على User ID
  static Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// حفظ User Code بشكل آمن
  static Future<bool> setUserCode(String code) async {
    try {
      await _secureStorage.write(key: _userCodeKey, value: code);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على User Code
  static Future<String?> getUserCode() async {
    try {
      return await _secureStorage.read(key: _userCodeKey);
    } catch (e) {
      return null;
    }
  }

  /// حذف جميع البيانات الحساسة
  static Future<bool> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// حفظ بيانات عامة (غير حساسة) في SharedPreferences
  static Future<bool> setString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(key, value);
    } catch (e) {
      return false;
    }
  }

  /// الحصول على بيانات عامة
  static Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  /// حفظ boolean
  static Future<bool> setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(key, value);
    } catch (e) {
      return false;
    }
  }

  /// الحصول على boolean
  static Future<bool?> getBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    } catch (e) {
      return null;
    }
  }

  /// حذف مفتاح
  static Future<bool> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(key);
    } catch (e) {
      return false;
    }
  }

  /// مسح جميع البيانات
  static Future<bool> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await clearAll(); // مسح البيانات الحساسة أيضاً
      return true;
    } catch (e) {
      return false;
    }
  }
}









