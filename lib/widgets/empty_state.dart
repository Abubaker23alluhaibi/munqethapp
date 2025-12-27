import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الأيقونة
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.lightPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 60,
                color: AppTheme.primaryColor,
              ),
            )
                .animate()
                .scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOut)
                .fadeIn(delay: 100.ms, duration: 500.ms),
            const SizedBox(height: 32),
            // العنوان
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 500.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),
            // الرسالة
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 500.ms, curve: Curves.easeOut),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(buttonText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0, delay: 500.ms, duration: 500.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}

// حالات فارغة محددة
class EmptySearchState extends StatelessWidget {
  final VoidCallback? onClearSearch;

  const EmptySearchState({
    super.key,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'لا توجد نتائج',
      message: 'لم نجد أي نتائج للبحث الذي أدخلته.\nحاول البحث بكلمات مختلفة.',
      buttonText: 'مسح البحث',
      onButtonPressed: onClearSearch,
    );
  }
}

class EmptyCartState extends StatelessWidget {
  final VoidCallback? onStartShopping;

  const EmptyCartState({
    super.key,
    this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'السلة فارغة',
      message: 'لم تقم بإضافة أي منتجات إلى السلة بعد.\nابدأ التسوق الآن!',
      buttonText: 'ابدأ التسوق',
      onButtonPressed: onStartShopping,
    );
  }
}

class EmptyOrdersState extends StatelessWidget {
  final VoidCallback? onStartShopping;

  const EmptyOrdersState({
    super.key,
    this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'لا توجد طلبات',
      message: 'لم تقم بإجراء أي طلبات بعد.\nابدأ التسوق الآن!',
      buttonText: 'ابدأ التسوق',
      onButtonPressed: onStartShopping,
    );
  }
}

class EmptyFavoritesState extends StatelessWidget {
  final VoidCallback? onBrowse;

  const EmptyFavoritesState({
    super.key,
    this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'لا توجد مفضلات',
      message: 'لم تقم بإضافة أي منتجات إلى المفضلة بعد.\nتصفح المنتجات وأضف ما يعجبك!',
      buttonText: 'تصفح المنتجات',
      onButtonPressed: onBrowse,
    );
  }
}

class EmptyNotificationsState extends StatelessWidget {
  const EmptyNotificationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'لا توجد إشعارات',
      message: 'لا توجد إشعارات جديدة في الوقت الحالي.',
    );
  }
}









