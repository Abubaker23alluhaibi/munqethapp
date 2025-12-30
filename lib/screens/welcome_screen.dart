import 'dart:async';
import 'dart:math';
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
  Timer? _textRotationTimer;
  int _currentTextIndex = 0;
  final Random _random = Random();
  
  // الجمل العامة
  final List<String> _generalTexts = [
    'كل خدماتك اليومية… بتطبيق واحد',
    'لا تتعب نفسك، اطلب وخلي الباقي علينا',
    'خدمات سريعة، أمان عالي، وأسعار تناسبك',
    'كل شي تحتاجه يوصل لبابك',
    'من البيت… لكل مكان',
  ];
  
  // جمل التكسي والنقل
  final List<String> _taxiTexts = [
    'مشوارك علينا، راحتك علينا أكثر',
    'تكسي آمن وسريع بأي وقت',
    'ودّع الانتظار… وصل بسرعة',
    'مشاوير داخل وخارج المدينة',
  ];
  
  // جمل البنزين وخدمات السيارات
  final List<String> _gasTexts = [
    'نفد البنزين؟ إحنا نوصله لك',
    'سيارتك تعطلت؟ نوصلك الحل',
    'بنزين، تصليح، كرين… وإنت مرتاح',
    'خدمات سيارات طوارئ 24/7',
  ];
  
  // جمل التصليح والكرين
  final List<String> _repairTexts = [
    'عطل مفاجئ؟ نوصلك أقرب فني',
    'كرين جاهز بأي وقت وأي مكان',
    'تصليح سريع بدون تعب',
    'خدمة طوارئ للسيارات بكل المناطق',
  ];
  
  // جمل السوبر ماركت والتوصيل
  final List<String> _supermarketTexts = [
    'تسوقك اليومي يوصل لبابك',
    'سوبر ماركت كامل بضغطة زر',
    'لا تطلع من البيت… كل شي عندك',
    'طلبك يوصل بسرعة وبأمان',
  ];
  
  // جمل العاملات والخدمات المنزلية
  final List<String> _maidTexts = [
    'عاملات موثوقات بخدمة سريعة',
    'خدمات منزلية حسب وقتك',
    'نظافة، ترتيب، وخدمة مضمونة',
  ];
  
  List<String> _rotatingTexts = [];

  @override
  void initState() {
    super.initState();
    
    // تهيئة الجمل مباشرة قبل أي شيء آخر
    _selectRandomTexts();
    
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
    
    // بدء التناوب بين الجمل كل 3 ثواني
    _textRotationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _rotatingTexts.isNotEmpty) {
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % _rotatingTexts.length;
        });
      }
    });
    
    // تحميل حالة تسجيل الدخول في الخلفية بعد عرض الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToLogin();
    });
  }
  
  void _selectRandomTexts() {
    // اختيار جملة عامة عشوائية
    final generalText = _generalTexts[_random.nextInt(_generalTexts.length)];
    
    // اختيار خدمة عشوائية وجملة منها
    final serviceTypes = [
      _taxiTexts,
      _gasTexts,
      _repairTexts,
      _supermarketTexts,
      _maidTexts,
    ];
    
    final selectedService = serviceTypes[_random.nextInt(serviceTypes.length)];
    final serviceText = selectedService[_random.nextInt(selectedService.length)];
    
    // تعيين الجملتين للتناوب
    _rotatingTexts = [generalText, serviceText];
    _currentTextIndex = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _carAnimationController.dispose();
    _textRotationTimer?.cancel();
    super.dispose();
  }

  _navigateToLogin() async {
    if (!mounted) return;
    
    // تحميل حالة تسجيل الدخول في الخلفية بدون تأخير عرض الصفحة
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // تحميل حالة تسجيل الدخول بشكل متوازي مع عرض الشاشة
    authProvider.loadSavedAuth().catchError((error) {
      // في حالة وجود خطأ، نستمر في الانتظار
    });
    
    // الانتظار 5 ثواني دائماً قبل الانتقال للصفحة التالية
    await Future.delayed(const Duration(seconds: 5));
    
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
    context.go('/phone-check');
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
                  const SizedBox(height: 20),
                  // النص الترحيبي مع animation
                  const Text(
                    'المنقذ',
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
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 600.ms, curve: Curves.easeOut),
                  const SizedBox(height: 20),
                  // الجمل المتناوبة
                  _rotatingTexts.isNotEmpty
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.3),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _rotatingTexts[_currentTextIndex],
                            key: ValueKey<int>(_currentTextIndex),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        )
                      : const SizedBox.shrink(),
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

