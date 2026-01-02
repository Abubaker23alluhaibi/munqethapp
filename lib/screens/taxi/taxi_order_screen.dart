import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../services/order_service.dart';
import '../../services/driver_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../widgets/payment_method_selector.dart';
import '../../core/utils/distance_calculator.dart';
import '../../utils/taxi_fare_calculator.dart';
import '../../services/card_service.dart';
import '../../core/storage/secure_storage_service.dart';

class TaxiOrderScreen extends StatefulWidget {
  final String? driverId;
  final String serviceType; // 'taxi' or 'crane'

  const TaxiOrderScreen({
    super.key,
    this.driverId,
    this.serviceType = 'taxi',
  });

  @override
  State<TaxiOrderScreen> createState() => _TaxiOrderScreenState();
}

class _TaxiOrderScreenState extends State<TaxiOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderService = OrderService();
  final _driverService = DriverService();
  final _cardService = CardService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _destinationAddressController = TextEditingController();

  // Locations
  double? _pickupLat;
  double? _pickupLng;
  double? _destinationLat;
  double? _destinationLng;

  // Payment
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedCardId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userName = StorageService.getString('user_name');
    final userPhone = StorageService.getString('user_phone');
    final userAddress = StorageService.getString('user_address');
    
    if (userName != null && userName.isNotEmpty) {
      _nameController.text = userName;
    }
    if (userPhone != null && userPhone.isNotEmpty) {
      _phoneController.text = userPhone;
    }
    if (userAddress != null && userAddress.isNotEmpty) {
      _addressController.text = userAddress;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _destinationAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_formKey.currentState!.validate()) {
      // Validate locations
      if (_pickupLat == null || _pickupLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.serviceType == 'crane' 
                ? 'الرجاء تحديد موقعك على الخريطة'
                : 'الرجاء تحديد موقع الانطلاق على الخريطة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Validate destination only for taxi, not for crane
      if (widget.serviceType != 'crane') {
        if (_destinationLat == null || _destinationLng == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء تحديد موقع الوجهة على الخريطة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }

      // Show loading dialog with video when searching for drivers FIRST
      if (!mounted) return;
      
      // Set loading state first to disable button
      setState(() {
        _isLoading = true;
      });
      
      // Show dialog immediately with video and search message
      // Show dialog synchronously to ensure it appears before async operations
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
                    widget.serviceType == 'crane' 
                        ? const _CraneLoadingWidget()
                        : const _TaxiLoadingWidget(),
                    const SizedBox(height: 20),
                    Text(
                      widget.serviceType == 'crane'
                          ? 'جاري البحث عن أقرب كرين'
                          : 'جاري البحث عن أقرب تكسي',
                      style: const TextStyle(
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
      
      // Give time for dialog and video to fully render and appear on screen
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Generate order ID
        final prefix = widget.serviceType == 'crane' ? 'CRANE' : 'TAXI';
        final orderId = '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        // Calculate fare (simple calculation based on distance)
        double fare;
        if (widget.serviceType == 'crane') {
          // For crane, use a fixed fare or calculate based on distance to driver
          fare = 50000.0; // Fixed fare for crane (example)
        } else {
          // For taxi, calculate based on distance between pickup and destination
          final distance = _calculateDistance(
            _pickupLat!,
            _pickupLng!,
            _destinationLat!,
            _destinationLng!,
          );
          
          if (distance <= 0 || !distance.isFinite) {
            fare = 2000.0; // Default minimum fare
          } else {
            // تحديد وقت الذروة والليل
            final isPeak = TaxiFareCalculator.isPeakTime();
            final isNight = TaxiFareCalculator.isNightTime();
            
            fare = TaxiFareCalculator.calculateFare(
              distance,
              isPeakTime: isPeak,
              isNight: isNight,
              hasTraffic: false, // يمكن إضافة منطق للزحام لاحقاً
            ).toDouble();
          }
        }

        // Find nearest 4 drivers with distances (the backend will send notifications to them)
        final driversResult = await _driverService.findNearestDriversWithDistances(
          _pickupLat!,
          _pickupLng!,
          widget.serviceType,
          limit: 4,
        );
        
        final nearestDrivers = driversResult['drivers'] as List<Driver>;
        final distances = driversResult['distances'] as List<double>;
        
        // Check if there's a driver within the allowed distance
        if (widget.serviceType == 'taxi') {
          // Close loading dialog first
          if (mounted) {
            Navigator.of(context).pop();
          }
          
          if (nearestDrivers.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
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
          
          // Check if nearest driver is within 3 km
          final nearestDistance = distances.isNotEmpty ? distances[0] : null;
          if (nearestDistance == null || nearestDistance > 3.0) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يوجد تكسي متاح ضمن مسافة 3 كيلومتر. الرجاء المحاولة لاحقاً'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
          
          // Driver found within 3km - continue to send request
        } else {
          // For crane, check if there's a crane within 15 km
          if (mounted) {
            Navigator.of(context).pop();
          }
          
          if (nearestDrivers.isEmpty) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يوجد كرين متاح حالياً. الرجاء المحاولة لاحقاً'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
          
          // Check if nearest crane is within 15 km
          final nearestDistance = distances.isNotEmpty ? distances[0] : null;
          if (nearestDistance == null || nearestDistance > 15.0) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يوجد كرين متاح ضمن مسافة 15 كيلومتر. الرجاء المحاولة لاحقاً'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
          
          // Crane found within 15km - continue to send request
        }
        
        // For display purposes, use the first driver
        final nearestDriver = nearestDrivers.isNotEmpty ? nearestDrivers[0] : null;

        // معالجة الدفع
        final userPhone = await SecureStorageService.getString('user_phone') ?? _phoneController.text.trim();
        bool paymentProcessed = false;

        if (_paymentMethod == PaymentMethod.wallet) {
          // خصم من المحفظة
          paymentProcessed = await _cardService.deductFromWallet(userPhone, fare.toInt());
          if (!paymentProcessed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الرصيد في المحفظة غير كافي'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else if (_paymentMethod == PaymentMethod.card && _selectedCardId != null) {
          // خصم من البطاقة
          paymentProcessed = await _cardService.useCardForPayment(userPhone, _selectedCardId!, fare.toInt());
          if (!paymentProcessed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل استخدام البطاقة للدفع'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // Create order
        final order = Order(
          id: orderId,
          type: widget.serviceType,
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          customerAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          customerLatitude: _pickupLat,
          customerLongitude: _pickupLng,
          destinationLatitude: widget.serviceType == 'crane' ? null : _destinationLat,
          destinationLongitude: widget.serviceType == 'crane' ? null : _destinationLng,
          destinationAddress: widget.serviceType == 'crane' 
              ? null 
              : (_destinationAddressController.text.trim().isEmpty
                  ? null
                  : _destinationAddressController.text.trim()),
          status: OrderStatus.pending,
          fare: fare,
          createdAt: DateTime.now(),
          paymentMethod: _paymentMethod.name,
          paymentCardId: _selectedCardId,
        );

        // Save order
        await _orderService.createOrder(order);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show success dialog with "تم إرسال الطلب" message
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
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم إرسال الطلب',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم إرسال طلبك بنجاح',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'رقم الطلب: $orderId',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'التكلفة المقدرة: ${fare.toStringAsFixed(0)} د.ع',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.serviceType == 'crane'
                      ? 'في انتظار موافقة الكرين'
                      : 'تم إرسال الطلب لأقرب تكسي - بانتظار الموافقة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                    // إعادة توجيه المستخدم لصفحة الطلبات
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
            _isLoading = false;
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
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final distance = DistanceCalculator.calculateDistance(lat1, lon1, lat2, lon2);
    
    // التحقق من أن المسافة صحيحة
    if (distance == null || distance <= 0 || !distance.isFinite) {
      return 0.0;
    }
    
    return distance;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(widget.serviceType == 'crane' ? 'طلب كرين طوارئ' : 'طلب تكسي'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.serviceType == 'crane' ? 'طلب كرين طوارئ' : 'طلب تكسي',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.serviceType == 'crane'
                            ? 'املأ النموذج وسيتم إرسال طلبك لأقرب كرين متاح'
                            : 'املأ النموذج وسيتم إرسال طلبك لأقرب سائق تكسي متاح',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Customer Info Section
                _buildSectionTitle('معلومات العميل'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم *',
                    hintText: 'أدخل اسمك',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الاسم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف *',
                    hintText: 'مثال: 07701234567',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Pickup Location Section
                _buildSectionTitle(widget.serviceType == 'crane' ? 'موقعك الحالي' : 'موقع الانطلاق'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: widget.serviceType == 'crane' ? 'عنوان موقعك' : 'عنوان الانطلاق',
                    hintText: widget.serviceType == 'crane' ? 'أدخل عنوان موقعك (اختياري)' : 'أدخل عنوان الانطلاق (اختياري)',
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                LocationPickerWidget(
                  label: widget.serviceType == 'crane' ? 'حدد موقعك على الخريطة *' : 'حدد موقع الانطلاق على الخريطة *',
                  initialLatitude: _pickupLat,
                  initialLongitude: _pickupLng,
                  onLocationSelected: (lat, lng) {
                    setState(() {
                      _pickupLat = lat;
                      _pickupLng = lng;
                    });
                    // إعادة بناء الواجهة لحساب السعر
                  },
                ),
                // Destination Location Section (only for taxi, not for crane)
                if (widget.serviceType != 'crane') ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('موقع الوجهة'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _destinationAddressController,
                    decoration: InputDecoration(
                      labelText: 'عنوان الوجهة',
                      hintText: 'أدخل عنوان الوجهة (اختياري)',
                      prefixIcon: const Icon(Icons.place_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  LocationPickerWidget(
                    label: 'حدد موقع الوجهة على الخريطة *',
                    initialLatitude: _destinationLat,
                    initialLongitude: _destinationLng,
                    onLocationSelected: (lat, lng) {
                      setState(() {
                        _destinationLat = lat;
                        _destinationLng = lng;
                      });
                      // إعادة بناء الواجهة لحساب السعر
                    },
                  ),
                ],
                const SizedBox(height: 24),
                // عرض السعر أولاً
                Builder(
                  builder: (context) {
                    // Calculate fare for display
                    double displayFare = 0;
                    if (_pickupLat != null && _pickupLng != null) {
                      if (widget.serviceType == 'crane') {
                        displayFare = 50000.0;
                      } else if (_destinationLat != null && _destinationLng != null) {
                        final distance = _calculateDistance(
                          _pickupLat!,
                          _pickupLng!,
                          _destinationLat!,
                          _destinationLng!,
                        );
                        
                        if (distance > 0 && distance.isFinite) {
                            // تحديد وقت الذروة والليل
                          final isPeak = TaxiFareCalculator.isPeakTime();
                          final isNight = TaxiFareCalculator.isNightTime();
                          
                          displayFare = TaxiFareCalculator.calculateFare(
                            distance,
                            isPeakTime: isPeak,
                            isNight: isNight,
                            hasTraffic: false,
                          ).toDouble();
                        } else {
                          displayFare = 0;
                        }
                      }
                    }
                    
                    if (displayFare > 0) {
                      return Column(
                        children: [
                          // عرض السعر بشكل واضح
                          Container(
                            padding: const EdgeInsets.all(20),
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
                                  '${displayFare.toStringAsFixed(0)} د.ع',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Payment Method Selector
                          PaymentMethodSelector(
                            totalAmount: displayFare,
                            onPaymentMethodSelected: (method, cardId) {
                              setState(() {
                                _paymentMethod = method;
                                _selectedCardId = cardId;
                              });
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),
                // Submit Button
                Builder(
                  builder: (context) {
                    // Calculate fare to check if button should be enabled
                    double displayFare = 0;
                    if (_pickupLat != null && _pickupLng != null) {
                      if (widget.serviceType == 'crane') {
                        displayFare = 50000.0;
                      } else if (_destinationLat != null && _destinationLng != null) {
                        final distance = _calculateDistance(
                          _pickupLat!,
                          _pickupLng!,
                          _destinationLat!,
                          _destinationLng!,
                        );
                        
                        if (distance > 0 && distance.isFinite) {
                            // تحديد وقت الذروة والليل
                          final isPeak = TaxiFareCalculator.isPeakTime();
                          final isNight = TaxiFareCalculator.isNightTime();
                          
                          displayFare = TaxiFareCalculator.calculateFare(
                            distance,
                            isPeakTime: isPeak,
                            isNight: isNight,
                            hasTraffic: false,
                          ).toDouble();
                        } else {
                          displayFare = 0;
                        }
                      }
                    }
                    
                    return ElevatedButton(
                      onPressed: (_isLoading || displayFare == 0) ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'موافق',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    );
                  },
                ),
                // مسافة إضافية في الأسفل لتجنب تداخل الأزرار
                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
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

// Widget تحميل خاص للكرين
class _CraneLoadingWidget extends StatefulWidget {
  const _CraneLoadingWidget();

  @override
  State<_CraneLoadingWidget> createState() => _CraneLoadingWidgetState();
}

class _CraneLoadingWidgetState extends State<_CraneLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _hookController;
  late Animation<double> _animation;
  late Animation<double> _hookAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Animation للخطاف (يتحرك للأعلى والأسفل)
    _hookController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _hookAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _hookController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _hookController.dispose();
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
          // الصورة المتحركة
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animation.value * 20, math.sin(_controller.value * 2 * math.pi) * 5),
                child: Transform.rotate(
                  angle: _animation.value * 0.1,
                  child: Image.asset(
                    'assets/images/craneloud.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // خطاف متحرك (يتحرك للأعلى والأسفل)
          Positioned(
            top: 20,
            right: 30,
            child: AnimatedBuilder(
              animation: _hookAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _hookAnimation.value),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

