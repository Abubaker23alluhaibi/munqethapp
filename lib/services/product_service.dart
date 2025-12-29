import '../models/product.dart';
import '../core/api/api_service_improved.dart';
import 'admin_service.dart';

class ProductService {
  final ApiServiceImproved _apiService = ApiServiceImproved();

  // الحصول على جميع المنتجات
  Future<List<Product>> getAllProducts(String supermarketId) async {
    try {
      final response = await _apiService.get('/products', queryParameters: {
        'supermarketId': supermarketId,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        final products = jsonList
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        return products;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // الحصول على منتج بالـ ID
  Future<Product?> getProductById(String id, String supermarketId) async {
    try {
      final response = await _apiService.get('/products/$id');
      if (response.statusCode == 200 && response.data != null) {
        final product = Product.fromJson(response.data as Map<String, dynamic>);
        // التحقق من أن المنتج ينتمي إلى السوبر ماركت المطلوب
        if (product.supermarketId == supermarketId) {
          return product;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // إضافة منتج جديد
  Future<Product?> addProduct(Product product) async {
    try {
      // إزالة id من البيانات عند إنشاء منتج جديد لأن الـ backend يولد _id تلقائياً
      final data = product.toJson();
      data.remove('id');
      data.remove('_id');
      
      final response = await _apiService.post('/products', data: data);
      
      if (response.statusCode == 201 && response.data != null) {
        final addedProduct = Product.fromJson(response.data as Map<String, dynamic>);
        return addedProduct;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // تحديث منتج
  Future<Product?> updateProduct(Product product) async {
    try {
      // إزالة id من البيانات لأن الـ backend يستخدم id من URL
      final data = product.toJson();
      data.remove('id');
      data.remove('_id');
      
      final response = await _apiService.put('/products/${product.id}', data: data);
      
      if (response.statusCode == 200 && response.data != null) {
        final updatedProduct = Product.fromJson(response.data as Map<String, dynamic>);
        return updatedProduct;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // حذف منتج
  Future<bool> deleteProduct(String id, String supermarketId) async {
    try {
      final response = await _apiService.delete('/products/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // البحث في المنتجات
  Future<List<Product>> searchProducts(String query, String supermarketId) async {
    try {
      if (query.isEmpty) {
        return await getAllProducts(supermarketId);
      }

      final response = await _apiService.get('/products/search', queryParameters: {
        'q': query,
        'supermarketId': supermarketId,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // فلترة حسب الفئة
  Future<List<Product>> getProductsByCategory(
      String category, String supermarketId) async {
    try {
      final allProducts = await getAllProducts(supermarketId);
      if (category.isEmpty) {
        return allProducts;
      }
      return allProducts.where((p) => p.category == category).toList();
    } catch (e) {
      return [];
    }
  }

  // الحصول على جميع الفئات
  Future<List<String>> getCategories(String supermarketId) async {
    try {
      final products = await getAllProducts(supermarketId);
      final categories = products.map((p) => p.category).toSet().toList();
      return categories;
    } catch (e) {
      return [];
    }
  }

  // الحصول على جميع المنتجات من جميع السوبر ماركتات (سوبر ماركت المنقذ فقط)
  // Backward compatibility method
  Future<List<Product>> getAllProductsFromAllSupermarkets() async {
    try {
      // الحصول على سوبر ماركت المنقذ من الـ admin service
      final adminService = AdminService();
      final supermarket = await adminService.getOrCreateAdminSupermarket();
      
      // استخدام الـ _id الصحيح من MongoDB
      return await getAllProducts(supermarket.id);
    } catch (e) {
      // Fallback: محاولة استخدام MUNQETH_SHOP
      return await getAllProducts('MUNQETH_SHOP');
    }
  }
}