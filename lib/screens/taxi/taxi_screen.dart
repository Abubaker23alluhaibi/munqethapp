import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:video_player/video_player.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../services/order_service.dart';
import '../../services/driver_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/distance_calculator.dart';
import '../../utils/taxi_fare_calculator.dart';
import '../../services/settings_service.dart';
import '../../models/app_settings.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class TaxiScreen extends StatefulWidget {
  const TaxiScreen({super.key});

  @override
  State<TaxiScreen> createState() => _TaxiScreenState();
}

class _TaxiScreenState extends State<TaxiScreen> {
  final _orderService = OrderService();
  GoogleMapController? _mapController;

  // Locations
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  
  bool _isLoadingLocation = true;
  
  // Order info
  final _pickupSearchController = TextEditingController();
  final _destinationSearchController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSearchingPickup = false;
  bool _isSearchingDestination = false;

  // Map markers
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Available taxi drivers
  List<Driver> _availableTaxiDrivers = [];
  AppSettings? _appSettings;
  Timer? _driverLocationTimer;
  
  // Car icon for taxi markers
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _loadCarIcon(); // تحميل أيقونة السيارة
    _getCurrentLocation();
    _loadAvailableTaxiDrivers();
    _loadAppSettings();
    // Update driver locations every 10 seconds for real-time tracking
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadAvailableTaxiDrivers();
      }
    });
  }

  Future<void> _loadAppSettings() async {
    final settings = await SettingsService().getAppSettings();
    if (mounted) setState(() => _appSettings = settings);
  }
  
  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    _pickupSearchController.dispose();
    _destinationSearchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation({bool updatePickupLocation = true}) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Use default Baghdad location
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(33.3152, 44.3661);
            if (updatePickupLocation) {
              _pickupLocation = _currentLocation;
            }
            _isLoadingLocation = false;
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
              if (updatePickupLocation) {
                _pickupLocation = _currentLocation;
              }
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentLocation = const LatLng(33.3152, 44.3661);
            if (updatePickupLocation) {
              _pickupLocation = _currentLocation;
            }
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      double lat = position.latitude;
      double lng = position.longitude;
      // تصحيح محتمل: إذا ظهرت الإحداثيات معكوسة (مثلاً تظهر تركيا بدل العراق)
      // العراق تقريباً: خط عرض 29–38، خط طول 39–49
      if (lat > 42 && lng < 40) {
        lat = position.longitude;
        lng = position.latitude;
      }
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(lat, lng);
          if (updatePickupLocation) {
            _pickupLocation = _currentLocation;
            _pickupSearchController.text = 'جاري الحصول على العنوان...';
          }
          _isLoadingLocation = false;
        });
        if (updatePickupLocation) {
          _updateMapCamera();
          await _loadAvailableTaxiDrivers(); // إعادة تحميل السائقين بعد تحديث الموقع
          await _getAddressFromLocation(_currentLocation!, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(33.3152, 44.3661);
          if (updatePickupLocation) {
            _pickupLocation = _currentLocation;
          }
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// تحميل السائقين المتاحين من نوع تكسي
  Future<void> _loadAvailableTaxiDrivers() async {
    try {
      final driverService = DriverService();
      final allDrivers = await driverService.getDriversByServiceType('taxi');
      var drivers = allDrivers
          .where((driver) => 
              driver.isAvailable && 
              driver.currentLatitude != null && 
              driver.currentLongitude != null &&
              driver.currentLatitude!.isFinite &&
              driver.currentLongitude!.isFinite)
          .toList();
      
      // ترتيب السائقين حسب المسافة من موقع الانطلاق
      if (_pickupLocation != null) {
        drivers.sort((a, b) {
          final distA = DistanceCalculator.calculateDistance(
            _pickupLocation!.latitude,
            _pickupLocation!.longitude,
            a.currentLatitude!,
            a.currentLongitude!,
          ) ?? double.infinity;
          final distB = DistanceCalculator.calculateDistance(
            _pickupLocation!.latitude,
            _pickupLocation!.longitude,
            b.currentLatitude!,
            b.currentLongitude!,
          ) ?? double.infinity;
          return distA.compareTo(distB);
        });
      }
      
      if (mounted) {
        setState(() {
          _availableTaxiDrivers = drivers;
        });
        
        // Update markers to include taxi drivers
        _updateMarkers();
      }
    } catch (e) {
      // في حالة الخطأ، تأكد من تحديث العلامات على الأقل
      if (mounted) {
        _updateMarkers();
      }
    }
  }

  /// تحميل أيقونة السيارة باللون الأزرق
  Future<void> _loadCarIcon() async {
    try {
      // إنشاء أيقونة السيارة من Material Icons
      const iconSize = 100.0; // زيادة الحجم من 80 إلى 100
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // رسم الأيقونة باللون الأزرق
      // استخدام IconData مباشرة بدون fontPackage
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.local_taxi_rounded.codePoint),
          style: TextStyle(
            fontSize: iconSize * 0.9, // زيادة حجم الأيقونة
            fontFamily: Icons.local_taxi_rounded.fontFamily,
            color: AppTheme.primaryColor, // اللون الأزرق
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // رسم الأيقونة في المنتصف
      textPainter.paint(
        canvas,
        Offset(
          (iconSize - textPainter.width) / 2,
          (iconSize - textPainter.height) / 2,
        ),
      );
      
      // تحويل إلى صورة
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(
        iconSize.toInt(),
        iconSize.toInt(),
      );
      
      // تحويل إلى ByteData
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // إنشاء BitmapDescriptor من الأيقونة
        _carIcon = BitmapDescriptor.fromBytes(pngBytes);
        
        // تحديث العلامات بعد تحميل الأيقونة
        if (mounted) {
          _updateMarkers();
        }
      }
      
      image.dispose();
    } catch (e) {
      // Error loading car icon
      // في حالة الخطأ، استخدم أيقونة افتراضية باللون الأزرق
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Pickup location marker
    if (_pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: _pickupLocation!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقع الانطلاق'),
          onDragEnd: (newPosition) {
            setState(() {
              _pickupLocation = newPosition;
              _pickupSearchController.text = 'جاري الحصول على العنوان...';
            });
            _getAddressFromLocation(newPosition, true);
            _updateRoute();
          },
        ),
      );
    }

    // Destination location marker
    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination_location'),
          position: _destinationLocation!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'موقع الوجهة'),
          onDragEnd: (newPosition) {
            setState(() {
              _destinationLocation = newPosition;
              _destinationSearchController.text = 'جاري الحصول على العنوان...';
            });
            _getAddressFromLocation(newPosition, false);
            _updateRoute();
          },
        ),
      );
    }

    // Available taxi drivers markers
    for (int i = 0; i < _availableTaxiDrivers.length; i++) {
      final driver = _availableTaxiDrivers[i];
      if (driver.currentLatitude != null && 
          driver.currentLongitude != null &&
          driver.currentLatitude!.isFinite &&
          driver.currentLongitude!.isFinite) {
        // حساب المسافة من موقع الانطلاق
        double? distance;
        String distanceText = '';
        if (_pickupLocation != null) {
          distance = DistanceCalculator.calculateDistance(
            _pickupLocation!.latitude,
            _pickupLocation!.longitude,
            driver.currentLatitude!,
            driver.currentLongitude!,
          );
          if (distance != null && distance.isFinite) {
            distanceText = DistanceCalculator.formatDistance(distance);
          }
        }
        
        // إضافة رقم الترتيب للسائق الأقرب
        final isNearest = i == 0 && _pickupLocation != null;
        final title = isNearest 
            ? '🚕 ${driver.name} (الأقرب)'
            : '🚕 ${driver.name}';
        
        final snippet = distance != null && distance.isFinite
            ? '${driver.vehicleNumber ?? driver.phone} • $distanceText'
            : (driver.vehicleNumber ?? driver.phone);
        
        markers.add(
          Marker(
            markerId: MarkerId('taxi_driver_${driver.id}'),
            position: LatLng(driver.currentLatitude!, driver.currentLongitude!),
            // استخدام أيقونة السيارة باللون الأزرق
            icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: title,
              snippet: snippet,
            ),
            visible: true,
          ),
        );
      }
    }

    // تحديث العلامات مع حركة سلسة
    setState(() {
      _markers = markers;
    });
    
    // إذا كان هناك سائق أقرب، نحرك الكاميرا قليلاً لإظهاره
    if (_availableTaxiDrivers.isNotEmpty && 
        _pickupLocation != null && 
        _mapController != null &&
        _availableTaxiDrivers[0].currentLatitude != null &&
        _availableTaxiDrivers[0].currentLongitude != null) {
      try {
        final nearestDriver = _availableTaxiDrivers[0];
        final driverLat = nearestDriver.currentLatitude!;
        final driverLng = nearestDriver.currentLongitude!;
        
        // حساب النقطة الوسطى بين موقع الانطلاق والسائق الأقرب
        final centerLat = (_pickupLocation!.latitude + driverLat) / 2;
        final centerLng = (_pickupLocation!.longitude + driverLng) / 2;
        
        // حساب المسافة لتحديد مستوى التكبير
        final distance = DistanceCalculator.calculateDistance(
          _pickupLocation!.latitude,
          _pickupLocation!.longitude,
          driverLat,
          driverLng,
        ) ?? 5.0;
        
        // تكبير مناسب حسب المسافة
        double zoom = 14.0;
        if (distance > 2) zoom = 13.0;
        if (distance > 5) zoom = 12.0;
        if (distance > 10) zoom = 11.0;
        
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(centerLat, centerLng),
            zoom,
          ),
        );
      } catch (e) {
        // تجاهل الأخطاء
      }
    }
  }

  void _updateRoute() {
    final polylines = <Polyline>{};

    if (_pickupLocation != null && _destinationLocation != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLocation!, _destinationLocation!],
          color: AppTheme.primaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _polylines = polylines;
    });
  }

  void _updateMapCamera() {
    if (_mapController == null || _pickupLocation == null || !mounted) return;

    try {
      // حركة سلسة للكاميرا
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupLocation!, 14),
      );
    } catch (e) {
      // Ignore error if controller is disposed
    }
  }

  Future<void> _getMyCurrentLocationForButton() async {
    if (!mounted) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل خدمات الموقع'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يجب منح إذن الموقع للحصول على موقعك الحالي'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل إذن الموقع من إعدادات التطبيق'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      double lat = position.latitude;
      double lng = position.longitude;
      if (lat > 42 && lng < 40) {
        lat = position.longitude;
        lng = position.latitude;
      }
      final newLocation = LatLng(lat, lng);
      
      if (mounted) {
        setState(() {
          _currentLocation = newLocation;
          _pickupLocation = newLocation;
          _pickupSearchController.text = 'جاري الحصول على العنوان...';
        });
        
        _updateMapCamera();
        await _loadAvailableTaxiDrivers(); // إعادة تحميل السائقين بعد تحديث الموقع
        await _getAddressFromLocation(newLocation, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر الحصول على الموقع الحالي: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _getLocationFromAddress(String address, bool isPickup) async {
    if (address.trim().isEmpty) return;
    
    setState(() {
      if (isPickup) {
        _isSearchingPickup = true;
      } else {
        _isSearchingDestination = true;
      }
    });

    try {
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        
        if (mounted) {
          setState(() {
            if (isPickup) {
              _pickupLocation = latLng;
              _isSearchingPickup = false;
            } else {
              _destinationLocation = latLng;
              _isSearchingDestination = false;
            }
          });
          
          if (isPickup) {
            await _loadAvailableTaxiDrivers(); // إعادة تحميل السائقين بعد تحديث موقع الانطلاق
            _updateMapCamera();
          } else {
            _updateRoute();
          }
          
          // Get full address for display
          await _getAddressFromLocation(latLng, isPickup);
        }
      } else {
        if (mounted) {
          setState(() {
            if (isPickup) {
              _isSearchingPickup = false;
            } else {
              _isSearchingDestination = false;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على العنوان المحدد'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isPickup) {
            _isSearchingPickup = false;
          } else {
            _isSearchingDestination = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء البحث: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _getAddressFromLocation(LatLng location, bool isPickup) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Build address from placemark components
        String address = '';
        
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address = placemark.street!;
        }
        if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
          address = '${placemark.subThoroughfare} $address'.trim();
        }
        if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
          address = '${placemark.thoroughfare} $address'.trim();
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          address = address.isEmpty 
              ? placemark.subLocality! 
              : '$address، ${placemark.subLocality}';
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          address = address.isEmpty 
              ? placemark.locality! 
              : '$address، ${placemark.locality}';
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          address = address.isEmpty 
              ? placemark.administrativeArea! 
              : '$address، ${placemark.administrativeArea}';
        }
        
        // If address is still empty, use locality or administrative area
        if (address.isEmpty) {
          address = placemark.locality ?? 
                   placemark.administrativeArea ?? 
                   placemark.country ?? 
                   'موقع محدد';
        }
        
        if (mounted) {
          setState(() {
            if (isPickup) {
              _pickupSearchController.text = address;
            } else {
              _destinationSearchController.text = address;
            }
          });
        }
      } else {
        // Fallback to coordinates if no address found
        if (mounted) {
          setState(() {
            if (isPickup) {
              _pickupSearchController.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
            } else {
              _destinationSearchController.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
            }
          });
        }
      }
    } catch (e) {
      // Fallback to coordinates on error
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSearchController.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
          } else {
            _destinationSearchController.text = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
          }
        });
      }
    }
  }

  Future<void> _onMapTap(LatLng location) async {
    if (_pickupLocation == null) {
      setState(() {
        _pickupLocation = location;
        _pickupSearchController.text = 'جاري الحصول على العنوان...';
      });
      _getAddressFromLocation(location, true);
      await _loadAvailableTaxiDrivers(); // إعادة تحميل السائقين بعد تحديث موقع الانطلاق
    } else if (_destinationLocation == null) {
      setState(() {
        _destinationLocation = location;
        _destinationSearchController.text = 'جاري الحصول على العنوان...';
      });
      _getAddressFromLocation(location, false);
      _updateRoute();
    } else {
      // Toggle between pickup and destination
      setState(() {
        _destinationLocation = null;
        _pickupLocation = location;
        _pickupSearchController.text = 'جاري الحصول على العنوان...';
        _destinationSearchController.clear();
      });
      _getAddressFromLocation(location, true);
      _updateRoute();
      await _loadAvailableTaxiDrivers(); // إعادة تحميل السائقين بعد تحديث موقع الانطلاق
    }
  }

  double _calculateDistance() {
    if (_pickupLocation == null || _destinationLocation == null) return 0.0;

    final distance = DistanceCalculator.calculateDistance(
      _pickupLocation!.latitude,
      _pickupLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
    
    // التحقق من أن المسافة صحيحة
    if (distance == null || distance <= 0 || !distance.isFinite) {
      return 0.0;
    }
    
    return distance;
  }

  int _calculateFare() {
    if (_pickupLocation == null || _destinationLocation == null) {
      return 0;
    }
    
    final distance = _calculateDistance();
    if (distance <= 0 || !distance.isFinite) {
      return 0;
    }
    
    final taxi = _appSettings?.taxi;
    final isPeak = taxi != null
        ? TaxiFareCalculator.isPeakTimeFrom(taxi.peakMorningStart, taxi.peakMorningEnd, taxi.peakEveningStart, taxi.peakEveningEnd)
        : TaxiFareCalculator.isPeakTime();
    final isNight = taxi != null
        ? TaxiFareCalculator.isNightTimeFrom(taxi.nightStart, taxi.nightEnd)
        : TaxiFareCalculator.isNightTime();
    
    return TaxiFareCalculator.calculateFare(
      distance,
      isPeakTime: isPeak,
      isNight: isNight,
      hasTraffic: false,
      nightMinFare: taxi?.nightMinFare,
      nightMaxFare: taxi?.nightMaxFare,
      peakMinFare: taxi?.peakMinFare,
      peakMaxFare: taxi?.peakMaxFare,
    );
  }

  Future<void> _submitOrder() async {
    if (_pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد موقع الانطلاق'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد موقع الوجهة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Get user info from StorageService
    final userName = StorageService.getString('user_name') ?? 'مستخدم';
    final userPhone = StorageService.getString('user_phone') ?? '';

    if (userPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على رقم الهاتف. الرجاء تسجيل الدخول مرة أخرى'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Show loading dialog with image when searching for drivers FIRST
    if (!mounted) return;
    
    // Show dialog immediately with image and search message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TaxiLoadingWidget(),
                    const SizedBox(height: 20),
                    const Text(
                      'جاري البحث عن أقرب تكسي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ),
        );
      },
    );
    
    // Give time for dialog to fully render
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final driverService = DriverService();
      
      // Find nearest 4 drivers with distances
      final driversResult = await driverService.findNearestDriversWithDistances(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        'taxi',
        limit: 4,
      );
      
      final nearestDrivers = driversResult['drivers'] as List<Driver>;
      final distances = driversResult['distances'] as List<double>;
      
      // Close loading dialog first
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Check if there's a driver within 3km
      if (nearestDrivers.isEmpty) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد تكسي متاح حالياً. الرجاء المحاولة لاحقاً'),
              backgroundColor: AppTheme.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      final maxTaxiKm = _appSettings?.taxi.maxDistanceKm ?? 3.0;
      final nearestDistance = distances.isNotEmpty ? distances[0] : null;
      if (nearestDistance == null || nearestDistance > maxTaxiKm) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يوجد تكسي متاح ضمن مسافة ${maxTaxiKm.toStringAsFixed(0)} كيلومتر. الرجاء المحاولة لاحقاً'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      // Driver found within 3km - continue to send request
      final orderId = 'TAXI${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final fare = _calculateFare();

      final order = Order(
        id: orderId,
        type: 'taxi',
        customerName: userName,
        customerPhone: userPhone,
        customerLatitude: _pickupLocation!.latitude,
        customerLongitude: _pickupLocation!.longitude,
        destinationLatitude: _destinationLocation!.latitude,
        destinationLongitude: _destinationLocation!.longitude,
        status: OrderStatus.pending,
        fare: fare.toDouble(),
        createdAt: DateTime.now(),
      );

      await _orderService.createOrder(order);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم إرسال الطلب',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تم إرسال طلبك بنجاح'),
                const SizedBox(height: 8),
                Text('رقم الطلب: $orderId'),
                const SizedBox(height: 8),
                Text('التكلفة المقدرة: ${fare.toStringAsFixed(0)} د.ع'),
                const SizedBox(height: 8),
                const Text('تم إرسال الطلب لأقرب تكسي - بانتظار الموافقة'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/orders/history');
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        // Close loading dialog if still open
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // Dialog might not be open, ignore
        }
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء البحث عن التكسي: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // Full Screen Map
            if (_isLoadingLocation)
              Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              )
            else if (_pickupLocation == null)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Text(
                    'جاري تحميل الخريطة...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              )
            else
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_pickupLocation!.latitude, _pickupLocation!.longitude),
                  zoom: 15,
                ),
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await Future.delayed(const Duration(milliseconds: 400));
                  if (mounted && _pickupLocation != null) {
                    _updateMarkers();
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_pickupLocation!, 15),
                    );
                    if (_availableTaxiDrivers.isEmpty) {
                      await _loadAvailableTaxiDrivers();
                    }
                  }
                },
                onTap: _onMapTap,
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
                mapType: MapType.normal,
                compassEnabled: true,
                buildingsEnabled: true,
                trafficEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                zoomGesturesEnabled: true,
              ),
            
            // Top Search Bars (like Uber/Careem)
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo and Location Button Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppTheme.elevatedShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/icons/logo2.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to logo.png if logo2.png is not found
                                return Image.asset(
                                  'assets/icons/logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Current Location Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.elevatedShadow,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.my_location_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () async {
                              await _getMyCurrentLocationForButton();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Pickup Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      child: TextField(
                        controller: _pickupSearchController,
                        decoration: InputDecoration(
                          hintText: 'من أين تريد الانطلاق؟ (اكتب العنوان أو حدد على الخريطة)',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.radio_button_checked,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          suffixIcon: _isSearchingPickup
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    if (_pickupSearchController.text.trim().isNotEmpty) {
                                      _getLocationFromAddress(_pickupSearchController.text.trim(), true);
                                    }
                                  },
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _getLocationFromAddress(value.trim(), true);
                          }
                        },
                        onTap: () {
                          // Focus on pickup location
                          if (_pickupLocation != null) {
                            _updateMapCamera();
                          }
                        },
                      ),
                    ),
                  ),
                  
                  // Destination Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      child: TextField(
                        controller: _destinationSearchController,
                        decoration: InputDecoration(
                          hintText: 'إلى أين تريد الذهاب؟ (اكتب العنوان أو حدد على الخريطة)',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.errorColor,
                              size: 20,
                            ),
                          ),
                          suffixIcon: _isSearchingDestination
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.errorColor),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search, color: AppTheme.errorColor),
                                  onPressed: () {
                                    if (_destinationSearchController.text.trim().isNotEmpty) {
                                      _getLocationFromAddress(_destinationSearchController.text.trim(), false);
                                    }
                                  },
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _getLocationFromAddress(value.trim(), false);
                          }
                        },
                        onTap: () {
                          // Focus on destination or allow selection
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // عرض السعر وزر الإرسال
            if (_pickupLocation != null && _destinationLocation != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // عرض السعر أولاً
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'السعر الإجمالي:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_calculateFare()} د.ع',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // زر الإرسال
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 6,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 20),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'موافق',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

}

