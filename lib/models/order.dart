class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? productImage;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.productImage,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'productImage': productImage,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      productImage: json['productImage'] as String?,
    );
  }
}

enum OrderStatus {
  pending('جديد', 'pending'),
  preparing('قيد التحضير', 'preparing'),
  ready('جاهز', 'ready'),
  accepted('مقبول', 'accepted'),
  arrived('وصل', 'arrived'),
  inProgress('قيد التنقل', 'in_progress'),
  delivered('تم التسليم', 'delivered'),
  completed('مكتمل', 'completed'),
  cancelled('ملغي', 'cancelled');

  final String arabicName;
  final String value;

  const OrderStatus(this.arabicName, this.value);
}

class Order {
  final String id;
  final String type; // "delivery", "taxi", "maintenance", "car_emergency", "crane", "fuel", "maid", "car_wash"
  final String? supermarketId; // null for taxi orders
  final String customerName;
  final String customerPhone;
  final String? customerAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final List<OrderItem>? items; // null for taxi orders
  final OrderStatus status;
  final double? total; // null for taxi orders (use fare instead)
  final double? fare; // for taxi orders
  final int? deliveryFee; // سعر التوصيل للتسوق (بالدينار)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? driverId; // unified field (was deliveryId/taxiId)
  final DateTime? driverAcceptedAt; // unified field (was deliveryAcceptedAt/taxiAcceptedAt)
  final String? driverName; // من الـ API عند وجود سائق
  final String? driverPhone;
  // Taxi/Crane-specific fields
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationAddress;
  // Fuel-specific fields
  final int? fuelQuantity; // كمية البنزين باللتر (5-20)
  // Maid-specific fields
  final String? maidServiceType; // نوع خدمة العاملات (تنظيف، ترتيب، أطفال، كبار سن)
  final int? maidWorkHours; // عدد ساعات العمل
  final DateTime? maidWorkDate; // تاريخ العمل
  // Car Emergency-specific fields
  final String? emergencyReason; // سبب طوارئ السيارات
  // Car Wash-specific fields
  final String? carWashSize; // 'small' or 'large' - حجم السيارة
  // Payment fields
  final String? paymentMethod; // 'wallet', 'card', 'cash'
  final String? paymentCardId; // ID of the card used for payment (if paymentMethod is 'card')
  // Cancellation fields
  final String? cancellationReason; // سبب الإلغاء (من السائق)

