import '../core/utils/distance_calculator.dart';

/// حاسبة سعر التكسي
class TaxiFareCalculator {
  /// حساب سعر التكسي بناءً على المسافة والوقت وحالة الزحام
  /// 
  /// [distanceKm]: المسافة بالكيلومترات
  /// [isPeakTime]: هل هو وقت الذروة (افتراضي: false)
  /// [isNight]: هل هو وقت الليل (افتراضي: false)
  /// [hasTraffic]: هل هناك زحام أو سؤال (افتراضي: false)
  /// [trafficMultiplier]: نسبة زيادة الزحام (10% إلى 25%) - افتراضي: 0.15 (15%)
  static int calculateFare(
    double distanceKm, {
    bool isPeakTime = false,
    bool isNight = false,
    bool hasTraffic = false,
    double trafficMultiplier = 0.15, // 15% افتراضي
  }) {
    // التحقق من أن المسافة صحيحة
    if (distanceKm <= 0 || !distanceKm.isFinite) {
      return 2000; // أقل كرة (سعر بداية)
    }

    // تقريب المسافة لأقرب كيلومتر
    final distance = distanceKm.ceil();

    int baseFare;

    // حساب السعر الأساسي حسب المسافة
    if (distance <= 1) {
      baseFare = 2000; // من 0 – 1 كم
    } else if (distance <= 4) {
      // من 1-4 كم: 3000 إلى 3500
      // حساب السعر بشكل تدريجي
      if (distance == 2) {
        baseFare = 3000;
      } else if (distance == 3) {
        baseFare = 3250;
      } else {
        baseFare = 3500; // 4 كم
      }
    } else if (distance <= 12) {
      // من 4-12 كم: 5000 إلى 8000
      // حساب السعر بشكل تدريجي
      final extraKm = distance - 4;
      // من 5000 إلى 8000 على 8 كيلومترات = 3000 / 8 = 375 لكل كم
      baseFare = 5000 + (extraKm * 375);
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    } else if (distance <= 25) {
      // من 12-25 كم: 8000 إلى 12000
      final extraKm = distance - 12;
      // من 8000 إلى 12000 على 13 كيلومترات = 4000 / 13 = 307 لكل كم
      baseFare = 8000 + (extraKm * 307);
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    } else {
      // أكثر من 25 كم: 12000 + 500 لكل كم إضافي
      final extraKm = distance - 25;
      baseFare = 12000 + (extraKm * 500);
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    }

    // تطبيق وقت الليل: سعر بين 10000 و 20000 بعد الساعة 8:30 مساءً
    // وقت الليل له أولوية على وقت الذروة
    if (isNight) {
      // بعد الساعة 8:30 مساءً: السعر بين 10000 و 20000
      // إذا كان السعر الأساسي أقل من 10000، نجعله 10000
      if (baseFare < 10000) {
        baseFare = 10000;
      }
      // إذا كان السعر الأساسي أكثر من 20000، نحدده بـ 20000
      if (baseFare > 20000) {
        baseFare = 20000;
      }
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    } else if (isPeakTime) {
      // تطبيق وقت الذروة: 10000 إلى 20000 (فقط إذا لم يكن وقت ليل)
      // إذا كان السعر الأساسي أقل من 10000، نجعله 10000
      if (baseFare < 10000) {
        baseFare = 10000;
      }
      // إذا كان السعر الأساسي أكثر من 20000، نحدده بـ 20000
      if (baseFare > 20000) {
        baseFare = 20000;
      }
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    }

    // تطبيق الزحام أو السؤال: زيادة 10% إلى 25%
    if (hasTraffic) {
      // التأكد من أن trafficMultiplier بين 0.10 و 0.25
      final multiplier = trafficMultiplier.clamp(0.10, 0.25);
      final increase = (baseFare * multiplier).round();
      baseFare = baseFare + increase;
      // تقريب لأقرب 250
      baseFare = ((baseFare / 250).round() * 250);
    }

    return baseFare;
  }

  /// حساب سعر التكسي بين موقعين
  static int? calculateFareBetween(
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng, {
    bool isPeakTime = false,
    bool isNight = false,
    bool hasTraffic = false,
    double trafficMultiplier = 0.15,
  }) {
    final distance = DistanceCalculator.calculateDistance(
      pickupLat,
      pickupLng,
      destinationLat,
      destinationLng,
    );

    if (distance == null) {
      return null;
    }

    return calculateFare(
      distance,
      isPeakTime: isPeakTime,
      isNight: isNight,
      hasTraffic: hasTraffic,
      trafficMultiplier: trafficMultiplier,
    );
  }

  /// تحديد إذا كان وقت الذروة (7-9 صباحاً و 5-7 مساءً)
  static bool isPeakTime() {
    final now = DateTime.now();
    final hour = now.hour;
    return (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19);
  }

  /// تحديد إذا كان وقت الليل (بعد 8:30 مساءً أو قبل 6 صباحاً)
  static bool isNightTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // بعد الساعة 8:30 مساءً (20:30) أو قبل 6 صباحاً
    if (hour < 6) {
      return true; // قبل 6 صباحاً
    }
    if (hour > 20 || (hour == 20 && minute >= 30)) {
      return true; // بعد 20:30 (8:30 مساءً)
    }
    return false;
  }
}

