import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
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

      setState(() {
        _isLoading = true;
      });

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

        // Find nearest 4 drivers (the backend will send notifications to them)
        final nearestDrivers = await _driverService.findNearestDrivers(
          _pickupLat!,
          _pickupLng!,
          widget.serviceType,
          limit: 4,
        );
        
        print('Found ${nearestDrivers.length} nearest drivers for ${widget.serviceType} order');
        
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

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
                      : 'في انتظار الموافقة',
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
        );
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
                          'موافق وإرسال الطلب',
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

