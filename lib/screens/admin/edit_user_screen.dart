import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/admin_service.dart';
import '../../models/driver.dart';

class EditUserScreen extends StatefulWidget {
  final Driver driver;

  const EditUserScreen({
    super.key,
    required this.driver,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehicleNumberController;
  
  bool _isLoading = false;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver.name);
    _phoneController = TextEditingController(text: widget.driver.phone);
    _codeController = TextEditingController(text: widget.driver.code);
    _vehicleTypeController = TextEditingController(text: widget.driver.vehicleType ?? '');
    _vehicleNumberController = TextEditingController(text: widget.driver.vehicleNumber ?? '');
    _isAvailable = widget.driver.isAvailable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final updatedDriver = Driver(
          id: widget.driver.id,
          driverId: widget.driver.driverId, // إضافة driverId المطلوب
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          serviceType: widget.driver.serviceType,
          vehicleType: _vehicleTypeController.text.trim().isEmpty 
              ? null 
              : _vehicleTypeController.text.trim(),
          vehicleNumber: (widget.driver.serviceType == 'taxi' || widget.driver.serviceType == 'crane')
              ? (_vehicleNumberController.text.trim().isEmpty 
                  ? null 
                  : _vehicleNumberController.text.trim())
              : null,
          isAvailable: _isAvailable,
          currentLatitude: widget.driver.currentLatitude,
          currentLongitude: widget.driver.currentLongitude,
          image: widget.driver.image,
        );

        // تمرير الرمز الأصلي للمقارنة
        final originalCode = widget.driver.code;
        final success = await _adminService.updateDriver(updatedDriver, originalCode: originalCode);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث المعلومات بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تحديث المعلومات'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
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
      case 'car_wash':
        return 'غسيل سيارات';
      default:
        return serviceType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('تعديل معلومات المستخدم'),
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
                // معلومات الحساب (غير قابلة للتعديل)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات الحساب',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('المعرف', widget.driver.driverId),
                      _buildInfoRow('نوع الحساب', _getServiceTypeName(widget.driver.serviceType)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // الحقول القابلة للتعديل
                CustomTextField(
                  label: 'الاسم *',
                  hint: 'أدخل الاسم',
                  controller: _nameController,
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
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رقم الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'الرمز *',
                  hint: 'أدخل الرمز الجديد',
                  controller: _codeController,
                  obscureText: true,
                  prefixIcon: Icons.lock_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الرمز';
                    }
                    return null;
                  },
                ),
                if (widget.driver.serviceType != 'car_emergency' && 
                    widget.driver.serviceType != 'fuel' && 
                    widget.driver.serviceType != 'maid' &&
                    widget.driver.serviceType != 'car_wash') ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'نوع المركبة',
                    hint: 'مثال: سيارة، دراجة نارية',
                    controller: _vehicleTypeController,
                    prefixIcon: Icons.directions_car_rounded,
                  ),
                ],
                if (widget.driver.serviceType == 'taxi' || widget.driver.serviceType == 'crane') ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'رقم المركبة',
                    hint: 'مثال: بغداد 1234',
                    controller: _vehicleNumberController,
                    prefixIcon: Icons.confirmation_number_rounded,
                  ),
                ],
                const SizedBox(height: 24),
                // حالة الحساب
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'حالة الحساب',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'حفظ التغييرات',
                  onPressed: _handleUpdate,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
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