  Order({
    required this.id,
    required this.type,
    this.supermarketId,
    required this.customerName,
    required this.customerPhone,
    this.customerAddress,
    this.customerLatitude,
    this.customerLongitude,
    this.items,
    required this.status,
    this.total,
    this.fare,
    this.deliveryFee,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.driverId,
    this.driverAcceptedAt,
    this.driverName,
    this.driverPhone,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationAddress,
    this.fuelQuantity,
    this.maidServiceType,
    this.maidWorkHours,
    this.maidWorkDate,
    this.emergencyReason,
    this.carWashSize,
    this.paymentMethod,
    this.paymentCardId,
    this.cancellationReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'supermarketId': supermarketId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'items': items?.map((item) => item.toJson()).toList(),
      'status': status.value,
      'total': total,
      'fare': fare,
      'deliveryFee': deliveryFee,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'driverId': driverId,
      'driverAcceptedAt': driverAcceptedAt?.toIso8601String(),
      'driverName': driverName,
      'driverPhone': driverPhone,
      'destinationLatitude': destinationLatitude,
      'destinationLongitude': destinationLongitude,
      'destinationAddress': destinationAddress,
      'fuelQuantity': fuelQuantity,
      'maidServiceType': maidServiceType,
      'maidWorkHours': maidWorkHours,
      'maidWorkDate': maidWorkDate?.toIso8601String(),
      'emergencyReason': emergencyReason,
      'carWashSize': carWashSize,
      'paymentMethod': paymentMethod,
      'paymentCardId': paymentCardId,
      'cancellationReason': cancellationReason,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    // Handle backward compatibility
    final type = json['type'] as String? ?? 
        (json['supermarketId'] != null ? 'delivery' : 'taxi');
    
    return Order(
      id: id,
      type: type,
      supermarketId: json['supermarketId'] as String?,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      customerAddress: json['customerAddress'] as String?,
      customerLatitude: json['customerLatitude'] != null
          ? (json['customerLatitude'] as num).toDouble()
          : null,
      customerLongitude: json['customerLongitude'] != null
          ? (json['customerLongitude'] as num).toDouble()
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      status: OrderStatus.values.firstWhere(
        (e) => e.value == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      total: json['total'] != null ? (json['total'] as num).toDouble() : null,
      fare: json['fare'] != null ? (json['fare'] as num).toDouble() : null,
      deliveryFee: json['deliveryFee'] != null ? (json['deliveryFee'] as num).toInt() : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : (json['createdAt'] is DateTime
                  ? json['createdAt'] as DateTime
                  : DateTime.parse((json['createdAt'] as DateTime).toIso8601String())))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : DateTime.parse((json['updatedAt'] as DateTime).toIso8601String()))
          : null,
      notes: json['notes'] as String?,
      driverId: json['driverId'] as String? ??
          json['deliveryId'] as String? ??
          json['taxiId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      driverAcceptedAt: json['driverAcceptedAt'] != null
          ? (json['driverAcceptedAt'] is String
              ? DateTime.parse(json['driverAcceptedAt'] as String)
              : DateTime.parse((json['driverAcceptedAt'] as DateTime).toIso8601String()))
          : json['deliveryAcceptedAt'] != null
              ? (json['deliveryAcceptedAt'] is String
                  ? DateTime.parse(json['deliveryAcceptedAt'] as String)
                  : DateTime.parse((json['deliveryAcceptedAt'] as DateTime).toIso8601String()))
              : json['taxiAcceptedAt'] != null
                  ? (json['taxiAcceptedAt'] is String
                      ? DateTime.parse(json['taxiAcceptedAt'] as String)
                      : DateTime.parse((json['taxiAcceptedAt'] as DateTime).toIso8601String()))
                  : null,
      destinationLatitude: json['destinationLatitude'] != null
          ? (json['destinationLatitude'] as num).toDouble()
          : null,
      destinationLongitude: json['destinationLongitude'] != null
          ? (json['destinationLongitude'] as num).toDouble()
          : null,
      destinationAddress: json['destinationAddress'] as String?,
      fuelQuantity: json['fuelQuantity'] as int?,
      maidServiceType: json['maidServiceType'] as String?,
      maidWorkHours: json['maidWorkHours'] as int?,
      maidWorkDate: json['maidWorkDate'] != null
          ? (json['maidWorkDate'] is String
              ? DateTime.parse(json['maidWorkDate'] as String)
              : DateTime.parse((json['maidWorkDate'] as DateTime).toIso8601String()))
          : null,
      emergencyReason: json['emergencyReason'] as String?,
      carWashSize: json['carWashSize'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentCardId: json['paymentCardId'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
    );
  }

  Order copyWith({
    String? id,
    String? type,
    String? supermarketId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? customerLatitude,
    double? customerLongitude,
    List<OrderItem>? items,
    OrderStatus? status,
    double? total,
    double? fare,
    int? deliveryFee,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? driverId,
    DateTime? driverAcceptedAt,
    String? driverName,
    String? driverPhone,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationAddress,
    int? fuelQuantity,
    String? maidServiceType,
    int? maidWorkHours,
    DateTime? maidWorkDate,
    String? emergencyReason,
    String? carWashSize,
    String? paymentMethod,
    String? paymentCardId,
    String? cancellationReason,
  }) {
    return Order(
      id: id ?? this.id,
      type: type ?? this.type,
      supermarketId: supermarketId ?? this.supermarketId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      items: items ?? this.items,
      status: status ?? this.status,
      total: total ?? this.total,
      fare: fare ?? this.fare,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      driverId: driverId ?? this.driverId,
      driverAcceptedAt: driverAcceptedAt ?? this.driverAcceptedAt,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      fuelQuantity: fuelQuantity ?? this.fuelQuantity,
      maidServiceType: maidServiceType ?? this.maidServiceType,
      maidWorkHours: maidWorkHours ?? this.maidWorkHours,
      maidWorkDate: maidWorkDate ?? this.maidWorkDate,
      emergencyReason: emergencyReason ?? this.emergencyReason,
      carWashSize: carWashSize ?? this.carWashSize,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentCardId: paymentCardId ?? this.paymentCardId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  // Helper methods
  bool get isDelivery => type == 'delivery';
  bool get isTaxi => type == 'taxi';
  bool get isMaintenance => type == 'maintenance';
  bool get isCarEmergency => type == 'car_emergency';
  bool get isCrane => type == 'crane';
  bool get isFuel => type == 'fuel';
  bool get isMaid => type == 'maid';
  bool get isCarWash => type == 'car_wash';
  double get displayTotal {
    final baseTotal = total ?? fare ?? 0.0;
    final fee = deliveryFee ?? 0;
    return baseTotal + fee;
  }
}

