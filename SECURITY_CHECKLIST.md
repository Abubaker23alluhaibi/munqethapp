# قائمة التحقق الأمنية - Security Checklist

## ✅ قبل الرفع على المتاجر

### 1. الملفات الحساسة
- [x] ✅ `keystore.properties` محمي في `.gitignore`
- [x] ✅ `*.keystore` و `*.jks` محمية
- [x] ✅ `google-services.json` محمي
- [ ] ⚠️ تأكد من عدم وجود API keys في `strings.xml`
- [ ] ⚠️ تأكد من عدم وجود API keys في `AppDelegate.swift`

### 2. التخزين الآمن
- [x] ✅ استخدام `FlutterSecureStorage` للبيانات الحساسة
- [x] ✅ Tokens محفوظة بشكل آمن
- [x] ✅ Passwords غير محفوظة (يتم إرسالها فقط)

### 3. أمان الشبكة
- [x] ✅ HTTPS فقط (no HTTP)
- [x] ✅ `cleartextTraffic` معطل
- [ ] ⚠️ إضافة Certificate Pinning (اختياري)

### 4. Code Protection
- [x] ✅ ProGuard/R8 مفعّل
- [x] ✅ Code obfuscation مفعّل
- [x] ✅ Log statements محذوفة في release
- [ ] ⚠️ تنظيف `print()` statements (قيد التنفيذ)

### 5. API Security
- [x] ✅ Bearer Token Authentication
- [x] ✅ Tokens في Secure Storage
- [ ] ⚠️ إضافة Token Refresh Mechanism
- [ ] ⚠️ إضافة Auto-logout

### 6. Error Handling
- [x] ✅ Error messages لا تعرض معلومات حساسة
- [x] ✅ Stack traces مخفية في production

### 7. Permissions
- [x] ✅ فقط الصلاحيات المطلوبة
- [x] ✅ Location permissions مع descriptions واضحة

## 📋 بعد الرفع

- [ ] مراقبة Crash Reports
- [ ] مراقبة API Usage
- [ ] تحديث Dependencies بانتظام
- [ ] مراجعة Security Advisories
- [ ] اختبار Penetration Testing

## 🔍 فحص سريع

```bash
# فحص الملفات الحساسة في Git
git ls-files | grep -E "(keystore|google-services|secrets|\.env)"

# يجب أن تكون النتيجة فارغة (لا ملفات حساسة في Git)
```

## ⚠️ تحذيرات مهمة

1. **لا ترفع أبداً:**
   - `keystore.properties`
   - `*.keystore` أو `*.jks`
   - `google-services.json`
   - أي ملف يحتوي على API keys أو passwords

2. **تأكد من:**
   - جميع الملفات الحساسة في `.gitignore`
   - `.gitignore` محدث
   - لا توجد secrets في الكود

3. **قبل كل commit:**
   - راجع الملفات المضافة: `git status`
   - تأكد من عدم إضافة ملفات حساسة


