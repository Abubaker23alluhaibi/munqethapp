class Admin {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;

  Admin({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  factory Admin.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    return Admin(
      id: id,
      code: json['code'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Admin copyWith({
    String? id,
    String? code,
    String? name,
    String? email,
    String? phone,
  }) {
    return Admin(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}






