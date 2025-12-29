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

  /* تعليق - لا حاجة لـ FCM tokens
  void _sendFcmTokenToServer_OLD({String? userId, String? phone, String? driverId}) {
    AppLogger.i('🔄 _sendFcmTokenToServer called - userId: $userId, phone: $phone, driverId: $driverId');
    
    // إرسال FCM token بشكل غير متزامن (لا ننتظر النتيجة)
    // محاولة فورية مع إعادة محاولة بعد تأخير قصير إذا فشلت
    _attemptSendFcmToken(userId: userId, phone: phone, driverId: driverId, isRetry: false);
    
    // إعادة محاولة بعد 3 ثوانٍ للتأكد
    Future.delayed(const Duration(seconds: 3), () {
      _attemptSendFcmToken(userId: userId, phone: phone, driverId: driverId, isRetry: true);
    });
    
    // إعادة محاولة إضافية بعد 10 ثوانٍ للتأكد من التسجيل
    Future.delayed(const Duration(seconds: 10), () {
      _attemptSendFcmToken(userId: userId, phone: phone, driverId: driverId, isRetry: true);
    });
    
    // إعادة محاولة نهائية بعد 30 ثانية
    Future.delayed(const Duration(seconds: 30), () {
      _attemptSendFcmToken(userId: userId, phone: phone, driverId: driverId, isRetry: true);
    });
  }
  
  Future<void> _attemptSendFcmToken_OLD({String? userId, String? phone, String? driverId, bool isRetry = false}) async {
    if (isRetry) {
      AppLogger.d('⏰ Retrying FCM token send after delay...');
    } else {
      AppLogger.d('⏰ Starting FCM token send immediately...');
    }
    
    try {
      final notificationService = NotificationService();
      AppLogger.d('📱 NotificationService instance created');
      AppLogger.d('   isInitialized: ${notificationService.isInitialized}');
      AppLogger.d('   fcmToken: ${notificationService.fcmToken != null ? notificationService.fcmToken!.substring(0, 20) + '...' : 'null'}');
      
      // التأكد من أن NotificationService مهيأ
      if (!notificationService.isInitialized) {
        AppLogger.w('⚠️ NotificationService not initialized, initializing now...');
        try {
          await notificationService.initialize();
          AppLogger.d('✅ NotificationService initialized');
          // انتظار قصير بعد التهيئة لضمان استقرار الخدمة
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          AppLogger.e('❌ Failed to initialize NotificationService', e);
          // استمر في المحاولة - قد يكون هناك token محفوظ
        }
      }
      
      // التحقق من FCM token - محاولة متعددة
      // أولاً: محاولة الحصول على token محفوظ (الأسرع والأكثر موثوقية)
      try {
        final savedToken = await SecureStorageService.getString('fcm_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          AppLogger.i('✅✅✅ Found saved FCM token, using it: ${savedToken.substring(0, 30)}...');
          AppLogger.i('   Token length: ${savedToken.length} characters');
          // تحديث notificationService بالـ token المحفوظ مباشرة
          await notificationService.setFcmToken(savedToken);
          // Token جاهز الآن - لا نحتاج لمزيد من المحاولات
        } else {
          AppLogger.w('   No saved token found in storage, will try to get new one');
        }
      } catch (e) {
        AppLogger.w('   Error getting saved token: $e');
      }
      
      // إذا لم يكن هناك token محفوظ، حاول الحصول على واحد جديد
      if (notificationService.fcmToken == null || notificationService.fcmToken!.isEmpty) {
        int tokenRetries = isRetry ? 3 : 5; // تقليل عدد المحاولات
        while (tokenRetries > 0 && (notificationService.fcmToken == null || notificationService.fcmToken!.isEmpty)) {
          AppLogger.w('⚠️ FCM token is null, retrying... ($tokenRetries retries left)');
          
          // إعادة تهيئة NotificationService إذا لزم الأمر
          if (!notificationService.isInitialized) {
            AppLogger.d('   Re-initializing NotificationService...');
            try {
              await notificationService.initialize();
              await Future.delayed(const Duration(seconds: 2));
            } catch (e) {
              AppLogger.w('   Failed to re-initialize: $e');
            }
          }
          
          // محاولة الحصول على token جديد من Firebase
          try {
            AppLogger.d('   Attempting to get new FCM token from Firebase...');
            final token = await notificationService.firebaseMessaging.getToken()
                .timeout(const Duration(seconds: 10), onTimeout: () {
              AppLogger.w('   Timeout getting FCM token');
              return null;
            });
            if (token != null && token.isNotEmpty) {
              AppLogger.i('✅ Got new FCM token: ${token.substring(0, 30)}...');
              await SecureStorageService.setString('fcm_token', token);
              // تحديث notificationService
              await notificationService.setFcmToken(token);
              break;
            } else {
              AppLogger.w('   Got null/empty token from Firebase');
            }
          } catch (retryError) {
            AppLogger.w('   Failed to get FCM token from Firebase: $retryError');
            // إذا كان الخطأ FIS_AUTH_ERROR، استخدم الـ token المحفوظ إذا كان موجوداً
            if (retryError.toString().contains('FIS_AUTH_ERROR')) {
              AppLogger.w('   FIS_AUTH_ERROR detected - will use saved token if available');
              final savedToken = await SecureStorageService.getString('fcm_token');
              if (savedToken != null && savedToken.isNotEmpty) {
                AppLogger.i('   Using saved token due to FIS_AUTH_ERROR: ${savedToken.substring(0, 30)}...');
                await notificationService.setFcmToken(savedToken);
                break;
              }
            }
          }
          
          tokenRetries--;
          if (tokenRetries > 0) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      
      // التحقق النهائي - محاولة أخيرة باستخدام الـ token المحفوظ
      if (notificationService.fcmToken == null || notificationService.fcmToken!.isEmpty) {
        // محاولة أخيرة - استخدام الـ token المحفوظ في Storage
        try {
          final lastSavedToken = await SecureStorageService.getString('fcm_token');
          if (lastSavedToken != null && lastSavedToken.isNotEmpty) {
            AppLogger.w('⚠️⚠️⚠️ Using saved FCM token as last resort: ${lastSavedToken.substring(0, 30)}...');
            notificationService.setFcmToken(lastSavedToken);
            AppLogger.i('✅ FCM token set from storage - will attempt to send to server');
          } else {
            if (!isRetry) {
              // في المحاولة الأولى فقط نطبع رسالة خطأ مفصلة
              AppLogger.e('❌ FCM token is still null after all retries');
              AppLogger.e('   This means Firebase is not properly configured or permissions are not granted');
              AppLogger.e('   Please check:');
              AppLogger.e('   1. google-services.json is in android/app/');
              AppLogger.e('   2. SHA fingerprint is added in Firebase Console');
              AppLogger.e('   3. Notification permissions are granted');
              AppLogger.e('   4. FIS_AUTH_ERROR indicates Firebase configuration issue');
            }
            return;
          }
        } catch (e) {
          AppLogger.e('❌ Failed to get saved token as last resort: $e');
          return;
        }
      }
      
      AppLogger.d('✅ FCM token is available: ${notificationService.fcmToken!.substring(0, 30)}...');
      
      // إرسال FCM token إلى السيرفر (زيادة عدد المحاولات)
      int retries = isRetry ? 3 : 5; // زيادة عدد المحاولات
      bool success = false;
      
      while (retries > 0 && !success) {
        try {
          AppLogger.i('📤 Attempting to send FCM token (${(isRetry ? 4 : 6) - retries}/${isRetry ? 3 : 5})...');
          if (driverId != null) {
            AppLogger.d('   Target: Driver ID = $driverId');
          } else if (phone != null) {
            AppLogger.d('   Target: User phone = $phone');
          } else if (userId != null) {
            AppLogger.d('   Target: User ID = $userId');
          }
          
          // التأكد من أن لدينا token قبل الإرسال
          if (notificationService.fcmToken == null || notificationService.fcmToken!.isEmpty) {
            AppLogger.w('   ⚠️ FCM token is still null, refreshing...');
            await notificationService.refreshFcmToken();
            if (notificationService.fcmToken == null || notificationService.fcmToken!.isEmpty) {
              AppLogger.e('   ❌ Cannot send FCM token - token is still null after refresh');
              retries--;
              if (retries > 0) {
                await Future.delayed(const Duration(seconds: 3));
              }
              continue;
            }
          }
          
          success = await notificationService.sendFcmTokenToServer(userId, phone, driverId: driverId);
          
          if (success) {
            AppLogger.i('✅ FCM token sent successfully');
            if (driverId != null) {
              AppLogger.i('   Driver ID: $driverId');
            } else if (phone != null) {
              AppLogger.i('   User phone: $phone');
            } else if (userId != null) {
              AppLogger.i('   User ID: $userId');
            }
            break;
          } else {
            if (!isRetry) {
              AppLogger.w('⚠️ Failed to send FCM token (${6 - retries}/5)');
            }
            retries--;
            if (retries > 0) {
              AppLogger.d('   Retrying in 3 seconds...');
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        } catch (error, stackTrace) {
          AppLogger.e('❌ Error sending FCM token', error, stackTrace);
          retries--;
          if (retries > 0) {
            AppLogger.d('   Retrying in 3 seconds...');
            await Future.delayed(const Duration(seconds: 3));
          }
        }
      }
      
      if (!success && !isRetry) {
        AppLogger.e('❌ Failed to send FCM token after all retries - notifications may not work');
        AppLogger.e('   Please check:');
        AppLogger.e('   1. Firebase is properly configured (google-services.json)');
        AppLogger.e('   2. Notification permissions are granted');
        AppLogger.e('   3. Network connection is available');
      }
    } catch (error, stackTrace) {
      AppLogger.e('❌ Critical error in _attemptSendFcmToken', error, stackTrace);
    }
  }
  
  /*
  Future<void> _tryUseSavedFcmToken_OLD({String? userId, String? phone, String? driverId}) async {
    try {
      // أولاً: التحقق من وجود FCM token محفوظ محلياً
      String? savedToken = await SecureStorageService.getString('fcm_token');
      
      // ثانياً: إذا لم يكن موجوداً محلياً، جربه من Backend
      if ((savedToken == null || savedToken.isEmpty) && (driverId != null || phone != null)) {
        AppLogger.i('💾 No local FCM token found, trying to get from backend...');
        savedToken = await _getFcmTokenFromBackend(driverId: driverId, phone: phone);
      }
      
      if (savedToken != null && savedToken.isNotEmpty) {
        AppLogger.i('💾 Found FCM token (${savedToken.substring(0, 30)}...)');
        
        // استخدام NotificationService لإدخال Token
        final notificationService = NotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        // إدخال Token يدوياً
        await notificationService.setFcmToken(savedToken);
        
        // محاولة إرساله للسيرفر مباشرة
        AppLogger.i('📤 Attempting to send FCM token to server...');
        final success = await notificationService.sendFcmTokenToServer(userId, phone, driverId: driverId);
        
        if (success) {
          AppLogger.i('✅✅✅ FCM token sent successfully to server');
          if (driverId != null) {
            AppLogger.i('   Driver ID: $driverId');
          } else if (phone != null) {
            AppLogger.i('   User phone: $phone');
          } else if (userId != null) {
            AppLogger.i('   User ID: $userId');
          }
        } else {
          AppLogger.w('⚠️ Failed to send FCM token - will retry automatically');
        }
      } else {
        AppLogger.d('   No FCM token found (local or backend)');
      }
    } catch (e, stackTrace) {
      AppLogger.e('❌ Error trying to use saved FCM token', e, stackTrace);
      // لا نرمي خطأ هنا - سنحاول الحصول على token جديد
    }
  }
  
  */
  // _getFcmTokenFromBackend removed - using Socket.IO instead
  /*
  Future<String?> _getFcmTokenFromBackend_OLD({String? driverId, String? phone}) async {
    try {
      if (driverId != null) {
        AppLogger.d('🔍 Fetching FCM token from backend for driver: $driverId');
        final driver = await _driverService.getDriverById(driverId);
        if (driver != null && driver.fcmToken != null && driver.fcmToken!.isNotEmpty) {
          // fcmToken في Driver model هو String? (ليس array في Flutter model)
          final tokenStr = driver.fcmToken!;
          AppLogger.i('✅ Found FCM token in backend for driver $driverId');
          // حفظه محلياً للاستخدام المستقبلي
          await SecureStorageService.setString('fcm_token', tokenStr);
          return tokenStr;
        }
      } else if (phone != null) {
        AppLogger.d('🔍 Fetching FCM token from backend for user: $phone');
        final user = await _userService.getUserByPhone(phone);
        if (user != null && user.fcmToken != null && user.fcmToken!.isNotEmpty) {
          // fcmToken في User model هو String? (ليس array في Flutter model)
          final tokenStr = user.fcmToken!;
          AppLogger.i('✅ Found FCM token in backend for user $phone');
          // حفظه محلياً للاستخدام المستقبلي
          await SecureStorageService.setString('fcm_token', tokenStr);
          return tokenStr;
        }
      }
      AppLogger.d('   No FCM token found in backend');
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Error fetching FCM token from backend', e, stackTrace);
      return null;
    }
  }
  */
  */
}





