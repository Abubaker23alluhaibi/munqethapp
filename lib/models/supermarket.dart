import 'dart:math' as math;
import '../core/utils/distance_calculator.dart';

class Supermarket {
  final String id;
  final String code;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? image;
  final double? latitude;
  final double? longitude;
  final List<SupermarketLocation>? locations; // مواقع متعددة

  Supermarket({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.image,
    this.latitude,
    this.longitude,
    this.locations,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'image': image,
      'latitude': latitude,
      'longitude': longitude,
      'locations': locations?.map((loc) => loc.toJson()).toList(),
    };
  }

  factory Supermarket.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    return Supermarket(
      id: id,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      image: json['image'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      locations: json['locations'] != null
          ? (json['locations'] as List<dynamic>)
              .map((loc) => SupermarketLocation.fromJson(loc as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Supermarket copyWith({
    String? id,
    String? code,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? image,
    double? latitude,
    double? longitude,
    List<SupermarketLocation>? locations,
  }) {
    return Supermarket(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locations: locations ?? this.locations,
    );
  }

  // حساب المسافة بين السوبر ماركت والعميل
  // إذا كان هناك مواقع متعددة، نستخدم الأقرب
  double? distanceTo(double? lat, double? lng) {
    // إذا كان هناك مواقع متعددة، نستخدم الأقرب
    if (locations != null && locations!.isNotEmpty) {
      double? minDistance;
      for (var location in locations!) {
        final distance = DistanceCalculator.calculateDistance(
          location.latitude,
          location.longitude,
          lat,
          lng,
        );
        if (distance != null && (minDistance == null || distance < minDistance)) {
          minDistance = distance;
        }
      }
      return minDistance;
    }
    
    // استخدام الموقع القديم (latitude, longitude) للتوافق مع الكود القديم
    return DistanceCalculator.calculateDistance(
      latitude,
      longitude,
      lat,
      lng,
    );
  }
  
  // الحصول على أقرب موقع للعميل
  SupermarketLocation? getNearestLocation(double? lat, double? lng) {
    if (locations == null || locations!.isEmpty || lat == null || lng == null) {
      return null;
    }
    
    // التحقق من صحة الإحداثيات
    if (lat.isNaN || lng.isNaN || !lat.isFinite || !lng.isFinite) {
      return null;
    }
    
    SupermarketLocation? nearest;
    double? minDistance;
    
    for (var location in locations!) {
      // التحقق من وجود إحداثيات الموقع
      if (location.latitude == null || location.longitude == null) {
        continue;
      }
      
      final distance = DistanceCalculator.calculateDistance(
        location.latitude,
        location.longitude,
        lat,
        lng,
      );
      
      // التحقق من أن المسافة صحيحة وليست NaN
      if (distance != null && 
          distance.isFinite && 
          !distance.isNaN &&
          (minDistance == null || distance < minDistance)) {
        minDistance = distance;
        nearest = location;
      }
    }
    
    return nearest;
  }
}

// نموذج موقع السوبر ماركت
class SupermarketLocation {
  final String? id;
  final String? name;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? createdAt;

  SupermarketLocation({
    this.id,
    this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (name != null) 'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  factory SupermarketLocation.fromJson(Map<String, dynamic> json) {
    return SupermarketLocation(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  SupermarketLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? createdAt,
  }) {
    return SupermarketLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}



