import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../config/theme.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../utils/phone_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  bool _isLoading = false;
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  Future<void> _loadUserInfo() async {
    final userName = StorageService.getString('user_name') ?? '';
    final userPhone = StorageService.getString('user_phone') ?? '';
    final userAddress = StorageService.getString('user_address') ?? '';
    
    setState(() {
      _nameController.text = userName;
      _phoneController.text = userPhone;
      _addressController.text = userAddress;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final name = _nameController.text.trim();
        final phone = _phoneController.text.trim();
        final address = _addressController.text.trim();
        final normalizedPhone = PhoneUtils.normalizePhone(phone);
        
        // التحقق من صحة الرقم (عراقي أو تركي)
        if (!PhoneUtils.isValidPhone(phone)) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء إدخال رقم هاتف عراقي صحيح'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        // الحصول على المستخدم الحالي
        final currentPhone = StorageService.getString('user_phone') ?? '';
        final currentNormalizedPhone = PhoneUtils.normalizePhone(currentPhone);
        
        // تحديث بيانات المستخدم الحالي في قاعدة البيانات
        final currentUser = await _userService.getUserByPhone(currentNormalizedPhone);
        if (currentUser != null) {
          // تحديث المستخدم عبر API
          final updatedUser = await _userService.updateUser(currentUser.id,
            name: name,
            phone: normalizedPhone,
            address: address,
          );
          if (updatedUser == null) {
            // إذا فشل التحديث، عرض رسالة خطأ
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل تحديث البيانات. يرجى المحاولة مرة أخرى'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            return;
          }
        } else {
          // إذا لم يكن موجود، عرض رسالة خطأ
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('المستخدم غير موجود. يرجى تسجيل الدخول أولاً'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        // حفظ البيانات في التخزين المحلي
        await StorageService.setString('user_name', name);
        await StorageService.setString('user_phone', normalizedPhone);
        await StorageService.setString('user_address', address);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ المعلومات بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.pop(true); // إرجاع true للإشارة إلى أن البيانات تم تحديثها
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المعلومات الشخصية'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.lightPrimary,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // حقل الاسم
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'الاسم',
                      hintText: 'أدخل اسمك',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال الاسم';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 20),
                  // حقل رقم الهاتف
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: 'أدخل رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال رقم الهاتف';
                      }
                      if (!PhoneUtils.isValidPhone(value)) {
                        return 'الرجاء إدخال رقم هاتف صحيح (عراقي أو تركي)';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _addressFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 20),
                  // حقل العنوان (اختياري)
                  TextFormField(
                    controller: _addressController,
                    focusNode: _addressFocusNode,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'العنوان (اختياري)',
                      hintText: 'أدخل عنوانك',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // زر الحفظ
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
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
                            'حفظ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}





