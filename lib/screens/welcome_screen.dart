import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _carAnimationController;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Animation للعربة - تتحرك من اليسار إلى اليمين
    _carAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    
    _carAnimation = Tween<double>(
      begin: 0.0, // من 0 (اليسار)
      end: 1.0,    // إلى 1 (اليمين)
    ).animate(CurvedAnimation(
      parent: _carAnimationController,
      curve: Curves.linear,
    ));
    
    // تحميل حالة تسجيل الدخول فوراً بدون انتظار
    _navigateToLogin();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _carAnimationController.dispose();
    super.dispose();
  }

  _navigateToLogin() async {
    // تحميل حالة تسجيل الدخول فوراً بدون انتظار
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // تحميل حالة تسجيل الدخول بشكل متوازي مع عرض الشاشة
    await authProvider.loadSavedAuth();
    
    if (!mounted) return;
    
    // التحقق من نوع المستخدم والانتقال للشاشة المناسبة
    if (authProvider.isAdminLoggedIn) {
      context.go('/admin/dashboard');
      return;
    }
    
    if (authProvider.isSupermarketLoggedIn) {
      context.go('/supermarket/dashboard');
      return;
    }
    
    if (authProvider.isDriverLoggedIn) {
      context.go('/driver/dashboard');
      return;
    }
    
    if (authProvider.isUserLoggedIn) {
      context.go('/main');
      return;
    }
    
    // إذا لم يكن هناك تسجيل دخول، انتقل إلى صفحة فحص رقم الهاتف
    // إضافة تأخير قصير فقط لعرض الشاشة الترحيبية (1 ثانية بدلاً من 3)
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      context.go('/phone-check');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Stack(
          children: [
            // خلفية زخرفية متحركة
            ...List.generate(5, (index) {
              return Positioned(
                left: (index * 80.0) % MediaQuery.of(context).size.width,
                top: (index * 100.0) % MediaQuery.of(context).size.height,
                child: Container(
                  width: 100 + (index * 20),
                  height: 100 + (index * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: Duration(seconds: 2 + index), delay: Duration(milliseconds: index * 200))
                  .fadeIn(duration: Duration(milliseconds: 1000 + index * 200));
            }),
            // المحتوى الرئيسي
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار مع حركة العربة من اليسار إلى اليمين
                  AnimatedBuilder(
                    animation: _carAnimation,
                    builder: (context, child) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      // حساب الموضع: من خارج الشاشة على اليسار (-200) إلى خارج الشاشة على اليمين (screenWidth + 200)
                      final position = -200 + (_carAnimation.value * (screenWidth + 400));
                      return Transform.translate(
                        offset: Offset(position, 0),
                        child: Hero(
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
                          )
                              .animate()
                              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                              .scale(delay: 50.ms, duration: 500.ms, curve: Curves.easeOut),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // النص الترحيبي مع animation
                  const Text(
                    'أهلاً بك في',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                    textDirection: TextDirection.rtl,
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 600.ms, curve: Curves.easeOut),
                  const SizedBox(height: 8),
                  const Text(
                    'تطبيق المنقذ',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    textDirection: TextDirection.rtl,
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, delay: 600.ms, duration: 600.ms, curve: Curves.easeOut),
                  const SizedBox(height: 60),
                  // مؤشر التحميل محسن
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(delay: 800.ms, duration: 1000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), curve: Curves.easeInOut)
                      .fadeIn(delay: 800.ms, duration: 500.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

