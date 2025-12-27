import '../core/utils/distance_calculator.dart';

/// حاسبة سعر التوصيل للتسوق
class DeliveryFeeCalculator {
  /// حساب سعر التوصيل بناءً على المسافة
  /// المسافة بالكيلومترات
  static int calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) {
      return 1000; // أقل كرة
    } else if (distanceKm <= 1) {
      return 1000; // من 0 – 1 كم
    } else if (distanceKm <= 2) {
      return 1500; // من 1 – 2 كم
    } else if (distanceKm <= 3) {
      return 2000; // من 2 – 3 كم
    } else if (distanceKm <= 4) {
      return 2500; // من 3 – 4 كم
    } else if (distanceKm <= 5) {
      return 3000; // من 4 – 5 كم
    } else if (distanceKm <= 6) {
      return 3500; // من 5 – 6 كم
    } else if (distanceKm <= 7) {
      return 4000; // من 6 – 7 كم
    } else if (distanceKm <= 8) {
      return 4500; // من 7 – 8 كم
    } else if (distanceKm <= 9) {
      return 5000; // من 8 – 9 كم
    } else if (distanceKm <= 10) {
      return 5500; // من 9 – 10 كم
    } else {
      // أكثر من 10 كم: 500 دينار لكل كم إضافي
      final additionalKm = distanceKm - 10;
      return 5500 + (additionalKm * 500).round();
    }
  }

  /// حساب سعر التوصيل بين موقعين
  static int? calculateDeliveryFeeBetween(
    double? supermarketLat,
    double? supermarketLng,
    double? customerLat,
    double? customerLng,
  ) {
    final distance = DistanceCalculator.calculateDistance(
      supermarketLat,
      supermarketLng,
      customerLat,
      customerLng,
    );

    if (distance == null) {
      return null;
    }

    return calculateDeliveryFee(distance);
  }
}






