import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../services/storage_service.dart';
import '../../services/card_service.dart';
import '../../core/storage/secure_storage_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _cardService = CardService();
  String? _userName;
  String? _userPhone;
  String? _userAddress;
  int _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _userName = StorageService.getString('user_name') ?? 'المستخدم';
      _userPhone = StorageService.getString('user_phone') ?? '';
      _userAddress = StorageService.getString('user_address') ?? '';
    });
    await _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final userPhone = await SecureStorageService.getString('user_phone');
      if (userPhone != null) {
        final balance = await _cardService.getUserWalletBalance(userPhone);
        if (mounted) {
          setState(() {
            _walletBalance = balance;
          });
        }
      }
    } catch (e) {
      // Error loading wallet balance
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName ?? 'المستخدم',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_userPhone != null && _userPhone!.isNotEmpty)
                            Text(
                              _userPhone!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          if (_userAddress != null && _userAddress!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _userAddress!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    // Wallet Balance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'رصيد المحفظة',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_walletBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} دينار',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: 'معلوماتي',
                      onTap: () async {
                        final result = await context.push('/profile/edit');
                        if (result == true || result == null) {
                          // إعادة تحميل المعلومات بعد التعديل
                          await _loadUserInfo();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'طلباتي',
                      onTap: () {
                        context.push('/orders/history');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'عناويني',
                      onTap: () {
                        context.push('/profile/addresses');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.credit_card_rounded,
                      title: 'استخدام بطاقة مالية',
                      onTap: () async {
                        final result = await context.push('/profile/redeem-card');
                        if (result == true) {
                          await _loadWalletBalance();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.favorite_outline_rounded,
                      title: 'المفضلة',
                      onTap: () {
                        // يمكن إضافة شاشة المفضلة لاحقاً
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('قريباً: شاشة المفضلة'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'الإعدادات',
                      onTap: () {
                        context.push('/profile/settings');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'المساعدة والدعم',
                      onTap: () {
                        context.push('/profile/help');
                      },
                    ),
                    const SizedBox(height: 24),
                    // زر تسجيل الخروج
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.red.withOpacity(0.1),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تسجيل الخروج'),
                              content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('تسجيل الخروج'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            // حذف حالة تسجيل الدخول والبيانات المحفوظة
                            await StorageService.remove('user_logged_in');
                            await StorageService.remove('user_name');
                            await StorageService.remove('user_phone');
                            context.go('/phone-check');
                          }
                        },
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
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}


