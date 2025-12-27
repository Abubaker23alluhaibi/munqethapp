import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/driver_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../utils/constants.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String serviceType; // 'maintenance', 'car_emergency', 'fuel', 'maid', 'car_wash'
  
  const ServiceRequestScreen({
    super.key,
    required this.serviceType,
  });

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderService = OrderService();
  final _driverService = DriverService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _problemController = TextEditingController();
  final _otherReasonController = TextEditingController();

  // Location
  double? _customerLat;
  double? _customerLng;

  // Car Emergency specific
  String? _selectedReason;
  final List<String> _reasons = [
    'تبديل إطارات',
    'شحن/تبديل بطارية',
    'إصلاح فيت بمب',
    'لا أعرف العطل',
    'الفحص السريع عند الموقع',
    'سبب آخر',
  ];

  // Fuel specific
  int _fuelQuantity = 5;
  double? _calculatedFare; // السعر المحسوب للبنزين

  // Maid specific
  String? _maidServiceType;
  final List<String> _maidServiceTypes = [
    'تنظيف',
    'ترتيب',
    'أطفال',
    'كبار سن',
  ];
  int _maidWorkHours = 1;
  DateTime? _maidWorkDate;

  // Car Wash specific
  String? _carWashSize; // 'small' or 'large'
  final Map<String, Map<String, dynamic>> _carWashSizes = {
    'small': {
      'label': 'سيارة صغيرة',
      'price': 10000,
    },
    'large': {
      'label': 'سيارة كبيرة',
      'price': 15000,
    },
  };

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

  // حساب سعر البنزين
  Future<void> _calculateFuelPrice() async {
    if (_customerLat == null || _customerLng == null) {
      setState(() {
        _calculatedFare = null;
      });
      return;
    }

    try {
      final nearestDriver = await _driverService.findNearestDriver(
        _customerLat!,
        _customerLng!,
        'fuel',
      );

      if (nearestDriver != null) {
        final distance = nearestDriver.distanceTo(_customerLat!, _customerLng!) ?? 1.0;
        final fare = calculateFuelPrice(_fuelQuantity, distance).toDouble();
        setState(() {
          _calculatedFare = fare;
        });
      } else {
        setState(() {
          _calculatedFare = null;
        });
      }
    } catch (e) {
      print('Error calculating fuel price: $e');
      setState(() {
        _calculatedFare = null;
      });
    }
  }

  // Service configuration
  Map<String, dynamic> get _serviceConfig {
    switch (widget.serviceType) {
      case 'car_emergency':
        return {
          'title': 'طلب خدمة طوارئ السيارات',
          'description': 'اختر السبب وحدد موقعك',
        };
      case 'fuel':
        return {
          'title': 'طلب خدمة بنزين',
          'description': 'اختر الكمية وحدد موقعك',
        };
      case 'maid':
        return {
          'title': 'طلب تأجير عاملة',
          'description': 'اختر نوع الخدمة وحدد التفاصيل',
        };
      case 'car_wash':
        return {
          'title': 'طلب خدمة غسيل سيارات',
          'description': 'اختر حجم السيارة وحدد موقعك',
        };
      default: // maintenance
        return {
          'title': 'طلب خدمة تصليح السيارات',
          'description': 'املأ النموذج وسيتم إرسال طلبك لأقرب مصلح متاح',
        };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _problemController.dispose();
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      // Validate service-specific fields
      if (widget.serviceType == 'car_emergency') {
        if (_selectedReason == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء اختيار سبب الطوارئ'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
        if (_selectedReason == 'سبب آخر' && _otherReasonController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء كتابة السبب'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }

      if (widget.serviceType == 'maid') {
        if (_maidServiceType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء اختيار نوع الخدمة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
        if (_maidWorkDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء اختيار تاريخ العمل'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }

      if (widget.serviceType == 'car_wash') {
        if (_carWashSize == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء اختيار حجم السيارة'),
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
        // Validate location
        if (_customerLat == null || _customerLng == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء تحديد موقعك على الخريطة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Generate order ID
        final prefix = widget.serviceType == 'car_emergency'
            ? 'EMERG'
            : widget.serviceType == 'fuel'
                ? 'FUEL'
                : widget.serviceType == 'maid'
                    ? 'MAID'
                    : widget.serviceType == 'car_wash'
                        ? 'WASH'
                        : 'MAINT';
        final orderId = '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        // Get customer location
        final customerLat = _customerLat!;
        final customerLng = _customerLng!;

        // Find nearest driver
        final nearestDriver = _driverService.findNearestDriver(
          customerLat,
          customerLng,
          widget.serviceType,
        );

        // Calculate fare for fuel or car wash
        double? fare;
        if (widget.serviceType == 'fuel') {
          // استخدام السعر المحسوب مسبقاً
          fare = _calculatedFare;
          if (fare == null) {
            // إذا لم يكن محسوباً، احسبه الآن
            final driver = await nearestDriver;
            if (driver != null) {
              final distance = driver.distanceTo(customerLat, customerLng) ?? 1.0;
              fare = calculateFuelPrice(_fuelQuantity, distance).toDouble();
            }
          }
        } else if (widget.serviceType == 'car_wash' && _carWashSize != null) {
          fare = (_carWashSizes[_carWashSize]!['price'] as int).toDouble();
        }

        // Determine emergency reason
        String? emergencyReason;
        if (widget.serviceType == 'car_emergency') {
          emergencyReason = _selectedReason == 'سبب آخر'
              ? _otherReasonController.text.trim()
              : _selectedReason!;
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
          customerLatitude: customerLat,
          customerLongitude: customerLng,
          status: OrderStatus.pending,
          notes: widget.serviceType != 'car_emergency' && widget.serviceType != 'car_wash'
              ? (_problemController.text.trim().isEmpty
                  ? null
                  : _problemController.text.trim())
              : null,
          emergencyReason: emergencyReason,
          fuelQuantity: widget.serviceType == 'fuel' ? _fuelQuantity : null,
          maidServiceType: widget.serviceType == 'maid' ? _maidServiceType : null,
          maidWorkHours: widget.serviceType == 'maid' ? _maidWorkHours : null,
          maidWorkDate: widget.serviceType == 'maid' ? _maidWorkDate : null,
          carWashSize: widget.serviceType == 'car_wash' ? _carWashSize : null,
          fare: fare,
          createdAt: DateTime.now(),
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
          barrierDismissible: false,
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
                if (fare != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'التكلفة: ${fare.toStringAsFixed(0)} د.ع',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (nearestDriver != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'سيتم التواصل معك قريباً',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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


  @override
  Widget build(BuildContext context) {
    final config = _serviceConfig;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(config['title']),
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
                        config['title'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        config['description'],
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
                // Name field
                TextFormField(
                  controller: _nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'الاسم *',
                    hintText: 'أدخل اسمك',
                    prefixIcon: const Icon(Icons.person_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الاسم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف *',
                    hintText: 'أدخل رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Service-specific fields
                if (widget.serviceType == 'car_emergency') ...[
                  const Text(
                    'سبب الطوارئ *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._reasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          groupValue: _selectedReason,
                          onChanged: (value) {
                            setState(() {
                              _selectedReason = value;
                              if (value != 'سبب آخر') {
                                _otherReasonController.clear();
                              }
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )),
                  if (_selectedReason == 'سبب آخر') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otherReasonController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'اكتب السبب',
                        hintText: 'أدخل سبب الطوارئ',
                        prefixIcon: const Icon(Icons.edit_rounded, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ] else if (widget.serviceType == 'fuel') ...[
                  const Text(
                    'كمية البنزين (لتر) *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _fuelQuantity.toDouble(),
                    min: 5,
                    max: 20,
                    divisions: 3,
                    label: '$_fuelQuantity لتر',
                    onChanged: (value) {
                      setState(() {
                        _fuelQuantity = value.toInt();
                      });
                      // حساب السعر عند تغيير الكمية
                      _calculateFuelPrice();
                    },
                    activeColor: config['color'],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [5, 10, 15, 20].map((qty) => ChoiceChip(
                          label: Text('$qty لتر'),
                          selected: _fuelQuantity == qty,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _fuelQuantity = qty;
                              });
                              // حساب السعر عند تغيير الكمية
                              _calculateFuelPrice();
                            }
                          },
                          selectedColor: AppTheme.primaryColor,
                        )).toList(),
                  ),
                ] else if (widget.serviceType == 'maid') ...[
                  const Text(
                    'نوع الخدمة *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _maidServiceType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _maidServiceTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _maidServiceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'عدد ساعات العمل *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _maidWorkHours.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '$_maidWorkHours ساعة',
                    onChanged: (value) {
                      setState(() {
                        _maidWorkHours = value.toInt();
                      });
                    },
                    activeColor: config['color'],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تاريخ العمل *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() {
                          _maidWorkDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            _maidWorkDate != null
                                ? '${_maidWorkDate!.day}/${_maidWorkDate!.month}/${_maidWorkDate!.year}'
                                : 'اختر التاريخ',
                            style: TextStyle(
                              color: _maidWorkDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (widget.serviceType == 'car_wash') ...[
                  const Text(
                    'حجم السيارة *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._carWashSizes.entries.map((entry) {
                    final sizeKey = entry.key;
                    final sizeData = entry.value;
                    final isSelected = _carWashSize == sizeKey;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _carWashSize = sizeKey;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: sizeKey,
                                groupValue: _carWashSize,
                                onChanged: (value) {
                                  setState(() {
                                    _carWashSize = value;
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sizeData['label'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${sizeData['price']} د.ع',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  // Maintenance - problem description
                  TextFormField(
                    controller: _problemController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'وصف المشكلة',
                      hintText: 'أدخل وصفاً للمشكلة (اختياري)',
                      prefixIcon: const Icon(Icons.description_rounded, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    maxLines: 4,
                  ),
                ],
                const SizedBox(height: 24),
                // Location Picker
                LocationPickerWidget(
                  label: 'حدد موقعك على الخريطة *',
                  initialLatitude: _customerLat,
                  initialLongitude: _customerLng,
                  onLocationSelected: (lat, lng) {
                    setState(() {
                      _customerLat = lat;
                      _customerLng = lng;
                    });
                    // حساب السعر عند تغيير الموقع (للبنزين)
                    if (widget.serviceType == 'fuel') {
                      _calculateFuelPrice();
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Address description
                TextFormField(
                  controller: _addressController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'وصف الموقع',
                    hintText: 'أدخل وصفاً للموقع (اختياري)',
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  maxLines: 2,
                ),
                // عرض السعر للبنزين
                if (widget.serviceType == 'fuel' && _calculatedFare != null) ...[
                  const SizedBox(height: 24),
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
                          '${_calculatedFare!.toStringAsFixed(0)} د.ع',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Submit button
                ElevatedButton(
                  onPressed: (_isLoading || (widget.serviceType == 'fuel' && _calculatedFare == null)) 
                      ? null 
                      : _submitRequest,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'إرسال الطلب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
}

