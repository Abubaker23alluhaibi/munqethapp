import '../models/card.dart';
import '../models/user_card.dart';
import '../core/api/api_service_improved.dart';
import '../core/storage/secure_storage_service.dart';
import '../utils/phone_utils.dart';
import '../core/utils/app_logger.dart';
import 'dart:convert';

class CardService {
  final ApiServiceImproved _apiService = ApiServiceImproved();
  static const String _userCardsKey = 'user_cards';

  String _canonicalPhone(String phone) {
    // إزالة كل شيء ما عدا الأرقام
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    // إزالة الصفر في البداية إذا كان موجوداً (لكن نحتفظ به إذا كان الرقم يبدأ بـ 0 فقط)
    // إذا كان الرقم يبدأ بـ 0 وله أكثر من رقم واحد، نزيل الصفر
    if (cleaned.length > 1 && cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
      AppLogger.d('_canonicalPhone: Removed leading zero from $phone -> $cleaned');
    }
    return cleaned;
  }

  // الحصول على جميع البطاقات
  Future<List<Card>> getAllCards() async {
    try {
      final response = await _apiService.get('/cards');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Card.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting all cards', e);
      return [];
    }
  }

  // البحث عن بطاقة بالكود
  Future<Card?> getCardByCode(String code) async {
    try {
      final response = await _apiService.get('/cards/code/$code');
      if (response.statusCode == 200 && response.data != null) {
        return Card.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error getting card by code', e);
      return null;
    }
  }

  // إنشاء بطاقة جديدة
  Future<Card?> createCard(int amount) async {
    try {
      if (amount != 5000 && amount != 10000 && amount != 25000) {
        throw Exception('المبلغ يجب أن يكون 5000 أو 10000 أو 25000');
      }

      final response = await _apiService.post('/cards', data: {
        'amount': amount,
      });
      
      if (response.statusCode == 201 && response.data != null) {
        return Card.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error creating card', e);
      return null;
    }
  }

  // استخدام بطاقة (استبدال البطاقة)
  Future<bool> redeemCard(String code, String userPhone, {bool addToWallet = true}) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final canonicalPhone = _canonicalPhone(normalizedPhone);
      final response = await _apiService.post('/cards/redeem', data: {
        'code': code,
        'phone': canonicalPhone, // نرسل رقم بدون رموز لتطابق الباكند
      });
      
      if (response.statusCode == 200) {
        // الرصيد تم إضافته إلى walletBalance في السيرفر تلقائياً
        // نحفظ البطاقة كمحفظة محلية أيضاً للتوافق
        if (response.data != null) {
          final cardData = response.data as Map<String, dynamic>;
          await _addUserCard(canonicalPhone, Card.fromJson(cardData));
        } else {
          // احتياط: إذا لم يرجع السيرفر البيانات نحاول جلبها ثم الحفظ
          final card = await getCardByCode(code);
          if (card != null) {
            await _addUserCard(canonicalPhone, card);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('Error redeeming card', e);
      return false;
    }
  }

  // إضافة بطاقة للمستخدم (للاستخدام في الدفع)
  Future<void> _addUserCard(String userPhone, Card card) async {
    try {
      // تطبيع الرقم أولاً
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final canonicalPhone = _canonicalPhone(normalizedPhone);
      AppLogger.d('Adding card ${card.id} (amount: ${card.amount}) to user: $canonicalPhone (from: $userPhone)');
      final userCards = await getUserCards(normalizedPhone);
      final userCard = UserCard(
        id: card.id,
        code: card.code,
        amount: card.amount,
        userPhone: canonicalPhone,
        addedAt: DateTime.now(),
      );
      userCards.add(userCard);
      await _saveUserCards(normalizedPhone, userCards);
      AppLogger.d('Card added successfully. Total cards: ${userCards.length}, Total balance: ${userCards.fold<int>(0, (sum, c) => sum + c.amount)}');
    } catch (e) {
      AppLogger.e('Error adding user card', e);
    }
  }

  // حفظ بطاقات المستخدم
  Future<void> _saveUserCards(String userPhone, List<UserCard> cards) async {
    try {
      // تطبيع الرقم أولاً (في حالة كان normalized أو canonical)
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final canonicalPhone = _canonicalPhone(normalizedPhone);
      final jsonList = cards.map((card) => card.toJson()).toList();
      final json = jsonEncode(jsonList);
      final storageKey = '${_userCardsKey}_$canonicalPhone';
      await SecureStorageService.setString(storageKey, json);
      AppLogger.d('Saved ${cards.length} cards for user: $canonicalPhone (storage key: $storageKey)');
      AppLogger.d('Total balance saved: ${cards.fold<int>(0, (sum, card) => sum + card.amount)}');
    } catch (e) {
      AppLogger.e('Error saving user cards', e);
    }
  }

  // الحصول على بطاقات المستخدم (من التخزين المحلي - لأنها بيانات مؤقتة)
  Future<List<UserCard>> getUserCards(String userPhone) async {
    try {
      // تطبيع الرقم أولاً
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final canonicalPhone = _canonicalPhone(normalizedPhone);
      
      AppLogger.d('getUserCards called with phone: $userPhone');
      AppLogger.d('Normalized to: $normalizedPhone');
      AppLogger.d('Canonical: $canonicalPhone');
      
      // قراءة من التخزين المحلي أولاً
      // جرب عدة أشكال من المفاتيح للتأكد من التطابق
      final storageKey = '${_userCardsKey}_$canonicalPhone';
      
      // إنشاء قائمة بجميع المفاتيح المحتملة (مع وبدون الصفر في البداية)
      final possibleKeys = <String>[
        storageKey, // المفتاح الأساسي (canonicalPhone)
      ];
      
      // إضافة المفتاح بدون الصفر في البداية إذا كان موجوداً
      if (canonicalPhone.startsWith('0') && canonicalPhone.length > 1) {
        final withoutLeadingZero = canonicalPhone.substring(1);
        possibleKeys.add('${_userCardsKey}_$withoutLeadingZero');
      }
      
      // إضافة المفتاح مع الصفر في البداية إذا لم يكن موجوداً
      if (!canonicalPhone.startsWith('0') && canonicalPhone.isNotEmpty) {
        possibleKeys.add('${_userCardsKey}_0$canonicalPhone');
      }
      
      // إضافة المفاتيح الأخرى
      possibleKeys.add('${_userCardsKey}_$normalizedPhone');
      final canonicalFromOriginal = _canonicalPhone(userPhone);
      possibleKeys.add('${_userCardsKey}_$canonicalFromOriginal');
      
      // إزالة التكرارات
      final uniqueKeys = possibleKeys.toSet().toList();
      
      AppLogger.d('Looking for cards in storage with keys:');
      for (var key in uniqueKeys) {
        AppLogger.d('  - $key');
      }
      
      // جرب جميع المفاتيح المحتملة
      String? data;
      for (var key in uniqueKeys) {
        data = await SecureStorageService.getString(key);
        if (data != null && data.isNotEmpty) {
          AppLogger.d('Found data using key: $key');
          break;
        }
      }
      
      if (data != null && data.isNotEmpty) {
        AppLogger.d('Found data in local storage, length: ${data.length}');
        try {
          final List<dynamic> jsonList = jsonDecode(data);
          final cards = jsonList
              .map((json) => UserCard.fromJson(json as Map<String, dynamic>))
              .toList();
          AppLogger.d('Loaded ${cards.length} cards from local storage for phone: $canonicalPhone');
          AppLogger.d('Total balance: ${cards.fold<int>(0, (sum, card) => sum + card.amount)}');
          return cards;
        } catch (e) {
          AppLogger.e('Error parsing local cards data', e);
          AppLogger.d('Data content: ${data.substring(0, data.length > 200 ? 200 : data.length)}...');
          // إذا كان هناك خطأ في parsing، نعيد قائمة فارغة
          return [];
        }
      } else {
        AppLogger.d('No data found in local storage for key: $storageKey');
      }

      // إذا لم يوجد تخزين محلي نحاول الجلب من السيرفر (بطاقات مستخدمة لهذا الهاتف)
      // لكن إذا فشل الطلب، نعيد قائمة فارغة بدلاً من إخفاء الأخطاء
      try {
        final response = await _apiService.get('/cards/user/$canonicalPhone');
        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> jsonList = response.data;
          final serverCards = jsonList
              .map((json) => Card.fromJson(json as Map<String, dynamic>))
              .toList();
          final userCards = serverCards
              .map((card) => UserCard(
                    id: card.id,
                    code: card.code,
                    amount: card.amount,
                    userPhone: canonicalPhone,
                    addedAt: card.usedAt ?? DateTime.now(),
                    lastUsedAt: card.usedAt,
                  ))
              .toList();
          await _saveUserCards(canonicalPhone, userCards);
          AppLogger.d('Loaded ${userCards.length} cards from server for phone: $canonicalPhone');
          return userCards;
        } else {
          AppLogger.w('Server returned status ${response.statusCode} for cards/user/$canonicalPhone');
        }
      } catch (e) {
        // إذا فشل الطلب من السيرفر (مثل 404)، نطبع الخطأ لكن نعيد قائمة فارغة
        // لأن البيانات المحلية هي المصدر الأساسي
        AppLogger.d('Error loading cards from server (this is OK if endpoint doesn\'t exist)', e);
      }
    } catch (e) {
      AppLogger.e('Error loading user cards', e);
    }
    AppLogger.d('No cards found for phone: ${_canonicalPhone(userPhone)}');
    return [];
  }

  // الحصول على بطاقات المستخدم الحالي
  Future<List<UserCard>> getCurrentUserCards() async {
    try {
      final userPhone = await SecureStorageService.getString('user_phone');
      if (userPhone != null) {
        return await getUserCards(userPhone);
      }
    } catch (e) {
      AppLogger.e('Error getting current user cards', e);
    }
    return [];
  }

  // استخدام بطاقة للدفع (تحديث محلي فقط - البيانات الفعلية في السيرفر)
  Future<bool> useCardForPayment(String userPhone, String cardId, int amount) async {
    try {
      // تطبيع رقم الهاتف أولاً
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final userCards = await getUserCards(normalizedPhone);
      final cardIndex = userCards.indexWhere((card) => card.id == cardId);
      
      if (cardIndex == -1) {
        return false; // البطاقة غير موجودة
      }

      final card = userCards[cardIndex];
      
      if (card.amount < amount) {
        return false; // الرصيد غير كافي
      }

      // تحديث رصيد البطاقة محلياً
      final newAmount = card.amount - amount;
      if (newAmount > 0) {
        userCards[cardIndex] = card.copyWith(
          amount: newAmount,
          lastUsedAt: DateTime.now(),
        );
      } else {
        // حذف البطاقة إذا نفد رصيدها
        userCards.removeAt(cardIndex);
      }
      
      await _saveUserCards(normalizedPhone, userCards);
      return true;
    } catch (e) {
      AppLogger.e('Error using card for payment', e);
      return false;
    }
  }

  // الحصول على إجمالي رصيد البطاقات للمستخدم
  Future<int> getUserCardsTotalBalance(String userPhone) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final userCards = await getUserCards(normalizedPhone);
      return userCards.fold<int>(0, (int sum, UserCard card) => sum + card.amount);
    } catch (e) {
      AppLogger.e('Error getting user cards total balance', e);
      return 0;
    }
  }

