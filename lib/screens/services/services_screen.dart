import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  final List<Map<String, dynamic>> services = const [
    {
      'title': 'طوارئ سيارات',
      'description': 'خدمة طوارئ سريعة للسيارات',
      'imagePath': 'assets/images/carEmergemcy.png',
      'route': '/services/service-request?type=car_emergency',
    },
    {
      'title': 'كرين طوارئ',
      'description': 'خدمة كرين لنقل المركبات',
      'imagePath': 'assets/images/crane.png',
      'route': '/taxi/order?serviceType=crane',
    },
    {
      'title': 'خدمة بنزين',
      'description': 'توصيل بنزين إلى موقعك',
      'imagePath': 'assets/images/fuel.png',
      'route': '/services/service-request?type=fuel',
    },
    {
      'title': 'تأجير عاملة',
      'description': 'خدمات تنظيف وترتيب ورعاية',
      'imagePath': 'assets/images/worker.png',
      'route': '/services/service-request?type=maid',
    },
    {
      'title': 'غسيل سيارات',
      'description': 'خدمة غسيل سيارات احترافية',
      'imagePath': 'assets/images/carwosh.png',
      'route': '/services/service-request?type=car_wash',
    },
    {
      'title': 'توصيل',
      'description': 'قريباً',
      'imagePath': null,
      'route': null,
      'isComingSoon': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          toolbarHeight: 60,
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icons/logoservise.png',
                    fit: BoxFit.contain,
                    width: 35,
                    height: 35,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.build_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'الخدمات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                // الصف الأول - صورتان مربعتان
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[0],
                          isMobile: isMobile,
                          delay: 200.ms,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[1],
                          isMobile: isMobile,
                          delay: 300.ms,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // الصف الثاني - صورتان مربعتان
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[2],
                          isMobile: isMobile,
                          delay: 400.ms,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[3],
                          isMobile: isMobile,
                          delay: 500.ms,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // الصف الثالث - صورتان (غسيل سيارات وتوصيل)
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[4],
                          isMobile: isMobile,
                          delay: 600.ms,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _buildServiceSquare(
                          context,
                          service: services[5],
                          isMobile: isMobile,
                          delay: 700.ms,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSquare(
    BuildContext context, {
    required Map<String, dynamic> service,
    required bool isMobile,
    required Duration delay,
  }) {
    final title = service['title'] as String;
    final imagePath = service['imagePath'] as String?;
    final route = service['route'] as String?;
    final isComingSoon = service['isComingSoon'] as bool? ?? false;
    final isMaid = title == 'تأجير عاملة';
    final isCarWash = title == 'غسيل سيارات';
    final isDelivery = title == 'توصيل';
    
    return InkWell(
      onTap: isComingSoon ? null : () {
        if (route != null) {
          context.push(route);
        }
      },
      borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      child: Column(
        children: [
          Expanded(
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
                    // الصورة في الخلفية مع إطار
                    Container(
                      color: AppTheme.backgroundColor,
                      child: imagePath != null
                          ? Image.asset(
                              imagePath,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.error,
                                  color: AppTheme.primaryColor,
                                  size: isMobile ? 40 : 48,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.delivery_dining_rounded,
                                size: isMobile ? 60 : 72,
                                color: AppTheme.primaryColor.withOpacity(0.6),
                              ),
                            ),
                    ),
                    // طبقة متدرجة حمراء للخدمات الثلاثة الأولى فقط
                    if (!isMaid && !isCarWash)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.red.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    // طبقة متدرجة زرقاء لتأجير العاملة وغسيل السيارات وتوصيل
                    if (isMaid || isCarWash || isDelivery)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.blue.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    // نص "قريباً" للخدمات القادمة
                    if (isComingSoon)
                      Container(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'قريباً',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // اسم القسم باللون الفيروزي
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
