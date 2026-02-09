import '../core/utils/distance_calculator.dart';
import '../models/app_settings.dart';

/// حاسبة سعر التوصيل للتسوق
class DeliveryFeeCalculator {
  /// حساب سعر التوصيل بناءً على المسافة (قيم افتراضية)
  static int calculateDeliveryFee(double distanceKm) {
    return calculateDeliveryFeeWithTiers(
      distanceKm,
    );
  }

  /// حساب سعر التوصيل من شرائح الإعدادات (من الأدمن)
  static int calculateDeliveryFeeWithTiers(
    double distanceKm, [
    List<DeliveryFeeTier>? tiers,
    int perKmOverMax = 500,
  ]) {
    if (distanceKm <= 0) return 1000;
    if (tiers != null && tiers.isNotEmpty) {
      tiers = List.from(tiers)..sort((a, b) => a.maxKm.compareTo(b.maxKm));
      for (final t in tiers) {
        if (distanceKm <= t.maxKm) return t.fee;
      }
      final maxTier = tiers.last;
      if (distanceKm > maxTier.maxKm) {
        final extra = distanceKm - maxTier.maxKm;
        return maxTier.fee + (extra * perKmOverMax).round();
      }
      return maxTier.fee;
    }
    if (distanceKm <= 1) return 1000;
    if (distanceKm <= 2) return 1500;
    if (distanceKm <= 3) return 2000;
    if (distanceKm <= 4) return 2500;
    if (distanceKm <= 5) return 3000;
    if (distanceKm <= 6) return 3500;
    if (distanceKm <= 7) return 4000;
    if (distanceKm <= 8) return 4500;
    if (distanceKm <= 9) return 5000;
    if (distanceKm <= 10) return 5500;
    return 5500 + ((distanceKm - 10) * 500).round();
  }

  /// حساب سعر التوصيل بين موقعين (مع اختياري لإعدادات الماركت)
  static int? calculateDeliveryFeeBetween(
    double? supermarketLat,
    double? supermarketLng,
    double? customerLat,
    double? customerLng, [
    MarketSettings? market,
  ]) {
    final distance = DistanceCalculator.calculateDistance(
      supermarketLat,
      supermarketLng,
      customerLat,
      customerLng,
    );
    if (distance == null) return null;
    if (market != null && market.deliveryFeeTiers.isNotEmpty) {
      return calculateDeliveryFeeWithTiers(
        distance,
        market.deliveryFeeTiers,
        market.deliveryFeePerKmOverMax,
      );
    }
    return calculateDeliveryFee(distance);
  }
}






