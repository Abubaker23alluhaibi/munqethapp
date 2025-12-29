import 'package:flutter/foundation.dart';
import '../models/admin.dart';
import '../models/driver.dart';
import '../models/supermarket.dart';
import '../models/user.dart';
import '../services/admin_service.dart';
import '../services/driver_service.dart';
import '../services/supermarket_service.dart';
import '../services/user_service.dart';
// import '../services/notification_service.dart'; // لا حاجة لـ Firebase
import '../services/socket_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';

/// Provider لإدارة حالة المصادقة
class AuthProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();
  final DriverService _driverService = DriverService();
  final SupermarketService _supermarketService = SupermarketService();
  final UserService _userService = UserService();

  Admin? _admin;
  Driver? _driver;
  Supermarket? _supermarket;
  User? _currentUser;
  bool _isUserLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Admin? get admin => _admin;
  Driver? get driver => _driver;
  Supermarket? get supermarket => _supermarket;
  User? get currentUser => _currentUser;
  bool get isAdminLoggedIn => _admin != null;
  bool get isDriverLoggedIn => _driver != null;
  bool get isSupermarketLoggedIn => _supermarket != null;
  bool get isUserLoggedIn => _isUserLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => isAdminLoggedIn || isDriverLoggedIn || isSupermarketLoggedIn || isUserLoggedIn;

  /// تسجيل الدخول كمدير
  Future<bool> loginAsAdmin(String id, String code) async {
    _setLoading(true);
    _clearError();

    try {
      final admin = await _adminService.login(id, code);
      if (admin != null) {
        _admin = admin;
        await SecureStorageService.setUserId(admin.id);
        await SecureStorageService.setUserCode(admin.code);
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('رقم المستخدم أو الكود غير صحيح');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('حدث خطأ أثناء تسجيل الدخول: $e');
      _setLoading(false);
      return false;
    }
  }

  /// تسجيل الدخول كسائق
  Future<bool> loginAsDriver(String id, String code) async {
    AppLogger.i('🔐 loginAsDriver called - id: $id');
    _setLoading(true);
    _clearError();

    try {
      final driver = await _driverService.login(id, code);
      if (driver != null) {
        AppLogger.i('✅ Driver login successful - driverId: ${driver.driverId}');
        _driver = driver;
        await SecureStorageService.setUserId(driver.id);
        await SecureStorageService.setUserCode(driver.code);
        // حفظ driver_id للاستخدام في onTokenRefresh
        await SecureStorageService.setString('driver_id', driver.driverId);
        
        _setLoading(false);
        notifyListeners();
        
      // Socket.IO connection - السائق يشارك في room
      final socketService = SocketService();
      socketService.connect();
      socketService.joinDriverRoom(driver.driverId);
        
        return true;
      } else {
        AppLogger.w('❌ Driver login failed - invalid credentials');
        _setError('رقم المستخدم أو الكود غير صحيح');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      AppLogger.e('❌ Error in loginAsDriver', e);
      _setError('حدث خطأ أثناء تسجيل الدخول: $e');
      _setLoading(false);
      return false;
    }
  }

  /// تسجيل الدخول كسوبر ماركت
  Future<bool> loginAsSupermarket(String id, String code) async {
    _setLoading(true);
    _clearError();

    try {
      final supermarket = await _supermarketService.login(id, code);
      if (supermarket != null) {
        _supermarket = supermarket;
        await SecureStorageService.setUserId(supermarket.id);
        await SecureStorageService.setUserCode(supermarket.code);
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('رقم المستخدم أو الكود غير صحيح');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('حدث خطأ أثناء تسجيل الدخول: $e');
      _setLoading(false);
      return false;
    }
  }

  /// تسجيل الدخول كمستخدم عادي (بدون password - للاستخدام بعد التحقق من password)
  Future<bool> loginAsUser(String phone, String code) async {
    AppLogger.i('🔐 loginAsUser called - phone: $phone');
    _setLoading(true);
    _clearError();

    try {
      // جلب بيانات المستخدم من السيرفر
      final user = await _userService.getUserByPhone(phone);
      
      // منع إنشاء حساب باسم افتراضي؛ يجب أن يكون المستخدم قد أنشأ حسابه سابقاً
      if (user == null) {
        AppLogger.w('❌ User login failed - user not found for phone: $phone');
        _setError('الحساب غير موجود، الرجاء إنشاء حساب جديد أولاً');
        _setLoading(false);
        return false;
      }
      
      AppLogger.i('✅ User login successful - userId: ${user.id}, phone: ${user.phone}');
      _currentUser = user;
      _isUserLoggedIn = true;
      // حفظ رقم الهاتف فقط للاستخدام اللاحق
      await SecureStorageService.setString('user_phone', phone);
      await SecureStorageService.setBool('user_logged_in', true);
      
      _setLoading(false);
      notifyListeners();
      
      // Socket.IO connection - المستخدم يشارك في room للطلبات
      final socketService = SocketService();
      socketService.connect();
      
      return true;
    } catch (e) {
      AppLogger.e('❌ Error in loginAsUser', e);
      _setError('حدث خطأ أثناء تسجيل الدخول: $e');
      _setLoading(false);
      return false;
    }
  }

  /// جلب بيانات المستخدم الحالي من السيرفر
  Future<void> loadCurrentUser() async {
    try {
      final phone = await SecureStorageService.getString('user_phone');
      if (phone != null && phone.isNotEmpty) {
        final user = await _userService.getUserByPhone(phone);
        if (user != null) {
          _currentUser = user;
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.e('Error loading current user', e);
    }
  }

  /// تحديث بيانات المستخدم
  Future<bool> updateCurrentUser(String name, String phone, String? address) async {
    try {
      if (_currentUser == null) return false;
      
      final updatedUser = await _userService.updateUser(_currentUser!.id, 
        name: name,
        phone: phone,
        address: address,
      );
      
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error updating user', e);
      return false;
    }
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    _setLoading(true);

    try {
      if (_admin != null) {
        await _adminService.logout();
        _admin = null;
      }
      if (_driver != null) {
        await _driverService.logout();
        _driver = null;
      }
      if (_supermarket != null) {
        await _supermarketService.logout();
        _supermarket = null;
      }
      if (_isUserLoggedIn) {
        await SecureStorageService.remove('user_logged_in');
        await SecureStorageService.remove('user_phone');
        _currentUser = null;
        _isUserLoggedIn = false;
      }

      await SecureStorageService.clearAll();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('حدث خطأ أثناء تسجيل الخروج: $e');
      _setLoading(false);
    }
  }

  /// تحميل حالة تسجيل الدخول المحفوظة
  Future<void> loadSavedAuth() async {
    _setLoading(true);

    try {
      // تحميل جميع حالات تسجيل الدخول بشكل متوازي (أسرع)
      final results = await Future.wait([
        _adminService.isLoggedIn(),
        _driverService.isLoggedIn(),
        _supermarketService.isLoggedIn(),
        SecureStorageService.getBool('user_logged_in'),
      ]);

      final isAdminLoggedIn = results[0] as bool;
      final isDriverLoggedIn = results[1] as bool;
      final isSupermarketLoggedIn = results[2] as bool;
      final userLoggedIn = results[3] as bool? ?? false;

      // تحميل البيانات بشكل متوازي
      final loadFutures = <Future>[];
      
      if (isAdminLoggedIn) {
        loadFutures.add(_adminService.getCurrentAdmin().then((admin) {
          _admin = admin;
        }));
      }

      if (isDriverLoggedIn) {
        loadFutures.add(_driverService.getCurrentDriver().then((driver) async {
          _driver = driver;
          // Socket.IO handles notifications - no FCM token needed
        }));
      }

      if (isSupermarketLoggedIn) {
        loadFutures.add(_supermarketService.getCurrentSupermarket().then((supermarket) {
          _supermarket = supermarket;
        }));
      }

      if (userLoggedIn) {
        _isUserLoggedIn = true;
        loadFutures.add(loadCurrentUser().then((_) async {
          // Socket.IO handles notifications - no FCM token needed
        }));
      }

      // انتظار تحميل جميع البيانات
      await Future.wait(loadFutures);
      
      // Socket.IO connection for logged in users/drivers
      final socketService = SocketService();
      socketService.connect();
      if (_driver != null) {
        socketService.joinDriverRoom(_driver!.driverId);
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('حدث خطأ أثناء تحميل حالة تسجيل الدخول: $e');
      _setLoading(false);
      notifyListeners();
    }
  }

  /// تحديث بيانات السائق
  Future<void> updateDriver(Driver driver) async {
    try {
      await _driverService.updateDriver(driver);
      _driver = driver;
      notifyListeners();
    } catch (e) {
      _setError('حدث خطأ أثناء تحديث البيانات: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// التأكد من تسجيل FCM token للمستخدم/السائق المسجل دخول (للاستخدام عند فتح التطبيق)
  // لا حاجة لـ FCM tokens - نستخدم Socket.IO الآن
  Future<void> ensureFcmTokenRegistered() async {
    AppLogger.d('ensureFcmTokenRegistered called - Socket.IO handles notifications');
    // Socket.IO connection handled in main.dart
    final socketService = SocketService();
    if (!socketService.isConnected) {
      socketService.connect();
    }
    if (_driver != null) {
      socketService.joinDriverRoom(_driver!.driverId);
    }
  }

  // FCM tokens removed - using Socket.IO for local notifications only
}





