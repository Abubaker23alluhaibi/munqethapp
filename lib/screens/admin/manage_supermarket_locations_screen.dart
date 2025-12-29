import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../models/supermarket.dart';
import '../../core/utils/app_logger.dart';
import 'add_location_screen.dart';

class ManageSupermarketLocationsScreen extends StatefulWidget {
  final Supermarket supermarket;

  const ManageSupermarketLocationsScreen({
    super.key,
    required this.supermarket,
  });

  @override
  State<ManageSupermarketLocationsScreen> createState() =>
      _ManageSupermarketLocationsScreenState();
}

class _ManageSupermarketLocationsScreenState
    extends State<ManageSupermarketLocationsScreen> {
  final _adminService = AdminService();
  Set<Marker> _markers = {};
  bool _isLoading = true;
  Supermarket? _supermarket;

  @override
  void initState() {
    super.initState();
    _supermarket = widget.supermarket;
    _isLoading = false;
    _loadLocations();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadLocations() {
    if (_supermarket?.locations != null && _supermarket!.locations!.isNotEmpty) {
      _markers.clear();
      for (var location in _supermarket!.locations!) {
        _markers.add(
          Marker(
            markerId: MarkerId(location.id ?? ''),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(
              title: location.name ?? 'موقع',
              snippet: location.address ?? '',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }
      setState(() {});
    }
  }

  Future<void> _refreshData() async {
    // إعادة تحميل بيانات السوبر ماركت
    try {
      final updatedSupermarket = await _adminService.getOrCreateAdminSupermarket();
      if (mounted) {
        setState(() {
          _supermarket = updatedSupermarket;
        });
        _loadLocations();
      }
    } catch (e) {
      AppLogger.e('Error refreshing data: $e');
    }
  }

  Future<void> _deleteLocation(SupermarketLocation location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الموقع "${location.name ?? 'موقع'}"؟'),
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
      ),
    );

    if (confirm == true && location.id != null) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final updatedSupermarket = await _adminService.deleteLocationFromSupermarket(
          _supermarket!.id,
          location.id!,
        );

        if (mounted) {
          Navigator.pop(context);

          if (updatedSupermarket != null) {
            setState(() {
              _supermarket = updatedSupermarket;
            });
            _loadLocations();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الموقع بنجاح'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل حذف الموقع'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة مواقع ${_supermarket?.name ?? ''}'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // قائمة المواقع المضافة (أول شيء - أفقية)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المواقع المضافة',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_supermarket?.locations?.length ?? 0}',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_supermarket?.locations == null ||
                          _supermarket!.locations!.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_off_rounded,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مواقع مضافة',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _supermarket!.locations!.length,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemBuilder: (context, index) {
                              final location = _supermarket!.locations![index];
                              return Card(
                                margin: const EdgeInsets.only(left: 12, right: 4),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  width: 240,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.location_on_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              location.name ?? 'موقع ${index + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (location.address != null)
                                        Expanded(
                                          child: Text(
                                            location.address!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                              height: 1.4,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_rounded,
                                              color: Colors.red,
                                              size: 22,
                                            ),
                                            onPressed: () => _deleteLocation(location),
                                            tooltip: 'حذف',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      // زر إضافة موقع جديد
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddLocationScreen(
                                supermarket: _supermarket!,
                              ),
                            ),
                          );
                          // إذا تم إضافة موقع، إعادة تحميل البيانات
                          if (result != null && mounted) {
                            setState(() {
                              _supermarket = result as Supermarket;
                            });
                            _loadLocations();
                          }
                        },
                        icon: const Icon(Icons.add_location_rounded),
                        label: const Text('إضافة موقع جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

