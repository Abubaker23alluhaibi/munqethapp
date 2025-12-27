import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/admin_service.dart';
import '../../models/supermarket.dart';
import '../../models/driver.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  
  String _selectedType = 'supermarket'; // 'supermarket', 'delivery', 'taxi', 'car_emergency', 'crane', 'fuel', 'maid', 'car_wash'
  
  // Supermarket fields
  final _smIdController = TextEditingController();
  final _smCodeController = TextEditingController();
  final _smNameController = TextEditingController();
  final _smAddressController = TextEditingController();
  
  // Driver fields
  final _driverIdController = TextEditingController();
  final _driverCodeController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _driverVehicleTypeController = TextEditingController();
  final _driverVehicleNumberController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _smIdController.dispose();
    _smCodeController.dispose();
    _smNameController.dispose();
    _smAddressController.dispose();
    _driverIdController.dispose();
    _driverCodeController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverVehicleTypeController.dispose();
    _driverVehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        bool success = false;
        
        if (_selectedType == 'supermarket') {
          final supermarket = Supermarket(
            id: _smIdController.text.trim().toUpperCase(),
            code: _smCodeController.text.trim(),
            name: _smNameController.text.trim(),
            address: _smAddressController.text.trim().isEmpty 
                ? null 
                : _smAddressController.text.trim(),
            phone: null,
            email: null,
          );
          success = await _adminService.addSupermarket(supermarket);
        } else {
          final driver = Driver(
            id: '', // سيتم توليده من الـ backend
            driverId: _driverIdController.text.trim().toUpperCase(), // المعرف المخصص
            code: _driverCodeController.text.trim(),
            name: _driverNameController.text.trim(),
            phone: _driverPhoneController.text.trim(),
            serviceType: _selectedType,
            vehicleType: _driverVehicleTypeController.text.trim().isEmpty 
                ? null 
                : _driverVehicleTypeController.text.trim(),
            vehicleNumber: _selectedType == 'taxi' 
                ? (_driverVehicleNumberController.text.trim().isEmpty 
                    ? null 
                    : _driverVehicleNumberController.text.trim())
                : null,
            isAvailable: true,
          );
          
          // إرسال طلب إنشاء السائق والحصول على النتيجة
          final result = await _adminService.addDriver(driver);
          
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء الحساب بنجاح'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            _clearForm();
          } else {
            // عرض رسالة الخطأ الواضحة
            final errorMessage = result['error'] ?? 'فشل إنشاء الحساب';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
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
  }

  void _clearForm() {
    _smIdController.clear();
    _smCodeController.clear();
    _smNameController.clear();
    _smAddressController.clear();
    _driverIdController.clear();
    _driverCodeController.clear();
    _driverNameController.clear();
    _driverPhoneController.clear();
    _driverVehicleTypeController.clear();
    _driverVehicleNumberController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إنشاء حساب جديد'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اختر نوع الحساب',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildTypeSelector(),
                const SizedBox(height: 32),
                if (_selectedType == 'supermarket') ...[
                  _buildSupermarketForm(),
                ] else ...[
                  _buildDriverForm(),
                ],
                const SizedBox(height: 32),
                CustomButton(
                  text: 'إنشاء الحساب',
                  onPressed: _handleCreate,
                  isLoading: _isLoading,
                  backgroundColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      {'value': 'supermarket', 'label': 'سوبر ماركت'},
      {'value': 'delivery', 'label': 'ديلفري'},
      {'value': 'taxi', 'label': 'تكسي'},
      {'value': 'car_emergency', 'label': 'سيارات الطوارئ'},
      {'value': 'crane', 'label': 'كرين طوارئ'},
      {'value': 'fuel', 'label': 'خدمة بنزين'},
      {'value': 'maid', 'label': 'تأجير عاملة'},
      {'value': 'car_wash', 'label': 'غسيل سيارات'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: _selectedType,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade600),
        items: types.map((type) {
          return DropdownMenuItem<String>(
            value: type['value'] as String,
            child: Text(
              type['label'] as String,
              style: TextStyle(
                color: _selectedType == type['value'] 
                    ? AppTheme.primaryColor 
                    : Colors.grey.shade700,
                fontWeight: _selectedType == type['value'] 
                    ? FontWeight.bold 
                    : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedType = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildSupermarketForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          label: 'الـ ID *',
          hint: 'مثال: SM002',
          controller: _smIdController,
          prefixIcon: Icons.badge_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الـ ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'الرمز *',
          hint: 'أدخل الرمز',
          controller: _smCodeController,
          obscureText: true,
          prefixIcon: Icons.lock_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الرمز';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'اسم السوبر ماركت *',
          hint: 'أدخل الاسم',
          controller: _smNameController,
          prefixIcon: Icons.store_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الاسم';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'العنوان',
          hint: 'أدخل العنوان (اختياري)',
          controller: _smAddressController,
          prefixIcon: Icons.location_on_rounded,
        ),
      ],
    );
  }

  Widget _buildDriverForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          label: 'الـ ID *',
          hint: _selectedType == 'delivery' 
              ? 'مثال: DEL005' 
              : _selectedType == 'taxi'
                  ? 'مثال: TAXI005'
                  : _selectedType == 'car_emergency'
                      ? 'مثال: EMERG005'
                      : _selectedType == 'crane'
                          ? 'مثال: CRANE005'
                          : _selectedType == 'fuel'
                              ? 'مثال: FUEL005'
                              : _selectedType == 'maid'
                                  ? 'مثال: MAID005'
                                  : 'مثال: WASH005',
          controller: _driverIdController,
          prefixIcon: Icons.badge_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الـ ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'الرمز *',
          hint: 'أدخل الرمز',
          controller: _driverCodeController,
          obscureText: true,
          prefixIcon: Icons.lock_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الرمز';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'الاسم *',
          hint: 'أدخل الاسم',
          controller: _driverNameController,
          prefixIcon: Icons.person_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال الاسم';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'رقم الهاتف *',
          hint: 'أدخل رقم الهاتف',
          controller: _driverPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال رقم الهاتف';
            }
            return null;
          },
        ),
        if (_selectedType != 'car_emergency' && _selectedType != 'fuel' && _selectedType != 'maid' && _selectedType != 'car_wash') ...[
          const SizedBox(height: 16),
          CustomTextField(
            label: 'نوع المركبة',
            hint: 'مثال: سيارة، دراجة نارية',
            controller: _driverVehicleTypeController,
            prefixIcon: Icons.directions_car_rounded,
          ),
        ],
        if (_selectedType == 'taxi' || _selectedType == 'crane') ...[
          const SizedBox(height: 16),
          CustomTextField(
            label: 'رقم المركبة',
            hint: 'مثال: بغداد 1234',
            controller: _driverVehicleNumberController,
            prefixIcon: Icons.confirmation_number_rounded,
          ),
        ],
      ],
    );
  }
}



