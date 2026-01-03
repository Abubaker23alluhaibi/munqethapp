import '../core/utils/distance_calculator.dart';

class Driver {
  final String id; // MongoDB _id
  final String driverId; // المعرف المخصص (مثل DEL001, TAXI001)
  final String code;
  final String name;
  final String phone;
  final String serviceType; // "delivery", "taxi", "maintenance", "car_emergency", "crane", "fuel", "maid", "car_wash"
  final String? vehicleType;
  final String? vehicleNumber;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? image;
  final String? fcmToken;
  final bool? isDeleted;
  final bool? isActive;

  Driver({
    required this.id,
    required this.driverId,
    required this.code,
    required this.name,
    required this.phone,
    required this.serviceType,
    this.vehicleType,
    this.vehicleNumber,
    this.isAvailable = true,
    this.currentLatitude,
    this.currentLongitude,
    this.image,
    this.fcmToken,
    this.isDeleted,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id, // حفظ _id من MongoDB
      'id': id, // حفظ id أيضاً للتوافق
      'driverId': driverId, // المعرف المخصص
      'code': code,
      'name': name,
      'phone': phone,
      'serviceType': serviceType,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'isAvailable': isAvailable,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'image': image,
      'fcmToken': fcmToken,
      'isDeleted': isDeleted,
      'isActive': isActive,
    };
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    // Handle driverId (المعرف المخصص)
    String? driverIdValue = json['driverId']?.toString();
    if (driverIdValue == null) {
      driverIdValue = json['driver_id']?.toString();
    }
    
    // إذا لم يكن driverId موجود (للتوافق مع البيانات القديمة)، نستخدم id كـ fallback
    final driverId = (driverIdValue != null && driverIdValue.isNotEmpty) 
        ? driverIdValue.toUpperCase() 
        : id;
    
    // استخدام _id كـ fallback إذا لم يكن driverId موجوداً
    
    return Driver(
      id: id,
      driverId: driverId,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      phone: json['phone'] as String,
      serviceType: json['serviceType'] as String? ?? 'delivery',
      vehicleType: json['vehicleType'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      currentLatitude: json['currentLatitude'] != null
          ? (json['currentLatitude'] as num).toDouble()
          : null,
      currentLongitude: json['currentLongitude'] != null
          ? (json['currentLongitude'] as num).toDouble()
          : null,
      image: json['image'] as String?,
      fcmToken: json['fcmToken'] != null
          ? (json['fcmToken'] is List
              ? (json['fcmToken'] as List).isNotEmpty
                  ? (json['fcmToken'] as List)[0] as String?
                  : null
              : json['fcmToken'] as String?)
          : null,
      isDeleted: json['isDeleted'] as bool?,
      isActive: json['isActive'] as bool?,
    );
  }

  Driver copyWith({
    String? id,
    String? driverId,
    String? code,
    String? name,
    String? phone,
    String? serviceType,
    String? vehicleType,
    String? vehicleNumber,
    bool? isAvailable,
    double? currentLatitude,
    double? currentLongitude,
    String? image,
    String? fcmToken,
    bool? isDeleted,
    bool? isActive,
  }) {
    return Driver(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      code: code ?? this.code,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      serviceType: serviceType ?? this.serviceType,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      image: image ?? this.image,
      fcmToken: fcmToken ?? this.fcmToken,
      isDeleted: isDeleted ?? this.isDeleted,
      isActive: isActive ?? this.isActive,
    );
  }

  // حساب المسافة بين السائق والعميل
  double? distanceTo(double? lat, double? lng) {
    return DistanceCalculator.calculateDistance(
      currentLatitude,
      currentLongitude,
      lat,
      lng,
    );
  }

  // Helper methods
  bool get isDelivery => serviceType == 'delivery';
  bool get isTaxi => serviceType == 'taxi';
  bool get isMaintenance => serviceType == 'maintenance';
  bool get isCarEmergency => serviceType == 'car_emergency';
  bool get isCrane => serviceType == 'crane';
  bool get isFuel => serviceType == 'fuel';
  bool get isMaid => serviceType == 'maid';
  bool get isCarWash => serviceType == 'car_wash';
}



