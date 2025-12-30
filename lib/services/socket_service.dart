import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:async';
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
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _keepAliveInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

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
            .setReconnectionAttempts(_maxReconnectAttempts)
            .setReconnectionDelay(2000)
            .setTimeout(20000)
            .setReconnectionDelayMax(10000)
            .build(),
      );

      _setupSocketListeners();
      _startKeepAlive();
    } catch (e, stackTrace) {
      AppLogger.e('Error connecting to Socket.IO server', e, stackTrace);
    }
  }

  /// إعداد Socket listeners
  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      _reconnectAttempts = 0;
      AppLogger.i('✅✅✅ Socket.IO connected successfully - ready to receive notifications');
      _startKeepAlive();
      _stopReconnectTimer();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      AppLogger.w('Socket.IO disconnected');
      _stopKeepAlive();
      _startReconnectTimer();
    });

    _socket!.onConnectError((error) {
      AppLogger.e('Socket.IO connection error: $error');
      _isConnected = false;
      _startReconnectTimer();
    });

    _socket!.onError((error) {
      AppLogger.e('Socket.IO error: $error');
    });

    // الاستماع للإشعارات (مع فلترة حسب رقم الهاتف والدور)
    _socket!.on('notification', (data) async {
      AppLogger.i('📨📨📨 Notification received via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        // التحقق من أن الإشعار موجه للمستخدم الحالي
        final shouldShow = await _shouldShowNotification(data);
        AppLogger.i('🔍 Should show notification: $shouldShow');
        if (shouldShow) {
          AppLogger.i('✅ Showing notification: ${data['title']} - ${data['body']}');
          await _notificationService.showNotificationFromSocket(data);
        } else {
          AppLogger.w('🔇 Notification filtered out - not for current user');
        }
      } else {
        AppLogger.w('⚠️ Notification data is not Map: ${data.runtimeType}');
      }
    });

    // الاستماع للطلبات الجديدة
    _socket!.on('order:new', (data) async {
      AppLogger.i('📦📦📦 New order received via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        // التحقق من أن الطلب موجه للسائق الحالي
        final shouldShow = await _shouldShowNewOrderNotification(data);
        AppLogger.i('🔍 Should show new order notification: $shouldShow');
        if (shouldShow) {
          AppLogger.i('✅ Showing new order notification');
          // إشعار للسائق
          await _notificationService.showNotification(
            title: 'طلب جديد متاح',
            body: 'لديك طلب جديد - اضغط لعرض التفاصيل',
            data: {
              'type': 'new_order',
              'orderId': data['_id']?.toString() ?? data['id']?.toString(),
            },
          );
        } else {
          AppLogger.w('🔇 New order notification filtered out');
        }
      } else {
        AppLogger.w('⚠️ New order data is not Map: ${data.runtimeType}');
      }
    });

    // الاستماع لتحديثات حالة الطلب (مع فلترة حسب رقم الهاتف والدور)
    _socket!.on('order:status:updated', (data) async {
      AppLogger.i('🔄🔄🔄 Order status updated via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        // التحقق من أن التحديث موجه للمستخدم الحالي
        final shouldShow = await _shouldShowOrderStatusNotification(data);
        AppLogger.i('🔍 Should show order status notification: $shouldShow');
        if (shouldShow) {
          AppLogger.i('✅ Showing order status notification');
          await _showOrderStatusNotification(data);
        } else {
          AppLogger.w('🔇 Order status update filtered out - not for current user');
        }
      } else {
        AppLogger.w('⚠️ Order status data is not Map: ${data.runtimeType}');
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

  /// التحقق من أن طلب جديد موجه للسائق الحالي
  Future<bool> _shouldShowNewOrderNotification(Map<String, dynamic> data) async {
    try {
      // جلب driverId المحفوظ (للسائق)
      final driverId = await SecureStorageService.getString('driver_id');
      
      // إذا لم يكن المستخدم سائق، لا تعرض الإشعار
      if (driverId == null || driverId.isEmpty) {
        AppLogger.d('🔇 New order notification - current user is not a driver');
        return false;
      }
      
      // جلب نوع الخدمة من الطلب
      final orderType = data['type'] as String?;
      final serviceType = data['serviceType'] as String?;
      
      // إذا كان هناك نوع خدمة محدد، يمكن إضافة فلترة إضافية هنا
      // حالياً نعرض الإشعار لجميع السائقين المتاحين
      
      AppLogger.d('✅ New order notification - current user is driver: $driverId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error checking if new order notification should be shown', e, stackTrace);
      return false;
    }
  }

  /// التحقق من أن الإشعار موجه للمستخدم الحالي
  Future<bool> _shouldShowNotification(Map<String, dynamic> data) async {
    try {
      // جلب رقم الهاتف المحفوظ (للمستخدم)
      final userPhone = await SecureStorageService.getString('user_phone');
      // جلب driverId المحفوظ (للسائق)
      final driverId = await SecureStorageService.getString('driver_id');
      
      AppLogger.d('🔍 Checking notification filter - userPhone: ${userPhone != null ? "exists" : "null"}, driverId: ${driverId != null ? "exists" : "null"}');
      
      // جلب رقم الهاتف من بيانات الإشعار
      final notificationPhone = data['phone'] as String?;
      final notificationType = data['type'] as String?;
      
      AppLogger.d('🔍 Notification data - phone: $notificationPhone, type: $notificationType');
      
      // إذا كان الإشعار يحتوي على رقم هاتف، فهو للزبون فقط - لا تعرضه للسائق
      if (notificationPhone != null && notificationPhone.isNotEmpty) {
        // تطبيع رقم الهاتف للمقارنة (إزالة المسافات والرموز)
        String normalizePhone(String phone) {
          return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        }
        
        final normalizedNotificationPhone = normalizePhone(notificationPhone);
        final normalizedUserPhone = userPhone != null ? normalizePhone(userPhone) : '';
        
        // إذا كان المستخدم (الزبون) مسجل دخول وكان رقم الهاتف يطابق، اعرض الإشعار
        if (userPhone != null && normalizedNotificationPhone == normalizedUserPhone) {
          AppLogger.d('✅ Notification matches current user phone: $notificationPhone');
          return true;
        }
        
        // إذا كان رقم الهاتف لا يطابق أو المستخدم الحالي سائق، لا تعرض الإشعار
        AppLogger.d('🔇 Notification phone ($notificationPhone) does not match current user phone ($userPhone) or user is driver');
        return false;
      }
      
      // إذا كان الإشعار من نوع order_taken أو order_update بدون رقم هاتف، تحقق من driverId
      // (هذه الإشعارات للسائقين فقط عندما لا تحتوي على رقم هاتف)
      if (notificationType == 'order_taken' || notificationType == 'order_update' || 
          notificationType == 'driver_accepted' || notificationType == 'driver_on_way' || 
          notificationType == 'order_cancelled') {
        // هذه الإشعارات للسائقين فقط - إذا كان المستخدم الحالي سائق، اعرض الإشعار
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
      
      // إذا لم يكن هناك معلومات كافية للفلترة، اعرض الإشعار فقط للزبون (لأن السيرفر يفلتر)
      if (userPhone != null && driverId == null) {
        AppLogger.d('⚠️ Notification does not contain enough info to filter - showing for user (server filtered)');
        return true;
      }
      
      // إذا كان المستخدم سائق ولا يوجد معلومات كافية، لا تعرض (آمن أكثر)
      AppLogger.d('⚠️ Notification does not contain enough info to filter - not showing for driver (server filtered)');
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Error checking if notification should be shown', e, stackTrace);
      // في حالة الخطأ، لا تعرض الإشعار (آمن أكثر)
      return false;
    }
  }

  /// التحقق من أن تحديث حالة الطلب موجه للمستخدم الحالي
  Future<bool> _shouldShowOrderStatusNotification(Map<String, dynamic> data) async {
    try {
      final orderId = data['orderId'] as String?;
      if (orderId == null) return false;

      // جلب رقم الهاتف المحفوظ (للمستخدم)
      final userPhone = await SecureStorageService.getString('user_phone');
      // جلب driverId المحفوظ (للسائق)
      final driverId = await SecureStorageService.getString('driver_id');
      
      AppLogger.d('🔍 Order status filter - orderId: $orderId, userPhone: ${userPhone != null ? "exists" : "null"}, driverId: ${driverId != null ? "exists" : "null"}');
      
      // التحقق من customerPhone و driverId في بيانات الإشعار
      final customerPhone = data['customerPhone'] as String?;
      final orderDriverId = data['driverId'] as String?;
      
      // إذا كان الإشعار يحتوي على customerPhone، فهو للزبون فقط
      if (customerPhone != null && customerPhone.isNotEmpty) {
        if (userPhone != null && driverId == null) {
          // تطبيع رقم الهاتف للمقارنة
          String normalizePhone(String phone) {
            return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          }
          
          final normalizedCustomerPhone = normalizePhone(customerPhone);
          final normalizedUserPhone = normalizePhone(userPhone);
          
          if (normalizedCustomerPhone == normalizedUserPhone) {
            AppLogger.d('✅ Order status update - matches customer phone: $customerPhone');
            return true;
          } else {
            AppLogger.d('🔇 Order status update - customer phone ($customerPhone) does not match user phone ($userPhone)');
            return false;
          }
        } else {
          // إذا كان المستخدم سائق، لا تعرض إشعارات الزبون
          AppLogger.d('🔇 Order status update - contains customerPhone but current user is driver, not showing');
          return false;
        }
      }
      
      // إذا كان الإشعار يحتوي على driverId، فهو للسائق فقط
      if (orderDriverId != null && orderDriverId.isNotEmpty) {
        if (driverId != null && driverId.isNotEmpty) {
          if (orderDriverId == driverId || orderDriverId.toString() == driverId.toString()) {
            AppLogger.d('✅ Order status update - matches driver ID: $orderDriverId');
            return true;
          } else {
            AppLogger.d('🔇 Order status update - driver ID ($orderDriverId) does not match current driver ($driverId)');
            return false;
          }
        } else {
          // إذا كان المستخدم زبون، لا تعرض إشعارات السائق
          AppLogger.d('🔇 Order status update - contains driverId but current user is customer, not showing');
          return false;
        }
      }
      
      // إذا لم يكن هناك معلومات للفلترة، لا تعرض الإشعار (آمن أكثر)
      // لأن الإشعارات الفعلية تأتي عبر FCM مع فلترة صحيحة
      AppLogger.w('⚠️ Order status update - no customerPhone or driverId in data, not showing (FCM handles actual notifications)');
      return false;
    } catch (e, stackTrace) {
      AppLogger.e('Error checking if order status notification should be shown', e, stackTrace);
      return false;
    }
  }

  /// عرض إشعار تحديث حالة الطلب
  Future<void> _showOrderStatusNotification(Map<String, dynamic> data) async {
    try {
      final orderId = data['orderId'] as String?;
      final status = data['status'] as String?;
      
      if (orderId == null || status == null) return;

      // تحديد رسالة الإشعار حسب الحالة
      String title = 'تحديث الطلب';
      String body = 'تم تحديث حالة الطلب';
      
      switch (status) {
        case 'accepted':
          title = 'تم قبول طلبك';
          body = 'تم قبول طلبك - السائق في الطريق إليك';
          break;
        case 'arrived':
          title = 'وصل السائق';
          body = 'وصل السائق إلى موقعك';
          break;
        case 'in_progress':
          title = 'السائق في الطريق';
          body = 'السائق في الطريق إليك';
          break;
        case 'delivered':
          title = 'تم التوصيل';
          body = 'تم التوصيل بنجاح';
          break;
        case 'completed':
          title = 'تم إكمال الطلب';
          body = 'تم إكمال طلبك بنجاح';
          break;
        case 'cancelled':
          title = 'تم إلغاء الطلب';
          body = 'تم إلغاء الطلب';
          break;
        default:
          title = 'تحديث الطلب';
          body = 'تم تحديث حالة الطلب إلى: $status';
      }

      await _notificationService.showNotification(
        title: title,
        body: body,
        data: {
          'type': 'order_status_update',
          'orderId': orderId,
          'status': status,
        },
      );
    } catch (e, stackTrace) {
      AppLogger.e('Error showing order status notification', e, stackTrace);
    }
  }

  /// إرسال Keep-alive ping للحفاظ على الاتصال
  void _startKeepAlive() {
    _stopKeepAlive();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) {
      if (_socket?.connected == true) {
        try {
          // إرسال ping للحفاظ على الاتصال
          _socket?.emit('ping', DateTime.now().millisecondsSinceEpoch);
          AppLogger.d('📡 Keep-alive ping sent');
        } catch (e) {
          AppLogger.e('Error sending keep-alive ping', e);
        }
      } else {
        _stopKeepAlive();
      }
    });
  }

  /// إيقاف Keep-alive
  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// بدء محاولات إعادة الاتصال
  void _startReconnectTimer() {
    _stopReconnectTimer();
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.w('Max reconnection attempts reached, will retry later');
      // إعادة المحاولة بعد فترة أطول
      _reconnectTimer = Timer(const Duration(minutes: 5), () {
        _reconnectAttempts = 0;
        _startReconnectTimer();
      });
      return;
    }

    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      AppLogger.d('🔄 Attempting to reconnect Socket.IO (attempt $_reconnectAttempts/$_maxReconnectAttempts)...');
      
      if (_socket?.connected != true) {
        try {
          _socket?.connect();
        } catch (e) {
          AppLogger.e('Error reconnecting Socket.IO', e);
          _startReconnectTimer();
        }
      }
    });
  }

  /// إيقاف محاولات إعادة الاتصال
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// إعادة الاتصال يدوياً
  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    disconnect();
    await Future.delayed(const Duration(seconds: 2));
    await connect();
  }

  /// قطع الاتصال
  void disconnect() {
    _stopKeepAlive();
    _stopReconnectTimer();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    AppLogger.d('Socket disconnected');
  }
}

