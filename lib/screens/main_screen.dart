import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../config/theme.dart';
import '../widgets/shimmer_widget.dart';
import '../models/advertisement.dart';
import '../services/advertisement_service.dart';
import '../services/storage_service.dart';
import '../services/local_notification_service.dart';
import '../services/socket_service.dart';
import '../core/utils/app_logger.dart';
import 'shopping/shopping_screen.dart';
import 'services/services_screen.dart';
import 'taxi/taxi_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _notificationService = LocalNotificationService();
  final _socketService = SocketService();

  final List<Widget> _screens = [
    const HomeContent(),
    const ShoppingScreen(),
    const ServicesScreen(),
    const TaxiScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // SocketService يتعامل مع الإشعارات تلقائياً
    _ensureSocketConnected();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _ensureSocketConnected() {
    // التأكد من اتصال Socket.IO
    if (!_socketService.isConnected) {
      _socketService.connect();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // دالة مساعدة لبناء لوجو - مستطيل وأطول
  Widget _buildTabIcon(String logoPath, bool isSelected) {
    final color = isSelected ? AppTheme.primaryColor : Colors.grey[600];
    return Container(
      width: 60,
      height: 30,
      alignment: Alignment.center,
      child: Image.asset(
        logoPath,
        width: 60,
        height: 30,
        filterQuality: FilterQuality.high,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcATop,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.error_outline,
          size: 30,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 32,
          elevation: 8,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'التسوق',
            ),
            BottomNavigationBarItem(
              icon: _buildTabIcon('assets/icons/logoservise.png', false),
              activeIcon: _buildTabIcon('assets/icons/logoservise.png', true),
              label: 'الخدمات',
            ),
            const BottomNavigationBarItem(
              icon: SizedBox.shrink(),
              activeIcon: SizedBox.shrink(),
              label: 'تاكسي',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'الملف الشخصي',
            ),
          ],
        ),
      ),
    );
  }
}

