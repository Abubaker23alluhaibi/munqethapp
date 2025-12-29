import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../models/supermarket.dart';
import '../../services/driver_service.dart';
import '../../services/order_service.dart';
import '../../services/supermarket_service.dart';
import '../../providers/order_provider.dart';
import '../../core/utils/distance_calculator.dart';

class DriverOrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const DriverOrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DriverOrderDetailsScreen> createState() => _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  final _driverService = DriverService();
  final _orderService = OrderService();
  final _supermarketService = SupermarketService();

  Order? _order;
  Driver? _driver;
  Supermarket? _supermarket;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Driver location tracking
  Position? _currentDriverPosition;
  StreamSubscription<Position>? _positionStream;
  double? _distanceToCustomer;
  Timer? _distanceUpdateTimer;
  bool _hasSentApproachingNotification = false;
  

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _distanceUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final driver = await _driverService.getCurrentDriver();
      if (driver == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      // محاولة الحصول على الطلب مباشرة من API أولاً
      Order? order;
      try {
        final allOrders = await _orderService.getAllOrdersForDriver();
        try {
          order = allOrders.firstWhere((o) => o.id == widget.orderId);
        } catch (e) {
          // إذا لم يُوجد في القائمة، محاولة مرة أخرى بعد قليل (في حالة التحديث)
          await Future.delayed(const Duration(milliseconds: 500));
          final retryOrders = await _orderService.getAllOrdersForDriver();
          try {
            order = retryOrders.firstWhere((o) => o.id == widget.orderId);
          } catch (e2) {
            // Order not found
          }
        }
      } catch (e) {
        // Error loading orders
      }
      
      if (order == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الطلب غير موجود'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          // لا نخرج مباشرة، فقط نعرض رسالة خطأ
          return;
        }
      }

      Supermarket? supermarket;
      if (order != null && order.type == 'delivery' && order.supermarketId != null) {
        supermarket = await _supermarketService.getCurrentSupermarket();
        if (supermarket == null && order.supermarketId != null) {
          supermarket = await _supermarketService.getSupermarketById(order.supermarketId!);
        }
      }

      if (mounted) {
        setState(() {
          _driver = driver;
          _order = order;
          _supermarket = supermarket;
          _isLoading = false;
        });
        // Update map markers after order is loaded
        _updateMapMarkers();
        // Start location tracking
        _startLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _openMapApp(String app) async {
    if (_order?.customerLatitude == null ||
        _order?.customerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('موقع العميل غير متوفر'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final lat = _order!.customerLatitude!;
    final lng = _order!.customerLongitude!;

    String url;
    switch (app) {
      case 'google':
        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
        break;
      case 'waze':
        // استخدام صيغة Waze الصحيحة
        url = 'waze://?ll=$lat,$lng&navigate=yes';
        break;
      case 'apple':
        url = 'https://maps.apple.com/?daddr=$lat,$lng';
        break;
      default:
        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }

    try {
      final uri = Uri.parse(url);
      
      // لـ Waze، نحاول فتحه مباشرة بدون التحقق من canLaunchUrl
      // لأن canLaunchUrl قد لا يتعرف على waze:// scheme حتى لو كان التطبيق مثبتاً
      if (app == 'waze') {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          // إذا فشل فتح Waze، حاول فتح Google Maps كبديل
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح Waze. يرجى التأكد من تثبيت التطبيق'),
                backgroundColor: AppTheme.warningColor,
                duration: Duration(seconds: 3),
              ),
            );
            // محاولة فتح Google Maps كبديل
            try {
              final googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
              await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
            } catch (_) {
              // تجاهل الخطأ في فتح Google Maps
            }
          }
        }
      } else {
        // للتطبيقات الأخرى، نستخدم canLaunchUrl أولاً
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح التطبيق'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }


  Widget _buildNavigationOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }


  Future<void> _updateStatus(OrderStatus status) async {
    if (_order == null || _driver == null) return;

    try {
      final success = await _orderService.updateOrderStatusByDriver(
        _order!.id,
        status,
        _driver!.id,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الحالة بنجاح'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
          // إضافة تأخير قصير للتأكد من تحديث السيرفر
          await Future.delayed(const Duration(milliseconds: 800));
          // إعادة تحميل البيانات للتأكد من الحصول على أحدث حالة
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'فشل تحديث الحالة';
        if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptOrder() async {
    if (_order == null || _driver == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبول الطلب'),
        content: Text('هل تريد قبول طلب #${_order!.id}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('قبول'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.acceptOrder(
      _order!.id,
      _driver!.id,
      _driver!.serviceType,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الطلب بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل قبول الطلب'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    if (_order == null || _driver == null) return;

    // التحقق من أن السائق قبل هذا الطلب
    final isDriverOrder = _order!.driverId == _driver!.id;

    // إذا كان السائق لم يقبل الطلب بعد، لا يمكنه إلغاؤه
    if (!isDriverOrder) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب قبول الطلب أولاً'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    // السماح بالإلغاء حتى بعد الوصول (لكن ليس بعد التسليم أو الإكمال)
    if (_order!.status == OrderStatus.delivered ||
        _order!.status == OrderStatus.completed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إلغاء الطلب بعد التسليم'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    // طلب سبب الإلغاء من السائق (مطلوب فقط بعد الوصول)
    final reasonController = TextEditingController();
    final requiresReason = _order!.status == OrderStatus.arrived || 
                           _order!.status == OrderStatus.inProgress;
    
    String? cancellationReason;
    
    // إذا كانت الحالة arrived أو inProgress، يجب طلب سبب الإلغاء
    if (requiresReason) {
      cancellationReason = await showDialog<String>(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إلغاء الطلب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('يرجى كتابة سبب الإلغاء (مطلوب):'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'مثال: العميل لم يأتِ، العنوان غير صحيح، إلخ...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('تراجع'),
              ),
              TextButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى كتابة سبب الإلغاء'),
                        backgroundColor: AppTheme.warningColor,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, reason);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('تأكيد الإلغاء'),
              ),
            ],
          ),
        ),
      );

      // إذا ألغى المستخدم الحوار أو لم يكتب سبباً، لا نفعل شيئاً
      if (cancellationReason == null || cancellationReason.isEmpty) {
        return;
      }
    }

    final finalReason = cancellationReason;

    // تأكيد الإلغاء
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الإلغاء'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
              if (finalReason != null && finalReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سبب الإلغاء:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(finalReason),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.cancelOrder(
        _order!.id,
        driverId: _driver!.id,
        cancellationReason: finalReason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الطلب بنجاح'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadData();
          // الرجوع للشاشة السابقة بعد ثانية
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.pop();
            }
          });
        } else {
          // عرض رسالة الخطأ من Provider
          final errorMessage = orderProvider.errorMessage ?? 'فشل إلغاء الطلب';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'حسناً',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'فشل إلغاء الطلب';
        if (e is Exception) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }


  void _startLocationTracking() {
    if (_driver == null) return;

    _positionStream?.cancel();
    _distanceUpdateTimer?.cancel();

    // تحديث موقع السائق بشكل مستمر
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // تحديث كل 10 متر
      ),
    ).listen(
      (Position position) {
        setState(() {
          _currentDriverPosition = position;
        });
        
        // تحديث موقع السائق في السيرفر
        _driverService.updateDriverLocation(
          _driver!.id,
          position.latitude,
          position.longitude,
        );
        
        // تحديث العلامات والمسافة
        if (mounted) {
          _updateMapMarkers();
          _calculateDistanceToCustomer();
        }
      },
      onError: (error) {
        // Error getting location
      },
    );

    // تحديث المسافة كل 5 ثوانٍ
    _distanceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _calculateDistanceToCustomer();
    });
  }

  void _calculateDistanceToCustomer() {
    if (_currentDriverPosition != null &&
        _order != null &&
        _order!.customerLatitude != null &&
        _order!.customerLongitude != null) {
      final distance = DistanceCalculator.calculateDistance(
        _currentDriverPosition!.latitude,
        _currentDriverPosition!.longitude,
        _order!.customerLatitude!,
        _order!.customerLongitude!,
      );

      if (distance != null) {
        setState(() {
          _distanceToCustomer = distance;
        });

        // إشعار الاقتراب (500 متر = 0.5 كم)
        if (distance < 0.5 && !_hasSentApproachingNotification) {
          _hasSentApproachingNotification = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.near_me, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('اقتربت من موقع العميل! سيتلقى العميل إشعاراً')),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    }
  }


  Future<void> _navigateToCustomer() async {
    if (_order?.customerLatitude == null ||
        _order?.customerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('موقع العميل غير متوفر'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // عرض خيارات تطبيقات الخرائط
    final mapAppResult = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختر تطبيق الخرائط',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Google Maps option
              _buildNavigationOption(
                context,
                icon: Icons.map,
                title: 'Google Maps',
                subtitle: 'افتح في Google Maps',
                color: Colors.blue,
                onTap: () => Navigator.pop(context, 'google'),
              ),
              const SizedBox(height: 12),
              // Apple Maps option
              _buildNavigationOption(
                context,
                icon: Icons.map_outlined,
                title: 'Apple Maps',
                subtitle: 'افتح في خرائط Apple',
                color: Colors.grey[700]!,
                onTap: () => Navigator.pop(context, 'apple'),
              ),
              const SizedBox(height: 12),
              // Waze option
              _buildNavigationOption(
                context,
                icon: Icons.navigation,
                title: 'Waze',
                subtitle: 'افتح في Waze',
                color: Colors.blue.shade700,
                onTap: () => Navigator.pop(context, 'waze'),
              ),
            ],
          ),
        ),
      ),
    );

    if (mapAppResult != null && mounted) {
      await _openMapApp(mapAppResult);
    }
  }

  Future<void> _navigateToDestination() async {
    if (_order == null || 
        _order!.destinationLatitude == null || 
        _order!.destinationLongitude == null) {
      return;
    }

    // عرض خيارات تطبيقات الخرائط
    final mapAppResult = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختر تطبيق الخرائط',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Google Maps option
              _buildNavigationOption(
                context,
                icon: Icons.map,
                title: 'Google Maps',
                subtitle: 'افتح في Google Maps',
                color: Colors.blue,
                onTap: () => Navigator.pop(context, 'google'),
              ),
              const SizedBox(height: 12),
              // Apple Maps option
              _buildNavigationOption(
                context,
                icon: Icons.map_outlined,
                title: 'Apple Maps',
                subtitle: 'افتح في خرائط Apple',
                color: Colors.grey[700]!,
                onTap: () => Navigator.pop(context, 'apple'),
              ),
              const SizedBox(height: 12),
              // Waze option
              _buildNavigationOption(
                context,
                icon: Icons.navigation,
                title: 'Waze',
                subtitle: 'افتح في Waze',
                color: Colors.blue.shade700,
                onTap: () => Navigator.pop(context, 'waze'),
              ),
            ],
          ),
        ),
      ),
    );

    if (mapAppResult != null && mounted) {
      // فتح التطبيق مع موقع الوجهة
      final lat = _order!.destinationLatitude!;
      final lng = _order!.destinationLongitude!;
      
      String url;
      switch (mapAppResult) {
        case 'google':
          url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
          break;
        case 'waze':
          url = 'waze://?ll=$lat,$lng&navigate=yes';
          break;
        case 'apple':
          url = 'https://maps.apple.com/?daddr=$lat,$lng';
          break;
        default:
          url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
      }

      try {
        final uri = Uri.parse(url);
        
        // لـ Waze، نحاول فتحه مباشرة بدون التحقق من canLaunchUrl
        if (mapAppResult == 'waze') {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            // إذا فشل فتح Waze، حاول فتح Google Maps كبديل
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يمكن فتح Waze. يرجى التأكد من تثبيت التطبيق'),
                  backgroundColor: AppTheme.warningColor,
                  duration: Duration(seconds: 3),
                ),
              );
              // محاولة فتح Google Maps كبديل
              try {
                final googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // تجاهل الخطأ في فتح Google Maps
              }
            }
          }
        } else {
          // للتطبيقات الأخرى، نستخدم canLaunchUrl أولاً
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يمكن فتح التطبيق'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Color _getPrimaryColor() {
    final serviceType = _order?.type ?? _driver?.serviceType ?? '';
    switch (serviceType) {
      case 'delivery':
        return Colors.orange;
      case 'taxi':
        return AppTheme.primaryColor;
      case 'crane':
        return Colors.orange.shade700;
      case 'maintenance':
        return Colors.green.shade600;
      case 'car_emergency':
        return Colors.red.shade600;
      case 'fuel':
        return Colors.amber.shade700;
      case 'maid':
        return Colors.purple.shade600;
      case 'car_wash':
        return Colors.blue.shade600;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_order == null) {
      return const Scaffold(
        body: Center(
          child: Text('الطلب غير موجود'),
        ),
      );
    }

    final primaryColor = _getPrimaryColor();
    final isTaxi = _order!.type == 'taxi';
    final isCrane = _order!.type == 'crane';
    final isMaintenance = _order!.type == 'maintenance';
    final isCarEmergency = _order!.type == 'car_emergency';
    final isFuel = _order!.type == 'fuel';
    final isMaid = _order!.type == 'maid';
    final isCarWash = _order!.type == 'car_wash';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text('طلب #${_order!.id}'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Order Info (different for each service type)
                    if (isTaxi || isCrane)
                      _buildTaxiInvoice(_order!, primaryColor, isCrane)
                    else if (isMaintenance || isCarEmergency || isFuel || isMaid || isCarWash)
                      _buildServiceInvoice(_order!, primaryColor)
                    else
                      _buildDeliveryInvoice(_order!, _supermarket, primaryColor),
                    const SizedBox(height: 24),
                    // Map Section
                    if (_order!.customerLatitude != null &&
                        _order!.customerLongitude != null)
                      _buildMapSection(primaryColor, isTaxi),
                    const SizedBox(height: 24),
                    // Action Buttons
                    if (isTaxi || isCrane)
                      _buildTaxiStatusButtons(primaryColor)
                    else if (isMaintenance || isCarEmergency || isFuel || isMaid || isCarWash)
                      _buildServiceStatusButtons(primaryColor)
                    else
                      _buildDeliveryActionButton(primaryColor),
                    // مسافة إضافية في الأسفل لتجنب تداخل الأزرار
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTaxiInvoice(Order order, Color primaryColor, bool isCrane) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  isCrane ? 'فاتورة طلب كرين' : 'فاتورة طلب التكسي',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'طلب #${order.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'التاريخ: ${_formatDate(order.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow('اسم العميل', order.customerName, Icons.person),
          const Divider(),
          _buildInfoRow('رقم الهاتف', order.customerPhone, Icons.phone),
          if (order.customerAddress != null) ...[
            const Divider(),
            _buildInfoRow('العنوان', order.customerAddress!, Icons.location_on),
          ],
          if (order.destinationAddress != null) ...[
            const Divider(),
            _buildInfoRow('الوجهة', order.destinationAddress!, Icons.place),
          ],
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const Divider(),
            _buildInfoRow('ملاحظات', order.notes!, Icons.note),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'المبلغ الإجمالي:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    order.fare != null
                        ? '${order.fare!.toStringAsFixed(0)} دينار'
                        : 'غير محدد',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(order.status),
                  color: _getStatusColor(order.status),
                ),
                const SizedBox(width: 8),
                Text(
                  'الحالة: ${order.status.arabicName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInvoice(Order order, Supermarket? supermarket, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  supermarket?.name ?? 'سوبر ماركت',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                ),
                if (supermarket?.address != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    supermarket!.address!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: primaryColor.withOpacity(0.3)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رقم الفاتورة',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.id,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'التاريخ والوقت',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                            textAlign: TextAlign.end,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightPrimary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات العميل',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('الاسم', order.customerName),
                _buildInfoRow('الهاتف', order.customerPhone),
                if (order.customerAddress != null)
                  _buildInfoRow('العنوان', order.customerAddress!),
              ],
            ),
          ),
          if (order.items != null && order.items!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildTableHeader(primaryColor),
            const SizedBox(height: 12),
            ...order.items!.map((item) => _buildInvoiceItem(item, primaryColor)),
            const SizedBox(height: 16),
            Divider(color: AppTheme.borderColor, thickness: 1),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'المجموع الكلي',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${order.displayTotal.toStringAsFixed(0)} د.ع',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.notes != null) ...[
            const SizedBox(height: 16),
            _buildNotes(order.notes!, primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [IconData? icon]) {
    if (icon != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'المنتج',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'الكمية',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'السعر',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'المجموع',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(OrderItem item, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.price.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.total.toStringAsFixed(0)} د.ع',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(String notes, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note_rounded,
            color: AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملاحظات',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(Color primaryColor, bool isTaxi) {
    final customerLat = _order!.customerLatitude;
    final customerLng = _order!.customerLongitude;
    
    if (customerLat == null || customerLng == null) {
      return const SizedBox.shrink();
    }

    final hasDestination = isTaxi && 
        _order!.destinationLatitude != null && 
        _order!.destinationLongitude != null;

    // Initialize markers and polylines
    if (_markers.isEmpty) {
      _updateMapMarkers();
    }

    // Calculate center point for camera
    LatLng centerPoint;
    if (hasDestination) {
      final destLat = _order!.destinationLatitude!;
      final destLng = _order!.destinationLongitude!;
      centerPoint = LatLng(
        (customerLat + destLat) / 2,
        (customerLng + destLng) / 2,
      );
    } else {
      centerPoint = LatLng(customerLat, customerLng);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isTaxi && hasDestination ? 'موقع العميل والوجهة' : 'موقع العميل',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppTheme.lightPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: centerPoint,
                  zoom: hasDestination ? 12 : 14,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _updateMapCamera();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
                compassEnabled: false,
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                myLocationEnabled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (_order!.customerLatitude != null && _order!.customerLongitude != null) {
      final customerLat = _order!.customerLatitude!;
      final customerLng = _order!.customerLongitude!;
      
      // Customer location marker
      markers.add(
        Marker(
          markerId: const MarkerId('customer_location'),
          position: LatLng(customerLat, customerLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'موقع العميل',
            snippet: _order!.customerAddress ?? _order!.customerName,
          ),
        ),
      );

      // Driver location marker (if tracking)
      if (_currentDriverPosition != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('driver_location'),
            position: LatLng(
              _currentDriverPosition!.latitude,
              _currentDriverPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(
              title: 'موقعك الحالي',
              snippet: 'أنت هنا',
            ),
          ),
        );
        
        // Simple line to customer if driver position available
        polylines.add(
          Polyline(
            polylineId: const PolylineId('simple_route'),
            points: [
              LatLng(_currentDriverPosition!.latitude, _currentDriverPosition!.longitude),
              LatLng(customerLat, customerLng),
            ],
            color: AppTheme.primaryColor.withOpacity(0.5),
            width: 3,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
      }

      // Destination marker (for taxi orders)
      if (_order!.type == 'taxi' && 
          _order!.destinationLatitude != null && 
          _order!.destinationLongitude != null) {
        final destLat = _order!.destinationLatitude!;
        final destLng = _order!.destinationLongitude!;
        
        markers.add(
          Marker(
            markerId: const MarkerId('destination_location'),
            position: LatLng(destLat, destLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'موقع الوجهة',
              snippet: _order!.destinationAddress ?? 'الوجهة',
            ),
          ),
        );

        // Show direct line to destination if no driver position
        if (_currentDriverPosition == null) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('destination_route'),
              points: [
                LatLng(customerLat, customerLng),
                LatLng(destLat, destLng),
              ],
              color: AppTheme.errorColor,
              width: 3,
              patterns: [PatternItem.dash(15), PatternItem.gap(10)],
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = polylines;
      });
    }
  }

  void _updateMapCamera() {
    if (_mapController == null || _order == null) return;

    final customerLat = _order!.customerLatitude;
    final customerLng = _order!.customerLongitude;
    
    if (customerLat == null || customerLng == null) return;

    LatLng centerPoint;
    double zoom = 14;

    // إذا كان هناك موقع للسائق، نركز على منتصف المسافة
    if (_currentDriverPosition != null) {
      // إذا كان هناك موقع للسائق، نركز على منتصف المسافة
      centerPoint = LatLng(
        (customerLat + _currentDriverPosition!.latitude) / 2,
        (customerLng + _currentDriverPosition!.longitude) / 2,
      );
      zoom = 13;
    } else if (_order!.type == 'taxi' && 
        _order!.destinationLatitude != null && 
        _order!.destinationLongitude != null) {
      final destLat = _order!.destinationLatitude!;
      final destLng = _order!.destinationLongitude!;
      centerPoint = LatLng(
        (customerLat + destLat) / 2,
        (customerLng + destLng) / 2,
      );
      zoom = 12;
    } else {
      centerPoint = LatLng(customerLat, customerLng);
      zoom = 14;
    }

    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(centerPoint, zoom),
      );
    } catch (e) {
      // Error updating camera
    }
  }

  Widget _buildTaxiStatusButtons(Color primaryColor) {
    if (_order!.status == OrderStatus.completed ||
        _order!.status == OrderStatus.cancelled ||
        _order!.status == OrderStatus.delivered) {
      return const SizedBox.shrink();
    }

    // Check if driver has accepted this order
    final isDriverOrder = _driver != null && _order!.driverId == _driver!.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // إذا لم يكن مقبول بعد، عرض زر الموافقة
        if (_order!.status == OrderStatus.pending || 
            _order!.status == OrderStatus.ready ||
            !isDriverOrder) ...[
          ElevatedButton.icon(
            onPressed: _acceptOrder,
            icon: const Icon(Icons.check_circle),
            label: const Text('موافقة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // إذا كان مقبول، عرض زر انطلق نحو الزبون و زر وصلت
        if (isDriverOrder && _order!.status == OrderStatus.accepted) ...[
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('اختر الخريطة للوصول للعميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(OrderStatus.arrived),
            icon: const Icon(Icons.location_on),
            label: const Text('وصلت لموقع العميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        // إذا وصل للموقع، عرض زر انطلق نحو الوجهة
        if (isDriverOrder && _order!.status == OrderStatus.arrived) ...[
          ElevatedButton.icon(
            onPressed: _navigateToDestination,
            icon: const Icon(Icons.map_rounded),
            label: const Text('اختر الخريطة للوصول للوجهة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(OrderStatus.inProgress),
            icon: const Icon(Icons.directions_car),
            label: const Text('وصلت للوجهة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (حتى بعد الوصول)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
        // إذا كان في الطريق، عرض زر اكتملت الرحلة
        if (isDriverOrder && _order!.status == OrderStatus.inProgress) ...[
          ElevatedButton.icon(
            onPressed: _navigateToDestination,
            icon: const Icon(Icons.map_rounded),
            label: const Text('فتح موقع الوجهة على الخريطة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              // تأكيد من السائق قبل تحديث الحالة
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تأكيد إكمال الرحلة'),
                  content: const Text('هل أنت متأكد من أنك أكملت الرحلة؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('نعم، اكتملت الرحلة'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await _updateStatus(OrderStatus.completed);
              }
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('اكتملت الرحلة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryActionButton(Color primaryColor) {
    if (_order!.status == OrderStatus.delivered ||
        _order!.status == OrderStatus.completed ||
        _order!.status == OrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    // Check if driver has accepted this order
    final isDriverOrder = _driver != null && _order!.driverId == _driver!.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // إذا لم يكن مقبول بعد، عرض زر الموافقة
        if (_order!.status == OrderStatus.pending || 
            _order!.status == OrderStatus.ready ||
            _order!.status == OrderStatus.preparing ||
            !isDriverOrder) ...[
          ElevatedButton.icon(
            onPressed: _acceptOrder,
            icon: const Icon(Icons.check_circle),
            label: const Text('موافقة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // إذا كان مقبول، عرض زر انطلق نحو الزبون و زر وصلت
        if (isDriverOrder && _order!.status == OrderStatus.accepted) ...[
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('اختر الخريطة للوصول للعميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(OrderStatus.arrived),
            icon: const Icon(Icons.location_on),
            label: const Text('وصلت لموقع العميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (قبل الوصول للموقع)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
        // إذا وصل، عرض زر تم التسليم
        if (isDriverOrder && 
            (_order!.status == OrderStatus.arrived || 
             _order!.status == OrderStatus.inProgress)) ...[
          // إضافة زر اختيار الخريطة أيضاً في حالة الوصول
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('فتح موقع العميل على الخريطة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              // تأكيد من الدلفري قبل تحديث الحالة
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تأكيد التسليم'),
                  content: const Text('هل أنت متأكد من أنك سلمت الطلب للعميل؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('نعم، تم التسليم'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await _updateStatus(OrderStatus.delivered);
              }
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('تم التسليم'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (حتى بعد الوصول)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
    );
  }

  Widget _buildServiceInvoice(Order order, Color primaryColor) {
    String getServiceTitle() {
      switch (order.type) {
        case 'car_emergency':
          return 'طلب طوارئ سيارات';
        case 'fuel':
          return 'طلب خدمة بنزين';
        case 'maid':
          return 'طلب تأجير عاملة';
        case 'car_wash':
          return 'طلب غسيل سيارات';
        default:
          return 'طلب تصليح السيارات';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  getServiceTitle(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'طلب #${order.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'التاريخ: ${_formatDate(order.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow('اسم العميل', order.customerName, Icons.person),
          const Divider(),
          _buildInfoRow('رقم الهاتف', order.customerPhone, Icons.phone),
          if (order.customerAddress != null) ...[
            const Divider(),
            _buildInfoRow('العنوان', order.customerAddress!, Icons.location_on),
          ],
          // Service-specific fields
          if (order.type == 'car_emergency' && order.emergencyReason != null) ...[
            const Divider(),
            _buildInfoRow('سبب الطوارئ', order.emergencyReason!, Icons.emergency_rounded),
          ],
          if (order.type == 'fuel' && order.fuelQuantity != null) ...[
            const Divider(),
            _buildInfoRow('كمية البنزين', '${order.fuelQuantity} لتر', Icons.local_gas_station_rounded),
            if (order.fare != null) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'المبلغ الإجمالي:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${order.fare!.toStringAsFixed(0)} دينار',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (order.type == 'maid') ...[
            if (order.maidServiceType != null) ...[
              const Divider(),
              _buildInfoRow('نوع الخدمة', order.maidServiceType!, Icons.cleaning_services_rounded),
            ],
            if (order.maidWorkHours != null) ...[
              const Divider(),
              _buildInfoRow('عدد الساعات', '${order.maidWorkHours} ساعة', Icons.access_time_rounded),
            ],
            if (order.maidWorkDate != null) ...[
              const Divider(),
              _buildInfoRow('تاريخ العمل', _formatDate(order.maidWorkDate!), Icons.calendar_today_rounded),
            ],
          ],
          if (order.type == 'car_wash') ...[
            if (order.carWashSize != null) ...[
              const Divider(),
              _buildInfoRow(
                'حجم السيارة',
                order.carWashSize == 'small' ? 'سيارة صغيرة' : 'سيارة كبيرة',
                Icons.directions_car_rounded,
              ),
            ],
            if (order.fare != null) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'المبلغ الإجمالي:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${order.fare!.toStringAsFixed(0)} دينار',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (order.notes != null && order.type != 'car_emergency' && order.type != 'car_wash') ...[
            const SizedBox(height: 20),
            _buildNotes(order.notes!, primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceStatusButtons(Color primaryColor) {
    if (_order!.status == OrderStatus.completed ||
        _order!.status == OrderStatus.cancelled ||
        _order!.status == OrderStatus.delivered) {
      return const SizedBox.shrink();
    }

    // Check if driver has accepted this order
    final isDriverOrder = _driver != null && _order!.driverId == _driver!.id;
    
    String getServiceActionText() {
      switch (_order!.type) {
        case 'maintenance':
          return 'اكتمل التصليح';
        case 'car_emergency':
          return 'اكتملت الخدمة';
        case 'fuel':
          return 'اكتملت الخدمة';
        case 'maid':
          return 'اكتملت الخدمة';
        case 'car_wash':
          return 'اكتملت الخدمة';
        default:
          return 'اكتملت الخدمة';
      }
    }

    String getServiceStartText() {
      switch (_order!.type) {
        case 'maintenance':
          return 'بدء التصليح';
        case 'car_emergency':
          return 'بدء الخدمة';
        case 'fuel':
          return 'بدء الخدمة';
        case 'maid':
          return 'بدء الخدمة';
        case 'car_wash':
          return 'بدء الخدمة';
        default:
          return 'بدء الخدمة';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // إذا لم يكن مقبول بعد، عرض زر الموافقة
        if (_order!.status == OrderStatus.pending || !isDriverOrder) ...[
          ElevatedButton.icon(
            onPressed: _acceptOrder,
            icon: const Icon(Icons.check_circle),
            label: const Text('موافقة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // إذا كان مقبول، عرض زر انطلق نحو الزبون و زر وصلت
        if (isDriverOrder && _order!.status == OrderStatus.accepted) ...[
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('اختر الخريطة للوصول للعميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(OrderStatus.arrived),
            icon: const Icon(Icons.location_on),
            label: const Text('وصلت لموقع العميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (قبل الوصول للموقع)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
        // إذا وصل للموقع، عرض زر بدء الخدمة
        if (isDriverOrder && _order!.status == OrderStatus.arrived) ...[
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('فتح موقع العميل على الخريطة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(OrderStatus.inProgress),
            icon: const Icon(Icons.build),
            label: Text(getServiceStartText()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (حتى بعد الوصول)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
        // إذا كان في التقدم، عرض زر اكتملت الخدمة
        if (isDriverOrder && _order!.status == OrderStatus.inProgress) ...[
          ElevatedButton.icon(
            onPressed: _navigateToCustomer,
            icon: const Icon(Icons.map_rounded),
            label: const Text('فتح موقع العميل على الخريطة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              // تأكيد من السائق قبل تحديث الحالة
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تأكيد إكمال الخدمة'),
                  content: Text('هل أنت متأكد من أنك أكملت ${getServiceActionText()}؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('نعم، اكتملت'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await _updateStatus(OrderStatus.completed);
              }
            },
            icon: const Icon(Icons.check_circle),
            label: Text(getServiceActionText()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // زر إلغاء الطلب (حتى بعد بدء الخدمة)
          OutlinedButton.icon(
            onPressed: _cancelOrder,
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
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.preparing:
        return AppTheme.secondaryColor;
      case OrderStatus.ready:
        return AppTheme.successColor;
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.arrived:
        return Colors.purple;
      case OrderStatus.inProgress:
        return Colors.indigo;
      case OrderStatus.delivered:
        return AppTheme.primaryColor;
      case OrderStatus.completed:
        return AppTheme.successColor;
      case OrderStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.check_circle;
      case OrderStatus.accepted:
        return Icons.check_circle;
      case OrderStatus.arrived:
        return Icons.location_on;
      case OrderStatus.inProgress:
        return Icons.directions_car;
      case OrderStatus.delivered:
        return Icons.local_shipping;
      case OrderStatus.completed:
        return Icons.check_circle_outline;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

