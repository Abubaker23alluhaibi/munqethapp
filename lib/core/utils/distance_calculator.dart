import 'dart:math' as math;

/// حاسبة المسافة بين نقطتين جغرافيتين
class DistanceCalculator {
  static const double earthRadius = 6371; // km

  /// حساب المسافة بين نقطتين باستخدام Haversine formula
  /// Returns distance in kilometers
  static double? calculateDistance(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    // التحقق من وجود القيم
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }

    // التحقق من أن القيم ليست NaN وأنها ضمن النطاق الصحيح
    if (lat1.isNaN || lon1.isNaN || lat2.isNaN || lon2.isNaN) {
      return null;
    }

    if (!lat1.isFinite || !lon1.isFinite || !lat2.isFinite || !lon2.isFinite) {
      return null;
    }

    // التحقق من نطاق الإحداثيات
    if (lat1 < -90 || lat1 > 90 || lat2 < -90 || lat2 > 90) {
      return null;
    }
    if (lon1 < -180 || lon1 > 180 || lon2 < -180 || lon2 > 180) {
      return null;
    }

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    final distance = earthRadius * c;

    // التحقق من أن النتيجة صحيحة
    if (distance.isNaN || !distance.isFinite) {
      return null;
    }

    return distance;
  }

  /// تحويل الدرجات إلى راديان
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// تنسيق المسافة للن display
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return 'غير متاح';
    
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} م';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} كم';
    } else {
      return '${distanceKm.toStringAsFixed(0)} كم';
    }
  }
}









