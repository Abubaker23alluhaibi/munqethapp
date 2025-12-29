import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api/api_service_improved.dart';
import '../utils/constants.dart';

class ImageService {
  final ApiServiceImproved _apiService = ApiServiceImproved();

  /// رفع صورة واحدة إلى السيرفر
  /// يُرجع URL الصورة من Cloudinary
  Future<String?> uploadImage(File imageFile) async {
    try {
      // التحقق من وجود الملف
      if (!await imageFile.exists()) {
        return null;
      }

      final fileName = imageFile.path.split('/').last;
      
      // إنشاء FormData
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      // إرسال الطلب
      // لا نحتاج لتعيين Content-Type يدوياً، Dio سيقوم بذلك تلقائياً
      final response = await _apiService.post(
        '/images/upload',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final imageUrl = response.data['url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      return null;
    }
  }

  /// رفع عدة صور إلى السيرفر
  Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    try {
      final formData = FormData();
      
      for (var imageFile in imageFiles) {
        final fileName = imageFile.path.split('/').last;
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              imageFile.path,
              filename: fileName,
            ),
          ),
        );
      }

      // لا نحتاج لتعيين Content-Type يدوياً، Dio سيقوم بذلك تلقائياً
      final response = await _apiService.post(
        '/images/upload-multiple',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final images = response.data['images'] as List<dynamic>?;
        if (images != null) {
          return images
              .map((img) => img['url'] as String)
              .where((url) => url.isNotEmpty)
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
}

