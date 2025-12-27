import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';
import '../../services/order_service.dart';
import '../../services/notification_service.dart';
import '../../core/utils/app_logger.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  final _driverService = DriverService();
  final _orderService = OrderService();
  final _notificationService = NotificationService();

  Driver? _driver;
  List<Order> _availableOrders = [];
  bool _isLoading = true;
  Map<String, DateTime> _orderTimers = {}; // لتتبع وقت ظهور الطلب
  StreamSubscription<RemoteMessage>? _notificationSubscription;
  Timer? _timer; // Timer لتحديث الوقت المتبقي كل ثانية
  ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0); // لتحديث الـ UI كل ثانية

  @override
  void initState() {
    super.initState();
    _loadData();
    // تحديث الطلبات كل 5 ثواني
    _startPeriodicUpdate();
    // الاستماع للإشعارات
    _setupNotificationListener();
    // بدء Timer لتحديث الوقت المتبقي كل ثانية
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // لا نقوم بإعادة التحميل عند العودة للصفحة
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _timer?.cancel();
    _timerNotifier.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }

  void _startTimer() {
    // إلغاء timer سابق إن وجد
    _timer?.cancel();
    
    // تحديث الـ UI كل ثانية لعرض الوقت المتبقي
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _availableOrders.isNotEmpty) {
        // تحديث ValueNotifier لإعادة بناء الـ widgets التي تستمع إليه
        _timerNotifier.value = DateTime.now().millisecondsSinceEpoch;
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  void _setupNotificationListener() {
    // الاستماع للإشعارات عند وصولها (التطبيق مفتوح)
    _notificationSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.i('Notification received in orders screen: ${message.messageId}');
      AppLogger.d('Notification data: ${message.data}');
      
      final data = message.data;
      if (data['type'] == 'new_order') {
        AppLogger.i('New order notification received, refreshing orders list');
        // تحديث الطلبات عند وصول إشعار طلب جديد
        _loadData();
        
        // عرض إشعار محلي
        _notificationService.showLocalNotification(
          title: message.notification?.title ?? 'طلب جديد',
          body: message.notification?.body ?? 'يوجد طلب جديد متاح',
          data: data,
        );
      }
    });

    // الاستماع عند فتح الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'new_order' && data['orderId'] != null) {
      // الانتقال لصفحة تفاصيل الطلب
      context.push('/driver/order-details', extra: data['orderId']);
      // تحديث الطلبات
      _loadData();
    }
  }

  void _startPeriodicUpdate() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _loadData();
        _startPeriodicUpdate();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.d('Loading driver orders data...');
      final driver = await _driverService.getCurrentDriver();
      if (driver != null) {
        AppLogger.d('Driver found: ${driver.driverId}, serviceType: ${driver.serviceType}');
        final orders = await _orderService.getAvailableOrdersForDriver(driver.serviceType);
        AppLogger.d('Retrieved ${orders.length} orders from server');

        // order_service.dart يفلتر الطلبات بالفعل، لا حاجة للفلترة مرة أخرى
        // فقط تحديث timers للطلبات الجديدة (لا نستبدل timers الموجودة لتجنب إعادة تعيين الوقت)
        for (var order in orders) {
          // فقط إضافة timer جديد إذا لم يكن موجوداً (للطلبات الجديدة)
          if (!_orderTimers.containsKey(order.id)) {
            _orderTimers[order.id] = order.createdAt;
          }
        }
        
        // إزالة timers للطلبات التي لم تعد متاحة
        _orderTimers.removeWhere((id, _) =>
            !orders.any((order) => order.id == id));

        AppLogger.d('Displaying ${orders.length} orders to driver');
        if (mounted) {
          setState(() {
            _driver = driver;
            _availableOrders = orders;
            _isLoading = false;
          });
        }
      } else {
        AppLogger.w('No driver found, redirecting to login');
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error loading driver orders data', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل الطلبات: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _acceptOrder(Order order) async {
    if (_driver == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبول الطلب'),
        content: Text('هل تريد قبول طلب #${order.id}؟'),
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

    if (confirm == true) {
      final success = await _orderService.acceptOrderByDriver(
        order.id,
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
          _loadData();
          // الانتقال لصفحة تفاصيل الطلب
          context.push('/driver/order-details', extra: order.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الطلب مقبول بالفعل من سائق آخر'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          _loadData();
        }
      }
    }
  }

  String _getTimeRemaining(String orderId) {
    // البحث عن الطلب في القائمة مباشرة (أكثر دقة)
    final order = _availableOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _availableOrders.isNotEmpty ? _availableOrders.first : Order(
        id: '',
        type: 'delivery',
        customerName: '',
        customerPhone: '',
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    
    // إذا لم يكن الطلب موجوداً، إرجاع سلسلة فارغة
    if (order.id != orderId || order.id.isEmpty) {
      return '';
    }
    
    // استخدام وقت الإنشاء من الطلب مباشرة (أكثر دقة)
    // تحديث _orderTimers للاحتفاظ بالوقت الأصلي عند أول ظهور للطلب
    if (!_orderTimers.containsKey(orderId)) {
      _orderTimers[orderId] = order.createdAt;
      AppLogger.d('Timer: Setting initial time for order ${orderId}: ${order.createdAt}');
    }
    
    // استخدام الوقت من _orderTimers إذا كان موجوداً، وإلا استخدام order.createdAt
    final startTime = _orderTimers[orderId] ?? order.createdAt;
    
    return _calculateTimeRemaining(startTime);
  }

  String _calculateTimeRemaining(DateTime createdAt) {
    // حساب الوقت المتبقي بناءً على وقت الإنشاء الفعلي
    final now = DateTime.now();
    // تحويل createdAt إلى UTC ثم مقارنته مع UTC الآن لتجنب مشاكل فارق التوقيت
    final createdAtUtc = createdAt.toUtc();
    final nowUtc = now.toUtc();
    final elapsed = nowUtc.difference(createdAtUtc);
    
    // 6 دقائق = 360 ثانية (buffer time)
    const totalTimeSeconds = 360;
    
    // إذا كان elapsed سالباً (الطلب في المستقبل بسبب timezone)، نستخدم 0
    // لكن يجب أن نحسب الوقت المتبقي بشكل صحيح
    int elapsedSeconds;
    if (elapsed.isNegative) {
      // إذا كان الطلب في المستقبل، نعتبر أنه بدأ للتو (0 ثانية)
      elapsedSeconds = 0;
      AppLogger.d('Timer: negative elapsed (timezone issue), using 0');
    } else {
      elapsedSeconds = elapsed.inSeconds;
    }
    
    final remaining = totalTimeSeconds - elapsedSeconds;
    
    // التأكد من أن remaining ليس سالباً
    final finalRemaining = remaining < 0 ? 0 : remaining;
    
    if (finalRemaining <= 0) return 'انتهى الوقت';
    
    final minutes = finalRemaining ~/ 60;
    final seconds = finalRemaining % 60;
    
    // تنسيق الوقت المتبقي
    final result = minutes > 0 
        ? '${minutes}:${seconds.toString().padLeft(2, '0')}'
        : '${seconds}ث';
    
    // Log للتحقق من الحساب (فقط في debug mode، كل 10 ثواني لتجنب spam)
    if (elapsedSeconds % 10 == 0) {
      AppLogger.d('Timer: elapsed=${elapsedSeconds}s, remaining=${finalRemaining}s, result=$result');
    }
    
    return result;
  }

  Color _getPrimaryColor() {
    if (_driver?.serviceType == 'delivery') {
      return Colors.orange;
    } else if (_driver?.serviceType == 'taxi') {
      return AppTheme.primaryColor;
    } else if (_driver?.serviceType == 'maintenance') {
      return Colors.green.shade600;
    }
    return AppTheme.primaryColor;
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

    final primaryColor = _getPrimaryColor();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('الطلبات المتاحة'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _availableOrders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _driver?.serviceType == 'taxi' 
                          ? Icons.assignment_outlined 
                          : _driver?.serviceType == 'maintenance'
                              ? Icons.build_outlined
                              : Icons.shopping_cart_outlined,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات متاحة',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الطلبات الجاهزة ستظهر هنا',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _availableOrders.length,
                  itemBuilder: (context, index) {
                    final order = _availableOrders[index];
                    return _buildOrderCard(order, primaryColor);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, Color primaryColor) {
    // استخدام ValueListenableBuilder مع ValueNotifier لتحديث الوقت المتبقي تلقائياً كل ثانية
    // هذه الطريقة أكثر موثوقية من StreamBuilder
    return ValueListenableBuilder<int>(
      valueListenable: _timerNotifier,
      builder: (context, timerValue, child) {
        // timerValue يتغير كل ثانية، مما يجبر الـ widget على إعادة البناء
        final timeRemaining = _getTimeRemaining(order.id);
        final isExpired = timeRemaining == 'انتهى الوقت';
        final isTaxi = order.type == 'taxi';
        
        return _buildOrderCardContent(order, primaryColor, timeRemaining, isExpired, isTaxi);
      },
    );
  }

  Widget _buildOrderCardContent(Order order, Color primaryColor, String timeRemaining, bool isExpired, bool isTaxi) {

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/driver/order-details', extra: order.id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'طلب #${order.id}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            order.customerName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (timeRemaining.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? AppTheme.errorColor.withOpacity(0.1)
                            : primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isExpired
                              ? AppTheme.errorColor
                              : primaryColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        timeRemaining,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isExpired
                                  ? AppTheme.errorColor
                                  : primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Order Details
              if (!isTaxi && order.items != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${order.items!.length} منتج',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      '${order.displayTotal.toStringAsFixed(0)} د.ع',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else if (isTaxi && order.fare != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'السعر: ${order.fare!.toStringAsFixed(0)} دينار',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Address
              if (order.customerAddress != null)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerAddress!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Accept Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isExpired ? null : () => _acceptOrder(order),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('قبول الطلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



