import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/supermarket.dart';
import '../../services/supermarket_service.dart';
import '../../services/product_service.dart';
import '../../services/admin_service.dart';
import '../../services/image_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({
    super.key,
    this.product,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imagePicker = ImagePicker();

  final _supermarketService = SupermarketService();
  final _productService = ProductService();
  final _adminService = AdminService();
  final _imageService = ImageService();

  Supermarket? _supermarket;
  bool _isLoading = false;
  bool _isAvailable = true;
  String _selectedCategory = '';
  bool _isAdminLoggedIn = false;
  File? _selectedImageFile;
  String? _selectedImagePath;

  // قائمة الفئات المتاحة
  final List<String> _categories = [
    'لحوم',
    'دجاج',
    'أسماك',
    'بقوليات',
    'ألبان وبيض',
    'فواكه',
    'خضروات',
    'مشروبات',
    'مشروبات باردة',
    'مشروبات ساخنة',
    'حلويات',
    'رقائق',
    'أغذية أساسية',
    'أرز ومعكرونة',
    'الصمون',
    'أطعمة جاهزة',
    'أطعمة مجمدة',
    'معلبات',
    'بهارات وتوابل',
    'منتجات صحية',
    'منتجات عضوية',
    'منتجات أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadData();
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
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final supermarket = await _supermarketService.getCurrentSupermarket();
    if (supermarket == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    setState(() {
      _supermarket = supermarket;
    });

    // إذا كان تعديل منتج موجود
    if (widget.product != null) {
      final product = widget.product!;
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toStringAsFixed(0);
      _imageController.text = product.image ?? '';
      _stockController.text = product.stock.toString();
      _selectedCategory = product.category;
      _categoryController.text = product.category;
      _isAvailable = product.isAvailable;
      
      // إذا كان هناك صورة محلية، تحميلها
      if (product.image != null && !product.image!.startsWith('http')) {
        final imageFile = File(product.image!);
        if (await imageFile.exists()) {
          setState(() {
            _selectedImageFile = imageFile;
            _selectedImagePath = product.image;
          });
        }
      }
    } else {
      // قيم افتراضية للمنتج الجديد
      _stockController.text = '0';
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories[0];
        _categoryController.text = _categories[0];
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        // نسخ الصورة إلى مجلد التطبيق
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'product_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
        final savedImage = await File(image.path).copy(path.join(imagesDir.path, fileName));
        
        setState(() {
          _selectedImageFile = savedImage;
          _selectedImagePath = savedImage.path;
          _imageController.text = savedImage.path; // استخدام مسار الملف المحلي
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate() && _supermarket != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final price = double.tryParse(_priceController.text);
        final stock = int.tryParse(_stockController.text) ?? 0;

        if (price == null || price <= 0) {
          throw 'السعر غير صحيح';
        }

        // رفع الصورة إذا كانت هناك صورة محلية جديدة
        String? imageUrl;
        if (_selectedImageFile != null) {
          // إذا كانت الصورة ملف محلي جديد، رفعها إلى السيرفر
          if (!_imageController.text.startsWith('http')) {
            // عرض رسالة تقدم
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('جاري رفع الصورة...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            
            imageUrl = await _imageService.uploadImage(_selectedImageFile!);
            if (imageUrl == null) {
              throw 'فشل رفع الصورة. يرجى المحاولة مرة أخرى';
            }
          } else {
            // إذا كانت الصورة URL موجودة، استخدامها
            imageUrl = _imageController.text.trim();
          }
        } else if (_imageController.text.trim().isNotEmpty && 
                   _imageController.text.startsWith('http')) {
          // إذا كان هناك URL موجود، استخدامه
          imageUrl = _imageController.text.trim();
        }

        final product = Product(
          id: widget.product?.id ?? '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          image: imageUrl,
          category: _selectedCategory,
          stock: stock,
          isAvailable: _isAvailable,
          supermarketId: _supermarket!.id,
        );

        bool success;
        if (widget.product != null) {
          final updatedProduct = await _productService.updateProduct(product);
          success = updatedProduct != null;
        } else {
          final addedProduct = await _productService.addProduct(product);
          success = addedProduct != null;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.product != null
                    ? 'تم تحديث المنتج بنجاح'
                    : 'تم إضافة المنتج بنجاح'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            // إرجاع true للإشارة إلى أن العملية نجحت
            context.pop(true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل حفظ المنتج'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
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
  }

  @override
  Widget build(BuildContext context) {
    if (_supermarket == null) {
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
          title: Text(widget.product != null ? 'تعديل المنتج' : 'إضافة منتج'),
          leading: _isAdminLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    context.go('/admin/dashboard');
                  },
                  tooltip: 'العودة إلى لوحة تحكم الأدمن',
                )
              : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                CustomTextField(
                  label: 'اسم المنتج',
                  hint: 'أدخل اسم المنتج',
                  controller: _nameController,
                  prefixIcon: Icons.inventory_2_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم المنتج';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Description
                CustomTextField(
                  label: 'الوصف',
                  hint: 'أدخل وصف المنتج',
                  controller: _descriptionController,
                  prefixIcon: Icons.description_rounded,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال وصف المنتج';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Price
                CustomTextField(
                  label: 'السعر (د.ع)',
                  hint: 'أدخل السعر',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.attach_money_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال السعر';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'السعر يجب أن يكون رقمًا أكبر من الصفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Category
                DropdownButtonFormField<String>(
                  value: _selectedCategory.isEmpty ? null : _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'الفئة',
                    prefixIcon: const Icon(
                      Icons.category_rounded,
                      color: AppTheme.primaryColor,
                    ),
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
                      vertical: 18,
                    ),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? '';
                      _categoryController.text = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء اختيار الفئة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Stock
                CustomTextField(
                  label: 'الكمية المتوفرة',
                  hint: 'أدخل الكمية',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.inventory_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الكمية';
                    }
                    final stock = int.tryParse(value);
                    if (stock == null || stock < 0) {
                      return 'الكمية يجب أن تكون رقمًا أكبر من أو يساوي الصفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Image Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'رابط الصورة (اختياري)',
                            hint: 'أدخل رابط الصورة أو اختر صورة',
                            controller: _imageController,
                            keyboardType: TextInputType.url,
                            prefixIcon: Icons.image_rounded,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('اختر صورة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    // Image Preview
                    if (_selectedImageFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImageFile!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (_imageController.text.isNotEmpty && _selectedImageFile == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imageController.text.startsWith('http')
                              ? Image.network(
                                  _imageController.text,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  ),
                                )
                              : Image.file(
                                  File(_imageController.text),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Availability
                Card(
                  child: SwitchListTile(
                    title: const Text('المنتج متوفر'),
                    subtitle: const Text('تفعيل/إلغاء توفر المنتج'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                    activeColor: AppTheme.successColor,
                  ),
                ),
                const SizedBox(height: 32),
                // Save Button
                CustomButton(
                  text: widget.product != null ? 'حفظ التعديلات' : 'إضافة المنتج',
                  onPressed: _handleSave,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

