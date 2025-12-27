import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../widgets/image_widget.dart';
import '../../models/product.dart';
import '../../models/supermarket.dart';
import '../../services/supermarket_service.dart';
import '../../services/product_service.dart';
import '../../services/admin_service.dart';
import 'add_edit_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _supermarketService = SupermarketService();
  final _productService = ProductService();
  final _adminService = AdminService();
  final _searchController = TextEditingController();

  Supermarket? _supermarket;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  bool _isLoading = true;
  bool _isAdminLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _checkAdminStatus() async {
    final isAdminLoggedIn = await _adminService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isAdminLoggedIn = isAdminLoggedIn;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supermarket = await _supermarketService.getCurrentSupermarket();
      if (supermarket != null) {
        final products = await _productService.getAllProducts(supermarket.id);
        final categories = await _productService.getCategories(supermarket.id);

        if (mounted) {
          setState(() {
            _supermarket = supermarket;
            _products = products;
            _filteredProducts = products;
            _categories = categories;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    _filterProducts();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedCategory.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final matchesSearch = query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.description.toLowerCase().contains(query);
          final matchesCategory =
              _selectedCategory.isEmpty || product.category == _selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();
      }
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? '' : category;
    });
    _filterProducts();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل أنت متأكد من حذف "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true && _supermarket != null) {
      final success = await _productService.deleteProduct(
        product.id,
        _supermarket!.id,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المنتج بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل حذف المنتج'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('المنتجات'),
          leading: _isAdminLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    context.go('/admin/dashboard');
                  },
                  tooltip: 'العودة إلى لوحة تحكم الأدمن',
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () async {
                if (_supermarket != null) {
                  final result = await context.push('/supermarket/products/add');
                  // تحديث القائمة إذا تم إضافة أو تعديل منتج
                  if (result == true || result == null) {
                    _loadData();
                  }
                }
              },
              tooltip: 'إضافة منتج',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            // Categories Filter
            if (_categories.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCategoryChip('الكل', '');
                    }
                    return _buildCategoryChip(
                        _categories[index - 1], _categories[index - 1]);
                  },
                ),
              ),
            const SizedBox(height: 8),
            // Products List
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد منتجات',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedCategory.isNotEmpty
                                ? 'لا توجد نتائج للبحث'
                                : 'ابدأ بإضافة منتجات جديدة',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_filteredProducts[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategorySelected(category),
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          if (_supermarket != null) {
            final result = await context.push(
              '/supermarket/products/edit',
              extra: product,
            );
            // تحديث القائمة إذا تم تعديل المنتج
            if (result == true || result == null) {
              _loadData();
            }
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              ImageWidget(
                imagePath: product.image,
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} د.ع',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lightPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.category,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    onPressed: () => _deleteProduct(product),
                    tooltip: 'حذف',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: product.isAvailable
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.isAvailable ? 'متوفر' : 'غير متوفر',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: product.isAvailable
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