  // الحصول على إجمالي رصيد البطاقات للمستخدم الحالي
  Future<int> getCurrentUserCardsTotalBalance() async {
    try {
      final userPhone = await SecureStorageService.getString('user_phone');
      if (userPhone != null) {
        return await getUserCardsTotalBalance(userPhone);
      }
    } catch (e) {
      AppLogger.e('Error getting current user cards total balance', e);
    }
    return 0;
  }

  // الحصول على إحصائيات البطاقات
  Future<Map<String, int>> getCardStatistics() async {
    try {
      final cards = await getAllCards();
      return {
        'total': cards.length,
        'used': cards.where((card) => card.isUsed).length,
        'unused': cards.where((card) => !card.isUsed).length,
        'total5000': cards.where((card) => card.amount == 5000).length,
        'total10000': cards.where((card) => card.amount == 10000).length,
        'total25000': cards.where((card) => card.amount == 25000).length,
      };
    } catch (e) {
      AppLogger.e('Error getting card statistics', e);
      return {};
    }
  }

  // استرجاع مبلغ إلى محفظة المستخدم (إضافة إلى البطاقة)
  Future<bool> refundToWallet(String userPhone, int amount) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final userCards = await getUserCards(normalizedPhone);
      
      if (userCards.isEmpty) {
        AppLogger.d('No cards found for refund - creating new card entry');
        // إذا لم توجد بطاقات، نضيف بطاقة جديدة
        final newCard = UserCard(
          id: 'refund_${DateTime.now().millisecondsSinceEpoch}',
          code: 'REFUND',
          amount: amount,
          userPhone: _canonicalPhone(normalizedPhone),
          addedAt: DateTime.now(),
        );
        await _saveUserCards(_canonicalPhone(normalizedPhone), [newCard]);
        return true;
      }
      
