class Advertisement {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String serviceType; // 'delivery', 'taxi', 'maintenance', 'all'
  final String? supermarketId; // null = general
  final bool hasDiscount;
  final int discountPercentage; // 0-100
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Advertisement({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.serviceType,
    this.supermarketId,
    required this.hasDiscount,
    required this.discountPercentage,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'serviceType': serviceType,
      'supermarketId': supermarketId,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    return Advertisement(
      id: id,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      serviceType: json['serviceType'] as String,
      supermarketId: json['supermarketId'] as String?,
      hasDiscount: json['hasDiscount'] as bool? ?? false,
      discountPercentage: json['discountPercentage'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.parse((json['createdAt'] as DateTime).toIso8601String()))
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? (json['expiresAt'] is String
              ? DateTime.parse(json['expiresAt'] as String)
              : DateTime.parse((json['expiresAt'] as DateTime).toIso8601String()))
          : null,
    );
  }

  Advertisement copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? serviceType,
    String? supermarketId,
    bool? hasDiscount,
    int? discountPercentage,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return Advertisement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      serviceType: serviceType ?? this.serviceType,
      supermarketId: supermarketId ?? this.supermarketId,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Helper methods
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid {
    return isActive && !isExpired;
  }

  String get discountText {
    if (!hasDiscount) return '';
    return '$discountPercentage%';
  }
}




