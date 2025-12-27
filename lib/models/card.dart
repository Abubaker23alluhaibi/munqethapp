class Card {
  final String id;
  final String code; // الكود العشوائي الفريد
  final int amount; // المبلغ: 5000, 10000, أو 25000
  final bool isUsed; // هل تم استخدام البطاقة
  final String? usedBy; // رقم هاتف المستخدم الذي استخدمها
  final DateTime? usedAt; // تاريخ الاستخدام
  final DateTime createdAt; // تاريخ الإنشاء

  Card({
    required this.id,
    required this.code,
    required this.amount,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'amount': amount,
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Card.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    return Card(
      id: id,
      code: json['code'] as String,
      amount: json['amount'] as int,
      isUsed: json['isUsed'] as bool? ?? false,
      usedBy: json['usedBy'] as String?,
      usedAt: json['usedAt'] != null
          ? (json['usedAt'] is String
              ? DateTime.parse(json['usedAt'] as String)
              : DateTime.parse((json['usedAt'] as DateTime).toIso8601String()))
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.parse((json['createdAt'] as DateTime).toIso8601String()))
          : DateTime.now(),
    );
  }

  Card copyWith({
    String? id,
    String? code,
    int? amount,
    bool? isUsed,
    String? usedBy,
    DateTime? usedAt,
    DateTime? createdAt,
  }) {
    return Card(
      id: id ?? this.id,
      code: code ?? this.code,
      amount: amount ?? this.amount,
      isUsed: isUsed ?? this.isUsed,
      usedBy: usedBy ?? this.usedBy,
      usedAt: usedAt ?? this.usedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}




