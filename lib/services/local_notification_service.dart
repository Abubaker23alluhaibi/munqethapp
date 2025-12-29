import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/utils/app_logger.dart';

/// خدمة الإشعارات المحلية (بدون Firebase)
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('LocalNotificationService already initialized');
      return;
    }

    try {
      AppLogger.d('Initializing LocalNotificationService...');

      // تهيئة Local Notifications
      await _initializeLocalNotifications();
      AppLogger.d('Local notifications initialized');

      // طلب صلاحيات الإشعارات
      await _requestPermissions();
      AppLogger.d('Notification permissions requested');

      _isInitialized = true;
      AppLogger.i('✅ LocalNotificationService initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.e('Error initializing LocalNotificationService', e, stackTrace);
      _isInitialized = false;
    }
  }

  /// طلب صلاحيات الإشعارات
  Future<void> _requestPermissions() async {
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

  /// معالجة النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      AppLogger.d('Notification tapped: ${response.payload}');
      // يمكن إضافة navigation logic هنا
    }
  }

  /// عرض إشعار محلي
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int? id,
  }) async {
    try {
      if (!_isInitialized) {
        AppLogger.w('LocalNotificationService not initialized, initializing now...');
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'munqeth_channel',
        'منقذ',
        channelDescription: 'إشعارات تطبيق المنقذ',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
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

      final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final payload = data != null ? data.toString() : null;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      AppLogger.d('✅ Local notification shown: $title');
    } catch (e, stackTrace) {
      AppLogger.e('Error showing local notification', e, stackTrace);
    }
  }

  /// عرض إشعار من بيانات Socket.IO
  Future<void> showNotificationFromSocket(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'منقذ';
    final body = data['body'] as String? ?? '';
    final orderId = data['orderId'] as String?;
    final type = data['type'] as String?;

    await showNotification(
      title: title,
      body: body,
      data: {
        'type': type,
        'orderId': orderId,
        ...data,
      },
    );
  }
}

