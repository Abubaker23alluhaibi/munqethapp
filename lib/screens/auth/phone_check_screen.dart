import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../config/theme.dart';
import '../../widgets/animated_button.dart';
import '../../services/driver_service.dart';
import '../../services/user_service.dart';
import '../../services/admin_service.dart';
import '../../services/storage_service.dart';
import '../../utils/phone_utils.dart';

class PhoneCheckScreen extends StatefulWidget {
  const PhoneCheckScreen({super.key});

  @override
  State<PhoneCheckScreen> createState() => _PhoneCheckScreenState();
}

class _PhoneCheckScreenState extends State<PhoneCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  final _driverService = DriverService();
  final _userService = UserService();
  final _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    // Focus على حقل الرقم عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkPhone() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final input = _phoneController.text.trim();
        
        // التحقق إذا كان المدخل يبدو كإيدي (يحتوي على أحرف) أم رقم هاتف (أرقام فقط)
        final isLikelyId = RegExp(r'[A-Za-z]').hasMatch(input);
        
        // إذا كان يبدو كإيدي (يحتوي على أحرف)، نفحص إذا كان موظف (سائق) أو أدمن
        if (isLikelyId) {
          // نفحص إذا كان موظف (سائق)
          final driver = await _driverService.findDriverById(input);
          
          if (!mounted) return;

          if (driver != null) {
            // إذا كان موظف، انقله لصفحة إدخال الرمز مع الإيدي
            setState(() {
              _isLoading = false;
            });
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              context.go('/login?id=${Uri.encodeComponent(input)}');
            }
            return;
          }

          // نفحص إذا كان أدمن
          final isAdmin = await _adminService.adminExistsById(input);
          
          if (!mounted) return;

          if (isAdmin) {
            // إذا كان أدمن، انقله لصفحة تسجيل الدخول العادية مع الإيدي (ستتحقق من نوع الحساب تلقائياً)
            setState(() {
              _isLoading = false;
            });
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              context.go('/login?id=${Uri.encodeComponent(input)}');
            }
            return;
          }

          // إذا كان إيدي ولكن غير مسجل (لا سائق ولا أدمن) → يظهر خطأ
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الإيدي غير مسجل في النظام'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        // إذا لم يكن موظف أو كان رقم هاتف، نتعامل معه كرقم هاتف (عراقي أو تركي)
        final normalizedPhone = PhoneUtils.normalizePhone(input);
        
        // التحقق من صحة الرقم (إذا كان يبدو كرقم هاتف وليس إيدي) - عراقي أو تركي
        if (!isLikelyId && !PhoneUtils.isValidPhone(input)) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرجاء إدخال رقم هاتف صحيح '),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }

        // التحقق إذا كان المستخدم موجود (منشأ حساب) في قاعدة البيانات
        try {
          final userExists = await _userService.userExistsByPhone(normalizedPhone);

          // طباعة للتحقق (يمكن حذفها لاحقاً)
          print('Phone: $normalizedPhone, User exists: $userExists');

          setState(() {
            _isLoading = false;
          });

          // المنطق الصحيح:
          // - إذا كان المستخدم موجود في قاعدة البيانات → صفحة إدخال الرمز (/login)
          // - إذا لم يكن موجود → صفحة إنشاء الحساب (/signup)
          if (userExists) {
            // المستخدم موجود في قاعدة البيانات (منشأ حساب) - انقله لصفحة إدخال الرمز مع الرقم
            print('Navigating to /login - user exists');
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              context.go('/login?id=${Uri.encodeComponent(normalizedPhone)}');
            }
          } else {
            // المستخدم غير موجود - انقله لصفحة إنشاء الحساب
            print('Navigating to /signup - user does not exist');
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              context.go('/signup?phone=${Uri.encodeComponent(normalizedPhone)}');
            }
          }
        } catch (e) {
          // في حالة فشل الاتصال، نعتبر أن المستخدم غير موجود وننتقل لصفحة signup
          // لكن نعرض رسالة تحذيرية
          setState(() {
            _isLoading = false;
          });
          
          print('Error checking user exists: $e');
          print('Navigating to /signup - connection error, assuming user does not exist');
          
          // عرض رسالة تحذيرية
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد اتصال بالسيرفر. سيتم إنشاء حساب محلي'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            context.go('/signup?phone=${Uri.encodeComponent(normalizedPhone)}');
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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
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
              'أدخل رقم الهاتف ',
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
            const SizedBox(height: 80),
            // حقل إدخال الرقم
            TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.text, // تغيير من phone إلى text للسماح بإدخال أحرف (للإيديهات)
              maxLength: 50, // زيادة الحد الأقصى للسماح بإدخال IDs أطول
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
                hintText: 'أدخل رقم الهاتف   ',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
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
                  return 'الرجاء إدخال رقم الهاتف ';
                }
                // التحقق من صحة الرقم (إذا كان رقم هاتف وليس إيدي)
                // الإيدي قد يكون نصاً، لذا نتحقق فقط إذا بدا كرقم هاتف
                if (RegExp(r'^[0-9+\s\-\(\)]+$').hasMatch(value) && !PhoneUtils.isValidPhone(value)) {
                  // إذا كان يحتوي على أرقام فقط ولكن ليس رقم هاتف صحيح
                  if (value.length > 5) { // إذا كان طويلاً، قد يكون رقم هاتف غير صحيح
                    return 'الرجاء إدخال رقم هاتف صحيح';
                  }
                }
                return null;
              },
              onFieldSubmitted: (_) => _checkPhone(),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms),
            const SizedBox(height: 40),
            // زر التالي
            AnimatedButton(
              text: 'التالي',
              onPressed: _isLoading ? null : _checkPhone,
              isLoading: _isLoading,
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






