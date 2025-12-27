class AppConstants {
  // API Endpoints
  // TODO: تحديث هذا الرابط إلى رابط API الحقيقي عند نشر السيرفر
  // للتطوير المحلي على المحاكي: http://localhost:3000/api
  // للتطوير المحلي على الجهاز الحقيقي: http://[YOUR_IP_ADDRESS]:3000/api
  // للإنتاج: https://your-api-domain.com
  // 
  // ⚠️ مهم: استبدل [YOUR_IP_ADDRESS] بـ IP address الكمبيوتر
  // لمعرفة IP address: Windows: ipconfig | Linux/Mac: ifconfig
  // مثال: http://192.168.1.100:3000/api
  // 
  // ✅ تم تحديثه إلى Railway Production Server (Backend منفصل)
  static const String baseUrl = 'https://munqethser-production.up.railway.app/api';
  
  // API Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Retry Configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userCodeKey = 'user_code';
  static const String languageKey = 'language';
  static const String rememberMeKey = 'remember_me';
  static const String savedUserIdKey = 'saved_user_id';
  static const String savedUserCodeKey = 'saved_user_code';
  static const String userLoggedInKey = 'user_logged_in';
  static const String userNameKey = 'user_name';
  static const String userPhoneKey = 'user_phone';
  static const String shoppingCartKey = 'shopping_cart';
  
  // App Info
  static const String appName = 'تطبيق المنقذ';
  static const String appVersion = '1.0.0';
  
  // Validation Limits
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int minAddressLength = 10;
  static const int maxAddressLength = 200;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Location
  static const double defaultLatitude = 33.3152; // بغداد
  static const double defaultLongitude = 44.3661; // بغداد
  static const double defaultZoom = 14.0;
  
  // Order Status
  static const List<String> orderStatuses = [
    'pending',
    'preparing',
    'ready',
    'accepted',
    'arrived',
    'in_progress',
    'delivered',
    'completed',
    'cancelled',
  ];
  
  // Service Types
  static const List<String> serviceTypes = [
    'delivery',
    'taxi',
    'maintenance',
    'car_emergency',
    'crane',
    'fuel',
    'maid',
  ];
  
  // Image Configuration
  static const int imageCacheWidth = 800;
  static const int imageCacheHeight = 800;
  static const int imageQuality = 85;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Snackbar Durations
  static const Duration shortSnackbar = Duration(seconds: 2);
  static const Duration mediumSnackbar = Duration(seconds: 4);
  static const Duration longSnackbar = Duration(seconds: 6);
}

// حساب سعر البنزين حسب الكمية والمسافة
int calculateFuelPrice(int quantity, double distanceKm) {
  // تقريب المسافة لأقرب كيلومتر (1-5)
  final distance = distanceKm.clamp(1.0, 5.0).ceil();
  
  // جدول الأسعار
  final prices = {
    1: {5: 5500, 10: 10500, 15: 15500, 20: 20500},
    2: {5: 6000, 10: 11000, 15: 16000, 20: 21000},
    3: {5: 6500, 10: 11500, 15: 16500, 20: 21500},
    4: {5: 7000, 10: 12000, 15: 17000, 20: 22000},
    5: {5: 7500, 10: 12500, 15: 17500, 20: 22500},
  };
  
  // الحصول على السعر من الجدول
  final distancePrices = prices[distance];
  if (distancePrices == null) {
    // في حالة المسافة أكبر من 5 كم، نستخدم سعر 5 كم
    final maxDistancePrices = prices[5]!;
    return maxDistancePrices[quantity] ?? maxDistancePrices[20]!;
  }
  
  return distancePrices[quantity] ?? distancePrices[20]!;
}


