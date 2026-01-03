import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../widgets/animated_button.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../utils/phone_utils.dart';

class LoginScreen extends StatefulWidget {
  final String initialId;
  
  const LoginScreen({super.key, this.initialId = ''});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _codeController = TextEditingController();
  final _idFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  bool _obscureCode = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  int _currentStep = 1; // 1 للرقم، 2 للرمز
  bool _idEntered = false;
  bool _isPhoneNumber = false; // true = رقم هاتف (password), false = إيدي (كود يدوي)
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    // إذا كان هناك إيدي أولي من صفحة التحقق، نضعه في الحقل
    if (widget.initialId.isNotEmpty) {
      _idController.text = widget.initialId;
      // التحقق إذا كان رقم هاتف أم إيدي (عراقي أو تركي)
      // إزالة + من الرقم للتحقق
      final cleanedId = widget.initialId.replaceAll('+', '').replaceAll(' ', '');
      _isPhoneNumber = RegExp(r'^[0-9]+$').hasMatch(cleanedId) && 
                      PhoneUtils.isValidPhone(widget.initialId);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isPhoneNumber) {
          // إذا كان رقم هاتف، تحقق من وجود المستخدم أولاً
          _checkUserExistsAndNavigate(widget.initialId);
        } else {
          // إذا كان إيدي، انتقل لصفحة الكود
          _moveToCodeStep();
        }
      });
    } else {
      // تحميل حالة تذكرني والبيانات المحفوظة
      _loadSavedCredentials();
      // Focus على حقل الرقم عند فتح الشاشة
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _idFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await SecureStorageService.getBool('remember_me') ?? false;
    if (rememberMe) {
      final savedId = await SecureStorageService.getString('saved_user_id');
      final savedCode = await SecureStorageService.getString('saved_user_code');
      if (savedId != null && savedCode != null) {
        setState(() {
          _rememberMe = true;
          _idController.text = savedId;
          _codeController.text = savedCode;
        });
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _codeController.dispose();
    _idFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _moveToCodeStep() {
    if (_idController.text.trim().isNotEmpty) {
      // التحقق إذا كان رقم هاتف أم إيدي (عراقي أو تركي)
      final input = _idController.text.trim();
      // إزالة + من الرقم للتحقق
      final cleanedInput = input.replaceAll('+', '').replaceAll(' ', '');
      _isPhoneNumber = RegExp(r'^[0-9]+$').hasMatch(cleanedInput) && 
                      PhoneUtils.isValidPhone(input);
      
      setState(() {
        _currentStep = 2;
        _idEntered = true;
      });
      
      // إذا كان رقم هاتف، انتقل لصفحة الباسورد مباشرة
      if (_isPhoneNumber) {
        // لا حاجة لإرسال OTP، فقط انتقل للخطوة التالية
        Future.delayed(const Duration(milliseconds: 300), () {
          _codeFocusNode.requestFocus();
        });
      } else {
        // إذا كان إيدي، فقط انتقل لصفحة الكود
        Future.delayed(const Duration(milliseconds: 300), () {
          _codeFocusNode.requestFocus();
        });
      }
    }
  }

  void _moveBackToIdStep() {
    setState(() {
      _currentStep = 1;
      _codeController.clear(); // مسح حقل الباسورد/الكود
      _idEntered = false; // إعادة تعيين حالة إدخال الرقم
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _idFocusNode.requestFocus();
    });
  }

  /// التحقق من وجود المستخدم ونقله للصفحة المناسبة
  Future<void> _checkUserExistsAndNavigate(String phone) async {
    try {
      final userExists = await _userService.userExistsByPhone(phone);
      if (!mounted) return;
      
      if (!userExists) {
        // إذا كان المستخدم غير موجود، انقله لصفحة إنشاء الحساب
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحساب غير موجود، سيتم نقلك لصفحة إنشاء الحساب'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/signup?phone=${Uri.encodeComponent(phone)}');
        }
        return;
      }
      
      // إذا كان المستخدم موجود، انتقل لصفحة الباسورد
      _moveToCodeStep();
    } catch (e) {
      // في حالة فشل التحقق، افترض أن المستخدم موجود وانتقل لصفحة الباسورد
      if (mounted) {
        _moveToCodeStep();
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final id = _idController.text.trim();
      final code = _codeController.text.trim();

      setState(() {
        _isLoading = true;
      });

      try {
        // إذا كان رقم هاتف، استخدم password
        if (_isPhoneNumber) {
          // التحقق من وجود المستخدم أولاً قبل محاولة تسجيل الدخول
          final userExists = await _userService.userExistsByPhone(id);
          if (!userExists) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الحساب غير موجود، الرجاء إنشاء حساب جديد'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 3),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              context.go('/signup?phone=${Uri.encodeComponent(id)}');
            }
            return;
          }
          
          // تسجيل الدخول بالباسورد مباشرة بدون طلب رمز التأكيد
          await _loginWithPassword(id, authProvider);
          return;
        }

        // إذا كان إيدي، استخدم الكود اليدوي (للسائقين/الأدمن/السوبر ماركت)
        final cleanId = id.trim().toUpperCase();
        
        // محاولة تسجيل الدخول كمدير أولاً (الأولوية للادمن)
        final adminSuccess = await authProvider.loginAsAdmin(cleanId, code);
        if (adminSuccess && mounted) {
          await _saveCredentials(cleanId, code);
          context.go('/admin/dashboard');
          return;
        }

        // إذا كان ID يبدأ بـ ADMIN، لا نحاول supermarket أو driver
        if (cleanId.startsWith('ADMIN')) {
          if (mounted) {
            ErrorHandler.showErrorSnackBar(
              context,
              null,
              customMessage: 'رقم المستخدم أو الكود غير صحيح',
            );
          }
          return;
        }

        // محاولة تسجيل الدخول كسوبر ماركت
        final supermarketSuccess = await authProvider.loginAsSupermarket(cleanId, code);
        if (supermarketSuccess && mounted) {
          await _saveCredentials(cleanId, code);
          context.go('/supermarket/dashboard');
          return;
        }

        // محاولة تسجيل الدخول كسائق
        final driverSuccess = await authProvider.loginAsDriver(cleanId, code);
        if (driverSuccess && mounted) {
          await _saveCredentials(cleanId, code);
          context.go('/driver/dashboard');
          return;
        }

        // إذا فشل كل شيء
        if (mounted) {
          ErrorHandler.showErrorSnackBar(
            context,
            null,
            customMessage: 'رقم المستخدم أو الكود غير صحيح',
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// تسجيل الدخول بالباسورد مباشرة بدون طلب رمز التأكيد
  Future<void> _loginWithPassword(String phone, AuthProvider authProvider) async {
    final password = _codeController.text.trim();
    
    if (!mounted) return;
    
    // التحقق من أن الباسورد ليس فارغاً
    if (password.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال كلمة المرور'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    try {
      // التحقق من وجود المستخدم أولاً
      final userExists = await _userService.userExistsByPhone(phone);
      if (!userExists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحساب غير موجود، الرجاء إنشاء حساب جديد'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/signup?phone=${Uri.encodeComponent(phone)}');
        }
        return;
      }
      
      // التحقق من الباسورد
      final user = await _userService.authenticateUser(phone, password);
      
      if (user == null) {
        // الباسورد خاطئ أو المستخدم غير موجود
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور غير صحيحة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      if (!mounted) return;
      
      // تسجيل الدخول مباشرة بدون طلب رمز التأكيد
      final userSuccess = await authProvider.loginAsUser(phone, '');
      
      if (!userSuccess) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'حدث خطأ أثناء تسجيل الدخول'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      if (!mounted) return;
      
      await _saveCredentials(phone, ''); // لا نحفظ الباسورد
      context.go('/main');
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
      if (e.toString().contains('Invalid phone or password') || 
          e.toString().contains('غير صحيحة')) {
        errorMessage = 'كلمة المرور غير صحيحة';
      } else if (e.toString().contains('User not found') || 
                 e.toString().contains('غير موجود')) {
        errorMessage = 'الحساب غير موجود، الرجاء إنشاء حساب جديد';
        // نقل لصفحة إنشاء الحساب
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/signup?phone=${Uri.encodeComponent(phone)}');
          return;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _saveCredentials(String id, String code) async {
    if (_rememberMe) {
      await SecureStorageService.setString('saved_user_id', id);
      await SecureStorageService.setString('saved_user_code', code);
      await SecureStorageService.setBool('remember_me', true);
    } else {
      await SecureStorageService.remove('saved_user_id');
      await SecureStorageService.remove('saved_user_code');
      await SecureStorageService.setBool('remember_me', false);
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
                child: _currentStep == 1 ? _buildIdScreen() : _buildCodeScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdScreen() {
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
            // رسالة ترحيب فاخرة
            Text(
              'مرحباً بك',
              style: TextStyle(
                fontSize: 48,
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
              'أدخل رقمك',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w300,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              textDirection: TextDirection.rtl,
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 500.ms),
            const SizedBox(height: 8),
            // جملة جميلة عن خدمات المنقذ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'خدمات متنوعة في متناول يدك ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                  fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 600.ms),
            ),
            const SizedBox(height: 60),
            // حقل إدخال الرقم بصندوق أبيض بسيط
            TextFormField(
              controller: _idController,
              focusNode: _idFocusNode,
              keyboardType: TextInputType.text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLength: 50, // زيادة الحد الأقصى للسماح بإدخال IDs أطول
              cursorColor: Colors.black,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'أدخل الرقم',
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
                counterText: '', // إخفاء عداد الأحرف
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الرقم';
                }
                return null;
              },
              onFieldSubmitted: (_) => _moveToCodeStep(),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms),
            const SizedBox(height: 40),
            // زر التالي
            AnimatedButton(
              text: 'التالي',
              onPressed: _moveToCodeStep,
              height: 56,
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

  Widget _buildCodeScreen() {
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
                onPressed: _moveBackToIdStep,
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
            // عنوان فاخر للرمز
            Text(
              'أدخل الرمز',
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
                .scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOut)
                .shimmer(
                  delay: 400.ms,
                  duration: 1000.ms,
                  color: Colors.white.withOpacity(0.3),
                ),
            const SizedBox(height: 12),
            Text(
              _isPhoneNumber ? 'أدخل كلمة المرور' : 'أدخل رمزك السري',
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
            const SizedBox(height: 80),
            // حقل إدخال الرمز بصندوق أبيض بسيط
            TextFormField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              obscureText: _isPhoneNumber ? _obscureCode : _obscureCode, // الباسورد يخفي
              keyboardType: TextInputType.text,
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
                hintText: _isPhoneNumber ? 'أدخل كلمة المرور' : 'أدخل الرمز',
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
                          _obscureCode
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCode = !_obscureCode;
                          });
                        },
                      ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الرمز';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms)
                .shimmer(
                  delay: 800.ms,
                  duration: 1500.ms,
                  color: Colors.white.withOpacity(0.2),
                ),
            const SizedBox(height: 30),
            // خيار تذكرني (فقط للإيديهات)
            if (!_isPhoneNumber)
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    activeColor: Colors.white,
                    checkColor: AppTheme.primaryColor,
                  ),
                  Text(
                    'تذكرني',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 500.ms),
            const SizedBox(height: 20),
            // زر تسجيل الدخول
            AnimatedButton(
              text: 'تسجيل الدخول',
              onPressed: _isLoading ? null : _handleLogin,
              isLoading: _isLoading,
              height: 60,
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 700.ms, duration: 500.ms)
                .scale(delay: 900.ms, duration: 400.ms, curve: Curves.elasticOut),
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
