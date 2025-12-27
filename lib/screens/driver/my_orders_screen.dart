import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';
import '../../services/order_service.dart';

class DriverMyOrdersScreen extends StatefulWidget {
  const DriverMyOrdersScreen({super.key});

  @override
  State<DriverMyOrdersScreen> createState() => _DriverMyOrdersScreenState();
}

class _DriverMyOrdersScreenState extends State<DriverMyOrdersScreen> {
  final _driverService = DriverService();
  final _orderService = OrderService();

  Driver? _driver;
  List<Order> _myOrders = [];
  OrderStatus? _selectedStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // لا نقوم بإعادة التحميل عند العودة للصفحة
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final driver = await _driverService.getCurrentDriver();
      if (driver != null) {
        final orders = await _orderService.getOrdersByDriver(driver.id);
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _driver = driver;
            _myOrders = orders;
            _isLoading = false;
          });
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

  void _onStatusFilterChanged(OrderStatus? status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppTheme.warningColor;
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

  Color _getPrimaryColor() {
    if (_driver?.serviceType == 'delivery') {
      return Colors.orange;
    } else if (_driver?.serviceType == 'taxi') {
      return AppTheme.primaryColor;
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

    final filteredOrders = _selectedStatus == null
        ? _myOrders
        : _myOrders.where((o) => o.status == _selectedStatus).toList();
    final primaryColor = _getPrimaryColor();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('طلباتي'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Status Filter
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: OrderStatus.values.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildStatusChip(null, 'الكل');
                  }
                  final status = OrderStatus.values[index - 1];
                  return _buildStatusChip(status, status.arabicName);
                },
              ),
            ),
            // Orders List
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedStatus != null
                                ? 'لا توجد طلبات بهذه الحالة'
                                : 'لم تقبل أي طلبات بعد',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(filteredOrders[index], primaryColor);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onStatusFilterChanged(status),
        selectedColor: status != null
            ? _getStatusColor(status).withOpacity(0.2)
            : AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: status != null ? _getStatusColor(status) : AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? (status != null ? _getStatusColor(status) : AppTheme.primaryColor)
              : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, Color primaryColor) {
    final isTaxi = order.type == 'taxi';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(
          '/driver/order-details',
          extra: order.id,
        ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(order.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      order.status.arabicName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getStatusColor(order.status),
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
              if (order.driverAcceptedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'قُبل في: ${order.driverAcceptedAt!.hour}:${order.driverAcceptedAt!.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}






