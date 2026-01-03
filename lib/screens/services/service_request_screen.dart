import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/driver.dart';
import '../../services/order_service.dart';
import '../../services/driver_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/distance_calculator.dart';

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
  final _userService = UserService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _problemController = TextEditingController();
  final _otherReasonController = TextEditingController();
  
  String? _savedUserName; // الاسم المحفوظ من قاعدة البيانات

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
    // جلب بيانات المستخدم من AuthProvider (من قاعدة البيانات)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadCurrentUser();
    
    final user = authProvider.currentUser;
    if (user != null) {
      // استخدام الاسم والهاتف والعنوان من قاعدة البيانات
      _savedUserName = user.name;
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      if (user.address != null && user.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }
    } else {
      // إذا لم يكن المستخدم مسجل دخول، جرب جلب من Storage
      final userPhone = StorageService.getString('user_phone');
      if (userPhone != null && userPhone.isNotEmpty) {
        _phoneController.text = userPhone;
      }
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
      // Error calculating fuel price
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
        // Validate location (not required for maid service)
        if (widget.serviceType != 'maid' && (_customerLat == null || _customerLng == null)) {
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

        // Show loading dialog with service-specific widget (for all services including maid)
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
                      _getLoadingWidget(),
                      const SizedBox(height: 20),
                      Text(
                        _getSearchMessage(),
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
        
        // Give time for dialog to render
        await Future.delayed(const Duration(milliseconds: 300));
        
        // إبطاء عملية البحث قليلاً للبحث بدقة (لجميع الخدمات)
        await Future.delayed(const Duration(milliseconds: 1500));

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

        // Find nearest driver with distance check (15 km max for all services)
        Driver? nearestDriver;
        double? driverDistance;
        
        if (widget.serviceType != 'maid' && _customerLat != null && _customerLng != null) {
          nearestDriver = await _driverService.findNearestDriver(
            _customerLat!,
            _customerLng!,
            widget.serviceType,
          );
          
          if (nearestDriver != null) {
            driverDistance = nearestDriver.distanceTo(_customerLat!, _customerLng!);
            
            // Check if driver is within 15 km
            if (driverDistance == null || driverDistance > 15.0) {
              // Close loading dialog
              if (mounted) {
                Navigator.of(context).pop();
              }
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('لا يوجد ${_getServiceName()} متاح ضمن مسافة 15 كيلومتر. الرجاء المحاولة لاحقاً'),
                    backgroundColor: AppTheme.errorColor,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
          } else {
            // Close loading dialog
            if (mounted) {
              Navigator.of(context).pop();
            }
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('لا يوجد ${_getServiceName()} متاح حالياً. الرجاء المحاولة لاحقاً'),
                  backgroundColor: AppTheme.errorColor,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        } else {
          nearestDriver = null;
        }

        // إبطاء إضافي قليلاً للبحث بدقة (خاصة للعاملة)
        if (widget.serviceType == 'maid') {
          await Future.delayed(const Duration(milliseconds: 800));
        }

        // Close loading dialog (for all services)
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Calculate fare for fuel, car wash, or maid
        double? fare;
        if (widget.serviceType == 'fuel') {
          // استخدام السعر المحسوب مسبقاً
          fare = _calculatedFare;
          if (fare == null && nearestDriver != null && _customerLat != null && _customerLng != null) {
            final distance = driverDistance ?? nearestDriver.distanceTo(_customerLat!, _customerLng!) ?? 1.0;
            fare = calculateFuelPrice(_fuelQuantity, distance).toDouble();
          }
        } else if (widget.serviceType == 'car_wash' && _carWashSize != null) {
          fare = (_carWashSizes[_carWashSize]!['price'] as int).toDouble();
        } else if (widget.serviceType == 'maid') {
          // سعر ثابت للعاملة: 55000 دينار
          fare = 55000.0;
        }

        // Determine emergency reason
        String? emergencyReason;
        if (widget.serviceType == 'car_emergency') {
          emergencyReason = _selectedReason == 'سبب آخر'
              ? _otherReasonController.text.trim()
              : _selectedReason!;
        }

        // Create order - استخدام الاسم المدخل في النموذج (حتى لو كان هناك اسم محفوظ)
        final order = Order(
          id: orderId,
          type: widget.serviceType,
          customerName: _nameController.text.trim(), // استخدام الاسم المدخل في النموذج
          customerPhone: _phoneController.text.trim(),
          customerAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          customerLatitude: widget.serviceType == 'maid' ? null : _customerLat,
          customerLongitude: widget.serviceType == 'maid' ? null : _customerLng,
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
                const SizedBox(height: 8),
                Text(
                  'في انتظار الموافقة',
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
              content: Text('حدث خطأ: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  // Get service name for messages
  String _getServiceName() {
    switch (widget.serviceType) {
      case 'fuel':
        return 'بنزين';
      case 'car_emergency':
        return 'طوارئ سيارات';
      case 'car_wash':
        return 'غسيل سيارات';
      case 'maintenance':
        return 'مصلح';
      default:
        return 'خدمة';
    }
  }

  // Get search message
  String _getSearchMessage() {
    switch (widget.serviceType) {
      case 'fuel':
        return 'جاري البحث عن أقرب بنزين';
      case 'car_emergency':
        return 'جاري البحث عن أقرب طوارئ سيارات';
      case 'car_wash':
        return 'جاري البحث عن أقرب خدمة غسيل';
      case 'maintenance':
        return 'جاري البحث عن أقرب مصلح';
      case 'maid':
        return 'جاري البحث عن أقرب عاملة متاحة';
      default:
        return 'جاري البحث';
    }
  }

  // Get loading widget based on service type
  Widget _getLoadingWidget() {
    switch (widget.serviceType) {
      case 'fuel':
        return const _FuelLoadingWidget();
      case 'car_emergency':
        return const _CarEmergencyLoadingWidget();
      case 'car_wash':
        return const _CarWashLoadingWidget();
      case 'maintenance':
        return const _MaintenanceLoadingWidget();
      case 'maid':
        return const _MaidLoadingWidget();
      default:
        return const SizedBox(
          height: 120,
          width: 120,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        );
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
                // Location Picker (not required for maid service)
                if (widget.serviceType != 'maid') ...[
                  const SizedBox(height: 24),
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
                ] else if (widget.serviceType == 'maid') ...[
                  // Address description for maid (optional)
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _addressController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'وصف الموقع (اختياري)',
                      hintText: 'أدخل وصفاً للموقع',
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
                  // عرض سعر العاملة
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
                          '55000 د.ع',
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
                  onPressed: _isLoading 
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

// Widget تحميل خاص للبنزين مع قطرة متحركة
class _FuelLoadingWidget extends StatefulWidget {
  const _FuelLoadingWidget();

  @override
  State<_FuelLoadingWidget> createState() => _FuelLoadingWidgetState();
}

class _FuelLoadingWidgetState extends State<_FuelLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _dropController;
  late AnimationController _pumpController;
  late Animation<double> _dropAnimation;
  late Animation<double> _pumpAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation للقطرة (تخرج من فم أداة التعبئة وتسقط للأسفل)
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _dropAnimation = Tween<double>(
      begin: 0,
      end: 50,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.easeIn,
    ));
    
    // Animation لحركة المضخة (اهتزاز خفيف)
    _pumpController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _pumpAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _pumpController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _dropController.dispose();
    _pumpController.dispose();
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
          // الصورة المتحركة (اهتزاز خفيف)
          AnimatedBuilder(
            animation: _pumpAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _pumpAnimation.value,
                child: Image.asset(
                  'assets/images/fuelLoud.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          
          // قطرة متحركة (تخرج من فم أداة التعبئة وتسقط للأسفل)
          Positioned(
            top: 55, // موضع فم أداة التعبئة تقريباً
            right: 20, // أقرب إلى اليسار (اليمين في RTL)
            child: AnimatedBuilder(
              animation: _dropAnimation,
              builder: (context, child) {
                // إخفاء القطرة عند بداية الحركة (0) وإظهارها تدريجياً
                final opacity = _dropController.value < 0.1 
                    ? _dropController.value * 10 
                    : (_dropController.value > 0.9 
                        ? (1 - _dropController.value) * 10 
                        : 1.0);
                
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _dropAnimation.value),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withOpacity(0.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
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

// Widget تحميل خاص لطوارئ السيارات
class _CarEmergencyLoadingWidget extends StatefulWidget {
  const _CarEmergencyLoadingWidget();

  @override
  State<_CarEmergencyLoadingWidget> createState() => _CarEmergencyLoadingWidgetState();
}

class _CarEmergencyLoadingWidgetState extends State<_CarEmergencyLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _sparkController;
  late Animation<double> _animation;
  late Animation<double> _sparkAnimation;

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
    
    // Animation للشرارة (تظهر وتختفي)
    _sparkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _sparkAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _sparkController.dispose();
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
                    'assets/images/carEloud.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // شرارة متحركة (تظهر وتختفي)
          Positioned(
            top: 20,
            right: 20,
            child: AnimatedBuilder(
              animation: _sparkAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _sparkAnimation.value,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(_sparkAnimation.value * 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
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

// Widget تحميل خاص لغسيل السيارات
class _CarWashLoadingWidget extends StatefulWidget {
  const _CarWashLoadingWidget();

  @override
  State<_CarWashLoadingWidget> createState() => _CarWashLoadingWidgetState();
}

class _CarWashLoadingWidgetState extends State<_CarWashLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _carController;
  late AnimationController _waterController;
  late AnimationController _scaleController;
  late Animation<double> _carAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Animation للصورة (تتحرك يمين ويسار)
    _carController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _carAnimation = Tween<double>(
      begin: -15,
      end: 15,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: Curves.easeInOut,
    ));
    
    // Animation للفقاعات (تظهر وتختفي)
    _waterController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    // Animation للتكبير والتصغير (لجعل الصورة أكثر حيوية)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _carController.dispose();
    _waterController.dispose();
    _scaleController.dispose();
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
          // صورة غسيل السيارات مع أنيميشن (حركة + تكبير/تصغير)
          AnimatedBuilder(
            animation: Listenable.merge([_carAnimation, _scaleAnimation]),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_carAnimation.value, 0),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Image.asset(
                    'assets/images/woshingloud.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // فقاعات صغيرة (تظهر وتختفي)
          ...List.generate(6, (index) {
            final delay = index * 0.15;
            final angle = (index * 60) * (math.pi / 180);
            return Positioned(
              top: 60 + (math.sin(angle) * 30),
              left: 50 + (math.cos(angle) * 30),
              child: AnimatedBuilder(
                animation: _waterController,
                builder: (context, child) {
                  final adjustedValue = (_waterController.value + delay) % 1.0;
                  final opacity = adjustedValue < 0.5 
                      ? (adjustedValue * 2) 
                      : (2 - adjustedValue * 2);
                  final scale = 0.3 + (adjustedValue * 0.7);
                  
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Widget تحميل خاص للصيانة
class _MaintenanceLoadingWidget extends StatefulWidget {
  const _MaintenanceLoadingWidget();

  @override
  State<_MaintenanceLoadingWidget> createState() => _MaintenanceLoadingWidgetState();
}

class _MaintenanceLoadingWidgetState extends State<_MaintenanceLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _toolController;
  late Animation<double> _animation;
  late Animation<double> _toolAnimation;

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
    
    // Animation للأدوات (تظهر وتختفي)
    _toolController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _toolAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toolController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _toolController.dispose();
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
                    'assets/images/carEloud.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // أدوات متحركة (تظهر وتختفي)
          Positioned(
            top: 15,
            left: 15,
            child: AnimatedBuilder(
              animation: _toolAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _toolAnimation.value,
                  child: Transform.rotate(
                    angle: _toolController.value * 2 * math.pi * 0.2,
                    child: const Icon(
                      Icons.build,
                      size: 24,
                      color: AppTheme.primaryColor,
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

// Widget تحميل خاص للعمال
class _MaidLoadingWidget extends StatefulWidget {
  const _MaidLoadingWidget();

  @override
  State<_MaidLoadingWidget> createState() => _MaidLoadingWidgetState();
}

class _MaidLoadingWidgetState extends State<_MaidLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _sparkleController;
  late Animation<double> _animation;
  late Animation<double> _sparkleAnimation;

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
    
    // Animation للنجوم/اللمعان (تظهر وتختفي)
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    _sparkleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _sparkleController.dispose();
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
                    'assets/images/wokerloud.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // نجوم/لمعان متحركة (تظهر حول الصورة)
          ...List.generate(4, (index) {
            final delay = index * 0.25;
            final angle = (index * 90) * (math.pi / 180);
            return Positioned(
              top: 40 + (math.sin(angle) * 40),
              left: 40 + (math.cos(angle) * 40),
              child: AnimatedBuilder(
                animation: _sparkleAnimation,
                builder: (context, child) {
                  final adjustedValue = (_sparkleAnimation.value + delay) % 1.0;
                  final opacity = adjustedValue < 0.5 
                      ? (adjustedValue * 2) 
                      : (2 - adjustedValue * 2);
                  
                  return Opacity(
                    opacity: opacity,
                    child: const Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

