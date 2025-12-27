import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../providers/order_provider.dart';
import '../../services/driver_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/empty_state.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  Driver? _driver;
  bool _isLoading = true;
  StreamSubscription<RemoteMessage>? _notificationSubscription;
  Timer? _updateTimer;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadOrderData();
    _setupNotificationListener();
    // تحديث الطلب كل 5 ثواني
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadOrderData();
      }
    });
  }

  void _setupNotificationListener() {
    // الاستماع للإشعارات عند وصولها
    _notificationSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'order_update' && data['orderId'] == widget.orderId) {
        // تحديث بيانات الطلب عند وصول إشعار
        _loadOrderData();
        
        // عرض إشعار محلي
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'تحديث الطلب',
          body: message.notification?.body ?? 'تم تحديث حالة طلبك',
          data: data,
        );
      } else if (data['type'] == 'driver_accepted' && data['orderId'] == widget.orderId) {
        // إشعار موافقة السائق
        _loadOrderData();
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'تم قبول الطلب',
          body: message.notification?.body ?? 'تم قبول طلبك من قبل سائق',
          data: data,
        );
      } else if (data['type'] == 'driver_on_way' && data['orderId'] == widget.orderId) {
        // إشعار "في الطريق إليك"
        _loadOrderData();
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'السائق في الطريق',
          body: message.notification?.body ?? 'السائق في الطريق إليك',
          data: data,
        );
      } else if (data['type'] == 'driver_approaching' && data['orderId'] == widget.orderId) {
        // إشعار اقتراب السائق
        _loadOrderData();
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'اقترب السائق',
          body: message.notification?.body ?? 'السائق في طريقه إليك الآن',
          data: data,
        );
      } else if (data['type'] == 'order_cancelled' && data['orderId'] == widget.orderId) {
        // إشعار إلغاء الطلب
        _loadOrderData();
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'تم إلغاء الطلب',
          body: message.notification?.body ?? 'تم إلغاء طلبك',
          data: data,
        );
      }
    });
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.loadOrder(widget.orderId);

      final order = orderProvider.currentOrder;
      if (order != null && order.driverId != null) {
        final driverService = DriverService();
        // محاولة جلب السائق من جميع السائقين (ليس فقط المتاحين)
        try {
          _driver = await driverService.getDriverById(order.driverId!);
        } catch (e) {
          // إذا فشل، جرب من المتاحين
          try {
            final drivers = await driverService.getAvailableDrivers();
            _driver = drivers.firstWhere((d) => d.id == order.driverId);
          } catch (e2) {
            // Driver not found
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _updateMapCamera();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateMapCamera() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.currentOrder;

    if (_mapController != null && order != null) {
      if (order.customerLatitude != null && order.customerLongitude != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(order.customerLatitude!, order.customerLongitude!),
            14,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder(Order order) async {
    // لا يمكن الإلغاء بعد وصول السائق
    if (order.status == OrderStatus.arrived ||
        order.status == OrderStatus.inProgress ||
        order.status == OrderStatus.delivered ||
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إلغاء الطلب بعد وصول السائق للموقع'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟ سيتم إشعار السائق بالإلغاء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.cancelOrder(order.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadOrderData();
        // الرجوع للشاشة السابقة بعد ثانية
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.pop();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.errorMessage ?? 'فشل إلغاء الطلب'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.currentOrder;

    if (order == null) return markers;

    // Customer location marker
    if (order.customerLatitude != null && order.customerLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(
            order.customerLatitude!,
            order.customerLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'موقع العميل',
            snippet: order.customerAddress ?? order.customerName,
          ),
        ),
      );
    }

    // Driver location marker
    if (_driver != null &&
        _driver!.currentLatitude != null &&
        _driver!.currentLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            _driver!.currentLatitude!,
            _driver!.currentLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'السائق: ${_driver!.name}',
            snippet: _driver!.phone,
          ),
        ),
      );
    }

    // Destination marker (for taxi orders)
    if (order.destinationLatitude != null &&
        order.destinationLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            order.destinationLatitude!,
            order.destinationLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'موقع الوجهة',
            snippet: order.destinationAddress ?? 'الوجهة',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.currentOrder;

    if (order == null) return polylines;

    // Route from driver to customer
    if (_driver != null &&
        _driver!.currentLatitude != null &&
        _driver!.currentLongitude != null &&
        order.customerLatitude != null &&
        order.customerLongitude != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(_driver!.currentLatitude!, _driver!.currentLongitude!),
            LatLng(order.customerLatitude!, order.customerLongitude!),
          ],
          color: AppTheme.primaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    // Route from customer to destination (for taxi)
    if (order.destinationLatitude != null &&
        order.destinationLongitude != null &&
        order.customerLatitude != null &&
        order.customerLongitude != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('destination_route'),
          points: [
            LatLng(order.customerLatitude!, order.customerLongitude!),
            LatLng(order.destinationLatitude!, order.destinationLongitude!),
          ],
          color: AppTheme.errorColor,
          width: 3,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      );
    }

    return polylines;
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
        return Colors.cyan;
      case OrderStatus.arrived:
        return Colors.teal;
      case OrderStatus.inProgress:
        return Colors.indigo;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return AppTheme.successColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('تتبع الطلب'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  final order = orderProvider.currentOrder;

                  if (order == null) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'الطلب غير موجود',
                      message: 'لم يتم العثور على الطلب المطلوب',
                      buttonText: 'العودة',
                      onButtonPressed: () => context.pop(),
                    );
                  }

                  final defaultLocation = order.customerLatitude != null &&
                          order.customerLongitude != null
                      ? LatLng(order.customerLatitude!, order.customerLongitude!)
                      : const LatLng(33.3152, 44.3661);

                  return Column(
                    children: [
                      // Map
                      Expanded(
                        flex: 2,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: defaultLocation,
                            zoom: 14,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMapCamera();
                          },
                          markers: _buildMarkers(),
                          polylines: _buildPolylines(),
                          myLocationButtonEnabled: false,
                          myLocationEnabled: true,
                          zoomControlsEnabled: false,
                          mapType: MapType.normal,
                        ),
                      ),
                      // Order Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getStatusColor(order.status),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    order.status.arabicName,
                                    style: TextStyle(
                                      color: _getStatusColor(order.status),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'طلب #${order.id}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Driver Info
                            if (_driver != null) ...[
                              Row(
                                children: [
                                  Icon(Icons.person, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'السائق: ${_driver!.name}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _driver!.phone,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.phone),
                                    color: AppTheme.primaryColor,
                                    onPressed: () {
                                      // يمكن إضافة مكالمة
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Customer Info
                            Row(
                              children: [
                                Icon(Icons.location_on, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'موقع التوصيل',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        order.customerAddress ??
                                            order.customerName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (order.destinationAddress != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.place, color: AppTheme.errorColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'موقع الوجهة',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          order.destinationAddress!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // زر إلغاء الطلب (للزبون - قبل وصول السائق)
                            // يمكن الإلغاء في حالات: pending, preparing, ready, accepted (قبل arrived)
                            if (order.status != OrderStatus.arrived &&
                                order.status != OrderStatus.inProgress &&
                                order.status != OrderStatus.delivered &&
                                order.status != OrderStatus.completed &&
                                order.status != OrderStatus.cancelled) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _cancelOrder(order),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('إلغاء الطلب'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: const BorderSide(color: AppTheme.errorColor),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}







