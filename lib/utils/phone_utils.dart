class PhoneUtils {
  // توحيد الرقم العراقي
  // يدعم: +9647xxxxxxxxx, 07xxxxxxxxx, 7xxxxxxxxx
  static String normalizeIraqiPhone(String phone) {
    // إزالة المسافات والرموز الخاصة
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // إذا بدأ بـ +9647
    if (cleaned.startsWith('+9647')) {
      return cleaned; // إرجاعه كما هو
    }
    
    // إذا بدأ بـ 9647 (بدون +)
    if (cleaned.startsWith('9647') && cleaned.length == 13) {
      return '+$cleaned';
    }
    
    // إذا بدأ بـ 07
    if (cleaned.startsWith('07') && cleaned.length == 11) {
      return '+964${cleaned.substring(1)}';
    }
    
    // إذا بدأ بـ 7 فقط وله 10 أرقام
    if (cleaned.startsWith('7') && cleaned.length == 10) {
      return '+964$cleaned';
    }
    
    // إذا كان الرقم يحتوي على 10 أرقام وليس له بادئة
    if (RegExp(r'^[0-9]{10}$').hasMatch(cleaned)) {
      return '+964$cleaned';
    }
    
    // إرجاع الرقم كما هو إذا كان يحتوي على +
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // إرجاع الرقم كما هو
    return cleaned;
  }

  // توحيد الرقم التركي
  // يدعم: +905xxxxxxxxx, 905xxxxxxxxx, 05xxxxxxxxx, 5xxxxxxxxx
  static String normalizeTurkishPhone(String phone) {
    // إزالة المسافات والرموز الخاصة
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // إذا بدأ بـ +90
    if (cleaned.startsWith('+90')) {
      return cleaned; // إرجاعه كما هو
    }
    
    // إذا بدأ بـ 90 (بدون +)
    if (cleaned.startsWith('90') && cleaned.length >= 12) {
      return '+$cleaned';
    }
    
    // إذا بدأ بـ 05
    if (cleaned.startsWith('05') && cleaned.length == 11) {
      return '+90${cleaned.substring(1)}';
    }
    
    // إذا بدأ بـ 5 فقط وله 10 أرقام
    if (cleaned.startsWith('5') && cleaned.length == 10) {
      return '+90$cleaned';
    }
    
    // إرجاع الرقم كما هو إذا كان يحتوي على +
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // إرجاع الرقم كما هو
    return cleaned;
  }

  // توحيد أي رقم (عراقي أو تركي)
  static String normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // إذا بدأ بـ +90 (تركي)
    if (cleaned.startsWith('+90') || cleaned.startsWith('90')) {
      return normalizeTurkishPhone(phone);
    }
    
    // إذا بدأ بـ +964 (عراقي)
    if (cleaned.startsWith('+964') || cleaned.startsWith('964')) {
      return normalizeIraqiPhone(phone);
    }
    
    // إذا بدأ بـ 05 (تركي)
    if (cleaned.startsWith('05') && cleaned.length == 11) {
      return normalizeTurkishPhone(phone);
    }
    
    // إذا بدأ بـ 07 (عراقي)
    if (cleaned.startsWith('07') && cleaned.length == 11) {
      return normalizeIraqiPhone(phone);
    }
    
    // افتراض أنه عراقي إذا لم يكن معروف
    return normalizeIraqiPhone(phone);
  }

  // التحقق من صحة الرقم العراقي
  static bool isValidIraqiPhone(String phone) {
    final normalized = normalizeIraqiPhone(phone);
    // الرقم العراقي يجب أن يكون +9647xxxxxxxxx (13 رقم بعد +)
    return RegExp(r'^\+9647[0-9]{9}$').hasMatch(normalized);
  }

  // التحقق من صحة الرقم التركي
  static bool isValidTurkishPhone(String phone) {
    final normalized = normalizeTurkishPhone(phone);
    // الرقم التركي يجب أن يكون +905xxxxxxxxx (13 رقم بعد +)
    // التركية: +90 + 5 + 9 أرقام = 13 رقم بعد +
    return RegExp(r'^\+905[0-9]{9}$').hasMatch(normalized);
  }

  // التحقق من صحة أي رقم (عراقي أو تركي)
  static bool isValidPhone(String phone) {
    return isValidIraqiPhone(phone) || isValidTurkishPhone(phone);
  }
}











