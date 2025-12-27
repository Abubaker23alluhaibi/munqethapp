class Validators {
  /// التحقق من البريد الإلكتروني
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return null;
  }

  /// التحقق من الحقل المطلوب
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty || value.trim().isEmpty) {
      return '${fieldName ?? 'هذا الحقل'} مطلوب';
    }
    return null;
  }

  /// التحقق من الحد الأدنى للطول
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.length < min) {
      return '${fieldName ?? 'هذا الحقل'} يجب أن يكون على الأقل $min أحرف';
    }
    return null;
  }

  /// التحقق من الحد الأقصى للطول
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value != null && value.length > max) {
      return '${fieldName ?? 'هذا الحقل'} يجب أن يكون على الأكثر $max أحرف';
    }
    return null;
  }

  /// التحقق من رقم الهاتف العراقي
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    
    // إزالة المسافات والأرقام غير الصحيحة
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // التحقق من رقم هاتف عراقي (يبدأ بـ 07 أو 7)
    final phoneRegex = RegExp(r'^(07|7)[0-9]{9}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      return 'رقم الهاتف غير صحيح. يجب أن يكون بصيغة: 07XXXXXXXXX';
    }
    return null;
  }

  /// التحقق من رقم الهاتف (عام)
  static String? phoneGeneral(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'رقم الهاتف غير صحيح';
    }
    return null;
  }

  /// التحقق من الكمية (أرقام فقط)
  static String? quantity(String? value, {int? min, int? max}) {
    if (value == null || value.isEmpty) {
      return 'الكمية مطلوبة';
    }
    
    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'الكمية يجب أن تكون رقماً';
    }
    
    if (min != null && quantity < min) {
      return 'الكمية يجب أن تكون على الأقل $min';
    }
    
    if (max != null && quantity > max) {
      return 'الكمية يجب أن تكون على الأكثر $max';
    }
    
    return null;
  }

  /// التحقق من السعر (أرقام فقط)
  static String? price(String? value) {
    if (value == null || value.isEmpty) {
      return 'السعر مطلوب';
    }
    
    final price = double.tryParse(value);
    if (price == null) {
      return 'السعر يجب أن يكون رقماً';
    }
    
    if (price < 0) {
      return 'السعر يجب أن يكون أكبر من صفر';
    }
    
    return null;
  }

  /// التحقق من العنوان
  static String? address(String? value) {
    if (value == null || value.isEmpty) {
      return 'العنوان مطلوب';
    }
    
    if (value.trim().length < 10) {
      return 'العنوان قصير جداً. يرجى إدخال عنوان مفصل';
    }
    
    if (value.trim().length > 200) {
      return 'العنوان طويل جداً';
    }
    
    return null;
  }

  /// التحقق من الاسم
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'الاسم مطلوب';
    }
    
    if (value.trim().length < 2) {
      return 'الاسم قصير جداً';
    }
    
    if (value.trim().length > 50) {
      return 'الاسم طويل جداً';
    }
    
    // التحقق من أن الاسم يحتوي على أحرف فقط
    final nameRegex = RegExp(r'^[\u0600-\u06FF\s\w]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return 'الاسم يحتوي على أحرف غير صحيحة';
    }
    
    return null;
  }

  /// التحقق من الكود/الرمز
  static String? code(String? value, {int? minLength, int? maxLength}) {
    if (value == null || value.isEmpty) {
      return 'الكود مطلوب';
    }
    
    final min = minLength ?? 4;
    final max = maxLength ?? 20;
    
    if (value.length < min) {
      return 'الكود يجب أن يكون على الأقل $min أحرف';
    }
    
    if (value.length > max) {
      return 'الكود يجب أن يكون على الأكثر $max أحرف';
    }
    
    return null;
  }

  /// التحقق من المسافة (latitude/longitude)
  static String? latitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'خط العرض مطلوب';
    }
    
    final lat = double.tryParse(value);
    if (lat == null) {
      return 'خط العرض غير صحيح';
    }
    
    if (lat < -90 || lat > 90) {
      return 'خط العرض يجب أن يكون بين -90 و 90';
    }
    
    return null;
  }

  static String? longitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'خط الطول مطلوب';
    }
    
    final lng = double.tryParse(value);
    if (lng == null) {
      return 'خط الطول غير صحيح';
    }
    
    if (lng < -180 || lng > 180) {
      return 'خط الطول يجب أن يكون بين -180 و 180';
    }
    
    return null;
  }

  /// التحقق من التاريخ
  static String? date(DateTime? value) {
    if (value == null) {
      return 'التاريخ مطلوب';
    }
    
    if (value.isBefore(DateTime.now().subtract(const Duration(days: 365)))) {
      return 'التاريخ قديم جداً';
    }
    
    return null;
  }

  /// التحقق من أن القيمة رقم موجب
  static String? positiveNumber(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'القيمة'} مطلوبة';
    }
    
    final number = num.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'القيمة'} يجب أن تكون رقماً';
    }
    
    if (number <= 0) {
      return '${fieldName ?? 'القيمة'} يجب أن تكون أكبر من صفر';
    }
    
    return null;
  }
}


