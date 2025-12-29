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
  
  // Setter لتحديث FCM token مباشرة (للاستخدام عند استخدام token محفوظ)
  Future<void> setFcmToken(String token) async {
    if (token.isNotEmpty) {
      _fcmToken = token;
      // حفظ Token في Storage
      await SecureStorageService.setString('fcm_token', token);
      AppLogger.i('✅✅✅ FCM token set manually: ${token.substring(0, 30)}...');
      AppLogger.i('   Token saved to storage and will be sent to server');
    }
  }
  
  /// طريقة لإدخال FCM token يدوياً من token موجود مسبقاً
  /// استخدم هذه الطريقة إذا كان لديك FCM token صالح من تطبيق آخر أو اختبار سابق
  /// ⚠️ هذا حل مؤقت فقط! الحل الصحيح هو إصلاح Firebase configuration
  Future<bool> injectFcmTokenManually(String token) async {
    try {
      if (token.isEmpty) {
        AppLogger.e('❌ Cannot inject empty FCM token');
        return false;
      }
      
      AppLogger.i('💉 ===== INJECTING FCM TOKEN MANUALLY =====');
      AppLogger.i('   Token preview: ${token.substring(0, 30)}...');
      AppLogger.w('   ⚠️ This is a temporary solution!');
      AppLogger.w('   ⚠️ Proper fix: Update google-services.json from Firebase Console');
      
      // حفظ Token
      await setFcmToken(token);
      
      // محاولة إرساله للسيرفر تلقائياً
      final userPhone = await SecureStorageService.getString('user_phone');
      final userId = await SecureStorageService.getUserId();
      final driverId = await SecureStorageService.getString('driver_id');
      
      if (driverId != null && driverId.isNotEmpty) {
        AppLogger.i('   Auto-sending token for driver: $driverId');
        await sendFcmTokenToServer(null, null, driverId: driverId);
      } else if (userPhone != null && userPhone.isNotEmpty) {
        AppLogger.i('   Auto-sending token for user: $userPhone');
        await sendFcmTokenToServer(userId, userPhone);
      } else if (userId != null && userId.isNotEmpty) {
        AppLogger.i('   Auto-sending token for user ID: $userId');
        await sendFcmTokenToServer(userId, null);
      } else {
        AppLogger.w('   No user/driver logged in - token saved but not sent to server');
        AppLogger.w('   Token will be sent automatically on next login');
      }
      
      AppLogger.i('✅✅✅ FCM token injected successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('❌ Failed to inject FCM token', e, stackTrace);
      return false;
    }
  }

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
      int retries = 3; // تقليل عدد المحاولات لتسريع العملية
      String? token;
      bool isFisAuthError = false;
      
      while (retries > 0 && token == null) {
        try {
          AppLogger.d('🔄 Attempting to get FCM token (${4 - retries}/3)...');
          
          // إضافة timeout للحصول على token
          token = await firebaseMessaging.getToken().timeout(
            Duration(seconds: 15),
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
          AppLogger.e('❌ Failed to get FCM token (${4 - retries}/3)', e, stackTrace);
          
          // التحقق من نوع الخطأ
          if (errorMessage.contains('FIS_AUTH_ERROR') || 
              errorMessage.contains('Firebase Installations Service') ||
              errorMessage.contains('FIS_AUTH_ERROR')) {
            isFisAuthError = true;
            AppLogger.e('   🔴 FIS_AUTH_ERROR detected - Firebase authentication failed');
            AppLogger.e('   ⚠️ This means SHA fingerprints are incorrect or google-services.json is outdated');
            AppLogger.e('   💡 Solution: Download google-services.json again from Firebase Console after adding SHA fingerprints');
            AppLogger.e('   🔄 Will use saved token if available...');
            // إذا كان خطأ FIS_AUTH_ERROR، لا نحتاج لإعادة المحاولة
            break;
          }
          
          retries--;
          if (retries > 0) {
            final waitTime = 2;
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
        // استخدام token محفوظ مسبقاً (الأولوية)
        if (savedToken != null && savedToken.isNotEmpty) {
          _fcmToken = savedToken;
          if (isFisAuthError) {
            AppLogger.w('⚠️ FIS_AUTH_ERROR: Using saved FCM token from storage');
            AppLogger.w('   ⚠️ This token may work, but you should fix Firebase configuration');
            AppLogger.w('   📝 Steps to fix:');
            AppLogger.w('      1. Go to Firebase Console → Project Settings');
            AppLogger.w('      2. Add SHA-1 and SHA-256 fingerprints (debug + release)');
            AppLogger.w('      3. Download new google-services.json');
            AppLogger.w('      4. Replace android/app/google-services.json');
            AppLogger.w('      5. Rebuild the app');
          } else {
            AppLogger.w('⚠️ Using saved FCM token from storage');
          }
          AppLogger.i('💡 Token will be sent to server - notifications should work');
        } else {
          AppLogger.e('❌ FCM Token is null or empty after all retries');
          AppLogger.e('   ❌ No saved FCM token found - notifications will NOT work');
          if (isFisAuthError) {
            AppLogger.e('   🔴 CRITICAL: FIS_AUTH_ERROR - Firebase configuration is broken');
            AppLogger.e('   📝 Required actions:');
            AppLogger.e('      1. Go to Firebase Console → Project Settings');
            AppLogger.e('      2. Add SHA-1 fingerprint: 58:47:44:af:85:e5:38:45:79:99:4a:9f:88:18:c9:b5:9d:98:72:70');
            AppLogger.e('      3. Add SHA-256 fingerprint: da:79:d0:59:45:c0:2a:3c:dc:58:dd:42:49:4e:ef:ec:86:65:9e:cd:67:fa:1a:35:e6:23:82:d4:79:99:3a:80');
            AppLogger.e('      4. Download NEW google-services.json file');
            AppLogger.e('      5. Replace android/app/google-services.json with new file');
            AppLogger.e('      6. Clean build: flutter clean && flutter pub get');
            AppLogger.e('      7. Rebuild: flutter build apk --release');
          } else {
            AppLogger.e('   Possible causes:');
            AppLogger.e('   1. Firebase not properly configured (check google-services.json)');
            AppLogger.e('   2. SHA fingerprint not added in Firebase Console');
            AppLogger.e('   3. Notification permissions not granted');
            AppLogger.e('   4. Network connectivity issues');
          }
        }
      }

      // الاستماع لتحديثات Token - مهم جداً: إرسال token جديد للسيرفر تلقائياً
      firebaseMessaging.onTokenRefresh.listen((newToken) async {
        if (newToken != null && newToken.isNotEmpty) {
          _fcmToken = newToken;
          await SecureStorageService.setString('fcm_token', newToken);
          AppLogger.i('🔄 FCM Token refreshed successfully.');
          AppLogger.i('   New token: ${newToken.substring(0, 30)}...');
          
          // في debug mode فقط، نعرض جزء صغير من Token
          if (kDebugMode) {
            AppLogger.d('FCM Token refreshed preview: ${newToken.substring(0, 20)}...');
          }
          
          // 🔥 مهم جداً: إرسال token جديد للسيرفر تلقائياً
          AppLogger.i('📤 Auto-sending refreshed FCM token to server...');
          try {
            // محاولة الحصول على معلومات المستخدم/السائق من Storage
            final userPhone = await SecureStorageService.getString('user_phone');
            final userId = await SecureStorageService.getUserId();
            final driverId = await SecureStorageService.getString('driver_id');
            
            AppLogger.d('   Checking stored credentials:');
            AppLogger.d('     userPhone: ${userPhone ?? 'null'}');
            AppLogger.d('     userId: ${userId ?? 'null'}');
            AppLogger.d('     driverId: ${driverId ?? 'null'}');
            
            if (driverId != null && driverId.isNotEmpty) {
              AppLogger.i('   ✅ Sending token for driver: driverId=$driverId');
              final success = await sendFcmTokenToServer(null, null, driverId: driverId);
              if (success) {
                AppLogger.i('   ✅✅✅ Refreshed token sent successfully for driver');
              } else {
                AppLogger.w('   ⚠️ Failed to send refreshed token for driver');
              }
            } else if (userPhone != null && userPhone.isNotEmpty) {
              AppLogger.i('   ✅ Sending token for user: phone=$userPhone, userId=$userId');
              final success = await sendFcmTokenToServer(userId, userPhone);
              if (success) {
                AppLogger.i('   ✅✅✅ Refreshed token sent successfully for user');
              } else {
                AppLogger.w('   ⚠️ Failed to send refreshed token for user');
              }
            } else if (userId != null && userId.isNotEmpty) {
              AppLogger.i('   ✅ Sending token for user: userId=$userId');
              final success = await sendFcmTokenToServer(userId, null);
              if (success) {
                AppLogger.i('   ✅✅✅ Refreshed token sent successfully for user');
              } else {
                AppLogger.w('   ⚠️ Failed to send refreshed token for user');
              }
            } else {
              AppLogger.w('   ⚠️ No user/driver info found in storage');
              AppLogger.w('   Token will be sent automatically on next login');
            }
          } catch (e, stackTrace) {
            AppLogger.e('   ❌ Failed to auto-send refreshed token to server', e, stackTrace);
            // لا نرمي خطأ هنا - سنحاول إرساله لاحقاً عند login
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
    AppLogger.i('📤 ===== sendFcmTokenToServer called =====');
    AppLogger.i('   userId: $userId, phone: $phone, driverId: $driverId');
    
    // أولاً: التأكد من أن NotificationService مهيأ
    if (!_isInitialized) {
      AppLogger.w('⚠️ NotificationService not initialized, initializing now...');
      try {
        await initialize();
        AppLogger.i('✅ NotificationService initialized');
        // انتظار قصير بعد التهيئة
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        AppLogger.e('❌ Failed to initialize NotificationService', e);
        // استمر في المحاولة باستخدام token محفوظ
      }
    }
    
    // أولاً: محاولة الحصول على token من storage (الأسرع والأكثر موثوقية)
    String? savedToken;
    try {
      savedToken = await SecureStorageService.getString('fcm_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        _fcmToken = savedToken;
        AppLogger.i('✅✅✅ Using saved FCM token from storage: ${savedToken.substring(0, 30)}...');
        AppLogger.i('   Token length: ${savedToken.length} characters');
        // استمر في إرسال Token المحفوظ حتى لو كان قديماً
        // Firebase سيقبل Token القديم إذا كان صالحاً
      } else {
        AppLogger.w('⚠️ No saved FCM token in storage');
      }
    } catch (e) {
      AppLogger.w('⚠️ Failed to get FCM token from storage: $e');
    }
    
    // إذا لم يكن موجوداً في storage أو كان null، محاولة الحصول عليه من Firebase
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      AppLogger.w('⚠️ No saved FCM token, attempting to get new one from Firebase...');
      
      // محاولة الحصول على token مع معالجة أخطاء أفضل
      try {
        // التأكد من أن FirebaseMessaging متاح
        if (_firebaseMessaging == null && _isInitialized) {
          _firebaseMessaging = FirebaseMessaging.instance;
        }
        
        if (_firebaseMessaging != null) {
          await _getFCMToken();
        } else {
          AppLogger.w('⚠️ FirebaseMessaging is null, cannot get new token');
        }
      } catch (e) {
        AppLogger.w('⚠️ Failed to get FCM token: $e');
      }
      
      // إذا فشل، حاول مرة أخرى بعد تأخير أطول
      if (_fcmToken == null || _fcmToken!.isEmpty) {
        AppLogger.w('⚠️ FCM token still null, waiting 3 seconds and retrying...');
        await Future.delayed(Duration(seconds: 3));
        
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
            AppLogger.e('   💡 Solution: Using saved FCM token if available');
          }
        }
      }
    }
    
    // إذا لم نحصل على token بعد كل المحاولات، استخدم المحفوظ حتى لو كان قديماً
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      // محاولة أخيرة - استخدام الـ token المحفوظ حتى لو كان قديماً
      if (savedToken != null && savedToken.isNotEmpty) {
        _fcmToken = savedToken;
        AppLogger.w('⚠️⚠️⚠️ Using saved FCM token as last resort (may be expired): ${savedToken.substring(0, 30)}...');
        AppLogger.w('   This token will be sent to server - notifications may work if token is still valid');
      } else {
        // محاولة أخيرة - البحث في Storage مرة أخرى
        try {
          final lastAttemptToken = await SecureStorageService.getString('fcm_token');
          if (lastAttemptToken != null && lastAttemptToken.isNotEmpty) {
            _fcmToken = lastAttemptToken;
            AppLogger.w('⚠️⚠️⚠️ Found FCM token in storage on last attempt: ${lastAttemptToken.substring(0, 30)}...');
            AppLogger.w('   This token will be sent to server - notifications may work if token is still valid');
          } else {
            AppLogger.e('❌❌❌ FCM token is still null or empty after all retries');
            AppLogger.e('   Cannot send FCM token to server - notifications will not work');
            AppLogger.e('');
            AppLogger.e('   🔧 FIX REQUIRED for Release Builds:');
            AppLogger.e('   1. Get SHA-1 fingerprint of your release keystore:');
            AppLogger.e('      keytool -list -v -keystore <path-to-keystore> -alias <alias>');
            AppLogger.e('   2. Add SHA-1 and SHA-256 to Firebase Console → Project Settings → Your Android App');
            AppLogger.e('   3. Download updated google-services.json from Firebase Console');
            AppLogger.e('   4. Replace android/app/google-services.json with the new file');
            AppLogger.e('   5. Clean and rebuild: flutter clean && flutter pub get && flutter build apk --release');
            AppLogger.e('');
            AppLogger.e('   ⚠️ NOTE: Debug and Release builds use different keystores');
            AppLogger.e('   ⚠️ You need to add SHA fingerprints for BOTH keystores to Firebase');
            return false;
          }
        } catch (e) {
          AppLogger.e('❌❌❌ Failed to get FCM token from storage: $e');
          return false;
        }
      }
    }
    
    AppLogger.i('📤✅✅✅ FCM token available: ${_fcmToken!.substring(0, 30)}...');
    AppLogger.i('   Token length: ${_fcmToken!.length} characters');
    AppLogger.i('   Will now send this token to server...');

    try {
      if (userId != null || phone != null) {
        // For users
        if (_fcmToken == null || _fcmToken!.isEmpty) {
          AppLogger.e('❌❌❌ Cannot send FCM token - token is null or empty for user: ${phone ?? userId}');
          AppLogger.e('   Please check Firebase configuration and notification permissions');
          return false;
        }
        
        final userService = UserService();
        if (phone != null) {
          AppLogger.i('📤 Sending FCM token for user phone: $phone');
          AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
          AppLogger.i('   Token length: ${_fcmToken!.length} characters');
          final success = await userService.updateFcmTokenByPhone(phone, _fcmToken!);
          if (success) {
            AppLogger.i('✅✅✅ FCM token sent successfully to server for user: $phone');
            AppLogger.i('   ✅✅✅ Token is now saved in MongoDB and ready for notifications');
            return true;
          } else {
            AppLogger.e('❌❌❌ Failed to send FCM token for user phone: $phone');
            AppLogger.e('   Please check server logs for more details');
          }
        } else if (userId != null) {
          AppLogger.i('📤 Sending FCM token for user ID: $userId');
          AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
          AppLogger.i('   Token length: ${_fcmToken!.length} characters');
          final success = await userService.updateFcmToken(userId, _fcmToken!);
          if (success) {
            AppLogger.i('✅✅✅ FCM token sent successfully to server for user ID: $userId');
            AppLogger.i('   ✅✅✅ Token is now saved in MongoDB and ready for notifications');
            return true;
          } else {
            AppLogger.e('❌❌❌ Failed to send FCM token for user ID: $userId');
            AppLogger.e('   Please check server logs for more details');
          }
        }
      } else if (driverId != null) {
        // For drivers
        if (_fcmToken == null || _fcmToken!.isEmpty) {
          AppLogger.e('❌❌❌ Cannot send FCM token - token is null or empty for driver: $driverId');
          AppLogger.e('   Please check Firebase configuration and notification permissions');
          return false;
        }
        
        AppLogger.i('📤 Sending FCM token for driver ID: $driverId');
        AppLogger.i('   Token preview: ${_fcmToken!.substring(0, 30)}...');
        AppLogger.i('   Token length: ${_fcmToken!.length} characters');
        AppLogger.i('   Endpoint: PUT /drivers/driverId/$driverId/fcm-token');
        
        final driverService = DriverService();
        final success = await driverService.updateFcmTokenByDriverId(driverId, _fcmToken!);
        if (success) {
          AppLogger.i('✅✅✅ FCM token sent successfully to server for driver: $driverId');
          AppLogger.i('   ✅✅✅ Token is now saved in MongoDB and ready for notifications');
          return true;
        } else {
          AppLogger.e('❌❌❌ Failed to send FCM token for driver ID: $driverId');
          AppLogger.e('   Please check server logs for more details');
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





