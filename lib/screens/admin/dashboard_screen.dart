import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/supermarket_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _supermarketService = SupermarketService();
  Map<String, int> _statistics = {};
  Map<String, double> _commissionStatistics = {};
  bool _isLoading = true;
  dynamic _currentAdmin;

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
      _currentAdmin = await _adminService.getCurrentAdmin();
      final stats = await _adminService.getStatistics();
      final commissionStats = await _adminService.getCommissionStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _commissionStatistics = commissionStats;
          _isLoading = false;
        });
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
      await _adminService.logout();
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لوحة تحكم الإدارة'),
              Text(
                'مدير النظام',
                style: TextStyle(
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
                _buildAdminInfoCard()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                Text(
                  'إحصائيات العمولات (${(_commissionStatistics['percentage'] ?? 10.0).toStringAsFixed(0)}%)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 400.ms),
                const SizedBox(height: 16),
                _buildCommissionStatisticsGrid()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 24),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInfoCard() {
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
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 35,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مدير النظام',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'لوحة التحكم الرئيسية',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
      childAspectRatio: 2.5,
      children: [
        _buildStatCard(
          'الكل',
          _statistics['drivers']?.toString() ?? '0',
          Icons.people_rounded,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'ديلفري',
          _statistics['deliveryDrivers']?.toString() ?? '0',
          Icons.delivery_dining_rounded,
          AppTheme.accentColor,
        ),
        _buildStatCard(
          'تكسي',
          _statistics['taxiDrivers']?.toString() ?? '0',
          Icons.local_taxi_rounded,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'طوارئ سيارات',
          _statistics['carEmergencyDrivers']?.toString() ?? '0',
          Icons.emergency_rounded,
          Colors.red.shade600,
        ),
        _buildStatCard(
          'كرين',
          _statistics['craneDrivers']?.toString() ?? '0',
          Icons.local_shipping_rounded,
          Colors.orange.shade700,
        ),
        _buildStatCard(
          'بنزين',
          _statistics['fuelDrivers']?.toString() ?? '0',
          Icons.local_gas_station_rounded,
          Colors.amber.shade700,
        ),
        _buildStatCard(
          'عاملة',
          _statistics['maidDrivers']?.toString() ?? '0',
          Icons.cleaning_services_rounded,
          Colors.purple.shade600,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
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
                          color: Colors.grey[600],
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
    );
  }

  Widget _buildCommissionStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildCommissionStatCard(
          'اليومي',
          '${(_commissionStatistics['daily'] ?? 0.0).toString()} د.ع',
          Colors.green.shade600,
        ),
        _buildCommissionStatCard(
          'الأسبوعي',
          '${(_commissionStatistics['weekly'] ?? 0.0).toString()} د.ع',
          Colors.blue.shade600,
        ),
        _buildCommissionStatCard(
          'الشهري',
          '${(_commissionStatistics['monthly'] ?? 0.0).toString()} د.ع',
          Colors.purple.shade600,
        ),
      ],
    );
  }

  Widget _buildCommissionStatCard(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.0,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _handleShopMunqeth() async {
    try {
      // إظهار مؤشر التحميل
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // الحصول على أو إنشاء سوبر ماركت المنقذ
      final supermarket = await _adminService.getOrCreateAdminSupermarket();

      if (mounted) {
        Navigator.pop(context); // إغلاق مؤشر التحميل
      }

      // تسجيل الدخول تلقائياً كسوبر ماركت
      final loggedInSupermarket = await _supermarketService.login(supermarket.id, supermarket.code);

      if (mounted) {
        if (loggedInSupermarket != null) {
          // الانتقال إلى dashboard السوبر ماركت
          context.go('/supermarket/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء سوبر ماركت المنقذ بنجاح. يمكنك الآن تسجيل الدخول من صفحة إدارة السوبر ماركتات'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildQuickActions() {
    final admin = _currentAdmin;
    final canDashboard = admin == null || admin.permissions.canAccessDashboard;
    final canCreateAccount = admin == null || admin.permissions.canCreateAccount;
    final canUsers = admin == null || admin.permissions.canManageUsers;
    final canAds = admin == null || admin.permissions.canManageAdvertisements;
    final canCards = admin == null || admin.permissions.canManageCards;
    final canSettings = admin == null || admin.permissions.canAccessSettings;
    final canChangePassword = admin == null || admin.permissions.canChangePassword;
    final canAddAdmins = admin != null && (admin.isSuperAdmin == true || admin.permissions.canAddAdmins);

    final actions = <Widget>[];
    if (canCreateAccount) {
      actions.addAll([
        _buildActionCard(
          'تسوق المنقذ',
          'إدارة المنتجات في سوبر ماركت المنقذ (سيتم إنشاؤه تلقائياً إذا لم يكن موجوداً)',
          Icons.shopping_cart_rounded,
          AppTheme.primaryColor,
          _handleShopMunqeth,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'إنشاء حساب جديد',
          'إضافة سوبر ماركت أو سائق جديد',
          Icons.add_circle_rounded,
          AppTheme.secondaryColor,
          () => context.push('/admin/create-account'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canUsers) {
      actions.addAll([
        _buildActionCard(
          'إدارة المستخدمين',
          'عرض وتعديل وحذف وتعليق جميع المستخدمين',
          Icons.people_rounded,
          AppTheme.primaryColor,
          () => context.push('/admin/users-management'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canAds) {
      actions.addAll([
        _buildActionCard(
          'إدارة الإعلانات والتنزيلات',
          'إضافة وتعديل وحذف الإعلانات والتنزيلات',
          Icons.campaign_rounded,
          AppTheme.secondaryColor,
          () => context.push('/admin/advertisements'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canCards) {
      actions.addAll([
        _buildActionCardWithExtraPadding(
          'البطاقات المالية',
          'إنشاء وإدارة البطاقات المالية (5000، 10000، 25000)',
          Icons.credit_card_rounded,
          Colors.green.shade600,
          () => context.push('/admin/cards'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canSettings) {
      actions.addAll([
        _buildActionCard(
          'الإعدادات',
          'تعديل نسبة الأرباح (العمولة) المعروضة في لوحة التحكم',
          Icons.settings_rounded,
          Colors.teal.shade600,
          () => context.push('/admin/settings'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canAddAdmins) {
      actions.addAll([
        _buildActionCard(
          'إضافة أدمن',
          'إضافة أدمن ثانوي وتحديد صلاحيات الدخول للصفحات',
          Icons.person_add_rounded,
          Colors.indigo.shade600,
          () => context.push('/admin/add-admin'),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (canChangePassword) {
      actions.addAll([
        _buildActionCard(
          'تغيير كلمة المرور',
          'تغيير كلمة المرور الخاصة بك',
          Icons.lock_rounded,
          Colors.orange.shade600,
          () => context.push('/admin/change-password'),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions,
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildActionCardWithExtraPadding(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0);
  }
}



