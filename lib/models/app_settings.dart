/// إعدادات النظام (مسافات، أسعار، أوقات) - يتحكم بها الأدمن
class AppSettings {
  final double commissionPercentage;
  final int orderExpirationMinutes;
  final TaxiSettings taxi;
  final CraneSettings crane;
  final MarketSettings market;
  final FuelSettings fuel;
  final ServiceLimitSettings carEmergency;
  final CarWashSettings carWash;
  final MaidSettings maid;

  const AppSettings({
    this.commissionPercentage = 10,
    this.orderExpirationMinutes = 6,
    required this.taxi,
    required this.crane,
    required this.market,
    required this.fuel,
    required this.carEmergency,
    required this.carWash,
    required this.maid,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      commissionPercentage: (json['commissionPercentage'] as num?)?.toDouble() ?? 10,
      orderExpirationMinutes: (json['orderExpirationMinutes'] as num?)?.toInt() ?? 6,
      taxi: TaxiSettings.fromJson(json['taxi'] is Map ? json['taxi'] as Map<String, dynamic> : {}),
      crane: CraneSettings.fromJson(json['crane'] is Map ? json['crane'] as Map<String, dynamic> : {}),
      market: MarketSettings.fromJson(json['market'] is Map ? json['market'] as Map<String, dynamic> : {}),
      fuel: FuelSettings.fromJson(json['fuel'] is Map ? json['fuel'] as Map<String, dynamic> : {}),
      carEmergency: ServiceLimitSettings.fromJson(json['carEmergency'] is Map ? json['carEmergency'] as Map<String, dynamic> : {}),
      carWash: CarWashSettings.fromJson(json['carWash'] is Map ? json['carWash'] as Map<String, dynamic> : {}),
      maid: MaidSettings.fromJson(json['maid'] is Map ? json['maid'] as Map<String, dynamic> : {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commissionPercentage': commissionPercentage,
      'orderExpirationMinutes': orderExpirationMinutes,
      'taxi': taxi.toJson(),
      'crane': crane.toJson(),
      'market': market.toJson(),
      'fuel': fuel.toJson(),
      'carEmergency': carEmergency.toJson(),
      'carWash': carWash.toJson(),
      'maid': maid.toJson(),
    };
  }

  static AppSettings get defaults => AppSettings(
        commissionPercentage: 10,
        orderExpirationMinutes: 6,
        taxi: TaxiSettings.defaults,
        crane: CraneSettings.defaults,
        market: MarketSettings.defaults,
        fuel: FuelSettings.defaults,
        carEmergency: ServiceLimitSettings.defaults,
        carWash: CarWashSettings.defaults,
        maid: MaidSettings.defaults,
      );
}

class TaxiSettings {
  final bool enabled;
  final double maxDistanceKm;
  final String nightStart;
  final String nightEnd;
  final String peakMorningStart;
  final String peakMorningEnd;
  final String peakEveningStart;
  final String peakEveningEnd;
  final int baseFare1km;
  final int nightMinFare;
  final int nightMaxFare;
  final int peakMinFare;
  final int peakMaxFare;

  const TaxiSettings({
    this.enabled = true,
    this.maxDistanceKm = 3,
    this.nightStart = '20:30',
    this.nightEnd = '06:00',
    this.peakMorningStart = '07:00',
    this.peakMorningEnd = '09:00',
    this.peakEveningStart = '17:00',
    this.peakEveningEnd = '19:00',
    this.baseFare1km = 2000,
    this.nightMinFare = 10000,
    this.nightMaxFare = 20000,
    this.peakMinFare = 10000,
    this.peakMaxFare = 20000,
  });

  factory TaxiSettings.fromJson(Map<String, dynamic> json) {
    return TaxiSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 3,
      nightStart: json['nightStart'] as String? ?? '20:30',
      nightEnd: json['nightEnd'] as String? ?? '06:00',
      peakMorningStart: json['peakMorningStart'] as String? ?? '07:00',
      peakMorningEnd: json['peakMorningEnd'] as String? ?? '09:00',
      peakEveningStart: json['peakEveningStart'] as String? ?? '17:00',
      peakEveningEnd: json['peakEveningEnd'] as String? ?? '19:00',
      baseFare1km: (json['baseFare1km'] as num?)?.toInt() ?? 2000,
      nightMinFare: (json['nightMinFare'] as num?)?.toInt() ?? 10000,
      nightMaxFare: (json['nightMaxFare'] as num?)?.toInt() ?? 20000,
      peakMinFare: (json['peakMinFare'] as num?)?.toInt() ?? 10000,
      peakMaxFare: (json['peakMaxFare'] as num?)?.toInt() ?? 20000,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxDistanceKm': maxDistanceKm,
        'nightStart': nightStart,
        'nightEnd': nightEnd,
        'peakMorningStart': peakMorningStart,
        'peakMorningEnd': peakMorningEnd,
        'peakEveningStart': peakEveningStart,
        'peakEveningEnd': peakEveningEnd,
        'baseFare1km': baseFare1km,
        'nightMinFare': nightMinFare,
        'nightMaxFare': nightMaxFare,
        'peakMinFare': peakMinFare,
        'peakMaxFare': peakMaxFare,
      };

  static const TaxiSettings defaults = TaxiSettings();
}

class CraneSettings {
  final bool enabled;
  final double maxDistanceKm;

  const CraneSettings({this.enabled = true, this.maxDistanceKm = 15});

  factory CraneSettings.fromJson(Map<String, dynamic> json) {
    return CraneSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'maxDistanceKm': maxDistanceKm};

  static const CraneSettings defaults = CraneSettings();
}

class DeliveryFeeTier {
  final double maxKm;
  final int fee;

  const DeliveryFeeTier({required this.maxKm, required this.fee});

  factory DeliveryFeeTier.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeTier(
      maxKm: (json['maxKm'] as num?)?.toDouble() ?? 0,
      fee: (json['fee'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'maxKm': maxKm, 'fee': fee};
}

class MarketSettings {
  final bool enabled;
  final double maxDistanceKm;
  final List<DeliveryFeeTier> deliveryFeeTiers;
  final int deliveryFeePerKmOverMax;

  const MarketSettings({
    this.enabled = true,
    this.maxDistanceKm = 5,
    this.deliveryFeeTiers = const [],
    this.deliveryFeePerKmOverMax = 500,
  });

  factory MarketSettings.fromJson(Map<String, dynamic> json) {
    List<DeliveryFeeTier> tiers = [];
    if (json['deliveryFeeTiers'] is List) {
      for (final e in json['deliveryFeeTiers'] as List) {
        if (e is Map) tiers.add(DeliveryFeeTier.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    if (tiers.isEmpty) {
      tiers = [
        const DeliveryFeeTier(maxKm: 1, fee: 1000),
        const DeliveryFeeTier(maxKm: 2, fee: 1500),
        const DeliveryFeeTier(maxKm: 3, fee: 2000),
        const DeliveryFeeTier(maxKm: 4, fee: 2500),
        const DeliveryFeeTier(maxKm: 5, fee: 3000),
        const DeliveryFeeTier(maxKm: 6, fee: 3500),
        const DeliveryFeeTier(maxKm: 7, fee: 4000),
        const DeliveryFeeTier(maxKm: 8, fee: 4500),
        const DeliveryFeeTier(maxKm: 9, fee: 5000),
        const DeliveryFeeTier(maxKm: 10, fee: 5500),
      ];
    }
    return MarketSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 5,
      deliveryFeeTiers: tiers,
      deliveryFeePerKmOverMax: (json['deliveryFeePerKmOverMax'] as num?)?.toInt() ?? 500,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxDistanceKm': maxDistanceKm,
        'deliveryFeeTiers': deliveryFeeTiers.map((t) => t.toJson()).toList(),
        'deliveryFeePerKmOverMax': deliveryFeePerKmOverMax,
      };

  static const MarketSettings defaults = MarketSettings();
}

class FuelPriceEntry {
  final int distanceKm;
  final Map<int, int> prices;

  const FuelPriceEntry({required this.distanceKm, required this.prices});

  factory FuelPriceEntry.fromJson(Map<String, dynamic> json) {
    Map<int, int> prices = {};
    if (json['prices'] is Map) {
      for (final e in (json['prices'] as Map).entries) {
        final k = int.tryParse(e.key.toString());
        final v = (e.value as num?)?.toInt();
        if (k != null && v != null) prices[k] = v;
      }
    }
    return FuelPriceEntry(
      distanceKm: (json['distanceKm'] as num?)?.toInt() ?? 0,
      prices: prices,
    );
  }

  Map<String, dynamic> toJson() => {
        'distanceKm': distanceKm,
        'prices': prices.map((k, v) => MapEntry(k.toString(), v)),
      };
}

class FuelSettings {
  final bool enabled;
  final double maxDistanceKm;
  final List<FuelPriceEntry> priceTable;

  const FuelSettings({
    this.enabled = true,
    this.maxDistanceKm = 15,
    this.priceTable = const [],
  });

  factory FuelSettings.fromJson(Map<String, dynamic> json) {
    List<FuelPriceEntry> table = [];
    if (json['priceTable'] is List) {
      for (final e in json['priceTable'] as List) {
        if (e is Map) table.add(FuelPriceEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return FuelSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 15,
      priceTable: table,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxDistanceKm': maxDistanceKm,
        'priceTable': priceTable.map((e) => e.toJson()).toList(),
      };

  /// سعر البنزين من جدول الإعدادات (كمية ومسافة). إذا لم يوجد في الجدول يُرجع null.
  int? getPriceFor(int quantity, double distanceKm) {
    if (priceTable.isEmpty) return null;
    final distance = distanceKm.clamp(1.0, 10.0).ceil();
    FuelPriceEntry? entry;
    for (final e in priceTable) {
      if (e.distanceKm >= distance && (entry == null || e.distanceKm < entry.distanceKm)) {
        entry = e;
      }
    }
    entry ??= priceTable.reduce((a, b) => a.distanceKm >= b.distanceKm ? a : b);
    if (entry.prices.containsKey(quantity)) return entry.prices[quantity];
    final keys = entry.prices.keys.toList()..sort();
    for (final k in keys.reversed) {
      if (quantity >= k) return entry.prices[k];
    }
    return keys.isNotEmpty ? entry.prices[keys.first] : null;
  }

  static const FuelSettings defaults = FuelSettings();
}

class ServiceLimitSettings {
  final bool enabled;
  final double maxDistanceKm;

  const ServiceLimitSettings({this.enabled = true, this.maxDistanceKm = 15});

  factory ServiceLimitSettings.fromJson(Map<String, dynamic> json) {
    return ServiceLimitSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'maxDistanceKm': maxDistanceKm};

  static const ServiceLimitSettings defaults = ServiceLimitSettings();
}

class CarWashSettings {
  final bool enabled;
  final double maxDistanceKm;
  final int smallPrice;
  final int largePrice;

  const CarWashSettings({
    this.enabled = true,
    this.maxDistanceKm = 15,
    this.smallPrice = 10000,
    this.largePrice = 15000,
  });

  factory CarWashSettings.fromJson(Map<String, dynamic> json) {
    return CarWashSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 15,
      smallPrice: (json['smallPrice'] as num?)?.toInt() ?? 10000,
      largePrice: (json['largePrice'] as num?)?.toInt() ?? 15000,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxDistanceKm': maxDistanceKm,
        'smallPrice': smallPrice,
        'largePrice': largePrice,
      };

  static const CarWashSettings defaults = CarWashSettings();
}

class MaidSettings {
  final bool enabled;
  final double maxDistanceKm;
  final int defaultPrice;

  const MaidSettings({
    this.enabled = true,
    this.maxDistanceKm = 15,
    this.defaultPrice = 55000,
  });

  factory MaidSettings.fromJson(Map<String, dynamic> json) {
    return MaidSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 15,
      defaultPrice: (json['defaultPrice'] as num?)?.toInt() ?? 55000,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxDistanceKm': maxDistanceKm,
        'defaultPrice': defaultPrice,
      };

  static const MaidSettings defaults = MaidSettings();
}
