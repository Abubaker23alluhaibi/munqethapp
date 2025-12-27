import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/supermarket.dart';
import '../../services/supermarket_service.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _codeController = TextEditingController();
  final _supermarketService = SupermarketService();
  final _adminService = AdminService();

  Supermarket? _supermarket;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isAdminLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadData();
  }

  Future<void> _checkAdminStatus() async {
    final isAdminLoggedIn = await _adminService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isAdminLoggedIn = isAdminLoggedIn;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final supermarket = await _supermarketService.getCurrentSupermarket();
    if (supermarket == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    setState(() {
      _supermarket = supermarket;
      _idController.text = supermarket.id;
      _codeController.text = supermarket.code;
      _isInitialized = true;
    });
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate() && _supermarket != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newId = _idController.text.trim();
        final newCode = _codeController.text.trim();

        // التحقق من أن القيم قد تغيرت
        if (newId == _supermarket!.id && newCode == _supermarket!.code) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم تغيير أي شيء'),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          }
          return;
        }

        // التحقق من أن الـ ID والـ Code غير فارغين
        if (newId.isEmpty || newCode.isEmpty) {
          throw 'الـ ID والرمز مطلوبان';
        }

        // تحديث البيانات
        final success = await _supermarketService.updateCredentials(newId, newCode);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديث الـ ID والرمز بنجاح'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            // إعادة تحميل البيانات
            await _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل تحديث البيانات'),
                backgroundColor: AppTheme.errorColor,
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          leading: _isAdminLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    context.go('/admin/dashboard');
                  },
                  tooltip: 'العودة إلى لوحة تحكم الأدمن',
                )
              : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'معلومات السوبر ماركت',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        if (_supermarket != null) ...[
                          const SizedBox(height: 16),
                          _buildInfoRow('الاسم', _supermarket!.name),
                          if (_supermarket!.address != null)
                            _buildInfoRow('العنوان', _supermarket!.address!),
                          if (_supermarket!.phone != null)
                            _buildInfoRow('الهاتف', _supermarket!.phone!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'تغيير الـ ID والرمز',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك تغيير الـ ID والرمز الخاص بك هنا',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // ID Field
                CustomTextField(
                  label: 'الـ ID',
                  hint: 'أدخل الـ ID الجديد',
                  controller: _idController,
                  keyboardType: TextInputType.text,
                  prefixIcon: Icons.badge_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الـ ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Code Field
                CustomTextField(
                  label: 'الرمز',
                  hint: 'أدخل الرمز الجديد',
                  controller: _codeController,
                  keyboardType: TextInputType.text,
                  obscureText: true,
                  prefixIcon: Icons.lock_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الرمز';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Warning Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warningColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تأكد من حفظ الـ ID والرمز الجديد في مكان آمن. ستحتاج إليهما لتسجيل الدخول في المرة القادمة.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.warningColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Save Button
                CustomButton(
                  text: 'حفظ التغييرات',
                  onPressed: _handleSave,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                // Current Values Display
                Card(
                  color: AppTheme.lightPrimary,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'القيم الحالية',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (_supermarket != null) ...[
                          _buildCurrentValueRow('الـ ID الحالي', _supermarket!.id),
                          _buildCurrentValueRow('الرمز الحالي', '••••'),
                        ],
                      ],
                    ),
                  ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
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

  Widget _buildCurrentValueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
        ],
      ),
    );
  }
}