// Widget لعرض الفيديو MP4
class _VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  final double height;
  final double width;

  const _VideoPlayerWidget({
    required this.videoPath,
    required this.height,
    required this.width,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: const Icon(
          Icons.local_taxi,
          size: 120,
          color: AppTheme.primaryColor,
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

// Widget لعرض التكسي المتحرك مع اللمبات والخطوط
class _TaxiLoadingWidget extends StatefulWidget {
  const _TaxiLoadingWidget();

  @override
  State<_TaxiLoadingWidget> createState() => _TaxiLoadingWidgetState();
}

class _TaxiLoadingWidgetState extends State<_TaxiLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _lightController;
  late Animation<double> _lightAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation لحركة التكسي (الأمام والخلف)
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    // Animation لللمبات والخطوط (تنطفئ وتشتغل)
    _lightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    
    _lightAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lightController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _lightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الصورة المتحركة (تتحرك كأنها تمشي)
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              // حركة أفقية للأمام والخلف
              final horizontalOffset = math.sin(_rotationController.value * 2 * math.pi) * 15;
              // حركة عمودية خفيفة (كأنها على طريق)
              final verticalOffset = math.sin(_rotationController.value * 4 * math.pi) * 3;
              // دوران خفيف
              final rotation = math.sin(_rotationController.value * 2 * math.pi) * 0.05;
              
              return Transform.translate(
                offset: Offset(horizontalOffset, verticalOffset),
                child: Transform.rotate(
                  angle: rotation,
                  child: Image.asset(
                    'assets/images/taxiLaod.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // 3 لمبات صغيرة فوق الصورة
          Positioned(
            top: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _lightAnimation,
                  builder: (context, child) {
                    // تأخير لكل لمبة
                    final delay = index * 0.2;
                    final adjustedValue = (_lightController.value + delay) % 1.0;
                    final opacity = adjustedValue < 0.5 
                        ? (adjustedValue * 2) 
                        : (2 - adjustedValue * 2);
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withOpacity(opacity),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(opacity * 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          
          // 3 خطوط مستقيمة باللون الأزرق تحت الصورة (تتحرك كموجة)
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _lightController,
                  builder: (context, child) {
                    // تأخير لكل خط لإنشاء تأثير الموجة
                    final delay = index * 0.2;
                    final adjustedValue = (_lightController.value + delay) % 1.0;
                    // ارتفاع الخط يتغير من 8 إلى 20
                    final height = 8 + (adjustedValue < 0.5 
                        ? (adjustedValue * 2 * 12) 
                        : ((2 - adjustedValue * 2) * 12));
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 4,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