      // نضيف المبلغ للبطاقة الأولى (أو الأكبر)
      final sortedCards = List<UserCard>.from(userCards);
      sortedCards.sort((a, b) => b.amount.compareTo(a.amount));
      final firstCard = sortedCards[0];
      
      final updatedCard = firstCard.copyWith(
        amount: firstCard.amount + amount,
        lastUsedAt: DateTime.now(),
      );
      
      final cardIndex = userCards.indexWhere((c) => c.id == firstCard.id);
      if (cardIndex != -1) {
        userCards[cardIndex] = updatedCard;
        await _saveUserCards(_canonicalPhone(normalizedPhone), userCards);
        AppLogger.d('Refunded $amount to wallet. New balance: ${updatedCard.amount}');
        return true;
      }
      
      return false;
    } catch (e) {
      AppLogger.e('Error refunding to wallet', e);
      return false;
    }
  }

  // استرجاع مبلغ إلى بطاقة محددة
  Future<bool> refundToCard(String userPhone, String cardId, int amount) async {
    try {
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final userCards = await getUserCards(normalizedPhone);
      final cardIndex = userCards.indexWhere((card) => card.id == cardId);
      
      if (cardIndex == -1) {
        AppLogger.w('Card not found for refund: $cardId');
        // إذا لم توجد البطاقة، نحاول استرجاعها للمحفظة عموماً
        return await refundToWallet(userPhone, amount);
      }

      final card = userCards[cardIndex];
      final updatedCard = card.copyWith(
        amount: card.amount + amount,
        lastUsedAt: DateTime.now(),
      );
      
      userCards[cardIndex] = updatedCard;
      await _saveUserCards(_canonicalPhone(normalizedPhone), userCards);
      AppLogger.d('Refunded $amount to card $cardId. New balance: ${updatedCard.amount}');
      return true;
    } catch (e) {
      AppLogger.e('Error refunding to card', e);
      return false;
    }
  }

  // خصم من محفظة المستخدم (من السيرفر أولاً)
  Future<bool> deductFromWallet(String userPhone, int amount) async {
    try {
      // تطبيع رقم الهاتف
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      AppLogger.d('Attempting to deduct $amount from wallet');
      AppLogger.d('Original phone: $userPhone');
      AppLogger.d('Normalized phone: $normalizedPhone');
      
      // محاولة الخصم من السيرفر أولاً
      try {
        final response = await _apiService.put('/users/phone/$normalizedPhone/wallet/deduct', data: {
          'amount': amount,
        });
        
        if (response.statusCode == 200) {
          AppLogger.d('Successfully deducted $amount from wallet on server');
          // تحديث التخزين المحلي أيضاً للتوافق
          await _updateLocalCardsAfterDeduction(normalizedPhone, amount);
          return true;
        } else if (response.statusCode == 400) {
          // الرصيد غير كافٍ
          AppLogger.w('Insufficient wallet balance on server');
          return false;
        }
      } catch (e) {
        AppLogger.w('Error deducting from server wallet, trying local: $e');
      }
      
      // إذا فشل الخصم من السيرفر، نستخدم الطريقة المحلية (للتوافق مع البيانات القديمة)
      final userCards = await getUserCards(normalizedPhone);
      AppLogger.d('Found ${userCards.length} cards for user');
      
      if (userCards.isEmpty) {
        AppLogger.w('No cards found for user - returning false');
        return false;
      }
      
      final totalBalance = userCards.fold<int>(0, (sum, card) => sum + card.amount);
      AppLogger.d('Total wallet balance: $totalBalance, Required: $amount');
      
      if (totalBalance < amount) {
        AppLogger.w('Insufficient balance: $totalBalance < $amount');
        return false; // الرصيد غير كافٍ
      }

      int remaining = amount;
      // نخصم من البطاقات بالترتيب (الأكبر أولاً)
      final sortedCards = List<UserCard>.from(userCards);
      sortedCards.sort((a, b) => b.amount.compareTo(a.amount));

      for (final card in sortedCards) {
        if (remaining <= 0) break;
        final deduct = remaining <= card.amount ? remaining : card.amount;
        AppLogger.d('Deducting $deduct from card ${card.id} (balance: ${card.amount})');
        final success = await useCardForPayment(normalizedPhone, card.id, deduct);
        if (!success) {
          AppLogger.w('Failed to deduct from card ${card.id}');
          continue;
        }
        remaining -= deduct;
        AppLogger.d('Remaining amount to deduct: $remaining');
      }

      final success = remaining <= 0;
      AppLogger.d('Deduction ${success ? "succeeded" : "failed"}. Remaining: $remaining');
      return success;
    } catch (e) {
      AppLogger.e('Error in deductFromWallet', e);
      return false;
    }
  }
  
  // تحديث البطاقات المحلية بعد الخصم (للتوافق)
  Future<void> _updateLocalCardsAfterDeduction(String userPhone, int amount) async {
    try {
      final userCards = await getUserCards(userPhone);
      if (userCards.isEmpty) return;
      
      int remaining = amount;
      final sortedCards = List<UserCard>.from(userCards);
      sortedCards.sort((a, b) => b.amount.compareTo(a.amount));
      
      for (final card in sortedCards) {
        if (remaining <= 0) break;
        final deduct = remaining <= card.amount ? remaining : card.amount;
        final cardIndex = userCards.indexWhere((c) => c.id == card.id);
        if (cardIndex != -1) {
          final newAmount = card.amount - deduct;
          if (newAmount > 0) {
            userCards[cardIndex] = card.copyWith(
              amount: newAmount,
              lastUsedAt: DateTime.now(),
            );
          } else {
            userCards.removeAt(cardIndex);
          }
        }
        remaining -= deduct;
      }
      
      await _saveUserCards(userPhone, userCards);
    } catch (e) {
      AppLogger.e('Error updating local cards after deduction', e);
    }
  }

  // الحصول على رصيد محفظة المستخدم (من السيرفر أولاً، ثم المحلي كبديل)
  Future<int> getUserWalletBalance(String userPhone) async {
    try {
      // محاولة جلب الرصيد من السيرفر أولاً
      final normalizedPhone = PhoneUtils.normalizePhone(userPhone);
      final response = await _apiService.get('/users/phone/$normalizedPhone/wallet');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final serverBalance = data['walletBalance'] as int? ?? 0;
        
        // تحديث التخزين المحلي بالرصيد من السيرفر
        // لكن نحتفظ بالبطاقات المحلية أيضاً للتوافق
        AppLogger.d('Wallet balance from server: $serverBalance');
        return serverBalance;
      }
    } catch (e) {
      AppLogger.d('Error getting wallet balance from server, using local: $e');
    }
    
    // إذا فشل جلب الرصيد من السيرفر، نستخدم الرصيد المحلي
    return await getUserCardsTotalBalance(userPhone);
  }

  // حذف بطاقة
  Future<bool> deleteCard(String cardId) async {
    // يمكن إضافة endpoint في الباكند لاحقاً
    return false; // غير مدعوم حالياً
  }
}