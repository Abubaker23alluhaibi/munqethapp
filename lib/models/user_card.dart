/// نموذج بطاقة المستخدم المحفوظة
class UserCard {
  final String id;
  final String code; // كود البطاقة
  final int amount; // المبلغ المتبقي في البطاقة
  final String userPhone; // رقم هاتف المستخدم
  final DateTime addedAt; // تاريخ إضافة البطاقة
  final DateTime? lastUsedAt; // تاريخ آخر استخدام

  UserCard({
    required this.id,
    required this.code,
    required this.amount,
    required this.userPhone,
    required this.addedAt,
    this.lastUsedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'amount': amount,
      'userPhone': userPhone,
      'addedAt': addedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory UserCard.fromJson(Map<String, dynamic> json) {
    return UserCard(
      id: json['id'] as String,
      code: json['code'] as String,
      amount: json['amount'] as int,
      userPhone: json['userPhone'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }

  UserCard copyWith({
    String? id,
    String? code,
    int? amount,
    String? userPhone,
    DateTime? addedAt,
    DateTime? lastUsedAt,
  }) {
    return UserCard(
      id: id ?? this.id,
      code: code ?? this.code,
      amount: amount ?? this.amount,
      userPhone: userPhone ?? this.userPhone,
      addedAt: addedAt ?? this.addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// التحقق من إمكانية استخدام البطاقة للمبلغ المطلوب
  bool canUseForAmount(int requiredAmount) {
    return amount >= requiredAmount;
  }
}






