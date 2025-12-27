import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/supermarket.dart';
import '../../models/order.dart';
import '../../services/supermarket_service.dart';
import '../../services/product_service.dart';
import '../../services/order_service.dart';
import '../../services/admin_service.dart';
import 'products_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

class SupermarketDashboardScreen extends StatefulWidget {
  const SupermarketDashboardScreen({super.key});

  @override
  State<SupermarketDashboardScreen> createState() =>
      _SupermarketDashboardScreenState();
}

class _SupermarketDashboardScreenState
    extends State<SupermarketDashboardScreen> {
  final _supermarketService = SupermarketService();
  final _productService = ProductService();
  final _orderService = OrderService();
  final _adminService = AdminService();

  Supermarket? _supermarket;
  int _productsCount = 0;
  Map<OrderStatus, int> _ordersCount = {};
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
      // إعطاء وقت إضافي للتأكد من حفظ البيانات
      await Future.delayed(const Duration(milliseconds: 200));
      
      // التحقق من السوبر ماركت مباشرة
      final supermarket = await _supermarketService.getCurrentSupermarket();
      
      if (supermarket != null) {
        final products = await _productService.getAllProducts(supermarket.id);
        final ordersCount =
            await _orderService.getOrdersCountByStatus(supermarket.id);

        if (mounted) {
          setState(() {
            _supermarket = supermarket;
            _productsCount = products.length;
            _ordersCount = ordersCount;
            _isLoading = false;
          });
        }
      } else {
        // إذا لم توجد بيانات، تحقق من حالة تسجيل الدخول
        final isLoggedIn = await _supermarketService.isLoggedIn();
        
        if (!isLoggedIn) {
          // إذا لم يكن مسجل دخول، انقله لصفحة تسجيل الدخول
          if (mounted) {
            context.go('/login');
          }
        } else {
          // إذا كان مسجل دخول لكن البيانات غير موجودة، إعادة المحاولة مرة واحدة
          await Future.delayed(const Duration(milliseconds: 300));
          final retrySupermarket = await _supermarketService.getCurrentSupermarket();
          if (retrySupermarket != null && mounted) {
            _loadData();
          } else if (mounted) {
            // إذا فشلت المحاولة، انقله لصفحة تسجيل الدخول
            context.go('/login');
          }
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
      await _supermarketService.logout();
      if (mounted) {
        context.go('/phone-check');
      }
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

    if (_supermarket == null) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(_supermarket!.name),
          leading: _isAdminLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    context.go('/admin/dashboard');
                  },
                  tooltip: 'العودة إلى لوحة تحكم الأدمن',
                )
              : null,
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
                // Supermarket Info Card
                _buildSupermarketInfoCard()
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
                _buildStatisticsGrid()
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
                _buildQuickActions()
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

  Widget _buildSupermarketInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_supermarket!.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _supermarket!.image!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: AppTheme.lightPrimary,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: AppTheme.lightPrimary,
                    child: const Icon(
                      Icons.store_rounded,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            if (_supermarket!.image == null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.lightPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _supermarket!.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_supermarket!.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _supermarket!.address!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.push('/supermarket/settings'),
              tooltip: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 3.0,
      children: [
        _buildStatCard(
          'المنتجات',
          _productsCount.toString(),
          Icons.inventory_2_rounded,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'طلبات جديدة',
          _ordersCount[OrderStatus.pending]?.toString() ?? '0',
          Icons.shopping_cart_rounded,
          AppTheme.warningColor,
        ),
        _buildStatCard(
          'قيد التحضير',
          _ordersCount[OrderStatus.preparing]?.toString() ?? '0',
          Icons.restaurant_rounded,
          AppTheme.secondaryColor,
        ),
        _buildStatCard(
          'جاهزة',
          _ordersCount[OrderStatus.ready]?.toString() ?? '0',
          Icons.check_circle_rounded,
          AppTheme.successColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionCard(
          'إدارة المنتجات',
          'عرض وإدارة جميع المنتجات',
          Icons.inventory_2_rounded,
          AppTheme.primaryColor,
          () => context.push('/supermarket/products'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'الطلبات',
          'عرض وإدارة الطلبات الواردة',
          Icons.shopping_cart_rounded,
          AppTheme.secondaryColor,
          () => context.push('/supermarket/orders'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'الإعدادات',
          'تغيير ID والرمز',
          Icons.settings_rounded,
          AppTheme.textSecondary,
          () => context.push('/supermarket/settings'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'إدارة المواقع',
          'إضافة وتعديل وحذف مواقع السوبر ماركت على الخريطة',
          Icons.location_on_rounded,
          Colors.blue.shade600,
          _handleManageLocations,
        ),
      ],
    );
  }

  Future<void> _handleManageLocations() async {
    if (_supermarket != null) {
      if (mounted) {
        context.push(
          '/admin/manage-supermarket-locations',
          extra: _supermarket!,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الوصول إلى بيانات السوبر ماركت'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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

