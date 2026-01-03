import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/storage/secure_storage_service.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await SecureStorageService.getBool('notifications_enabled') ?? true;
    final darkMode = await SecureStorageService.getBool('dark_mode_enabled') ?? false;
    
    setState(() {
      _notificationsEnabled = notifications;
      _darkModeEnabled = darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Notifications
            Card(
              child: SwitchListTile(
                title: const Text('الإشعارات'),
                subtitle: const Text('تفعيل أو إلغاء الإشعارات'),
                value: _notificationsEnabled,
                onChanged: (value) async {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  await SecureStorageService.setBool('notifications_enabled', value);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            // Dark Mode
            Card(
              child: SwitchListTile(
                title: const Text('الوضع الليلي'),
                subtitle: const Text('تفعيل الوضع الليلي'),
                value: _darkModeEnabled,
                onChanged: (value) async {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  await SecureStorageService.setBool('dark_mode_enabled', value);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            // Change Password
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.lock_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('تغيير كلمة المرور'),
                subtitle: const Text('تغيير كلمة المرور الخاصة بك'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  context.push('/profile/change-password');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}









