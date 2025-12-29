import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../core/utils/app_logger.dart';
import '../utils/constants.dart';
import 'local_notification_service.dart';

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

    // الاستماع للإشعارات
    _socket!.on('notification', (data) {
      AppLogger.d('📨 Notification received via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        _notificationService.showNotificationFromSocket(data);
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

    // الاستماع لتحديثات حالة الطلب
    _socket!.on('order:status:updated', (data) {
      AppLogger.d('🔄 Order status updated via Socket.IO: $data');
      if (data is Map<String, dynamic>) {
        final status = data['status'] as String?;
        final orderId = data['orderId'] as String?;

        String title = 'تحديث الطلب';
        String body = 'تم تحديث حالة طلبك';

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
            body = 'تم إلغاء طلبك';
            break;
        }

        _notificationService.showNotification(
          title: title,
          body: body,
          data: {
            'type': 'order_update',
            'orderId': orderId,
            'status': status,
          },
        );
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

  /// قطع الاتصال
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    AppLogger.d('Socket disconnected');
  }
}

