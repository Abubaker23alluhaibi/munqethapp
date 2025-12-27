import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../core/storage/secure_storage_service.dart';
import 'dart:convert';

/// Provider لإدارة سلة التسوق
class CartProvider with ChangeNotifier {
  Map<String, int> _cartItems = {}; // productId -> quantity
  Map<String, Product> _products = {}; // productId -> Product
  bool _isLoading = false;

  // Getters
  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  Map<String, Product> get products => Map.unmodifiable(_products);
  bool get isLoading => _isLoading;
  int get itemCount => _cartItems.values.fold(0, (sum, quantity) => sum + quantity);
  bool get isEmpty => _cartItems.isEmpty;

  /// حساب المجموع الكلي
  double get total {
    double total = 0;
    for (var entry in _cartItems.entries) {
      final product = _products[entry.key];
      if (product != null) {
        total += product.price * entry.value;
      }
    }
    return total;
  }

  /// الحصول على قائمة المنتجات في السلة
  List<Product> get cartProducts {
    return _cartItems.entries
        .map((entry) => _products[entry.key])
        .where((product) => product != null)
        .cast<Product>()
        .toList();
  }

  CartProvider() {
    _loadCartFromStorage();
  }

  /// إضافة منتج للسلة
  void addToCart(Product product, {int quantity = 1}) {
    _products[product.id] = product;
    _cartItems[product.id] = (_cartItems[product.id] ?? 0) + quantity;
    _saveCartToStorage();
    notifyListeners();
  }

  /// إزالة منتج من السلة
  void removeFromCart(String productId, {int quantity = 1}) {
    if (_cartItems.containsKey(productId)) {
      final currentQuantity = _cartItems[productId]!;
      if (currentQuantity <= quantity) {
        _cartItems.remove(productId);
        _products.remove(productId);
      } else {
        _cartItems[productId] = currentQuantity - quantity;
      }
      _saveCartToStorage();
      notifyListeners();
    }
  }

  /// تحديث كمية منتج
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    if (_cartItems.containsKey(productId)) {
      _cartItems[productId] = quantity;
      _saveCartToStorage();
      notifyListeners();
    }
  }

  /// الحصول على كمية منتج
  int getQuantity(String productId) {
    return _cartItems[productId] ?? 0;
  }

  /// التحقق من وجود منتج في السلة
  bool isInCart(String productId) {
    return _cartItems.containsKey(productId) && _cartItems[productId]! > 0;
  }

  /// مسح السلة
  void clearCart() {
    _cartItems.clear();
    _products.clear();
    _saveCartToStorage();
    notifyListeners();
  }

  /// حفظ السلة في Storage
  Future<void> _saveCartToStorage() async {
    try {
      final cartData = {
        'items': _cartItems,
        'products': _products.map((key, value) => MapEntry(key, value.toJson())),
      };
      final json = jsonEncode(cartData);
      await SecureStorageService.setString('shopping_cart', json);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  /// تحميل السلة من Storage
  Future<void> _loadCartFromStorage() async {
    _setLoading(true);

    try {
      final cartJson = await SecureStorageService.getString('shopping_cart');
      if (cartJson != null && cartJson.isNotEmpty) {
        final cartData = jsonDecode(cartJson) as Map<String, dynamic>;
        
        // تحميل المنتجات
        if (cartData['products'] != null) {
          final productsMap = cartData['products'] as Map<String, dynamic>;
          _products = productsMap.map((key, value) => 
            MapEntry(key, Product.fromJson(value as Map<String, dynamic>))
          );
        }

        // تحميل الكميات
        if (cartData['items'] != null) {
          _cartItems = Map<String, int>.from(
            (cartData['items'] as Map).map((key, value) => 
              MapEntry(key as String, value as int)
            )
          );
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}









