import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/order_service.dart';
import '../../models/driver.dart';
import '../../models/order.dart';
import 'dart:math' as math;

class UserDetailsScreen extends StatefulWidget {
  final String userId;

  const UserDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _adminService = AdminService();
  final _orderService = OrderService();
  Driver? _driver;
  bool _isLoading = true;
  Map<String, dynamic> _allStatistics = {};
  Map<String, dynamic> _filteredStatistics = {};
  String _selectedPeriod = 'total'; // 'weekly', 'monthly', 'total'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final drivers = await _adminService.getAllDrivers();
      // البحث بالمعرف المخصص أولاً، ثم بـ _id من MongoDB
      final driver = drivers.firstWhere(
        (d) => d.driverId.toUpperCase() == widget.userId.toUpperCase() || d.id == widget.userId,
        orElse: () => drivers.first,
      );

      if (mounted) {
        // جلب الطلبات الحقيقية من السيرفر
        await _loadRealStatistics(driver);
        setState(() {
          _driver = driver;
          _isLoading = false;
        });
        // تطبيق الفلترة بعد تحميل البيانات
        _applyPeriodFilter();
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

  // تطبيق الفلترة الزمنية
  void _applyPeriodFilter() {
    final now = DateTime.now();
    final allOrders = _allStatistics['orders'] as List<Map<String, dynamic>>? ?? [];
    List<Map<String, dynamic>> filteredOrders = [];
    final isDelivery = _driver?.serviceType == 'delivery';

    if (_selectedPeriod == 'weekly') {
      // الأسبوعي: من الأحد إلى السبت
      // weekday: 1 = Monday, 7 = Sunday
      final today = now.weekday;
      // حساب عدد الأيام من الأحد (إذا كان اليوم = 7 (الأحد) فالأيام = 0)
      final daysFromSunday = today == 7 ? 0 : today;
      // بداية الأسبوع (الأحد)
      final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromSunday));
      // نهاية الأسبوع (السبت)
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      filteredOrders = allOrders.where((order) {
        final orderDate = order['date'] as DateTime;
        return orderDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
               orderDate.isBefore(weekEnd);
      }).toList();
    } else if (_selectedPeriod == 'monthly') {
      // الشهري: الشهر الحالي
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      filteredOrders = allOrders.where((order) {
        final orderDate = order['date'] as DateTime;
        return orderDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
               orderDate.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();
    } else {
      // الإجمالي: كل الطلبات
      filteredOrders = allOrders;
    }

    // حساب الإحصائيات من الطلبات المفلترة
    // استثناء الطلبات الملغاة من المبالغ الرئيسية (فقط المكتملة)
    double totalAmount = 0; // فقط للمكتملة
    double totalDeliveryFee = 0; // فقط للديلفري المكتملة
    double totalOrderAmount = 0; // فقط مبلغ الطلبية للديلفري المكتملة
    double totalFullAmount = 0; // المبلغ الكامل (التوصيل + الطلبية للديلفري، أو إجمالي المبلغ للخدمات الأخرى)
    double commission10Percent = 0; // 10% من المبلغ الكامل
    int completedOrders = 0;
    int pendingOrders = 0;
    int cancelledOrders = 0;
    
    // إحصائيات الطلبات الملغاة (منفصلة)
    double cancelledTotalAmount = 0;
    double cancelledDeliveryFee = 0;
    double cancelledOrderAmount = 0;

    for (var order in filteredOrders) {
      final status = order['status'] as String?;
      final orderTotal = order['total'] as double? ?? 0.0;
      final deliveryFee = order['deliveryFee'] as double? ?? 0.0;
      final orderAmount = order['orderAmount'] as double? ?? (orderTotal - deliveryFee);
      
      if (status == 'completed' || status == 'delivered') {
        // فقط المكتملة (completed أو delivered) تُحسب في المبالغ الرئيسية
        completedOrders++;
        totalAmount += orderTotal;
        // للديلفري فقط: حساب مبلغ التوصيل ومبلغ الطلبية منفصلين
        if (isDelivery) {
          totalDeliveryFee += deliveryFee;
          totalOrderAmount += orderAmount;
        }
      } else if (status == 'cancelled') {
        // حساب إحصائيات الطلبات الملغاة بشكل منفصل
        cancelledOrders++;
        cancelledTotalAmount += orderTotal;
        if (isDelivery) {
          cancelledDeliveryFee += deliveryFee;
          cancelledOrderAmount += orderAmount;
        }
      } else if (status == 'pending' || status == 'accepted' || status == 'preparing' || 
                 status == 'ready' || status == 'in_progress' || status == 'arrived') {
        pendingOrders++;
        // الطلبات قيد الانتظار لا تُحسب في المبالغ (لأنها لم تكتمل بعد)
      }
    }
    
    // حساب المبلغ الكامل و 10% منه
    if (isDelivery) {
      // للديلفري: المبلغ الكامل = مبلغ التوصيل + مبلغ الطلبية
      totalFullAmount = totalDeliveryFee + totalOrderAmount;
    } else {
      // للخدمات الأخرى: المبلغ الكامل = إجمالي المبلغ
      totalFullAmount = totalAmount;
    }
    // حساب 10% من المبلغ الكامل
    commission10Percent = totalFullAmount * 0.10;

    setState(() {
      _filteredStatistics = {
        'totalOrders': filteredOrders.length,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'cancelledOrders': cancelledOrders,
        'totalAmount': totalAmount, // فقط المكتملة
        'totalDeliveryFee': totalDeliveryFee, // فقط للديلفري المكتملة
        'totalOrderAmount': totalOrderAmount, // فقط مبلغ الطلبية للديلفري المكتملة
        'totalFullAmount': totalFullAmount, // المبلغ الكامل
        'commission10Percent': commission10Percent, // 10% من المبلغ الكامل
        'orders': filteredOrders,
        // إحصائيات الطلبات الملغاة (منفصلة)
        'cancelledTotalAmount': cancelledTotalAmount,
        'cancelledDeliveryFee': cancelledDeliveryFee,
        'cancelledOrderAmount': cancelledOrderAmount,
      };
    });
  }

  // جلب الإحصائيات الحقيقية من السيرفر
  Future<void> _loadRealStatistics(Driver driver) async {
    try {
      // جلب جميع طلبات السائق من السيرفر
      final orders = await _orderService.getOrdersByDriver(driver.id);
      
      // تحويل الطلبات إلى تنسيق مناسب
      List<Map<String, dynamic>> ordersList = [];
      double totalAmount = 0; // فقط المكتملة
      double totalDeliveryFee = 0; // فقط للديلفري المكتملة
      double totalOrderAmount = 0; // فقط مبلغ الطلبية للديلفري المكتملة
      double totalFullAmount = 0; // المبلغ الكامل (التوصيل + الطلبية للديلفري، أو إجمالي المبلغ للخدمات الأخرى)
      double commission10Percent = 0; // 10% من المبلغ الكامل
      int completedOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      
      // إحصائيات الطلبات الملغاة
      double cancelledTotalAmount = 0;
      double cancelledDeliveryFee = 0;
      double cancelledOrderAmount = 0;
      
      final isDelivery = driver.serviceType == 'delivery';
      
      for (var order in orders) {
        final orderDate = order.createdAt;
        final orderTotal = order.total ?? order.fare ?? 0.0;
        final deliveryFee = (order.deliveryFee ?? 0).toDouble();
        final orderAmount = orderTotal - deliveryFee;
        
        // حساب الطلبات حسب الحالة
        if (order.status == OrderStatus.completed || order.status == OrderStatus.delivered) {
          completedOrders++;
          totalAmount += orderTotal;
          // للديلفري فقط: حساب مبلغ التوصيل ومبلغ الطلبية منفصلين
          if (isDelivery) {
            totalDeliveryFee += deliveryFee;
            totalOrderAmount += orderAmount;
          }
        } else if (order.status == OrderStatus.cancelled) {
          cancelledOrders++;
          cancelledTotalAmount += orderTotal;
          if (isDelivery) {
            cancelledDeliveryFee += deliveryFee;
            cancelledOrderAmount += orderAmount;
          }
        } else if (order.status == OrderStatus.pending || order.status == OrderStatus.accepted) {
          pendingOrders++;
        }
        
        ordersList.add({
          'id': order.id,
          'orderAmount': orderAmount,
          'deliveryFee': deliveryFee,
          'total': orderTotal,
          'date': orderDate,
          'status': order.status.value,
        });
      }
      
      final totalOrders = orders.length;
      
      // حساب المبلغ الكامل و 10% منه
      if (isDelivery) {
        // للديلفري: المبلغ الكامل = مبلغ التوصيل + مبلغ الطلبية
        totalFullAmount = totalDeliveryFee + totalOrderAmount;
      } else {
        // للخدمات الأخرى: المبلغ الكامل = إجمالي المبلغ
        totalFullAmount = totalAmount;
      }
      // حساب 10% من المبلغ الكامل
      commission10Percent = totalFullAmount * 0.10;

      if (mounted) {
        setState(() {
          _allStatistics = {
            'totalOrders': totalOrders,
            'completedOrders': completedOrders,
            'pendingOrders': pendingOrders,
            'cancelledOrders': cancelledOrders,
            'totalAmount': totalAmount,
            'totalDeliveryFee': totalDeliveryFee,
            'totalOrderAmount': totalOrderAmount,
            'totalFullAmount': totalFullAmount, // المبلغ الكامل
            'commission10Percent': commission10Percent, // 10% من المبلغ الكامل
            'orders': ordersList,
            // إحصائيات الطلبات الملغاة
            'cancelledTotalAmount': cancelledTotalAmount,
            'cancelledDeliveryFee': cancelledDeliveryFee,
            'cancelledOrderAmount': cancelledOrderAmount,
          };
        });
        // تطبيق الفلترة بعد حفظ البيانات
        if (_driver != null) {
          _applyPeriodFilter();
        }
      }
    } catch (e) {
      // في حالة الخطأ، نستخدم بيانات فارغة
      if (mounted) {
        setState(() {
          _allStatistics = {
            'totalOrders': 0,
            'completedOrders': 0,
            'pendingOrders': 0,
            'cancelledOrders': 0,
            'totalAmount': 0.0,
            'totalDeliveryFee': 0.0,
            'totalOrderAmount': 0.0,
            'totalFullAmount': 0.0,
            'commission10Percent': 0.0,
            'orders': <Map<String, dynamic>>[],
            'cancelledTotalAmount': 0.0,
            'cancelledDeliveryFee': 0.0,
            'cancelledOrderAmount': 0.0,
          };
        });
      }
    }
  }

  // بيانات تجريبية للإحصائيات (محفوظة للرجوع إليها إذا لزم الأمر)
  Map<String, dynamic> _generateMockStatistics(Driver driver) {
    final random = math.Random();
    final serviceType = driver.serviceType;

    // عدد الطلبات
    final totalOrders = random.nextInt(50) + 10;
    final completedOrders = (totalOrders * 0.8).round();
    final pendingOrders = totalOrders - completedOrders;

    // المبالغ حسب نوع الخدمة
    double totalAmount = 0;
    double totalDeliveryFee = 0;
    List<Map<String, dynamic>> orders = [];

    if (serviceType == 'delivery') {
      // ديلفري: تكلفة الطلب + رسوم التوصيل
      for (int i = 0; i < completedOrders; i++) {
        final orderAmount = (random.nextDouble() * 50000 + 10000).roundToDouble();
        final deliveryFee = (random.nextDouble() * 5000 + 2000).roundToDouble();
        totalAmount += orderAmount;
        totalDeliveryFee += deliveryFee;
        orders.add({
          'id': 'ORD${1000 + i}',
          'orderAmount': orderAmount,
          'deliveryFee': deliveryFee,
          'total': orderAmount + deliveryFee,
          'date': DateTime.now().subtract(Duration(days: random.nextInt(30))),
        });
      }
    } else if (serviceType == 'taxi') {
      // تكسي: فقط رسوم الرحلة
      for (int i = 0; i < completedOrders; i++) {
        final tripFee = (random.nextDouble() * 15000 + 5000).roundToDouble();
        totalAmount += tripFee;
        final daysAgo = random.nextInt(60);
        final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
        orders.add({
          'id': 'TAXI${1000 + i}',
          'tripFee': tripFee,
          'distance': (random.nextDouble() * 20 + 5).toStringAsFixed(1),
          'total': tripFee,
          'date': orderDate,
        });
      }
    } else if (serviceType == 'car_emergency') {
      // طوارئ سيارات: رسوم الخدمة
      for (int i = 0; i < completedOrders; i++) {
        final serviceFee = (random.nextDouble() * 100000 + 30000).roundToDouble();
        totalAmount += serviceFee;
        final daysAgo = random.nextInt(60);
        final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
        orders.add({
          'id': 'EMERG${1000 + i}',
          'serviceFee': serviceFee,
          'serviceType': ['بطارية', 'إطارات', 'وقود', 'ميكانيكي'][random.nextInt(4)],
          'total': serviceFee,
          'date': orderDate,
        });
      }
    } else if (serviceType == 'crane') {
      // كرين: رسوم السحب
      for (int i = 0; i < completedOrders; i++) {
        final craneFee = (random.nextDouble() * 80000 + 20000).roundToDouble();
        totalAmount += craneFee;
        final daysAgo = random.nextInt(60);
        final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
        orders.add({
          'id': 'CRANE${1000 + i}',
          'craneFee': craneFee,
          'distance': (random.nextDouble() * 30 + 5).toStringAsFixed(1),
          'total': craneFee,
          'date': orderDate,
        });
      }
    } else if (serviceType == 'fuel') {
      // بنزين: كمية البنزين + السعر
      for (int i = 0; i < completedOrders; i++) {
        final quantity = random.nextInt(5) + 1;
        final pricePerLiter = (random.nextDouble() * 500 + 1000).roundToDouble();
        final totalFuelPrice = quantity * pricePerLiter;
        totalAmount += totalFuelPrice;
        final daysAgo = random.nextInt(60);
        final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
        orders.add({
          'id': 'FUEL${1000 + i}',
          'quantity': quantity,
          'pricePerLiter': pricePerLiter,
          'total': totalFuelPrice,
          'date': orderDate,
        });
      }
    } else if (serviceType == 'maid') {
      // عاملة: رسوم الساعة
      for (int i = 0; i < completedOrders; i++) {
        final hours = random.nextInt(8) + 2;
        final hourlyRate = (random.nextDouble() * 5000 + 3000).roundToDouble();
        final totalMaidFee = hours * hourlyRate;
        totalAmount += totalMaidFee;
        final daysAgo = random.nextInt(60);
        final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
        orders.add({
          'id': 'MAID${1000 + i}',
          'hours': hours,
          'hourlyRate': hourlyRate,
          'total': totalMaidFee,
          'date': orderDate,
        });
      }
    }

    return {
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'pendingOrders': pendingOrders,
      'totalAmount': totalAmount,
      'totalDeliveryFee': totalDeliveryFee,
      'orders': orders,
    };
  }

  String _getServiceTypeName(String serviceType) {
    switch (serviceType) {
      case 'delivery':
        return 'ديلفري';
      case 'taxi':
        return 'تكسي';
      case 'car_emergency':
        return 'سيارات الطوارئ';
      case 'crane':
        return 'كرين طوارئ';
      case 'fuel':
        return 'خدمة بنزين';
      case 'maid':
        return 'تأجير عاملة';
      default:
        return serviceType;
    }
  }

  Color _getServiceTypeColor(String serviceType) {
    switch (serviceType) {
      case 'delivery':
        return Colors.orange;
      case 'taxi':
        return Colors.yellow.shade700;
      case 'car_emergency':
        return Colors.red.shade600;
      case 'crane':
        return Colors.orange.shade700;
      case 'fuel':
        return Colors.amber.shade700;
      case 'maid':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _driver == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final color = _getServiceTypeColor(_driver!.serviceType);
    final serviceName = _getServiceTypeName(_driver!.serviceType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('تفاصيل المستخدم'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // معلومات المستخدم
              _buildUserInfoCard(_driver!, color, serviceName),
              // فلترة زمنية
              _buildPeriodFilter(),
              // الإحصائيات
              _buildStatisticsSection(),
              // قائمة الطلبات
              _buildOrdersList(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildUserInfoCard(Driver driver, Color color, String serviceName) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.person_rounded, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow('المعرف', driver.driverId),
          _buildInfoRow('رقم الهاتف', driver.phone),
          if (driver.vehicleType != null)
            _buildInfoRow('نوع المركبة', driver.vehicleType!),
          if (driver.vehicleNumber != null)
            _buildInfoRow('رقم المركبة', driver.vehicleNumber!),
          _buildInfoRow('الحالة', driver.isAvailable ? 'متاح' : 'غير متاح'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('أسبوعي', 'weekly'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('شهري', 'monthly'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPeriodButton('إجمالي', 'total'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _applyPeriodFilter();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final serviceType = _driver?.serviceType ?? '';
    final isDelivery = serviceType == 'delivery';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الطلبات',
                  '${_filteredStatistics['totalOrders'] ?? 0}',
                  Icons.shopping_cart_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مكتملة',
                  '${_filteredStatistics['completedOrders'] ?? 0}',
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'قيد الانتظار',
                  '${_filteredStatistics['pendingOrders'] ?? 0}',
                  Icons.hourglass_empty_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _showCancelledOrdersDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStatCard(
                    'ملغاة',
                    '${_filteredStatistics['cancelledOrders'] ?? 0}',
                    Icons.cancel_rounded,
                    Colors.red,
                  ),
                ),
              ),
            ],
          ),
          // للديلفري: عرض مبلغ التوصيل ومبلغ الطلبية منفصلين (للمكتملة فقط)
          if (isDelivery) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'مبلغ التوصيل (مكتملة)',
                    '${(_filteredStatistics['totalDeliveryFee'] ?? 0.0).toStringAsFixed(0)} د.ع',
                    Icons.local_shipping_rounded,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'مبلغ الطلبية (مكتملة)',
                    '${(_filteredStatistics['totalOrderAmount'] ?? 0.0).toStringAsFixed(0)} د.ع',
                    Icons.shopping_bag_rounded,
                    Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ],
          // للخدمات الأخرى (غير الديلفري): عرض إجمالي المبلغ للمكتملة فقط
          if (!isDelivery) ...[
            const SizedBox(height: 12),
            _buildStatCard(
              'إجمالي المبلغ (مكتملة)',
              '${(_filteredStatistics['totalAmount'] ?? 0.0).toStringAsFixed(0)} د.ع',
              Icons.attach_money_rounded,
              AppTheme.primaryColor,
            ),
          ],
          // عرض المبلغ الكامل و 10% منه لجميع الخدمات
          const SizedBox(height: 12),
          _buildStatCard(
            'المبلغ الكامل',
            '${(_filteredStatistics['totalFullAmount'] ?? 0.0).toStringAsFixed(0)} د.ع',
            Icons.account_balance_wallet_rounded,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'العمولة (10%)',
            '${(_filteredStatistics['commission10Percent'] ?? 0.0).toStringAsFixed(0)} د.ع',
            Icons.percent_rounded,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  // إظهار dialog لإحصائيات الطلبات الملغاة
  void _showCancelledOrdersDialog() {
    final cancelledCount = _filteredStatistics['cancelledOrders'] ?? 0;
    final cancelledTotal = _filteredStatistics['cancelledTotalAmount'] ?? 0.0;
    final cancelledDeliveryFee = _filteredStatistics['cancelledDeliveryFee'] ?? 0.0;
    final cancelledOrderAmount = _filteredStatistics['cancelledOrderAmount'] ?? 0.0;
    final isDelivery = _driver?.serviceType == 'delivery';
    
    if (cancelledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد طلبات ملغاة'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إحصائيات الطلبات الملغاة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogStatRow('عدد الطلبات الملغاة', '$cancelledCount', isBold: true),
              const SizedBox(height: 16),
              if (isDelivery) ...[
                _buildDialogStatRow('مبلغ التوصيل', '${cancelledDeliveryFee.toStringAsFixed(0)} د.ع'),
                _buildDialogStatRow('مبلغ الطلبية', '${cancelledOrderAmount.toStringAsFixed(0)} د.ع'),
                const Divider(height: 24),
                _buildDialogStatRow('الإجمالي', '${cancelledTotal.toStringAsFixed(0)} د.ع', isBold: true),
              ] else ...[
                const Divider(height: 24),
                _buildDialogStatRow('إجمالي المبلغ', '${cancelledTotal.toStringAsFixed(0)} د.ع', isBold: true),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogStatRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final orders = _filteredStatistics['orders'] as List<Map<String, dynamic>>? ?? [];

    if (orders.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'لا توجد طلبات',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الطلبات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...orders.map((order) => _buildOrderCard(order, _driver!.serviceType)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String serviceType) {
    final date = order['date'] as DateTime;
    final total = order['total'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  order['id'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOrderDetails(order, serviceType),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Flexible(
                child: Text(
                  '${total.toStringAsFixed(0)} د.ع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order, String serviceType) {
    if (serviceType == 'delivery') {
      final orderAmount = (order['orderAmount'] as num?)?.toDouble() ?? 0.0;
      final deliveryFee = (order['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          _buildDetailRow('تكلفة الطلب', '${orderAmount.toStringAsFixed(0)} د.ع'),
          _buildDetailRow('رسوم التوصيل', '${deliveryFee.toStringAsFixed(0)} د.ع'),
        ],
      );
    } else if (serviceType == 'taxi') {
      final tripFee = (order['tripFee'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          _buildDetailRow('رسوم الرحلة', '${tripFee.toStringAsFixed(0)} د.ع'),
          if (order['distance'] != null)
            _buildDetailRow('المسافة', '${order['distance']} كم'),
        ],
      );
    } else if (serviceType == 'car_emergency') {
      final serviceFee = (order['serviceFee'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          if (order['serviceType'] != null)
            _buildDetailRow('نوع الخدمة', order['serviceType'].toString()),
          _buildDetailRow('رسوم الخدمة', '${serviceFee.toStringAsFixed(0)} د.ع'),
        ],
      );
    } else if (serviceType == 'crane') {
      final craneFee = (order['craneFee'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          _buildDetailRow('رسوم السحب', '${craneFee.toStringAsFixed(0)} د.ع'),
          if (order['distance'] != null)
            _buildDetailRow('المسافة', '${order['distance']} كم'),
        ],
      );
    } else if (serviceType == 'fuel') {
      final pricePerLiter = (order['pricePerLiter'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          if (order['quantity'] != null)
            _buildDetailRow('الكمية', '${order['quantity']} لتر'),
          _buildDetailRow('سعر اللتر', '${pricePerLiter.toStringAsFixed(0)} د.ع'),
        ],
      );
    } else if (serviceType == 'maid') {
      final hourlyRate = (order['hourlyRate'] as num?)?.toDouble() ?? 0.0;
      return Column(
        children: [
          if (order['hours'] != null)
            _buildDetailRow('عدد الساعات', '${order['hours']} ساعة'),
          _buildDetailRow('سعر الساعة', '${hourlyRate.toStringAsFixed(0)} د.ع'),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

