import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../config/theme.dart';
import '../../widgets/animated_button.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import 'dart:math';
import '../../providers/auth_provider.dart';
import '../../core/errors/app_exception.dart';
import 'package:provider/provider.dart';
import '../../utils/phone_utils.dart';

class SignupScreen extends StatefulWidget {
  final String phone;

  const SignupScreen({
    super.key,
    required this.phone,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  final _userService = UserService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showVerificationScreen = false;
  String? _verificationCode;
  final _verificationCodeController = TextEditingController();
  final _verificationCodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // تعيين الرقم في حقل الهاتف
    _phoneController.text = widget.phone;
    // Focus على حقل الاسم عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _nameFocusNode.dispose();
    _addressFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
    super.dispose();
  }

  // توليد رمز تأكيد عشوائي
  String _generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString(); // رقم من 4 أرقام
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // توحيد الرقم (عراقي أو تركي)
        final normalizedPhone = PhoneUtils.normalizePhone(_phoneController.text.trim());
        final name = _nameController.text.trim();
        final address = _addressController.text.trim();
        final password = _passwordController.text.trim();

        // حفظ بيانات المستخدم في قاعدة البيانات
        final userAdded = await _userService.addUser(
          name: name,
          phone: normalizedPhone,
          password: password,
          address: address,
        );

        if (userAdded == null) {
          // فشل الاتصال بالسيرفر
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد اتصال بالسيرفر. يرجى التحقق من اتصالك'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        if (!mounted) return;

        // توليد رمز تأكيد عشوائي
        _verificationCode = _generateVerificationCode();
        
        // حفظ بيانات المستخدم مؤقتاً
        await StorageService.setString('user_name_temp', name);
        await StorageService.setString('user_phone_temp', normalizedPhone);
        await StorageService.setString('user_address_temp', address);
        await StorageService.setString('user_password_temp', password);

        setState(() {
          _isLoading = false;
          _showVerificationScreen = true;
        });

        // عرض رمز التأكيد للمستخدم (مؤقتاً)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رمز التأكيد: $_verificationCode'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 10),
          ),
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          _verificationCodeFocusNode.requestFocus();
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // التحقق من نوع الخطأ
          String errorMessage;
          if (e is AppException) {
            if (e.type == AppExceptionType.validation && 
                (e.message.contains('مسجل') || e.message.contains('already exists'))) {
              errorMessage = 'هذا الرقم مسجل بالفعل';
            } else if (e.type == AppExceptionType.network) {
              errorMessage = 'لا يوجد اتصال بالسيرفر. يرجى التحقق من اتصالك';
            } else {
              errorMessage = e.message;
            }
          } else {
            errorMessage = 'حدث خطأ: $e';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  /// التحقق من رمز التأكيد وإكمال تسجيل الدخول
  Future<void> _verifyCodeAndCompleteSignup() async {
    if (_verificationCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رمز التأكيد'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_verificationCodeController.text.trim() != _verificationCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز التأكيد غير صحيح'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // استرجاع البيانات المؤقتة
      final name = await StorageService.getString('user_name_temp') ?? 'مستخدم';
      final phone = await StorageService.getString('user_phone_temp') ?? '';
      final address = await StorageService.getString('user_address_temp') ?? 'غير محدد';

      // حفظ بيانات المستخدم في التخزين المحلي
      await StorageService.setString('user_name', name);
      await StorageService.setString('user_phone', phone);
      await StorageService.setString('user_address', address);
      await StorageService.setBool('user_logged_in', true);

      // مسح البيانات المؤقتة
      await StorageService.remove('user_name_temp');
      await StorageService.remove('user_phone_temp');
      await StorageService.remove('user_address_temp');
      await StorageService.remove('user_password_temp');

      // تسجيل الدخول عبر AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loginAsUser(phone, '');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الحساب وتسجيل الدخول بنجاح'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.go('/main');
      }
    } catch (e) {
      if (!mounted) return;
      
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white.withOpacity(0.3),
          selectionHandleColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // خلفية متدرجة فاخرة
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                    AppTheme.accentColor,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // دوائر ديكورية ثابتة
            StaticCirclesBackground(
              color: AppTheme.primaryColor,
            ),
            // المحتوى الرئيسي
            SafeArea(
              child: Form(
                key: _formKey,
                child: _showVerificationScreen ? _buildVerificationScreen() : _buildSignupContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // الشعار
            Hero(
              tag: 'logo',
              child: Container(
                width: 200,
                height: 140,
                margin: const EdgeInsets.only(bottom: 40),
                child: Image.asset(
                  'assets/icons/logo2.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .scale(delay: 50.ms, duration: 500.ms, curve: Curves.easeOut),
            // عنوان فاخر
            Text(
              'إنشاء حساب جديد',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textDirection: TextDirection.rtl,
            )
                .animate()
                .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                .scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),
            Text(
              'أدخل بياناتك لإكمال التسجيل',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w300,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              textDirection: TextDirection.rtl,
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 500.ms),
            const SizedBox(height: 60),
            // حقل الاسم
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'الاسم',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الاسم';
                }
                return null;
              },
              onFieldSubmitted: (_) => _addressFocusNode.requestFocus(),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms),
            const SizedBox(height: 20),
            // حقل العنوان
            TextFormField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 2,
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'العنوان',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال العنوان';
                }
                return null;
              },
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 600.ms, duration: 600.ms),
            const SizedBox(height: 20),
            // حقل كلمة المرور
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'كلمة المرور',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال كلمة المرور';
                }
                if (value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
              onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 700.ms, duration: 600.ms),
            const SizedBox(height: 20),
            // حقل تأكيد كلمة المرور
            TextFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              obscureText: _obscureConfirmPassword,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'تأكيد كلمة المرور',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء تأكيد كلمة المرور';
                }
                if (value != _passwordController.text) {
                  return 'كلمة المرور غير متطابقة';
                }
                return null;
              },
            )
                .animate()
                .fadeIn(delay: 750.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 750.ms, duration: 600.ms),
            const SizedBox(height: 20),
            // حقل الرقم (معطل للقراءة فقط)
            TextFormField(
              controller: _phoneController,
              enabled: false,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 800.ms, duration: 600.ms),
            const SizedBox(height: 40),
            // زر إنشاء الحساب
            AnimatedButton(
              text: 'إنشاء الحساب',
              onPressed: _isLoading ? null : _handleSignup,
              isLoading: _isLoading,
              height: 60,
            )
                .animate()
                .fadeIn(delay: 900.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 900.ms, duration: 500.ms)
                .scale(delay: 1000.ms, duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // زر العودة
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _showVerificationScreen = false;
                  });
                },
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.2, end: 0, duration: 300.ms),
            ),
            const SizedBox(height: 20),
            // الشعار
            Hero(
              tag: 'logo',
              child: Container(
                width: 180,
                height: 120,
                margin: const EdgeInsets.only(bottom: 30),
                child: Image.asset(
                  'assets/icons/logo2.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .scale(delay: 50.ms, duration: 500.ms, curve: Curves.easeOut),
            // عنوان
            Text(
              'تحقق من رقم هاتفك',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textDirection: TextDirection.rtl,
            )
                .animate()
                .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                .scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),
            Text(
              'أدخل رمز التحقق المرسل إلى ${_phoneController.text}',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w300,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 500.ms),
            const SizedBox(height: 80),
            // حقل إدخال رمز التأكيد
            TextFormField(
              controller: _verificationCodeController,
              focusNode: _verificationCodeFocusNode,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'أدخل رمز التأكيد',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms),
            const SizedBox(height: 30),
            // زر التحقق
            AnimatedButton(
              text: 'تحقق',
              onPressed: _isLoading ? null : _verifyCodeAndCompleteSignup,
              isLoading: _isLoading,
              height: 60,
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 700.ms, duration: 500.ms),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// Widget للدوائر الديكورية الثابتة
class StaticCirclesBackground extends StatelessWidget {
  final Color color;

  const StaticCirclesBackground({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final random = math.Random(42); // seed ثابت للحصول على نفس المواضع

    return CustomPaint(
      painter: StaticCirclesPainter(
        color: color,
        random: random,
        screenSize: screenSize,
      ),
      size: screenSize,
    );
  }
}

class StaticCirclesPainter extends CustomPainter {
  final Color color;
  final math.Random random;
  final Size screenSize;

  StaticCirclesPainter({
    required this.color,
    required this.random,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    // إنشاء دوائر ثابتة عشوائية على الأطراف
    for (int i = 0; i < 12; i++) {
      final circleSize = 30.0 + random.nextDouble() * 80;
      final opacity = 0.1 + random.nextDouble() * 0.3;

      double x, y;

      // تحديد موضع الدائرة على الأطراف (ثابت)
      final side = random.nextInt(4);
      switch (side) {
        case 0: // أعلى
          x = random.nextDouble() * size.width;
          y = -circleSize / 2 + circleSize * 0.3;
          break;
        case 1: // يمين
          x = size.width + circleSize / 2 - circleSize * 0.3;
          y = random.nextDouble() * size.height;
          break;
        case 2: // أسفل
          x = random.nextDouble() * size.width;
          y = size.height + circleSize / 2 - circleSize * 0.3;
          break;
        default: // يسار
          x = -circleSize / 2 + circleSize * 0.3;
          y = random.nextDouble() * size.height;
          break;
      }

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(
        Offset(x, y),
        circleSize / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StaticCirclesPainter oldDelegate) {
    return false; // لا حاجة لإعادة الرسم لأن الدوائر ثابتة
  }
}






