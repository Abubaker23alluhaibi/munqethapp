class User {
  final String id;
  final String name;
  final String phone;
  final String? password; // Optional - won't be sent from backend usually
  final String? address;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.password,
    this.address,
    this.fcmToken,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
    if (password != null) {
      map['password'] = password;
    }
    return map;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    // Handle fcmToken - can be String (old format) or List<String> (new format)
    // For Flutter client, we don't need the fcmToken array, so we ignore it
    String? fcmToken;
    if (json['fcmToken'] != null) {
      if (json['fcmToken'] is List) {
        // New format: array - take first token if available, or null
        final tokens = json['fcmToken'] as List;
        fcmToken = tokens.isNotEmpty ? tokens[0] as String? : null;
      } else if (json['fcmToken'] is String) {
        // Old format: string
        fcmToken = json['fcmToken'] as String?;
      }
    }
    
    return User(
      id: id,
      name: json['name'] as String,
      phone: json['phone'] as String,
      password: json['password'] as String?,
      address: json['address'] as String?,
      fcmToken: fcmToken,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.parse((json['createdAt'] as DateTime).toIso8601String()))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : DateTime.parse((json['updatedAt'] as DateTime).toIso8601String()))
          : null,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? password,
    String? address,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      address: address ?? this.address,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}



