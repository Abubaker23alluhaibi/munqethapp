import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../models/supermarket.dart';

class AddLocationScreen extends StatefulWidget {
  final Supermarket supermarket;

  const AddLocationScreen({
    super.key,
    required this.supermarket,
  });

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final _adminService = AdminService();
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(33.3152, 44.3661); // بغداد
            _isLoading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentLocation = const LatLng(33.3152, 44.3661);
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(33.3152, 44.3661);
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _updateMapCamera();
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(33.3152, 44.3661);
          _isLoading = false;
        });
      }
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 13),
      );
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
    });

    // الحصول على العنوان من الإحداثيات
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address = '${place.street}, ${place.locality}, ${place.country}';
        _addressController.text = address;
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    // إظهار dialog لإضافة الموقع
    _showAddLocationDialog(position);
  }

  Future<void> _showAddLocationDialog(LatLng position) async {
    _nameController.clear();
    if (_addressController.text.isEmpty) {
      // الحصول على العنوان إذا لم يكن موجوداً
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          final address = '${place.street}, ${place.locality}, ${place.country}';
          _addressController.text = address;
        }
      } catch (e) {
        print('Error getting address: $e');
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة موقع جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموقع (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _addLocation(position);
    }
  }

  Future<void> _addLocation(LatLng position) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final updatedSupermarket = await _adminService.addLocationToSupermarket(
        widget.supermarket.id,
        _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        position.latitude,
        position.longitude,
        _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // إغلاق loading

        if (updatedSupermarket != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الموقع بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // العودة للصفحة السابقة
          Navigator.pop(context, updatedSupermarket);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل إضافة الموقع'),
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
          title: const Text('إضافة موقع جديد'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? const LatLng(33.3152, 44.3661),
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                    }
                  : {},
              onTap: _onMapTap,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
            ),
            // زر إضافة موقع في موقعي الحالي
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_currentLocation != null) {
                    _onMapTap(_currentLocation!);
                  }
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('إضافة موقع في موقعي الحالي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            // تعليمات
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اضغط على الخريطة لتحديد موقع جديد',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



