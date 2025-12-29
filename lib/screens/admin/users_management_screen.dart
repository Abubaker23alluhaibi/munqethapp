import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../models/driver.dart';
import '../../core/utils/app_logger.dart';
import 'edit_user_screen.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _adminService = AdminService();
  List<Driver> _allDrivers = [];
  List<Driver> _filteredDrivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedFilter; // null = الكل

  // إحصائيات
  Map<String, int> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statistics = {}; // إعادة تعيين الإحصائيات قبل التحميل
    });

    try {
      final drivers = await _adminService.getAllDrivers();
      
      if (mounted) {
        setState(() {
          _allDrivers = drivers;
          _calculateStatistics();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading drivers', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statistics = {}; // إعادة تعيين الإحصائيات في حالة الخطأ
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

  void _calculateStatistics() {
    // حساب الإحصائيات بشكل صريح
    final allCount = _allDrivers.length;
    final deliveryCount = _allDrivers.where((d) => d.serviceType == 'delivery').length;
    final taxiCount = _allDrivers.where((d) => d.serviceType == 'taxi').length;
    final carEmergencyCount = _allDrivers.where((d) => d.serviceType == 'car_emergency').length;
    final craneCount = _allDrivers.where((d) => d.serviceType == 'crane').length;
    final fuelCount = _allDrivers.where((d) => d.serviceType == 'fuel').length;
    final maidCount = _allDrivers.where((d) => d.serviceType == 'maid').length;
    
    _statistics = {
      'all': allCount,
      'delivery': deliveryCount,
      'taxi': taxiCount,
      'car_emergency': carEmergencyCount,
      'crane': craneCount,
      'fuel': fuelCount,
      'maid': maidCount,
    };
  }

  void _applyFilters() {
    List<Driver> filtered = List.from(_allDrivers);

    // فلترة حسب النوع
    if (_selectedFilter != null) {
      filtered = filtered.where((d) => d.serviceType == _selectedFilter).toList();
    }

    // البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((driver) {
        return driver.name.toLowerCase().contains(query) ||
            driver.driverId.toLowerCase().contains(query) ||
            driver.phone.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredDrivers = filtered;
    });
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
        return Colors.purple.shade600;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleDelete(Driver driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${driver.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // استخدام id (MongoDB _id) للحذف - السيرفر يتوقع _id
      final success = await _adminService.deleteDriver(driver.id);
      if (mounted) {
        if (success) {
          // إزالة السائق من القائمة المحلية فوراً
          setState(() {
            _allDrivers.removeWhere((d) => d.id == driver.id);
            _applyFilters();
            _calculateStatistics();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحذف بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // إعادة تحميل البيانات من السيرفر للتأكد
          await _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل الحذف'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSuspend(Driver driver) async {
    // TODO: إضافة وظيفة التعليق في AdminService
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة التعليق قريباً')),
    );
  }

  Future<void> _handleEdit(Driver driver) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserScreen(driver: driver),
      ),
    );
    if (result == true) {
      _loadData(); // إعادة تحميل البيانات بعد التعديل
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إدارة المستخدمين'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _allDrivers.isEmpty && _statistics.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // الإحصائيات
                      _buildStatisticsSection(),
                      // البحث والفلترة
                      _buildSearchAndFilterSection(),
                      // قائمة المستخدمين
                      Expanded(
                        child: _buildUsersList(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    // لا نعرض الإحصائيات إذا كانت فارغة أو أثناء التحميل
    if (_isLoading || _statistics.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatChip('الكل', _statistics['all'] ?? 0, null),
                const SizedBox(width: 8),
                _buildStatChip('ديلفري', _statistics['delivery'] ?? 0, 'delivery'),
                const SizedBox(width: 8),
                _buildStatChip('تكسي', _statistics['taxi'] ?? 0, 'taxi'),
                const SizedBox(width: 8),
                _buildStatChip('طوارئ سيارات', _statistics['car_emergency'] ?? 0, 'car_emergency'),
                const SizedBox(width: 8),
                _buildStatChip('كرين', _statistics['crane'] ?? 0, 'crane'),
                const SizedBox(width: 8),
                _buildStatChip('بنزين', _statistics['fuel'] ?? 0, 'fuel'),
                const SizedBox(width: 8),
                _buildStatChip('عاملة', _statistics['maid'] ?? 0, 'maid'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, String? filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = isSelected ? null : filterValue;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // البحث
          TextField(
            decoration: InputDecoration(
              hintText: 'بحث بالاسم، ID، أو رقم الهاتف',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          // فلتر النوع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String?>(
              value: _selectedFilter,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('الكل'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
                const DropdownMenuItem<String>(value: 'delivery', child: Text('ديلفري')),
                const DropdownMenuItem<String>(value: 'taxi', child: Text('تكسي')),
                const DropdownMenuItem<String>(value: 'car_emergency', child: Text('سيارات الطوارئ')),
                const DropdownMenuItem<String>(value: 'crane', child: Text('كرين طوارئ')),
                const DropdownMenuItem<String>(value: 'fuel', child: Text('خدمة بنزين')),
                const DropdownMenuItem<String>(value: 'maid', child: Text('تأجير عاملة')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value;
                });
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_filteredDrivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != null
                  ? 'لا توجد نتائج'
                  : 'لا يوجد مستخدمين',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDrivers.length,
        itemBuilder: (context, index) {
          return _buildUserCard(_filteredDrivers[index]);
        },
      ),
    );
  }

  Widget _buildUserCard(Driver driver) {
    final color = _getServiceTypeColor(driver.serviceType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(Icons.person_rounded, color: color),
            ),
            title: Text(
              driver.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  driver.phone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'المعرف: ${driver.driverId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            onTap: () {
              // استخدام driverId للانتقال (يمكن البحث به في صفحة التفاصيل)
              context.push('/admin/user-details/${driver.driverId}');
            },
          ),
          Positioned(
            top: 8,
            left: 8,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _handleEdit(driver);
                } else if (value == 'delete') {
                  _handleDelete(driver);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 20, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text('تعديل المعلومات'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, size: 20, color: AppTheme.errorColor),
                      SizedBox(width: 8),
                      Text('حذف المستخدم'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
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
}

