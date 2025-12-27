import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/image_widget.dart';
import '../../core/errors/error_handler.dart';
import '../../providers/cart_provider.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _productService = ProductService();
  List<Product> _allProducts = [];
  List<Product> _displayedProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool showError = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // الحصول على جميع المنتجات
      final products = await _productService.getAllProductsFromAllSupermarkets();
      
      // الحصول على الفئات
      final categories = products.map((p) => p.category).toSet().toList();
      
      // خلط المنتجات بشكل عشوائي
      final random = math.Random();
      final shuffledProducts = List<Product>.from(products)..shuffle(random);
      
      if (mounted) {
        setState(() {
          _allProducts = products;
          _displayedProducts = shuffledProducts;
          _categories = ['الكل', ...categories];
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'حدث خطأ أثناء تحميل المنتجات';
        });
        
        if (showError) {
          ErrorHandler.showErrorSnackBar(context, e, customMessage: _errorMessage);
        }
      }
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category == null || category == 'الكل') {
        // خلط المنتجات بشكل عشوائي
        final random = math.Random();
        _displayedProducts = List<Product>.from(_allProducts)..shuffle(random);
      } else {
        // فلترة حسب الفئة وخلطها بشكل عشوائي
        final filtered = _allProducts.where((p) => p.category == category).toList();
        final random = math.Random();
        _displayedProducts = List<Product>.from(filtered)..shuffle(random);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          toolbarHeight: 60,
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icons/logoshoping.png',
                    fit: BoxFit.contain,
                    width: 35,
                    height: 35,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.shopping_cart_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'التسوق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        body: _isLoading && _allProducts.isEmpty
            ? const LoadingWidget(message: 'جاري تحميل المنتجات...')
            : RefreshIndicator(
                onRefresh: () => _loadProducts(showError: false),
                child: Column(
                children: [
                  // Categories Filter
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category || 
                              (_selectedCategory == null && category == 'الكل');
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                _filterByCategory(selected ? category : null);
                              },
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              checkmarkColor: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Products Grid
                  Expanded(
                    child: _errorMessage != null && _displayedProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _loadProducts(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _displayedProducts.isEmpty
                            ? const Center(
                                child: EmptyState(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'لا توجد منتجات متاحة',
                                  message: 'لم يتم العثور على أي منتجات',
                                ),
                              )
                            : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.68,
                            ),
                            itemCount: _displayedProducts.length,
                            itemBuilder: (context, index) {
                              final product = _displayedProducts[index];
                              return _buildProductCard(product);
                            },
                          ),
                  ),
                  // Cart Summary and Order Button
                  Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      if (cartProvider.isEmpty) return const SizedBox.shrink();
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Total Price
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المجموع الكلي',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    '${cartProvider.total.toStringAsFixed(0)} د.ع',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Order Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/shopping/order');
                                },
                                icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                                label: const Text(
                                  'اطلب الآن',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      ),
    );
  }


  Widget _buildProductCard(Product product) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final quantity = cartProvider.getQuantity(product.id);
        final isInCart = cartProvider.isInCart(product.id);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1.0,
            child: ImageWidget(
              imagePath: product.image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: Container(
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.image,
                  color: Colors.grey[400],
                  size: 32,
                ),
              ),
            ),
          ),
          // Product Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Name
                Flexible(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Price
                Text(
                  '${product.price.toStringAsFixed(0)} د.ع',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 6),
                // Add to Cart Button or Quantity Controls
                if (!isInCart)
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => cartProvider.addToCart(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  )
                else
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        GestureDetector(
                          onTap: () => cartProvider.removeFromCart(product.id),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.remove_circle,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        Text(
                          quantity.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 14,
                              ),
                        ),
                        GestureDetector(
                          onTap: () => cartProvider.addToCart(product),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.add_circle,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
