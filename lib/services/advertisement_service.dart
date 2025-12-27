import '../models/advertisement.dart';
import '../core/api/api_service_improved.dart';

class AdvertisementService {
  final ApiServiceImproved _apiService = ApiServiceImproved();

  // الحصول على جميع الإعلانات
  Future<List<Advertisement>> getAllAdvertisements() async {
    try {
      final response = await _apiService.get('/advertisements');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Advertisement.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting all advertisements: $e');
      return [];
    }
  }

  // الحصول على الإعلانات النشطة فقط
  Future<List<Advertisement>> getActiveAdvertisements() async {
    final all = await getAllAdvertisements();
    return all.where((ad) => ad.isValid).toList();
  }

  // الحصول على الإعلانات حسب نوع الخدمة
  Future<List<Advertisement>> getAdvertisementsByService(String serviceType) async {
    final all = await getAllAdvertisements();
    return all
        .where((ad) =>
            ad.isValid &&
            (ad.serviceType == serviceType || ad.serviceType == 'all'))
        .toList();
  }

  // الحصول على الإعلانات حسب السوبر ماركت
  Future<List<Advertisement>> getAdvertisementsBySupermarket(String? supermarketId) async {
    final all = await getAllAdvertisements();
    if (supermarketId == null) {
      // إعلانات عامة (بدون سوبر ماركت محدد)
      return all.where((ad) => ad.isValid && ad.supermarketId == null).toList();
    }
    // إعلانات عامة + إعلانات السوبر ماركت المحدد
    return all
        .where((ad) =>
            ad.isValid &&
            (ad.supermarketId == null || ad.supermarketId == supermarketId))
        .toList();
  }

  // الحصول على إعلان بالـ ID
  Future<Advertisement?> getAdvertisementById(String id) async {
    try {
      final response = await _apiService.get('/advertisements/$id');
      if (response.statusCode == 200 && response.data != null) {
        return Advertisement.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting advertisement by id: $e');
      return null;
    }
  }

  // إنشاء إعلان جديد
  Future<Advertisement?> createAdvertisement(Advertisement advertisement) async {
    try {
      // إزالة id من البيانات المرسلة لأن السيرفر سينشئه
      final adData = advertisement.toJson();
      adData.remove('id');
      
      final response = await _apiService.post('/advertisements', data: adData);
      
      if (response.statusCode == 201 && response.data != null) {
        return Advertisement.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error creating advertisement: $e');
      return null;
    }
  }

  // تحديث إعلان
  Future<bool> updateAdvertisement(Advertisement advertisement) async {
    try {
      final response = await _apiService.put('/advertisements/${advertisement.id}', data: advertisement.toJson());
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating advertisement: $e');
      return false;
    }
  }

  // حذف إعلان
  Future<bool> deleteAdvertisement(String id) async {
    try {
      final response = await _apiService.delete('/advertisements/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting advertisement: $e');
      return false;
    }
  }

  // الحصول على الإعلانات التي تحتوي على تنزيلات
  Future<List<Advertisement>> getAdvertisementsWithDiscount() async {
    final all = await getAllAdvertisements();
    return all
        .where((ad) => ad.isValid && ad.hasDiscount)
        .toList();
  }
}