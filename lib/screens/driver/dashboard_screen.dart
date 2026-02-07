import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import '../../config/theme.dart';
import '../../models/driver.dart';
import '../../models/order.dart';
import '../../services/driver_service.dart';
import '../../services/order_service.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _driverService = DriverService();
  final _orderService = OrderService();

  Driver? _driver;
  int _availableOrdersCount = 0;
  int _myOrdersCount = 0;
  int _activeOrdersCount = 0;
  bool _isLoading = true;
  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadData();
    // طلب صلاحية Background Location عند الحاجة
    _requestBackgroundLocationPermissionIfNeeded();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  /// طلب صلاحية Background Location إذا كان السائق يحتاج تتبع مستمر
  Future<void> _requestBackgroundLocationPermissionIfNeeded() async {
    // التحقق من نوع الخدمة بعد تحميل البيانات
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_driver != null && _needsContinuousTracking(_driver!.serviceType)) {
      if (Platform.isAndroid) {
        var permission = await Geolocator.checkPermission();
        
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse) {
          // طلب صلاحية الخلفية (Always)
          // ملاحظة: في Android 10+ قد يحتاج المستخدم للذهاب للإعدادات يدوياً
          final backgroundPermission = await Geolocator.requestPermission();
          // Background permission requested
        } else if (permission == LocationPermission.always) {
          // Background permission already granted
        }
      }
    }
  }

  /// تحديد إذا كان نوع الخدمة يحتاج تتبع مستمر
  bool _needsContinuousTracking(String? serviceType) {
    return serviceType == 'taxi' || serviceType == 'delivery';
  }

  void _startLocationUpdates() {
    if (_driver == null) return;

    // إلغاء أي تحديثات سابقة
    _locationUpdateTimer?.cancel();
    _positionStream?.cancel();

    final needsContinuousTracking = _needsContinuousTracking(_driver!.serviceType);

    if (needsContinuousTracking) {
      // للتكسي والدلفري: استخدام PositionStream للتتبع المستمر
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // تحديث كل 10 متر
        ),
      ).listen(
        (Position position) {
          if (_driver != null && mounted && _driver!.isAvailable) {
            _updateDriverLocationWithPosition(position);
          }
        },
        onError: (error) {
          // Error in position stream
        },
      );
    } else {
      // للخدمات الأخرى: تحديث دوري فقط عندما يكون التطبيق نشط
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && _driver != null && _driver!.isAvailable) {
          _updateDriverLocation();
        }
      });
    }
  }

  /// تحديث الموقع باستخدام Position محدد (للتتبع المستمر)
  Future<void> _updateDriverLocationWithPosition(Position position) async {
    try {
      if (_driver != null && mounted) {
        await _driverService.updateDriverLocation(
          _driver!.id,
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      // Error updating driver location
    }
  }

  Future<void> _updateDriverLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (_driver != null && mounted) {
        await _driverService.updateDriverLocation(
          _driver!.id,
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      // تجاهل الأخطاء في تحديث الموقع لتجنب إزعاج السائق
    }
  }

  /// تبديل حالة النشاط (متاح / متوقف عن استلام الطلبات)
  Future<void> _toggleAvailability() async {
    if (_driver == null) return;
    final newValue = !_driver!.isAvailable;
    setState(() => _driver = _driver!.copyWith(isAvailable: newValue));
    final ok = await _driverService.updateDriver(_driver!);
    if (mounted) {
      if (!ok) {
        setState(() => _driver = _driver!.copyWith(isAvailable: !newValue));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحديث الحالة، حاول مرة أخرى'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'أنت الآن نشط وتستلم الطلبات' : 'توقفت عن استلام الطلبات'),
            backgroundColor: newValue ? AppTheme.successColor : Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final driver = await _driverService.getCurrentDriver();
      if (driver != null) {
        final availableOrders =
            await _orderService.getAvailableOrdersForDriver(driver.serviceType);
        final myOrders = await _orderService.getOrdersByDriver(driver.id);
        
        // Calculate active orders based on service type
        List<Order> activeOrders;
        if (driver.serviceType == 'delivery') {
          // للدلفري: الطلبات النشطة هي التي لم يتم تسليمها بعد
          activeOrders = myOrders
              .where((o) =>
                  o.status == OrderStatus.accepted ||
                  o.status == OrderStatus.arrived ||
                  o.status == OrderStatus.inProgress)
              .toList();
        } else {
          activeOrders = myOrders
              .where((o) =>
                  o.status == OrderStatus.accepted ||
                  o.status == OrderStatus.inProgress ||
                  o.status == OrderStatus.arrived)
              .toList();
        }

        if (mounted) {
          setState(() {
            _driver = driver;
            _availableOrdersCount = availableOrders.length;
            _myOrdersCount = myOrders.length;
            _activeOrdersCount = activeOrders.length;
            _isLoading = false;
          });
          // بدء تحديثات الموقع بعد تحميل بيانات السائق
          _startLocationUpdates();
        }
      } else {
        if (mounted) {
          context.go('/login');
        }
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _driverService.logout();
      if (mounted) {
        context.go('/phone-check');
      }
    }
  }

  Color _getPrimaryColor() {
    // توحيد الألوان - فيروزي وأبيض لجميع الأنواع
    return AppTheme.primaryColor;
  }
  
  String _getServiceTypeName() {
    if (_driver?.serviceType == 'delivery') {
      return 'ديلفري';
    } else if (_driver?.serviceType == 'taxi') {
      return 'تكسي';
    } else if (_driver?.serviceType == 'maintenance') {
      return 'صيانة';
    } else if (_driver?.serviceType == 'car_emergency') {
      return 'طوارئ سيارات';
    } else if (_driver?.serviceType == 'crane') {
      return 'كرين';
    } else if (_driver?.serviceType == 'fuel') {
      return 'خدمة بنزين';
    } else if (_driver?.serviceType == 'maid') {
      return 'تأجير عاملة';
    }
    return 'سائق';
  }

  IconData _getIcon() {
    if (_driver?.serviceType == 'delivery') {
      return Icons.delivery_dining_rounded;
    } else if (_driver?.serviceType == 'taxi') {
      return Icons.local_taxi_rounded;
    } else if (_driver?.serviceType == 'maintenance') {
      return Icons.build_rounded;
    }
    return Icons.person_rounded;
  }

  String _getTitle() {
    if (_driver?.serviceType == 'delivery') {
      return 'لوحة تحكم الديلفري';
    } else if (_driver?.serviceType == 'taxi') {
      return 'لوحة تحكم التكسي';
    } else if (_driver?.serviceType == 'maintenance') {
      return 'لوحة تحكم المصلح';
    }
    return 'لوحة تحكم السائق';
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

    if (_driver == null) {
      return const SizedBox.shrink();
    }

    final primaryColor = _getPrimaryColor();
    final icon = _getIcon();
    final title = _getTitle();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_driver!.name),
              Text(
                _getServiceTypeName(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _handleLogout,
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Driver Info Card
                _buildDriverInfoCard(primaryColor, icon)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0),
                const SizedBox(height: 24),
                // Statistics
                Text(
                  'الإحصائيات',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 16),
                _buildStatisticsGrid(primaryColor)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
                // Quick Actions
                Text(
                  'إجراءات سريعة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 16),
                _buildQuickActions(primaryColor)
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(Color primaryColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 35,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driver!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getServiceTypeName(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    if (_driver!.vehicleNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _driver!.vehicleNumber!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // زر التحكم بالنشاط: نشط = أستلم طلبات، غير نشط = متوقف
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _toggleAvailability,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _driver!.isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _driver!.isAvailable ? 'نشط - أستلم الطلبات' : 'متوقف - لا أستلم طلبات',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _driver!.isAvailable ? 'اضغط لإيقاف استلام الطلبات' : 'اضغط لتفعيل استلام الطلبات',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _driver!.isAvailable
                            ? AppTheme.successColor
                            : Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _driver!.isAvailable ? 'متاح' : 'غير متاح',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(Color primaryColor) {
    final isDelivery = _driver!.serviceType == 'delivery';
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: [
        _buildStatCard(
          'طلبات متاحة',
          _availableOrdersCount.toString(),
          Icons.shopping_cart_outlined,
          primaryColor,
        ),
        _buildStatCard(
          'طلباتي',
          _myOrdersCount.toString(),
          Icons.list_alt_rounded,
          AppTheme.secondaryColor,
        ),
        _buildStatCard(
          isDelivery ? 'قيد التوصيل' : 'قيد التنفيذ',
          _activeOrdersCount.toString(),
          isDelivery ? Icons.local_shipping_rounded : Icons.directions_car_rounded,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'مكتملة',
          (_myOrdersCount - _activeOrdersCount).toString(),
          Icons.check_circle_outline_rounded,
          AppTheme.secondaryColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 15,
                            height: 1.1,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            height: 1.1,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return Column(
      children: [
        _buildActionCard(
          'الطلبات المتاحة',
          'عرض الطلبات الجاهزة',
          Icons.shopping_cart_rounded,
          primaryColor,
          () => context.push('/driver/orders'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'طلباتي',
          'عرض الطلبات المقبولة',
          Icons.list_alt_rounded,
          AppTheme.secondaryColor,
          () => context.push('/driver/my-orders'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'تغيير كلمة المرور',
          'تغيير كلمة المرور الخاصة بك',
          Icons.lock_rounded,
          Colors.orange.shade600,
          () => context.push('/driver/change-password'),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

}



