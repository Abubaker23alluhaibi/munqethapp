import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/utils/app_logger.dart';
import '../core/storage/secure_storage_service.dart';
import 'local_notification_service.dart';
import 'user_service.dart';
import 'driver_service.dart';

/// Handler للإشعارات في الخلفية (يجب أن يكون top-level function)
/// هذا الـ handler يعمل عندما يكون التطبيق مغلق تماماً
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تهيئة Firebase (مطلوب في background handler)
  await Firebase.initializeApp();
  
  AppLogger.d('📨 Background message received: ${message.messageId}');
  AppLogger.d('Title: ${message.notification?.title}');
  AppLogger.d('Body: ${message.notification?.body}');
  AppLogger.d('Data: ${message.data}');
  
  // Note: عندما يكون التطبيق مغلق تماماً، Firebase يعرض الإشعار تلقائياً
  // إذا كان الإشعار يحتوي على notification payload (title + body)
}

/// خدمة Firebase Cloud Messaging للإشعارات الخارجية
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotificationService = LocalNotificationService();
  String? _fcmToken;
  bool _isInitialized = false;
  
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// تهيئة Firebase Messaging
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('FirebaseMessagingService already initialized');
      return;
    }

    try {
      AppLogger.d('Initializing FirebaseMessagingService...');

      // تهيئة Local Notifications أولاً (مطلوب لعرض الإشعارات)
      await _localNotificationService.initialize();

      // طلب صلاحيات الإشعارات
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      AppLogger.d('Firebase Messaging permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.i('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.i('✅ User granted provisional notification permission');
      } else {
        AppLogger.w('❌ User declined or has not accepted notification permission');
        _isInitialized = false;
        return;
      }

      // الحصول على FCM Token
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        AppLogger.i('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        print('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...'); // Print للتحقق في Release APK
      } else {
        AppLogger.w('⚠️ FCM Token is null');
        print('⚠️ FCM Token is null'); // Print للتحقق في Release APK
      }

      // الاستماع لتحديثات Token (مهم عندما يتغير Token)
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        AppLogger.i('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        // إرسال Token الجديد للسيرفر إذا كان المستخدم مسجل دخول
        _sendTokenToServerIfLoggedIn();
      });

      // تهيئة Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // معالجة الإشعارات عندما يكون التطبيق مفتوح (Foreground)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // معالجة النقر على الإشعار عندما يكون التطبيق في الخلفية
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // التحقق من وجود إشعار فتح التطبيق (عندما يكون التطبيق مغلق تماماً)
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.d('📱 App opened from notification (was closed)');
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;
      AppLogger.i('✅ FirebaseMessagingService initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.e('Error initializing FirebaseMessagingService', e, stackTrace);
      _isInitialized = false;
    }
  }

  /// معالجة الإشعارات عندما يكون التطبيق مفتوح (Foreground)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.d('📨 Foreground message received: ${message.messageId}');
    AppLogger.d('Title: ${message.notification?.title}');
    AppLogger.d('Body: ${message.notification?.body}');
    AppLogger.d('Data: ${message.data}');
    
    // عرض الإشعار محلياً باستخدام flutter_local_notifications
    if (message.notification != null) {
      await _localNotificationService.showNotification(
        title: message.notification!.title ?? 'منقذ',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }
  }

  /// معالجة النقر على الإشعار
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    AppLogger.d('📱 Notification opened app: ${message.messageId}');
    AppLogger.d('Data: ${message.data}');
    
    // يمكنك إضافة navigation logic هنا بناءً على message.data
    // مثال: إذا كان type == 'order', افتح شاشة الطلب
    // يمكن استخدام go_router للتنقل
  }

  /// إرسال FCM Token إلى السيرفر إذا كان المستخدم مسجل دخول
  Future<void> _sendTokenToServerIfLoggedIn() async {
    if (_fcmToken == null) {
      AppLogger.w('FCM Token is null, cannot send to server');
      return;
    }

    try {
      // جلب بيانات تسجيل الدخول
      final userPhone = await SecureStorageService.getString('user_phone');
      final driverId = await SecureStorageService.getString('driver_id');

      if (userPhone != null && userPhone.isNotEmpty) {
        // إرسال Token للمستخدم
        final success = await UserService().updateFcmTokenByPhone(userPhone, _fcmToken!);
        if (success) {
          AppLogger.i('✅ FCM Token sent to server for user: $userPhone');
        } else {
          AppLogger.w('⚠️ Failed to send FCM Token to server for user');
        }
      } else if (driverId != null && driverId.isNotEmpty) {
        // إرسال Token للسائق
        final success = await DriverService().updateFcmTokenByDriverId(driverId, _fcmToken!);
        if (success) {
          AppLogger.i('✅ FCM Token sent to server for driver: $driverId');
        } else {
          AppLogger.w('⚠️ Failed to send FCM Token to server for driver');
        }
      } else {
        AppLogger.d('No user/driver logged in, FCM Token not sent to server');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error sending FCM Token to server', e, stackTrace);
    }
  }

  /// إرسال FCM Token إلى السيرفر
  /// يُستدعى بعد تسجيل الدخول
  Future<void> sendTokenToServer({
    String? userId,
    String? driverId,
    String? phone,
  }) async {
    if (_fcmToken == null) {
      AppLogger.w('FCM Token is null, cannot send to server');
      // محاولة الحصول على Token مرة أخرى
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        if (_fcmToken == null) {
          AppLogger.w('Still no FCM Token available');
          return;
        }
      } catch (e) {
        AppLogger.e('Error getting FCM Token', e);
        return;
      }
    }

    try {
      bool success = false;

      if (phone != null && phone.isNotEmpty) {
        // إرسال Token للمستخدم برقم الهاتف
        success = await UserService().updateFcmTokenByPhone(phone, _fcmToken!);
        if (success) {
          AppLogger.i('✅ FCM Token sent to server for user phone: $phone');
          print('✅ FCM Token sent to server for user phone: $phone'); // Print للتحقق في Release APK
        } else {
          AppLogger.w('⚠️ Failed to send FCM Token to server for user phone: $phone');
          print('⚠️ Failed to send FCM Token to server for user phone: $phone'); // Print للتحقق في Release APK
        }
      } else if (driverId != null && driverId.isNotEmpty) {
        // إرسال Token للسائق
        success = await DriverService().updateFcmTokenByDriverId(driverId, _fcmToken!);
        if (success) {
          AppLogger.i('✅ FCM Token sent to server for driver: $driverId');
          print('✅ FCM Token sent to server for driver: $driverId'); // Print للتحقق في Release APK
        } else {
          AppLogger.w('⚠️ Failed to send FCM Token to server for driver: $driverId');
          print('⚠️ Failed to send FCM Token to server for driver: $driverId'); // Print للتحقق في Release APK
        }
      } else if (userId != null && userId.isNotEmpty) {
        // إرسال Token للمستخدم بـ ID
        success = await UserService().updateFcmToken(userId, _fcmToken!);
        if (success) {
          AppLogger.i('✅ FCM Token sent to server for user ID: $userId');
          print('✅ FCM Token sent to server for user ID: $userId'); // Print للتحقق في Release APK
        } else {
          AppLogger.w('⚠️ Failed to send FCM Token to server for user ID: $userId');
          print('⚠️ Failed to send FCM Token to server for user ID: $userId'); // Print للتحقق في Release APK
        }
      } else {
        AppLogger.w('No phone, driverId, or userId provided');
        print('⚠️ No phone, driverId, or userId provided for FCM Token'); // Print للتحقق في Release APK
        return;
      }

      if (!success) {
        AppLogger.w('⚠️ Failed to send FCM Token to server');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error sending FCM Token to server', e, stackTrace);
    }
  }
}

