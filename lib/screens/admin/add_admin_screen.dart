import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  Map<String, bool> _permissions = {
    'dashboard': true,
    'usersManagement': true,
    'createAccount': true,
    'advertisements': true,
    'cards': true,
    'settings': true,
    'manageLocations': true,
    'changePassword': true,
    'addAdmins': false,
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
  }

  Future<void> _checkPermission() async {
    final admin = await _adminService.getCurrentAdmin();
    final canAdd = admin != null && (admin.isSuperAdmin || admin.permissions.canAddAdmins);
    if (!canAdd && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ليس لديك صلاحية إضافة أدمن'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await _adminService.addAdmin(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        password: _passwordController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        permissions: _permissions,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الأدمن بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'فشل الإضافة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const List<Map<String, String>> _permissionLabels = [
    {'key': 'dashboard', 'label': 'لوحة التحكم'},
    {'key': 'usersManagement', 'label': 'إدارة المستخدمين'},
    {'key': 'createAccount', 'label': 'إنشاء حساب (سوبر ماركت/سائق)'},
    {'key': 'advertisements', 'label': 'الإعلانات والتنزيلات'},
    {'key': 'cards', 'label': 'البطاقات المالية'},
    {'key': 'settings', 'label': 'إعدادات النظام (نسبة الأرباح)'},
    {'key': 'manageLocations', 'label': 'مواقع السوبر ماركت'},
    {'key': 'changePassword', 'label': 'تغيير كلمة المرور'},
    {'key': 'addAdmins', 'label': 'إضافة أدمن آخر'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إضافة أدمن'),
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
                CustomTextField(
                  label: 'الكود (للدخول) *',
                  hint: 'مثال: ADMIN02',
                  controller: _codeController,
                  prefixIcon: Icons.badge_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'أدخل الكود' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'الاسم *',
                  hint: 'اسم الأدمن',
                  controller: _nameController,
                  prefixIcon: Icons.person_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'كلمة المرور *',
                  hint: '6 أحرف على الأقل',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                    if (v.length < 6) return '6 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'البريد (اختياري)',
                  hint: 'email@example.com',
                  controller: _emailController,
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'الهاتف (اختياري)',
                  hint: '07xxxxxxxxx',
                  controller: _phoneController,
                  prefixIcon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                Text(
                  'الصلاحيات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ..._permissionLabels.map((e) {
                  final key = e['key']!;
                  return CheckboxListTile(
                    value: _permissions[key] ?? false,
                    onChanged: (val) => setState(() => _permissions[key] = val ?? false),
                    title: Text(e['label']!),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primaryColor,
                  );
                }),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'إضافة الأدمن',
                  onPressed: _isLoading ? null : _submit,
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
}
