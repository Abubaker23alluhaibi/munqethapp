import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _adminService = AdminService();
  final _commissionController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
    _loadSettings();
  }

  Future<void> _checkPermission() async {
    final admin = await _adminService.getCurrentAdmin();
    if (admin != null && !admin.permissions.canAccessSettings && !admin.isSuperAdmin) {
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية الدخول لهذه الصفحة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _adminService.getSettings();
      final pct = settings['commissionPercentage'] ?? 10.0;
      if (mounted) {
        _commissionController.text = (pct is num) ? pct.toStringAsFixed(0) : '10';
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _commissionController.text = '10';
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    final pctStr = _commissionController.text.trim();
    if (pctStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل نسبة العمولة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final pct = double.tryParse(pctStr);
    if (pct == null || pct < 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نسبة العمولة يجب أن تكون بين 0 و 100'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _adminService.updateSettings(commissionPercentage: pct);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إعدادات النظام'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'نسبة الأرباح (العمولة)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'هذه النسبة تُستخدم في لوحة التحكم لحساب إحصائيات العمولات من الطلبات المكتملة.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'نسبة العمولة (%)',
                      hint: 'مثال: 10',
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      prefixIcon: Icons.percent_rounded,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخل النسبة';
                        final n = double.tryParse(v);
                        if (n == null || n < 0 || n > 100) return 'النسبة بين 0 و 100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'حفظ الإعدادات',
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
