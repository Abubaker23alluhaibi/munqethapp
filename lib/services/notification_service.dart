import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import 'user_service.dart';
import 'driver_service.dart';

/// خدمة الإشعارات
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;

  FirebaseMessaging get firebaseMessaging {
    if (_firebaseMessaging == null) {
      throw StateError('NotificationService not initialized. Call initialize() first.');
    }
    return _firebaseMessaging!;
  }

  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('NotificationService already initialized');
      return;
    }

    try {
      AppLogger.d('Initializing NotificationService...');
      
      // تهيئة Firebase مع error handling أفضل
      try {
        await Firebase.initializeApp();
        AppLogger.i('Firebase initialized successfully');
      } catch (firebaseError, stackTrace) {
        AppLogger.e('Error initializing Firebase', firebaseError, stackTrace);
        // في release mode، نريد رؤية الأخطاء بوضوح
        if (!kDebugMode) {
          AppLogger.e('Firebase initialization failed in release mode. Check google-services.json');
        }
        rethrow;
      }
      
      // تهيئة FirebaseMessaging بعد تهيئة Firebase
      _firebaseMessaging = FirebaseMessaging.instance;
      AppLogger.d('FirebaseMessaging instance created');

      // طلب صلاحيات الإشعارات
      await _requestPermissions();
      AppLogger.d('Notification permissions requested');

      // تهيئة Local Notifications
      await _initializeLocalNotifications();
      AppLogger.d('Local notifications initialized');

      // الحصول على FCM Token
      await _getFCMToken();
      AppLogger.d('FCM token obtained');

      // إعداد message handlers
      _setupMessageHandlers();
      AppLogger.d('Message handlers setup complete');

      _isInitialized = true;
      AppLogger.i('NotificationService initialized successfully');
      
      // في release mode، نؤكد فقط أن الخدمة جاهزة بدون عرض FCM Token
      if (!kDebugMode && _fcmToken != null) {
        AppLogger.i('NotificationService ready. FCM Token obtained successfully.');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error initializing notifications', e, stackTrace);
      // في release mode، نريد رؤية الأخطاء بوضوح
      _isInitialized = false;
      
      // محاولة استخدام token محفوظ مسبقاً
      try {
        final savedToken = await SecureStorageService.getString('fcm_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          AppLogger.w('Using saved FCM token after initialization error');
        }
      } catch (storageError) {
        AppLogger.e('Error getting saved FCM token', storageError);
      }
    }
  }

  /// طلب صلاحيات الإشعارات
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      final settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.d('Notification permission status: ${settings.authorizationStatus}');
    } else if (Platform.isAndroid) {
      // Android 13+ requires runtime permission
      final androidSettings = await firebaseMessaging.requestPermission();
      AppLogger.d('Android notification permission: ${androidSettings.authorizationStatus}');
    }
    
    // طلب صلاحيات Local Notifications
    if (Platform.isAndroid) {
      final androidSettings = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      AppLogger.d('Android local notification permission: $androidSettings');
    } else if (Platform.isIOS) {
      final iosSettings = await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      AppLogger.d('iOS local notification permission: $iosSettings');
    }
  }

  /// تهيئة Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// الحصول على FCM Token
  Future<void> _getFCMToken() async {
    try {
      AppLogger.d('🔑 Starting to get FCM token...');
      
      // التحقق من أن FirebaseMessaging مهيأ
      if (_firebaseMessaging == null) {
        AppLogger.e('❌ FirebaseMessaging is null - cannot get FCM token');
        return;
      }
      
      // التحقق من أن Firebase مهيأ
      try {
        final firebaseApp = Firebase.app();
        AppLogger.d('✅ Firebase app initialized: ${firebaseApp.name}');
      } catch (e) {
        AppLogger.e('❌ Firebase app not initialized', e);
        // محاولة إعادة تهيئة Firebase
        try {
          await Firebase.initializeApp();
          AppLogger.i('✅ Firebase re-initialized successfully');
        } catch (reinitError) {
          AppLogger.e('❌ Failed to re-initialize Firebase', reinitError);
          return;
        }
      }
      
      // محاولة الحصول على token محفوظ مسبقاً أولاً
      final savedToken = await SecureStorageService.getString('fcm_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        AppLogger.d('📦 Found saved FCM token, using it temporarily');
        _fcmToken = savedToken;
      }
      
      // محاولة الحصول على token مع retry في حالة الفشل
      int retries = 5; // زيادة عدد المحاولات
      String? token;
      
      while (retries > 0 && token == null) {
        try {
          AppLogger.d('🔄 Attempting to get FCM token (${6 - retries}/5)...');
          
          // إضافة timeout للحصول على token
          token = await firebaseMessaging.getToken().timeout(
            Duration(seconds: 10),
            onTimeout: () {
              AppLogger.w('⏱️ Timeout getting FCM token');
              return null;
            },
          );
          
          if (token != null && token.isNotEmpty) {
            AppLogger.i('✅ FCM token obtained: ${token.substring(0, 30)}...');
            break;
          } else {
            AppLogger.w('⚠️ FCM token is null or empty');
          }
        } catch (e, stackTrace) {
          final errorMessage = e.toString();
          AppLogger.e('❌ Failed to get FCM token (${6 - retries}/5)', e, stackTrace);
          
          // التحقق من نوع الخطأ
          if (errorMessage.contains('FIS_AUTH_ERROR') || 
              errorMessage.contains('Firebase Installations Service')) {
            AppLogger.e('   🔴 FIS_AUTH_ERROR detected - Firebase authentication failed');
            AppLogger.e('   This usually means:');
            AppLogger.e('   1. SHA fingerprints are missing or incorrect in Firebase Console');
            AppLogger.e('   2. google-services.json is incorrect or missing');
            AppLogger.e('   3. Package name mismatch');
            AppLogger.e('   4. Firebase project configuration issue');
          }
          
          retries--;
          if (retries > 0) {
            final waitTime = 5; // زيادة وقت الانتظار
            AppLogger.d('⏳ Waiting $waitTime seconds before retry...');
            await Future.delayed(Duration(seconds: waitTime));
          }
        }
      }
      
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        // حفظ Token في Storage
        await SecureStorageService.setString('fcm_token', _fcmToken!);
        AppLogger.i('✅ FCM Token saved successfully.');
        
        // في release mode، لا نطبع FCM Token لأسباب أمنية
        // في debug mode فقط، نعرض جزء صغير من Token للتحقق
        if (kDebugMode) {
          AppLogger.d('FCM Token preview: ${_fcmToken!.substring(0, 20)}...');
        }
      } else {
        AppLogger.e('❌ FCM Token is null or empty after all retries');
        AppLogger.e('   Possible causes:');
        AppLogger.e('   1. Firebase not properly configured (check google-services.json)');
        AppLogger.e('   2. SHA fingerprint not added in Firebase Console');
        AppLogger.e('   3. Notification permissions not granted');
        AppLogger.e('   4. Network connectivity issues');
        AppLogger.e('   5. FIS_AUTH_ERROR - Firebase Installations Service authentication failed');
        
        // محاولة الحصول على token محفوظ مسبقاً
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          AppLogger.w('⚠️ Using saved FCM token from storage (may be expired)');
          AppLogger.i('💡 This token will be sent to server - if it works, notifications will function');
        } else {
          AppLogger.e('❌ No saved FCM token found - notifications will not work');
          AppLogger.e('   Please fix Firebase configuration (SHA fingerprints) to get new token');
        }
      }

      // الاستماع لتحديثات Token
      firebaseMessaging.onTokenRefresh.listen((newToken) async {
        if (newToken != null && newToken.isNotEmpty) {
          _fcmToken = newToken;
          await SecureStorageService.setString('fcm_token', newToken);
          AppLogger.i('FCM Token refreshed successfully.');
          
          // في debug mode فقط، نعرض جزء صغير من Token
          if (kDebugMode) {
            AppLogger.d('FCM Token refreshed preview: ${newToken.substring(0, 20)}...');
          }
        }
      });
    } catch (e, stackTrace) {
      AppLogger.e('Error getting FCM token', e, stackTrace);
      // محاولة الحصول على token محفوظ مسبقاً
      try {
        final savedToken = await SecureStorageService.getString('fcm_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          AppLogger.w('Using saved FCM token from storage after error');
        }
      } catch (storageError) {
        AppLogger.e('Error getting saved FCM token', storageError);
      }
    }
  }

  /// إعداد message handlers
  void _setupMessageHandlers() {
    // معالجة الإشعارات عندما يكون التطبيق في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.d('Received message: ${message.messageId}');
      _showLocalNotificationFromFCM(message);
    });

    // معالجة الإشعارات عند النقر عليها
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.d('Notification opened: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // معالجة الإشعارات عند فتح التطبيق من إشعار
    firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        AppLogger.d('App opened from notification: ${message.messageId}');
        _handleNotificationTap(message);
      }
    });
  }

  /// معالجة النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // يمكن إضافة navigation logic هنا
      AppLogger.d('Notification tapped: ${response.payload}');
    }
  }

  /// معالجة النقر على إشعار FCM
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    
    AppLogger.d('Handling notification tap: ${data['type']}, orderId: ${data['orderId']}');
    
    // يمكن إضافة navigation logic حسب نوع الإشعار
    if (data['type'] == 'order' || 
        data['type'] == 'driver_accepted' || 
        data['type'] == 'order_accepted' ||
        data['type'] == 'driver_on_way' ||
        data['type'] == 'on_the_way' ||
        data['type'] == 'order_update') {
      final orderId = data['orderId'];
      if (orderId != null) {
        AppLogger.d('Should navigate to order: $orderId');
        // سيتم التعامل مع navigation في الشاشات التي تستمع للإشعارات
      }
    } else if (data['type'] == 'message') {
      // Navigate to messages
      AppLogger.d('Navigate to messages');
    }
  }

  /// عرض إشعار محلي من رسالة FCM
  Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'munqeth_channel',
        'منقذ',
        channelDescription: 'إشعارات تطبيق المنقذ',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title ?? 'منقذ',
        notification.body ?? '',
        details,
        payload: message.data.toString(),
      );
    }
  }

  /// الاشتراك في topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await firebaseMessaging.subscribeToTopic(topic);
      AppLogger.d('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.e('Error subscribing to topic', e);
    }
  }

  /// إلغاء الاشتراك من topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await firebaseMessaging.unsubscribeFromTopic(topic);
      AppLogger.d('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.e('Error unsubscribing from topic', e);
    }
  }

  /// إعادة الحصول على FCM token
  Future<String?> refreshFcmToken() async {
    try {
      AppLogger.d('🔄 Refreshing FCM token...');
      
      // محاولة الحصول على token جديد
      await _getFCMToken();
      
      // إذا فشل، استخدم المحفوظ
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        final savedToken = await SecureStorageService.getString('fcm_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          AppLogger.w('⚠️ Using saved FCM token after refresh failure');
        }
      }
      
      return _fcmToken;
    } catch (e, stackTrace) {
      AppLogger.e('Error refreshing FCM token', e, stackTrace);
      
      // محاولة استخدام token محفوظ
      try {
        final savedToken = await SecureStorageService.getString('fcm_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          AppLogger.w('⚠️ Using saved FCM token after error');
          return _fcmToken;
        }
      } catch (storageError) {
        AppLogger.e('Error getting saved FCM token', storageError);
      }
      
      return null;
    }
  }
  
  /// إعادة محاولة إرسال FCM token إلى السيرفر (للاستخدام عند فتح التطبيق)
  Future<bool> retrySendingFcmToken({String? userId, String? phone, String? driverId}) async {
    AppLogger.i('🔄 Retrying to send FCM token to server...');
    
    // أولاً: محاولة الحصول على token جديد
    await refreshFcmToken();
    
    // إذا كان لدينا token (جديد أو محفوظ)، أرسله
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      AppLogger.i('📤 Sending FCM token (${_fcmToken!.substring(0, 20)}...) to server...');
      return await sendFcmTokenToServer(userId, phone, driverId: driverId);
    }
    
    AppLogger.w('⚠️ No FCM token available to send');
    return false;
  }

  /// إرسال FCM token إلى السيرفر
  Future<bool> sendFcmTokenToServer(String? userId, String? phone, {String? driverId}) async {
    AppLogger.d('sendFcmTokenToServer called - userId: $userId, phone: $phone, driverId: $driverId');
    
    // أولاً: محاولة الحصول على token من storage (الأسرع والأكثر موثوقية)
    try {
      final savedToken = await SecureStorageService.getString('fcm_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        _fcmToken = savedToken;
        AppLogger.i('✅ Using saved FCM token from storage: ${savedToken.substring(0, 30)}...');
        // استمر في إرسال Token المحفوظ حتى لو كان قديماً
        // Firebase سيقبل Token القديم إذا كان صالحاً
      }
    } catch (e) {
      AppLogger.w('⚠️ Failed to get FCM token from storage: $e');
    }
    
    // إذا لم يكن موجوداً في storage أو كان null، محاولة الحصول عليه من Firebase
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      AppLogger.w('⚠️ No saved FCM token, attempting to get new one from Firebase...');
      
      // محاولة الحصول على token مع معالجة أخطاء أفضل
      try {
        await _getFCMToken();
      } catch (e) {
        AppLogger.w('⚠️ Failed to get FCM token: $e');
      }
      
      // إذا فشل، حاول مرة أخرى بعد تأخير أطول
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        AppLogger.w('⚠️ FCM token still null, waiting 5 seconds and retrying...');
        await Future.delayed(Duration(seconds: 5));
        
        // محاولة مباشرة مع timeout أطول
        try {
          if (_firebaseMessaging != null) {
            final token = await _firebaseMessaging!.getToken()
                .timeout(Duration(seconds: 10), onTimeout: () {
              AppLogger.w('⏱️ Timeout waiting for FCM token');
              return null;
            });
            if (token != null && token.isNotEmpty) {
              _fcmToken = token;
              await SecureStorageService.setString('fcm_token', token);
              AppLogger.i('✅ Got FCM token on retry: ${token.substring(0, 30)}...');
            }
          }
        } catch (e) {
          AppLogger.e('❌ Failed to get FCM token on retry', e);
          AppLogger.e('   Error type: ${e.runtimeType}');
          
          // إذا كان الخطأ FIS_AUTH_ERROR، هذا يعني مشكلة في Firebase configuration
          if (e.toString().contains('FIS_AUTH_ERROR') || 
              e.toString().contains('Firebase Installations')) {
            AppLogger.e('   ⚠️ FIS_AUTH_ERROR detected - This usually means:');
            AppLogger.e('      1. SHA fingerprint mismatch (Debug vs Release keystore)');
            AppLogger.e('      2. google-services.json needs update after adding SHA');
            AppLogger.e('      3. Internet connection issues');
            AppLogger.e('   💡 Solution: Try using saved FCM token if available');
          }
        }
      }
    }
    
    // إذا لم نحصل على token بعد كل المحاولات، استخدم المحفوظ حتى لو كان قديماً
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      AppLogger.e('❌ FCM token is still null or empty after all retries');
      AppLogger.e('   Cannot send FCM token to server - notifications will not work');
      AppLogger.e('   Please check Firebase configuration (SHA fingerprints, google-services.json)');
      return false;
    }
    
    AppLogger.i('📤 FCM token available: ${_fcmToken!.substring(0, 30)}...');
    AppLogger.i('   Token length: ${_fcmToken!.length} characters');

    try {
      if (userId != null || phone != null) {
        // For users
        final userService = UserService();
        if (phone != null) {
          AppLogger.i('📤 Sending FCM token for user phone: $phone');
          AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
          final success = await userService.updateFcmTokenByPhone(phone, _fcmToken!);
          if (success) {
            AppLogger.i('✅✅✅ FCM token sent successfully to server for user: $phone');
            return true;
          } else {
            AppLogger.e('❌❌❌ Failed to send FCM token for user phone: $phone');
          }
        } else if (userId != null) {
          AppLogger.i('📤 Sending FCM token for user ID: $userId');
          AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
          final success = await userService.updateFcmToken(userId, _fcmToken!);
          if (success) {
            AppLogger.i('✅✅✅ FCM token sent successfully to server for user ID: $userId');
            return true;
          } else {
            AppLogger.e('❌❌❌ Failed to send FCM token for user ID: $userId');
          }
        }
      } else if (driverId != null) {
        // For drivers
        AppLogger.i('📤 Sending FCM token for driver ID: $driverId');
        AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
        final driverService = DriverService();
        final success = await driverService.updateFcmTokenByDriverId(driverId, _fcmToken!);
        if (success) {
          AppLogger.i('✅✅✅ FCM token sent successfully to server for driver: $driverId');
          return true;
        } else {
          AppLogger.e('❌❌❌ Failed to send FCM token for driver ID: $driverId');
        }
      } else {
        AppLogger.w('No userId, phone, or driverId provided');
      }
      
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Error sending FCM token to server', e, stackTrace);
      return false;
    }
  }

  /// إرسال إشعار محلي (للاختبار)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'munqeth_channel',
      'منقذ',
      channelDescription: 'إشعارات تطبيق المنقذ',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data?.toString(),
    );
  }
}

/// Background message handler (يجب أن يكون top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // استخدام safePrint لإخفاء logs في release mode
  // ignore: avoid_print
  if (kDebugMode) {
    AppLogger.d('Background message: ${message.messageId}');
    AppLogger.d('Background message data: ${message.data}');
  }
}





