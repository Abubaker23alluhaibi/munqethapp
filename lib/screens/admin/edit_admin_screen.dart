import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/admin.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditAdminScreen extends StatefulWidget {
  final Admin admin;

  const EditAdminScreen({super.key, required this.admin});

  @override
  State<EditAdminScreen> createState() => _EditAdminScreenState();
}

class _EditAdminScreenState extends State<EditAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late Map<String, bool> _permissions;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin.name);
    _emailController = TextEditingController(text: widget.admin.email ?? '');
    _phoneController = TextEditingController(text: widget.admin.phone ?? '');
    _permissions = {
      'dashboard': widget.admin.permissions.dashboard,
      'usersManagement': widget.admin.permissions.usersManagement,
      'createAccount': widget.admin.permissions.createAccount,
      'advertisements': widget.admin.permissions.advertisements,
      'cards': widget.admin.permissions.cards,
      'settings': widget.admin.permissions.settings,
      'manageLocations': widget.admin.permissions.manageLocations,
      'changePassword': widget.admin.permissions.changePassword,
      'addAdmins': widget.admin.permissions.addAdmins,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _adminService.updateAdmin(
        widget.admin.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        permissions: _permissions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text('تعديل: ${widget.admin.code}'),
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
                  label: 'الاسم *',
                  hint: 'اسم الأدمن',
                  controller: _nameController,
                  prefixIcon: Icons.person_rounded,
                  validator: (v) => v == null || v.isEmpty ? 'أدخل الاسم' : null,
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
                const SizedBox(height: 8),
                Text(
                  'الكود: ${widget.admin.code}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                  final isSuperAdmin = widget.admin.isSuperAdmin;
                  final isAddAdmins = key == 'addAdmins';
                  return CheckboxListTile(
                    value: _permissions[key] ?? false,
                    onChanged: (val) {
                      if (isAddAdmins && isSuperAdmin) return;
                      setState(() => _permissions[key] = val ?? false);
                    },
                    title: Text(e['label']!),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primaryColor,
                    subtitle: isAddAdmins && isSuperAdmin
                        ? Text('الأدمن الرئيسي يملكها دائماً', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                        : null,
                  );
                }),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'حفظ التعديلات',
                  onPressed: _isLoading ? null : _save,
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
