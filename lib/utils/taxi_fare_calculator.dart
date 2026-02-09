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
  /// [nightMinFare], [nightMaxFare], [peakMinFare], [peakMaxFare]: من إعدادات الأدمن إن وُجدت
  static int calculateFare(
    double distanceKm, {
    bool isPeakTime = false,
    bool isNight = false,
    bool hasTraffic = false,
    double trafficMultiplier = 0.15, // 15% افتراضي
    int? nightMinFare,
    int? nightMaxFare,
    int? peakMinFare,
    int? peakMaxFare,
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

    final int nightMin = nightMinFare ?? 10000;
    final int nightMax = nightMaxFare ?? 20000;
    final int peakMin = peakMinFare ?? 10000;
    final int peakMax = peakMaxFare ?? 20000;
    // تطبيق وقت الليل: سعر بين nightMin و nightMax (من الإعدادات أو الافتراضي)
    if (isNight) {
      if (baseFare < nightMin) baseFare = nightMin;
      if (baseFare > nightMax) baseFare = nightMax;
      baseFare = ((baseFare / 250).round() * 250);
    } else if (isPeakTime) {
      if (baseFare < peakMin) baseFare = peakMin;
      if (baseFare > peakMax) baseFare = peakMax;
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
    int? nightMinFare,
    int? nightMaxFare,
    int? peakMinFare,
    int? peakMaxFare,
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
      nightMinFare: nightMinFare,
      nightMaxFare: nightMaxFare,
      peakMinFare: peakMinFare,
      peakMaxFare: peakMaxFare,
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
    return isNightTimeFrom('20:30', '06:00');
  }

  /// تحديد إذا كان وقت الليل من إعدادات الأدمن (مثال: nightStart "20:30", nightEnd "06:00")
  static bool isNightTimeFrom(String nightStart, String nightEnd) {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final nowMinutes = hour * 60 + minute;
    final (startHour, startMin) = _parseTime(nightStart);
    final (endHour, endMin) = _parseTime(nightEnd);
    final startMinutes = startHour * 60 + startMin;
    final endMinutes = endHour * 60 + endMin;
    if (startMinutes > endMinutes) {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  /// تحديد إذا كان وقت الذروة من إعدادات الأدمن
  static bool isPeakTimeFrom(String peakMorningStart, String peakMorningEnd, String peakEveningStart, String peakEveningEnd) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final (mStartH, mStartM) = _parseTime(peakMorningStart);
    final (mEndH, mEndM) = _parseTime(peakMorningEnd);
    final (eStartH, eStartM) = _parseTime(peakEveningStart);
    final (eEndH, eEndM) = _parseTime(peakEveningEnd);
    final inMorning = nowMinutes >= mStartH * 60 + mStartM && nowMinutes < mEndH * 60 + mEndM;
    final inEvening = nowMinutes >= eStartH * 60 + eStartM && nowMinutes < eEndH * 60 + eEndM;
    return inMorning || inEvening;
  }

  static (int, int) _parseTime(String time) {
    final parts = time.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0].trim()) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }
}