// محتوى الشاشة الرئيسية
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int _currentCarouselIndex = 0;
  final _advertisementService = AdvertisementService();
  
  List<Advertisement> _advertisements = [];
  bool _isLoadingAds = true;

  @override
  void initState() {
    super.initState();
    _loadAdvertisements();
  }

  Future<void> _loadAdvertisements() async {
    setState(() {
      _isLoadingAds = true;
    });

    try {
      // تحميل جميع الإعلانات النشطة
      final allAds = await _advertisementService.getActiveAdvertisements();
      
      // إعلانات الماركات (جميع الإعلانات مع صورة)
      _advertisements = allAds.where((ad) => ad.imageUrl != null).toList();
    } catch (e) {
      // في حالة الخطأ، نستخدم البيانات الثابتة كبديل
      _advertisements = [];
    }

    if (mounted) {
      setState(() {
        _isLoadingAds = false;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
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

    if (confirm == true && mounted) {
      // حذف حالة تسجيل الدخول والبيانات المحفوظة
      await StorageService.remove('user_logged_in');
      await StorageService.remove('user_name');
      await StorageService.remove('user_phone');
      context.go('/phone-check');
    }
  }

  // بطاقات الخدمات
  final List<Map<String, dynamic>> services = const [
    {
      'image': 'assets/images/shoping.png',
      'logo': 'assets/icons/logoshoping.png',
      'index': 1,
      'name': 'تسوق',
      'comingSoon': false,
    },
    {
      'image': 'assets/images/services.png',
      'logo': 'assets/icons/logoservise.png',
      'index': 2,
      'name': 'خدمات',
      'comingSoon': false,
    },
    {
      'image': 'assets/images/taxi.png',
      'logo': 'assets/icons/logo2.png',
      'index': 3,
      'name': 'تكسي',
      'comingSoon': false,
    },
    {
      'image': 'assets/images/restaurant.png',
      'logo': null,
      'index': -1, // لن يكون له تبويب
      'name': 'مطاعم',
      'comingSoon': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // ارتفاع قسم الإعلانات - أكثر استجابة للموبايل
    final adsSectionHeight = isMobile 
        ? screenHeight * 0.35  // 35% للموبايل
        : screenHeight * 0.45;  // 45% للشاشات الكبيرة
    
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
              // قسم الإعلانات
              Container(
                height: adsSectionHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16.0 : 20.0,
                  vertical: isMobile ? 8.0 : 10.0,
                ),
                child: _buildAdsCarousel(),
              ),
              // قسم الخدمات أسفل الإعلانات
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                  child: _buildServicesAdsGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdsCarousel() {
    if (_isLoadingAds) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_advertisements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('لا توجد إعلانات متاحة'),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CarouselSlider.builder(
            itemCount: _advertisements.length,
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1.0,
              autoPlay: _advertisements.length > 1,
              autoPlayInterval: const Duration(seconds: 3),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: false,
              scrollDirection: Axis.horizontal,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
            ),
            itemBuilder: (context, index, realIndex) {
              final ad = _advertisements[index];
              return _buildAdvertisementCard(ad);
            },
          ),
        ),
        if (_advertisements.length > 1) ...[
          const SizedBox(height: 12),
          // مؤشرات الصفحات
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _advertisements.asMap().entries.map((entry) {
              final isActive = _currentCarouselIndex == entry.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvertisementCard(Advertisement ad) {
    String getServiceTypeName(String serviceType) {
      switch (serviceType) {
        case 'delivery':
          return 'توصيل';
        case 'taxi':
          return 'تكسي';
        case 'maintenance':
          return 'صيانة';
        case 'all':
          return 'جميع الخدمات';
        default:
          return serviceType;
      }
    }

    Color getServiceTypeColor(String serviceType) {
      switch (serviceType) {
        case 'delivery':
          return Colors.orange;
        case 'taxi':
          return Colors.yellow.shade700;
        case 'maintenance':
          return Colors.green.shade600;
        case 'all':
          return AppTheme.primaryColor;
        default:
          return Colors.grey;
      }
    }

    final serviceColor = getServiceTypeColor(ad.serviceType);
    final serviceName = getServiceTypeName(ad.serviceType);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // الصورة - عالية الجودة
            ad.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: ad.imageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    memCacheWidth: (MediaQuery.of(context).size.width * 2).toInt(),
                    memCacheHeight: (MediaQuery.of(context).size.height * 0.7).toInt(),
                    placeholder: (context, url) => const ShimmerImage(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: serviceColor.withOpacity(0.1),
                      child: Icon(Icons.campaign_rounded, color: serviceColor, size: 64),
                    ),
                  )
                : Container(
                    color: serviceColor.withOpacity(0.1),
                    child: Icon(Icons.campaign_rounded, color: serviceColor, size: 64),
                  ),
            // طبقة متدرجة
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            // المحتوى
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge نوع الخدمة
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: serviceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: serviceColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          serviceName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // عنوان الإعلان
                      Text(
                        ad.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      if (ad.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          ad.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (ad.hasDiscount) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'خصم ${ad.discountPercentage}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesAdsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Column(
      children: [
        // الصف الأول - صورتان (تسوق، خدمات)
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildServiceSquare(
                  context,
                  service: services[0],
                  delay: 200.ms,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: _buildServiceSquare(
                  context,
                  service: services[1],
                  delay: 300.ms,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        // الصف الثاني - تكسي (كامل العرض)
        Expanded(
          child: _buildServiceSquare(
            context,
            service: services[2],
            delay: 400.ms,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        // الصف الثالث - مطاعم (كامل العرض، ارتفاع أقل)
        SizedBox(
          height: isMobile ? 80 : 100, // ارتفاع أقل
          child: _buildServiceSquare(
            context,
            service: services[3],
            delay: 500.ms,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSquare(
    BuildContext context, {
    required Map<String, dynamic> service,
    required Duration delay,
  }) {
    final index = service['index'] as int;
    final imagePath = service['image'] as String;
    final logoPath = service['logo'] as String?;
    final serviceName = service['name'] as String;
    final comingSoon = service['comingSoon'] as bool? ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isRestaurant = serviceName == 'مطاعم';
    
    return InkWell(
      onTap: comingSoon
          ? null // تعطيل النقر إذا كانت قريباً
          : () {
              // التنقل عبر Bottom Navigation
              final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
              if (mainScreenState != null) {
                mainScreenState.setState(() {
                  mainScreenState._currentIndex = index;
                });
              }
            },
      borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      child: Column(
        mainAxisSize: isRestaurant ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Expanded(
            flex: isRestaurant ? 1 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // الصورة في الخلفية - عالية الجودة
                    Image.asset(
                      imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade100,
                              Colors.orange.shade300,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.orange.shade700,
                          size: isMobile ? (isRestaurant ? 40 : 60) : (isRestaurant ? 50 : 72),
                        ),
                      ),
                    ),
                    // طبقة قاتمة إذا كانت قريباً
                    if (comingSoon)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                        ),
                      ),
                    // شارة "قريباً"
                    if (comingSoon)
                      Positioned(
                        top: isMobile ? (isRestaurant ? 6 : 8) : (isRestaurant ? 8 : 12),
                        right: isMobile ? (isRestaurant ? 6 : 8) : (isRestaurant ? 8 : 12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? (isRestaurant ? 8 : 10) : (isRestaurant ? 10 : 12),
                            vertical: isMobile ? (isRestaurant ? 3 : 4) : (isRestaurant ? 4 : 6),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(isMobile ? (isRestaurant ? 10 : 12) : (isRestaurant ? 12 : 16)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'قريباً',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? (isRestaurant ? 10 : 11) : (isRestaurant ? 11 : 12),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: isRestaurant ? 4 : 8),
          // اسم القسم باللون الفيروزي
          Text(
            serviceName,
            style: TextStyle(
              fontSize: isMobile ? (isRestaurant ? 14 : 16) : (isRestaurant ? 16 : 18),
              fontWeight: FontWeight.bold,
              color: comingSoon 
                  ? Colors.grey.shade600
                  : AppTheme.primaryColor,
              letterSpacing: 0.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 600.ms)
        .slideY(begin: 0.2, end: 0, delay: delay, duration: 600.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), delay: delay, duration: 600.ms, curve: Curves.easeOut);
  }

}
