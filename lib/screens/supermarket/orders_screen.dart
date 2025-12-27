import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/supermarket.dart';
import '../../services/supermarket_service.dart';
import '../../services/order_service.dart';
import '../../services/admin_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _supermarketService = SupermarketService();
  final _orderService = OrderService();
  final _adminService = AdminService();

  Supermarket? _supermarket;
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  OrderStatus? _selectedStatus;
  bool _isLoading = true;
  bool _isAdminLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadData();
  }

  Future<void> _checkAdminStatus() async {
    final isAdminLoggedIn = await _adminService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isAdminLoggedIn = isAdminLoggedIn;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supermarket = await _supermarketService.getCurrentSupermarket();
      if (supermarket != null) {
        final orders = await _orderService.getAllOrdersSorted(supermarket.id);

        if (mounted) {
          setState(() {
            _supermarket = supermarket;
            _orders = orders;
            _filterOrders();
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

  void _filterOrders() {
    if (_selectedStatus == null) {
      _filteredOrders = _orders;
    } else {
      _filteredOrders = _orders.where((o) => o.status == _selectedStatus).toList();
    }
  }

  void _onStatusFilterChanged(OrderStatus? status) {
    setState(() {
      _selectedStatus = status;
    });
    _filterOrders();
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    if (_supermarket == null) return;

    final success = await _orderService.updateOrderStatus(
      order.id,
      newStatus,
      _supermarket!.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحديث حالة الطلب'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: _buildInvoice(order),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoice(Order order) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Invoice Header
          _buildInvoiceHeader(order),
          const SizedBox(height: 24),
          // Customer Info
          _buildCustomerInfo(order),
          const SizedBox(height: 24),
          Divider(color: AppTheme.borderColor, thickness: 1),
          const SizedBox(height: 16),
          // Products Table Header
          if (order.items != null && order.items!.isNotEmpty) ...[
            _buildTableHeader(),
            const SizedBox(height: 12),
            // Products List
            ...order.items!.map((item) => _buildInvoiceItem(item)),
          ],
          const SizedBox(height: 16),
          Divider(color: AppTheme.borderColor, thickness: 1),
          const SizedBox(height: 16),
          // Invoice Total
          _buildInvoiceTotal(order),
          if (order.notes != null) ...[
            const SizedBox(height: 24),
            _buildNotes(order.notes!),
          ],
          if (order.status == OrderStatus.cancelled && order.cancellationReason != null) ...[
            const SizedBox(height: 24),
            _buildCancellationReason(order.cancellationReason!),
          ],
          const SizedBox(height: 24),
          // Status Actions
          if (order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled)
            _buildStatusActions(order),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader(Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            _supermarket?.name ?? 'سوبر ماركت',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          if (_supermarket?.address != null) ...[
            const SizedBox(height: 4),
            Text(
              _supermarket!.address!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: AppTheme.primaryColor.withOpacity(0.3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'التاريخ والوقت',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Order order) {
    return Container(
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
          _buildInfoRow('الحالة', order.status.arabicName),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
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
                    color: AppTheme.primaryColor,
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
                    color: AppTheme.primaryColor,
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
                    color: AppTheme.primaryColor,
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
                    color: AppTheme.primaryColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(OrderItem item) {
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
                    color: AppTheme.primaryColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTotal(Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المجموع الفرعي',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${order.displayTotal.toStringAsFixed(0)} د.ع',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.primaryColor.withOpacity(0.3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المجموع الكلي',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
              Text(
                '${order.displayTotal.toStringAsFixed(0)} د.ع',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationReason(String reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cancel_outlined,
            color: AppTheme.errorColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سبب الإلغاء من السائق:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(String notes) {
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.productImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.productImage!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: AppTheme.lightPrimary,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: AppTheme.lightPrimary,
                    child: const Icon(Icons.image_not_supported_rounded),
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.lightPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_not_supported_rounded),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(0)} د.ع × ${item.quantity}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${item.total.toStringAsFixed(0)} د.ع',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActions(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.status == OrderStatus.pending)
          ElevatedButton.icon(
            onPressed: () {
              _updateOrderStatus(order, OrderStatus.preparing);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.restaurant_rounded),
            label: const Text('بدء التحضير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        if (order.status == OrderStatus.preparing) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              _updateOrderStatus(order, OrderStatus.ready);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('تم التحضير - جاهز'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
        if (order.status == OrderStatus.ready) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              _updateOrderStatus(order, OrderStatus.delivered);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('تم التسليم'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('الطلبات'),
          leading: _isAdminLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    context.go('/admin/dashboard');
                  },
                  tooltip: 'العودة إلى لوحة تحكم الأدمن',
                )
              : null,
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
              child: _filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
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
                                : 'لا توجد طلبات بعد',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(_filteredOrders[index]);
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

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
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
                      children: [
                        Text(
                          'طلب #${order.id}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.customerName,
                          style: Theme.of(context).textTheme.bodyMedium,
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
              // Items Count
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.items != null 
                        ? '${order.items!.length} منتج'
                        : 'طلب بدون منتجات',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${order.displayTotal.toStringAsFixed(0)} د.ع',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Time
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

