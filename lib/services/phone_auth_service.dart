import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/phone_utils.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;

  /// إرسال رمز OTP للرقم المحدد
  Future<void> sendOTP(String phoneNumber) async {
    // إعادة تعيين verificationId قبل محاولة جديدة
    _verificationId = null;
    _resendToken = null;
    
    final completer = Completer<void>();
    FirebaseAuthException? authException;
    
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phoneNumber);
      final formattedPhone = _formatPhoneForFirebase(normalizedPhone);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-verification (Android only - يحدث تلقائياً في بعض الحالات)
          // يمكن استخدام هذا لاحقاً لتسجيل الدخول التلقائي
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // طباعة الخطأ بالكامل للتحقق
          print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
          authException = e;
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        timeout: const Duration(seconds: 60),
      );
      
      // انتظار إكمال العملية
      await completer.future;
      
      // التحقق من أن verificationId تم تعيينه
      if (_verificationId == null && authException == null) {
        throw Exception('فشل إرسال رمز التحقق. يرجى المحاولة مرة أخرى');
      }
      
    } catch (e) {
      // إعادة تعيين verificationId في حالة الخطأ
      _verificationId = null;
      _resendToken = null;
      
      if (e is FirebaseAuthException || authException != null) {
        final exception = e is FirebaseAuthException ? e : authException!;
        print('❌ Firebase Auth Error: ${exception.code} - ${exception.message}');
        
        // التحقق من أخطاء Firebase API المحظورة
        final errorMessage = exception.message ?? '';
        if (errorMessage.contains('blocked') || 
            errorMessage.contains('403') ||
            errorMessage.contains('identitytoolkit')) {
          throw Exception('خدمة Firebase غير متاحة حالياً. يرجى التحقق من إعدادات Firebase أو المحاولة لاحقاً');
        }
        
        throw Exception(_getErrorMessage(exception.code));
      }
      
      // التحقق من الرسالة إذا كانت تحتوي على BILLING_NOT_ENABLED
      final errorMessage = e.toString();
      if (errorMessage.contains('BILLING_NOT_ENABLED') || errorMessage.contains('billing')) {
        throw Exception('خدمة الفواتير غير مفعلة في Firebase. يرجى تفعيل Billing من Firebase Console');
      }
      
      // التحقق من أخطاء Firebase API المحظورة في الرسالة
      if (errorMessage.contains('blocked') || 
          errorMessage.contains('403') ||
          errorMessage.contains('identitytoolkit')) {
        throw Exception('خدمة Firebase غير متاحة حالياً. يرجى التحقق من إعدادات Firebase أو المحاولة لاحقاً');
      }
      
      throw Exception('فشل إرسال رمز التحقق: $e');
    }
  }

  /// إعادة إرسال رمز OTP
  Future<void> resendOTP(String phoneNumber) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(phoneNumber);
      final formattedPhone = _formatPhoneForFirebase(normalizedPhone);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          throw Exception(_getErrorMessage(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception(_getErrorMessage(e.code));
      }
      throw Exception('فشل إعادة إرسال رمز التحقق: $e');
    }
  }

  /// التحقق من رمز OTP
  Future<UserCredential> verifyOTP(String otpCode) async {
    try {
      if (_verificationId == null) {
        throw Exception('لم يتم إرسال رمز التحقق بعد. يرجى إرسال الرمز أولاً');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode.trim(),
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // إعادة تعيين verificationId بعد الاستخدام
      _verificationId = null;
      _resendToken = null;
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      throw Exception('رمز التحقق غير صحيح: $e');
    }
  }

  /// تحويل رقم الهاتف لصيغة Firebase (مطلوب +964 أو +90...)
  String _formatPhoneForFirebase(String phone) {
    // استخدام PhoneUtils.normalizePhone الذي يدعم العراقي والتركي
    // وإرجاعه كما هو إذا كان يبدأ بـ + (الصيغة الصحيحة لـ Firebase)
    final normalized = PhoneUtils.normalizePhone(phone);
    
    // إذا كان الرقم يبدأ بـ +، إرجاعه كما هو (الصيغة الصحيحة)
    if (normalized.startsWith('+')) {
      return normalized;
    }
    
    // إذا لم يكن يبدأ بـ +، محاولة إضافته
    // لكن normalizePhone يجب أن يرجع رقم بصيغة +XX...
    // لذا هذا يجب ألا يحدث، لكن للاحتياط:
    if (normalized.startsWith('90')) {
      return '+$normalized';
    }
    if (normalized.startsWith('964')) {
      return '+$normalized';
    }
    
    return normalized;
  }

  /// الحصول على رسالة خطأ بالعربية
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح';
      case 'too-many-requests':
        return 'تم إرسال طلبات كثيرة. يرجى المحاولة لاحقاً';
      case 'quota-exceeded':
        return 'تم تجاوز الحد المسموح. يرجى المحاولة لاحقاً';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح';
      case 'session-expired':
        return 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت';
      case 'billing-not-enabled':
      case 'BILLING_NOT_ENABLED':
        return 'خدمة الفواتير غير مفعلة في Firebase. يرجى تفعيلها من Firebase Console أو استخدام رقم اختبار';
      default:
        // التحقق من الرسالة الأصلية إذا كانت تحتوي على BILLING_NOT_ENABLED
        if (code.toLowerCase().contains('billing')) {
          return 'خدمة الفواتير غير مفعلة في Firebase. يرجى تفعيل Billing من Firebase Console';
        }
        return 'حدث خطأ أثناء التحقق: $code';
    }
  }

  /// تسجيل الخروج من Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }

  /// التحقق من وجود مستخدم مسجل حالياً
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// مسح verificationId (لإعادة الإرسال)
  void clearVerificationId() {
    _verificationId = null;
  }
}

