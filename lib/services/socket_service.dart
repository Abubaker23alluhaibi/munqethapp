import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../core/utils/app_logger.dart';
import '../utils/constants.dart';
import 'local_notification_service.dart';
import '../core/storage/secure_storage_service.dart';

/// خدمة Socket.IO للاتصال بالسيرفر
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  final LocalNotificationService _notificationService = LocalNotificationService();

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  /// الاتصال بـ Socket.IO server
  Future<void> connect() async {
    if (_socket?.connected == true) {
      AppLogger.d('Socket already connected');
      return;
    }

    try {
      AppLogger.d('Connecting to Socket.IO server...');

      // استخراج base URL بدون /api
      String socketUrl = AppConstants.baseUrl.replaceAll('/api', '');
      
      AppLogger.d('Socket URL: $socketUrl');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setTimeout(20000)
            .build(),
      );

      _setupSocketListeners();
    } catch (e, stackTrace) {
      AppLogger.e('Error connecting to Socket.IO server', e, stackTrace);
    }
  }

  /// إعداد Socket listeners
  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      AppLogger.i('✅ Socket.IO connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      AppLogger.w('Socket.IO disconnected');
    });

    _socket!.onConnectError((error) {
      AppLogger.e('Socket.IO connection error: $error');
    });

    _socket!.onError((error) {
      AppLogger.e('Socket.IO error: $error');
    });

    // الاستماع للإشعارات (مع فلترة حسب رقم الهاتف والدور)
    _socket!.on('notification', (data) async {
      AppLogger.d('📨 Notification received via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        // التحقق من أن الإشعار موجه للمستخدم الحالي
        final shouldShow = await _shouldShowNotification(data);
        if (shouldShow) {
          _notificationService.showNotificationFromSocket(data);
        } else {
          AppLogger.d('🔇 Notification filtered out - not for current user');
        }
      }
    });

    // الاستماع للطلبات الجديدة
    _socket!.on('order:new', (data) {
      AppLogger.d('📦 New order received via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        final isForThisDriver = data['isForThisDriver'] as bool? ?? false;
        if (isForThisDriver) {
          // إشعار للسائق
          _notificationService.showNotification(
            title: 'طلب جديد متاح',
            body: 'لديك طلب جديد - اضغط لعرض التفاصيل',
            data: {
              'type': 'new_order',
              'orderId': data['_id']?.toString(),
            },
          );
        }
      }
    });

    // الاستماع لتحديثات حالة الطلب (مع فلترة حسب رقم الهاتف والدور)
    _socket!.on('order:status:updated', (data) async {
      AppLogger.d('🔄 Order status updated via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        // التحقق من أن التحديث موجه للمستخدم الحالي
        // ملاحظة: تحديثات حالة الطلب عادة تكون عامة، لكن سنعتمد على FCM للإشعارات
        // لذلك سنعطل الإشعارات من Socket.IO هنا لتجنب التكرار
        AppLogger.d('🔇 Order status update received via Socket.IO - skipping notification (FCM will handle it)');
        // لا نعرض إشعار هنا - FCM سيرسل الإشعار للمستخدمين الصحيحين فقط
      }
    });
  }

  /// الاشتراك في room (مثل driver room أو order room)
  void joinRoom(String room) {
    if (_socket?.connected != true) {
      AppLogger.w('Socket not connected, cannot join room: $room');
      return;
    }

    AppLogger.d('Joining room: $room');
    _socket!.emit('join', room);
  }

  /// الاشتراك في driver room
  void joinDriverRoom(String driverId) {
    joinRoom('driver:$driverId');
    _socket?.emit('driver:join', driverId);
  }

  /// الاشتراك في order room
  void joinOrderRoom(String orderId) {
    joinRoom('order:$orderId');
    _socket?.emit('order:track', orderId);
  }

  /// التحقق من أن الإشعار موجه للمستخدم الحالي
  Future<bool> _shouldShowNotification(Map<String, dynamic> data) async {
    try {
      // جلب رقم الهاتف المحفوظ (للمستخدم)
      final userPhone = await SecureStorageService.getString('user_phone');
      // جلب driverId المحفوظ (للسائق)
      final driverId = await SecureStorageService.getString('driver_id');
      
      // جلب رقم الهاتف من بيانات الإشعار
      final notificationPhone = data['phone'] as String?;
      final notificationType = data['type'] as String?;
      
      // إذا كان الإشعار يحتوي على رقم هاتف، تحقق من أنه مطابق للمستخدم الحالي
      if (notificationPhone != null && notificationPhone.isNotEmpty) {
        // تطبيع رقم الهاتف للمقارنة (إزالة المسافات والرموز)
        String normalizePhone(String phone) {
          return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        }
        
        final normalizedNotificationPhone = normalizePhone(notificationPhone);
        final normalizedUserPhone = userPhone != null ? normalizePhone(userPhone) : '';
        
        // إذا كان المستخدم مسجل دخول وكان رقم الهاتف يطابق، اعرض الإشعار
        if (userPhone != null && normalizedNotificationPhone == normalizedUserPhone) {
          AppLogger.d('✅ Notification matches current user phone: $notificationPhone');
          return true;
        }
        
        // إذا كان رقم الهاتف لا يطابق، لا تعرض الإشعار
        AppLogger.d('🔇 Notification phone ($notificationPhone) does not match current user phone ($userPhone)');
        return false;
      }
      
      // إذا كان الإشعار من نوع order_taken أو order_update للسائق، تحقق من driverId
      if (notificationType == 'order_taken' || notificationType == 'order_update') {
        // هذه الإشعارات للسائقين - إذا كان المستخدم الحالي سائق، اعرض الإشعار
        if (driverId != null && driverId.isNotEmpty) {
          AppLogger.d('✅ Notification is for driver - current user is driver: $driverId');
          return true;
        }
        // إذا لم يكن المستخدم سائق، لا تعرض الإشعار
        AppLogger.d('🔇 Notification is for driver but current user is not a driver');
        return false;
      }
      
      // إذا كان الإشعار من نوع new_order، فهو للسائقين فقط
      if (notificationType == 'new_order') {
        if (driverId != null && driverId.isNotEmpty) {
          AppLogger.d('✅ New order notification - current user is driver: $driverId');
          return true;
        }
        AppLogger.d('🔇 New order notification but current user is not a driver');
        return false;
      }
      
      // إذا لم يكن هناك معلومات كافية للفلترة، لا تعرض الإشعار (لتجنب الإشعارات الخاطئة)
      AppLogger.d('🔇 Notification does not contain enough info to filter - skipping to avoid wrong notifications');
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Error checking if notification should be shown', e, stackTrace);
      // في حالة الخطأ، لا تعرض الإشعار (آمن أكثر)
      return false;
    }
  }

  /// قطع الاتصال
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    AppLogger.d('Socket disconnected');
  }
}

