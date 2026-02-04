import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_widget.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/app_logger.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _selectedFilter = 'all'; // all, pending, completed, cancelled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // الحصول على رقم هاتف المستخدم الحالي
    final userPhone = await SecureStorageService.getString('user_phone');
    AppLogger.d('Loading orders for user phone: $userPhone');
    
    if (userPhone != null && userPhone.isNotEmpty) {
      await orderProvider.loadOrders(customerPhone: userPhone);
    } else {
      AppLogger.w('No user phone found, loading all orders');
      // إذا لم يكن هناك رقم هاتف، نحمل جميع الطلبات (للتطوير فقط)
      await orderProvider.loadOrders();
    }
  }

  Future<void> _refreshOrders() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final userPhone = await SecureStorageService.getString('user_phone');
    
    if (userPhone != null && userPhone.isNotEmpty) {
      await orderProvider.refreshOrders(customerPhone: userPhone);
    } else {
      await orderProvider.refreshOrders();
    }
  }

  List<Order> _getFilteredOrders(List<Order> orders) {
    switch (_selectedFilter) {
      case 'pending':
        return orders.where((o) => o.status == OrderStatus.pending).toList();
      case 'completed':
        return orders.where((o) => o.status == OrderStatus.completed).toList();
      case 'cancelled':
        return orders.where((o) => o.status == OrderStatus.cancelled).toList();
      default:
        return orders;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.accepted:
        return Colors.cyan;
      case OrderStatus.arrived:
        return Colors.teal;
      case OrderStatus.inProgress:
        return Colors.indigo;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return AppTheme.successColor;
      case OrderStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  String _getStatusText(OrderStatus status) {
    return status.arabicName;
  }

  String _getOrderTypeText(String type) {
    switch (type) {
      case 'delivery':
        return 'توصيل';
      case 'taxi':
        return 'تكسي';
      case 'maintenance':
        return 'صيانة';
      case 'car_emergency':
        return 'طوارئ سيارات';
      case 'crane':
        return 'كرين';
      case 'fuel':
        return 'بنزين';
      case 'maid':
        return 'عاملات';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('سجل الطلبات'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Filters
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'الكل'),
                    const SizedBox(width: 8),
                    _buildFilterChip('pending', 'قيد الانتظار'),
                    const SizedBox(width: 8),
                    _buildFilterChip('completed', 'مكتملة'),
                    const SizedBox(width: 8),
                    _buildFilterChip('cancelled', 'ملغاة'),
                  ],
                ),
              ),
            ),
            // Orders List
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
                    return const ShimmerList(itemCount: 5, itemHeight: 120);
                  }

                  final filteredOrders = _getFilteredOrders(orderProvider.orders);

                  if (filteredOrders.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refreshOrders,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'لا توجد طلبات',
                          message: _selectedFilter == 'all'
                              ? 'لم تقم بإجراء أي طلبات بعد'
                              : 'لا توجد طلبات في هذه الفئة',
                          buttonText: 'تحديث',
                          onButtonPressed: _refreshOrders,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _buildOrderCard(order);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);
    final orderType = _getOrderTypeText(order.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          context.push('/orders/tracking/${order.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Order ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${order.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          orderType,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Order Info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    order.customerPhone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if ((order.driverName != null && order.driverName!.isNotEmpty) || order.driverId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.local_taxi_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.driverName ?? 'سائق معين',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (order.items != null && order.items!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${order.items!.length} منتج',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Total
                  Text(
                    '${order.displayTotal.toStringAsFixed(0)} د.ع',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              // Cancel Button (only for cancellable orders)
              if (_canCancelOrder(order)) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(order),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('إلغاء الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'الآن';
        }
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _canCancelOrder(Order order) {
    // يمكن الإلغاء للطلبات التي لم يصل السائق بعد (قبل arrived)
    // أي يمكن الإلغاء في حالات: pending, preparing, ready, accepted
    return order.status == OrderStatus.pending ||
           order.status == OrderStatus.preparing ||
           order.status == OrderStatus.ready ||
           order.status == OrderStatus.accepted;
  }

  Future<void> _showCancelDialog(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
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
          // إعادة تحميل الطلبات
          await _loadOrders();
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
  }
}





