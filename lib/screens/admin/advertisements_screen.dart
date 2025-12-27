import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/advertisement.dart';
import '../../services/advertisement_service.dart';
import '../../services/supermarket_service.dart';
import '../../models/supermarket.dart';

class AdvertisementsScreen extends StatefulWidget {
  const AdvertisementsScreen({super.key});

  @override
  State<AdvertisementsScreen> createState() => _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends State<AdvertisementsScreen> {
  final _advertisementService = AdvertisementService();
  final _supermarketService = SupermarketService();

  List<Advertisement> _advertisements = [];
  List<Supermarket> _supermarkets = [];
  bool _isLoading = true;
  String? _selectedServiceFilter;
  String? _selectedSupermarketFilter;

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
      final advertisements = await _advertisementService.getAllAdvertisements();
      final supermarkets = await _supermarketService.getAllSupermarkets();

      if (mounted) {
        setState(() {
          _advertisements = advertisements;
          _supermarkets = supermarkets;
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

  Future<void> _handleDelete(Advertisement advertisement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل أنت متأكد من حذف الإعلان "${advertisement.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _advertisementService.deleteAdvertisement(advertisement.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الإعلان بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل حذف الإعلان'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _getServiceTypeName(String serviceType) {
    switch (serviceType) {
      case 'delivery':
        return 'توصيل';
      case 'taxi':
        return 'تكسي';
      case 'maintenance':
        return 'صيانة';
      case 'all':
        return 'جميع الخدمات';
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
      case 'maintenance':
        return Colors.green.shade600;
      case 'all':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  String? _getSupermarketName(String? supermarketId) {
    if (supermarketId == null) return 'عام';
    try {
      return _supermarkets.firstWhere((s) => s.id == supermarketId).name;
    } catch (e) {
      return supermarketId;
    }
  }

  List<Advertisement> get _filteredAdvertisements {
    var filtered = _advertisements;

    if (_selectedServiceFilter != null) {
      filtered = filtered
          .where((ad) => ad.serviceType == _selectedServiceFilter)
          .toList();
    }

    if (_selectedSupermarketFilter != null) {
      if (_selectedSupermarketFilter == 'general') {
        filtered = filtered.where((ad) => ad.supermarketId == null).toList();
      } else {
        filtered = filtered
            .where((ad) => ad.supermarketId == _selectedSupermarketFilter)
            .toList();
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إدارة الإعلانات والتنزيلات'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push('/admin/advertisements/add'),
              tooltip: 'إضافة إعلان جديد',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Filters
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _selectedServiceFilter,
                                decoration: InputDecoration(
                                  labelText: 'نوع الخدمة',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'الكل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text(
                                      'جميع الخدمات',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'delivery',
                                    child: Text(
                                      'توصيل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'taxi',
                                    child: Text(
                                      'تكسي',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'maintenance',
                                    child: Text(
                                      'صيانة',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                selectedItemBuilder: (BuildContext context) {
                                  return [
                                    const Text(
                                      'الكل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'جميع الخدمات',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'توصيل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'تكسي',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'صيانة',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ];
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedServiceFilter = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _selectedSupermarketFilter,
                                decoration: InputDecoration(
                                  labelText: 'السوبر ماركت',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'الكل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'general',
                                    child: Text(
                                      'عام',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ..._supermarkets.map((sm) => DropdownMenuItem(
                                        value: sm.id,
                                        child: Text(
                                          sm.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                                ],
                                selectedItemBuilder: (BuildContext context) {
                                  return [
                                    const Text(
                                      'الكل',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'عام',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    ..._supermarkets.map((sm) => Text(
                                          sm.name,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                  ];
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSupermarketFilter = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: _filteredAdvertisements.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.campaign_rounded,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد إعلانات',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredAdvertisements.length,
                              itemBuilder: (context, index) {
                                final ad = _filteredAdvertisements[index];
                                return _buildAdvertisementCard(ad);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdvertisementCard(Advertisement ad) {
    final serviceColor = _getServiceTypeColor(ad.serviceType);
    final supermarketName = _getSupermarketName(ad.supermarketId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/admin/advertisements/edit/${ad.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Image
                  if (ad.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: ad.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: serviceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: serviceColor,
                        size: 40,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ad.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            ad.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: serviceColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: serviceColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getServiceTypeName(ad.serviceType),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: serviceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                supermarketName ?? 'عام',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ad.hasDiscount)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.successColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'خصم ${ad.discountPercentage}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ad.isActive
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ad.isActive
                                      ? AppTheme.successColor.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                ad.isActive ? 'نشط' : 'غير نشط',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ad.isActive
                                      ? AppTheme.successColor
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'تعديل',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Future.delayed(
                            Duration.zero,
                            () => context.push('/admin/advertisements/edit/${ad.id}'),
                          );
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'حذف',
                                style: TextStyle(color: AppTheme.errorColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Future.delayed(Duration.zero, () => _handleDelete(ad));
                        },
                      ),
                    ],
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




